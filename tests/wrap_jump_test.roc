app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.32.0/3MnQnCrtfe6XS5qx58MnAGU6iWk8i1N24MYfoejcWeax.tar.zst",
    playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.15.2/BFCzMMp3DePaKT1sLy1m38p7qS5QB3okSVoFy6A1Y3Jf.tar.zst",
}

import pf.Cmd
import pf.Duration
import pf.Env
import pf.OsStr
import playwright.Playwright

## Test: A carousel with `wraps: Jump` puts the slide at the other end in
## place at once when it wraps, instead of sliding back across the track,
## and still slides between neighbours.
main! = |_args| {
    # The test server is started once by tests.roc, which passes its address here.
    base_url = Env.var_str!(OsStr.from_str("CAROUSEL_TEST_URL")).ok_or("http://127.0.0.1:9000")
    { browser, page } = Playwright.launch_page!({ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis }, Chromium(DefaultChannel))?

    Playwright.navigate!(page, base_url)?
    Playwright.wait_for!(page, "#jumped [aria-label='1 / 3']:not([inert])", Visible)?

    # Wrap back from the first slide to the last: the track is at the last
    # slide's place right away, with no transition running.
    Playwright.click!(page, "#jumped .carousel-button-prev")?
    wrapped = track!(page)?
    if wrapped.duration != "0s" or !(near(wrapped.x, -2.0 * wrapped.width)) {
        Err(WrapShouldJump(wrapped))?
    } else {
        {}
    }
    Playwright.wait_for!(page, "#jumped [aria-label='3 / 3']:not([inert])", Visible) ? |_| PrevShouldWrapToTheLastSlide

    # A step to the neighbour slides again.
    Playwright.click!(page, "#jumped .carousel-button-prev")?
    stepped = track!(page)?
    if stepped.duration != "0.3s" {
        Err(NeighbourStepShouldSlide(stepped))?
    } else {
        {}
    }

    Playwright.close!(browser)
}

## The jumping carousel's track: its transition duration, its current
## horizontal offset (mid-transition when one runs) and the carousel's width.
track! = |page| {
    expression =
        \\(() => {
        \\    const track = document.querySelector('#jumped .carousel-wrapper');
        \\    const style = getComputedStyle(track);
        \\    const x = new DOMMatrix(style.transform).m41;
        \\    return [style.transitionDuration, x, track.parentElement.clientWidth].join('|');
        \\})()
    raw = Playwright.evaluate!(page, expression) ? |_| EvalFailed(expression)
    match Str.split_on(raw, "|") {
        [duration, x, width] => Ok({ duration, x: F64.from_str(x) ?? 0.0, width: F64.from_str(width) ?? 0.0 })
        _ => Err(UnexpectedTrack(raw))
    }
}

near : F64, F64 -> Bool
near = |a, b| (a - b).abs() < 1.0
