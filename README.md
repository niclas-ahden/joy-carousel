# joy-carousel

A carousel/slider component for [Joy](https://github.com/niclas-ahden/joy) applications. Supports touch and mouse drag gestures, navigation buttons, wrap-around, and slide or fade transitions, and follows the WAI-ARIA carousel pattern.

## Example usage

```roc
app [Model, Msg, init, update, render, subscriptions] {
    pf: platform "https://github.com/niclas-ahden/joy/releases/download/0.35.0/FtRCTy7CSPSdS2vLzGJPwYfcGurQfoaADXPNT8aJBBCr.tar.zst",
    # Must be the same joy-html release the Joy platform uses, see "Requirements" below
    html: "https://github.com/niclas-ahden/joy-html/releases/download/0.18.0/6XAQypURmG12GNMHHZmjcXVGtctYy52mmPZoaUMWejRK.tar.zst",
    carousel: "https://github.com/niclas-ahden/joy-carousel/releases/download/0.8.0/9FR5dheLRdURWWECifu1urp2Bu5Jehd6FyGAEyiBWjwy.tar.zst",
}

import html.Html exposing [div, text]
import pf.Effect
import carousel.Carousel

# The carousel holds its slides, here the names of games.
Model : { games : Carousel(Str) }

# The carousel's events arrive wrapped in the app's own message, see render.
Msg : [Games(Carousel.Event)]

subscriptions = |_model| []

init : Str -> (Model, List(Effect(Msg)))
init = |_flags| {
    games = Carousel.new(
        {
            id: "games",
            slides: ["Diablo", "Diablo II", "Diablo II: Lord of Destruction", "Diablo II: Resurrected"],
            navigation: Buttons({ previous: "Previous game", next: "Next game" }),
            label: Labelled("Favourite games"),
        },
    )
    ({ games: games }, [])
}

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |model, msg|
    match msg {
        Games(event) => ({ games: model.games.update(event) }, [])
    }

render : Model -> Html(Msg)
render = |model|
    # Each slide renders with the app's message type, so it can have
    # handlers of its own. The last argument wraps the carousel's events.
    model.games.view(|name, _index| div([], [text(name)]), |event| Games(event))
```

`Carousel.new` takes the carousel element's `id`, its slides and its
accessible name: `label: Labelled("Favourite games")`, or
`label: LabelledBy("games-heading")` to name it after a visible heading by
that element's `id`. Every other field is optional:

| Field | Default | |
|---|---|---|
| `role` | `Region` | `Region` makes the carousel a landmark. `Group` suits a carousel that a page has many of, like the photos on every product card. |
| `transition` | `Slide` | `Slide` moves a horizontal track, `Fade` cross-fades in place. |
| `slides_per_view` | `SlidesPerView.one` | How many slides show at once. `SlidesPerView.from_f64(1.5)?` shows one and half of the next, and rejects zero, negative and non-finite counts. The view stops once the last slide is fully in it, so no empty space shows past the end. |
| `navigation` | `NoButtons` | `Buttons({ previous, next })` renders previous and next buttons with those accessible names. |
| `at_ends` | `Stop` | `Wrap` steps from the end to the start and back. |
| `wraps` | `Slide` | `Jump` puts the slide at the other end in place at once when a `Slide` carousel wraps, instead of sliding back across every slide in between. For slides rendered only near the active one, like a gallery. |
| `slide_label` | `"{number} / {count}"` | Each slide's accessible name in the page's language, like `"Bild {number} av {count}"`. |
| `drag_threshold_px` | `50` | How far a drag has to go to change the slide. |
| `duration_ms` | `300` | How long a slide change animates. |

The carousel's state is hidden. Read it with `slides`, `slide_count`,
`active_index`, `has_previous` and `has_next`, and replace the slides with
`set_slides`, for slides that load after the page does. An empty carousel is
fine.

With several carousels on a page, give each its own tag
(`Msg : [Games(Carousel.Event), Drinks(Carousel.Event)]`) and route on it in
`update`. Navigation outside the carousel sends events of its own, made with
`Carousel.next`, `Carousel.previous` and `Carousel.go_to`:
`Attribute.on_click(Games(Carousel.next))` or
`Attribute.on_click(Games(Carousel.go_to(3)))`.

A drag that starts on a button or a link inside a slide changes the slide
without clicking it. A press only becomes a drag once it moves a few pixels,
so a plain click on a slide's content goes through as usual.

## Accessibility

The carousel follows the [WAI-ARIA carousel pattern](https://www.w3.org/WAI/ARIA/apg/patterns/carousel/).
It is a region or a group, always named by its `label`. Each slide is a
group named by `slide_label`, and the slides sit in a polite live region, so a
screen reader reads the slide that comes into view. The slides out of view are
`inert`, so neither the keyboard nor a screen reader lands on them. The
previous and next buttons are real buttons that control the slides. At the
ends of a carousel that does not wrap they are marked `aria-disabled` rather
than disabled, so a keyboard user who steps to the last slide keeps the focus
on the button. With `prefers-reduced-motion` the slide changes happen at once,
through `carousel.css`. The carousel has no arrow-key handling of its own,
since arrow keys inside a slide (in a text field, say) belong to what is in
the slide.

## Styles

The carousel needs `carousel.css` to lay out at all. Without it every slide
shows, one under the other. Each release carries the `carousel.css` that goes
with it as a release asset. Take the one from the release your app depends on,
since the class names can change between releases, serve it and include it in
your HTML:

```html
<link rel="stylesheet" href="/wherever-you-serve-it-from/carousel.css">
```

Customize with CSS variables:

```css
:root {
    --carousel-navigation-color: #007aff;
}
```

## Limitations

The track moves left to right, so a carousel inside a right-to-left page
(`dir="rtl"`) steps the wrong way.

## Requirements

- The [Joy](https://github.com/niclas-ahden/joy) platform.
- [joy-html](https://github.com/niclas-ahden/joy-html) for HTML rendering. Your
  app must depend on the exact joy-html release URL that the Joy platform and
  this package use (currently 0.18.0). With any other URL the carousel's `Html`
  is a different type than the one your app's `render` has to return.

## Documentation

View the full API documentation at [https://niclas-ahden.github.io/joy-carousel/](https://niclas-ahden.github.io/joy-carousel/).

## Development

`nix develop` provides the pinned Roc compiler and Playwright. The test suite
builds the test app against the Joy release its header names and drives it
with roc-playwright.

```sh
roc check package/main.roc
roc test package/main.roc
./tests.roc        # the probe and the whole browser suite
./tests.roc drag   # only the browser specs whose filename contains "drag"
```

## Status

`joy-carousel` is usable but still in development. Expect breaking changes as the API evolves.
