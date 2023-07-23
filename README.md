# DiscorderTradingGame

Set environment variable with your bot's token:
```
$ export DISCORD_BOT_TOKEN="TOKEN_HERE"
```

Start Discorder server:
```
cd Discorder.jl
$ julia --project=. example/server.jl
```

Start the trading game bot:
```
cd
$ julia --project=. -e 'using DiscorderTradingGame: run_bot; run_bot()'
```
