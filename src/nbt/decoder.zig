//! Functions for decoding a NBT file

const std = @import("std");

const nbt = @import("nbt.zig");
const tags = nbt.tags;
const TagId = nbt.TagId;

// TODO: do not use anyerror everywhere

/// Reads a single tag from a reader stream
/// Arrays and names are allocated with alloc and owned by the called, should be freed
/// TODO: free method to kill a whole NBT tree
fn decodeNamedTag(data: *std.io.Reader, alloc: std.mem.Allocator) anyerror!tags.NamedTag {
    // Read tag id
    const tag_id = try data.takeEnum(TagId, nbt.nbt_endianness);

    // Handle special tag id "end"
    if (tag_id == .tag_end) {
        return tags.NamedTag{ .name = "", .payload = .tag_end };
    }

    // Read name
    const name_len = try data.takeInt(u16, nbt.nbt_endianness);
    const name = try data.readAlloc(alloc, name_len);
    errdefer alloc.free(name);

    // Read payload
    const payload = try decodePayload(tag_id, data, alloc);
    return .{ .name = name, .payload = payload };
}

/// Read a payload of the specified type
/// The type must have a payload and be supported
fn decodePayload(tag_id: TagId, data: *std.io.Reader, alloc: std.mem.Allocator) anyerror!tags.AnyPayload {
    return switch (tag_id) {
        .tag_end => error.InvalidTagId, // Has no payload
        .tag_byte => tags.AnyPayload{ .tag_byte = try takeNumber(tags.Byte, data) },
        .tag_short => tags.AnyPayload{ .tag_short = try takeNumber(tags.Short, data) },
        .tag_int => tags.AnyPayload{ .tag_int = try takeNumber(tags.Int, data) },
        .tag_long => tags.AnyPayload{ .tag_long = try takeNumber(tags.Long, data) },
        .tag_float => tags.AnyPayload{ .tag_float = try takeNumber(tags.Float, data) },
        .tag_double => tags.AnyPayload{ .tag_double = try takeNumber(tags.Double, data) },
        .tag_byte_array => tags.AnyPayload{ .tag_byte_array = try decodeByteArray(data, alloc) },
        .tag_string => tags.AnyPayload{ .tag_string = try decodeString(data, alloc) },
        .tag_list => tags.AnyPayload{ .tag_list = try decodeList(data, alloc) },
        .tag_compound => tags.AnyPayload{ .tag_compound = try decodeCompound(data, alloc, false) },
    };
}

/// Read a byte array payload
/// The result is allocated with the passed allocator and owned by caller
fn decodeByteArray(data: *std.io.Reader, alloc: std.mem.Allocator) anyerror!tags.ByteArray {
    // Read length of array
    // Technically len should be a i32, but I don't see a situation where len could be negative
    const len = try data.takeInt(u32, nbt.nbt_endianness);

    // Alloc and read (and cast pointer to have i8's)
    return @ptrCast(try data.readAlloc(alloc, len));
}

/// Read a byte array payload
/// The result is allocated with the passed allocator and owned by caller
fn decodeString(data: *std.io.Reader, alloc: std.mem.Allocator) anyerror!tags.String {
    // Read length of array
    const len = try data.takeInt(u16, nbt.nbt_endianness);

    // Alloc and read
    return try data.readAlloc(alloc, len);
}

/// Read a list payload
/// The result is allocated with the passed allocator and owned by caller
fn decodeList(data: *std.io.Reader, alloc: std.mem.Allocator) anyerror!tags.List {
    // Read tag id for stored type
    const tag_id = try data.takeEnum(TagId, nbt.nbt_endianness);

    // Read length of list
    // Technically len should be a i32, but I don't see a situation where len could be negative
    const len = try data.takeInt(u32, nbt.nbt_endianness);

    return switch (tag_id) {
        .tag_end => error.InvalidTagId, // Has no payload
        .tag_byte => tags.List{ .tag_byte = @ptrCast(try data.readAlloc(alloc, len)) },
        .tag_short => tags.List{ .tag_short = try decodeListNumbers(tags.Short, data, len, alloc) },
        .tag_int => tags.List{ .tag_int = try decodeListNumbers(tags.Int, data, len, alloc) },
        .tag_long => tags.List{ .tag_long = try decodeListNumbers(tags.Long, data, len, alloc) },
        .tag_float => tags.List{ .tag_float = try decodeListNumbers(tags.Float, data, len, alloc) },
        .tag_double => tags.List{ .tag_double = try decodeListNumbers(tags.Double, data, len, alloc) },
        .tag_byte_array => tags.List{ .tag_byte_array = try decodeListByteArray(data, len, alloc) },
        .tag_string => tags.List{ .tag_string = try decodeListString(data, len, alloc) },
        .tag_list => tags.List{ .tag_list = try decodeListList(data, len, alloc) },
        .tag_compound => tags.List{ .tag_compound = try decodeListCompound(data, len, alloc) },
    };
}

