module DatesExt

using Dates
using Ntfy

Ntfy.handle_delay!(headers, date::Date) = Ntfy.handle_delay!(headers, string(floor(Int, datetime2unix(DateTime(date)))))

Ntfy.handle_delay!(headers, datetime::DateTime) = Ntfy.handle_delay!(headers, string(floor(Int, datetime2unix(datetime))))

Ntfy.handle_delay!(headers, period::Second) = Ntfy.handle_delay!(headers, string(period.value, " ", abs(period.value) == 1 ? "second" : "seconds"))

Ntfy.handle_delay!(headers, period::Minute) = Ntfy.handle_delay!(headers, string(period.value, " ", abs(period.value) == 1 ? "minute" : "minutes"))

Ntfy.handle_delay!(headers, period::Hour) = Ntfy.handle_delay!(headers, string(period.value, " ", abs(period.value) == 1 ? "hour" : "hours"))

Ntfy.handle_delay!(headers, period::Day) = Ntfy.handle_delay!(headers, string(period.value, " ", abs(period.value) == 1 ? "day" : "days"))

end
