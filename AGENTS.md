# Agent Notes

- This repository implements the `Ntfy` Julia package for the ntfy.sh notification service.
- The public API exports only `ntfy`; `ntfy_request` is an internal helper and must remain unexported and undocumentated for end users.
- Tests must never perform real network requests. The current suite only exercises `ntfy_request` and should continue to avoid calling `ntfy`.
- Keep this file up to date with any new design decisions or instructions provided in future tasks so that later agents can follow them.
