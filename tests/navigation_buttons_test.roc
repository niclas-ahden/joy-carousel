app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.32.0/3MnQnCrtfe6XS5qx58MnAGU6iWk8i1N24MYfoejcWeax.tar.zst",
    playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.15.2/BFCzMMp3DePaKT1sLy1m38p7qS5QB3okSVoFy6A1Y3Jf.tar.zst",
}

import pf.Cmd
import pf.Duration
import pf.Env
import pf.OsStr
import playwright.Playwright

## Test: Navigation buttons (next/prev) work correctly
## The games carousel has 2 slides (0, 1)
main! = |_args| {
    # The test server is started once by tests.roc, which passes its address here.
    base_url = Env.var_str!(OsStr.from_str("CAROUSEL_TEST_URL")).ok_or("http://127.0.0.1:9000")
    { browser, page } = Playwright.launch_page!({ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis }, Chromium(DefaultChannel))?

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

    Playwright.close!(browser)
}
