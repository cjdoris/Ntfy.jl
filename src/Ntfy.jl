module Ntfy

using Downloads

export ntfy

const NTFY_BASE = "https://ntfy.sh/"

"""
    ntfy_request(topic, message; base_url=NTFY_BASE, priority=nothing, title=nothing,
                 tags=nothing, click=nothing, attach=nothing, actions=nothing,
                 email=nothing)

Construct the arguments required by `Downloads.request` to publish `message` to
the given `topic` on the ntfy service. Optional keyword arguments map to the
respective ntfy headers when provided. Values that are `nothing` are omitted.
Returns a named tuple with `method`, `url`, `headers`, and `body` keys.
"""

function ntfy_request(topic::AbstractString, message::AbstractString;
                      base_url::AbstractString=NTFY_BASE,
                      priority::Union{Nothing,AbstractString}=nothing,
                      title::Union{Nothing,AbstractString}=nothing,
                      tags::Union{Nothing,AbstractString,AbstractVector{<:AbstractString}}=nothing,
                      click::Union{Nothing,AbstractString}=nothing,
                      attach::Union{Nothing,AbstractString}=nothing,
                      actions::Union{Nothing,AbstractString,AbstractVector{<:AbstractString}}=nothing,
                      email::Union{Nothing,AbstractString}=nothing)
    base = String(base_url)
    url = endswith(base, "/") ? string(base, topic) : string(base, "/", topic)

    headers = Pair{String,String}[]
    if !isnothing(priority)
        push!(headers, "Priority" => _stringify_header_value(priority))
    end
    if !isnothing(title)
        push!(headers, "Title" => _stringify_header_value(title))
    end
    if !isnothing(tags)
        tag_value = tags isa AbstractVector ? join(tags, ",") : tags
        push!(headers, "Tags" => _stringify_header_value(tag_value))
    end
    if !isnothing(click)
        push!(headers, "Click" => _stringify_header_value(click))
    end
    if !isnothing(attach)
        push!(headers, "Attach" => _stringify_header_value(attach))
    end
    if !isnothing(actions)
        action_value = actions isa AbstractVector ? join(actions, "; ") : actions
        push!(headers, "Actions" => _stringify_header_value(action_value))
    end
    if !isnothing(email)
        push!(headers, "Email" => _stringify_header_value(email))
    end

    return (method = "POST", url = url, headers = headers, body = message)
end

function _stringify_header_value(value)
    return value isa AbstractString ? String(value) : string(value)
end

"""
    ntfy(topic, message; kwargs...)

Publish a `message` to `topic` on ntfy using the supplied keyword options (see
`ntfy_request`, including `base_url` to override the host). Raises an error if
the response status is not a successful 2xx code. Returns the response from
`Downloads.request`.
"""
function ntfy(topic::AbstractString, message::AbstractString; kwargs...)
    req = ntfy_request(topic, message; kwargs...)
    response = Downloads.request(req.method, req.url; headers=req.headers, body=req.body)
    if !hasproperty(response, :status)
        error("Unexpected response from ntfy request")
    end
    if response.status < 200 || response.status >= 300
        error("ntfy request failed with status $(response.status)")
    end
    return response
end

end
