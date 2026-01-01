module Ntfy

export ntfy

using Base64
using Downloads
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

function format_message(template, value, is_error::Bool)
    template_str = normalise_message(template)
    status_lower = is_error ? "error" : "success"
    status_title = is_error ? "Error" : "Success"
    status_upper = is_error ? "ERROR" : "SUCCESS"
    io = IOBuffer()
    if is_error
        showerror(IOContext(io, :limit => true), value)
    else
        show(IOContext(io, :limit => true), value)
    end
    value_str = String(take!(io))

    return replace(template_str,
        "\$(value)" => value_str,
        "\$(success)" => status_lower,
        "\$(SUCCESS)" => status_upper,
        "\$(Success)" => status_title,
    )
end

"""
    handle_priority!(headers, priority)

Add an `X-Priority` header to `headers` when `priority` is provided.
"""
function handle_priority!(headers, priority)
    if priority === nothing
        return headers
    end
    push!(headers, "X-Priority" => normalise_priority(priority)::String)
    return headers
end

"""
    handle_title!(headers, title)

Add an `X-Title` header to `headers` when `title` is provided.
"""
function handle_title!(headers, title)
    if title === nothing
        return headers
    end
    push!(headers, "X-Title" => normalise_title(title)::String)
    return headers
end

"""
    handle_tags!(headers, tags)

Add an `X-Tags` header to `headers` when `tags` is provided.
"""
function handle_tags!(headers, tags)
    if tags === nothing
        return headers
    end
    push!(headers, "X-Tags" => normalise_tags(tags)::String)
    return headers
end

"""
    handle_click!(headers, click)

Add an `X-Click` header to `headers` when `click` is provided.
"""
function handle_click!(headers, click)
    if click === nothing
        return headers
    end
    push!(headers, "X-Click" => normalise_click(click)::String)
    return headers
end

"""
    handle_attach!(headers, attach)

Add an `X-Attach` header to `headers` when `attach` is provided.
"""
function handle_attach!(headers, attach)
    if attach === nothing
        return headers
    end
    push!(headers, "X-Attach" => normalise_attach(attach)::String)
    return headers
end

"""
    handle_actions!(headers, actions)

Add an `X-Actions` header to `headers` when `actions` is provided.
"""
function handle_actions!(headers, actions)
    if actions === nothing
        return headers
    end
    push!(headers, "X-Actions" => normalise_actions(actions)::String)
    return headers
end

"""
    handle_email!(headers, email)

Add an `X-Email` header to `headers` when `email` is provided.
"""
function handle_email!(headers, email)
    if email === nothing
        return headers
    end
    push!(headers, "X-Email" => normalise_email(email)::String)
    return headers
end

"""
    handle_markdown!(headers, markdown)

Add an `X-Markdown` header to `headers` when Markdown support is explicitly
requested.
"""
function handle_markdown!(headers, markdown)
    if markdown === true
        push!(headers, "X-Markdown" => normalise_markdown(markdown)::String)
        return headers
    elseif markdown === false || markdown === nothing
        return headers
    end

    normalise_markdown(markdown)
    return headers
end

"""
    handle_delay!(headers, delay)

Add an `X-Delay` header to `headers` when `delay` is provided.
"""
function handle_delay!(headers, delay)
    if delay === nothing
        return headers
    end
    push!(headers, "X-Delay" => normalise_delay(delay)::String)
    return headers
end

"""
    handle_auth!(headers, auth)

Add an `Authorization` header to `headers` based on the provided `auth`
argument or configured defaults. No header is added when no credentials are
available.
"""
function handle_auth!(headers, auth)
    selected_auth = auth === nothing ? resolve_default_auth() : auth
    if selected_auth === nothing
        return headers
    end
    push!(headers, "Authorization" => normalise_auth(selected_auth)::String)
    return headers
end

"""
    handle_extra_headers!(headers, extra_headers)

Append additional headers from `extra_headers` to `headers`.
"""
function handle_extra_headers!(headers, extra_headers)
    append!(headers, normalise_extra_headers(extra_headers))
    return headers
end

"""
    ntfy(topic, message; priority=nothing, title=nothing, tags=nothing, click=nothing,
        attach=nothing, actions=nothing, email=nothing, delay=nothing, markdown=nothing,
        extra_headers=nothing, base_url=nothing, auth=nothing, request_handler=nothing)

Publish a notification to `topic` with `message` via the ntfy.sh service. Optional
settings correspond to the headers supported by ntfy.sh. Raises an error if the
response status is not in the 2xx range.
"""
function ntfy(topic, message; priority=nothing, title=nothing, tags=nothing, click=nothing,
        attach=nothing, actions=nothing, email=nothing, delay=nothing, markdown=nothing,
        extra_headers=nothing, base_url=nothing, auth=nothing, request_handler=nothing)
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
end

