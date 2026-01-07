using Test
using Dates
using Downloads
using Markdown
using Preferences
using Base64
using Ntfy

ENV["JULIA_PREFERENCES_PATH"] = mktempdir()
Preferences.delete_preferences!(Ntfy, "token", "user", "password"; force = true, block_inheritance = true)
pop!(ENV, "NTFY_TOKEN", nothing)
pop!(ENV, "NTFY_USER", nothing)
pop!(ENV, "NTFY_PASSWORD", nothing)

@testset "ntfy" begin
    @testset "defaults" begin
        handler = Ntfy.DummyRequestHandler()
        Ntfy.ntfy("mytopic", "Backup successful 😀"; request_handler=handler)
        req = only(handler.requests)
        @test req.method == "POST"
        @test req.url == "https://ntfy.sh/mytopic"
        @test req.headers == Pair{String,String}[]
        @test req.body == "Backup successful 😀"
    end

    @testset "auth" begin
        handler = Ntfy.DummyRequestHandler()
        Ntfy.ntfy("secrets", "payload"; auth = "Custom", request_handler = handler)
        req = only(handler.requests)
        @test req.headers == ["Authorization" => "Bearer Custom"]

        handler = Ntfy.DummyRequestHandler()
        Ntfy.ntfy("secrets", "payload"; auth = ("user", "pass"), request_handler = handler)
        req = only(handler.requests)
        encoded = Base64.base64encode("user:pass")
        @test req.headers == ["Authorization" => "Basic $(encoded)"]

        handler = Ntfy.DummyRequestHandler()
        Ntfy.ntfy(
            "secrets",
            "payload";
            auth = ("user", "pass"),
            extra_headers = Dict("X-Test" => "yes"),
            priority = "high",
            request_handler = handler,
        )
        req = only(handler.requests)
        encoded = Base64.base64encode("user:pass")
        @test req.headers == [
            "X-Priority" => "high",
            "Authorization" => "Basic $(encoded)",
            "X-Test" => "yes",
        ]

        @test_throws ErrorException Ntfy.ntfy("secrets", "payload"; auth = 123, request_handler = Ntfy.DummyRequestHandler())
        @test_throws ErrorException Ntfy.ntfy("secrets", "payload"; auth = ("token",), request_handler = Ntfy.DummyRequestHandler())
        @test_throws ErrorException Ntfy.ntfy("secrets", "payload"; auth = ("too", "many", "values"), request_handler = Ntfy.DummyRequestHandler())

        @testset "defaults from preferences" begin
            mktempdir() do prefs_path
                withenv("JULIA_PREFERENCES_PATH" => prefs_path) do
                    Preferences.set_preferences!(Ntfy, "token" => "pref-token"; force = true)

                    handler = Ntfy.DummyRequestHandler()
                    Ntfy.ntfy("defaults", "payload"; request_handler = handler)
                    req = only(handler.requests)
                    @test req.headers == ["Authorization" => "Bearer pref-token"]

                    Preferences.delete_preferences!(Ntfy, "token"; force = true, block_inheritance = true)
                    Preferences.set_preferences!(Ntfy, "user" => "pref-user", "password" => "pref-pass"; force = true)

                    handler = Ntfy.DummyRequestHandler()
                    Ntfy.ntfy("defaults", "payload"; request_handler = handler)
                    req = only(handler.requests)
                    encoded = Base64.base64encode("pref-user:pref-pass")
                    @test req.headers == ["Authorization" => "Basic $(encoded)"]

                    Preferences.delete_preferences!(Ntfy, "token", "user", "password"; force = true, block_inheritance = true)

                    withenv(
                        "NTFY_TOKEN" => "env-token",
                        "NTFY_USER" => "env-user",
                        "NTFY_PASSWORD" => "env-pass",
                    ) do
                        handler = Ntfy.DummyRequestHandler()
                        Ntfy.ntfy("defaults", "payload"; request_handler = handler)
                        req = only(handler.requests)
                        @test req.headers == ["Authorization" => "Bearer env-token"]
                    end
                end
            end
        end
    end

    @testset "headers" begin
        handler = Ntfy.DummyRequestHandler()
        Ntfy.ntfy(
            "phil_alerts",
            "Remote access detected. Act right away.";
            priority = "urgent",
            title = "Unauthorized access detected",
            tags = ["warning", "skull"],
            click = "https://home.nest.com/",
            attach = "https://nest.com/view/yAxkasd.jpg",
            actions = [
                "view, Open portal, https://home.nest.com/, clear=true",
                "http, Open door, https://api.nest.com/open/yAxkasd, method=PUT",
            ],
            email = "phil@example.com",
            delay = "tomorrow, 10am",
            extra_headers = Dict("X-Test" => "yes"),
            request_handler = handler,
        )
        req = only(handler.requests)
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
        handler = Ntfy.DummyRequestHandler()
        Ntfy.ntfy("dummy-topic", "msg"; markdown = false, request_handler=handler)
        req = only(handler.requests)
        @test req.headers == Pair{String,String}[]
    end

    @testset "base url" begin
        handler = Ntfy.DummyRequestHandler()
        Ntfy.ntfy("dummy-topic", "hi"; base_url = "https://example.com/", title = "unused", request_handler=handler)
        req = only(handler.requests)
        @test req.url == "https://example.com/dummy-topic"

        @testset "from preference" begin
            mktempdir() do prefs_path
                withenv(
                    "JULIA_PREFERENCES_PATH" => prefs_path,
                    "NTFY_BASE_URL" => "https://env.example/",
                ) do
                    Preferences.set_preferences!(Ntfy, "base_url" => "https://prefs.example/"; force = true)

                    handler = Ntfy.DummyRequestHandler()
                    Ntfy.ntfy("pref-topic", "hi"; title = "unused", request_handler=handler)
                    pref_req = only(handler.requests)
                    @test pref_req.url == "https://prefs.example/pref-topic"
                end
            end
        end

        @testset "from env" begin
            mktempdir() do prefs_path
                handler = Ntfy.DummyRequestHandler()
                withenv(
                    "JULIA_PREFERENCES_PATH" => prefs_path,
                    "NTFY_BASE_URL" => "https://env.example/",
                ) do
                    Preferences.delete_preferences!(Ntfy, Ntfy.BASE_URL_PREFERENCE; force = true, block_inheritance = true)
                    Ntfy.ntfy("env-topic", "hi"; title = "unused", request_handler=handler)
                end
                env_req = only(handler.requests)
                @test env_req.url == "https://env.example/env-topic"
            end
        end
    end

    @testset "extra headers vector" begin
        handler = Ntfy.DummyRequestHandler()
        Ntfy.ntfy("dummy-topic", "msg"; extra_headers = ["X-One" => "1", "X-Two" => "2"], request_handler=handler)
        req = only(handler.requests)
        @test req.headers == ["X-One" => "1", "X-Two" => "2"]
    end

    @testset "delay" begin
        handler = Ntfy.DummyRequestHandler()
        Ntfy.ntfy("reminders", "Drink water"; delay = "30m", request_handler=handler)
        req = only(handler.requests)
        @test req.headers == ["X-Delay" => "30m"]
    end

    @testset "delay dates extension" begin
        handler = Ntfy.DummyRequestHandler()
        dt = DateTime(2024, 1, 2, 3, 4, 5)
        Ntfy.ntfy("reminders", "time"; delay = dt, request_handler = handler)
        req = only(handler.requests)
        @test req.headers == ["X-Delay" => string(floor(Int, Dates.datetime2unix(dt)))]

        handler = Ntfy.DummyRequestHandler()
        date = Date(2024, 1, 2)
        Ntfy.ntfy("reminders", "date"; delay = date, request_handler = handler)
        req = only(handler.requests)
        @test req.headers == ["X-Delay" => string(floor(Int, Dates.datetime2unix(DateTime(date))))]

        handler = Ntfy.DummyRequestHandler()
        Ntfy.ntfy("reminders", "seconds"; delay = Second(5), request_handler = handler)
        req = only(handler.requests)
        @test req.headers == ["X-Delay" => "5 seconds"]

        handler = Ntfy.DummyRequestHandler()
        Ntfy.ntfy("reminders", "minutes"; delay = Minute(1), request_handler = handler)
        req = only(handler.requests)
        @test req.headers == ["X-Delay" => "1 minute"]

        handler = Ntfy.DummyRequestHandler()
        Ntfy.ntfy("reminders", "hours"; delay = Hour(2), request_handler = handler)
        req = only(handler.requests)
        @test req.headers == ["X-Delay" => "2 hours"]

        handler = Ntfy.DummyRequestHandler()
        @test_throws ErrorException Ntfy.ntfy("reminders", "weeks"; delay = Week(1), request_handler = handler)

        handler = Ntfy.DummyRequestHandler()
        Ntfy.ntfy("reminders", "days"; delay = Day(1), request_handler = handler)
        req = only(handler.requests)
        @test req.headers == ["X-Delay" => "1 day"]
    end

    @testset "invalid types" begin
        @test_throws ErrorException Ntfy.ntfy(123, "msg"; request_handler = Ntfy.DummyRequestHandler())
        @test_throws ErrorException Ntfy.ntfy("topic", 456; request_handler = Ntfy.DummyRequestHandler())
        @test_throws ErrorException Ntfy.ntfy("topic", "msg"; extra_headers = ["bad"], request_handler = Ntfy.DummyRequestHandler())
        @test_throws ErrorException Ntfy.ntfy("topic", "msg"; base_url = 123, request_handler = Ntfy.DummyRequestHandler())
        @test_throws ErrorException Ntfy.ntfy("topic", "msg"; delay = "", request_handler = Ntfy.DummyRequestHandler())
        @test_throws ErrorException Ntfy.ntfy("topic", "msg"; delay = 123, request_handler = Ntfy.DummyRequestHandler())
        @test_throws ErrorException Ntfy.ntfy("topic", "msg"; markdown = "yes", request_handler = Ntfy.DummyRequestHandler())
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
        @test_throws ErrorException Ntfy.handle_actions!(headers, 42)

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
        handler = Ntfy.DummyRequestHandler()
        msg = md"**bold** text"
        Ntfy.ntfy("markdown-topic", msg; request_handler=handler)
        req = only(handler.requests)
        @test req.body == string(msg)
        @test Dict(req.headers)["X-Markdown"] == "yes"

        handler = Ntfy.DummyRequestHandler()
        msg = md"plain"
        Ntfy.ntfy("markdown-topic", msg; markdown=false, title="ignored", request_handler=handler)
        req = only(handler.requests)
        @test req.body == string(msg)
        @test !haskey(Dict(req.headers), "X-Markdown")
    end
