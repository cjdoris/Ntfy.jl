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
                "http",
                "Open door",
                "https://api.nest.com/open/yAxkasd",
                "clear=true",
            ],
            email = "phil@example.com",
            markdown = true,
            extra_headers = Dict("X-Test" => "yes"),
        )
        expected_headers = [
            "X-Priority" => "urgent",
            "X-Title" => "Unauthorized access detected",
            "X-Tags" => "warning,skull",
            "X-Click" => "https://home.nest.com/",
            "X-Attach" => "https://nest.com/view/yAxkasd.jpg",
            "X-Actions" => "http, Open door, https://api.nest.com/open/yAxkasd, clear=true",
            "X-Email" => "phil@example.com",
            "X-Markdown" => "yes",
            "X-Test" => "yes",
        ]
        @test req.headers == expected_headers
    end

    @testset "base url" begin
        req = Ntfy.ntfy_request("/nested/topic", "hi"; base_url = "https://example.com/")
        @test req.url == "https://example.com/nested/topic"
    end

    @testset "extra headers vector" begin
        req = Ntfy.ntfy_request("topic", "msg"; extra_headers = ["X-One" => "1", "X-Two" => "2"])
        @test req.headers == ["X-One" => "1", "X-Two" => "2"]
    end

    @testset "invalid types" begin
        @test_throws ErrorException Ntfy.ntfy_request(123, "msg")
        @test_throws ErrorException Ntfy.ntfy_request("topic", 456)
        @test_throws ErrorException Ntfy.ntfy_request("topic", "msg"; extra_headers = ["bad"])
        @test_throws ErrorException Ntfy.ntfy_request("topic", "msg"; base_url = 123)
        @test_throws ErrorException Ntfy.ntfy_request("topic", "msg"; markdown = "yes")
    end
end
