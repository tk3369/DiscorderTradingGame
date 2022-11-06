"Format money amount"
format_amount(x::Real) = format(x; commas=true, precision=2)
format_amount(x::Integer) = format(x; commas=true)

# Date utilities

seconds_since_1970(d::Date) = (d - Day(719163)).instant.periods.value * 24 * 60 * 60

# This functino was added because it used to be mockable
current_date() = today()

# Convert a date period string into a DatePeriod object
# julia> TradingGameBot.date_period("2y") isa Dates.DatePeriod
# true
function date_period(s::AbstractString)
    m = match(r"^(\d+)([ymd])$", s)
    m !== nothing || throw(IgUserError("invalid date period: $s. Try `5y` or `30m`."))
    num = parse(Int, m.captures[1])
    dct = Dict("y" => Year, "m" => Month, "d" => Day)
    return dct[m.captures[2]](num)
end

"Returns a tuple of two dates by looking back from today's date"
function recent_date_range(lookback::DatePeriod)
    T = current_date()
    to_date = T
    from_date = T - lookback
    return from_date, to_date
end

function reply(client, message, content)
    result = create_message(
        client,
        message.channel_id;
        content,
        message_reference=MessageReference(; message_id=message.id),
    )
    return result
end

function expect(condition, message)
    if !condition
        throw(ErrorException(message))
    end
    return nothing
end
