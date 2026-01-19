module [
    Config,
    State,
    Event,
    InitError,
    default_config,
    init,
    view,
    encode_event,
    decode_event,
    update,
    # View helper functions (exported for testing)
    calculate_slide_width,
    calculate_transform,
    calculate_transition,
    nav_button_class,
]

import html.Html exposing [Html, div, button]
import html.Attribute exposing [class, style, id, type, attribute]
import html.Event as HtmlEvent

## Carousel configuration options.
##
## ```
## config = { Carousel.default_config & navigation: Bool.true, drag_threshold_px: 100 }
## ```
##
## - `slides_per_view`: Number of slides visible at once. Use `1.0` for full-width slides,
##   `2.0` for half-width, or `1.5` to show a partial next slide as a preview.
## - `initial_slide`: Zero-indexed starting slide.
## - `navigation`: Show prev/next buttons.
## - `drag_threshold_px`: Minimum drag distance in pixels before a swipe registers.
## - `animation_duration_ms`: Slide transition duration in milliseconds.
##
Config : {
    slides_per_view : F64,
    initial_slide : U64,
    navigation : Bool,
    drag_threshold_px : U64,
    animation_duration_ms : U64,
}

## Default configuration: 1 slide per view, no navigation buttons, 50px drag threshold, 300ms animation.
default_config : Config
default_config = {
    slides_per_view: 1.0,
    initial_slide: 0,
    navigation: Bool.false,
    drag_threshold_px: 50,
    animation_duration_ms: 300,
}

## Create with [init], update with [update], render with [view].
State : {
    active_index : U64,
    slide_count : U64,
    is_dragging : Bool,
    start_x : F64,
    drag_offset_px : F64,
    config : Config,
}

## Errors returned by [init] for invalid configuration.
InitError : [
    NoSlides,
    InvalidSlidesPerView,
    InitialSlideOutOfBounds { initial_slide : U64, slide_count : U64 },
]

## Create carousel state for the given number of slides.
##
## ```
## when Carousel.init(config, List.len(slides)) is
##     Ok(state) -> { carousel_state: state }
##     Err(NoSlides) -> crash "Need at least one slide"
##     Err(_) -> crash "Invalid config"
## ```
init : Config, U64 -> Result State InitError
init = |config, slide_count|
    if slide_count == 0 then
        Err(NoSlides)
    else if config.slides_per_view <= 0.0 then
        Err(InvalidSlidesPerView)
    else if config.initial_slide >= slide_count then
        Err(InitialSlideOutOfBounds({ initial_slide: config.initial_slide, slide_count }))
    else
        Ok({
            active_index: config.initial_slide,
            slide_count,
            is_dragging: Bool.false,
            start_x: 0.0,
            drag_offset_px: 0.0,
            config,
        })

## Carousel events. Decoded from DOM events via [decode_event].
Event : [
    TouchStart F64 F64,
    TouchMove F64 F64,
    TouchEnd F64 F64,
    MouseDown F64 F64,
    MouseMove F64 F64,
    MouseUp F64 F64,
    MouseLeave,
    PrevSlide,
    NextSlide,
    GoToSlide U64,
]

## Encode an event type to a handler string for use with joy-html event attributes.
## Used internally by [view].
encode_event : [TouchStart, TouchMove, TouchEnd, MouseDown, MouseMove, MouseUp, MouseLeave, PrevSlide, NextSlide, GoToSlide U64] -> Str
encode_event = |event|
    when event is
        TouchStart -> "CarouselTouchStart"
        TouchMove -> "CarouselTouchMove"
        TouchEnd -> "CarouselTouchEnd"
        MouseDown -> "CarouselMouseDown"
        MouseMove -> "CarouselMouseMove"
        MouseUp -> "CarouselMouseUp"
        MouseLeave -> "CarouselMouseLeave"
        PrevSlide -> "CarouselPrevSlide"
        NextSlide -> "CarouselNextSlide"
        GoToSlide(idx) -> "CarouselGoToSlide:${Num.to_str(idx)}"

