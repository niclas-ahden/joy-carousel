app [Model, init!, update!, render] {
    pf: platform "../../../joy/platform/main.roc",
    html: "https://github.com/niclas-ahden/joy-html/releases/download/0.11.0/7rgWAa6Gu3IGfdGl1JKxHQyCBVK9IUbZXbDui0jIZSQ.tar.br",
    carousel: "../../../package/main.roc",
    shared: "../shared/main.roc",
}

import html.Html exposing [Html, div, text, h1, p]
import html.Attribute exposing [style]
import pf.Action exposing [Action]
import carousel.Carousel

Model : {
    carousel_state : Carousel.State,
}

slides : List Str
slides = ["Slide 1", "Slide 2", "Slide 3", "Slide 4"]

init! : Str => Model
init! = |_flags|
    config = { Carousel.default_config & navigation: Bool.true }
    carousel_state =
        when Carousel.init(config, List.len(slides)) is
            Ok(state) -> state
            Err(_) -> crash "Invalid carousel configuration"
    { carousel_state }

update! : Model, Str, List U8 => Action Model
update! = |model, raw, payload|
    when Carousel.decode_event(raw, payload) is
        Ok(event) ->
            new_carousel_state = Carousel.update(model.carousel_state, event)
            Action.update({ model & carousel_state: new_carousel_state })

        Err(_) ->
            # Unknown event - ignore and keep current state
            Action.none

render : Model -> Html Model
render = |model|
    slide_content =
        List.map(
            slides,
            |slide_text|
                div(
                    [
                        style([
                            ("display", "flex"),
                            ("align-items", "center"),
                            ("justify-content", "center"),
                            ("height", "200px"),
                            ("background", "#f0f0f0"),
                            ("border", "1px solid #ccc"),
                            ("font-size", "24px"),
                        ]),
                    ],
                    [text(slide_text)],
                ),
        )

    div(
        [style([("max-width", "600px"), ("margin", "40px auto"), ("padding", "20px")])],
        [
            h1([], [text("Carousel Test")]),
            p([], [text("Active slide: ${Num.to_str(model.carousel_state.active_index)}")]),
            Carousel.view({ state: model.carousel_state, id: "test-carousel", slides: slide_content }),
        ],
    )
