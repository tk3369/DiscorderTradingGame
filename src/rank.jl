function cmd_rank(client, message, arg)
    arg = strip(arg)  # trim arg string

    n = arg == "" ? 5 : tryparse(Int, arg)
    n !== nothing || throw(
        IgUserError("invalid rank argument `$arg`. " * "Try `ig rank` or `ig rank 10`")
    )

    rt = get_ranking_table(client)
    rt = rt[1:min(n, nrow(rt)), :]  # get top N results
    rt_str = format_view_table(PrettyView(), rt)

    reply(
        client,
        message,
        """here's the current ranking:
        ```
        $rt_str
        ```
        """,
    )
    return nothing
end

function get_ranking_table(client)
    valuations = value_all_portfolios()
    if length(valuations) > 0
        users_dict = retrieve_users(client, [v.id for v in valuations])
        @debug "get_ranking_table" valuations users_dict
        df = DataFrame(;
            rank=1:length(valuations),
            player=[users_dict[v.id].username for v in valuations],
            portfolio_value=[v.total for v in valuations],
        )
        return df
    else
        return DataFrame(; player=String[], portfolio_value=Float64[])
    end
end

"Format data frame using pretty table"
function format_view_table(::PrettyView, df::AbstractDataFrame)
    return pretty_table(String, df; formatters=integer_formatter, header=names(df))
end

function value_all_portfolios()
    pfs = load_all_portfolios()
    valuations = []
    for (id, pf) in pfs
        @debug "Evaluating portfolio" id pf
        df = mark_to_market!(get_holdings_data_frame(pf))
        mv = nrow(df) > 0 ? sum(df.market_value) : 0.0
        cash = pf.cash
        total = mv + cash
        push!(valuations, (; id, mv, cash, total))
    end
    sort!(valuations; lt=(x, y) -> x.total < y.total, rev=true)
    # @info "value_all_portfolios result" valuations
    return valuations
end
