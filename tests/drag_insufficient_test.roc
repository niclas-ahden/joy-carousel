app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.32.0/3MnQnCrtfe6XS5qx58MnAGU6iWk8i1N24MYfoejcWeax.tar.zst",
    playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.15.2/BFCzMMp3DePaKT1sLy1m38p7qS5QB3okSVoFy6A1Y3Jf.tar.zst",
}

import pf.Cmd
import pf.Duration
import pf.Env
import pf.OsStr
import pf.Sleep
import playwright.Playwright

## Test: Dragging less than threshold (30px < 50px) does NOT change slide
main! = |_args| {
    # The test server is started once by tests.roc, which passes its address here.
    base_url = Env.var_str!(OsStr.from_str("CAROUSEL_TEST_URL")).ok_or("http://127.0.0.1:9000")
    { browser, page } = Playwright.launch_page!({ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis }, Chromium(DefaultChannel))?

    Playwright.navigate!(page, base_url)?

    # Wait for initial render at slide 0 (prev disabled)
    Playwright.wait_for!(page, "#games .carousel-button-prev.carousel-button-disabled", Visible)?

    # Get the carousel element's bounding box for dynamic positioning
    box = Playwright.bounding_box!(page, "#games")?
    center_x = box.x + (box.width / 2.0)
    center_y = box.y + (box.height / 2.0)

    # Drag only 30px left - below the 50px threshold
    Playwright.mouse_move!(page, center_x, center_y)?
    Playwright.mouse_down!(page)?
    Playwright.mouse_move_with_steps!(page, center_x - 30.0, center_y, 5)?
    Playwright.mouse_up!(page)?

    # Small delay to let any transition settle
    Sleep.millis!(500)?

    # Should still be on slide 0 since drag was insufficient (prev still disabled)
    Playwright.wait_for!(page, "#games .carousel-button-prev.carousel-button-disabled", Visible)?

    Playwright.close!(browser)
}
