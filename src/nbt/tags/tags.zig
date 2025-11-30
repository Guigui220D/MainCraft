//! Tags namespace

const std = @import("std");
const TagId = @import("tag_id.zig").TagId;

/// Representation of a complete tag
pub const NamedTag = struct {
    name: []const u8,
    payload: AnyPayload,
};

/// Union of any payload type
pub const AnyPayload = union(TagId) {
    tag_end: void,
    tag_byte: Byte,
    tag_short: Short,
    tag_int: Int,
    tag_long: Long,
    tag_float: Float,
    tag_double: Double,
    tag_byte_array: ByteArray,
    tag_string: String,
    tag_list: List,
    tag_compound: Compound,
};

// The following are structs for local representation of NBT payloads, they are not in the actual layout of NBT data

/// Byte tag (signed 8 bits, local endianness)
pub const Byte = i8;

/// Short int tag (signed 16 bits, local endianness)
pub const Short = i16;

/// Regular int tag (signed 32 bits, local endianness)
pub const Int = i32;

/// Long int tag (signed 64 bits, local endianness)
pub const Long = i64;

/// Float tag (single (32 bits) IEEE float, local endianness)
pub const Float = f32;

/// Double tag (double (64 bits) IEEE float, local endianness)
pub const Double = f64;

/// Byte array tag: slice of bytes (signed)
pub const ByteArray = []const Byte;

/// String tag: UTF-8
pub const String = []const u8;

/// List tag: many named tags (as an union for polymorphism)
pub const List = union(TagId) {
    tag_end: void,
    tag_byte: []const Byte,
    tag_short: []const Short,
    tag_int: []const Int,
    tag_long: []const Long,
    tag_float: []const Float,
    tag_double: []const Double,
    tag_byte_array: []const ByteArray,
    tag_string: []const String,
    tag_list: []const List,
    tag_compound: []const Compound,
};

/// Compound tag: many named tags (as an union for polymorphism)
pub const CompoundHashMap = std.StringArrayHashMap(NamedTag);
pub const Compound = *CompoundHashMap;
