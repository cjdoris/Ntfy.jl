module StringTemplatesExt

using Ntfy
using Printf
using StringTemplates

include(joinpath(@__DIR__, "..", "src", "templating.jl"))

"""
    Ntfy.render_template(template::StringTemplates.Template, info)

Render a StringTemplates template using the standard ntfy substitution values.
"""
function Ntfy.render_template(template::StringTemplates.Template, info)
    view = Dict{Symbol,Any}()
    for key in unique(StringTemplates.props(template))
        view[key] = template_value(key, info)
    end
    return StringTemplates.render(template, view)
end

end
