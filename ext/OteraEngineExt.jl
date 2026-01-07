module OteraEngineExt

using Ntfy
using OteraEngine
using Printf

include(joinpath(@__DIR__, "..", "src", "templating.jl"))

"""
    template_view(info)

Return a template view containing the standard ntfy substitution values.
"""
function template_view(info)
    view = Dict{Symbol,Any}()
    for key in TEMPLATE_KEYS
        view[key] = template_value(key, info)
    end
    return view
end

"""
    Ntfy.render_template(template::OteraEngine.Template, info)

Render an OteraEngine template using the standard ntfy substitution values.
"""
function Ntfy.render_template(template::OteraEngine.Template, info)
    return template(init=template_view(info))
end

end
