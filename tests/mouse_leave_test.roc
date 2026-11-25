app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.32.0/3MnQnCrtfe6XS5qx58MnAGU6iWk8i1N24MYfoejcWeax.tar.zst",
    playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.15.2/BFCzMMp3DePaKT1sLy1m38p7qS5QB3okSVoFy6A1Y3Jf.tar.zst",
}

import pf.Cmd
import pf.Duration
import pf.Env
import pf.OsStr
import playwright.Playwright

## Test: Mouse leave during drag finalizes the slide change
## When dragging exceeds threshold and mouse leaves, should still change slide
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

    # Start a drag that exceeds threshold, then move mouse outside the carousel
    Playwright.mouse_move!(page, center_x, center_y)?
    Playwright.mouse_down!(page)?
    Playwright.mouse_move_with_steps!(page, center_x - 300.0, center_y, 10)? # -300px exceeds threshold
    # Move mouse far outside the carousel area to trigger mouseleave
    Playwright.mouse_move!(page, 0.0, 0.0)?

    # Should have advanced (prev no longer disabled)
    Playwright.wait_for!(page, "#games .carousel-button-prev:not(.carousel-button-disabled)", Visible)?

    Playwright.close!(browser)
}
