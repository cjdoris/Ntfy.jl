# Ntfy.jl

Ntfy.jl is a tiny Julia client for publishing notifications to [ntfy.sh](https://ntfy.sh/).
It exposes a single function, `ntfy(topic, message; kwargs...)`, that mirrors the
HTTP headers supported in the examples below.

## Installation

Add the package directly from the repository directory:

```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
```

## API

```julia
ntfy(topic, message; priority=nothing, title=nothing, tags=nothing,
    click=nothing, attach=nothing, actions=nothing, email=nothing)
```

Keyword arguments correspond to the documented ntfy headers:

- `priority`: Notification priority (e.g. `"urgent"`).
- `title`: Notification title.
- `tags`: Comma-separated tag string or vector of tag strings.
- `click`: URL opened when the notification is tapped.
- `attach`: External attachment URL.
- `actions`: Action string or vector of action definitions; multiple actions are joined with `"; "`.
- `email`: Email address to forward the notification.

All keywords default to `nothing` and are omitted when not provided.

## Usage

```julia
using Ntfy

# Publish a basic notification
ntfy("mytopic", "Backup successful 😀")

# Publish a rich notification with headers
ntfy(
    "phil_alerts",
    "Remote access to phils-laptop detected. Act right away.";
    priority = "urgent",
    title = "Unauthorized access detected",
    tags = ["warning", "skull"],
    click = "https://home.nest.com/",
    attach = "https://nest.com/view/yAxkasd.jpg",
    actions = ["http, Open door, https://api.nest.com/open/yAxkasd, clear=true"],
    email = "phil@example.com",
)
```
