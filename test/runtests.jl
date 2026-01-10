using Test
using Dates
using Downloads
using Markdown
using Preferences
using Base64
using Logging
using Ntfy

ENV["JULIA_PREFERENCES_PATH"] = mktempdir()
Preferences.delete_preferences!(Ntfy, "token", "user", "password"; force = true, block_inheritance = true)
pop!(ENV, "NTFY_TOKEN", nothing)
pop!(ENV, "NTFY_USER", nothing)
pop!(ENV, "NTFY_PASSWORD", nothing)

"""
    dummy_ntfy(args...; kwargs...)

Call `Ntfy.ntfy` with a fresh `DummyRequestHandler` and return the single recorded
request.
"""
function dummy_ntfy(args...; kwargs...)
    handler = Ntfy.DummyRequestHandler()
    Ntfy.ntfy(args...; kwargs..., request_handler=handler)
    return only(handler.requests)
end

"""
    with_dummy_ntfy_logger(f; topic=nothing, min_level=Logging.Info, kwargs...)

Create a `NtfyLogger` and `DummyRequestHandler`, run `f` with the logger, and
return the captured request.
"""
function with_dummy_ntfy_logger(f; topic=nothing, min_level=Logging.Info, kwargs...)
    handler = Ntfy.DummyRequestHandler()
    logger = Ntfy.NtfyLogger(topic, min_level; kwargs..., request_handler=handler)
    with_logger(f, logger)
    return only(handler.requests)
end

