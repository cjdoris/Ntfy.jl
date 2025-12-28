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
- `extra_headers`: Additional headers as a vector of pairs or dictionary.
- `base_url`: Alternative base server URL (defaults to `https://ntfy.sh`).

Raises an error if the server does not return a 2xx response. Returns the `Downloads.Response` object on success.

### `ntfy_request(topic, message; kwargs...)`
Internal helper that prepares the HTTP request. It returns a named tuple containing the HTTP method, URL, headers, and body without issuing any network calls. Accepts the same keywords as `ntfy`.
