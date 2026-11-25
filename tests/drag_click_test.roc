app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.32.0/3MnQnCrtfe6XS5qx58MnAGU6iWk8i1N24MYfoejcWeax.tar.zst",
    playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.15.2/BFCzMMp3DePaKT1sLy1m38p7qS5QB3okSVoFy6A1Y3Jf.tar.zst",
}

import pf.Cmd
import pf.Duration
import pf.Env
import pf.OsStr
import playwright.Playwright

## Test: A mouse drag that starts on a button or a link inside a slide changes
## the slide and does nothing else. The button sends no message and the link
## is not followed. A plain click on either still works.
main! = |_args| {
    # The test server is started once by tests.roc, which passes its address here.
    base_url = Env.var_str!(OsStr.from_str("CAROUSEL_TEST_URL")).ok_or("http://127.0.0.1:9000")
    { browser, page } = Playwright.launch_page!({ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis }, Chromium(DefaultChannel))?

    Playwright.navigate!(page, base_url)?
    Playwright.wait_for!(page, "#picked:text-is('Picked: ')", Visible)?

    # A drag from a button.
    drag_from!(page, "#picks", "#picks button:text-is('Pick Apple')")?
    Playwright.wait_for!(page, "#picks [aria-label='2 / 2']:not([inert])", Visible) ? |_| ButtonDragShouldChangeTheSlide
    picked = Playwright.evaluate!(page, "document.querySelector('#picked').textContent")?
    if picked != "Picked: " {
        Err(ButtonDragShouldNotClick(picked))?
    } else {
        {}
    }

    Playwright.click!(page, "#picks button:text-is('Pick Pear')")?
    Playwright.wait_for!(page, "#picked:text-is('Picked: Pear')", Visible) ? |_| ButtonClickShouldStillWork

    # A drag from a link.
    drag_from!(page, "#links", "#links a:text-is('Open first')")?
    Playwright.wait_for!(page, "#links [aria-label='2 / 2']:not([inert])", Visible) ? |_| LinkDragShouldChangeTheSlide
    hash = Playwright.evaluate!(page, "location.hash || 'none'")?
    if hash != "none" {
        Err(LinkDragShouldNotFollowTheLink(hash))?
    } else {
        {}
    }

    Playwright.click!(page, "#links a:text-is('Open second')")?
    followed = Playwright.evaluate!(page, hash_is_second_js)?
    if followed != "yes" {
        Err(LinkClickShouldStillWork)?
    } else {
        {}
    }

    Playwright.close!(browser)
}

## Press the mouse on `selector` and drag it 200px left, well past the
## threshold, inside the carousel `carousel`, scrolled into view first.
drag_from! = |page, carousel, selector| {
    _ = Playwright.evaluate!(page, "document.querySelector('${carousel}').scrollIntoView({ block: 'center' }); 'ok'")?
    box = Playwright.bounding_box!(page, selector)?
    x = box.x + (box.width / 2.0)
    y = box.y + (box.height / 2.0)
    Playwright.mouse_move!(page, x, y)?
    Playwright.mouse_down!(page)?
    Playwright.mouse_move_with_steps!(page, x - 200.0, y, 10)?
    Playwright.mouse_up!(page)
}

hash_is_second_js : Str
hash_is_second_js =
    \\new Promise((resolve) => {
    \\    const check = () => location.hash === '#second' ? resolve('yes') : setTimeout(check, 20);
    \\    check();
    \\    setTimeout(() => resolve('no'), 2000);
    \\})
