//! All serverbound packets and methods to write them

const std = @import("std");
const net = @import("net.zig");
const string = @import("string.zig");

pub const Packet1Login = @import("server_bound/Packet1Login.zig");
pub const Packet2Handshake = @import("server_bound/Packet2Handshake.zig");
