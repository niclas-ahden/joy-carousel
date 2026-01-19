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
main! : List Arg.Arg => Result {} _
main! = |_args|
    Server.with!(
        Cmd.new("./tests/app/server/main"),
        |base_url|
            { browser, page } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(30000) })?

            Playwright.navigate!(page, base_url)?

            # Wait for initial render at slide 0
            Playwright.wait_for_selector!(page, "text=Active slide: 0")?

            # Verify prev button is disabled at first slide
            Playwright.wait_for_selector!(page, ".carousel-button-prev.carousel-button-disabled")?

            # Click next button to go to slide 1
            Playwright.click!(page, ".carousel-button-next")?
            Playwright.wait_for_selector!(page, "text=Active slide: 1")?

            # Prev button should no longer be disabled
            Playwright.wait_for_selector!(page, ".carousel-button-prev:not(.carousel-button-disabled)")?

            # Click next button to go to slide 2
            Playwright.click!(page, ".carousel-button-next")?
            Playwright.wait_for_selector!(page, "text=Active slide: 2")?

            # Click next button to go to slide 3 (last)
            Playwright.click!(page, ".carousel-button-next")?
            Playwright.wait_for_selector!(page, "text=Active slide: 3")?

            # Verify next button is disabled at last slide
            Playwright.wait_for_selector!(page, ".carousel-button-next.carousel-button-disabled")?

            # Click prev button to go back to slide 2
            Playwright.click!(page, ".carousel-button-prev")?
            Playwright.wait_for_selector!(page, "text=Active slide: 2")?

            Playwright.close!(browser),
    )
