module Ntfy

using Downloads

export ntfy

const NTFY_BASE = "https://ntfy.sh/"

"""
    ntfy_request(topic, message; priority=nothing, title=nothing, tags=nothing,
                 click=nothing, attach=nothing, actions=nothing, email=nothing)

Construct the arguments required by `Downloads.request` to publish `message` to
the given `topic` on the ntfy.sh service. Optional keyword arguments map to the
respective ntfy headers when provided. Values that are `nothing` are omitted.
Returns a named tuple with `method`, `url`, `headers`, and `body` keys.
"""

function ntfy_request(topic::AbstractString, message::AbstractString;
                      priority::Union{Nothing,AbstractString}=nothing,
                      title::Union{Nothing,AbstractString}=nothing,
                      tags::Union{Nothing,AbstractString,AbstractVector{<:AbstractString}}=nothing,
                      click::Union{Nothing,AbstractString}=nothing,
                      attach::Union{Nothing,AbstractString}=nothing,
                      actions::Union{Nothing,AbstractString,AbstractVector{<:AbstractString}}=nothing,
                      email::Union{Nothing,AbstractString}=nothing)
    url = endswith(NTFY_BASE, "/") ? string(NTFY_BASE, topic) : string(NTFY_BASE, "/", topic)

    headers = Pair{String,String}[]
    push_header!(name, value) = isnothing(value) || push!(headers, name => _stringify_header_value(value))

    push_header!("Priority", priority)
    push_header!("Title", title)
    push_header!("Tags", tags isa AbstractVector ? join(tags, ",") : tags)
    push_header!("Click", click)
    push_header!("Attach", attach)
    push_header!("Actions", actions isa AbstractVector ? join(actions, "; ") : actions)
    push_header!("Email", email)

    return (method = "POST", url = url, headers = headers, body = message)
end

function _stringify_header_value(value)
    return value isa AbstractString ? String(value) : string(value)
end

"""
    ntfy(topic, message; kwargs...)

Publish a `message` to `topic` on ntfy.sh using the supplied keyword options. See
`ntfy_request` for supported keywords. Raises an error if the response status is
not a successful 2xx code. Returns the response from `Downloads.request`.
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
