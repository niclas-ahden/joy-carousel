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

## Test: Vertical page scrolling must work on carousels, even after changing slides.
##
## We use two different touch simulation methods because neither alone can test both
## native scrolling and JS-driven interactions:
##
## - `touch_scroll!` (CDP `synthesizeScrollGesture`): triggers real compositor-level
##   scrolling that respects `touch-action` CSS, but does NOT fire JS event handlers.
##   Used for steps 1 and 3 to verify vertical scrolling works.
##
## - `touch_drag!` (synthetic JS `TouchEvent`s): fires JS `addEventListener`
##   handlers (so the carousel processes the drag), but does NOT trigger native
##   browser scrolling. Used for step 2 to change the active slide.
main! : List Arg.Arg => Result {} _
main! = |_args|
    Server.with!(
        Cmd.new("./tests/app/server/main"),
        |base_url|
            browser = Playwright.launch_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(30000) })
                |> Result.map_err(|_| LaunchFailed)?
            context = Playwright.new_context_with!(browser, { has_touch: Bool.true })
                |> Result.map_err(|_| ContextFailed)?
            page = Playwright.new_page!(context)
                |> Result.map_err(|_| PageFailed)?

            Playwright.navigate!(page, base_url) |> Result.map_err(|_| NavigateFailed)?
            Playwright.wait_for!(page, "#games", Visible) |> Result.map_err(|_| CarouselNotVisible)?

            # The test app page is shorter than the viewport. Inject spacers to make it scrollable.
            _ = eval!(page, add_spacers_js)?
            _ = eval!(page, "document.querySelector('#games').scrollIntoView({block:'center'}); 'ok'")?

            # --- Step 1: Vertical scroll on carousel BEFORE changing slide ---

            scroll_before = eval!(page, "String(Math.round(window.scrollY))")?
            scroll_before_y = Str.to_f64(scroll_before) |> Result.with_default(0.0)

            box = Playwright.bounding_box!(page, "#games") |> Result.map_err(|_| BboxFailed)?
            center_x = box.x + (box.width / 2.0)
            center_y = box.y + (box.height / 2.0)

            scroll!(page, center_x, center_y, center_x, center_y - 150.0)?

            scroll_after = eval!(page, "String(Math.round(window.scrollY))")?
            scroll_after_y = Str.to_f64(scroll_after) |> Result.with_default(0.0)

            if !(scroll_after_y > scroll_before_y) then
                Playwright.close!(browser) |> Result.map_err(|_| CloseFailed)?
                Err(VerticalScrollShouldWorkBeforeSlideChange(
                    "scrollY before: ${Num.to_str(scroll_before_y)}, after: ${Num.to_str(scroll_after_y)}",
                ))?
            else
                {}

            # --- Step 2: Horizontal swipe to change slide ---

            _ = eval!(page, "document.querySelector('#games').scrollIntoView({block:'center'}); 'ok'")?

            box2 = Playwright.bounding_box!(page, "#games") |> Result.map_err(|_| BboxFailed)?
            swipe_x = box2.x + (box2.width / 2.0)
            swipe_y = box2.y + (box2.height / 2.0)

            drag!(page, swipe_x, swipe_y, swipe_x - 300.0, swipe_y)?

            Playwright.wait_for!(page, "#games .carousel-button-prev:not(.carousel-button-disabled)", Visible)
            |> Result.map_err(|_| SlideDidNotChange)?

            # --- Step 3: Vertical scroll on carousel AFTER changing slide ---

            _ = eval!(page, "document.querySelector('#games').scrollIntoView({block:'center'}); 'ok'")?

            scroll_before_2 = eval!(page, "String(Math.round(window.scrollY))")?
            scroll_before_2_y = Str.to_f64(scroll_before_2) |> Result.with_default(0.0)

            box3 = Playwright.bounding_box!(page, "#games") |> Result.map_err(|_| BboxFailed)?
            scroll_x = box3.x + (box3.width / 2.0)
            scroll_y = box3.y + (box3.height / 2.0)

            scroll!(page, scroll_x, scroll_y, scroll_x, scroll_y - 150.0)?

            scroll_after_2 = eval!(page, "String(Math.round(window.scrollY))")?
            scroll_after_2_y = Str.to_f64(scroll_after_2) |> Result.with_default(0.0)

            Playwright.close!(browser) |> Result.map_err(|_| CloseFailed)?

            if !(scroll_after_2_y > scroll_before_2_y) then
                Err(VerticalScrollShouldWorkAfterSlideChange(
                    "scrollY before: ${Num.to_str(scroll_before_2_y)}, after: ${Num.to_str(scroll_after_2_y)}",
                ))
            else
                Ok({}),
    )

eval! = |page, expression|
    when Playwright.evaluate!(page, expression) is
        Ok(val) -> Ok(val)
        Err(EvaluateReturnedNull) -> Ok("null")
        Err(_) -> Err(EvalFailed(expression))

scroll! = |page, start_x, start_y, end_x, end_y|
    Playwright.touch_scroll!(page, { start_x, start_y, end_x, end_y })
    |> Result.map_err(|_| ScrollFailed)

drag! = |page, start_x, start_y, end_x, end_y|
    Playwright.touch_drag!(page, { start_x, start_y, end_x, end_y })
    |> Result.map_err(|_| DragFailed)

add_spacers_js : Str
add_spacers_js =
    """
    (() => {
        const app = document.querySelector('#app');
        const spacer = (id) => { const d = document.createElement('div'); d.id = id; d.style.height = '2000px'; d.style.background = '#eee'; return d; };
        document.body.insertBefore(spacer('spacer-top'), document.body.firstChild);
        document.body.appendChild(spacer('spacer-bottom'));
        return 'ok';
    })()
    """
