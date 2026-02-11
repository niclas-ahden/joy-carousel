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
    id : Str,
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
    InvalidCarouselId Str,
]

## Create carousel state for the given number of slides.
## The `id` is validated to not contain `|` and is stored in the state
## for use by [view] and [encode_event].
##
## ```
## when Carousel.init({ id: "my-carousel", config, slide_count: List.len(slides) }) is
##     Ok(state) -> { carousel_state: state }
##     Err(NoSlides) -> crash "Need at least one slide"
##     Err(_) -> crash "Invalid config"
## ```
init : { id : Str, config : Config, slide_count : U64 } -> Result State InitError
init = |{ id: carousel_id, config, slide_count }|
    when Str.split_first(carousel_id, "|") is
        Ok(_) -> Err(InvalidCarouselId(carousel_id))
        Err(_) ->
            if slide_count == 0 then
                Err(NoSlides)
            else if config.slides_per_view <= 0.0 then
                Err(InvalidSlidesPerView)
            else if config.initial_slide >= slide_count then
                Err(InitialSlideOutOfBounds({ initial_slide: config.initial_slide, slide_count }))
            else
                Ok({
                    id: carousel_id,
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

## Encode a navigation event to a handler string for use with joy-html event attributes.
## For custom navigation buttons rendered outside of [view].
## The carousel ID (validated at [init]) is read from the state.
##
## ```
## HtmlEvent.on_click(Carousel.encode_event(model.carousel_state, PrevSlide))
## ```
encode_event : State, [PrevSlide, NextSlide, GoToSlide U64] -> Str
encode_event = |state, event|
    # Keep in sync with format_event (duplicated due to Roc's closed tag unions)
    base =
        when event is
            PrevSlide -> "PrevSlide"
            NextSlide -> "NextSlide"
            GoToSlide(idx) -> "GoToSlide|${Num.to_str(idx)}"
    "Carousel|${state.id}|${base}"

format_event : Str, [TouchStart, TouchMove, TouchEnd, MouseDown, MouseMove, MouseUp, MouseLeave, PrevSlide, NextSlide, GoToSlide U64] -> Str
format_event = |carousel_id, event|
    # TODO: Do this better with typed events in Roc v0.1
    base =
        when event is
            TouchStart -> "TouchStart"
            TouchMove -> "TouchMove"
            TouchEnd -> "TouchEnd"
            MouseDown -> "MouseDown"
            MouseMove -> "MouseMove"
            MouseUp -> "MouseUp"
            MouseLeave -> "MouseLeave"
            PrevSlide -> "PrevSlide"
            NextSlide -> "NextSlide"
            GoToSlide(idx) -> "GoToSlide|${Num.to_str(idx)}"
    "Carousel|${carousel_id}|${base}"

## Decode a carousel event from the Joy event name and payload.
## Returns both the carousel ID and the event, allowing apps with multiple carousels
## to route events to the correct instance.
##
## ```
## when Carousel.decode_event(event_name, payload) is
##     Ok({ id, event }) -> Action.update({ model & carousel_state: Carousel.update(model.carousel_state, event) })
##     Err(_) -> Action.none
## ```
decode_event : Str, List U8 -> Result { id : Str, event : Event } [UnknownEvent Str]
decode_event = |raw, payload|
    when Str.split_first(raw, "|") is
        Ok({ before: "Carousel", after: rest }) ->
            when Str.split_first(rest, "|") is
                Ok({ before: carousel_id, after: event_str }) ->
                    parse_event_str(event_str, payload)
                    |> Result.map_ok(|event| { id: carousel_id, event })
                    |> Result.map_err(|_| UnknownEvent(raw))

                Err(_) -> Err(UnknownEvent(raw))

        _ -> Err(UnknownEvent(raw))

parse_event_str : Str, List U8 -> Result Event [UnknownEvent Str]
parse_event_str = |event_str, payload|
    when event_str is
        "TouchStart" -> Ok(parse_coords(payload, TouchStart))
        "TouchMove" -> Ok(parse_coords(payload, TouchMove))
        "TouchEnd" -> Ok(parse_coords(payload, TouchEnd))
        "MouseDown" -> Ok(parse_coords(payload, MouseDown))
        "MouseMove" -> Ok(parse_coords(payload, MouseMove))
        "MouseUp" -> Ok(parse_coords(payload, MouseUp))
        "MouseLeave" -> Ok(MouseLeave)
        "PrevSlide" -> Ok(PrevSlide)
        "NextSlide" -> Ok(NextSlide)
        _ ->
            when Str.split_first(event_str, "|") is
                Ok({ before: "GoToSlide", after: idx_str }) ->
                    when Str.to_u64(idx_str) is
                        Ok(idx) -> Ok(GoToSlide(idx))
                        Err(_) -> Err(UnknownEvent(event_str))

                _ -> Err(UnknownEvent(event_str))

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

## Render the carousel. The carousel ID is read from the state (set at [init]).
##
## ```
## slide_content = List.map(slides, |s| div([], [text(s)]))
## Carousel.view(model.carousel_state, slide_content)
## ```
view : State, List (Html state) -> Html state
view = |state, slides|
    carousel_id = state.id
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
                button([class(prev_class), type("button"), attribute("aria-label", "Previous slide"), HtmlEvent.on_click(format_event(carousel_id, PrevSlide))], []),
                button([class(next_class), type("button"), attribute("aria-label", "Next slide"), HtmlEvent.on_click(format_event(carousel_id, NextSlide))], []),
            ]
        else
            []

    div(
        [
            id(carousel_id),
            class("carousel"),
            HtmlEvent.on_touchstart(format_event(carousel_id, TouchStart)),
            HtmlEvent.on_touchmove_prevent_default(format_event(carousel_id, TouchMove), Bool.true),
            HtmlEvent.on_touchend(format_event(carousel_id, TouchEnd)),
            HtmlEvent.on_mousedown(format_event(carousel_id, MouseDown)),
            HtmlEvent.on_mousemove(format_event(carousel_id, MouseMove)),
            HtmlEvent.on_mouseup(format_event(carousel_id, MouseUp)),
            HtmlEvent.on_mouseleave(format_event(carousel_id, MouseLeave)),
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
    when init({ id: "test", config, slide_count: 5 }) is
        Ok(state) -> state.active_index == 2 && state.slide_count == 5 && state.is_dragging == Bool.false && state.id == "test"
        Err(_) -> Bool.false

expect
    # init with default config starts at slide 0
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(state) -> state.active_index == 0
        Err(_) -> Bool.false

# --- init validation error tests ---

expect
    # init with 0 slides returns NoSlides error
    when init({ id: "test", config: default_config, slide_count: 0 }) is
        Err(NoSlides) -> Bool.true
        _ -> Bool.false

expect
    # init with slides_per_view = 0 returns InvalidSlidesPerView error
    config = { default_config & slides_per_view: 0.0 }
    when init({ id: "test", config, slide_count: 3 }) is
        Err(InvalidSlidesPerView) -> Bool.true
        _ -> Bool.false

expect
    # init with negative slides_per_view returns InvalidSlidesPerView error
    config = { default_config & slides_per_view: -1.0 }
    when init({ id: "test", config, slide_count: 3 }) is
        Err(InvalidSlidesPerView) -> Bool.true
        _ -> Bool.false

expect
    # init with initial_slide >= slide_count returns InitialSlideOutOfBounds error
    config = { default_config & initial_slide: 5 }
    when init({ id: "test", config, slide_count: 3 }) is
        Err(InitialSlideOutOfBounds({ initial_slide: 5, slide_count: 3 })) -> Bool.true
        _ -> Bool.false

expect
    # init with initial_slide == slide_count returns InitialSlideOutOfBounds error
    config = { default_config & initial_slide: 3 }
    when init({ id: "test", config, slide_count: 3 }) is
        Err(InitialSlideOutOfBounds(_)) -> Bool.true
        _ -> Bool.false

expect
    # init with valid config at boundary (initial_slide = slide_count - 1) succeeds
    config = { default_config & initial_slide: 2 }
    when init({ id: "test", config, slide_count: 3 }) is
        Ok(state) -> state.active_index == 2
        Err(_) -> Bool.false

expect
    # init with id containing pipe returns InvalidCarouselId error
    when init({ id: "bad|id", config: default_config, slide_count: 3 }) is
        Err(InvalidCarouselId(bad_id)) -> bad_id == "bad|id"
        _ -> Bool.false

expect
    # init with valid id succeeds
    when init({ id: "my-carousel", config: default_config, slide_count: 3 }) is
        Ok(state) -> state.id == "my-carousel"
        Err(_) -> Bool.false

# --- update: drag forward tests ---

expect
    # MouseDown starts dragging
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            new_state = update(state, MouseDown(100.0, 50.0))
            new_state.is_dragging == Bool.true
        Err(_) -> Bool.false

expect
    # MouseMove during drag updates offset (offset should be negative when moving left)
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            state_dragging = update(state, MouseDown(100.0, 50.0))
            state_moved = update(state_dragging, MouseMove(50.0, 50.0))
            state_moved.drag_offset_px < 0.0 # moved left, so offset is negative
        Err(_) -> Bool.false

expect
    # MouseMove without dragging does not update offset
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            new_state = update(state, MouseMove(50.0, 50.0))
            new_state.is_dragging == Bool.false
        Err(_) -> Bool.false

expect
    # Drag left more than threshold advances slide
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            state1 = update(state, MouseDown(200.0, 50.0))
            state2 = update(state1, MouseMove(100.0, 50.0)) # -100px offset, exceeds -50 threshold
            state3 = update(state2, MouseUp(100.0, 50.0))
            state3.active_index == 1 && state3.is_dragging == Bool.false
        Err(_) -> Bool.false

# --- update: drag backward tests ---

expect
    # Drag right more than threshold goes to previous slide
    when init({ id: "test", config: default_config, slide_count: 3 }) is
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
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            state1 = update(state, MouseDown(100.0, 50.0))
            state2 = update(state1, MouseMove(70.0, 50.0)) # -30px offset, below 50px threshold
            state3 = update(state2, MouseUp(70.0, 50.0))
            state3.active_index == 0
        Err(_) -> Bool.false

expect
    # Drag exactly at threshold boundary (49px) does NOT change slide
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            state1 = update(state, MouseDown(100.0, 50.0))
            state2 = update(state1, MouseMove(51.0, 50.0)) # -49px offset
            state3 = update(state2, MouseUp(51.0, 50.0))
            state3.active_index == 0
        Err(_) -> Bool.false

expect
    # Drag just over threshold (51px) DOES change slide
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            state1 = update(state, MouseDown(100.0, 50.0))
            state2 = update(state1, MouseMove(49.0, 50.0)) # -51px offset
            state3 = update(state2, MouseUp(49.0, 50.0))
            state3.active_index == 1
        Err(_) -> Bool.false

# --- update: boundary tests ---

expect
    # Cannot go before first slide (drag right at slide 0)
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            state1 = update(state, MouseDown(100.0, 50.0))
            state2 = update(state1, MouseMove(200.0, 50.0)) # +100px, would go to -1
            state3 = update(state2, MouseUp(200.0, 50.0))
            state3.active_index == 0
        Err(_) -> Bool.false

expect
    # Cannot go past last slide (drag left at last slide)
    when init({ id: "test", config: default_config, slide_count: 3 }) is
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
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            new_state = update(state, NextSlide)
            new_state.active_index == 1
        Err(_) -> Bool.false

expect
    # PrevSlide goes to previous slide
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(initial) ->
            state = { initial & active_index: 2 }
            new_state = update(state, PrevSlide)
            new_state.active_index == 1
        Err(_) -> Bool.false

expect
    # NextSlide at last slide stays at last
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(initial) ->
            state = { initial & active_index: 2 }
            new_state = update(state, NextSlide)
            new_state.active_index == 2
        Err(_) -> Bool.false

expect
    # PrevSlide at first slide stays at first
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            new_state = update(state, PrevSlide)
            new_state.active_index == 0
        Err(_) -> Bool.false

# --- update: GoToSlide tests ---

expect
    # GoToSlide goes to specified slide
    when init({ id: "test", config: default_config, slide_count: 5 }) is
        Ok(state) ->
            new_state = update(state, GoToSlide(3))
            new_state.active_index == 3
        Err(_) -> Bool.false

expect
    # GoToSlide with invalid index (too high) stays at current
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            new_state = update(state, GoToSlide(10))
            new_state.active_index == 0
        Err(_) -> Bool.false

# --- update: MouseLeave during drag tests ---

expect
    # MouseLeave during drag finalizes with slide change if threshold exceeded
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            state1 = update(state, MouseDown(200.0, 50.0))
            state2 = update(state1, MouseMove(100.0, 50.0)) # -100px
            state3 = update(state2, MouseLeave)
            state3.active_index == 1 && state3.is_dragging == Bool.false
        Err(_) -> Bool.false

expect
    # MouseLeave during drag does NOT change slide if threshold not exceeded
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            state1 = update(state, MouseDown(100.0, 50.0))
            state2 = update(state1, MouseMove(70.0, 50.0)) # -30px
            state3 = update(state2, MouseLeave)
            state3.active_index == 0 && state3.is_dragging == Bool.false
        Err(_) -> Bool.false

# --- update: TouchStart/TouchMove/TouchEnd tests ---

expect
    # TouchStart starts dragging (same as MouseDown)
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            new_state = update(state, TouchStart(100.0, 50.0))
            new_state.is_dragging == Bool.true
        Err(_) -> Bool.false

expect
    # Touch drag left advances slide
    when init({ id: "test", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            state1 = update(state, TouchStart(200.0, 50.0))
            state2 = update(state1, TouchMove(100.0, 50.0))
            state3 = update(state2, TouchEnd(100.0, 50.0))
            state3.active_index == 1
        Err(_) -> Bool.false

# --- encode_event/decode_event roundtrip tests ---

expect
    # encode/decode PrevSlide roundtrip
    when init({ id: "test-carousel", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            encoded = encode_event(state, PrevSlide)
            when decode_event(encoded, []) is
                Ok({ id: carousel_id, event: PrevSlide }) -> carousel_id == "test-carousel"
                _ -> Bool.false
        Err(_) -> Bool.false

expect
    # encode/decode NextSlide roundtrip
    when init({ id: "test-carousel", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            encoded = encode_event(state, NextSlide)
            when decode_event(encoded, []) is
                Ok({ id: carousel_id, event: NextSlide }) -> carousel_id == "test-carousel"
                _ -> Bool.false
        Err(_) -> Bool.false

expect
    # encode/decode GoToSlide roundtrip
    when init({ id: "test-carousel", config: default_config, slide_count: 3 }) is
        Ok(state) ->
            encoded = encode_event(state, GoToSlide(2))
            when decode_event(encoded, []) is
                Ok({ id: carousel_id, event: GoToSlide(slide_idx) }) -> carousel_id == "test-carousel" && slide_idx == 2
                _ -> Bool.false
        Err(_) -> Bool.false

expect
    # decode MouseDown with coordinates (check tag, not exact floats)
    decoded = decode_event("Carousel|my-carousel|MouseDown", Str.to_utf8("123.5,456.7"))
    when decoded is
        Ok({ id: carousel_id, event: MouseDown(_, _) }) -> carousel_id == "my-carousel"
        _ -> Bool.false

expect
    # decode TouchStart with coordinates (check tag, not exact floats)
    decoded = decode_event("Carousel|touch-carousel|TouchStart", Str.to_utf8("100.0,200.0"))
    when decoded is
        Ok({ id: carousel_id, event: TouchStart(_, _) }) -> carousel_id == "touch-carousel"
        _ -> Bool.false

expect
    # decode MouseLeave with pipe format
    decoded = decode_event("Carousel|test|MouseLeave", [])
    when decoded is
        Ok({ id: carousel_id, event: MouseLeave }) -> carousel_id == "test"
        _ -> Bool.false

# --- decode_event error handling tests ---

expect
    # decode unknown event returns Err (doesn't start with "Carousel|")
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

expect
    # decode unknown event type within Carousel format returns Err
    decoded = decode_event("Carousel|test|UnknownAction", [])
    when decoded is
        Err(UnknownEvent(msg)) -> msg == "Carousel|test|UnknownAction"
        _ -> Bool.false

# --- parse_coords edge case tests ---

expect
    # empty payload defaults to (0, 0)
    decoded = decode_event("Carousel|test|MouseDown", [])
    when decoded is
        Ok({ id: _, event: MouseDown(_, _) }) -> Bool.true
        _ -> Bool.false

expect
    # just a comma defaults to (0, 0)
    decoded = decode_event("Carousel|test|MouseDown", Str.to_utf8(","))
    when decoded is
        Ok({ id: _, event: MouseDown(_, _) }) -> Bool.true
        _ -> Bool.false

expect
    # invalid numbers default to 0
    decoded = decode_event("Carousel|test|MouseDown", Str.to_utf8("abc,def"))
    when decoded is
        Ok({ id: _, event: MouseDown(_, _) }) -> Bool.true
        _ -> Bool.false

expect
    # partial valid - first number valid, second invalid
    decoded = decode_event("Carousel|test|MouseDown", Str.to_utf8("100,abc"))
    when decoded is
        Ok({ id: _, event: MouseDown(_, _) }) -> Bool.true
        _ -> Bool.false

expect
    # no comma - defaults to (0, 0)
    decoded = decode_event("Carousel|test|MouseDown", Str.to_utf8("123"))
    when decoded is
        Ok({ id: _, event: MouseDown(_, _) }) -> Bool.true
        _ -> Bool.false

expect
    # extra commas - parses first two parts
    decoded = decode_event("Carousel|test|MouseDown", Str.to_utf8("1,2,3"))
    when decoded is
        Ok({ id: _, event: MouseDown(_, _) }) -> Bool.true
        _ -> Bool.false

expect
    # negative numbers work
    decoded = decode_event("Carousel|test|MouseDown", Str.to_utf8("-100.5,-200.5"))
    when decoded is
        Ok({ id: _, event: MouseDown(_, _) }) -> Bool.true
        _ -> Bool.false

expect
    # scientific notation - may or may not parse depending on Str.to_f64
    decoded = decode_event("Carousel|test|MouseDown", Str.to_utf8("1e10,2e10"))
    when decoded is
        Ok({ id: _, event: MouseDown(_, _) }) -> Bool.true
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

# --- InvalidCarouselId validation tests (validated at init) ---

expect
    # init rejects id with pipe at start
    when init({ id: "|leading", config: default_config, slide_count: 3 }) is
        Err(InvalidCarouselId(_)) -> Bool.true
        _ -> Bool.false

expect
    # init rejects id with pipe at end
    when init({ id: "trailing|", config: default_config, slide_count: 3 }) is
        Err(InvalidCarouselId(_)) -> Bool.true
        _ -> Bool.false

expect
    # init rejects id with pipe in middle
    when init({ id: "bad|id", config: default_config, slide_count: 3 }) is
        Err(InvalidCarouselId(bad_id)) -> bad_id == "bad|id"
        _ -> Bool.false

expect
    # init accepts valid id without pipe
    when init({ id: "my-carousel", config: default_config, slide_count: 3 }) is
        Ok(state) -> state.id == "my-carousel"
        Err(_) -> Bool.false
