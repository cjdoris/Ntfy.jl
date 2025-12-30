using Test
using Ntfy

@testset "ntfy" begin
    @testset "defaults" begin
        topic = Ntfy.DummyTopic(topic = "mytopic")
        Ntfy.ntfy(topic, "Backup successful 😀")
        req = only(topic.requests)
        @test req.method == "POST"
        @test req.url == "https://ntfy.sh/mytopic"
        @test req.headers == Pair{String,String}[]
        @test req.body == "Backup successful 😀"
    end

    @testset "headers" begin
        topic = Ntfy.DummyTopic(topic = "phil_alerts")
        Ntfy.ntfy(
            topic,
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
        req = only(topic.requests)
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
        topic = Ntfy.DummyTopic()
        Ntfy.ntfy(topic, "msg"; markdown = false)
        req = only(topic.requests)
        @test req.headers == Pair{String,String}[]
    end

    @testset "base url" begin
        topic = Ntfy.DummyTopic()
        Ntfy.ntfy(topic, "hi"; base_url = "https://example.com/", title = "unused")
        req = only(topic.requests)
        @test req.url == "https://example.com/dummy-topic"
    end

    @testset "extra headers vector" begin
        topic = Ntfy.DummyTopic()
        Ntfy.ntfy(topic, "msg"; extra_headers = ["X-One" => "1", "X-Two" => "2"])
        req = only(topic.requests)
        @test req.headers == ["X-One" => "1", "X-Two" => "2"]
    end

    @testset "delay" begin
        topic = Ntfy.DummyTopic(topic = "reminders")
        Ntfy.ntfy(topic, "Drink water"; delay = "30m")
        req = only(topic.requests)
        @test req.headers == ["X-Delay" => "30m"]
    end

    @testset "invalid types" begin
        @test_throws ErrorException Ntfy.ntfy(123, "msg")
        @test_throws ErrorException Ntfy.ntfy("topic", 456)
        @test_throws ErrorException Ntfy.ntfy("topic", "msg"; extra_headers = ["bad"])
        @test_throws ErrorException Ntfy.ntfy("topic", "msg"; base_url = 123)
        @test_throws ErrorException Ntfy.ntfy("topic", "msg"; delay = "")
        @test_throws ErrorException Ntfy.ntfy("topic", "msg"; delay = 123)
        @test_throws ErrorException Ntfy.ntfy("topic", "msg"; markdown = "yes")
    end

    @testset "error status" begin
        topic = Ntfy.DummyTopic(status = 500)
        @test_throws ErrorException Ntfy.ntfy(topic, "boom")
        @test length(topic.requests) == 1
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
    topic = Ntfy.DummyTopic()

    result = Ntfy.ntfy(topic, "result \$(value) - \$(SUCCESS)"; title = "overall \$(Success)") do
        99
    end
    @test result === nothing
    @test topic.requests[1].body == "result 99 - SUCCESS"
    @test Dict(topic.requests[1].headers)["X-Title"] == "overall Success"

    @test_throws ErrorException Ntfy.ntfy(topic, "failing \$(success): \$(value)"; title = "failing \$(SUCCESS)") do
        error("kaboom")
    end
    @test endswith(topic.requests[end].body, "kaboom")
    @test Dict(topic.requests[end].headers)["X-Title"] == "failing ERROR"

    Ntfy.ntfy(topic, "no title formatting"; title = :unchanged) do
        :ok
    end
    @test Dict(topic.requests[end].headers)["X-Title"] == "unchanged"
end
