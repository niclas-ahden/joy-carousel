app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.32.0/3MnQnCrtfe6XS5qx58MnAGU6iWk8i1N24MYfoejcWeax.tar.zst",
    playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.15.2/BFCzMMp3DePaKT1sLy1m38p7qS5QB3okSVoFy6A1Y3Jf.tar.zst",
}

import pf.Cmd
import pf.Duration
import pf.Env
import pf.OsStr
import playwright.Playwright

## Test: A press is not a drag until it moves. Holding the mouse down on the
## next button keeps the track's transition, so a slide change that is still
## running is not cut short, and the click that follows steps as usual.
main! = |_args| {
    # The test server is started once by tests.roc, which passes its address here.
    base_url = Env.var_str!(OsStr.from_str("CAROUSEL_TEST_URL")).ok_or("http://127.0.0.1:9000")
    { browser, page } = Playwright.launch_page!({ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis }, Chromium(DefaultChannel))?

    Playwright.navigate!(page, base_url)?
    Playwright.wait_for!(page, "#drinks [aria-label='1 / 3']:not([inert])", Visible)?
    _ = Playwright.evaluate!(page, "document.querySelector('#drinks').scrollIntoView({ block: 'center' }); 'ok'")?

    box = Playwright.bounding_box!(page, "#drinks .carousel-button-next")?
    x = box.x + (box.width / 2.0)
    y = box.y + (box.height / 2.0)
    Playwright.mouse_move!(page, x, y)?
    Playwright.mouse_down!(page)?

    duration = Playwright.evaluate!(page, "getComputedStyle(document.querySelector('#drinks-slides')).transitionDuration")?
    if duration != "0.3s" {
        Err(PressShouldKeepTheTransition(duration))?
    } else {
        {}
    }

    Playwright.mouse_up!(page)?
    Playwright.wait_for!(page, "#drinks [aria-label='2 / 3']:not([inert])", Visible) ? |_| ClickShouldStillStep

    Playwright.close!(browser)
}
