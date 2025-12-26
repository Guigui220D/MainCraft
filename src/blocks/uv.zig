//! Helpers for terrain UV related stuff

const io = @import("io");

// The atlas has (atlas_size*atlas_size) textures
pub const atlas_size = 16;

/// Gets the texture coordinates for an ID of the terrain.png atlas
pub fn getTerrainUV(texture_id: u8, comptime reversed: bool) [8]f32 {
    const tx: f32 = @as(f32, @floatFromInt(texture_id % atlas_size));
    const ty: f32 = @as(f32, @floatFromInt(texture_id / atlas_size));
    const divide: f32 = if (io.properties.normalized_uvs) atlas_size else 1;

    if (reversed) {
        return [8]f32{
            (0.0 + tx) / divide, (1.0 + ty) / divide,
            (1.0 + tx) / divide, (1.0 + ty) / divide,
            (1.0 + tx) / divide, (0.0 + ty) / divide,
            (0.0 + tx) / divide, (0.0 + ty) / divide,
        };
    } else {
        return [8]f32{
            (1.0 + tx) / divide, (1.0 + ty) / divide,
            (0.0 + tx) / divide, (1.0 + ty) / divide,
            (0.0 + tx) / divide, (0.0 + ty) / divide,
            (1.0 + tx) / divide, (0.0 + ty) / divide,
        };
    }
}
