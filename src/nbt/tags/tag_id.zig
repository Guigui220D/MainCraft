//! Tags Ids for version 19132

/// 1 byte tag IDs from the NBT format
pub const TagId = enum(u8) {
    tag_end = 0, // Ends compound tags
    tag_byte = 1, // A single i8 value (signed byte integer), also used for booleans
    tag_short = 2, // A single signed short integer (i16) (big endian)
    tag_int = 3, // A single signed integer (i32) (big endian)
    tag_long = 4, // A single long signed integer (i64) (big endian)
    tag_float = 5, // A single 32 bit (single) float (f32) (big endian)
    tag_double = 6, // A single 64 bit (double) float (f64) (big endian)
    tag_byte_array = 7, // A signed int (i32, big endian) for the count followed by that many bytes
    tag_string = 8, // A short unsigned int (u16, big endian) for the byte count, then that many bytes of UTF-8 data (not null-terminated)
    tag_list = 9, // A first TagID for the type of the contained values, then a signed int (i32, big endian) for the count followed by that many values
    tag_compound = 10, // Many tags, until a tag_end
    //tag_int_array = 11, // Added in version 19133 (Anvil format, MC 1.2.1)
    //tag_long_array = 12, // Added in Java Edition 1.12
};
