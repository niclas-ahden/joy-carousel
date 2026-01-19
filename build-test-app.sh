#!/usr/bin/env bash
set -euo pipefail

# --dev or --release
profile=${1:---dev}

echo "=====> Building test app ($profile)"

# Clean old artifacts
rm -f app.o libapp.a

# Build client
echo "=====> Compiling client (Roc -> WASM)..."
exit_code=0
roc build --target wasm32 --no-link --emit-llvm-ir --output app.o tests/app/client/main.roc || exit_code=$?

if [ "${exit_code}" -eq 0 ] || [ "${exit_code}" -eq 2 ]; then
    # Link into static library
    echo "=====> Linking with Zig..."
    zig build-lib -target wasm32-freestanding-musl --library c app.o

    # Build WASM with Joy
    echo "=====> Building WASM with Joy..."
    project_dir=$(pwd)
    mkdir -p tests/app/www/pkg

    JOY_PROJECT_ROOT=$project_dir wasm-pack build $profile \
        --target web \
        --out-dir $project_dir/tests/app/www/pkg \
        joy/crates/web

    # Build server
    echo "=====> Building server..."
    roc build --linker legacy tests/app/server/main.roc

    echo "=====> Build complete!"
    echo "Run: ./tests/app/server/main"
else
    echo "=====> Roc build failed with exit code $exit_code"
    exit $exit_code
fi
