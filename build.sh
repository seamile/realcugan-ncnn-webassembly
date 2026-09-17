#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$PROJECT_DIR"

# Use an already activated emsdk, or discover the layout used by this repo.
# emsdk_env.sh cannot locate itself when sourced by Ubuntu's /bin/sh (dash).
if [ -z "${EMSDK:-}" ] && [ -f "$PROJECT_DIR/../emsdk/.emscripten" ]; then
    EMSDK=$(CDPATH= cd -- "$PROJECT_DIR/../emsdk" && pwd)
    export EMSDK
    eval "$(EMSDK_BASH=1 EMSDK_QUIET=1 "$EMSDK/emsdk" construct_env)"
fi

if [ -z "${EMSDK:-}" ] || [ ! -f "$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake" ]; then
    echo "Error: emsdk is not active. Run: source /path/to/emsdk/emsdk_env.sh" >&2
    exit 1
fi

# The upstream repository declares these in .gitmodules but does not contain
# gitlink entries, so `git submodule update --init` cannot fetch them.
if [ ! -f fmt/CMakeLists.txt ]; then
    git clone --branch 8.1.1 --depth 1 https://github.com/fmtlib/fmt.git fmt
fi
if [ ! -f ncnn/CMakeLists.txt ]; then
    git clone --branch 20220420 --depth 1 https://github.com/Tencent/ncnn.git ncnn
fi

cmake -S . -B build \
    -DCMAKE_TOOLCHAIN_FILE="$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake" \
    -DWASM_FEATURE=simd-threads \
    -DNCNN_THREADS=ON \
    -DNCNN_OPENMP=ON \
    -DNCNN_SIMPLEOMP=ON \
    -DNCNN_RUNTIME_CPU=OFF \
    -DNCNN_SSE2=ON \
    -DNCNN_AVX2=OFF \
    -DNCNN_AVX=OFF \
    -DNCNN_BUILD_TOOLS=OFF \
    -DNCNN_BUILD_EXAMPLES=OFF \
    -DNCNN_BUILD_BENCHMARK=OFF \
    -DNCNN_TTT=ON

cmake --build build --parallel "${BUILD_JOBS:-4}"
cp build/realcugan-ncnn-webassembly* web/
cp models/* web/
