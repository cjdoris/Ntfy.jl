module Ntfy

export ntfy

using Base64
using Downloads
using Printf
using Preferences

const DEFAULT_BASE_URL = "https://ntfy.sh"
const BASE_URL_PREFERENCE = "base_url"
const BASE_URL_ENVIRONMENT = "NTFY_BASE_URL"
const USER_PREFERENCE = "user"
const USER_ENVIRONMENT = "NTFY_USER"
const PASSWORD_PREFERENCE = "password"
const PASSWORD_ENVIRONMENT = "NTFY_PASSWORD"
const TOKEN_PREFERENCE = "token"
const TOKEN_ENVIRONMENT = "NTFY_TOKEN"

struct RequestHandler end

"""
    DummyRequestHandler(; requests=Any[], status=200, body="dummy response")

Internal helper used by the test suite to capture ntfy requests without issuing
network calls. `requests` stores the collected request tuples, `status`
controls the simulated HTTP status code, and `body` sets the simulated response
message.
"""
Base.@kwdef mutable struct DummyRequestHandler
    requests::Vector{Any} = Any[]
    status::Int = 200
    body::String = "dummy response"
end

"""
    getpref(pref, envvar)

Return the configured preference identified by `pref` if set, otherwise fall back
to the environment variable `envvar`. Returns `nothing` when neither value is
available. The return value is always a `String` when present.
"""
function getpref(pref, envvar)
    preference_value = @load_preference(pref, nothing)
    if preference_value !== nothing
        return convert(String, preference_value)
    end
    env_value = get(ENV, envvar, nothing)
    return env_value === nothing ? nothing : convert(String, env_value)
end

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
    render_template(template, info)

Replace `{{ name }}` placeholders in `template` using the provided `info`.
"""
function render_template(template, info)
    function resolve_key(key)
        value = if key == "value"
            io = IOBuffer()
            if info.is_error
                showerror(IOContext(io, :limit => true), info.value)
            else
                show(IOContext(io, :limit => true), info.value)
            end
            String(take!(io))
        elseif key == "success"
            info.is_error ? "error" : "success"
        elseif key == "SUCCESS"
            info.is_error ? "ERROR" : "SUCCESS"
        elseif key == "Success"
            info.is_error ? "Error" : "Success"
        elseif key == "time_ns"
            format_time_value(float(info.time_ns))
        elseif key == "time_us"
            format_time_value(float(info.time_ns) / 1e3)
        elseif key == "time_ms"
            format_time_value(float(info.time_ns) / 1e6)
        elseif key == "time_s"
            format_time_value(float(info.time_ns) / 1e9)
        elseif key == "time_m"
            format_time_value(float(info.time_ns) / 6e10)
        elseif key == "time_h"
            format_time_value(float(info.time_ns) / 3.6e12)
        elseif key == "time_d"
            format_time_value(float(info.time_ns) / 8.64e13)
        elseif key == "time"
            format_elapsed_time(float(info.time_ns))
        else
            return nothing
        end
        return value
    end
    return replace(template, r"\{\{\s*[A-Za-z_]+\s*\}\}" => match_text -> begin
        key_match = match(r"^\{\{\s*([A-Za-z_]+)\s*\}\}$", match_text)
        key = key_match === nothing ? nothing : key_match.captures[1]
        value = key === nothing ? nothing : resolve_key(key)
        return value === nothing ? match_text : value
    end)
end

function format_message(template, info)
    template_str = normalise_message(template)
    return render_template(template_str, info)
end

"""
    handle_priority!(headers, priority)

Add an `X-Priority` header to `headers` when `priority` is provided.
"""
handle_priority!(headers, ::Nothing) = headers
function handle_priority!(headers, priority::AbstractString)
    push!(headers, "X-Priority" => convert(String, priority))
    return headers
end
handle_priority!(headers, priority::Integer) = handle_priority!(headers, string(priority))
handle_priority!(headers, ::Any) = error("Unsupported priority type")

"""
    handle_title!(headers, title)

Add an `X-Title` header to `headers` when `title` is provided.
"""
handle_title!(headers, ::Nothing) = headers
function handle_title!(headers, title::AbstractString)
    push!(headers, "X-Title" => convert(String, title))
    return headers
end
handle_title!(headers, title::Symbol) = handle_title!(headers, String(title))
handle_title!(headers, ::Any) = error("Unsupported title type")

"""
    handle_tags!(headers, tags)

