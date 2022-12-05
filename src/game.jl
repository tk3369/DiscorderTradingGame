const QUOTE_CACHE = Cache{String,Float64}(Minute(1))

"File location of the game file for a user"
user_game_file_path(user_id::Snowflake) = joinpath(game_data_directory(), "$user_id.json")

"Directory of the investment game data files"
game_data_directory() = joinpath("data", "ig")

"Returns true if user already has a game in progress."
is_player(user_id::Snowflake) = isfile(user_game_file_path(user_id))

"Start a new game file"
function start_new_game(user_id::Snowflake)
    pf = IgPortfolio(1_000_000.00, IgHolding[])
    save_portfolio(user_id, pf)
    return pf
end

"Destroy the existing game file for a user."
remove_game(user_id::Snowflake) = rm(user_game_file_path(user_id))

"Affirms the user has a game or throw an exception."
function affirm_player(user_id::Snowflake)
    is_player(user_id) || throw(
        IgUserError("you don't have a game yet. Type `ig start-game` to start a new game."),
    )
    return nothing
end

"Affirms the user does not have game or throw an exception."
function affirm_non_player(user_id::Snowflake)
    !is_player(user_id) || throw(
        IgUserError(
            "You already have a game running. Type `ig view` to see your current portfolio.",
        ),
    )
    return nothing
end

"Save a user portfolio in the data directory."
function save_portfolio(user_id::Snowflake, pf::IgPortfolio)
    @debug "Saving portfolio" user_id
    path = user_game_file_path(user_id)
    write(ensurepath!(path), JSON3.write(pf))
    return nothing
end

"Load the portfolio for a single user"
function load_portfolio(user_id::Snowflake)
    @debug "Loading portfolio" user_id
    path = user_game_file_path(user_id)
    return load_portfolio(path)
end

"Load a single portfolio from game file"
function load_portfolio(path::AbstractString)
    bytes = read(path)
    return JSON3.read(bytes, IgPortfolio)
end

"Extract user id from the portfolio data file"
function user_id_from_path(path::AbstractString)
    filename = basename(path)
    filename_without_extension = replace(filename, r"\.json$" => "")
    return parse(Snowflake, filename_without_extension)
end

"Load all game files"
function load_all_portfolios()
    dir = game_data_directory()
    files = readdir(dir)
    user_ids = user_id_from_path.(files)
    return Dict(
        user_id => load_portfolio(joinpath(dir, file)) for
        (user_id, file) in zip(user_ids, files)
    )
end

"Fetch quote of a stock, but possibly with a time delay."
function get_quote(symbol::AbstractString)
    return get!(QUOTE_CACHE, symbol) do
        return find_real_time_price(symbol)
    end
end

"Buy stock for a specific user at a specific price."
function execute_buy(
    user_id::Snowflake,
    symbol::AbstractString,
    shares::Real,
    current_price::Real=find_real_time_price(symbol),
)
    @debug "Buying stock" user_id symbol shares
    current_price > 0.0 ||
        throw(IgUserError("No price is found for $symbol. Is it a valid stock symbol?"))
    pf = load_portfolio(user_id)
    cost = shares * current_price
    if pf.cash >= cost
        pf.cash -= cost
        push!(pf.holdings, IgHolding(symbol, shares, current_date(), current_price))
        save_portfolio(user_id, pf)
        return current_price
    end
    return throw(
        IgUserError(
            "you don't have enough cash. " *
            "Buying $shares shares of $symbol will cost you $(format_amount(cost)) " *
            "but you only have $(format_amount(pf.cash))",
        ),
    )
end

"Sell stock for a specific user. Returns executed price."
function execute_sell(
    user_id::Snowflake,
    symbol::AbstractString,
    shares::Real,
    current_price::Real=find_real_time_price(symbol),
)
    @debug "Selling stock" user_id symbol shares
    pf = load_portfolio(user_id)
    pf_new = execute_sell_fifo(pf, symbol, shares, current_price)
    save_portfolio(user_id, pf_new)
    return current_price
end

"Sell stock based upon FIFO accounting scheme. Returns the resulting `IgPortfolio` object."
function execute_sell_fifo(
    pf::IgPortfolio, symbol::AbstractString, shares::Real, current_price::Real
)
    existing_shares = count_shares(pf, symbol)
    if existing_shares == 0
        throw(IgUserError("you do not have $symbol in your portfolio"))
    elseif shares > existing_shares
        existing_shares_str = format_amount(round(Int, existing_shares))
        throw(
            IgUserError(
                "you cannot sell more than what you own ($existing_shares_str shares)"
            ),
        )
    end

    proceeds = shares * current_price

    # Construct a new IgPortfolio object that contains the resulting portfolio after
    # selling the stock. The following logic does it incrementally but just for documentation
    # purpose an alternative algorithm would be to make a copy and then relief the sold lots.
    holdings = IgHolding[]
    pf_new = IgPortfolio(pf.cash + proceeds, holdings)
    remaining = shares   # keep track of how much to sell
    for h in pf.holdings
        if h.symbol != symbol || remaining == 0
            push!(holdings, h)
        else
            if h.shares > remaining  # relief lot partially
                revised_lot = IgHolding(
                    symbol, h.shares - remaining, h.date, h.purchase_price
                )
                push!(holdings, revised_lot)
                remaining = 0
            else # relief this lot completely and continue
                remaining -= h.shares
            end
        end
    end
    return pf_new
