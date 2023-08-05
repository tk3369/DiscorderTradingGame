function cmd_gl(client, message, args)
    user = message.author
    affirm_player(user.id)
    df = gain_loss(user.id)
    page_size = 25  # approximate table size before exceeding Discord 2,000 char limit
    for (i, subdf) in enumerate(partition_table(df, page_size))
        if i == 1
            reply(client, message, "Here are the gains/losses for your stocks")
        end
        table = pretty_table(String, subdf; header=names(subdf))
        reply(
            client,
            message,
            """
            ```
            $table
            ```
            """,
        )
    end
    return nothing
end

"Return a data frame with gains/losses for user's current holdings."
function gain_loss(user_id::Snowflake)
    pf = load_portfolio(user_id)
    df = get_grouped_holdings(holdings_data_frame(pf))
    rename!(df, "purchase_price" => "px_buy")

    df.px_now = fetch.(@async(get_quote(s)) for s in df.symbol)
    df.chg = round.(df.px_now .- df.px_buy; digits=2)
    df.pct_chg = round.(df.chg ./ df.px_buy * 100; digits=1)
    rename!(df, "pct_chg" => "% chg")

    df.shares = round.(Int, df.shares)

    return df
end
