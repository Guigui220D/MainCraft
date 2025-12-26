# IO API

## Description

The IO module, also called Frontend is a module that exists in different versions, as to allow choosing the input/output libraries. These frontends are in the [frontend folder](../src/frontend).

Here, input/output (I/O) refers to the way the player interacts with the game, not general IO like networking and filesystem accesses. This includes windowing, graphics (3D, GUI), keyboard/mouse input, and audio to name a few.

The minecraft client is made as to not directly depend on any graphics/etc library but abstract all of that through the I/O API.

To create a new drop-in I/O replacement, refer to the [dummy io module](../src/frontend/dummy/) which implements a non-fonctionnal but compiling frontend with the strictly necessary functions that the engine calls. Fill in the functions you want. The main function should be rewritten, to allow making menus, etc, calling draw functions.

The selected I/O frontend exposes both functions and structures for storing ressources and state of rendered objects that are then stored in the engine's objects.

Pass a `-Dfrontend=` argument to the build call to compile with a selected frontend. Default is `dummy`.

## Available frontends

### Raylib

The first frontend written, based on Raysan's [Raylib](https://www.raylib.com/) ([raysan5/raylib](https://github.com/raysan5/raylib)) through [raylib-zig](https://github.com/raylib-zig/raylib-zig), bindings for Zig.

Pass `-Dfrontend=raylib` to use it.

### Dummy

A non functional frontend made as reference for creating other frontends or as a way to create headless clients.

Pass `-Dfrontend=dummy` to use it default.