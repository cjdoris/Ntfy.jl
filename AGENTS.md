# Agent Notes
- This repository implements the `Ntfy` Julia package for the ntfy.sh notification service.
- The public API exports only `ntfy`; keep helper types like `DummyRequestHandler` internal (unexported and not documented in the README).
- Tests must never perform real network requests. Use `DummyRequestHandler` with `ntfy` to capture requests instead of sending them, even in tests that are expected to throw; set its `status` and `body` fields to exercise success and error paths.
- Keep this file up to date with any new design decisions or instructions provided in future tasks so that later agents can follow them.
- Use ntfy's official `X-` prefixed headers (e.g., `X-Title`, `X-Priority`) when constructing requests.
- Run tests with `julia --project=. -e 'using Pkg; Pkg.test()'.
- Ensure any new functions have docstrings, including internal helpers.
- After tests pass, rerun them with coverage enabled using `julia --project=. -e 'using Pkg; Pkg.test(coverage=true)'`. When
  editing code, add tests that aim for full coverage of the modified lines. If full coverage isn't practical, explain any
  remaining uncovered lines and why in the final report.
- The `ntfy(f::Function, ...)` helper supports `error_` keyword variants and function-valued notification arguments to tailor
  success/error notifications without templating the function return values.
