using Test
using Ntfy: ntfy_request

@testset "ntfy_request" begin
    req = ntfy_request("mytopic", "Backup successful 😀")
    @test req.method == "POST"
    @test req.url == "https://ntfy.sh/mytopic"
    @test req.headers == Pair{String,String}[]
    @test req.body == "Backup successful 😀"

    req2 = ntfy_request(
        "phil_alerts",
        "Remote access to phils-laptop detected. Act right away.";
        priority = "urgent",
        title = "Unauthorized access detected",
        tags = ["warning", "skull"],
        click = "https://home.nest.com/",
        attach = "https://nest.com/view/yAxkasd.jpg",
        actions = [
            "http, Open door, https://api.nest.com/open/yAxkasd, clear=true",
            "http, View camera, https://home.nest.com/camera"
        ],
        email = "phil@example.com",
    )

    headers = Dict(req2.headers)
    @test headers["Priority"] == "urgent"
    @test headers["Title"] == "Unauthorized access detected"
    @test headers["Tags"] == "warning,skull"
    @test headers["Click"] == "https://home.nest.com/"
    @test headers["Attach"] == "https://nest.com/view/yAxkasd.jpg"
    @test headers["Actions"] == "http, Open door, https://api.nest.com/open/yAxkasd, clear=true; http, View camera, https://home.nest.com/camera"
    @test headers["Email"] == "phil@example.com"
    @test req2.body == "Remote access to phils-laptop detected. Act right away."

    req3 = ntfy_request("mydoorbell", "Ding dong"; actions = "http, Open door, https://api.nest.com/open/yAxkasd, clear=true")
    headers3 = Dict(req3.headers)
    @test headers3["Actions"] == "http, Open door, https://api.nest.com/open/yAxkasd, clear=true"
    @test length(req3.headers) == 1

    req4 = ntfy_request("alt", "hello"; base_url = "https://ntfy.example.com")
    @test req4.url == "https://ntfy.example.com/alt"

    req5 = ntfy_request("another", "hey"; base_url = "https://ntfy.example.com/")
    @test req5.url == "https://ntfy.example.com/another"
end
