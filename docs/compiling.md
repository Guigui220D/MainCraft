# Compiling

Compile with `zig build`. The project uses Zig 0.15.2. See `zig build -h` for help on arguments.

To select a frontend (see [IO](./io_api.md)), use `-Dfrontend=frontend-name`.

To enable tracy, use `-Dtracy`.

In order to run the raylib frontend, you need to decompress a b1.7.3 jar in the `res/jar` as a folder called `minecraft`.