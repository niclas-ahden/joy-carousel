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

## Test: Initial render shows carousel with slide 0 active
main! : List Arg.Arg => Result {} _
main! = |_args|
    Server.with!(
        Cmd.new("./tests/app/server/main"),
        |base_url|
            { browser, page } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(30000) })?

            Playwright.navigate!(page, base_url)?

            # Verify page title/heading renders
            Playwright.wait_for_selector!(page, "text=Carousel Test")?

            # Verify carousel container exists
            Playwright.wait_for_selector!(page, ".carousel")?

            # Verify first slide content is visible
            Playwright.wait_for_selector!(page, "text=Slide 1")?

            # Verify active slide indicator shows 0
            Playwright.wait_for_selector!(page, "text=Active slide: 0")?

            # Verify navigation buttons exist (test app has navigation: Bool.true)
            Playwright.wait_for_selector!(page, ".carousel-button-prev")?
            Playwright.wait_for_selector!(page, ".carousel-button-next")?

            Playwright.close!(browser),
    )
