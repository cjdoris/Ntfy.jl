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
  or the `NTFY_BASE_URL` environment variable before falling back to
  `https://ntfy.sh`.
- `auth`: Optional authentication. Provide a 2-tuple `(username, password)` for
  Basic auth, or a string token for Bearer authentication. When omitted, `ntfy`
  checks the `token`, `user`, and `password` preferences (or the environment
  variables `NTFY_TOKEN`, `NTFY_USER`, `NTFY_PASSWORD`) to build the
  `Authorization` header.
- `nothrow`: When set to `true`, suppress errors raised while sending the notification and log a warning instead.

Raises an error if the server does not return a 2xx response (unless `nothrow=true`). Returns nothing on success.

### `ntfy(topic, message; kwargs...) do f end`

Execute `f()` and send a notification based on `message` on success or
`error_message` on failure. Any keyword arguments (including `nothrow`) are
forwarded to the inner `ntfy` call. This method returns the result of `f()` so
callers can continue using the computed value even when notifications are
best-effort.

## Extensions

Ntfy.jl exposes a few opt-in extensions that activate when the corresponding
packages are loaded.

- **Markdown**: Passing a `Markdown.MD` value converts the document to a string
  and forwards it to `ntfy`. The `markdown` keyword defaults to `true` so
  supported clients render the result.
- **Dates**: `delay` accepts `Date`, `DateTime`, and `Period` values from Dates
  and converts them into ntfy-compatible delay strings.
- **Mustache**: The Mustache.jl extension lets the `ntfy(topic, template) do f end`
  form accept `Mustache.MustacheTokens` (e.g. `mt"..."`) for the message or
  title. Available fields include `value`, `value_md`, `success`, `SUCCESS`,
  `Success`, `is_error`, and the time fields `time`, `time_ns`, `time_us`,
  `time_ms`, `time_s`, `time_m`, `time_h`, and `time_d`.
