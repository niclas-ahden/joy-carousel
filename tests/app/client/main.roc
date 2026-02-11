app [Model, init!, update!, render] {
    pf: platform "../../../joy/platform/main.roc",
    html: "https://github.com/niclas-ahden/joy-html/releases/download/0.11.0/7rgWAa6Gu3IGfdGl1JKxHQyCBVK9IUbZXbDui0jIZSQ.tar.br",
    carousel: "../../../package/main.roc",
}

import html.Html exposing [Html, div, text, h1, p]
import html.Attribute exposing [style]
import pf.Action exposing [Action]
import carousel.Carousel

Model : {
    games_carousel : Carousel.State,
    drinks_carousel : Result Carousel.State Carousel.InitError,
}

drinks : List Str
drinks = ["Whisky", "Cognac", "Rum"]

games : List Str
games = ["Diablo II", "Diablo II: Resurrected"]

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

    { games_carousel, drinks_carousel }

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
        ],
    )
