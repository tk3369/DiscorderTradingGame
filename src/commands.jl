function register_commands(bot, prefix=",", cmd="$(prefix)ig")

    # Help
    register_command_handler!(
        bot, CommandTrigger(Regex("^$(cmd) help( .*)*"))
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
        bot, CommandTrigger(Regex("^$(cmd) quote (\\S+)(.*)\$"))
    ) do client, message, symbol, _tail
        symbol = strip(uppercase(symbol))
        price = find_real_time_price(symbol)
        reply(client, message, "The current price of $symbol is " * format_amount(price))
    end

    # Chart
    register_command_handler!(
        bot, CommandTrigger(Regex("^$(cmd) chart (\\S+) *(\\S*)(.*)\$"))
    ) do client, message, symbol, lookback, _tail
        # TodO report usage when _tail isn't blank?
        symbol = strip(uppercase(symbol))
        lookback = isempty(lookback) ? Year(1) : date_period(lowercase(lookback))
        from_date, to_date = recent_date_range(lookback)
        df = find_historical_prices(symbol, from_date, to_date)
        filename = generate_chart(symbol, df.Date, df."Adj Close")
        reply(
            client,
            message,
            """
            Here is the chart for $symbol for the past $lookback.
            To plot a chart with different time horizon,
            try something like `ig chart $symbol 90d` or `ig chart $symbol 10y`.
            """;
            files=[filename],
        )
    end

    # Start new game
    register_command_handler!(
        bot, CommandTrigger(Regex("^$(cmd) start-game\$"))
    ) do client, message, _tail
        user = message.author
        affirm_non_player(user.id)
        pf = start_new_game(user.id)
        amt = format_amount(pf.cash)
        reply(client, message, "You have $amt in your shiny new portfolio now! Good luck!")
    end

    # Abandon game
    register_command_handler!(
        bot, CommandTrigger(Regex("^$(cmd) abandon-game\$"))
    ) do client, message, _tail
        user = message.author
        affirm_player(user.id)
        reply(
            client,
            message,
            """
            Do you REALLY want to abandon the game and wipe out all of your data?
            If so, type `$cmd really-abandon-game`.
            """,
        )
    end

    # Really abandon game
    register_command_handler!(
        bot, CommandTrigger(Regex("^$(cmd) really-abandon-game\$"))
    ) do client, message, _tail
        user = message.author
        affirm_player(user.id)
        remove_game(user.id)
        reply(client, message, "Your investment game is now over. Play again soon!")
    end

    # Buy
    register_command_handler!(
        bot, CommandTrigger(Regex("^$(cmd) buy( .*)\$"))
    ) do client, message, arg
        user = message.author
        affirm_player(user.id)
        args = split(arg)
        length(args) == 2 || throw(
            IgUserError(
                "Invalid command. Try `$cmd 100 aapl` to buy 100 shares of Apple Inc."
            ),
        )
        symbol = strip(uppercase(args[2]))
        shares = tryparse(Int, args[1])
        shares !== nothing ||
            throw(IgUserError("please enter number of shares as a number: `$shares`"))
        purchase_price = format_amount(execute_buy(user.id, symbol, shares))
        reply(
            client, message, "You have bought $shares shares of $symbol at $purchase_price"
        )
    end

    # Sell
    register_command_handler!(
        bot, CommandTrigger(Regex("^$(cmd) sell( .*)\$"))
    ) do client, message, arg
        user = message.author
        affirm_player(user.id)

        args = split(arg)
        length(args) == 2 || throw(
            IgUserError(
                "Invalid command. Try `$cmd sell 100 aapl` to sell 100 shares of Apple Inc.",
            ),
        )

        symbol = strip(uppercase(args[2]))
        shares = tryparse(Int, args[1])
        shares !== nothing ||
            throw(IgUserError("please enter number of shares as a number: `$shares`"))

        current_price = format_amount(execute_sell(user.id, symbol, shares))
        reply(client, message, "You have sold $shares shares of $symbol at $current_price.")
    end

    # View holdings
    register_command_handler!(
        bot, CommandTrigger(Regex("^$(cmd) view( .*)\$"))
    ) do client, message, arg
        user = message.author
        affirm_player(user.id)

        df = get_mark_to_market_portfolio(user.id)
        reformat_view!(df)

        args = split(arg)
        view = length(args) == 1 && args[1] == "simple" ? SimpleView() : PrettyView()
        table = make_pretty_table(view, df)
        total_str = format_amount(round(Int, sum(df.amount)))
        reply(
            client,
            message,
            """
            Here is your portfolio:
            ```
            $table
            ```
            Total portfolio Value: $total_str
            """,
        )
        check_bad_stocks(client, message, user, df)
    end

    # View performance
    register_command_handler!(
        bot, CommandTrigger(Regex("^$(cmd) perf\$"))
    ) do client, message
        user = message.author
        affirm_player(user.id)
        df = calculate_performance(user.id)
        table = pretty_table(String, df; header=names(df))
        reply(
            client,
            message,
            """
            Your stocks' performance today:
            ```
            $table
            ```
            """,
        )
    end
end
