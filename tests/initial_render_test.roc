app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.32.0/3MnQnCrtfe6XS5qx58MnAGU6iWk8i1N24MYfoejcWeax.tar.zst",
    playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.15.2/BFCzMMp3DePaKT1sLy1m38p7qS5QB3okSVoFy6A1Y3Jf.tar.zst",
}

import pf.Cmd
import pf.Duration
import pf.Env
import pf.OsStr
import playwright.Playwright

## Test: Initial render shows carousels with slide 0 active
main! = |_args| {
    # The test server is started once by tests.roc, which passes its address here.
    base_url = Env.var_str!(OsStr.from_str("CAROUSEL_TEST_URL")).ok_or("http://127.0.0.1:9000")
    { browser, page } = Playwright.launch_page!({ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis }, Chromium(DefaultChannel))?

    Playwright.navigate!(page, base_url)?

    # Verify page title/heading renders
    Playwright.wait_for!(page, "text=Carousel Test", Visible)?

    # Verify games carousel renders
    Playwright.wait_for!(page, "#games", Visible)?
    Playwright.wait_for!(page, "text=Diablo II", Visible)?

    # Verify navigation buttons exist (test app has navigation: Bool.True)
    Playwright.wait_for!(page, "#games .carousel-button-prev", Visible)?
    Playwright.wait_for!(page, "#games .carousel-button-next", Visible)?

    # Verify prev is disabled at first slide
    Playwright.wait_for!(page, "#games .carousel-button-prev.carousel-button-disabled", Visible)?

    # Verify drinks carousel renders
    Playwright.wait_for!(page, "#drinks", Visible)?
    Playwright.wait_for!(page, "text=Whisky", Visible)?

    Playwright.close!(browser)
}
