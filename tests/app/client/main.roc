app [Model, Msg, init, update, view, subscriptions] {
    pf: platform "https://github.com/niclas-ahden/joy/releases/download/0.35.0/FtRCTy7CSPSdS2vLzGJPwYfcGurQfoaADXPNT8aJBBCr.tar.zst",
    html: "https://github.com/niclas-ahden/joy-html/releases/download/0.18.0/6XAQypURmG12GNMHHZmjcXVGtctYy52mmPZoaUMWejRK.tar.zst",
    carousel: "../../../package/main.roc",
}

import html.Html exposing [div, text, h1, h2, p, a, button, img]
import html.Attribute exposing [style, id, href, on_click, src, alt]
import pf.Effect
import carousel.Carousel
import carousel.SlidesPerView

Model : {
    # A group rather than a region, for the page has many carousels.
    games : Carousel(Str),
    # Named by the visible heading above it.
    drinks : Carousel(Str),
    # Fade and multi-per-view carousels exercised by the browser tests.
    # `fade_single` is a plain 1-per-view fade, `fade_multi` fades a window of
    # two slides at a time, `slide_multi` slides two per view.
    fade_single : Carousel(Str),
    fade_multi : Carousel(Str),
    slide_multi : Carousel(Str),
    # Slides that are buttons sending the app's own message, and the last one
    # picked.
    picks : Carousel(Str),
    picked : Str,
    # Slides that are links, which a drag must never follow.
    links : Carousel(Str),
    # Image slides, which the browser would otherwise drag natively. Their
    # slide labels are in Swedish.
    photos : Carousel(Str),
    # Wraps round at the ends.
    looped : Carousel(Str),
    # Wraps round at the ends without sliding across the track.
    jumped : Carousel(Str),
}

# Each carousel's events arrive in its own tag, the wrapper the app hands to
# its view. `Picked` comes from the buttons inside the picks slides.
Msg : [
    Games(Carousel.Event),
    Drinks(Carousel.Event),
    FadeSingle(Carousel.Event),
    FadeMulti(Carousel.Event),
    SlideMulti(Carousel.Event),
    Picks(Carousel.Event),
    Picked(Str),
    Links(Carousel.Event),
    Photos(Carousel.Event),
    Looped(Carousel.Event),
    Jumped(Carousel.Event),
]

subscriptions = |_model| []

buttons : [NoButtons, Buttons({ previous : Str, next : Str })]
buttons = Buttons({ previous: "Previous slide", next: "Next slide" })

