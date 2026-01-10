# Ntfy.jl

[![Project Status: Active – The project has reached a stable, usable state and is being actively developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![Test Status](https://github.com/cjdoris/Ntfy.jl/actions/workflows/tests.yml/badge.svg)](https://github.com/cjdoris/Ntfy.jl/actions/workflows/tests.yml)
[![Codecov](https://codecov.io/gh/cjdoris/Ntfy.jl/branch/main/graph/badge.svg?token=1flP5128hZ)](https://codecov.io/gh/cjdoris/Ntfy.jl)

Ntfy.jl is a lightweight Julia client for [ntfy.sh](https://ntfy.sh), letting you
publish notifications via HTTP.

## Installation

```
pkg> add https://github.com/cjdoris/Ntfy.jl
```

## Example usage

```julia
using Ntfy

# Send a basic notification
ntfy("mytopic", "Backup successful 😀")

# Send with more formatting, time delay and password
ntfy(
    "phil_alerts",
    "Remote access detected. Act right away.";
    priority = "urgent",
    title = "Unauthorized access detected",
    tags = ["warning", "skull"],
    delay = "tomorrow, 10am",
    auth = ("phil", "supersecret"),
)

# Send Markdown content directly
using Markdown
ntfy("release_notes", md"## v1.0.1\n- Added ntfy Markdown helper"; priority=3)

# Forward log records to ntfy
using Logging
logger = NtfyLogger(topic="service_logs", title="service")
with_logger(logger) do
    @info "Started background job" job_id=123
end
```

## API

### `ntfy(topic, message; ...)`

Publish a notification to `topic` with `message` via the `ntfy.sh` service.

#### Keyword Arguments
- `priority`: The priority, as a string or integer (1-5).
- `title`: The title, as a string.
- `tags`: The tag/tags, as a string or vector of strings.
- `click`: The action to take when clicked, as a string.
- `attach`: URL of an attachment, as a string.
- `actions`: Action button/buttons, as a string, a list of strings, or tuple
  expressions like `:(view, "Open portal", "https://...", clear=true)`.
- `email`: Email address to also notify, as a string.
- `delay`: Specify a time in the future to send the notification, as a string or `DateTime` or `Period`.
- `markdown`: Set to `true` if the `message` is markdown-formatted, for richer display.
- `extra_headers`: Extra headers to send to `ntfy.sh`.
- `base_url`: Alternative server URL.
- `auth`: Authorisation credentials, either a token (as a string) or a username and password (tuple of two strings).
- `nothrow`: Set to `true` to suppress any exceptions and instead log a warning message.
  Useful to prevent a long-running script from failing just because `ntfy.sh` is down,
  for example.

### `NtfyLogger(topic=nothing, min_level=Info; ...)`

Create a `Logging.AbstractLogger` that forwards log messages to ntfy. Set it as
the active logger with `with_logger` or `global_logger` and use ordinary logging
macros like `@info`.

The logger accepts the same keyword arguments as `ntfy`, along with `message` and
`enabled`. Log-time keyword arguments prefixed with `ntfy_` override fields on the
logger, and `ntfy=true/false` overrides the `enabled` setting.

### Configuration

Keyword arguments take precendence, but some default values can be configured via
preferences (in the sense of [Preferences.jl](https://github.com/JuliaPackaging/Preferences.jl))
or environment variables.

`base_url`: This is `https://ntfy.sh` by default but can be set with the
`base_url` preference or the `NTFY_BASE_URL` environment variable.

`auth`: By default no auth is used, but can be set with one of:
- Auth token: `token` preference or `NTFY_TOKEN` environment variable.
- Username & password: `user` and `password` preferences or `NTFY_USER` and
  `NTFY_PASSWORD` environment variables.

### Extensions

[Markdown.jl](https://docs.julialang.org/en/v1/stdlib/Markdown/):
The `message` can also be a `md"..."` string, in which case `markdown=true` is set
automatically.

[Dates.jl](https://docs.julialang.org/en/v1/stdlib/Dates/):
The `delay` can be a `DateTime`, `Date`, `Second`, `Minute`, `Hour` or `Day`.