function request(::RequestHandler, req)
    response = Downloads.request(req.url; method=req.method, headers=req.headers, input=IOBuffer(req.body))
    return response.status, response.message
end

function request(handler::DummyRequestHandler, req)
    push!(handler.requests, req)
    return handler.status, handler.body
end

function ntfy(f::Function, topic, message_template; title=nothing, kwargs...)
    function format_title(value, is_error)
        return title isa AbstractString ? format_message(title, value, is_error) : title
    end
    value = try
        f()
    catch err
        message = format_message(message_template, err, true)
        ntfy(topic, message; title=format_title(err, true), kwargs...)
        rethrow()
    end
    message = format_message(message_template, value, false)
    ntfy(topic, message; title=format_title(value, false), kwargs...)
    return nothing
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
    normalise_priority(value)

Convert `value` to a priority string for ntfy.sh.
"""
normalise_priority(::Any) = error("Unsupported priority type")
normalise_priority(priority::AbstractString) = convert(String, priority)
normalise_priority(priority::Integer) = string(priority)

"""
    normalise_title(value)

Convert `value` to a title string or raise an error.
"""
normalise_title(::Any) = error("Unsupported title type")
normalise_title(title::AbstractString) = convert(String, title)
normalise_title(title::Symbol) = String(title)

"""
    normalise_tags(value)

Convert `value` to a comma-separated tag string.
"""
normalise_tags(::Any) = error("Unsupported tags type")
normalise_tags(tags::AbstractString) = convert(String, tags)
function normalise_tags(tags::AbstractVector)
    return join([convert(String, tag) for tag in tags], ",")
end

"""
    normalise_click(value)

Convert `value` to a click action URL string.
"""
normalise_click(::Any) = error("Unsupported click type")
normalise_click(click::AbstractString) = convert(String, click)

"""
    normalise_attach(value)

Convert `value` to an attachment URL string.
"""
normalise_attach(::Any) = error("Unsupported attach type")
normalise_attach(attach::AbstractString) = convert(String, attach)

"""
    normalise_actions(value)

Convert `value` to an actions header string.
"""
normalise_actions(::Any) = error("Unsupported actions type")
normalise_actions(actions::AbstractString) = convert(String, actions)
function normalise_actions(actions::AbstractVector)
    return join([convert(String, action) for action in actions], "; ")
end

"""
    normalise_email(value)

Convert `value` to an email string.
"""
normalise_email(::Any) = error("Unsupported email type")
normalise_email(email::AbstractString) = convert(String, email)

"""
    normalise_delay(value)

Convert `value` to a delay string for scheduled delivery.
"""
normalise_delay(::Any) = error("Unsupported delay type")
function normalise_delay(delay::AbstractString)
    delay_str = convert(String, delay)
    return isempty(delay_str) ? error("delay cannot be empty") : delay_str
end

"""
    normalise_markdown(value)

Convert `value` to a Markdown flag string.
"""
normalise_markdown(::Any) = error("Unsupported markdown type")
normalise_markdown(flag::Bool) = flag ? "yes" : "no"

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
    normalise_extra_headers(value)

Convert `value` to a vector of string header pairs.
"""
normalise_extra_headers(::Nothing) = Pair{String,String}[]
normalise_extra_headers(::Any) = error("Unsupported extra_headers type")
function normalise_extra_headers(headers::AbstractDict)
    return Pair{String,String}[convert(String, k) => convert(String, v) for (k, v) in headers]
end
function normalise_extra_headers(headers::AbstractVector)
    pairs = Pair{String,String}[]
    for item in headers
        if item isa Pair
            push!(pairs, convert(String, first(item)) => convert(String, last(item)))
        else
            error("extra_headers entries must be pairs")
        end
    end
    return pairs
end

"""
    normalise_auth(value)

Convert `value` to an `Authorization` header value string.
"""
function normalise_auth(auth::AbstractString)
    token = convert(String, auth)
    return isempty(token) ? error("auth token cannot be empty") : string("Bearer ", token)
end
function normalise_auth(auth::Tuple{A,B}) where {A,B}
    username, password = auth
    creds = string(convert(String, username), ":", convert(String, password))
    encoded = Base64.base64encode(creds)
    return string("Basic ", encoded)
end
normalise_auth(::Tuple) = error("Unsupported auth tuple length")
normalise_auth(::Any) = error("Unsupported auth type")

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
