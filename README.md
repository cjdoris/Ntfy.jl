# Ntfy.jl

Ntfy.jl is a lightweight Julia client for [ntfy.sh](https://ntfy.sh), letting you publish notifications via HTTP.

## Installation

```
julia> ] add https://github.com/example/Ntfy.jl
```

## Usage

```julia
using Ntfy
using Markdown

# Send a basic notification
ntfy("mytopic", "Backup successful 😀")

# Send with headers supported by ntfy.sh
ntfy(
    "phil_alerts",
    "Remote access detected. Act right away.";
    priority = "urgent",
    title = "Unauthorized access detected",
    tags = ["warning", "skull"],
    delay = "tomorrow, 10am",
    markdown = true,
    auth = ("phil", "supersecret"),
)

# Send Markdown content directly
ntfy("release_notes", md"## v1.0.1\n- Added ntfy Markdown helper"; priority = 3)
```

## API

### `ntfy(topic, message; kwargs...)`
Send a notification to `topic` with the given `message`. Optional keyword arguments map to ntfy.sh headers:

- `priority`: Priority string or integer.
- `title`: Notification title.
- `tags`: Comma-separated string or vector of tags.
- `click`: URL to open when the notification is clicked.
- `attach`: URL of an attachment.
- `actions`: Actions definition string or vector (e.g. HTTP action buttons). When provided as a
  vector, each entry is treated as a separate action definition and combined with semicolons in
  the `X-Actions` header.
- `email`: Forward notification to an email address.
- `delay`: Delivery time string (sent as the `X-Delay` header) to schedule a notification (e.g. `"30m"`, `"tomorrow, 10am"`).
- `markdown`: Set to `true` to enable Markdown rendering in supported clients.
- `extra_headers`: Additional headers as a vector of pairs or dictionary.
- `base_url`: Alternative base server URL. When omitted, `ntfy` checks the
  `base_url` package preference (see [Preferences.jl](https://github.com/JuliaPackaging/Preferences.jl))
  or the `JULIA_NTFY_BASE_URL` environment variable before falling back to
  `https://ntfy.sh`.
- `auth`: Optional authentication. Provide a string for a literal `Authorization`
  header value, a 2-tuple `(username, password)` for [Basic auth](https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication#basic_authentication),
  or a 1-tuple `(token,)` for Bearer tokens.

Raises an error if the server does not return a 2xx response. Returns nothing on success.

### `ntfy(topic, message::Markdown.MD; markdown=true, kwargs...)`

When you pass a `Markdown.MD` value, the Markdown package extension converts the
markdown document to a string and forwards it to `ntfy`. The `markdown`
keyword defaults to `true` to enable rendering in supported ntfy clients, and
all other keyword arguments are passed through unchanged.

