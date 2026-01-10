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

function request(::RequestHandler, req)
    response = Downloads.request(req.url; method=req.method, headers=req.headers, input=IOBuffer(req.body))
    return response.status, response.message
end

function request(handler::DummyRequestHandler, req)
    push!(handler.requests, req)
    return handler.status, handler.body
end