end

@testset "format_message" begin
    info = (value=42, is_error=false, time_ns=1_234_000_000)
    @test Ntfy.format_message("value: {{ value }}", info) == "value: 42"
    @test Ntfy.format_message("status: {{ success }} / {{ SUCCESS }} / {{ Success }}", info) ==
          "status: success / SUCCESS / Success"
    @test Ntfy.format_message("elapsed: {{ time_s }}", info) == "elapsed: 1.23"
    @test Ntfy.format_message("elapsed: {{ time }}", info) == "elapsed: 1.23 s"
    zero_info = (value=0, is_error=false, time_ns=0)
    @test Ntfy.format_message("elapsed: {{ time }}", zero_info) == "elapsed: 0 ns"

    err = ErrorException("boom")
    err_info = (value=err, is_error=true, time_ns=1200)
    @test occursin("boom", Ntfy.format_message("error: {{ value }}", err_info))
end

@testset "do-notation" begin
    handler = Ntfy.DummyRequestHandler()

    result = Ntfy.ntfy("dummy-topic", "result {{ value }} - {{ SUCCESS }}"; title = "overall {{ Success }}", request_handler=handler) do
        99
    end
    @test result === 99
    @test handler.requests[1].body == "result 99 - SUCCESS"
    @test Dict(handler.requests[1].headers)["X-Title"] == "overall Success"

    @test_throws ErrorException Ntfy.ntfy(
        "dummy-topic",
        "failing {{ success }}: {{ value }}";
        error_message = "failed {{ SUCCESS }}: {{ value }}",
        title = "failing {{ SUCCESS }}",
        error_title = "error {{ Success }}",
        error_priority = 5,
        error_tags = ["fire"],
        request_handler=handler,
    ) do
        error("kaboom")
    end
    @test endswith(handler.requests[end].body, "kaboom")
    @test Dict(handler.requests[end].headers)["X-Title"] == "error Error"
    @test Dict(handler.requests[end].headers)["X-Priority"] == "5"
    @test Dict(handler.requests[end].headers)["X-Tags"] == "fire"

    Ntfy.ntfy("dummy-topic", "no title formatting"; title = :unchanged, request_handler=handler) do
        :ok
    end
    @test Dict(handler.requests[end].headers)["X-Title"] == "unchanged"

    handler = Ntfy.DummyRequestHandler()
    result = Ntfy.ntfy(
        "dummy-topic",
        info -> "literal {{ value }}";
        title = info -> "title {{ Success }}",
        tags = info -> ["tag-$(info.value)"],
        priority = info -> 3,
        click = info -> "https://example.com/$(info.value)",
        attach = info -> "https://example.com/$(info.value).txt",
        actions = info -> ["view, $(info.value)"],
        email = info -> "user$(info.value)@example.com",
        delay = info -> "1h",
        markdown = info -> true,
        request_handler = handler,
    ) do
        7
    end
    @test result == 7
    req = only(handler.requests)
    @test req.body == "literal {{ value }}"
    headers = Dict(req.headers)
    @test headers["X-Title"] == "title {{ Success }}"
    @test headers["X-Tags"] == "tag-7"
    @test headers["X-Priority"] == "3"
    @test headers["X-Click"] == "https://example.com/7"
    @test headers["X-Attach"] == "https://example.com/7.txt"
    @test headers["X-Actions"] == "view, 7"
    @test headers["X-Email"] == "user7@example.com"
    @test headers["X-Delay"] == "1h"
    @test headers["X-Markdown"] == "yes"