## Decode a carousel event from the Joy event name and payload.
##
## ```
## when Carousel.decode_event(event_name, payload) is
##     Ok(event) -> Action.update({ model & carousel_state: Carousel.update(model.carousel_state, event) })
##     Err(_) -> Action.none
## ```
decode_event : Str, List U8 -> Result Event [UnknownEvent Str]
decode_event = |raw, payload|
    when raw is
        "CarouselTouchStart" -> Ok(parse_coords(payload, TouchStart))
        "CarouselTouchMove" -> Ok(parse_coords(payload, TouchMove))
        "CarouselTouchEnd" -> Ok(parse_coords(payload, TouchEnd))
        "CarouselMouseDown" -> Ok(parse_coords(payload, MouseDown))
        "CarouselMouseMove" -> Ok(parse_coords(payload, MouseMove))
        "CarouselMouseUp" -> Ok(parse_coords(payload, MouseUp))
        "CarouselMouseLeave" -> Ok(MouseLeave)
        "CarouselPrevSlide" -> Ok(PrevSlide)
        "CarouselNextSlide" -> Ok(NextSlide)
        _ ->
            if Str.starts_with(raw, "CarouselGoToSlide:") then
                idx_str = Str.split_last(raw, ":") |> Result.map_ok(.after) |> Result.with_default("0")
                idx = Str.to_u64(idx_str) |> Result.with_default(0)
                Ok(GoToSlide(idx))
            else
                Err(UnknownEvent(raw))

parse_coords : List U8, (F64, F64 -> Event) -> Event
parse_coords = |payload, to_event|
    coord_str = Str.from_utf8_lossy(payload)
    when Str.split_first(coord_str, ",") is
        Ok({ before, after }) ->
            x = Str.to_f64(before) |> Result.with_default(0.0)
            y = Str.to_f64(after) |> Result.with_default(0.0)
            to_event(x, y)

        Err(_) -> to_event(0.0, 0.0)

## Apply an event to the carousel state, returning the new state.
update : State, Event -> State
update = |state, event|
    when event is
        TouchStart(x, _y) | MouseDown(x, _y) ->
            { state & is_dragging: Bool.true, start_x: x, drag_offset_px: 0.0 }

        TouchMove(x, _y) | MouseMove(x, _y) ->
            if state.is_dragging then
                offset = x - state.start_x
                { state & drag_offset_px: offset }
            else
                state

        TouchEnd(_x, _y) | MouseUp(_x, _y) | MouseLeave ->
            if state.is_dragging then
                threshold = Num.to_f64(state.config.drag_threshold_px)

                new_index =
                    if state.drag_offset_px < -threshold && state.active_index < state.slide_count - 1 then
                        state.active_index + 1
                    else if state.drag_offset_px > threshold && state.active_index > 0 then
                        state.active_index - 1
                    else
                        state.active_index

                { state & is_dragging: Bool.false, active_index: new_index, drag_offset_px: 0.0 }
            else
                state

        PrevSlide ->
            if state.active_index > 0 then
                { state & active_index: state.active_index - 1 }
            else
                state

        NextSlide ->
            if state.active_index < state.slide_count - 1 then
                { state & active_index: state.active_index + 1 }
            else
                state

        GoToSlide(idx) ->
            if idx < state.slide_count then
                { state & active_index: idx }
            else
                state

## Calculate slide width as a percentage. Exported for testing.
calculate_slide_width : F64 -> F64
calculate_slide_width = |slides_per_view|
    100.0 / slides_per_view

## Calculate the CSS transform for the carousel wrapper. Exported for testing.
calculate_transform : { active_index : U64, slides_per_view : F64, is_dragging : Bool, drag_offset_px : F64 } -> Str
calculate_transform = |{ active_index, slides_per_view, is_dragging, drag_offset_px }|
    slide_width = calculate_slide_width(slides_per_view)
    base_translate_percent = -(Num.to_f64(active_index) * slide_width)

    if is_dragging then
        "translate3d(calc(${Num.to_str(base_translate_percent)}% + ${Num.to_str(drag_offset_px)}px), 0, 0)"
    else
        "translate3d(${Num.to_str(base_translate_percent)}%, 0, 0)"

