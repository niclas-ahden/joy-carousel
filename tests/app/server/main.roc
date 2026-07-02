app [Model, init!, respond!] {
    pf: platform "https://github.com/growthagent/basic-webserver/releases/download/0.15.0/HUvmkDBBkVzixg3f4HuJvb4KfEOpRlY4MS_JRbhbna8.tar.br",
    html: "https://github.com/niclas-ahden/joy-html/releases/download/0.13.0/D8dlKh8s_ZJeGZt5U_aeAx9b3KOBSady2jIGX_9of2Q.tar.br",
    shared: "../shared/main.roc",
}

import pf.Http exposing [Request, Response]
import pf.File
import html.Html exposing [Html, html, head, body, meta, title, link, script, div]
import html.Attribute exposing [charset, name, content, rel, href, type, id, lang]
import shared.Shared

Model : {}

init! : {} => Result Model []
init! = |{}| Ok({})

respond! : Request, Model => Result Response [ServerErr Str]_
respond! = |request, _model|
    uri = request.uri
    if uri == "/" then
        serve_app!({})
    else if uri == "/carousel.css" then
        serve_file!("carousel.css", "text/css")
    else if Str.starts_with(uri, "/pkg/") and !(Str.contains(uri, "..")) then
        serve_file!(Str.concat("tests/app/www", uri), content_type_for(uri))
    else
        Ok({ status: 404, headers: [], body: Str.to_utf8("Not found") })

content_type_for : Str -> Str
content_type_for = |path|
    if Str.ends_with(path, ".wasm") then
        "application/wasm"
    else if Str.ends_with(path, ".js") then
        "application/javascript"
    else
        "application/octet-stream"

serve_app! : {} => Result Response [ServerErr Str]_
serve_app! = |{}|
    flags = Shared.encode_model({ initial_slide: 0 })
    html_content = render_page(flags)
    Ok({ status: 200, headers: [{ name: "Content-Type", value: "text/html" }], body: Str.to_utf8(html_content) })

serve_file! : Str, Str => Result Response [ServerErr Str]_
serve_file! = |path, content_type|
    when File.read_bytes!(path) is
        Ok(bytes) -> Ok({ status: 200, headers: [{ name: "Content-Type", value: content_type }], body: bytes })
        Err(_) -> Ok({ status: 404, headers: [], body: Str.to_utf8("File not found") })

render_page : Str -> Str
render_page = |flags|
    page : Html {}
    page =
        html(
            [lang("en")],
            [
                head(
                    [],
                    [
                        meta([charset("UTF-8")]),
                        meta([name("viewport"), content("width=device-width, initial-scale=1.0")]),
                        title([], [Html.text("Carousel Test")]),
                        link([rel("stylesheet"), href("/carousel.css")]),
                    ],
                ),
                body(
                    [],
                    [
                        div([id("app")], []),
                        script(
                            [type("module")],
                            [
                                Html.text(
                                    """
                                    import init, { run } from '/pkg/web.js';
                                    await init();
                                    run('${flags}');
                                    """,
                                ),
                            ],
                        ),
                    ],
                ),
            ],
        )
    Html.ssr_document(page)
