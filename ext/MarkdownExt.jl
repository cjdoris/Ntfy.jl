module MarkdownExt

using Markdown
using Ntfy
using Printf

"""
    format_time_value(value)

Format a numeric time value with at most three significant figures.
"""
function format_time_value(value)
    return @sprintf("%.3g", float(value))
end

"""
    format_elapsed_time(time_ns)

Format an elapsed duration, provided in nanoseconds, into a human-readable
string using the largest sensible unit.
"""
function format_elapsed_time(time_ns)
    time_value = float(time_ns)
    units = (
        (86400e9, "d"),
        (3600e9, "h"),
        (60e9, "m"),
        (1e9, "s"),
        (1e6, "ms"),
        (1e3, "μs"),
        (1.0, "ns"),
    )
    for (unit_ns, suffix) in units
        if time_value >= unit_ns
            return "$(format_time_value(time_value / unit_ns)) $(suffix)"
        end
    end
    return "0 ns"
end

function Ntfy.ntfy(topic, message::Markdown.MD; markdown=true, kwargs...)
    return Ntfy.ntfy(topic, string(message); markdown=markdown, kwargs...)
end

end
