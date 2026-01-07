# Common templating helpers for extension modules; include this file in each
# templating extension to share template key handling and value rendering.

"""
    TEMPLATE_KEYS

Ordered tuple of supported template substitution keys.
"""
const TEMPLATE_KEYS = (
    :value,
    :value_md,
    :success,
    :SUCCESS,
    :Success,
    :time_ns,
    :time_us,
    :time_ms,
    :time_s,
    :time_m,
    :time_h,
    :time_d,
    :time,
    :is_error,
)

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

"""
    render_value(info, mime)

Render `info.value` using the provided MIME type.
"""
function render_value(info, mime)
    io = IOBuffer()
    show(IOContext(io, :limit => true), mime, info.value)
    return String(take!(io))
end

"""
    render_markdown_value(info)

Render `info.value` as markdown, falling back to plain text wrapped in
triple backticks if markdown rendering fails.
"""
function render_markdown_value(info)
    try
        return render_value(info, MIME"text/markdown"())
    catch err
        plain_value = render_value(info, MIME"text/plain"())
        return "```\n$(plain_value)\n```"
    end
end

"""
    template_value(key, info)

Return the substitution value for `key` using the provided notification info.
"""
function template_value(key::Symbol, info)
    if key === :value
        return render_value(info, MIME"text/plain"())
    elseif key === :value_md
        return render_markdown_value(info)
    elseif key === :success
        return info.is_error ? "error" : "success"
    elseif key === :SUCCESS
        return info.is_error ? "ERROR" : "SUCCESS"
    elseif key === :Success
        return info.is_error ? "Error" : "Success"
    elseif key === :time_ns
        return format_time_value(float(info.time_ns))
    elseif key === :time_us
        return format_time_value(float(info.time_ns) / 1e3)
    elseif key === :time_ms
        return format_time_value(float(info.time_ns) / 1e6)
    elseif key === :time_s
        return format_time_value(float(info.time_ns) / 1e9)
    elseif key === :time_m
        return format_time_value(float(info.time_ns) / 6e10)
    elseif key === :time_h
        return format_time_value(float(info.time_ns) / 3.6e12)
    elseif key === :time_d
        return format_time_value(float(info.time_ns) / 8.64e13)
    elseif key === :time
        return format_elapsed_time(float(info.time_ns))
    elseif key === :is_error
        return info.is_error
    end
    error("Unsupported template key: $(key)")
end

template_value(key::AbstractString, info) = template_value(Symbol(key), info)
