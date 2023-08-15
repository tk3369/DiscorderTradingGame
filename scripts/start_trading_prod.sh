#!/bin/sh
# Start trading game bot

export DISCORD_BOT_TOKEN=${TRADING_GAME_TOKEN_PROD}

export JULIA_DEBUG=bot

julia --project=. --heap-size-hint=400M -e "using DiscorderTradingGame: run_bot; run_bot('-')"