/// Read a numbers list
/// The result is allocated with the passed allocator and owned by caller
fn decodeListNumbers(comptime NumType: type, data: *std.io.Reader, count: usize, alloc: std.mem.Allocator) anyerror![]const NumType {
    // Allocate buffer
    const ret = try alloc.alloc(NumType, count);
    errdefer alloc.free(ret);

    // Read to fill
    for (ret) |*num| {
        num.* = try takeNumber(NumType, data);
    }
    return ret;
}

/// Read a byte array list
/// The result is allocated with the passed allocator and owned by caller
fn decodeListByteArray(data: *std.io.Reader, count: usize, alloc: std.mem.Allocator) anyerror![]const tags.ByteArray {
    // Allocate buffer
    const ret = try alloc.alloc(tags.ByteArray, count);
    errdefer alloc.free(ret);

    // Read each byte array
    for (ret) |*byte_array| {
        byte_array.* = try decodeByteArray(data, alloc);
    }
    return ret;
}

/// Read a string list
/// The result is allocated with the passed allocator and owned by caller
fn decodeListString(data: *std.io.Reader, count: usize, alloc: std.mem.Allocator) anyerror![]const tags.String {
    // Allocate buffer
    const ret = try alloc.alloc(tags.String, count);
    errdefer alloc.free(ret);

    // Read each string
    for (ret) |*string| {
        string.* = try decodeString(data, alloc);
    }
    return ret;
}

/// Read a list of lists
/// The result is allocated with the passed allocator and owned by caller
fn decodeListList(data: *std.io.Reader, count: usize, alloc: std.mem.Allocator) anyerror![]const tags.List {
    // Allocate buffer
    const ret = try alloc.alloc(tags.List, count);
    errdefer alloc.free(ret);

    // Read each list
    for (ret) |*list| {
        list.* = try decodeList(data, alloc);
    }
    return ret;
}

/// Read a list of compounds
/// The result is allocated with the passed allocator and owned by caller
fn decodeListCompound(data: *std.io.Reader, count: usize, alloc: std.mem.Allocator) anyerror![]const tags.Compound {
    // Allocate buffer
    const ret = try alloc.alloc(tags.Compound, count);
    errdefer alloc.free(ret);

    // Read each compound
    for (ret) |*compound| {
        compound.* = try decodeCompound(data, alloc, false);
    }
    return ret;
}

/// Decode a compound's subtags into the compound hashmap
/// Allow_eos should be false except for root compounds where we except the end of the file
pub fn decodeCompound(data: *std.io.Reader, alloc: std.mem.Allocator, comptime allow_eos: bool) anyerror!tags.Compound {
    // Allocate pointer to hashmap
    var ret: tags.Compound = try alloc.create(tags.CompoundHashMap);
    ret.* = .init(alloc);

    // Read tags as long as possible
    while (true) {
        // Check if we have reached the end of the data
        // using peekByte and detecting endOfStream
        if (allow_eos) {
            _ = data.peekByte() catch |e| {
                if (e == error.EndOfStream) break else return e;
            };
        }

        // Read named tag
        const named_tag = try decodeNamedTag(data, alloc);

        // Until tag end
        if (named_tag.payload == .tag_end)
            break;

        // Check that the key doesn't already exist
        if (ret.contains(named_tag.name))
            return error.KeyDuplicate;

        // Add to hashmap
        try ret.put(named_tag.name, named_tag);
    }

    return ret;
}

/// Reads an integer or float from a reader
/// Just like reader.takeInt but handles floats
fn takeNumber(comptime NumType: type, data: *std.io.Reader) anyerror!NumType {
    // Type to pass to readInt before bitcasting
    const ReadType = switch (NumType) {
        tags.Float => u32,
        tags.Double => u64,
        else => NumType,
    };

    // Read int in NBT endianness and bitcast
    return @bitCast(try data.takeInt(ReadType, nbt.nbt_endianness));
}
