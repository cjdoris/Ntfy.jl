module DatesExt

using Dates
using Ntfy

function Ntfy.normalise_delay(date::Date)
    return string(floor(Int, datetime2unix(DateTime(date))))
end

function Ntfy.normalise_delay(datetime::DateTime)
    return string(floor(Int, datetime2unix(datetime)))
end

function Ntfy.normalise_delay(period::Second)
    return string(period.value, " ", abs(period.value) == 1 ? "second" : "seconds")
end

function Ntfy.normalise_delay(period::Minute)
    return string(period.value, " ", abs(period.value) == 1 ? "minute" : "minutes")
end

function Ntfy.normalise_delay(period::Hour)
    return string(period.value, " ", abs(period.value) == 1 ? "hour" : "hours")
end

function Ntfy.normalise_delay(period::Day)
    return string(period.value, " ", abs(period.value) == 1 ? "day" : "days")
end

end