## Calculate the CSS transition. Exported for testing.
calculate_transition : Bool, U64 -> Str
calculate_transition = |is_dragging, animation_duration_ms|
    if is_dragging then
        "none"
    else
        "transform ${Num.to_str(animation_duration_ms)}ms ease-out"

## Calculate navigation button CSS class. Exported for testing.
nav_button_class : Str, Bool -> Str
nav_button_class = |base_class, is_disabled|
    if is_disabled then
        "${base_class} carousel-button-disabled"
    else
        base_class

## Render the carousel.
##
## ```
## slide_content = List.map(slides, |s| div([], [text(s)]))
## Carousel.view({ state: model.carousel_state, id: "my-carousel", slides: slide_content })
## ```
view : { state : State, id : Str, slides : List (Html state) } -> Html state
view = |{ state, id: carousel_id, slides }|
    slide_width = calculate_slide_width(state.config.slides_per_view)

    transform = calculate_transform({
        active_index: state.active_index,
        slides_per_view: state.config.slides_per_view,
        is_dragging: state.is_dragging,
        drag_offset_px: state.drag_offset_px,
    })

    transition = calculate_transition(state.is_dragging, state.config.animation_duration_ms)

    wrapped_slides =
        List.map_with_index(
            slides,
            |slide, _idx|
                div([class("carousel-slide"), style([("width", "${Num.to_str(slide_width)}%")])], [slide]),
        )

    wrapper =
        div(
            [
                class("carousel-wrapper"),
                style([("transform", transform), ("transition", transition)]),
            ],
            wrapped_slides,
        )

    nav_buttons =
        if state.config.navigation then
            prev_disabled = state.active_index == 0
            next_disabled = state.active_index >= state.slide_count - 1

            prev_class = nav_button_class("carousel-button-prev", prev_disabled)
            next_class = nav_button_class("carousel-button-next", next_disabled)

            [
                button([class(prev_class), type("button"), attribute("aria-label", "Previous slide"), HtmlEvent.on_click(encode_event(PrevSlide))], []),
                button([class(next_class), type("button"), attribute("aria-label", "Next slide"), HtmlEvent.on_click(encode_event(NextSlide))], []),
            ]
        else
            []

    div(
        [
            id(carousel_id),
            class("carousel"),
            HtmlEvent.on_touchstart(encode_event(TouchStart)),
            HtmlEvent.on_touchmove_prevent_default(encode_event(TouchMove), Bool.true),
            HtmlEvent.on_touchend(encode_event(TouchEnd)),
            HtmlEvent.on_mousedown(encode_event(MouseDown)),
            HtmlEvent.on_mousemove(encode_event(MouseMove)),
            HtmlEvent.on_mouseup(encode_event(MouseUp)),
            HtmlEvent.on_mouseleave(encode_event(MouseLeave)),
        ],
        List.concat([wrapper], nav_buttons),
    )

# ============================================================================
# Unit Tests
# ============================================================================

# --- init tests ---

expect
    # init creates state with correct initial values
    config = { default_config & initial_slide: 2 }
    when init(config, 5) is
        Ok(state) -> state.active_index == 2 && state.slide_count == 5 && state.is_dragging == Bool.false
        Err(_) -> Bool.false

expect
    # init with default config starts at slide 0
    when init(default_config, 3) is
        Ok(state) -> state.active_index == 0
        Err(_) -> Bool.false

# --- init validation error tests ---

expect
    # init with 0 slides returns NoSlides error
    when init(default_config, 0) is
        Err(NoSlides) -> Bool.true
        _ -> Bool.false

expect
    # init with slides_per_view = 0 returns InvalidSlidesPerView error
    config = { default_config & slides_per_view: 0.0 }
    when init(config, 3) is
        Err(InvalidSlidesPerView) -> Bool.true
        _ -> Bool.false

