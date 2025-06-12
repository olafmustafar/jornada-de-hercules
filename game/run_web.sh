#!/bin/sh
zig build -Dtarget=wasm32-emscripten --sysroot ~/emsdk/upstream/emscripten && 
emrun zig-out/bin/index.html 
