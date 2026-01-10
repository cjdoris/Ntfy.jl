"""
    NtfyLogger(topic=nothing, min_level=Info; kwargs...)

Logging backend that forwards log messages to `ntfy`. The logger sends messages
only when enabled, and supports the same keyword arguments as `ntfy`.

If `message` is left as `nothing`, the log record is rendered with
`SimpleLogger` and forwarded to ntfy. Log-time keyword arguments prefixed with
`ntfy_` override fields on the logger, and function-valued fields are called
with a named tuple of log metadata.
"""
struct NtfyLogger <: AbstractLogger
    topic::Any
    min_level::LogLevel
    message::Any
    enabled::Bool
    priority::Any
    title::Any
    tags::Any
    click::Any
    attach::Any
    actions::Any
    email::Any
    delay::Any
    markdown::Any
    extra_headers::Any
    base_url::Any
    auth::Any
    request_handler::Any
    backup_logger::AbstractLogger
    nothrow::Any
end

"""
    NtfyLogger(topic=nothing, min_level=Info; message=nothing, enabled=topic !== nothing, kwargs...)

Construct a new `NtfyLogger`, defaulting `enabled` to `true` when a topic is
provided. Remaining keyword arguments map to `ntfy` arguments. `backup_logger` is
used while the logger forwards messages to `ntfy`, preventing `ntfy` warnings
from being routed back into this logger.
"""
function NtfyLogger(topic=nothing, min_level=Logging.Info; message=nothing,
        enabled=topic !== nothing, priority=nothing, title=nothing, tags=nothing,
        click=nothing, attach=nothing, actions=nothing, email=nothing, delay=nothing,
        markdown=nothing, extra_headers=nothing, base_url=nothing, auth=nothing,
        request_handler=nothing, backup_logger=Logging.SimpleLogger(), nothrow=nothing)
    return NtfyLogger(topic, min_level, message, enabled, priority, title, tags,
        click, attach, actions, email, delay, markdown, extra_headers, base_url,
        auth, request_handler, backup_logger, nothrow)
end

"""
    filter_log_kwargs(kwargs)

Return keyword arguments excluding `ntfy` and `ntfy_`-prefixed overrides.
"""
function filter_log_kwargs(kwargs)
    return (; (key => value for (key, value) in kwargs
        if key != :ntfy && !startswith(String(key), "ntfy_"))...)
end

"""
    build_log_info(level, message, _module, group, id, file, line, kwargs)

Build the `info` named tuple passed to function-valued logger fields.
"""
function build_log_info(level, message, _module, group, id, file, line, kwargs)
    return (level=level, message=message, _module=_module, group=group, id=id, file=file, line=line, kwargs=kwargs)
end

"""
    resolve_log_value(value, info)

Return `value`, or call it with `info` when it is a function.
"""
resolve_log_value(value, info) = value isa Function ? value(info) : value

Logging.min_enabled_level(logger::NtfyLogger) = logger.min_level

Logging.shouldlog(::NtfyLogger, level, _module, group, id) = true

function Logging.handle_message(
        logger::NtfyLogger,
        level,
        message,
        _module,
        group,
        id,
        file,
        line;
        kwargs...)
    ntfy_override = get(kwargs, :ntfy, nothing)
    enabled = if ntfy_override === true
        true
    elseif ntfy_override === false
        false
    else
        logger.enabled
    end
    enabled || return nothing

    filtered_kwargs = filter_log_kwargs(kwargs)
    info = build_log_info(level, message, _module, group, id, file, line, filtered_kwargs)

    topic_value = get(kwargs, :ntfy_topic, logger.topic)
    resolved_topic = resolve_log_value(topic_value, info)
    resolved_topic === nothing && error("ntfy topic is required")

    message_value = get(kwargs, :ntfy_message, logger.message)
    resolved_message = resolve_log_value(message_value, info)
    if resolved_message === nothing
        io = IOBuffer()
        simple_logger = Logging.SimpleLogger(io, logger.min_level)
        Logging.handle_message(simple_logger, level, message, _module, group, id, file, line; filtered_kwargs...)
        resolved_message = String(take!(io))
    end

    resolved_title = resolve_log_value(get(kwargs, :ntfy_title, logger.title), info)
    resolved_tags = resolve_log_value(get(kwargs, :ntfy_tags, logger.tags), info)
    resolved_priority = resolve_log_value(get(kwargs, :ntfy_priority, logger.priority), info)
    resolved_click = resolve_log_value(get(kwargs, :ntfy_click, logger.click), info)
    resolved_attach = resolve_log_value(get(kwargs, :ntfy_attach, logger.attach), info)
    resolved_actions = resolve_log_value(get(kwargs, :ntfy_actions, logger.actions), info)
    resolved_email = resolve_log_value(get(kwargs, :ntfy_email, logger.email), info)
    resolved_delay = resolve_log_value(get(kwargs, :ntfy_delay, logger.delay), info)
    resolved_markdown = resolve_log_value(get(kwargs, :ntfy_markdown, logger.markdown), info)
    resolved_extra_headers = resolve_log_value(get(kwargs, :ntfy_extra_headers, logger.extra_headers), info)
    resolved_base_url = resolve_log_value(get(kwargs, :ntfy_base_url, logger.base_url), info)
    resolved_auth = resolve_log_value(get(kwargs, :ntfy_auth, logger.auth), info)
    resolved_request_handler = resolve_log_value(get(kwargs, :ntfy_request_handler, logger.request_handler), info)
    resolved_nothrow = resolve_log_value(get(kwargs, :ntfy_nothrow, logger.nothrow), info)
    resolved_nothrow = resolved_nothrow === nothing ? false : resolved_nothrow

    Logging.with_logger(logger.backup_logger) do
        ntfy(resolved_topic, resolved_message;
            title=resolved_title,
            tags=resolved_tags,
            priority=resolved_priority,
            click=resolved_click,
            attach=resolved_attach,
            actions=resolved_actions,
            email=resolved_email,
            delay=resolved_delay,
            markdown=resolved_markdown,
            extra_headers=resolved_extra_headers,
            base_url=resolved_base_url,
            auth=resolved_auth,
            request_handler=resolved_request_handler,
            nothrow=resolved_nothrow)
    end
    return nothing
end