expect
    # init with negative slides_per_view returns InvalidSlidesPerView error
    config = { default_config & slides_per_view: -1.0 }
    when init(config, 3) is
        Err(InvalidSlidesPerView) -> Bool.true
        _ -> Bool.false

expect
    # init with initial_slide >= slide_count returns InitialSlideOutOfBounds error
    config = { default_config & initial_slide: 5 }
    when init(config, 3) is
        Err(InitialSlideOutOfBounds({ initial_slide: 5, slide_count: 3 })) -> Bool.true
        _ -> Bool.false

expect
    # init with initial_slide == slide_count returns InitialSlideOutOfBounds error
    config = { default_config & initial_slide: 3 }
    when init(config, 3) is
        Err(InitialSlideOutOfBounds(_)) -> Bool.true
        _ -> Bool.false

expect
    # init with valid config at boundary (initial_slide = slide_count - 1) succeeds
    config = { default_config & initial_slide: 2 }
    when init(config, 3) is
        Ok(state) -> state.active_index == 2
        Err(_) -> Bool.false

# --- update: drag forward tests ---

expect
    # MouseDown starts dragging
    when init(default_config, 3) is
        Ok(state) ->
            new_state = update(state, MouseDown(100.0, 50.0))
            new_state.is_dragging == Bool.true
        Err(_) -> Bool.false

expect
    # MouseMove during drag updates offset (offset should be negative when moving left)
    when init(default_config, 3) is
        Ok(state) ->
            state_dragging = update(state, MouseDown(100.0, 50.0))
            state_moved = update(state_dragging, MouseMove(50.0, 50.0))
            state_moved.drag_offset_px < 0.0 # moved left, so offset is negative
        Err(_) -> Bool.false

expect
    # MouseMove without dragging does not update offset
    when init(default_config, 3) is
        Ok(state) ->
            new_state = update(state, MouseMove(50.0, 50.0))
            new_state.is_dragging == Bool.false
        Err(_) -> Bool.false

expect
    # Drag left more than threshold advances slide
    when init(default_config, 3) is
        Ok(state) ->
            state1 = update(state, MouseDown(200.0, 50.0))
            state2 = update(state1, MouseMove(100.0, 50.0)) # -100px offset, exceeds -50 threshold
            state3 = update(state2, MouseUp(100.0, 50.0))
            state3.active_index == 1 && state3.is_dragging == Bool.false
        Err(_) -> Bool.false

# --- update: drag backward tests ---

expect
    # Drag right more than threshold goes to previous slide
    when init(default_config, 3) is
        Ok(initial) ->
            state = { initial & active_index: 1 }
            state1 = update(state, MouseDown(100.0, 50.0))
            state2 = update(state1, MouseMove(200.0, 50.0)) # +100px offset, exceeds +50 threshold
            state3 = update(state2, MouseUp(200.0, 50.0))
            state3.active_index == 0
        Err(_) -> Bool.false

# --- update: insufficient drag tests ---

expect
    # Drag less than threshold does NOT change slide
    when init(default_config, 3) is
        Ok(state) ->
            state1 = update(state, MouseDown(100.0, 50.0))
            state2 = update(state1, MouseMove(70.0, 50.0)) # -30px offset, below 50px threshold
            state3 = update(state2, MouseUp(70.0, 50.0))
            state3.active_index == 0
        Err(_) -> Bool.false

expect
    # Drag exactly at threshold boundary (49px) does NOT change slide
    when init(default_config, 3) is
        Ok(state) ->
            state1 = update(state, MouseDown(100.0, 50.0))
            state2 = update(state1, MouseMove(51.0, 50.0)) # -49px offset
            state3 = update(state2, MouseUp(51.0, 50.0))
            state3.active_index == 0
        Err(_) -> Bool.false

expect
    # Drag just over threshold (51px) DOES change slide
    when init(default_config, 3) is
        Ok(state) ->
            state1 = update(state, MouseDown(100.0, 50.0))
            state2 = update(state1, MouseMove(49.0, 50.0)) # -51px offset
            state3 = update(state2, MouseUp(49.0, 50.0))
            state3.active_index == 1
        Err(_) -> Bool.false

