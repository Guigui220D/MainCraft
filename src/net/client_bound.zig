pub const Packet1Login = struct {
    protocol_version: i32,
    username: []const u8,
    map_seed: i64,
    dimension: i8,
};
