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

## Test: Navigation buttons (next/prev) work correctly
## The games carousel has 2 slides (0, 1)
main! : List Arg.Arg => Result {} _
main! = |_args|
    Server.with!(
        Cmd.new("./tests/app/server/main"),
        |base_url|
            { browser, page } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(30000) })?

            Playwright.navigate!(page, base_url)?

            # Verify prev button is disabled at first slide, next is enabled
            Playwright.wait_for!(page, "#games .carousel-button-prev.carousel-button-disabled", Visible)?
            Playwright.wait_for!(page, "#games .carousel-button-next:not(.carousel-button-disabled)", Visible)?

            # Click next button to go to slide 1 (last)
            Playwright.click!(page, "#games .carousel-button-next")?

            # Prev should be enabled, next should be disabled (last slide)
            Playwright.wait_for!(page, "#games .carousel-button-prev:not(.carousel-button-disabled)", Visible)?
            Playwright.wait_for!(page, "#games .carousel-button-next.carousel-button-disabled", Visible)?

            # Click prev button to go back to slide 0
            Playwright.click!(page, "#games .carousel-button-prev")?

            # Prev disabled again (first slide), next enabled
            Playwright.wait_for!(page, "#games .carousel-button-prev.carousel-button-disabled", Visible)?
            Playwright.wait_for!(page, "#games .carousel-button-next:not(.carousel-button-disabled)", Visible)?

            Playwright.close!(browser),
    )