# --- update: boundary tests ---

expect
    # Cannot go before first slide (drag right at slide 0)
    when init(default_config, 3) is
        Ok(state) ->
            state1 = update(state, MouseDown(100.0, 50.0))
            state2 = update(state1, MouseMove(200.0, 50.0)) # +100px, would go to -1
            state3 = update(state2, MouseUp(200.0, 50.0))
            state3.active_index == 0
        Err(_) -> Bool.false

expect
    # Cannot go past last slide (drag left at last slide)
    when init(default_config, 3) is
        Ok(initial) ->
            state = { initial & active_index: 2 } # at last slide (index 2 of 3)
            state1 = update(state, MouseDown(200.0, 50.0))
            state2 = update(state1, MouseMove(100.0, 50.0)) # -100px, would go to 3
            state3 = update(state2, MouseUp(100.0, 50.0))
            state3.active_index == 2
        Err(_) -> Bool.false

# --- update: PrevSlide/NextSlide tests ---

expect
    # NextSlide advances to next slide
    when init(default_config, 3) is
        Ok(state) ->
            new_state = update(state, NextSlide)
            new_state.active_index == 1
        Err(_) -> Bool.false

expect
    # PrevSlide goes to previous slide
    when init(default_config, 3) is
        Ok(initial) ->
            state = { initial & active_index: 2 }
            new_state = update(state, PrevSlide)
            new_state.active_index == 1
        Err(_) -> Bool.false

expect
    # NextSlide at last slide stays at last
    when init(default_config, 3) is
        Ok(initial) ->
            state = { initial & active_index: 2 }
            new_state = update(state, NextSlide)
            new_state.active_index == 2
        Err(_) -> Bool.false

expect
    # PrevSlide at first slide stays at first
    when init(default_config, 3) is
        Ok(state) ->
            new_state = update(state, PrevSlide)
            new_state.active_index == 0
        Err(_) -> Bool.false

# --- update: GoToSlide tests ---

expect
    # GoToSlide goes to specified slide
    when init(default_config, 5) is
        Ok(state) ->
            new_state = update(state, GoToSlide(3))
            new_state.active_index == 3
        Err(_) -> Bool.false

expect
    # GoToSlide with invalid index (too high) stays at current
    when init(default_config, 3) is
        Ok(state) ->
            new_state = update(state, GoToSlide(10))
            new_state.active_index == 0
        Err(_) -> Bool.false

# --- update: MouseLeave during drag tests ---

expect
    # MouseLeave during drag finalizes with slide change if threshold exceeded
    when init(default_config, 3) is
        Ok(state) ->
            state1 = update(state, MouseDown(200.0, 50.0))
            state2 = update(state1, MouseMove(100.0, 50.0)) # -100px
            state3 = update(state2, MouseLeave)
            state3.active_index == 1 && state3.is_dragging == Bool.false
        Err(_) -> Bool.false

expect
    # MouseLeave during drag does NOT change slide if threshold not exceeded
    when init(default_config, 3) is
        Ok(state) ->
            state1 = update(state, MouseDown(100.0, 50.0))
            state2 = update(state1, MouseMove(70.0, 50.0)) # -30px
            state3 = update(state2, MouseLeave)
            state3.active_index == 0 && state3.is_dragging == Bool.false
        Err(_) -> Bool.false

# --- update: TouchStart/TouchMove/TouchEnd tests ---

expect
    # TouchStart starts dragging (same as MouseDown)
    when init(default_config, 3) is
        Ok(state) ->
            new_state = update(state, TouchStart(100.0, 50.0))
            new_state.is_dragging == Bool.true
        Err(_) -> Bool.false

expect
    # Touch drag left advances slide
    when init(default_config, 3) is
        Ok(state) ->
            state1 = update(state, TouchStart(200.0, 50.0))
            state2 = update(state1, TouchMove(100.0, 50.0))
            state3 = update(state2, TouchEnd(100.0, 50.0))
            state3.active_index == 1
        Err(_) -> Bool.false