@testset "ntfy" begin
    @testset "defaults" begin
        req = dummy_ntfy("mytopic", "Backup successful 😀")
        @test req.method == "POST"
        @test req.url == "https://ntfy.sh/mytopic"
        @test req.headers == Pair{String,String}[]
        @test req.body == "Backup successful 😀"
    end

    @testset "auth" begin
        req = dummy_ntfy("secrets", "payload"; auth = "Custom")
        @test req.headers == ["Authorization" => "Bearer Custom"]

        req = dummy_ntfy("secrets", "payload"; auth = ("user", "pass"))
        encoded = Base64.base64encode("user:pass")
        @test req.headers == ["Authorization" => "Basic $(encoded)"]

        req = dummy_ntfy(
            "secrets",
            "payload";
            auth = ("user", "pass"),
            extra_headers = Dict("X-Test" => "yes"),
            priority = "high",
        )
        encoded = Base64.base64encode("user:pass")
        @test req.headers == [
            "X-Priority" => "high",
            "Authorization" => "Basic $(encoded)",
            "X-Test" => "yes",
        ]

        @test_throws ErrorException dummy_ntfy("secrets", "payload"; auth = 123)
        @test_throws ErrorException dummy_ntfy("secrets", "payload"; auth = ("token",))
        @test_throws ErrorException dummy_ntfy("secrets", "payload"; auth = ("too", "many", "values"))

        @testset "defaults from preferences" begin
            mktempdir() do prefs_path
                withenv("JULIA_PREFERENCES_PATH" => prefs_path) do
                    Preferences.set_preferences!(Ntfy, "token" => "pref-token"; force = true)

                    req = dummy_ntfy("defaults", "payload")
                    @test req.headers == ["Authorization" => "Bearer pref-token"]

                    Preferences.delete_preferences!(Ntfy, "token"; force = true, block_inheritance = true)
                    Preferences.set_preferences!(Ntfy, "user" => "pref-user", "password" => "pref-pass"; force = true)

                    req = dummy_ntfy("defaults", "payload")
                    encoded = Base64.base64encode("pref-user:pref-pass")
                    @test req.headers == ["Authorization" => "Basic $(encoded)"]

                    Preferences.delete_preferences!(Ntfy, "token", "user", "password"; force = true, block_inheritance = true)

                    withenv(
                        "NTFY_TOKEN" => "env-token",
                        "NTFY_USER" => "env-user",
                        "NTFY_PASSWORD" => "env-pass",
                    ) do
                        req = dummy_ntfy("defaults", "payload")
                        @test req.headers == ["Authorization" => "Bearer env-token"]
                    end
                end
            end
        end
    end

    @testset "headers" begin
        req = dummy_ntfy(
            "phil_alerts",
            "Remote access detected. Act right away.";
            priority = "urgent",
            title = "Unauthorized access detected",
            tags = ["warning", "skull"],
            click = "https://home.nest.com/",
            attach = "https://nest.com/view/yAxkasd.jpg",
            actions = [
                :(view, "Open portal", "https://home.nest.com/", clear=true),
                "http, Open door, https://api.nest.com/open/yAxkasd, method=PUT",
            ],
            email = "phil@example.com",
            delay = "tomorrow, 10am",
            extra_headers = Dict("X-Test" => "yes"),
        )
        expected_headers = [
            "X-Priority" => "urgent",
            "X-Title" => "Unauthorized access detected",
            "X-Tags" => "warning,skull",
            "X-Click" => "https://home.nest.com/",
            "X-Attach" => "https://nest.com/view/yAxkasd.jpg",
            "X-Actions" => "view, Open portal, https://home.nest.com/, clear=true; http, Open door, https://api.nest.com/open/yAxkasd, method=PUT",
            "X-Email" => "phil@example.com",
            "X-Delay" => "tomorrow, 10am",
            "X-Test" => "yes",
        ]
        @test req.headers == expected_headers
    end

    @testset "markdown disabled" begin
        req = dummy_ntfy("dummy-topic", "msg"; markdown = false)
        @test req.headers == Pair{String,String}[]
    end

    @testset "base url" begin
        req = dummy_ntfy("dummy-topic", "hi"; base_url = "https://example.com/", title = "unused")
        @test req.url == "https://example.com/dummy-topic"

        @testset "from preference" begin
            mktempdir() do prefs_path
                withenv(
                    "JULIA_PREFERENCES_PATH" => prefs_path,
                    "NTFY_BASE_URL" => "https://env.example/",
                ) do
                    Preferences.set_preferences!(Ntfy, "base_url" => "https://prefs.example/"; force = true)

                    pref_req = dummy_ntfy("pref-topic", "hi"; title = "unused")
                    @test pref_req.url == "https://prefs.example/pref-topic"
                end
            end
        end

        @testset "from env" begin
            mktempdir() do prefs_path
                withenv(
                    "JULIA_PREFERENCES_PATH" => prefs_path,
                    "NTFY_BASE_URL" => "https://env.example/",
                ) do
                    Preferences.delete_preferences!(Ntfy, Ntfy.BASE_URL_PREFERENCE; force = true, block_inheritance = true)
                    env_req = dummy_ntfy("env-topic", "hi"; title = "unused")
                    @test env_req.url == "https://env.example/env-topic"
                end
            end
        end
    end

    @testset "extra headers vector" begin
        req = dummy_ntfy("dummy-topic", "msg"; extra_headers = ["X-One" => "1", "X-Two" => "2"])
        @test req.headers == ["X-One" => "1", "X-Two" => "2"]
    end

    @testset "delay" begin
        req = dummy_ntfy("reminders", "Drink water"; delay = "30m")
        @test req.headers == ["X-Delay" => "30m"]
    end

    @testset "delay dates extension" begin
        dt = DateTime(2024, 1, 2, 3, 4, 5)
        req = dummy_ntfy("reminders", "time"; delay = dt)
        @test req.headers == ["X-Delay" => string(floor(Int, Dates.datetime2unix(dt)))]

        date = Date(2024, 1, 2)
        req = dummy_ntfy("reminders", "date"; delay = date)
        @test req.headers == ["X-Delay" => string(floor(Int, Dates.datetime2unix(DateTime(date))))]

        req = dummy_ntfy("reminders", "seconds"; delay = Second(5))
        @test req.headers == ["X-Delay" => "5 seconds"]

        req = dummy_ntfy("reminders", "minutes"; delay = Minute(1))
        @test req.headers == ["X-Delay" => "1 minute"]

        req = dummy_ntfy("reminders", "hours"; delay = Hour(2))
        @test req.headers == ["X-Delay" => "2 hours"]

        @test_throws ErrorException dummy_ntfy("reminders", "weeks"; delay = Week(1))

        req = dummy_ntfy("reminders", "days"; delay = Day(1))
        @test req.headers == ["X-Delay" => "1 day"]
    end

    @testset "invalid types" begin
        @test_throws ErrorException dummy_ntfy(123, "msg")
        @test_throws ErrorException dummy_ntfy("topic", 456)
        @test_throws ErrorException dummy_ntfy("topic", "msg"; extra_headers = ["bad"])
        @test_throws ErrorException dummy_ntfy("topic", "msg"; base_url = 123)
        @test_throws ErrorException dummy_ntfy("topic", "msg"; delay = "")
        @test_throws ErrorException dummy_ntfy("topic", "msg"; delay = 123)
        @test_throws ErrorException dummy_ntfy("topic", "msg"; markdown = "yes")
    end

    @testset "handle helpers" begin
        headers = Pair{String,String}[]
        @test Ntfy.handle_priority!(copy(headers), nothing) == headers
        @test Ntfy.handle_priority!(copy(headers), 5) == ["X-Priority" => "5"]
        @test_throws ErrorException Ntfy.handle_priority!(headers, 3.14)

        @test Ntfy.handle_title!(copy(headers), :mytitle) == ["X-Title" => "mytitle"]
        @test_throws ErrorException Ntfy.handle_title!(headers, 123)

        @test Ntfy.handle_tags!(copy(headers), "alpha,beta") == ["X-Tags" => "alpha,beta"]
        @test Ntfy.handle_tags!(copy(headers), ["alpha", "beta"]) == ["X-Tags" => "alpha,beta"]
        @test_throws ErrorException Ntfy.handle_tags!(headers, 1)

        @test Ntfy.handle_click!(copy(headers), "https://example.com") == ["X-Click" => "https://example.com"]
        @test_throws ErrorException Ntfy.handle_click!(headers, 100)

        @test Ntfy.handle_attach!(copy(headers), "https://example.com/file.txt") == ["X-Attach" => "https://example.com/file.txt"]
        @test_throws ErrorException Ntfy.handle_attach!(headers, Any[])

        @test Ntfy.handle_actions!(copy(headers), "view, Open") == ["X-Actions" => "view, Open"]
        @test Ntfy.handle_actions!(copy(headers), ["view, Open", "dismiss"]) == ["X-Actions" => "view, Open; dismiss"]
        @test Ntfy.handle_actions!(copy(headers), (:view, "Open")) == ["X-Actions" => "view, Open"]
        @test Ntfy.handle_actions!(copy(headers), :(view, "Open portal", "https://example.com", clear=true)) ==
            ["X-Actions" => "view, Open portal, https://example.com, clear=true"]
        @test Ntfy.handle_actions!(copy(headers), :(view, "It's good, ok")) ==
            ["X-Actions" => "view, \"It's good, ok\""]
        @test Ntfy.handle_actions!(copy(headers), :(http, "Turn, down", "https://api", body="{\"temperature\": 65}")) ==
            ["X-Actions" => "http, 'Turn, down', https://api, body='{\"temperature\": 65}'"]
        @test Ntfy.handle_actions!(copy(headers), :(http, "Do", "https://api", headers=(foo=bar, baz=true))) ==
            ["X-Actions" => "http, Do, https://api, headers.foo=bar, headers.baz=true"]
        @test Ntfy.handle_actions!(copy(headers), Expr(:tuple, :view, Expr(:(=), "header", "value"))) ==
            ["X-Actions" => "view, header=value"]
        @test_throws ErrorException Ntfy.format_action(123)
        @test_throws ErrorException Ntfy.handle_actions!(headers, :(view, "He said \"hi\" and it's ok"))
        @test_throws ErrorException Ntfy.handle_actions!(headers, Expr(:tuple, :view, Expr(:(=), 1, "value")))
        @test_throws ErrorException Ntfy.handle_actions!(headers, Expr(:tuple, :view, Expr(:(=), :data, Expr(:tuple, 1, 2))))
        @test_throws ErrorException Ntfy.handle_actions!(headers, 42)

        @test_throws ErrorException Ntfy.handle_email!(headers, 123)

        @test Ntfy.handle_extra_headers!(copy(headers), Dict("X-Custom" => "1")) == ["X-Custom" => "1"]
        @test_throws ErrorException Ntfy.handle_extra_headers!(headers, 42)
    end

    @testset "request handler" begin
        struct FakeURL end
        struct FakeResponse
            status::Int
            message::String
        end

        Downloads.request(::FakeURL; method, headers, input) = FakeResponse(202, "accepted")

        req = (method = "POST", url = FakeURL(), headers = Pair{String,String}[], body = "payload")
        status, message = Ntfy.request(Ntfy.RequestHandler(), req)
        @test status == 202
        @test message == "accepted"
    end

    @testset "error status" begin
        handler = Ntfy.DummyRequestHandler(status = 500)
        @test_throws ErrorException Ntfy.ntfy("dummy-topic", "boom"; request_handler=handler)
        @test length(handler.requests) == 1
    end

    @testset "markdown extension" begin
        msg = md"**bold** text"
        req = dummy_ntfy("markdown-topic", msg)
        @test req.body == string(msg)
        @test Dict(req.headers)["X-Markdown"] == "yes"

        msg = md"plain"
        req = dummy_ntfy("markdown-topic", msg; markdown=false, title="ignored")
        @test req.body == string(msg)
        @test !haskey(Dict(req.headers), "X-Markdown")
    end
