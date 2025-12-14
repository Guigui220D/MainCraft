//! Functions for decoding a NBT file

const std = @import("std");

const nbt = @import("nbt.zig");
const tags = nbt.tags;
const TagId = nbt.TagId;

/// Nbt decoder specific errors
const NbtDecoderError = error{
    InvalidTagId,
    KeyDuplicate,
};

/// All errors that can happen when decoding
const ErrSet = NbtDecoderError || std.Io.Reader.TakeEnumError || std.mem.Allocator.Error;

/// Reads a single tag from a reader stream
/// Arrays and names are allocated with alloc and owned by the called, should be freed
fn decodeNamedTag(data: *std.Io.Reader, alloc: std.mem.Allocator) ErrSet!tags.NamedTag {
    // Read tag id
    const tag_id = try data.takeEnum(TagId, nbt.endianness);

    // Handle special tag id "end"
    if (tag_id == .tag_end) {
        return tags.NamedTag{ .name = "", .payload = .tag_end };
    }

    // Read name
    const name_len = try data.takeInt(u16, nbt.endianness);
    const name = try data.readAlloc(alloc, name_len);
    errdefer alloc.free(name);

    // Read payload
    const payload = try decodePayload(tag_id, data, alloc);
    return .{ .name = name, .payload = payload };
}

/// Read a payload of the specified type
/// The type must have a payload and be supported
fn decodePayload(tag_id: TagId, data: *std.Io.Reader, alloc: std.mem.Allocator) ErrSet!tags.AnyPayload {
    return switch (tag_id) {
        .tag_end => NbtDecoderError.InvalidTagId, // Has no payload
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
fn decodeByteArray(data: *std.Io.Reader, alloc: std.mem.Allocator) ErrSet!tags.ByteArray {
    // Read length of array
    // Technically len should be a i32, but I don't see a situation where len could be negative
    const len = try data.takeInt(u32, nbt.endianness);

    // Alloc and read (and cast pointer to have i8's)
    return @ptrCast(try data.readAlloc(alloc, len));
}

/// Read a byte array payload
/// The result is allocated with the passed allocator and owned by caller
fn decodeString(data: *std.Io.Reader, alloc: std.mem.Allocator) ErrSet!tags.String {
    // Read length of array
    const len = try data.takeInt(u16, nbt.endianness);

    // Alloc and read
    return try data.readAlloc(alloc, len);
}

/// Read a list payload
/// The result is allocated with the passed allocator and owned by caller
fn decodeList(data: *std.Io.Reader, alloc: std.mem.Allocator) ErrSet!tags.List {
    // Read tag id for stored type
    const tag_id = try data.takeEnum(TagId, nbt.endianness);

    // Read length of list
    // Technically len should be a i32, but I don't see a situation where len could be negative
    const len = try data.takeInt(u32, nbt.endianness);

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
fn decodeListNumbers(comptime NumType: type, data: *std.Io.Reader, count: usize, alloc: std.mem.Allocator) ErrSet![]const NumType {
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
fn decodeListByteArray(data: *std.Io.Reader, count: usize, alloc: std.mem.Allocator) ErrSet![]const tags.ByteArray {
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
fn decodeListString(data: *std.Io.Reader, count: usize, alloc: std.mem.Allocator) ErrSet![]const tags.String {
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
fn decodeListList(data: *std.Io.Reader, count: usize, alloc: std.mem.Allocator) ErrSet![]const tags.List {
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
fn decodeListCompound(data: *std.Io.Reader, count: usize, alloc: std.mem.Allocator) ErrSet![]const tags.Compound {
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
pub fn decodeCompound(data: *std.Io.Reader, alloc: std.mem.Allocator, comptime allow_eos: bool) ErrSet!tags.Compound {
    // Allocate pointer to hashmap
    var ret: tags.Compound = .{ .hashmap = try alloc.create(tags.CompoundHashMap) };
    ret.hashmap.* = .init(alloc);

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
        if (ret.hashmap.contains(named_tag.name))
            return NbtDecoderError.KeyDuplicate;

        // Add to hashmap
        try ret.hashmap.put(named_tag.name, named_tag.payload);
    }

    return ret;
}

/// Reads an integer or float from a reader
/// Just like reader.takeInt but handles floats
fn takeNumber(comptime NumType: type, data: *std.Io.Reader) ErrSet!NumType {
    // Type to pass to readInt before bitcasting
    const ReadType = switch (NumType) {
        tags.Float => u32,
        tags.Double => u64,
        else => NumType,
    };

    // Read int in NBT endianness and bitcast
    return @bitCast(try data.takeInt(ReadType, nbt.endianness));
}