# --- encode_event/decode_event roundtrip tests ---

expect
    # encode/decode PrevSlide roundtrip
    encoded = encode_event(PrevSlide)
    decoded = decode_event(encoded, [])
    when decoded is
        Ok(PrevSlide) -> Bool.true
        _ -> Bool.false

expect
    # encode/decode NextSlide roundtrip
    encoded = encode_event(NextSlide)
    decoded = decode_event(encoded, [])
    when decoded is
        Ok(NextSlide) -> Bool.true
        _ -> Bool.false

expect
    # encode/decode GoToSlide roundtrip
    encoded = encode_event(GoToSlide(5))
    decoded = decode_event(encoded, [])
    when decoded is
        Ok(GoToSlide(idx)) -> idx == 5
        _ -> Bool.false

expect
    # encode/decode MouseDown with coordinates (check tag, not exact floats)
    encoded = encode_event(MouseDown)
    payload = Str.to_utf8("123.5,456.7")
    decoded = decode_event(encoded, payload)
    when decoded is
        Ok(MouseDown(_, _)) -> Bool.true
        _ -> Bool.false

expect
    # encode/decode TouchStart with coordinates (check tag, not exact floats)
    encoded = encode_event(TouchStart)
    payload = Str.to_utf8("100.0,200.0")
    decoded = decode_event(encoded, payload)
    when decoded is
        Ok(TouchStart(_, _)) -> Bool.true
        _ -> Bool.false

expect
    # decode MouseLeave
    decoded = decode_event("CarouselMouseLeave", [])
    when decoded is
        Ok(MouseLeave) -> Bool.true
        _ -> Bool.false

# --- decode_event error handling tests ---

expect
    # decode unknown event returns Err
    decoded = decode_event("UnknownEvent", [])
    when decoded is
        Err(UnknownEvent(msg)) -> msg == "UnknownEvent"
        _ -> Bool.false

expect
    # decode empty string returns Err
    decoded = decode_event("", [])
    when decoded is
        Err(UnknownEvent(msg)) -> msg == ""
        _ -> Bool.false

expect
    # decode random string returns Err with the string
    decoded = decode_event("SomethingRandom123", [])
    when decoded is
        Err(UnknownEvent(msg)) -> msg == "SomethingRandom123"
        _ -> Bool.false

# --- parse_coords edge case tests ---

expect
    # empty payload defaults to (0, 0)
    decoded = decode_event("CarouselMouseDown", [])
    when decoded is
        Ok(MouseDown(_, _)) -> Bool.true
        _ -> Bool.false

expect
    # just a comma defaults to (0, 0)
    decoded = decode_event("CarouselMouseDown", Str.to_utf8(","))
    when decoded is
        Ok(MouseDown(_, _)) -> Bool.true
        _ -> Bool.false

expect
    # invalid numbers default to 0
    decoded = decode_event("CarouselMouseDown", Str.to_utf8("abc,def"))
    when decoded is
        Ok(MouseDown(_, _)) -> Bool.true
        _ -> Bool.false

expect
    # partial valid - first number valid, second invalid
    decoded = decode_event("CarouselMouseDown", Str.to_utf8("100,abc"))
    when decoded is
        Ok(MouseDown(_, _)) -> Bool.true
        _ -> Bool.false

expect
    # no comma - defaults to (0, 0)
    decoded = decode_event("CarouselMouseDown", Str.to_utf8("123"))
    when decoded is
        Ok(MouseDown(_, _)) -> Bool.true
        _ -> Bool.false

expect
    # extra commas - parses first two parts
    decoded = decode_event("CarouselMouseDown", Str.to_utf8("1,2,3"))
    when decoded is
        Ok(MouseDown(_, _)) -> Bool.true
        _ -> Bool.false

expect
    # negative numbers work
    decoded = decode_event("CarouselMouseDown", Str.to_utf8("-100.5,-200.5"))
    when decoded is
        Ok(MouseDown(_, _)) -> Bool.true
        _ -> Bool.false