end

@testset "logging" begin
    req = with_dummy_ntfy_logger(topic="log-topic") do
        @info "hello world" foo=1
    end
    @test req.url == "https://ntfy.sh/log-topic"
    @test occursin("hello world", req.body)
    @test occursin("foo", req.body)
    @test !occursin("ntfy_topic", req.body)

    req = with_dummy_ntfy_logger(topic="base-topic", message=info -> "logger $(info.message)") do
        @info "hi" foo=2 ntfy_topic="override-topic" ntfy_title=info -> "title $(info.kwargs.foo)"
    end
    @test req.url == "https://ntfy.sh/override-topic"
    @test req.body == "logger hi"
    @test Dict(req.headers)["X-Title"] == "title 2"

    req = with_dummy_ntfy_logger(topic="base-topic", message="base message") do
        @info "ignored" ntfy_message="override message"
    end
    @test req.body == "override message"

    handler = Ntfy.DummyRequestHandler(status = 500)
    backup_io = IOBuffer()
    backup_logger = Logging.SimpleLogger(backup_io, Logging.Info)
    logger = Ntfy.NtfyLogger(
        "log-topic";
        request_handler=handler,
        nothrow=true,
        backup_logger=backup_logger,
    )
    with_logger(logger) do
        @info "hello backup"
    end
    @test length(handler.requests) == 1
    backup_output = String(take!(backup_io))
    @test occursin("ntfy() failed", backup_output)
    @test !occursin("hello backup", backup_output)

    handler = Ntfy.DummyRequestHandler()
    logger = Ntfy.NtfyLogger("disabled-topic"; enabled=false, request_handler=handler)
    with_logger(logger) do
        @info "skip" ntfy=false
    end
    @test isempty(handler.requests)

    req = with_dummy_ntfy_logger(; topic="disabled-topic", enabled=false) do
        @info "send" ntfy=true
    end
    @test req.url == "https://ntfy.sh/disabled-topic"

    handler = Ntfy.DummyRequestHandler()
    logger = Ntfy.NtfyLogger(nothing; enabled=true, request_handler=handler)
    @test Logging.shouldlog(logger, Logging.Info, @__MODULE__, :group, :id)
    @test_throws ErrorException Logging.handle_message(
        logger,
        Logging.Info,
        "missing topic",
        @__MODULE__,
        :group,
        :id,
        "file",
        1,
    )
end

@testset "nothrow" begin
    handler = Ntfy.DummyRequestHandler(status = 500)
    @test_logs (:warn, r"ntfy\(\) failed") Ntfy.ntfy("dummy-topic", "boom"; request_handler = handler, nothrow = true)
    @test length(handler.requests) == 1

    handler = Ntfy.DummyRequestHandler()
    result = @test_logs (:warn, r"ntfy\(\) failed") Ntfy.ntfy(123, "bad topic"; request_handler = handler, nothrow = true)
    @test result === nothing
    @test isempty(handler.requests)

    handler = Ntfy.DummyRequestHandler()
    result = @test_logs (:warn, r"ntfy\(\) failed") Ntfy.ntfy("dummy-topic", 123; request_handler = handler, nothrow = true)
    @test result === nothing
    @test isempty(handler.requests)
end
