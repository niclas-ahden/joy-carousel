app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.32.0/3MnQnCrtfe6XS5qx58MnAGU6iWk8i1N24MYfoejcWeax.tar.zst",
    playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.15.2/BFCzMMp3DePaKT1sLy1m38p7qS5QB3okSVoFy6A1Y3Jf.tar.zst",
}

import pf.Cmd
import pf.Duration
import pf.Env
import pf.OsStr
import playwright.Playwright

## Test: Touch drag right (300px, exceeds 50px threshold) goes to previous slide
main! = |_args| {
    # The test server is started once by tests.roc, which passes its address here.
    base_url = Env.var_str!(OsStr.from_str("CAROUSEL_TEST_URL")).ok_or("http://127.0.0.1:9000")

    # Launch with touch enabled
    browser = Playwright.launch_with!({ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis }, { browser_type: Chromium(DefaultChannel), headless: Bool.True, timeout: TimeoutMilliseconds(30000), args: [] })?
    context = Playwright.new_context_with!(browser, { has_touch: Bool.True, permissions: [] })?
    page = Playwright.new_page!(context)?

    Playwright.navigate!(page, base_url)?

    Playwright.wait_for!(page, "#games", Visible)?

    # Verify we start at first slide (prev disabled)
    Playwright.wait_for!(page, "#games .carousel-button-prev.carousel-button-disabled", Visible)?

    # Get the carousel element's bounding box for dynamic positioning
    box = Playwright.bounding_box!(page, "#games")?
    center_x = box.x + (box.width / 2.0)
    center_y = box.y + (box.height / 2.0)

    # First, advance to slide 1 using touch
    Playwright.touch_swipe!(page, {
        start_x: center_x,
        start_y: center_y,
        end_x: center_x - 300.0,
        end_y: center_y,
    })?

    Playwright.wait_for!(page, "#games .carousel-button-prev:not(.carousel-button-disabled)", Visible)?

    # Now drag right to go back to slide 0
    Playwright.touch_swipe!(page, {
        start_x: center_x,
        start_y: center_y,
        end_x: center_x + 300.0,
        end_y: center_y,
    })?

    # Back at first slide (prev disabled again)
    Playwright.wait_for!(page, "#games .carousel-button-prev.carousel-button-disabled", Visible)?

    Playwright.close!(browser)
}
