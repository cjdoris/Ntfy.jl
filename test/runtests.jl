using Test
push!(LOAD_PATH, "@stdlib")
using Markdown
using Ntfy

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

    @testset "invalid types" begin
        @test_throws ErrorException Ntfy.ntfy(123, "msg"; request_handler = Ntfy.DummyRequestHandler())
        @test_throws ErrorException Ntfy.ntfy("topic", 456; request_handler = Ntfy.DummyRequestHandler())
        @test_throws ErrorException Ntfy.ntfy("topic", "msg"; extra_headers = ["bad"], request_handler = Ntfy.DummyRequestHandler())
        @test_throws ErrorException Ntfy.ntfy("topic", "msg"; base_url = 123, request_handler = Ntfy.DummyRequestHandler())
        @test_throws ErrorException Ntfy.ntfy("topic", "msg"; delay = "", request_handler = Ntfy.DummyRequestHandler())
        @test_throws ErrorException Ntfy.ntfy("topic", "msg"; delay = 123, request_handler = Ntfy.DummyRequestHandler())
        @test_throws ErrorException Ntfy.ntfy("topic", "msg"; markdown = "yes", request_handler = Ntfy.DummyRequestHandler())
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
