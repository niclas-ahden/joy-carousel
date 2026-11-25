app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.32.0/3MnQnCrtfe6XS5qx58MnAGU6iWk8i1N24MYfoejcWeax.tar.zst",
    playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.15.2/BFCzMMp3DePaKT1sLy1m38p7qS5QB3okSVoFy6A1Y3Jf.tar.zst",
}

import pf.Cmd
import pf.Duration
import pf.Env
import pf.OsStr
import playwright.Playwright

## Test: A carousel with `at_ends: Wrap` steps from the first slide back to
## the last and from the last on to the first, and never disables a button.
main! = |_args| {
    # The test server is started once by tests.roc, which passes its address here.
    base_url = Env.var_str!(OsStr.from_str("CAROUSEL_TEST_URL")).ok_or("http://127.0.0.1:9000")
    { browser, page } = Playwright.launch_page!({ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis }, Chromium(DefaultChannel))?

    Playwright.navigate!(page, base_url)?
    Playwright.wait_for!(page, "#looped [aria-label='1 / 3']:not([inert])", Visible)?

    disabled = Playwright.query_count!(page, "#looped button[aria-disabled]")?
    if disabled != 0 { Err(WrappingButtonsShouldNeverBeDisabled(disabled))? } else { {} }

    Playwright.click!(page, "#looped .carousel-button-prev")?
    Playwright.wait_for!(page, "#looped [aria-label='3 / 3']:not([inert])", Visible) ? |_| PrevShouldWrapToTheLastSlide

    Playwright.click!(page, "#looped .carousel-button-next")?
    Playwright.wait_for!(page, "#looped [aria-label='1 / 3']:not([inert])", Visible) ? |_| NextShouldWrapToTheFirstSlide

    Playwright.close!(browser)
}