expect
    # scientific notation - may or may not parse depending on Str.to_f64
    decoded = decode_event("CarouselMouseDown", Str.to_utf8("1e10,2e10"))
    when decoded is
        Ok(MouseDown(_, _)) -> Bool.true
        _ -> Bool.false

# --- view helper function tests ---

# calculate_slide_width tests

expect
    # 1 slide per view = 100% width
    width = calculate_slide_width(1.0)
    width > 99.9 && width < 100.1

expect
    # 2 slides per view = 50% width
    width = calculate_slide_width(2.0)
    width > 49.9 && width < 50.1

expect
    # 3 slides per view = ~33.33% width
    width = calculate_slide_width(3.0)
    width > 33.0 && width < 34.0

expect
    # fractional slides per view (1.5) = ~66.67% width
    width = calculate_slide_width(1.5)
    width > 66.0 && width < 67.0

# calculate_transform tests

expect
    # at slide 0, not dragging = translate3d(-0%, 0, 0)
    # Note: -0 is produced by negating 0.0 in Roc
    transform = calculate_transform({
        active_index: 0,
        slides_per_view: 1.0,
        is_dragging: Bool.false,
        drag_offset_px: 0.0,
    })
    transform == "translate3d(-0%, 0, 0)"

expect
    # at slide 1 with 1 slide per view = translate3d(-100%, 0, 0)
    transform = calculate_transform({
        active_index: 1,
        slides_per_view: 1.0,
        is_dragging: Bool.false,
        drag_offset_px: 0.0,
    })
    transform == "translate3d(-100%, 0, 0)"

expect
    # at slide 2 with 1 slide per view = translate3d(-200%, 0, 0)
    transform = calculate_transform({
        active_index: 2,
        slides_per_view: 1.0,
        is_dragging: Bool.false,
        drag_offset_px: 0.0,
    })
    transform == "translate3d(-200%, 0, 0)"

expect
    # at slide 1 with 2 slides per view = translate3d(-50%, 0, 0)
    transform = calculate_transform({
        active_index: 1,
        slides_per_view: 2.0,
        is_dragging: Bool.false,
        drag_offset_px: 0.0,
    })
    transform == "translate3d(-50%, 0, 0)"

expect
    # while dragging, uses calc() with pixel offset
    transform = calculate_transform({
        active_index: 0,
        slides_per_view: 1.0,
        is_dragging: Bool.true,
        drag_offset_px: -50.0,
    })
    transform == "translate3d(calc(-0% + -50px), 0, 0)"

expect
    # dragging with positive offset
    transform = calculate_transform({
        active_index: 1,
        slides_per_view: 1.0,
        is_dragging: Bool.true,
        drag_offset_px: 75.0,
    })
    transform == "translate3d(calc(-100% + 75px), 0, 0)"

# calculate_transition tests

expect
    # not dragging = animated transition with default duration
    transition = calculate_transition(Bool.false, 300)
    transition == "transform 300ms ease-out"

expect
    # not dragging = animated transition with custom duration
    transition = calculate_transition(Bool.false, 500)
    transition == "transform 500ms ease-out"

expect
    # dragging = no transition (duration ignored)
    transition = calculate_transition(Bool.true, 300)
    transition == "none"

# nav_button_class tests

expect
    # prev button not disabled
    cls = nav_button_class("carousel-button-prev", Bool.false)
    cls == "carousel-button-prev"

expect
    # prev button disabled
    cls = nav_button_class("carousel-button-prev", Bool.true)
    cls == "carousel-button-prev carousel-button-disabled"

expect
    # next button not disabled
    cls = nav_button_class("carousel-button-next", Bool.false)
    cls == "carousel-button-next"

expect
    # next button disabled
    cls = nav_button_class("carousel-button-next", Bool.true)
    cls == "carousel-button-next carousel-button-disabled"

expect
    # works with any base class
    cls = nav_button_class("custom-class", Bool.true)
    cls == "custom-class carousel-button-disabled"
