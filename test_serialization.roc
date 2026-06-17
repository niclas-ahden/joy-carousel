app [main!] {
    pf: platform "https://github.com/growthagent/basic-cli/releases/download/0.27.0/G-A6F5ny0IYDx4hmF3t_YPHUSR28c9ZXMBnh0FEJjwk.tar.br",
    carousel: "package/main.roc",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.12.0/1trwx8sltQ-e9Y2rOB4LWUWLS_sFVyETK8Twl0i9qpw.tar.gz",
}

import pf.Arg
import carousel.Carousel
import json.Json

## Regression guard, run via `roc test test_serialization.roc`.
##
## `Carousel.State` must stay JSON-encodable AND decodable: consumers embed it
## in page models that round-trip through SSR (the server encodes the model to
## JSON; the client decodes it). A tag union anywhere in `State`/`Config` makes
## `Decoding` underivable — roc cannot derive `Decoding` for tag unions — which
## panics the consumer's build with `DeriveError(Underivable)` and explodes WASM
## compile times (a 15s Portal build became a 7+ minute timeout). Keep `State`
## and `Config` flat (scalars/records only, no tag-union fields).
##
## This lives in a standalone test app rather than an inline `expect` in the
## package so the carousel package itself need not depend on roc-json.
main! : List Arg.Arg => Result {} _
main! = |_args| Ok({})

expect
    when Carousel.init({ id: "guard", config: Carousel.default_config, slide_count: 3 }) is
        Ok(state) ->
            encoded = Encode.to_bytes(state, Json.utf8)
            decoded : Result Carousel.State _
            decoded = Decode.from_bytes(encoded, Json.utf8)
            when decoded is
                Ok(restored) -> restored.active_index == state.active_index and restored.slide_count == state.slide_count
                Err(_) -> Bool.false

        Err(_) -> Bool.false
