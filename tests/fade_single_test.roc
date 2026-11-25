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

## Test: Fade mode with slides_per_view 1.0 (#fade_single, slides "Solo A/B/C").
##
## Verifies the *rendered* result, not just the class strings the unit tests
## cover: exactly one slide is in the active window, it's the right one, and the
## CSS actually drives its opacity to 1 while the others sit at 0. Navigation
## moves the window and the opacity follows.
main! = |_args| {
    # The test server is started once by tests.roc, which passes its address here.
    base_url = Env.var_str!(OsStr.from_str("CAROUSEL_TEST_URL")).ok_or("http://127.0.0.1:9000")
    { browser, page } = Playwright.launch_page!({ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis }, Chromium(DefaultChannel))?

    Playwright.navigate!(page, base_url)?

    # The wrapper opts into fade layout.
    Playwright.wait_for!(page, "#fade_single .carousel-wrapper--fade", Visible)?

    # Initially exactly one slide is active, and it's the first.
    initial_count = active_count!(page, "#fade_single")?
    check(initial_count == "1", InitialActiveCount(initial_count))?

    initial_active = active_texts!(page, "#fade_single")?
    check(initial_active == "Solo A", InitialActiveText(initial_active))?

    # Let the initial paint settle, then the CSS opacity must match the
    # active class: active slide fully opaque, others fully transparent.
    settle!({})?

    solo_a_opacity = opacity_of!(page, "#fade_single", "Solo A")?
    check(solo_a_opacity == "1", ActiveOpacity("Solo A", solo_a_opacity))?

    solo_b_opacity = opacity_of!(page, "#fade_single", "Solo B")?
    check(solo_b_opacity == "0", InactiveOpacity("Solo B", solo_b_opacity))?

    # Advance one slide, and the window moves to "Solo B".
    Playwright.click!(page, "#fade_single .carousel-button-next")?
    Playwright.wait_for!(page, "#fade_single .carousel-slide--active >> text=Solo B", Visible)?

    after_count = active_count!(page, "#fade_single")?
    check(after_count == "1", AfterNextActiveCount(after_count))?

    after_active = active_texts!(page, "#fade_single")?
    check(after_active == "Solo B", AfterNextActiveText(after_active))?

    # And the opacity follows the moved window after the transition.
    settle!({})?

    solo_b_after = opacity_of!(page, "#fade_single", "Solo B")?
    check(solo_b_after == "1", AfterNextActiveOpacity(solo_b_after))?

    solo_a_after = opacity_of!(page, "#fade_single", "Solo A")?
    check(solo_a_after == "0", AfterNextInactiveOpacity(solo_a_after))?

    Playwright.close!(browser)
}

# Wait out the fade transition (default 300ms) before reading computed opacity.
settle! = |{}| {
    Sleep.millis!(500)?
    Ok({})
}

eval! = |page, expression|
    match Playwright.evaluate!(page, expression) {
        Ok(val) => Ok(val)
        Err(EvaluateReturnedNull) => Ok("null")
        Err(_) => Err(EvalFailed(expression))
    }

check = |cond, err|
    if cond { Ok({}) } else { Err(err) }

active_count! = |page, container|
    eval!(page, "String(document.querySelectorAll('${container} .carousel-slide--active').length)")

active_texts! = |page, container|
    eval!(page, "Array.from(document.querySelectorAll('${container} .carousel-slide--active')).map(e => e.textContent.trim()).join(',')")

opacity_of! = |page, container, slide_text| {
    expr =
        \\(() => {
        \\    const slides = Array.from(document.querySelectorAll('${container} .carousel-slide--fade'));
        \\    const el = slides.find(s => s.textContent.trim() === '${slide_text}');
        \\    return el ? getComputedStyle(el).opacity : 'missing';
        \\})()
    eval!(page, expr)
}
