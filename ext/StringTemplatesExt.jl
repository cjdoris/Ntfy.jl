module StringTemplatesExt

using Ntfy
using Printf
using StringTemplates

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
    Ntfy.render_template(template::StringTemplates.Template, info)

Render a StringTemplates template using the standard ntfy substitution values.
"""
function Ntfy.render_template(template::StringTemplates.Template, info)
    return StringTemplates.render(template, template_view(info))
end

end
