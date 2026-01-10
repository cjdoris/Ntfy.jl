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
"""
    quote_action_value(value)

Quote action values that contain commas, semicolons, or quotes.
"""
function quote_action_value(value::AbstractString)
    if any(ch -> ch in (',', ';', '\'', '"'), value)
        if !occursin("'", value)
            return string("'", value, "'")
        elseif !occursin("\"", value)
            return string("\"", value, "\"")
        else
            error("Action value contains both single and double quotes: $(value)")
        end
    end
    return value
end

"""
    format_action_value(value)

Format a single action value, quoting it when necessary.
"""
function format_action_value(value)
    if value isa AbstractString
        return quote_action_value(convert(String, value))
    elseif value isa Symbol
        return quote_action_value(String(value))
    elseif value isa Bool || value isa Number
        return quote_action_value(string(value))
    else
        error("Unsupported action value type: $(typeof(value))")
    end
end

"""
    format_action_key(key)

Format an action key used in `key=value` entries.
"""
function format_action_key(key)
    if key isa AbstractString
        return convert(String, key)
    elseif key isa Symbol
        return String(key)
    else
        error("Unsupported action key type: $(typeof(key))")
    end
end

"""
    is_named_tuple_expr(expr)

Return `true` when `expr` represents a named tuple literal.
"""
function is_named_tuple_expr(expr::Expr)
    return expr.head == :tuple && all(arg -> arg isa Expr && arg.head in (:kw, :(=)), expr.args)
end

"""
    action_entries(action_args)

Return action entries rendered from the provided action arguments.
"""
function action_entries(action_args)
    entries = String[]
    for arg in action_args
        if arg isa Expr && arg.head in (:kw, :(=))
            key = format_action_key(arg.args[1])
            value = arg.args[2]
            if value isa Expr && is_named_tuple_expr(value)
                for entry in value.args
                    subkey = format_action_key(entry.args[1])
                    subvalue = format_action_value(entry.args[2])
                    push!(entries, "$(key).$(subkey)=$(subvalue)")
                end
            else
                push!(entries, "$(key)=$(format_action_value(value))")
            end
        else
            push!(entries, format_action_value(arg))
        end
    end
    return entries
end

"""
    format_action(action)

Format a single action definition.
"""
format_action(action::AbstractString) = convert(String, action)
function format_action(action::Expr)
    action.head == :tuple || error("Unsupported action expression type: $(action.head)")
    return join(action_entries(action.args), ", ")
end
function format_action(action::Tuple)
    return join(action_entries(action), ", ")
end
format_action(::Any) = error("Unsupported action type")

function handle_actions!(headers, actions::AbstractString)
    push!(headers, "X-Actions" => convert(String, actions))
    return headers
end
handle_actions!(headers, actions::Expr) = handle_actions!(headers, format_action(actions))
handle_actions!(headers, actions::Tuple) = handle_actions!(headers, format_action(actions))
function handle_actions!(headers, actions::AbstractVector)
    formatted = [format_action(action) for action in actions]
    return handle_actions!(headers, join(formatted, "; "))
end
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

function ntfy end

"""
    ntfy(topic, message; ...)

Publish a notification to `topic` with `message` via the `ntfy.sh` service.

## Keyword Arguments
- `priority`: The priority, as a string or integer (1-5).
- `title`: The title, as a string.
- `tags`: The tag/tags, as a string or vector of strings.
- `click`: The action to take when clicked, as a string.
- `attach`: URL of an attachment, as a string.
- `actions`: Action button/buttons, as a string, list of strings, or tuple
  expression like `:(view, "Open portal", "https://...", clear=true)`.
- `email`: Email address to also notify, as a string.
- `delay`: Specify a time in the future to send the notification, as a string or `DateTime` or `Period`.
- `markdown`: Set to `true` if the `message` is markdown-formatted, for richer display.
- `extra_headers`: Extra headers to send to `ntfy.sh`.
- `base_url`: Alternative server URL.
- `auth`: Authorisation credentials, either a token (as a string) or a username and password (tuple of two strings).
- `nothrow`: Set to `true` to suppress any exceptions and instead log a warning message.
  Useful to prevent a long-running script from failing just because `ntfy.sh` is down,
  for example.

!!! example

    ```julia
    ntfy(
        "phil_alerts",
        "Remote access detected. Act right away.";
        priority = "urgent",
        title = "Unauthorized access detected",
        tags = ["warning", "skull"],
        delay = "tomorrow, 10am",
        auth = ("phil", "supersecret"),
    )
    ```

!!! tip

    Use the `nothrow=true` argument to prevent a long-running script from failing if
    `ntfy()` fails for some reason (e.g. if `ntfy.sh` is down). It will emit a warning
    instead.

# Extended help

## Configuration

Keyword arguments take precendence, but some default values can be configured via
preferences (in the sense of [Preferences.jl](https://github.com/JuliaPackaging/Preferences.jl))
or environment variables.

`base_url`: This is `$DEFAULT_BASE_URL` by default but can be set with the
`$BASE_URL_PREFERENCE` preference or the `$BASE_URL_ENVIRONMENT` environment variable.

`auth`: By default no auth is used, but can be set with one of:
- Auth token: `$TOKEN_PREFERENCE` preference or `$TOKEN_ENVIRONMENT` environment variable.
- Username & password: `$USER_PREFERENCE` and `$PASSWORD_PREFERENCE` preferences or `$USER_ENVIRONMENT` and
  `$PASSWORD_ENVIRONMENT` environment variables.

## Extensions

[Markdown.jl](https://docs.julialang.org/en/v1/stdlib/Markdown/):
The `message` can also be a `md"..."` string, in which case `markdown=true` is set
automatically.

[Dates.jl](https://docs.julialang.org/en/v1/stdlib/Dates/):
The `delay` can be a `DateTime`, `Date`, `Second`, `Minute`, `Hour` or `Day`.
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