Add an `X-Tags` header to `headers` when `tags` is provided.
"""
handle_tags!(headers, ::Nothing) = headers
function handle_tags!(headers, tags::AbstractString)
    push!(headers, "X-Tags" => convert(String, tags))
    return headers
end
handle_tags!(headers, tags::AbstractVector) = handle_tags!(headers, join([convert(String, tag) for tag in tags], ","))
handle_tags!(headers, ::Any) = error("Unsupported tags type")

"""
    handle_click!(headers, click)

Add an `X-Click` header to `headers` when `click` is provided.
"""
handle_click!(headers, ::Nothing) = headers
function handle_click!(headers, click::AbstractString)
    push!(headers, "X-Click" => convert(String, click))
    return headers
end
handle_click!(headers, ::Any) = error("Unsupported click type")

"""
    handle_attach!(headers, attach)

Add an `X-Attach` header to `headers` when `attach` is provided.
"""
handle_attach!(headers, ::Nothing) = headers
function handle_attach!(headers, attach::AbstractString)
    push!(headers, "X-Attach" => convert(String, attach))
    return headers
end
handle_attach!(headers, ::Any) = error("Unsupported attach type")

"""
    handle_actions!(headers, actions)

Add an `X-Actions` header to `headers` when `actions` is provided.
"""
handle_actions!(headers, ::Nothing) = headers
function handle_actions!(headers, actions::AbstractString)
    push!(headers, "X-Actions" => convert(String, actions))
    return headers
end
handle_actions!(headers, actions::AbstractVector) = handle_actions!(headers, join([convert(String, action) for action in actions], "; "))
handle_actions!(headers, ::Any) = error("Unsupported actions type")

"""
    handle_email!(headers, email)

Add an `X-Email` header to `headers` when `email` is provided.
"""
handle_email!(headers, ::Nothing) = headers
function handle_email!(headers, email::AbstractString)
    push!(headers, "X-Email" => convert(String, email))
    return headers
end
handle_email!(headers, ::Any) = error("Unsupported email type")

"""
    handle_markdown!(headers, markdown)

Add an `X-Markdown` header to `headers` when Markdown support is explicitly
requested.
"""
handle_markdown!(headers, ::Nothing) = headers
function handle_markdown!(headers, markdown::Bool)
    if markdown
        push!(headers, "X-Markdown" => "yes")
    end
    return headers
end
handle_markdown!(headers, ::Any) = error("Unsupported markdown type")

"""
    handle_delay!(headers, delay)

Add an `X-Delay` header to `headers` when `delay` is provided.
"""
handle_delay!(headers, ::Nothing) = headers
function handle_delay!(headers, delay::AbstractString)
    delay_str = convert(String, delay)
    isempty(delay_str) && error("delay cannot be empty")
    push!(headers, "X-Delay" => delay_str)
    return headers
end
handle_delay!(headers, ::Any) = error("Unsupported delay type")

"""
    handle_auth!(headers, auth)

Add an `Authorization` header to `headers` based on the provided `auth`
argument or configured defaults. No header is added when no credentials are
available.
"""
function handle_auth!(headers, ::Nothing)
    selected_auth = resolve_default_auth()
    return selected_auth === nothing ? headers : handle_auth!(headers, selected_auth)
end
function handle_auth!(headers, auth::AbstractString)
    token = convert(String, auth)
    isempty(token) && error("auth token cannot be empty")
    push!(headers, "Authorization" => string("Bearer ", token))
    return headers
end
function handle_auth!(headers, auth::Tuple{A,B}) where {A,B}
    username, password = auth
    creds = string(convert(String, username), ":", convert(String, password))
    encoded = Base64.base64encode(creds)
    push!(headers, "Authorization" => string("Basic ", encoded))
    return headers
end
handle_auth!(headers, ::Tuple) = error("Unsupported auth tuple length")
handle_auth!(headers, ::Any) = error("Unsupported auth type")

"""
    handle_extra_headers!(headers, extra_headers)

Append additional headers from `extra_headers` to `headers`.
"""
handle_extra_headers!(headers, ::Nothing) = headers
function handle_extra_headers!(headers, extra_headers::AbstractDict)
    append!(headers, Pair{String,String}[convert(String, k) => convert(String, v) for (k, v) in extra_headers])
    return headers
end
function handle_extra_headers!(headers, extra_headers::AbstractVector)
    for item in extra_headers
        if item isa Pair
            push!(headers, convert(String, first(item)) => convert(String, last(item)))
        else
            error("extra_headers entries must be pairs")
        end
    end
    return headers
end
handle_extra_headers!(headers, ::Any) = error("Unsupported extra_headers type")

"""
    ntfy(topic, message; ...)

