"""
Return a data frame with historical prices data. Columns include:
- `Date`
- `Open`
- `High`
- `Low`
- `Close`
- `Adj Close`
- `Volume`
"""
function find_historical_prices(symbol::AbstractString, from_date::Date, to_date::Date)
    from_sec = seconds_since_1970(from_date)
    to_sec = seconds_since_1970(to_date + Day(1))  # apparently, Yahoo is exclusive on this end
    symbol = HTTP.escapeuri(symbol)
    url =
        "https://query1.finance.yahoo.com/v7/finance/download/$symbol?" *
        "period1=$from_sec&period2=$to_sec&interval=1d&events=history&includeAdjustedClose=true"
    @info "Fetching data from Yahoo" url
    try
        elapsed = @elapsed df = DataFrame(
            CSV.File(Downloads.download(url); missingstring="null")
        )
        dropmissing!(df)
        @info "$(now())\thistorical_prices\t$symbol\t$from_date\t$to_date\t$elapsed"
        return df
    catch ex
        @info "Exception" ex
        if ex isa Downloads.RequestError && ex.response.status == 404
            throw(
                IgUserError(
                    "there is no historical prices for $symbol. Is it a valid stock symbol?"
                ),
            )
        else
            rethrow()
        end
    end
end

"Return yesterday's EOD pricing data"
find_yesterday_price(symbol::AbstractString) = find_latest_price(symbol, Day(1))

"Return real-time pricing data"
find_real_time_price(symbol::AbstractString) = find_latest_price(symbol, Day(0))

# Using Yahoo's historical price query to find the latest price
# Fortunately, Yahoo also provides real-time prices, so setting offset to Day(0)
# would return the current price.
function find_latest_price(symbol::AbstractString, offset::DatePeriod)
    to_date = today() - offset
    from_date = to_date - Day(4)   # account for weekend and holidays
    df = find_historical_prices(symbol, from_date, to_date)
    if nrow(df) == 0
        @error "Unable to find price for $symbol, defaulting to zero. Exception=$ex"
        throw(IgUserError("No price is found for $symbol. Invalid symbol?"))
    end
    return df[end, "Adj Close"]
end
