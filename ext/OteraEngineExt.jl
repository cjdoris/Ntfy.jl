module OteraEngineExt

using Ntfy
using OteraEngine
using Printf

include(joinpath(@__DIR__, "..", "src", "templating.jl"))

"""
    Ntfy.render_template(template::OteraEngine.Template, info)

Render an OteraEngine template using the standard ntfy substitution values.
"""
function Ntfy.render_template(template::OteraEngine.Template, info)
    view = Dict{Symbol,Any}()
    for key in template.args
        view[key] = template_value(key, info)
    end
    return template(init=view)
end

end
