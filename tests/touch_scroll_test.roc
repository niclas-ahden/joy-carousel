app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.32.0/3MnQnCrtfe6XS5qx58MnAGU6iWk8i1N24MYfoejcWeax.tar.zst",
    playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.15.2/BFCzMMp3DePaKT1sLy1m38p7qS5QB3okSVoFy6A1Y3Jf.tar.zst",
}

import pf.Cmd
import pf.Duration
import pf.Env
import pf.OsStr
import playwright.Playwright

## Test: Vertical page scrolling must work on carousels, even after changing slides.
##
## Two gesture methods:
##
## - `touch_scroll!` (CDP `synthesizeScrollGesture`, default source = mouse
##   wheel on desktop) scrolls the page in steps 1 and 3. A touch swipe would
##   be the real thing, but headless Chromium does not scroll the page for a
##   synthetic vertical touch swipe anywhere, not even outside a carousel, so
##   the test cannot drive one.
##
## - `touch_swipe!` (the same CDP gesture with `gestureSourceType: "touch"`)
##   is real touch input, so the browser fires the pointer events the
##   carousel listens to. Step 2 swipes horizontally to change the slide.
##
## A wheel scroll ignores `touch-action`, so step 0 checks the CSS that lets a
## finger scroll the page over a carousel directly: `pan-y` on the carousel.
main! = |_args| {
    # The test server is started once by tests.roc, which passes its address here.
    base_url = Env.var_str!(OsStr.from_str("CAROUSEL_TEST_URL")).ok_or("http://127.0.0.1:9000")
    browser = Playwright.launch_with!({ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis }, { browser_type: Chromium(DefaultChannel), headless: Bool.True, timeout: TimeoutMilliseconds(30000), args: [] }) ? |_| LaunchFailed
    context = Playwright.new_context_with!(browser, { has_touch: Bool.True, permissions: [] }) ? |_| ContextFailed
    page = Playwright.new_page!(context) ? |_| PageFailed

    Playwright.navigate!(page, base_url) ? |_| NavigateFailed
    Playwright.wait_for!(page, "#games", Visible) ? |_| CarouselNotVisible

    # --- Step 0: the carousel leaves vertical panning to the browser ---

    touch_action = eval!(page, "getComputedStyle(document.querySelector('#games')).touchAction")?
    if touch_action != "pan-y" {
        Playwright.close!(browser) ? |_| CloseFailed
        Err(CarouselShouldLeaveVerticalPanningToTheBrowser(touch_action))?
    }

    # The test app page is shorter than the viewport. Inject spacers to make it scrollable.
    _ = eval!(page, add_spacers_js)?
    _ = eval!(page, "document.querySelector('#games').scrollIntoView({block:'center'}); 'ok'")?

    # --- Step 1: Vertical scroll on carousel BEFORE changing slide ---

    scroll_before = eval!(page, "String(Math.round(window.scrollY))")?
    scroll_before_y = F64.from_str(scroll_before).ok_or(0.0)

    box = Playwright.bounding_box!(page, "#games") ? |_| BboxFailed
    center_x = box.x + (box.width / 2.0)
    center_y = box.y + (box.height / 2.0)

    scroll!(page, center_x, center_y, center_x, center_y - 150.0)?

    scroll_after = eval!(page, "String(Math.round(window.scrollY))")?
    scroll_after_y = F64.from_str(scroll_after).ok_or(0.0)

    if scroll_after_y > scroll_before_y {
        {}
    } else {
        Playwright.close!(browser) ? |_| CloseFailed
        Err(VerticalScrollShouldWorkBeforeSlideChange(
            "scrollY before: ${scroll_before_y.to_str()}, after: ${scroll_after_y.to_str()}",
        ))?
    }

    # --- Step 2: Horizontal swipe to change slide ---

    _ = eval!(page, "document.querySelector('#games').scrollIntoView({block:'center'}); 'ok'")?

    box2 = Playwright.bounding_box!(page, "#games") ? |_| BboxFailed
    swipe_x = box2.x + (box2.width / 2.0)
    swipe_y = box2.y + (box2.height / 2.0)

    drag!(page, swipe_x, swipe_y, swipe_x - 300.0, swipe_y)?

    Playwright.wait_for!(page, "#games .carousel-button-prev:not(.carousel-button-disabled)", Visible) ? |_| SlideDidNotChange

    # --- Step 3: Vertical scroll on carousel AFTER changing slide ---

    _ = eval!(page, "document.querySelector('#games').scrollIntoView({block:'center'}); 'ok'")?

    scroll_before_2 = eval!(page, "String(Math.round(window.scrollY))")?
    scroll_before_2_y = F64.from_str(scroll_before_2).ok_or(0.0)

    box3 = Playwright.bounding_box!(page, "#games") ? |_| BboxFailed
    scroll_x = box3.x + (box3.width / 2.0)
    scroll_y = box3.y + (box3.height / 2.0)

    scroll!(page, scroll_x, scroll_y, scroll_x, scroll_y - 150.0)?

    scroll_after_2 = eval!(page, "String(Math.round(window.scrollY))")?
    scroll_after_2_y = F64.from_str(scroll_after_2).ok_or(0.0)

    Playwright.close!(browser) ? |_| CloseFailed

    if scroll_after_2_y > scroll_before_2_y {
        Ok({})
    } else {
        Err(VerticalScrollShouldWorkAfterSlideChange(
            "scrollY before: ${scroll_before_2_y.to_str()}, after: ${scroll_after_2_y.to_str()}",
        ))
    }
}

eval! = |page, expression|
    match Playwright.evaluate!(page, expression) {
        Ok(val) => Ok(val)
        Err(EvaluateReturnedNull) => Ok("null")
        Err(_) => Err(EvalFailed(expression))
    }

scroll! = |page, start_x, start_y, end_x, end_y|
    match Playwright.touch_scroll!(page, { start_x, start_y, end_x, end_y }) {
        Ok(v) => Ok(v)
        Err(_) => Err(ScrollFailed)
    }

drag! = |page, start_x, start_y, end_x, end_y|
    match Playwright.touch_swipe!(page, { start_x, start_y, end_x, end_y }) {
        Ok(v) => Ok(v)
        Err(_) => Err(DragFailed)
    }

add_spacers_js : Str
add_spacers_js =
    \\(() => {
    \\    const app = document.querySelector('#root');
    \\    const spacer = (id) => { const d = document.createElement('div'); d.id = id; d.style.height = '2000px'; d.style.background = '#eee'; return d; };
    \\    document.body.insertBefore(spacer('spacer-top'), document.body.firstChild);
    \\    document.body.appendChild(spacer('spacer-bottom'));
    \\    return 'ok';
    \\})()
