//! Tags namespace

const std = @import("std");
const TagId = @import("tag_id.zig").TagId;

/// Representation of a complete tag
pub const NamedTag = struct {
    name: []const u8,
    payload: AnyPayload,

    /// Standard format signature for printing
    /// formats as a SNBT string
    pub fn format(self: NamedTag, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        if (self.name.len != 0) {
            try writer.writeAll(self.name);
            try writer.writeByte(':');
        }
        try self.payload.format(writer);
    }
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

    /// Creates a payload from a value
    pub fn fromValue(value: anytype) AnyPayload {
        return switch (@TypeOf(value)) {
            Byte => AnyPayload{ .tag_byte = value },
            Short => AnyPayload{ .tag_short = value },
            Int => AnyPayload{ .tag_int = value },
            Long => AnyPayload{ .tag_long = value },
            Float => AnyPayload{ .tag_float = value },
            Double => AnyPayload{ .tag_double = value },
            ByteArray => AnyPayload{ .tag_byte_array = value },
            String => AnyPayload{ .tag_string = value },
            List => AnyPayload{ .tag_list = value },
            Compound => AnyPayload{ .tag_compound = value },
            else => @compileError(@typeName(@TypeOf(value)) ++ " is not a valid anyPayload type"),
        };
    }

    /// Standard format signature for printing
    /// formats as a SNBT string
    pub fn format(self: AnyPayload, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (self) {
            .tag_end => return,
            .tag_string => |string| try writer.print("\"{s}\"", .{string}),
            .tag_byte_array => |byte_array| {
                // Special case for byte arrays
                try writer.writeAll("[B;");
                // Print all bytes
                var is_first = true;
                for (byte_array) |byte| {
                    // Put commas after each element
                    // or rather before every element except the first
                    if (is_first) {
                        is_first = false;
                    } else {
                        try writer.writeByte(',');
                    }
                    try writer.print("{}b", .{byte});
                }
                try writer.writeByte(']');
            },
            .tag_byte => |byte| try writer.print("{}b", .{byte}),
            .tag_short => |short| try writer.print("{}s", .{short}),
            .tag_int => |int| try writer.print("{}", .{int}),
            .tag_long => |long| try writer.print("{}l", .{long}),
            .tag_float => |float| try writer.print("{}f", .{float}),
            .tag_double => |double| try writer.print("{}", .{double}),
            inline else => |payload| try payload.format(writer),
        }
    }
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

    /// Standard format signature for printing
    /// formats as a SNBT string
    pub fn format(self: List, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (self) {
            .tag_end => {},
            inline else => |array| {
                try writer.writeByte('[');
                // Print all values
                var is_first = true;
                for (array) |elem| {
                    // Convert to anypayload to help with the metaprogramming pattern
                    const any = AnyPayload.fromValue(elem);
                    // Put commas after each element
                    // or rather before every element except the first
                    if (is_first) {
                        is_first = false;
                    } else {
                        try writer.writeByte(',');
                    }
                    try any.format(writer);
                }

                try writer.writeByte(']');
            },
        }
    }
};

/// Backing hashmap for compounds
pub const CompoundHashMap = std.StringArrayHashMap(NamedTag);

/// Compound tag: many named tags (as an union for polymorphism)
pub const Compound = struct {
    hashmap: *CompoundHashMap,

    /// Standard format signature for printing
    /// formats as a SNBT string
    pub fn format(self: Compound, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.writeByte('{');

        // Print each sub-element
        var is_first = true;
        var it = self.hashmap.iterator();
        while (it.next()) |elem| {
            // Put commas after each element
            // or rather before every element except the first
            if (is_first) {
                is_first = false;
            } else {
                try writer.writeByte(',');
            }

            // Write named tag
            try elem.value_ptr.format(writer);
        }

        try writer.writeByte('}');
    }
};
