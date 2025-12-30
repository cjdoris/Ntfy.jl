module MarkdownExt

using Markdown
using Ntfy

function Ntfy.ntfy(topic, message::Markdown.MD; markdown=true, kwargs...)
    return Ntfy.ntfy(topic, string(message); markdown=markdown, kwargs...)
end

end
