module MustacheExt

using Mustache
using Ntfy

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
    view = Dict{Any,Any}()
    function add_key!(key::AbstractString, value)
        view[key] = value
        view[Symbol(key)] = value
    end
    add_key!("value", () -> render_value(info, MIME"text/plain"()))
    add_key!("value_md", () -> render_markdown_value(info))
    add_key!("success", () -> (info.is_error ? "error" : "success"))
    add_key!("SUCCESS", () -> (info.is_error ? "ERROR" : "SUCCESS"))
    add_key!("Success", () -> (info.is_error ? "Error" : "Success"))
    add_key!("time_ns", () -> Ntfy.format_time_value(float(info.time_ns)))
    add_key!("time_us", () -> Ntfy.format_time_value(float(info.time_ns) / 1e3))
    add_key!("time_ms", () -> Ntfy.format_time_value(float(info.time_ns) / 1e6))
    add_key!("time_s", () -> Ntfy.format_time_value(float(info.time_ns) / 1e9))
    add_key!("time_m", () -> Ntfy.format_time_value(float(info.time_ns) / 6e10))
    add_key!("time_h", () -> Ntfy.format_time_value(float(info.time_ns) / 3.6e12))
    add_key!("time_d", () -> Ntfy.format_time_value(float(info.time_ns) / 8.64e13))
    add_key!("time", () -> Ntfy.format_elapsed_time(float(info.time_ns)))
    add_key!("is_error", info.is_error)
    return view
end

"""
    Ntfy.render_template(template::Mustache.MustacheTokens, info)

Render a Mustache template using the standard ntfy substitution values.
"""
function Ntfy.render_template(template::Mustache.MustacheTokens, info)
    return Mustache.render(template, template_view(info))
end

end
