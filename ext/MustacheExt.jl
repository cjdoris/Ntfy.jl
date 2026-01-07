module MustacheExt

using Mustache
using Ntfy
using Printf

include(joinpath(@__DIR__, "..", "src", "templating.jl"))

"""
    Ntfy.render_template(template::Mustache.MustacheTokens, info)

Render a Mustache template using the standard ntfy substitution values.
"""
function Ntfy.render_template(template::Mustache.MustacheTokens, info)
    view = Dict{String,Any}()
    for key in TEMPLATE_KEYS
        key_string = String(key)
        if key === :is_error
            view[key_string] = template_value(key, info)
        else
            view[key_string] = () -> template_value(key, info)
        end
    end
    return Mustache.render(template, view)
end

end
