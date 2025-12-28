//! Module root of the "io" submodule, for all interface with the player
//! i.e. windowing, graphics, audio, and input
//! This frontend does nothing, just stands as a frontend but disables all i/o (except the terminal)

pub const main = @import("main.zig").main;
pub const GameWindow = @import("GameWindow.zig");
pub const ChunkModel = @import("ChunkModel.zig");
pub const EntityModel = @import("EntityModel.zig");
pub const properties = @import("properties.zig");
