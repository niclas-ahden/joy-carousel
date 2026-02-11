app [main!] {
    pf: platform "https://github.com/growthagent/basic-cli/releases/download/0.25.0/2Qj7ggHJdVV9jAspIjvskp_cUWvAyh7B9I-Ma_sY4zk.tar.br",
    playwright: "/home/niclas/dev/roc-playwright/package/main.roc",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.1.0/1gNyp2QAxomebg0_bZTY4WwD6WFyLjVl6TbC7Dr7AX8.tar.br",
}

import pf.Arg
import pf.Cmd
import pf.Env
import pf.Http
import pf.Sleep

import playwright.Playwright {
    cmd_new: Cmd.new,
    cmd_args: Cmd.args,
    cmd_spawn_grouped!: Cmd.spawn_grouped!,
}

import spec.Server {
    env_var!: Env.var!,
    cmd_env: Cmd.env,
    cmd_spawn_grouped!: Cmd.spawn_grouped!,
    http_get!: Http.get_utf8!,
    sleep!: Sleep.millis!,
}

## Test: Initial render shows carousels with slide 0 active
main! : List Arg.Arg => Result {} _
main! = |_args|
    Server.with!(
        Cmd.new("./tests/app/server/main"),
        |base_url|
            { browser, page } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(30000) })?

            Playwright.navigate!(page, base_url)?

            # Verify page title/heading renders
            Playwright.wait_for!(page, "text=Carousel Test", Visible)?

            # Verify games carousel renders
            Playwright.wait_for!(page, "#games", Visible)?
            Playwright.wait_for!(page, "text=Diablo II", Visible)?

            # Verify navigation buttons exist (test app has navigation: Bool.true)
            Playwright.wait_for!(page, "#games .carousel-button-prev", Visible)?
            Playwright.wait_for!(page, "#games .carousel-button-next", Visible)?

            # Verify prev is disabled at first slide
            Playwright.wait_for!(page, "#games .carousel-button-prev.carousel-button-disabled", Visible)?

            # Verify drinks carousel renders
            Playwright.wait_for!(page, "#drinks", Visible)?
            Playwright.wait_for!(page, "text=Whisky", Visible)?

            Playwright.close!(browser),
    )
