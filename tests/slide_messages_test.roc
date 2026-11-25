app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.32.0/3MnQnCrtfe6XS5qx58MnAGU6iWk8i1N24MYfoejcWeax.tar.zst",
    playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.15.2/BFCzMMp3DePaKT1sLy1m38p7qS5QB3okSVoFy6A1Y3Jf.tar.zst",
}

import pf.Cmd
import pf.Duration
import pf.Env
import pf.OsStr
import playwright.Playwright

## Test: Slides keep the app's message type, so a button inside a slide sends
## the app's own message, and clicking it does not move the carousel
## The picks carousel has 2 slides, each a "Pick <name>" button
main! = |_args| {
    # The test server is started once by tests.roc, which passes its address here.
    base_url = Env.var_str!(OsStr.from_str("CAROUSEL_TEST_URL")).ok_or("http://127.0.0.1:9000")
    { browser, page } = Playwright.launch_page!({ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis }, Chromium(DefaultChannel))?

    Playwright.navigate!(page, base_url)?

    # Nothing picked yet
    Playwright.wait_for!(page, "#picked:text-is('Picked: ')", Visible)?

    # The first slide's button sends the app's message
    Playwright.click!(page, "#picks button:text-is('Pick Apple')")?
    Playwright.wait_for!(page, "#picked:text-is('Picked: Apple')", Visible)?
    Playwright.wait_for!(page, "#picks .carousel-button-prev.carousel-button-disabled", Visible)?

    # Move to the second slide and pick from there
    Playwright.click!(page, "#picks .carousel-button-next")?
    Playwright.wait_for!(page, "#picks .carousel-button-next.carousel-button-disabled", Visible)?
    Playwright.click!(page, "#picks button:text-is('Pick Pear')")?
    Playwright.wait_for!(page, "#picked:text-is('Picked: Pear')", Visible)?

    # The click inside the slide left the carousel where it was
    Playwright.wait_for!(page, "#picks .carousel-button-next.carousel-button-disabled", Visible)?

    Playwright.close!(browser)
}
