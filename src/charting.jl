"Plot a simple price chart"
function generate_chart(symbol::AbstractString, dates::Vector{Date}, values::Vector{<:Real})
    from_date, to_date = extrema(dates)
    last_price_str = format_amount(last(values))
    c = crplot(
        dates,
        values;
        xticks=5,
        yticks=10,
        title="$symbol Historical Prices ($from_date to $to_date)\nLast price: $last_price_str",
    )
    filename = tempname() * ".png"
    CairoPlot.write_to_png(c, filename)
    return filename
end
