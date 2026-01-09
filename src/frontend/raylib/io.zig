//! Module root of the "io" submodule, for all interface with the player
//! i.e. windowing, graphics, audio, and input
//! This frontend uses Raylib

pub const main = @import("main.zig").main;
pub const GameWindow = @import("GameWindow.zig");
pub const ChunkModel = @import("ChunkModel.zig");
pub const EntityModel = @import("EntityModel.zig");
pub const properties = @import("properties.zig");

pub const frontend_name = "raylib";