Publish a notification to `topic` with `message` via the ntfy.sh service. Optional
settings correspond to the headers supported by ntfy.sh. Raises an error if the
response status is not in the 2xx range unless `nothrow=true`, in which case the
error is logged and suppressed.

# Keyword Arguments
- `priority`
- `title`
- `tags`
- `click`
- `attach`
- `actions`
- `email`
- `delay`
- `markdown`
- `extra_headers`
- `base_url`
- `auth`
- `request_handler`
- `nothrow`
"""
function ntfy(topic, message; priority=nothing, title=nothing, tags=nothing, click=nothing,
        attach=nothing, actions=nothing, email=nothing, delay=nothing, markdown=nothing,
        extra_headers=nothing, base_url=nothing, auth=nothing, request_handler=nothing,
        nothrow=false)
    try
        handler = request_handler === nothing ? RequestHandler() : request_handler
        topic_name = normalise_topic(topic)::String
        message = normalise_message(message)::String
        base_url = normalise_base_url(base_url)::String

        url = build_url(base_url, topic_name)
        headers = Pair{String,String}[]

        handle_priority!(headers, priority)
        handle_title!(headers, title)
        handle_tags!(headers, tags)
        handle_click!(headers, click)
        handle_attach!(headers, attach)
        handle_actions!(headers, actions)
        handle_email!(headers, email)
        handle_markdown!(headers, markdown)
        handle_delay!(headers, delay)
        handle_auth!(headers, auth)
        handle_extra_headers!(headers, extra_headers)

        req = (method = "POST", url = url, headers = headers, body = message)

        status, response_message = request(handler, req)

        if status < 200 || status >= 300
            error("ntfy request failed with status $(status): $(response_message)")
        end
        return nothing
    catch err
        if nothrow
            @warn "ntfy() failed" err
            return nothing
        else
            rethrow()
        end
    end
end

function request(::RequestHandler, req)
    response = Downloads.request(req.url; method=req.method, headers=req.headers, input=IOBuffer(req.body))
    return response.status, response.message
end

function request(handler::DummyRequestHandler, req)
    push!(handler.requests, req)
    return handler.status, handler.body
end

"""
    ntfy(f::Function, topic, message; ...)

Invoke `f` and publish its output (or error) to `topic`. Success notifications use the
`message` and related arguments, while error notifications use the corresponding
`error_` variants. String message and title values are treated as templates supporting
`{{ value }}`, `{{ success }}`, `{{ time }}`, and `{{ time_ns }}`/`{{ time_s }}` style
placeholders unless provided via functions, in which case the return values are
passed through without templating. Function-valued arguments receive an `info`
named tuple with `value`, `is_error`, and `time_ns` fields.

