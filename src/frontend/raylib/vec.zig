const rl = @import("raylib");
const coord = @import("coord");

pub fn coordToRlVec(coords: coord.Vec3f) rl.Vector3 {
    return .{
        .x = @floatCast(coords.x),
        .y = @floatCast(coords.y),
        .z = @floatCast(coords.z),
    };
}

pub fn rlVecToCoord(coords: rl.Vector3) coord.Vec3f {
    return .{
        .x = @floatCast(coords.x),
        .y = @floatCast(coords.y),
        .z = @floatCast(coords.z),
    };
}
