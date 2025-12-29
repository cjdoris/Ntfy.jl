module Ntfy

export ntfy

using Downloads

const DEFAULT_BASE_URL = "https://ntfy.sh"

"""
    ntfy(topic, message; priority=nothing, title=nothing, tags=nothing, click=nothing,
        attach=nothing, actions=nothing, email=nothing, delay=nothing, markdown=nothing,
        extra_headers=nothing, base_url=nothing)

Publish a notification to `topic` with `message` via the ntfy.sh service. Optional
settings correspond to the headers supported by ntfy.sh. Raises an error if the
response status is not in the 2xx range.
"""
function ntfy(topic, message; priority=nothing, title=nothing, tags=nothing, click=nothing,
        attach=nothing, actions=nothing, email=nothing, delay=nothing, markdown=nothing,
        extra_headers=nothing, base_url=nothing)
    req = ntfy_request(topic, message; priority=priority, title=title, tags=tags,
        click=click, attach=attach, actions=actions, email=email, delay=delay,
        markdown=markdown, extra_headers=extra_headers, base_url=base_url)

    response = Downloads.request(req.method, req.url; headers=req.headers, body=req.body)
    status = response.status
    if status < 200 || status >= 300
        error("ntfy request failed with status $(status): $(response.message)")
    end
    return response
end

"""
    ntfy_request(topic, message; priority=nothing, title=nothing, tags=nothing,
        click=nothing, attach=nothing, actions=nothing, email=nothing, delay=nothing,
        markdown=nothing, extra_headers=nothing, base_url=nothing)

Construct the HTTP parameters needed to publish a notification to ntfy.sh. Returns a
`NamedTuple` with the request method, URL, headers, and body. No network requests are
performed.
"""
function ntfy_request(topic, message; priority=nothing, title=nothing, tags=nothing,
        click=nothing, attach=nothing, actions=nothing, email=nothing, delay=nothing,
        markdown=nothing, extra_headers=nothing, base_url=nothing)
    topic = normalise_topic(topic)::String
    message = normalise_message(message)::String
    base_url = normalise_base_url(base_url)::String

    url = build_url(base_url, topic)
    headers = Pair{String,String}[]

    if priority !== nothing
        push!(headers, "X-Priority" => normalise_priority(priority)::String)
    end
    if title !== nothing
        push!(headers, "X-Title" => normalise_title(title)::String)
    end
    if tags !== nothing
        push!(headers, "X-Tags" => normalise_tags(tags)::String)
    end
    if click !== nothing
        push!(headers, "X-Click" => normalise_click(click)::String)
    end
    if attach !== nothing
        push!(headers, "X-Attach" => normalise_attach(attach)::String)
    end
    if actions !== nothing
        push!(headers, "X-Actions" => normalise_actions(actions)::String)
    end
    if email !== nothing
        push!(headers, "X-Email" => normalise_email(email)::String)
    end
    if markdown === true
        push!(headers, "X-Markdown" => normalise_markdown(markdown)::String)
    elseif markdown !== false && markdown !== nothing
        normalise_markdown(markdown)
    end
    if delay !== nothing
        push!(headers, "X-Delay" => normalise_delay(delay)::String)
    end

    append!(headers, normalise_extra_headers(extra_headers))

    return (method = "POST", url = url, headers = headers, body = message)
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

Convert `value` to a base URL string, defaulting to `https://ntfy.sh` when `nothing` is
provided.
"""
normalise_base_url(::Nothing) = DEFAULT_BASE_URL
normalise_base_url(::Any) = error("Unsupported base_url type")
function normalise_base_url(url::AbstractString)
    url_str = convert(String, url)
    return isempty(url_str) ? error("base_url cannot be empty") : String(rstrip(url_str, '/'))
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

function build_url(base_url::AbstractString, topic::AbstractString)
    stripped = rstrip(base_url, '/')
    return string(stripped, "/", lstrip(topic, '/'))
end

end # module
