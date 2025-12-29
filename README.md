# Ntfy.jl

Ntfy.jl is a lightweight Julia client for [ntfy.sh](https://ntfy.sh), letting you publish notifications via HTTP.

## Installation

```
julia> ] add https://github.com/example/Ntfy.jl
```

## Usage

```julia
using Ntfy

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
)
```

## API

### `ntfy(topic, message; kwargs...)`
Send a notification to `topic` with the given `message`. Optional keyword arguments map to ntfy.sh headers:

- `priority`: Priority string or integer.
- `title`: Notification title.
- `tags`: Comma-separated string or vector of tags.
- `click`: URL to open when the notification is clicked.
- `attach`: URL of an attachment.
- `actions`: Actions definition string or vector (e.g. HTTP action buttons).
- `email`: Forward notification to an email address.
- `delay`: Delivery time string (sent as the `X-Delay` header) to schedule a notification (e.g. `"30m"`, `"tomorrow, 10am"`).
- `markdown`: Set to `true` to enable Markdown rendering in supported clients.
- `extra_headers`: Additional headers as a vector of pairs or dictionary.
- `base_url`: Alternative base server URL (defaults to `https://ntfy.sh`).

Raises an error if the server does not return a 2xx response. Returns the `Downloads.Response` object on success.

