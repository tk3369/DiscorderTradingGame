# The first word is determined by splitting non-alphanumeric characters
# and then take the first token.
first_word(str) = split(strip(str), r"[^a-zA-Z0-9]")[1]

function cmd_hist(client, message, arg)
    user = message.author
    affirm_player(user.id)
    @info "arg" arg typeof(arg)
    if length(args) == 0
        symbol = nothing
        clause = ""
    else
        # Need to take first word because the user might enter more than one symbol
        # For example, CMD hist sym1 sym2, and in that case, arg == " sym1 sym2"
        symbol = first_word(arg)
        clause = " of $symbol"
    end

    # when symbol is nothing, retrieve the purchase history for entire portfolio
    df = hist(user.id, symbol)
    if nrow(df) > 0
        table = pretty_table(String, df; header=names(df))
        reply(
            client,
            message,
            """here is the purchase history$clause:
            ```
            $table
            ```
            """,
        )
    else
        msg = "no purchase history was found"
        if symbol !== nothing
            msg *= " for $symbol"
        end
        reply(client, message, msg)
    end
    return nothing
end

"Return a data frame with the purchase history of current holdings."
function hist(user_id::Snowflake, symbol::Optional{AbstractString})
    pf = load_portfolio(user_id)
    df = get_holdings_data_frame(pf)
    if symbol !== nothing
        filter!(:symbol => ==(symbol), df)
    end

    df.shares = round.(Int, df.shares)
    rename!(df, "purchase_price" => "px_buy")
    rename!(df, "purchase_date" => "date")

    sort!(df, [:symbol, :date, :px_buy])

    return df[!, [:symbol, :date, :px_buy, :shares]]
end
