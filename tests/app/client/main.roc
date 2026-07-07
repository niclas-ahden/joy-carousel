app [Model, init!, update!, render] {
    pf: platform "../../../joy/platform/main.roc",
    html: "https://github.com/niclas-ahden/joy-html/releases/download/0.14.0/IVK93mBqjterEFSYijs67Dkl1rYfu0qGl4PAhSPGET0.tar.br",
    carousel: "../../../package/main.roc",
}

import html.Html exposing [Html, div, text, h1, p]
import html.Attribute exposing [style]
import pf.Action exposing [Action]
import carousel.Carousel

Model : {
    games_carousel : Carousel.State,
    drinks_carousel : Result Carousel.State Carousel.InitError,
    # Fade-mode carousels exercised by the browser tests. `fade_single` is a
    # plain 1-per-view fade; `fade_multi` fades a window of two slides at a time
    # (slides_per_view: 2.0). `slide_multi` is a non-fade multi-per-view, so the
    # browser suite also covers slides_per_view > 1 in slide mode.
    fade_single_carousel : Carousel.State,
    fade_multi_carousel : Carousel.State,
    slide_multi_carousel : Carousel.State,
}

drinks : List Str
drinks = ["Whisky", "Cognac", "Rum"]

games : List Str
games = ["Diablo II", "Diablo II: Resurrected"]

fade_single_slides : List Str
fade_single_slides = ["Solo A", "Solo B", "Solo C"]

fade_multi_slides : List Str
fade_multi_slides = ["Multi 1", "Multi 2", "Multi 3", "Multi 4"]

slide_multi_slides : List Str
slide_multi_slides = ["Pane 1", "Pane 2", "Pane 3", "Pane 4"]

# These carousels are render-only in the test app (no error recovery), so a bad
# config is a test-app bug — crash loudly rather than render a silent fallback.
init_or_crash : Str, Carousel.Config, U64 -> Carousel.State
init_or_crash = |id, config, slide_count|
    when Carousel.init({ id, config, slide_count }) is
        Ok(state) -> state
        Err(_) -> crash "Invalid ${id} carousel"

init! : Str => Model
init! = |_flags|
    config = { Carousel.default_config & navigation: Bool.true }

    # Initializing a carousel can fail for a few reasons (see documentation).
    # When that happens we can handle the error or crash.
    #
    # If our favorite games don't work, let's just crash:
    games_carousel =
        when Carousel.init({ id: "games", config, slide_count: List.len(games) }) is
            Ok(state) -> state
            Err(_) -> crash "Invalid games carousel"

    # Drinks we can do without, so we don't crash, and instead show an error during rendering.
    drinks_carousel = Carousel.init({ id: "drinks", config, slide_count: List.len(drinks) })

    fade_single_config = { config & is_fade: Bool.true }
    fade_single_carousel = init_or_crash("fade_single", fade_single_config, List.len(fade_single_slides))

    fade_multi_config = { config & is_fade: Bool.true, slides_per_view: 2.0 }
    fade_multi_carousel = init_or_crash("fade_multi", fade_multi_config, List.len(fade_multi_slides))

    slide_multi_config = { config & slides_per_view: 2.0 }
    slide_multi_carousel = init_or_crash("slide_multi", slide_multi_config, List.len(slide_multi_slides))

    { games_carousel, drinks_carousel, fade_single_carousel, fade_multi_carousel, slide_multi_carousel }

update! : Model, Str, List U8 => Action Model
update! = |model, raw, payload|
    when Carousel.decode_event(raw, payload) is
        Ok({ id, event }) ->
            when id is
                "games" ->
                    new_state = Carousel.update(model.games_carousel, event)
                    Action.update({ model & games_carousel: new_state })

                "drinks" ->
                    when model.drinks_carousel is
                        Ok(drinks_carousel) ->
                            new_state = Carousel.update(drinks_carousel, event)
                            Action.update({ model & drinks_carousel: Ok(new_state) })

                        _ -> Action.none

                "fade_single" ->
                    new_state = Carousel.update(model.fade_single_carousel, event)
                    Action.update({ model & fade_single_carousel: new_state })

                "fade_multi" ->
                    new_state = Carousel.update(model.fade_multi_carousel, event)
                    Action.update({ model & fade_multi_carousel: new_state })

                "slide_multi" ->
                    new_state = Carousel.update(model.slide_multi_carousel, event)
                    Action.update({ model & slide_multi_carousel: new_state })

                _ ->
                    Action.none

        Err(_) ->
            Action.none

render_slides = |content|
    List.map(
        content,
        |slide_text|
            div(
                [
                    style(
                        [
                            ("display", "flex"),
                            ("align-items", "center"),
                            ("justify-content", "center"),
                            ("height", "200px"),
                            ("background", "#f0f0f0"),
                            ("border", "1px solid #ccc"),
                            ("font-size", "24px"),
                        ],
                    ),
                ],
                [text(slide_text)],
            ),
    )

render : Model -> Html Model
render = |model|

    div(
        [style([("max-width", "600px"), ("margin", "40px auto"), ("padding", "20px")])],
        [
            h1([], [text("Carousel Test")]),
            Carousel.view(model.games_carousel, render_slides(games)),
            when model.drinks_carousel is
                Ok(drinks_carousel) ->
                    Carousel.view(drinks_carousel, render_slides(drinks))

                Err(e) ->
                    p([], [text("Drinks carousel failed to initialize due to: ${Inspect.to_str(e)}")]),
            Carousel.view(model.fade_single_carousel, render_slides(fade_single_slides)),
            Carousel.view(model.fade_multi_carousel, render_slides(fade_multi_slides)),
            Carousel.view(model.slide_multi_carousel, render_slides(slide_multi_slides)),
        ],
    )
