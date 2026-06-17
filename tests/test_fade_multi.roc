app [main!] {
    pf: platform "https://github.com/growthagent/basic-cli/releases/download/0.27.0/G-A6F5ny0IYDx4hmF3t_YPHUSR28c9ZXMBnh0FEJjwk.tar.br",
    playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.5.0/F-pfPFwi-5dx3qsGdMim87i0hfGY3oRHRLXKjYDol-U.tar.br",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.2.0/Cv22_pXKIt82Cz5qzFxdm47SNo81RDx6j4gahQIJvME.tar.br",
}

import pf.Arg
import pf.Cmd
import pf.Env
import pf.Http
import pf.Sleep

import playwright.Playwright {
    cmd_new: Cmd.new,
    cmd_args: Cmd.args,
    cmd_spawn_grouped!: Cmd.spawn_grouped!,
}

import spec.Server {
    env_var!: Env.var!,
    cmd_env: Cmd.env,
    cmd_spawn_grouped!: Cmd.spawn_grouped!,
    http_get!: Http.get_utf8!,
    sleep!: Sleep.millis!,
}

## Test: Fade mode honouring slides_per_view 2.0 (#fade_multi, slides "Multi 1-4").
##
## This is the regression guard for the windowed fade: a window of two slides
## must be active at once, each sized to half the track and laid out *side by
## side* (the old implementation stacked every slide and showed only one). We
## measure the rendered boxes to prove both, then check the window shifts on
## navigation.
main! : List Arg.Arg => Result {} _
main! = |_args|
    Server.with!(
        Cmd.new("./tests/app/server/main"),
        |base_url|
            { browser, page } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(30000) })?

            Playwright.navigate!(page, base_url)?

            Playwright.wait_for!(page, "#fade_multi .carousel-wrapper--fade", Visible)?

            # slides_per_view 2.0 => two slides active, the first two.
            initial_count = active_count!(page, "#fade_multi")?
            check(initial_count == "2", InitialActiveCount(initial_count))?

            initial_active = active_texts!(page, "#fade_multi")?
            check(initial_active == "Multi 1,Multi 2", InitialActiveText(initial_active))?

            # Each slide is sized to ~half the track (100% / 2.0).
            width_ratio = eval_num!(page, slide_width_ratio_js)?
            check(width_ratio > 0.45 && width_ratio < 0.55, SlideWidthRatio(Num.to_str(width_ratio)))?

            # The second slide sits one slide-width to the right of the first —
            # i.e. side by side. If slides were stacked (the old bug) this ratio
            # would be ~0 instead of ~1.
            offset_ratio = eval_num!(page, neighbour_offset_ratio_js)?
            check(offset_ratio > 0.9 && offset_ratio < 1.1, NeighbourOffsetRatio(Num.to_str(offset_ratio)))?

            # Window opacity: both active slides opaque, the next one out.
            settle!({})?

            multi2_opacity = opacity_of!(page, "#fade_multi", "Multi 2")?
            check(multi2_opacity == "1", InWindowOpacity("Multi 2", multi2_opacity))?

            multi3_opacity = opacity_of!(page, "#fade_multi", "Multi 3")?
            check(multi3_opacity == "0", OutOfWindowOpacity("Multi 3", multi3_opacity))?

            # Advance one slide; the window slides to "Multi 2,Multi 3".
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

            Playwright.close!(browser),
    )

slide_width_ratio_js : Str
slide_width_ratio_js =
    """
    (() => {
        const w = document.querySelector('#fade_multi .carousel-wrapper--fade');
        const s = document.querySelector('#fade_multi .carousel-slide--fade');
        return String(s.getBoundingClientRect().width / w.getBoundingClientRect().width);
    })()
    """

neighbour_offset_ratio_js : Str
neighbour_offset_ratio_js =
    """
    (() => {
        const slides = document.querySelectorAll('#fade_multi .carousel-slide--fade');
        const a = slides[0].getBoundingClientRect();
        const b = slides[1].getBoundingClientRect();
        return String((b.left - a.left) / a.width);
    })()
    """

# Wait out the fade transition (default 300ms) before reading computed opacity.
settle! : {} => Result {} []
settle! = |{}|
    {} = Sleep.millis!(500)
    Ok({})

eval! = |page, expression|
    when Playwright.evaluate!(page, expression) is
        Ok(val) -> Ok(val)
        Err(EvaluateReturnedNull) -> Ok("null")
        Err(_) -> Err(EvalFailed(expression))

eval_num! = |page, expression|
    val = eval!(page, expression)?
    Str.to_f64(val) |> Result.map_err(|_| NotANumber(val))

check = |cond, err|
    if cond then Ok({}) else Err(err)

active_count! = |page, container|
    eval!(page, "String(document.querySelectorAll('${container} .carousel-slide--active').length)")

active_texts! = |page, container|
    eval!(page, "Array.from(document.querySelectorAll('${container} .carousel-slide--active')).map(e => e.textContent.trim()).join(',')")

opacity_of! = |page, container, slide_text|
    expr =
        """
        (() => {
            const slides = Array.from(document.querySelectorAll('${container} .carousel-slide--fade'));
            const el = slides.find(s => s.textContent.trim() === '${slide_text}');
            return el ? getComputedStyle(el).opacity : 'missing';
        })()
        """
    eval!(page, expr)
