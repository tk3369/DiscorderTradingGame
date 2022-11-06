function register_commands(bot)

    # Help
    register_command_handler!(
        bot, CommandTrigger(r"^,ig help( .*)*")
    ) do client, message, tail
        reply(
            client,
            message,
            """
            Play the investment game (ig). US market only for now.
            ```
            ig start-game
            ig abandon-game
            ```
            Research stocks:
            ```
            ig quote <symbol>            - get current price quote
            ig chart <symbol> [period]   - historical price chart
                Period is optional. Examples are: 200d, 36m, or 10y
                for 200 days, 36 months, or 10 years respectively.
            ```
            Manage portfolio:
            ```
            ig buy <n> <symbol>    - buy <n> shares of a stock
            ig sell <n> <symbol>   - sell <n> shares of a stock
            ig view                - view holdings and current market values
            ig perf                - compare with yesterday's EOD prices
            ig gl                  - gain/loss view of your current portfolio
            ig hist [<symbol>]     - purchase history
            ```
            How are you doing?
            ```
            ig rank [n]            - display top <n> portfolios, defaults to 5.
            ```
            """,
        )
    end

    # Quote
    register_command_handler!(
        bot, CommandTrigger(r"^,ig quote ([^ ]*)")
    ) do client, message, arg
        symbol = strip(uppercase(arg))
        price = find_real_time_price(symbol)
        reply(client, message, "The current price of $symbol is " * format_amount(price))
    end

    # Chart
    register_command_handler!(
        bot, CommandTrigger(r"^,ig chart (\S+) *(\S*)(.*)$")
    ) do client, message, symbol, lookback, _tail
        # TodO report usage when _tail isn't blank?
        symbol = strip(uppercase(symbol))
        lookback = isempty(lookback) ? Year(1) : date_period(lowercase(lookback))
        from_date, to_date = recent_date_range(lookback)
        df = find_historical_prices(symbol, from_date, to_date)
        filename = generate_chart(symbol, df.Date, df."Adj Close")
        result = create_message(
            client,
            message.channel_id;
            files=[filename],
            message_reference=MessageReference(; message_id=message.id),
            content="""
                here is the chart for $symbol for the past $lookback.
                To plot a chart with different time horizon,
                try something like `ig chart $symbol 90d` or `ig chart $symbol 10y`.
                    """,
        )
    end
end
