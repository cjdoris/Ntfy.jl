module MustacheExt

using Mustache
using Ntfy
using Printf

include(joinpath(@__DIR__, "..", "src", "templating.jl"))

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
    for key in TEMPLATE_KEYS
        if key === :is_error
            add_key!(String(key), template_value(key, info))
        else
            add_key!(String(key), () -> template_value(key, info))
        end
    end
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
