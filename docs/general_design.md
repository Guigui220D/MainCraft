# General design

## Codebase

This project makes heavy use of modules to encourage reusable and replaceable code. If something can be a module, it shall be a module. Those are also referred to as submodules (not the git kind).

This project tries to separate the game interface (I/O) from the engine/core so as to make it easy to change the graphics library and whatnot and port the game. See [I/O API](io_api.md).

## Lawfulness

This project doesn't implement cheats or exploits and aims to respects the expected way a client should behave, as to not be targetted as an undesirable client by server owners.

This project doesn't contain any of Mojang's code or assets, as to respect copyright, although it is possible to use original assets by providing a lawfully acquired jar or the game.