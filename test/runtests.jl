using Test
using Dates
using Downloads
using Markdown
using Preferences
using Base64
using Ntfy

ENV["JULIA_PREFERENCES_PATH"] = mktempdir()

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
        @test req.headers == ["Authorization" => "Custom"]

        handler = Ntfy.DummyRequestHandler()
        Ntfy.ntfy("secrets", "payload"; auth = ("user", "pass"), request_handler = handler)
        req = only(handler.requests)
        encoded = Base64.base64encode("user:pass")
        @test req.headers == ["Authorization" => "Basic $(encoded)"]

        handler = Ntfy.DummyRequestHandler()
        Ntfy.ntfy("secrets", "payload"; auth = ("token",), request_handler = handler)
        req = only(handler.requests)
        @test req.headers == ["Authorization" => "Bearer token"]

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
        @test_throws ErrorException Ntfy.ntfy("secrets", "payload"; auth = ("too", "many", "values"), request_handler = Ntfy.DummyRequestHandler())
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
                    "JULIA_NTFY_BASE_URL" => "https://env.example/",
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
                    "JULIA_NTFY_BASE_URL" => "https://env.example/",
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

    @testset "normalise helpers" begin
        @test Ntfy.normalise_priority(5) == "5"
        @test_throws ErrorException Ntfy.normalise_priority(3.14)

        @test Ntfy.normalise_title(:mytitle) == "mytitle"
        @test_throws ErrorException Ntfy.normalise_title(123)

        @test Ntfy.normalise_tags("alpha,beta") == "alpha,beta"
        @test_throws ErrorException Ntfy.normalise_tags(1)

        @test Ntfy.normalise_click("https://example.com") == "https://example.com"
        @test_throws ErrorException Ntfy.normalise_click(100)

        @test Ntfy.normalise_attach("https://example.com/file.txt") == "https://example.com/file.txt"
        @test_throws ErrorException Ntfy.normalise_attach(Any[])

        @test Ntfy.normalise_actions("view, Open") == "view, Open"
        @test_throws ErrorException Ntfy.normalise_actions(42)

        @test_throws ErrorException Ntfy.normalise_email(123)

        @test Ntfy.normalise_extra_headers(Dict("X-Custom" => "1")) == ["X-Custom" => "1"]
        @test_throws ErrorException Ntfy.normalise_extra_headers(42)
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
    @test Ntfy.format_message("value: \$(value)", 42, false) == "value: 42"

    err = ErrorException("boom")
    @test Ntfy.format_message("status: \$(success) / \$(SUCCESS) / \$(Success)", 1, false) ==
          "status: success / SUCCESS / Success"
    @test occursin("boom", Ntfy.format_message("error: \$(value)", err, true))
end

@testset "do-notation" begin
    handler = Ntfy.DummyRequestHandler()

    result = Ntfy.ntfy("dummy-topic", "result \$(value) - \$(SUCCESS)"; title = "overall \$(Success)", request_handler=handler) do
        99
    end
    @test result === nothing
    @test handler.requests[1].body == "result 99 - SUCCESS"
    @test Dict(handler.requests[1].headers)["X-Title"] == "overall Success"

    @test_throws ErrorException Ntfy.ntfy("dummy-topic", "failing \$(success): \$(value)"; title = "failing \$(SUCCESS)", request_handler=handler) do
        error("kaboom")
    end
    @test endswith(handler.requests[end].body, "kaboom")
    @test Dict(handler.requests[end].headers)["X-Title"] == "failing ERROR"

    Ntfy.ntfy("dummy-topic", "no title formatting"; title = :unchanged, request_handler=handler) do
        :ok
    end
    @test Dict(handler.requests[end].headers)["X-Title"] == "unchanged"
end
