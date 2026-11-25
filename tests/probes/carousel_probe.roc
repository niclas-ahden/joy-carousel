app [main!] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.28.1/7brgwR8YUqfeGrkdfF1V4GPPN7DnP7ftqub9KcrTEZtr.tar.zst",
    html: "https://github.com/niclas-ahden/joy-html/releases/download/0.18.0/6XAQypURmG12GNMHHZmjcXVGtctYy52mmPZoaUMWejRK.tar.zst",
    carousel: "../../package/main.roc",
}

import pf.Stdout
import html.Html
import carousel.Carousel
import carousel.SlidesPerView

## Behavior probe for the carousel package, built and run by ./tests.roc.
## The expects in package/Carousel.roc cover the pure logic under `roc test`.
## This app covers what they cannot reach from inside the package: the public
## surface used the way an app uses it, including rendering the view to HTML
## through joy-html. It prints one PASS/FAIL line per check.
main! = |_args| {
    failed = print_checks!(build_checks({}), 0, Bool.False)?
    if failed {
        Err(Exit(1))
    } else {
        Ok({})
    }
}

print_checks! : List({ label : Str, ok : Bool }), U64, Bool => Try(Bool, _)
print_checks! = |checks, idx, any_failed|
    match checks.get(idx) {
        Ok(check) => {
            if check.ok {
                Stdout.line!("PASS: ${check.label}")?
            } else {
                Stdout.line!("FAIL: ${check.label}")?
            }
            print_checks!(checks, idx + 1, any_failed or !check.ok)
        }
        Err(_) => Ok(any_failed)
    }

# An app's model holds a carousel of its own slide type and names the
# carousel's events in its messages.
Msg : [ProbeCarousel(Carousel.Event)]

build_checks : {} -> List({ label : Str, ok : Bool })
build_checks = |{}| {
    # Every optional field left out takes its default.
    plain = Carousel.new({ id: "probe", slides: ["one", "two", "three"], label: Labelled("Probe") })

    defaults =
        plain.active_index() == 0
        and plain.slide_count() == 3
        and plain.slides() == ["one", "two", "three"]
        and !plain.has_previous()
        and plain.has_next()

    steps =
        plain.update(Carousel.next).active_index() == 1
        and plain.update(Carousel.go_to(2)).update(Carousel.previous).active_index() == 1
        and plain.update(Carousel.go_to(9)).active_index() == 0

    wraps = {
        looped = Carousel.new({ id: "probe", slides: ["one", "two", "three"], label: Labelled("Probe"), at_ends: Wrap })
        looped.update(Carousel.previous).active_index() == 2 and looped.has_previous()
    }

    stops_at_the_last_view = {
        two = SlidesPerView.from_f64(2.0) ?? SlidesPerView.one
        panes = Carousel.new({ id: "probe", slides: ["one", "two", "three", "four"], label: Labelled("Probe"), slides_per_view: two })
        at_end = panes.update(Carousel.go_to(3))
        at_end.active_index() == 2 and !at_end.has_next()
    }

    grows = {
        later = Carousel.new({ id: "probe", slides: [], label: Labelled("Probe") })
        grown = later.set_slides(["one", "two"])
        later.slide_count() == 0 and grown.slide_count() == 2 and grown.has_next()
    }

    rejects_bad_slides_per_view =
        SlidesPerView.from_f64(0.0).is_err()
        and SlidesPerView.from_f64(-2.0).is_err()
        and SlidesPerView.from_f64(1.5).is_ok()

    view_renders = {
        with_buttons = Carousel.new({ id: "probe", slides: ["one", "two"], navigation: Buttons({ previous: "Back", next: "On" }), label: Labelled("Probe") })
        rendered = Html.render(with_buttons.view(slide, |event| ProbeCarousel(event)))
        rendered.contains("id=\"probe\"")
        and rendered.contains("role=\"region\" aria-roledescription=\"carousel\" aria-label=\"Probe\"")
        and rendered.contains("id=\"probe-slides\" aria-live=\"polite\"")
        and rendered.contains("translate3d(0%, 0, 0)")
        and rendered.contains("aria-label=\"Back\" aria-controls=\"probe-slides\" aria-disabled=\"true\"")
        and rendered.contains("<div>one 0</div>")
        and rendered.contains("aria-label=\"2 / 2\" inert><div>two 1</div>")
    }

    fade_view_renders = {
        fading = Carousel.new({ id: "probe", slides: ["one", "two"], label: Labelled("Probe"), transition: Fade })
        rendered = Html.render(fading.view(slide, |event| ProbeCarousel(event)))
        rendered.contains("carousel-wrapper--fade")
        and rendered.contains("carousel-slide--active")
        and rendered.contains("--carousel-fade-duration: 300ms")
    }

    [
        { label: "new fills in the defaults", ok: defaults },
        { label: "next, previous and go_to move within bounds", ok: steps },
        { label: "at_ends: Wrap steps round the ends", ok: wraps },
        { label: "two per view stops where the last slide is in view", ok: stops_at_the_last_view },
        { label: "set_slides fills an empty carousel", ok: grows },
        { label: "SlidesPerView rejects zero and negative counts", ok: rejects_bad_slides_per_view },
        { label: "view renders slides, landmark and buttons via SSR", ok: view_renders },
        { label: "fade mode view renders the fade classes", ok: fade_view_renders },
    ]
}

slide : Str, U64 -> Html(Msg)
slide = |content, index| Html.div([], [Html.text("${content} ${index.to_str()}")])
