# Common templating helpers for extension modules; include this file in each
# templating extension to share template key handling and value rendering.

"""
    TEMPLATE_KEYS

Ordered tuple of supported template substitution keys.
"""
const TEMPLATE_KEYS = (
    :value,
    :time,
    :value_str,
    :value_md,
    :success_str,
    :SUCCESS_str,
    :Success_str,
    :time_str,
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
    format_elapsed_time(time_seconds)

Format an elapsed duration, provided in seconds, into a human-readable string
using a sensible unit.
"""
function format_elapsed_time(time_seconds)
    time_value = float(time_seconds)
    if time_value >= 86400.0
        return "$(format_time_value(time_value / 86400.0)) d"
    elseif time_value >= 3600.0
        return "$(format_time_value(time_value / 3600.0)) h"
    elseif time_value >= 60.0
        return "$(format_time_value(time_value / 60.0)) m"
    else
        return "$(format_time_value(time_value)) s"
    end
end

"""
    render_value(info, mime)

Render `info.value` using the provided MIME type.
"""
function render_value(info, mime=MIME"text/plain"())
    if info.is_error
        if mime isa MIME"text/plain"
            io = IOBuffer()
            showerror(IOContext(io, :limit => true), info.value)
            return String(take!(io))
        end
        error("Cannot render non-plain MIME content for error values.")
    end
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
        plain_value = render_value(info)
        return "```\n$(plain_value)\n```"
    end
end

"""
    template_value(key, info)

Return the substitution value for `key` using the provided notification info.
"""
function template_value(key::Symbol, info)
    if key === :value
        return info.value
    elseif key === :time
        return info.time
    elseif key === :value_str
        return render_value(info)
    elseif key === :value_md
        return render_markdown_value(info)
    elseif key === :success_str
        return info.is_error ? "error" : "success"
    elseif key === :SUCCESS_str
        return info.is_error ? "ERROR" : "SUCCESS"
    elseif key === :Success_str
        return info.is_error ? "Error" : "Success"
    elseif key === :time_str
        return format_elapsed_time(float(info.time))
    elseif key === :is_error
        return info.is_error
    end
    error("Unsupported template key: $(key)")
end

template_value(key::AbstractString, info) = template_value(Symbol(key), info)
