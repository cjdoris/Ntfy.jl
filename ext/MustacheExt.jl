module MustacheExt

using Mustache
using Ntfy

"""
    Ntfy.render_template(template::Mustache.MustacheTokens, info)

Render a Mustache template using the standard ntfy substitution values.
"""
function Ntfy.render_template(template::Mustache.MustacheTokens, info)
    return Mustache.render(template, Ntfy.template_view(info))
end

end
