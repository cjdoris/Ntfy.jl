using Test
using Ntfy

@testset "ntfy_request" begin
    @testset "defaults" begin
        req = Ntfy.ntfy_request("mytopic", "Backup successful 😀")
        @test req.method == "POST"
        @test req.url == "https://ntfy.sh/mytopic"
        @test req.headers == Pair{String,String}[]
        @test req.body == "Backup successful 😀"
    end

    @testset "headers" begin
        req = Ntfy.ntfy_request(
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
        req = Ntfy.ntfy_request("topic", "msg"; markdown = false)
        @test req.headers == Pair{String,String}[]
    end

    @testset "base url" begin
        req = Ntfy.ntfy_request("/nested/topic", "hi"; base_url = "https://example.com/")
        @test req.url == "https://example.com/nested/topic"
    end

    @testset "extra headers vector" begin
        req = Ntfy.ntfy_request("topic", "msg"; extra_headers = ["X-One" => "1", "X-Two" => "2"])
        @test req.headers == ["X-One" => "1", "X-Two" => "2"]
    end

    @testset "delay" begin
        req = Ntfy.ntfy_request("reminders", "Drink water"; delay = "30m")
        @test req.headers == ["X-Delay" => "30m"]
    end

    @testset "invalid types" begin
        @test_throws ErrorException Ntfy.ntfy_request(123, "msg")
        @test_throws ErrorException Ntfy.ntfy_request("topic", 456)
        @test_throws ErrorException Ntfy.ntfy_request("topic", "msg"; extra_headers = ["bad"])
        @test_throws ErrorException Ntfy.ntfy_request("topic", "msg"; base_url = 123)
        @test_throws ErrorException Ntfy.ntfy_request("topic", "msg"; delay = "")
        @test_throws ErrorException Ntfy.ntfy_request("topic", "msg"; delay = 123)
        @test_throws ErrorException Ntfy.ntfy_request("topic", "msg"; markdown = "yes")
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
    struct DummyTopic end
    messages = String[]
    function Ntfy.ntfy(::DummyTopic, message; kwargs...)
        push!(messages, message)
        return :ok
    end

    result = Ntfy.ntfy(DummyTopic(), "result \$(value) - \$(SUCCESS)") do
        99
    end
    @test result == 99
    @test messages == ["result 99 - SUCCESS"]

    @test_throws ErrorException Ntfy.ntfy(DummyTopic(), "failing \$(success): \$(value)") do
        error("kaboom")
    end
    @test endswith(last(messages), "kaboom")
end
