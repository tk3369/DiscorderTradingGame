function cmd_hist(client, message, args)
    user = message.author
    affirm_player(user.id)
    @info "args" args typeof(args)
    if length(args) == 1
        symbol = uppercase(args)
        clause = " of $symbol"
    else
        symbol = nothing
        clause = ""
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
