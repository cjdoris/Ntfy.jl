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
                "view, Open portal, https://home.nest.com/, clear=true",
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

@testset "template view" begin
    struct MarkdownValue
        text::String
    end
    Base.show(io::IO, ::MIME"text/plain", value::MarkdownValue) = print(io, value.text)
    Base.show(io::IO, ::MIME"text/markdown", value::MarkdownValue) = print(io, "**", value.text, "**")

    struct BrokenMarkdownValue
        text::String
    end
    Base.show(io::IO, ::MIME"text/plain", value::BrokenMarkdownValue) = print(io, value.text)
    Base.show(::IO, ::MIME"text/markdown", ::BrokenMarkdownValue) = error("no markdown support")

    info = (value=MarkdownValue("bold"), is_error=false, time=1.234)
    template = :"plain $value md $value_md $success $SUCCESS $Success $time"
    @test Ntfy.render_template(template, info) ==
          "plain bold md **bold** success SUCCESS Success 1.23 s"

    fallback_info = (value=BrokenMarkdownValue("plain"), is_error=false, time=0.0)
    fallback_template = :"md $value_md"
    @test Ntfy.render_template(fallback_template, fallback_info) == "md ```\nplain\n```"

    err = ErrorException("boom")
    err_info = (value=err, is_error=true, time=1.2e-6)
    err_template = :"error $value"
    @test occursin("boom", Ntfy.render_template(err_template, err_info))

    @test Ntfy.render_template(:"elapsed $time", (value=0, is_error=false, time=86400.0)) ==
          "elapsed 1 d"
    @test Ntfy.render_template(:"elapsed $time", (value=0, is_error=false, time=3600.0)) ==
          "elapsed 1 h"
    @test Ntfy.render_template(:"elapsed $time", (value=0, is_error=false, time=60.0)) ==
          "elapsed 1 m"
    @test Ntfy.render_template(:"elapsed $time", (value=0, is_error=false, time=1.23)) ==
          "elapsed 1.23 s"
    @test Ntfy.render_template(:"elapsed $time", (value=0, is_error=false, time=0.0)) ==
          "elapsed 0 s"

    struct FancyError <: Exception
        msg::String
    end
    Base.show(io::IO, err::FancyError) = print(io, "show:", err.msg)
    Base.showerror(io::IO, err::FancyError) = print(io, "showerror:", err.msg)
    fancy_info = (value=FancyError("fail"), is_error=true, time=0.0)
    @test Ntfy.render_template(:"$value", fancy_info) == "showerror:fail"
    @test Ntfy.render_template(:"$value_md", fancy_info) == "```\nshowerror:fail\n```"
    @test_throws ErrorException Ntfy.render_template(:(value + 1), info)
    @test_throws ErrorException Ntfy.render_template(Expr(:string, "bad ", 1), info)
    @test_throws ErrorException Ntfy.render_template(:"$unknown", info)
end

@testset "do-notation" begin
    handler = Ntfy.DummyRequestHandler()

    result = Ntfy.ntfy(
        "dummy-topic",
        :"result $value - $SUCCESS";
        title = :"overall $Success",
        request_handler=handler,
    ) do
        99
    end
    @test result === 99
    @test handler.requests[1].body == "result 99 - SUCCESS"
    @test Dict(handler.requests[1].headers)["X-Title"] == "overall Success"

    @test_throws ErrorException Ntfy.ntfy(
        "dummy-topic",
        :"ok $value";
        error_message = :"failed $SUCCESS: $value",
        title = :"failing $SUCCESS",
        error_title = :"error $Success",
        error_priority = 5,
        error_tags = ["fire"],
        request_handler=handler,
    ) do
        error("kaboom")
    end
    @test occursin("kaboom", handler.requests[end].body)
    @test Dict(handler.requests[end].headers)["X-Title"] == "error Error"
    @test Dict(handler.requests[end].headers)["X-Priority"] == "5"
    @test Dict(handler.requests[end].headers)["X-Tags"] == "fire"

    handler = Ntfy.DummyRequestHandler()
    message_template = :"message $value $success"
    title_template = :"title $Success"
    result = Ntfy.ntfy("dummy-topic", message_template; title=title_template, request_handler=handler) do
        42
    end
    @test result == 42
    @test handler.requests[end].body == "message 42 success"
    @test Dict(handler.requests[end].headers)["X-Title"] == "title Success"

    handler = Ntfy.DummyRequestHandler()
    error_message_template = :"error $value"
    error_title_template = :"title $SUCCESS"
    @test_throws ErrorException Ntfy.ntfy(
        "dummy-topic",
        "unused";
        error_message=error_message_template,
        error_title=error_title_template,
        request_handler=handler,
    ) do
        error("boom")
    end
    @test occursin("boom", handler.requests[end].body)
    @test Dict(handler.requests[end].headers)["X-Title"] == "title ERROR"

    Ntfy.ntfy("dummy-topic", "no title formatting"; title = :unchanged, request_handler=handler) do
        :ok
    end
    @test Dict(handler.requests[end].headers)["X-Title"] == "unchanged"

    handler = Ntfy.DummyRequestHandler()
    Ntfy.ntfy("dummy-topic", "literal {{value}}"; request_handler=handler) do
        123
    end
    @test handler.requests[end].body == "literal {{value}}"

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