end

@testset "nothrow" begin
    handler = Ntfy.DummyRequestHandler(status = 500)
    @test_logs (:warn, r"ntfy\(\) failed") Ntfy.ntfy("dummy-topic", "boom"; request_handler = handler, nothrow = true)
    @test length(handler.requests) == 1

    handler = Ntfy.DummyRequestHandler(status = 500)
    @test_throws ErrorException Ntfy.ntfy("dummy-topic", "result {{ value }}"; request_handler = handler) do
        7
    end
    @test length(handler.requests) == 1

    handler = Ntfy.DummyRequestHandler(status = 500)
    result = @test_logs (:warn, r"ntfy\(\) failed") Ntfy.ntfy("dummy-topic", "result {{ value }}"; request_handler = handler, nothrow = true) do
        123
    end
    @test result == 123
    @test length(handler.requests) == 1

    handler = Ntfy.DummyRequestHandler()
    result = @test_logs (:warn, r"ntfy\(\) failed") Ntfy.ntfy(123, "bad topic"; request_handler = handler, nothrow = true)
    @test result === nothing
    @test isempty(handler.requests)

    handler = Ntfy.DummyRequestHandler()
    result = @test_logs (:warn, r"ntfy\(\) failed") Ntfy.ntfy("dummy-topic", 123; request_handler = handler, nothrow = true) do
        42
    end
    @test result == 42
    @test isempty(handler.requests)
end
