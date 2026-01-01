module DatesExt

using Dates
using Ntfy

function Ntfy.handle_delay!(headers, date::Date)
    push!(headers, "X-Delay" => string(floor(Int, datetime2unix(DateTime(date)))))
    return headers
end

function Ntfy.handle_delay!(headers, datetime::DateTime)
    push!(headers, "X-Delay" => string(floor(Int, datetime2unix(datetime))))
    return headers
end

function Ntfy.handle_delay!(headers, period::Second)
    push!(headers, "X-Delay" => string(period.value, " ", abs(period.value) == 1 ? "second" : "seconds"))
    return headers
end

function Ntfy.handle_delay!(headers, period::Minute)
    push!(headers, "X-Delay" => string(period.value, " ", abs(period.value) == 1 ? "minute" : "minutes"))
    return headers
end

function Ntfy.handle_delay!(headers, period::Hour)
    push!(headers, "X-Delay" => string(period.value, " ", abs(period.value) == 1 ? "hour" : "hours"))
    return headers
end

function Ntfy.handle_delay!(headers, period::Day)
    push!(headers, "X-Delay" => string(period.value, " ", abs(period.value) == 1 ? "day" : "days"))
    return headers
end

end