# Keyword Arguments
- `error_message`
- `title`
- `error_title`
- `tags`
- `error_tags`
- `priority`
- `error_priority`
- `click`
- `error_click`
- `attach`
- `error_attach`
- `actions`
- `error_actions`
- `email`
- `error_email`
- `delay`
- `error_delay`
- `markdown`
- `error_markdown`
- `nothrow`
- `kwargs...`
"""
function ntfy(f::Function, topic, message_template;
        error_message=message_template,
        title=nothing,
        error_title=title,
        tags=nothing,
        error_tags=tags,
        priority=nothing,
        error_priority=priority,
        click=nothing,
        error_click=click,
        attach=nothing,
        error_attach=attach,
        actions=nothing,
        error_actions=actions,
        email=nothing,
        error_email=email,
        delay=nothing,
        error_delay=delay,
        markdown=nothing,
        error_markdown=markdown,
        nothrow=false,
        kwargs...)
    """
        inner_ntfy(topic, message_template, info; title=nothing, tags=nothing, priority=nothing,
            click=nothing, attach=nothing, actions=nothing, email=nothing, delay=nothing,
            markdown=nothing)

    Resolve function arguments, format templated message/title values, and dispatch a
    notification for the given `info`.
    """
    function inner_ntfy(topic, message_template, info;
            title=nothing,
            tags=nothing,
            priority=nothing,
            click=nothing,
            attach=nothing,
            actions=nothing,
            email=nothing,
            delay=nothing,
            markdown=nothing)
        function resolve_arg(arg)
            return arg isa Function ? arg(info) : arg
        end
        function resolve_template(template, is_error)
            if template isa Function
                return template(info)
            elseif template isa AbstractString
                return format_message(template, info)
            end
            return template
        end
        try
            is_error = info.is_error
            message = resolve_template(message_template, is_error)
            resolved_title = resolve_template(title, is_error)
            resolved_tags = resolve_arg(tags)
            resolved_priority = resolve_arg(priority)
            resolved_click = resolve_arg(click)
            resolved_attach = resolve_arg(attach)
            resolved_actions = resolve_arg(actions)
            resolved_email = resolve_arg(email)
            resolved_delay = resolve_arg(delay)
            resolved_markdown = resolve_arg(markdown)

            ntfy(topic, message;
                title=resolved_title,
                tags=resolved_tags,
                priority=resolved_priority,
                click=resolved_click,
                attach=resolved_attach,
                actions=resolved_actions,
                email=resolved_email,
                delay=resolved_delay,
                markdown=resolved_markdown,
                kwargs...)
            return nothing
        catch err
            if nothrow
                @warn "ntfy() failed" err
                return nothing
            else
                rethrow()
            end
        end
    end

    start_time = Base.time_ns()
    value = try
        f()
    catch err
        finish_time = Base.time_ns()
        info = (value=err, is_error=true, time_ns=finish_time - start_time)
        inner_ntfy(topic, error_message, info;
            title=error_title,
            tags=error_tags,
            priority=error_priority,
            click=error_click,
            attach=error_attach,
            actions=error_actions,
            email=error_email,
            delay=error_delay,
            markdown=error_markdown)
        rethrow()
    end
    finish_time = Base.time_ns()
    info = (value=value, is_error=false, time_ns=finish_time - start_time)
    inner_ntfy(topic, message_template, info;
        title=title,
        tags=tags,
        priority=priority,
        click=click,
        attach=attach,
        actions=actions,
        email=email,
        delay=delay,
        markdown=markdown)
    return value
end

"""
    normalise_topic(value)

Convert `value` to a topic string or raise an error if it cannot be converted.
"""
normalise_topic(::Any) = error("Unsupported topic type")
normalise_topic(topic::AbstractString) = convert(String, topic)

"""
    normalise_message(value)

Convert `value` to a message string or raise an error if it cannot be converted.
"""
normalise_message(::Any) = error("Unsupported message type")
normalise_message(message::AbstractString) = convert(String, message)

"""
    normalise_base_url(value)

Convert `value` to a base URL string, defaulting to `https://ntfy.sh` (or a configured
preference or environment variable) when `nothing` is provided.
"""
normalise_base_url(::Nothing) = resolve_default_base_url()
normalise_base_url(::Any) = error("Unsupported base_url type")
function normalise_base_url(url::AbstractString)
    url_str = convert(String, url)
    return isempty(url_str) ? error("base_url cannot be empty") : normalise_base_url_string(url_str)
end

"""
    resolve_default_base_url()

Resolve the base URL by first checking package preferences, then the
`NTFY_BASE_URL` environment variable, and finally falling back to the
default ntfy.sh URL.
"""
function resolve_default_base_url()
    url = getpref(BASE_URL_PREFERENCE, BASE_URL_ENVIRONMENT)
    return url === nothing ? DEFAULT_BASE_URL : normalise_base_url(url)
end

"""
    normalise_base_url_string(url)

Strip trailing slashes from a base URL string to ensure consistent URL
construction.
"""
function normalise_base_url_string(url::AbstractString)
    return String(rstrip(url, '/'))
end

"""
    resolve_default_auth()

Determine the default `auth` configuration using preferences first and then
environment variables. Uses the configured token when available, otherwise
falls back to a basic auth username/password pair. Returns `nothing` when no
credentials are configured.
"""
function resolve_default_auth()
    token = getpref(TOKEN_PREFERENCE, TOKEN_ENVIRONMENT)
    if token !== nothing
        return token
    end

    user = getpref(USER_PREFERENCE, USER_ENVIRONMENT)
    password = getpref(PASSWORD_PREFERENCE, PASSWORD_ENVIRONMENT)
    if user !== nothing && password !== nothing
        return (user, password)
    end

    return nothing
end

function build_url(base_url::AbstractString, topic::AbstractString)
    stripped = rstrip(base_url, '/')
    return string(stripped, "/", lstrip(topic, '/'))
end

end # module
