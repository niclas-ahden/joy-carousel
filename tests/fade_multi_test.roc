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

## Test: Fade mode honouring slides_per_view 2.0 (#fade_multi, slides "Multi 1-4").
##
## This is the regression guard for the windowed fade: a window of two slides
## must be active at once, each sized to half the track and laid out *side by
## side* (the old implementation stacked every slide and showed only one). We
## measure the rendered boxes to prove both, then check the window shifts on
## navigation.
main! = |_args| {
    # The test server is started once by tests.roc, which passes its address here.
    base_url = Env.var_str!(OsStr.from_str("CAROUSEL_TEST_URL")).ok_or("http://127.0.0.1:9000")
    { browser, page } = Playwright.launch_page!({ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis }, Chromium(DefaultChannel))?

    Playwright.navigate!(page, base_url)?

    Playwright.wait_for!(page, "#fade_multi .carousel-wrapper--fade", Visible)?

    # slides_per_view 2.0 => two slides active, the first two.
    initial_count = active_count!(page, "#fade_multi")?
    check(initial_count == "2", InitialActiveCount(initial_count))?

    initial_active = active_texts!(page, "#fade_multi")?
    check(initial_active == "Multi 1,Multi 2", InitialActiveText(initial_active))?

    # Each slide is sized to ~half the track (100% / 2.0).
    width_ratio = eval_num!(page, slide_width_ratio_js)?
    check(width_ratio > 0.45 and width_ratio < 0.55, SlideWidthRatio(width_ratio.to_str()))?

    # The second slide sits one slide-width to the right of the first, side
    # by side. If slides were stacked (the old bug) this ratio would be ~0
    # instead of ~1.
    offset_ratio = eval_num!(page, neighbour_offset_ratio_js)?
    check(offset_ratio > 0.9 and offset_ratio < 1.1, NeighbourOffsetRatio(offset_ratio.to_str()))?

    # Window opacity: both active slides opaque, the next one out.
    settle!({})?

    multi2_opacity = opacity_of!(page, "#fade_multi", "Multi 2")?
    check(multi2_opacity == "1", InWindowOpacity("Multi 2", multi2_opacity))?

    multi3_opacity = opacity_of!(page, "#fade_multi", "Multi 3")?
    check(multi3_opacity == "0", OutOfWindowOpacity("Multi 3", multi3_opacity))?

    # Advance one slide, and the window slides to "Multi 2,Multi 3".
    Playwright.click!(page, "#fade_multi .carousel-button-next")?
    Playwright.wait_for!(page, "#fade_multi .carousel-slide--active >> text=Multi 3", Visible)?

    after_count = active_count!(page, "#fade_multi")?
    check(after_count == "2", AfterNextActiveCount(after_count))?

    after_active = active_texts!(page, "#fade_multi")?
    check(after_active == "Multi 2,Multi 3", AfterNextActiveText(after_active))?

    settle!({})?

    multi1_after = opacity_of!(page, "#fade_multi", "Multi 1")?
    check(multi1_after == "0", AfterNextDroppedOpacity(multi1_after))?

    multi3_after = opacity_of!(page, "#fade_multi", "Multi 3")?
    check(multi3_after == "1", AfterNextAddedOpacity(multi3_after))?

    Playwright.close!(browser)
}

slide_width_ratio_js : Str
slide_width_ratio_js =
    \\(() => {
    \\    const w = document.querySelector('#fade_multi .carousel-wrapper--fade');
    \\    const s = document.querySelector('#fade_multi .carousel-slide--fade');
    \\    return String(s.getBoundingClientRect().width / w.getBoundingClientRect().width);
    \\})()

neighbour_offset_ratio_js : Str
neighbour_offset_ratio_js =
    \\(() => {
    \\    const slides = document.querySelectorAll('#fade_multi .carousel-slide--fade');
    \\    const a = slides[0].getBoundingClientRect();
    \\    const b = slides[1].getBoundingClientRect();
    \\    return String((b.left - a.left) / a.width);
    \\})()

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

eval_num! = |page, expression| {
    val = eval!(page, expression)?
    F64.from_str(val).map_err(|_| NotANumber(val))
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
