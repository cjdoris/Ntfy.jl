# Agent Notes
- This repository implements the `Ntfy` Julia package for the ntfy.sh notification service.
- The public API exports only `ntfy`; keep helper types like `DummyTopic` internal (unexported and not documented in the README).
- Tests must never perform real network requests. Use `DummyTopic` with `ntfy` to capture requests instead of sending them; set its `status` field to exercise success and error paths.
- Keep this file up to date with any new design decisions or instructions provided in future tasks so that later agents can follow them.
- Use ntfy's official `X-` prefixed headers (e.g., `X-Title`, `X-Priority`) when constructing requests.
- Run tests with `julia --project=. -e 'using Pkg; Pkg.test()'.
