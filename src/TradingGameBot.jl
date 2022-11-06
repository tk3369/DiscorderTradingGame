module TradingGameBot

using CairoPlot
using CSV
using DataFrames
using Dates
using Discorder
using Downloads
using Formatting
using HTTP
using JSON3
using StructTypes

include("types.jl")
include("commands.jl")
include("error_handling.jl")
include("pricing.jl")
include("utils.jl")
include("charting.jl")

function run_bot()
    port = 6000
    bot = Bot()
    register_commands(bot)
    return start(bot, port)
end

end
