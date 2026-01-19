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

## Test: Dragging less than threshold (30px < 50px) does NOT change slide
main! : List Arg.Arg => Result {} _
main! = |_args|
    Server.with!(
        Cmd.new("./tests/app/server/main"),
        |base_url|
            { browser, page } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(30000) })?

            Playwright.navigate!(page, base_url)?

            # Wait for initial render at slide 0
            Playwright.wait_for_selector!(page, "text=Active slide: 0")?

            # Get the carousel element's bounding box for dynamic positioning
            box = Playwright.bounding_box!(page, ".carousel")?
            center_x = box.x + (box.width / 2.0)
            center_y = box.y + (box.height / 2.0)

            # Drag only 30px left - below the 50px threshold
            Playwright.mouse_move!(page, center_x, center_y)?
            Playwright.mouse_down!(page)?
            Playwright.mouse_move_with_steps!(page, center_x - 30.0, center_y, 5)?
            Playwright.mouse_up!(page)?

            # Small delay to let any transition settle
            Sleep.millis!(500)

            # Should still be on slide 0 since drag was insufficient
            Playwright.wait_for_selector!(page, "text=Active slide: 0")?

            Playwright.close!(browser),
    )
