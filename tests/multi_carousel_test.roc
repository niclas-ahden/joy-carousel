app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.32.0/3MnQnCrtfe6XS5qx58MnAGU6iWk8i1N24MYfoejcWeax.tar.zst",
    playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.15.2/BFCzMMp3DePaKT1sLy1m38p7qS5QB3okSVoFy6A1Y3Jf.tar.zst",
}

import pf.Cmd
import pf.Duration
import pf.Env
import pf.OsStr
import playwright.Playwright

## Test: Multiple carousels route events independently
main! = |_args| {
    # The test server is started once by tests.roc, which passes its address here.
    base_url = Env.var_str!(OsStr.from_str("CAROUSEL_TEST_URL")).ok_or("http://127.0.0.1:9000")
    { browser, page } = Playwright.launch_page!({ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis }, Chromium(DefaultChannel))?

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

    Playwright.close!(browser)
}
