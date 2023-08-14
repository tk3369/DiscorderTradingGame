module DiscorderTradingGame

using CairoPlot
using CSV
using DataFrames
using Dates
using Discorder
using Downloads
using ExpiringCaches
using Formatting
using HTTP
using JSON3
using StructTypes
using PrettyTables

include("types.jl")
include("history.jl")
include("gainloss.jl")
include("rank.jl")
include("terminate.jl")
include("commands.jl")
include("error_handling.jl")
include("pricing.jl")
include("utils.jl")
include("charting.jl")
include("game.jl")

function run_bot(command_prefix::Char, port=6000)
    bot = Bot()
    register_commands(bot, command_prefix)
    register_error_handler(bot)
    return start(bot, port)
end

end
