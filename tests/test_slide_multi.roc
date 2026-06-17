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

## Test: Slide (non-fade) mode with slides_per_view 2.0 (#slide_multi, "Pane 1-4").
##
## Covers slides_per_view > 1 in the rendered slide track: each slide is half the
## track width, and advancing translates the track left by exactly one slide
## width.
main! : List Arg.Arg => Result {} _
main! = |_args|
    Server.with!(
        Cmd.new("./tests/app/server/main"),
        |base_url|
            { browser, page } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(30000) })?

            Playwright.navigate!(page, base_url)?

            Playwright.wait_for!(page, "#slide_multi .carousel-wrapper", Visible)?

            # Each slide is half the track (100% / 2.0).
            width_ratio = eval_num!(page, slide_width_ratio_js)?
            check(width_ratio > 0.45 && width_ratio < 0.55, SlideWidthRatio(Num.to_str(width_ratio)))?

            # Record the first slide's position, advance, and confirm the track
            # shifted left by one slide width.
            slide_width = eval_num!(page, slide_width_px_js)?
            left_before = eval_num!(page, pane1_left_js)?

            Playwright.click!(page, "#slide_multi .carousel-button-next")?
            Playwright.wait_for!(page, "#slide_multi .carousel-button-prev:not(.carousel-button-disabled)", Visible)?
            settle!({})?

            left_after = eval_num!(page, pane1_left_js)?
            shift_ratio = (left_before - left_after) / slide_width
            check(shift_ratio > 0.9 && shift_ratio < 1.1, TrackShiftRatio(Num.to_str(shift_ratio)))?

            Playwright.close!(browser),
    )

slide_width_ratio_js : Str
slide_width_ratio_js =
    """
    (() => {
        const w = document.querySelector('#slide_multi .carousel-wrapper');
        const s = document.querySelector('#slide_multi .carousel-slide');
        return String(s.getBoundingClientRect().width / w.getBoundingClientRect().width);
    })()
    """

slide_width_px_js : Str
slide_width_px_js =
    """
    (() => {
        const s = document.querySelector('#slide_multi .carousel-slide');
        return String(s.getBoundingClientRect().width);
    })()
    """

pane1_left_js : Str
pane1_left_js =
    """
    (() => {
        const slides = Array.from(document.querySelectorAll('#slide_multi .carousel-slide'));
        const el = slides.find(s => s.textContent.trim() === 'Pane 1');
        return String(el ? el.getBoundingClientRect().left : NaN);
    })()
    """

# Wait out the slide transition (default 300ms) before re-measuring positions.
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
