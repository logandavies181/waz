default:
    @just --list

build:
    zig build

build-windows:
    zig build -Dtarget=x86_64-windows
