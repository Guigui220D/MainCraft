//! Packed struct to store skylight and blocklight as a single byte

/// Packed struct to store skylight and blocklight as a single byte
pub const LightLevel = packed struct(u8) {
    blocklight: u4,
    skylight: u4,
};