end

"""
Returns a data frame for the portfolio holdings.
Note that:
1. It does not include cash portion of the portfolio
2. Multiple lots of the same stock will be in different rows
See also: `get_grouped_holdings`(@ref)
"""
function get_holdings_data_frame(pf::IgPortfolio)
    return DataFrame(;
        symbol=[h.symbol for h in pf.holdings],
        shares=[h.shares for h in pf.holdings],
        purchase_price=[h.purchase_price for h in pf.holdings],
        purchase_date=[h.date for h in pf.holdings],
    )
end

"Returns grouped holdings by symbol with average purchase price"
function get_grouped_holdings(df::AbstractDataFrame)
    df = combine(groupby(df, :symbol)) do sdf
        shares = sum(sdf.shares)
        weights = sdf.shares / shares
        purchase_price = sum(weights .* sdf.purchase_price)
        return (; shares, purchase_price)
    end
    return sort!(df, :symbol)
end

"Return a data frame with the user's portfolio marked to market."
function get_mark_to_market_portfolio(user_id::Snowflake)
    pf = load_portfolio(user_id)
    df = get_grouped_holdings(get_holdings_data_frame(pf))
    cash_entry = get_cash_entry(pf)
    if nrow(df) > 0
        mark_to_market!(df)
        push!(df, cash_entry)
    else
        df = DataFrame([cash_entry])
    end
    return df
end

"Return the portoflio cash as named tuple that can be appended to the portfolio data frame."
function get_cash_entry(pf::IgPortfolio)
    return (
        symbol="CASH:USD",
        shares=pf.cash,
        purchase_price=1.0,
        current_price=1.0,
        market_value=pf.cash,
    )
end

"Add columns with current price and market value"
function mark_to_market!(df::AbstractDataFrame)
    df.current_price = fetch.(@async(get_quote(s)) for s in df.symbol)
    df.market_value = df.shares .* df.current_price
    return df
end

"Format data frame using pretty table"
function make_pretty_table(::PrettyView, df::AbstractDataFrame)
    return pretty_table(String, df; formatters=integer_formatter, header=names(df))
end

"Return portfolio view as string in a simple format"
function make_pretty_table(::SimpleView, df::AbstractDataFrame)
    io = IOBuffer()
    for (i, r) in enumerate(eachrow(df))
        if !startswith(r.symbol, "CASH:")
            println(
                io,
                i,
                ". ",
                r.symbol,
                ": ",
                round(Int, r.shares),
                " x \$",
                format_amount(r.price),
                " = \$",
                format_amount(round(Int, r.amount)),
            )
        else
            println(io, i, ". ", r.symbol, " = ", format_amount(round(Int, r.amount)))
        end
    end

    return String(take!(io))
end

# Shorten colummn headings for better display in Discord
function reformat_view!(df::AbstractDataFrame)
    select!(df, Not(:purchase_price))
    rename!(df, "current_price" => "price", "market_value" => "amount")
    return df
end

# If there's any unknown stocks, advise user to get rid of it
function check_bad_stocks(c::BotClient, m::Message, user::User, df::AbstractDataFrame)
    bad_stocks = filter(r -> r.price == 0.0, df)
    if nrow(bad_stocks) > 0
        bad_stock_symbols = join(bad_stocks.symbol, ",")
        reply(
            client,
            message,
            """
            You have some unknown stocks in your portfolio: $bad_stock_symbols
            Please use `sell` command to get rid of the bad positions.
            """,
        )
    end
    return nothing
end

"Return total number of shares for a specific stock in the portfolio."
function count_shares(pf::IgPortfolio, symbol::AbstractString)
    lots = find_lots(pf, symbol)
    return length(lots) > 0 ? round(sum(lot.shares for lot in lots); digits=0) : 0
    # note that we store shares as Float64 but uses it as Int (for now)
end

"Find lots for a specific stock in the portfolio. Sort by purchase date."
function find_lots(pf::IgPortfolio, symbol::AbstractString)
    lots = IgHolding[x for x in pf.holdings if x.symbol == symbol]
    return sort(lots; lt=(x, y) -> x.date < y.date)
end

"Return a data frame with daily performance of user's current holdings."
function calculate_performance(user_id::Snowflake)
    pf = load_portfolio(user_id)
    symbols = unique(h.symbol for h in pf.holdings)
    prices_yesterday = fetch.(@async(find_yesterday_price(s)) for s in symbols)
    prices_today = fetch.(@async(get_quote(s)) for s in symbols)
    prices_change = prices_today .- prices_yesterday
    prices_change_pct = prices_change ./ prices_yesterday * 100
    df = DataFrame(;
        symbol=symbols,
        px_eod=prices_yesterday,
        px_now=prices_today,
        chg=round.(prices_change; digits=2),
        pct_chg=round.(prices_change_pct; digits=1),
    )
    rename!(df, "pct_chg" => "% chg")
    sort!(df, :symbol)
    return df
end
