# joy-carousel

A carousel/slider component for [Joy](https://github.com/niclas-ahden/joy) applications. Supports touch and mouse drag gestures, navigation buttons, and smooth animations.

## Example usage

```roc
app [Model, init!, update!, render] {
    pf: platform "../joy/main.roc", # Joy doesn't have releases, and must be vendored in your project
    html: "https://github.com/niclas-ahden/joy-html/releases/download/0.11.0/7rgWAa6Gu3IGfdGl1JKxHQyCBVK9IUbZXbDui0jIZSQ.tar.br",
    carousel: "https://github.com/niclas-ahden/joy-carousel/releases/download/0.1.0/xCFoGhzq7hvFUSUeWiXRvaiMFxO9FWzONVL7-MwxZNE.tar.br",
}

import html.Html exposing [div, text]
import pf.Action exposing [Action]
import carousel.Carousel

Model : { carousel_state : Carousel.State }

slides : List Str
slides = ["Slide 1", "Slide 2", "Slide 3"]

init! : Str => Model
init! = |_flags|
    config = { Carousel.default_config & navigation: Bool.true }
    carousel_state =
        when Carousel.init(config, List.len(slides)) is
            Ok(state) -> state
            Err(_) -> crash "Invalid carousel configuration"
    { carousel_state }

update! : Model, Str, List U8 => Action Model
update! = |model, event_name, payload|
    when Carousel.decode_event(event_name, payload) is
        Ok(event) ->
            new_state = Carousel.update(model.carousel_state, event)
            Action.update({ model & carousel_state: new_state })
        Err(_) ->
            Action.none

render : Model -> Html Model
render = |model|
    slide_content = List.map(slides, |s| div([], [text(s)]))
    Carousel.view({ state: model.carousel_state, id: "my-carousel", slides: slide_content })
```

## Styles

Copy `carousel.css` from this repository into a fitting location for you to serve it and include it in your HTML:

```html
<link rel="stylesheet" href="/wherever-you-serve-it-from/carousel.css">
```

Customize with CSS variables:

```css
:root {
    --carousel-navigation-color: #007aff;
    --carousel-pagination-color: #000;
    --carousel-pagination-bullet-active-color: #007aff;
}
```

## Requirements

- [Joy](https://github.com/niclas-ahden/joy) platform
- [joy-html](https://github.com/niclas-ahden/joy-html) for HTML rendering

## Documentation

View the full API documentation at [https://niclas-ahden.github.io/joy-carousel/](https://niclas-ahden.github.io/joy-carousel/).

## Status

`joy-carousel` is usable but still in development. Expect breaking changes as the API evolves. We're using the old Rust-based Roc compiler and will migrate to the new Zig-based one when possible.
