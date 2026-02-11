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

## Test: Multiple carousels route events independently
main! : List Arg.Arg => Result {} _
main! = |_args|
    Server.with!(
        Cmd.new("./tests/app/server/main"),
        |base_url|
            { browser, page } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(30000) })?

            Playwright.navigate!(page, base_url)?

            # Verify both carousels render at slide 0 (prev disabled on both)
            Playwright.wait_for!(page, "#games .carousel-button-prev.carousel-button-disabled", Visible)?
            Playwright.wait_for!(page, "#drinks .carousel-button-prev.carousel-button-disabled", Visible)?

            # Click next on games → only games advances
            Playwright.click!(page, "#games .carousel-button-next")?
            Playwright.wait_for!(page, "#games .carousel-button-prev:not(.carousel-button-disabled)", Visible)?
            # Drinks should still be at slide 0
            Playwright.wait_for!(page, "#drinks .carousel-button-prev.carousel-button-disabled", Visible)?

            # Click next on drinks → only drinks advances
            Playwright.click!(page, "#drinks .carousel-button-next")?
            Playwright.wait_for!(page, "#drinks .carousel-button-prev:not(.carousel-button-disabled)", Visible)?
            # Games should still be at slide 1 (prev not disabled)
            Playwright.wait_for!(page, "#games .carousel-button-prev:not(.carousel-button-disabled)", Visible)?

            # Click prev on games → only games goes back
            Playwright.click!(page, "#games .carousel-button-prev")?
            Playwright.wait_for!(page, "#games .carousel-button-prev.carousel-button-disabled", Visible)?
            # Drinks should still be at slide 1
            Playwright.wait_for!(page, "#drinks .carousel-button-prev:not(.carousel-button-disabled)", Visible)?

            Playwright.close!(browser),
    )
