module OteraEngineExt

using Ntfy
using OteraEngine
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
    template_view(info)

Return a template view containing the standard ntfy substitution values.
"""
function template_view(info)
    view = Dict{Symbol,Any}()
    view[:value] = render_value(info, MIME"text/plain"())
    view[:value_md] = render_markdown_value(info)
    view[:success] = info.is_error ? "error" : "success"
    view[:SUCCESS] = info.is_error ? "ERROR" : "SUCCESS"
    view[:Success] = info.is_error ? "Error" : "Success"
    view[:time_ns] = format_time_value(float(info.time_ns))
    view[:time_us] = format_time_value(float(info.time_ns) / 1e3)
    view[:time_ms] = format_time_value(float(info.time_ns) / 1e6)
    view[:time_s] = format_time_value(float(info.time_ns) / 1e9)
    view[:time_m] = format_time_value(float(info.time_ns) / 6e10)
    view[:time_h] = format_time_value(float(info.time_ns) / 3.6e12)
    view[:time_d] = format_time_value(float(info.time_ns) / 8.64e13)
    view[:time] = format_elapsed_time(float(info.time_ns))
    view[:is_error] = info.is_error
    return view
end

"""
    Ntfy.render_template(template::OteraEngine.Template, info)

Render an OteraEngine template using the standard ntfy substitution values.
"""
function Ntfy.render_template(template::OteraEngine.Template, info)
    return template(init=template_view(info))
end

end