init : Str -> (Model, List(Effect(Msg)))
init = |_flags| {
    two = SlidesPerView.from_f64(2.0) ?? SlidesPerView.one
    model = {
        games: Carousel.new({ id: "games", slides: ["Diablo II", "Diablo II: Resurrected"], label: Labelled("Games"), role: Group, navigation: buttons }),
        drinks: Carousel.new({ id: "drinks", slides: ["Whisky", "Cognac", "Rum"], label: LabelledBy("drinks-heading"), navigation: buttons }),
        fade_single: Carousel.new({ id: "fade_single", slides: ["Solo A", "Solo B", "Solo C"], label: Labelled("Solo fades"), navigation: buttons, transition: Fade }),
        fade_multi: Carousel.new({ id: "fade_multi", slides: ["Multi 1", "Multi 2", "Multi 3", "Multi 4"], label: Labelled("Multi fades"), navigation: buttons, transition: Fade, slides_per_view: two }),
        slide_multi: Carousel.new({ id: "slide_multi", slides: ["Pane 1", "Pane 2", "Pane 3", "Pane 4"], label: Labelled("Panes"), navigation: buttons, slides_per_view: two }),
        picks: Carousel.new({ id: "picks", slides: ["Apple", "Pear"], label: Labelled("Picks"), navigation: buttons }),
        picked: "",
        links: Carousel.new({ id: "links", slides: ["first", "second"], label: Labelled("Links"), navigation: buttons }),
        photos: Carousel.new({ id: "photos", slides: ["crimson", "seagreen", "steelblue"], label: Labelled("Foton"), navigation: buttons, slide_label: "Bild {number} av {count}" }),
        looped: Carousel.new({ id: "looped", slides: ["Loop 1", "Loop 2", "Loop 3"], label: Labelled("Loops"), navigation: buttons, at_ends: Wrap }),
        jumped: Carousel.new({ id: "jumped", slides: ["Jump 1", "Jump 2", "Jump 3"], label: Labelled("Jumps"), navigation: buttons, at_ends: Wrap, wraps: Jump }),
    }
    (model, [])
}

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |model, msg|
    match msg {
        Games(event) => ({ ..model, games: model.games.update(event) }, [])
        Drinks(event) => ({ ..model, drinks: model.drinks.update(event) }, [])
        FadeSingle(event) => ({ ..model, fade_single: model.fade_single.update(event) }, [])
        FadeMulti(event) => ({ ..model, fade_multi: model.fade_multi.update(event) }, [])
        SlideMulti(event) => ({ ..model, slide_multi: model.slide_multi.update(event) }, [])
        Picks(event) => ({ ..model, picks: model.picks.update(event) }, [])
        Picked(name) => ({ ..model, picked: name }, [])
        Links(event) => ({ ..model, links: model.links.update(event) }, [])
        Photos(event) => ({ ..model, photos: model.photos.update(event) }, [])
        Looped(event) => ({ ..model, looped: model.looped.update(event) }, [])
        Jumped(event) => ({ ..model, jumped: model.jumped.update(event) }, [])
    }

text_slide : Str, U64 -> Html(Msg)
text_slide = |content, _index| slide_box([text(content)])

# Each pick sits in the middle of its slide, clear of the prev/next buttons,
# which overlap the slide's edges.
pick_slide : Str, U64 -> Html(Msg)
pick_slide = |name, _index| slide_box([button([on_click(Picked(name))], [text("Pick ${name}")])])

# A link in the middle of its slide, to a fragment, so following it shows in
# the address without leaving the page.
link_slide : Str, U64 -> Html(Msg)
link_slide = |name, _index| slide_box([a([href("#${name}"), style([("padding", "40px")])], [text("Open ${name}")])])

# A full-slide image, which the browser drags natively unless the carousel
# stops it.
photo_slide : Str, U64 -> Html(Msg)
photo_slide = |colour, index| {
    svg = "<svg xmlns='http://www.w3.org/2000/svg' width='600' height='200'><rect width='600' height='200' fill='${colour}'/></svg>"
    img([src("data:image/svg+xml,${svg}"), alt("Photo ${(index + 1).to_str()}"), style([("display", "block"), ("width", "100%"), ("height", "200px")])])
}

slide_box : List(Html(Msg)) -> Html(Msg)
slide_box = |children|
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
        children,
    )

view : Model -> Html(Msg)
view = |model|
    div(
        [style([("max-width", "600px"), ("margin", "40px auto"), ("padding", "20px")])],
        [
            h1([], [text("Carousel Test")]),
            model.games.view(text_slide, |event| Games(event)),
            # Navigation outside the carousel sends the carousel's own events.
            button([id("games-last"), on_click(Games(Carousel.go_to(1)))], [text("Last game")]),
            h2([id("drinks-heading")], [text("Drinks")]),
            model.drinks.view(text_slide, |event| Drinks(event)),
            model.fade_single.view(text_slide, |event| FadeSingle(event)),
            model.fade_multi.view(text_slide, |event| FadeMulti(event)),
            model.slide_multi.view(text_slide, |event| SlideMulti(event)),
            model.picks.view(pick_slide, |event| Picks(event)),
            p([id("picked")], [text("Picked: ${model.picked}")]),
            model.links.view(link_slide, |event| Links(event)),
            model.photos.view(photo_slide, |event| Photos(event)),
            model.looped.view(text_slide, |event| Looped(event)),
            model.jumped.view(text_slide, |event| Jumped(event)),
        ],
    )
