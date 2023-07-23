"Format money amount"
format_amount(x::Real) = format(x; commas=true, precision=2)
format_amount(x::Integer) = format(x; commas=true)

"Formatters used by PrettyTable"
decimal_formatter(v, i, j) = v isa Real ? format_amount(v) : v
integer_formatter(v, i, j) = v isa Real ? format_amount(round(Int, v)) : v

# Date utilities

seconds_since_1970(d::Date) = (d - Day(719163)).instant.periods.value * 24 * 60 * 60

# This functino was added because it used to be mockable
current_date() = today()

# Convert a date period string into a DatePeriod object
# julia> DiscorderTradingGame.date_period("2y") isa Dates.DatePeriod
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

# Reply to a user message with specified content.
# Ok to pass other keyword arguments like `files`.
function reply(client, message, content; kwargs...)
    return retry(
        () -> create_message(
            client,
            message.channel_id;
            content,
            message_reference=MessageReference(; message_id=message.id),
            kwargs...,
        );
        delays=[1.0],  # retry only once after 1 sec
    )()
end

function expect(condition, message)
    if !condition
        throw(ErrorException(message))
    end
    return nothing
end

"""
    ensurepath!(fileorpath::AbstractString)

Ensure that the path exists in a way that writing to path does not error.
Returns the argument afterwards for composability.
"""
function ensurepath!(fileorpath::AbstractString)
    mkpath(dirname(fileorpath))
    return fileorpath
end
