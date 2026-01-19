module [Model, encode_model]

import json.Json

## Model shared between client and server
Model : {
    initial_slide : U64,
}

encode_model : Model -> Str
encode_model = |model|
    bytes : List U8
    bytes = Encode.to_bytes(model, Json.utf8_with({ field_name_mapping: SnakeCase }))
    Str.from_utf8_lossy(bytes)
