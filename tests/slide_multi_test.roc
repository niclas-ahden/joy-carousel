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

## Test: Slide (non-fade) mode with slides_per_view 2.0 (#slide_multi, "Pane 1-4").
##
## Covers slides_per_view > 1 in the rendered slide track: each slide is half the
## track width, advancing translates the track left by exactly one slide
## width, and the track stops where the last slide is fully in view.
main! = |_args| {
    # The test server is started once by tests.roc, which passes its address here.
    base_url = Env.var_str!(OsStr.from_str("CAROUSEL_TEST_URL")).ok_or("http://127.0.0.1:9000")
    { browser, page } = Playwright.launch_page!({ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis }, Chromium(DefaultChannel))?

    Playwright.navigate!(page, base_url)?

    Playwright.wait_for!(page, "#slide_multi .carousel-wrapper", Visible)?

    # Each slide is half the track (100% / 2.0).
    width_ratio = eval_num!(page, slide_width_ratio_js)?
    check(width_ratio > 0.45 and width_ratio < 0.55, SlideWidthRatio(width_ratio.to_str()))?

    # Record the first slide's position, advance, and confirm the track
    # shifted left by one slide width.
    slide_width = eval_num!(page, slide_width_px_js)?
    left_before = eval_num!(page, pane1_left_js)?

    Playwright.click!(page, "#slide_multi .carousel-button-next")?
    Playwright.wait_for!(page, "#slide_multi .carousel-button-prev:not(.carousel-button-disabled)", Visible)?
    settle!({})?

    left_after = eval_num!(page, pane1_left_js)?
    shift_ratio = (left_before - left_after) / slide_width
    check(shift_ratio > 0.9 and shift_ratio < 1.1, TrackShiftRatio(shift_ratio.to_str()))?

    # The view stops once the last slide is fully in it. With four slides two
    # at a time that is one more step, after which the next button is
    # unavailable and no empty space shows past the last slide.
    Playwright.click!(page, "#slide_multi .carousel-button-next")?
    Playwright.wait_for!(page, "#slide_multi .carousel-button-next[aria-disabled='true']", Visible) ? |_| NextShouldStopAtTheLastView
    settle!({})?

    gap = eval_num!(page, empty_space_js)?
    check(gap.abs() < 1.0, EmptySpacePastTheLastSlide(gap.to_str()))?

    Playwright.close!(browser)
}

empty_space_js : Str
empty_space_js =
    \\(() => {
    \\    const carousel = document.querySelector('#slide_multi').getBoundingClientRect();
    \\    const last = [...document.querySelectorAll('#slide_multi .carousel-slide')].pop().getBoundingClientRect();
    \\    return String(carousel.right - last.right);
    \\})()

slide_width_ratio_js : Str
slide_width_ratio_js =
    \\(() => {
    \\    const w = document.querySelector('#slide_multi .carousel-wrapper');
    \\    const s = document.querySelector('#slide_multi .carousel-slide');
    \\    return String(s.getBoundingClientRect().width / w.getBoundingClientRect().width);
    \\})()

slide_width_px_js : Str
slide_width_px_js =
    \\(() => {
    \\    const s = document.querySelector('#slide_multi .carousel-slide');
    \\    return String(s.getBoundingClientRect().width);
    \\})()

pane1_left_js : Str
pane1_left_js =
    \\(() => {
    \\    const slides = Array.from(document.querySelectorAll('#slide_multi .carousel-slide'));
    \\    const el = slides.find(s => s.textContent.trim() === 'Pane 1');
    \\    return String(el ? el.getBoundingClientRect().left : NaN);
    \\})()

# Wait out the slide transition (default 300ms) before re-measuring positions.
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
