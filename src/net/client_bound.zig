//! All clientbound packets and methods to read them

const std = @import("std");
const net = @import("net.zig");
const string = @import("string.zig");
const Packets = @import("packets.zig").Packets;

fn ErrorPacket(comptime err: anytype) type {
    return struct {
        pub fn receive(_: std.mem.Allocator, _: *std.Io.Reader) !@This() {
            return err;
        }
    };
}

const BadPacket = ErrorPacket(error.BadPacket);
const UnimplementedPacket = ErrorPacket(error.Unimplemented);

fn PacketDebug(size: comptime_int) type {
    return struct {
        pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
            var buf: [size]u8 = undefined;
            try stream.readSliceAll(&buf);

            std.debug.print("Packet dump:\n{any}\n", .{&buf});

            return error.BadPacket;
        }
    };
}

// TODO: move these in their own folder/files

pub const Packet0KeepAlive = struct {
    pub fn receive(_: std.mem.Allocator, _: *std.Io.Reader) !@This() {
        return .{};
    }
};

// Despite having the same name as the serverbound packet
// And the same field types, they are used differently
// TODO: should I name it differently?
pub const Packet1Login = struct {
    entity_id: i32,
    //username: []const u8, // Unused serverbound
    map_seed: i64,
    dimension: i8,

    pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
        // Entity ID
        const entity_id = try stream.takeInt(i32, net.endianness);
        // Unused string
        try string.discardString(stream, 16);
        // Map seed
        const map_seed = try stream.takeInt(i64, net.endianness);
        // Dimension
        const dimension = try stream.takeInt(i8, net.endianness);

        return .{
            .entity_id = entity_id,
            .map_seed = map_seed,
            .dimension = dimension,
        };
    }
};

pub const Packet2Handshake = struct {
    username: []const u8,

    pub fn receive(alloc: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
        // Get username
        const name = try string.readString(stream, alloc, 32);
        errdefer alloc.free(name);

        return .{
            .username = name,
        };
    }

    pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
        alloc.free(self.username);
    }
};

pub const Packet4UpdateTime = struct {
    time: i64,

    pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
        return .{
            // Read time
            .time = try stream.takeInt(i64, net.endianness),
        };
    }
};

pub const Packet6SpawnPosition = struct {
    x_position: i32,
    y_position: i32,
    z_position: i32,

    pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
        return .{
            // Read spawn coordinates
            .x_position = try stream.takeInt(i32, net.endianness),
            .y_position = try stream.takeInt(i32, net.endianness),
            .z_position = try stream.takeInt(i32, net.endianness),
        };
    }
};

pub const Packet21PickupSpawn = struct {
    entity_id: i32,
    x_position: i32,
    y_position: i32,
    z_position: i32,
    rotation: i8,
    pitch: i8,
    roll: i8,
    item_id: i16,
    stack_size: i8,
    item_dmg: i16,

    pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
        return .{
            // Entity id
            .entity_id = try stream.takeInt(i32, net.endianness),
            .item_id = try stream.takeInt(i16, net.endianness),
            .stack_size = try stream.takeInt(i8, net.endianness),
            // Stack
            .item_dmg = try stream.takeInt(i16, net.endianness),
            // Position
            .x_position = try stream.takeInt(i32, net.endianness),
            .y_position = try stream.takeInt(i32, net.endianness),
            .z_position = try stream.takeInt(i32, net.endianness),
            // Rotation
            .rotation = try stream.takeInt(i8, net.endianness),
            .pitch = try stream.takeInt(i8, net.endianness),
            .roll = try stream.takeInt(i8, net.endianness),
        };
    }
};

pub const Packet24MobSpawn = struct {
    entity_id: i32,
    entity_type: i8,
    x_position: i32,
    y_position: i32,
    z_position: i32,
    yaw: i8,
    pitch: i8,

    and_more: void,

    pub fn receive(alloc: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
        const ret = Packet24MobSpawn{
            .entity_id = try stream.takeInt(i32, net.endianness),
            .entity_type = try stream.takeInt(i8, net.endianness),
            .x_position = try stream.takeInt(i32, net.endianness),
            .y_position = try stream.takeInt(i32, net.endianness),
            .z_position = try stream.takeInt(i32, net.endianness),
            .yaw = try stream.takeInt(i8, net.endianness),
            .pitch = try stream.takeInt(i8, net.endianness),
            .and_more = {}, // placeholder
        };

        // TODO: keep data for real
        // TEMPORARY

        while (true) {
            const byte = try stream.takeInt(u8, net.endianness);

            // 127 is the end marker
            if (byte == 127)
                break;

            const b = (byte & 224) >> 5;
            switch (b) {
                0 => {
                    const n = try stream.takeInt(i8, net.endianness);
                    _ = n; //std.debug.print("Byte: {}\n", .{n});
                },
                1 => {
                    const n = try stream.takeInt(i16, net.endianness);
                    _ = n; // std.debug.print("Short: {}\n", .{n});
                },
                2 => {
                    const n = try stream.takeInt(i32, net.endianness);
                    _ = n; //std.debug.print("Int: {}\n", .{n});
                },
                3 => {
                    const n: f32 = @bitCast(try stream.takeInt(i32, net.endianness));
                    _ = n; //std.debug.print("Float: {}\n", .{n});
                },
                4 => {
                    const str = try string.readString(stream, alloc, 64);
                    defer alloc.free(str);
                    //std.debug.print("String: {s}\n", .{str});
                },
                5 => {
                    const item_id = try stream.takeInt(i16, net.endianness);
                    const stack_size = try stream.takeInt(i8, net.endianness);
                    const item_dmg = try stream.takeInt(i16, net.endianness);
                    _ = item_id;
                    _ = stack_size;
                    _ = item_dmg;
                    //std.debug.print("Item: {},{},{}\n", .{ item_id, stack_size, item_dmg });
                },
                6 => {
                    const x = try stream.takeInt(i32, net.endianness);
                    const y = try stream.takeInt(i32, net.endianness);
                    const z = try stream.takeInt(i32, net.endianness);
                    _ = x;
                    _ = y;
                    _ = z;
                    //std.debug.print("Coords: {},{},{}\n", .{ x, y, z });
                },
                else => std.debug.print("Unexpected byte {}\n", .{b}),
            }
        }

        return ret;
    }
};

pub const Packet28EntityVelocity = struct {
    entity_id: i32,
    x_motion: i16,
    y_motion: i16,
    z_motion: i16,

    pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
        return .{
            // Entity Id
            .entity_id = try stream.takeInt(i32, net.endianness),
            // Read motion
            .x_motion = try stream.takeInt(i16, net.endianness),
            .y_motion = try stream.takeInt(i16, net.endianness),
            .z_motion = try stream.takeInt(i16, net.endianness),
        };
    }
};

pub const Packet255KickDisconnect = struct {
    reason: []const u8,

    pub fn receive(alloc: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
        return .{
            // Reason
            .reason = try string.readString(stream, alloc, 100),
        };
    }

    pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
        alloc.free(self.reason);
    }
};

// Union of any inbound packet
pub const InboundPacket = union(Packets) {
    keep_alive_0: Packet0KeepAlive,
    login_1: Packet1Login,
    handshake_2: Packet2Handshake,
    chat_3: UnimplementedPacket,
    update_time_4: Packet4UpdateTime,
    player_inventory_5: UnimplementedPacket,
    spawn_position_6: Packet6SpawnPosition,
    use_entity_7: UnimplementedPacket,
    update_health_8: UnimplementedPacket,
    respawn_9: UnimplementedPacket,
    flying_10: UnimplementedPacket,
    player_position_11: UnimplementedPacket,
    player_look_12: UnimplementedPacket,
    player_look_move_13: UnimplementedPacket,
    block_dig_14: UnimplementedPacket,
    place_15: UnimplementedPacket,
    block_item_switch_16: UnimplementedPacket,
    sleep_17: UnimplementedPacket,
    animation_18: UnimplementedPacket,
    entity_action_19: UnimplementedPacket,
    named_entity_spawn_20: UnimplementedPacket,
    pickup_spawn_21: Packet21PickupSpawn,
    collect_22: UnimplementedPacket,
    vehicle_spawn_23: UnimplementedPacket,
    mob_spawn_24: Packet24MobSpawn,
    entity_painting_25: UnimplementedPacket,
    unused_26: BadPacket,
    position_27: UnimplementedPacket,
    entity_velocity_28: Packet28EntityVelocity,
    destroy_entity_29: UnimplementedPacket,
    entity_30: UnimplementedPacket,
    rel_entity_move_31: UnimplementedPacket,
    entity_look_32: UnimplementedPacket,
    rel_entity_move_look_33: UnimplementedPacket,
    entity_teleport_34: UnimplementedPacket,
    unused_35: BadPacket,
    unused_36: BadPacket,
    unused_37: BadPacket,
    entity_status_38: UnimplementedPacket,
    attach_entity_39: UnimplementedPacket,
    entity_metadata_40: UnimplementedPacket,
    unused_41: BadPacket,
    unused_42: BadPacket,
    unused_43: BadPacket,
    unused_44: BadPacket,
    unused_45: BadPacket,
    unused_46: BadPacket,
    unused_47: BadPacket,
    unused_48: BadPacket,
    unused_49: BadPacket,
    pre_chunk_50: UnimplementedPacket,
    map_chunk_51: UnimplementedPacket,
    multi_block_change_52: UnimplementedPacket,
    block_change_53: UnimplementedPacket,
    play_note_block_54: UnimplementedPacket,
    unused_55: BadPacket,
    unused_56: BadPacket,
    unused_57: BadPacket,
    unused_58: BadPacket,
    unused_59: BadPacket,
    explosion_60: UnimplementedPacket,
    door_change_61: UnimplementedPacket,
    unused_62: BadPacket,
    unused_63: BadPacket,
    unused_64: BadPacket,
    unused_65: BadPacket,
    unused_66: BadPacket,
    unused_67: BadPacket,
    unused_68: BadPacket,
    unused_69: BadPacket,
    bed_70: UnimplementedPacket,
    weather_71: UnimplementedPacket,
    unused_72: BadPacket,
    unused_73: BadPacket,
    unused_74: BadPacket,
    unused_75: BadPacket,
    unused_76: BadPacket,
    unused_77: BadPacket,
    unused_78: BadPacket,
    unused_79: BadPacket,
    unused_80: BadPacket,
    unused_81: BadPacket,
    unused_82: BadPacket,
    unused_83: BadPacket,
    unused_84: BadPacket,
    unused_85: BadPacket,
    unused_86: BadPacket,
    unused_87: BadPacket,
    unused_88: BadPacket,
    unused_89: BadPacket,
    unused_90: BadPacket,
    unused_91: BadPacket,
    unused_92: BadPacket,
    unused_93: BadPacket,
    unused_94: BadPacket,
    unused_95: BadPacket,
    unused_96: BadPacket,
    unused_97: BadPacket,
    unused_98: BadPacket,
    unused_99: BadPacket,
    open_window_100: UnimplementedPacket,
    close_window_101: UnimplementedPacket,
    window_click_102: UnimplementedPacket,
    set_slot_103: UnimplementedPacket,
    window_items_104: UnimplementedPacket,
    update_progress_bar_105: UnimplementedPacket,
    transaction_106: UnimplementedPacket,
    unused_107: BadPacket,
    unused_108: BadPacket,
    unused_109: BadPacket,
    unused_110: BadPacket,
    unused_111: BadPacket,
    unused_112: BadPacket,
    unused_113: BadPacket,
    unused_114: BadPacket,
    unused_115: BadPacket,
    unused_116: BadPacket,
    unused_117: BadPacket,
    unused_118: BadPacket,
    unused_119: BadPacket,
    unused_120: BadPacket,
    unused_121: BadPacket,
    unused_122: BadPacket,
    unused_123: BadPacket,
    unused_124: BadPacket,
    unused_125: BadPacket,
    unused_126: BadPacket,
    unused_127: BadPacket,
    unused_128: BadPacket,
    unused_129: BadPacket,
    update_sign_130: UnimplementedPacket,
    map_data_131: UnimplementedPacket,
    unused_132: BadPacket,
    unused_133: BadPacket,
    unused_134: BadPacket,
    unused_135: BadPacket,
    unused_136: BadPacket,
    unused_137: BadPacket,
    unused_138: BadPacket,
    unused_139: BadPacket,
    unused_140: BadPacket,
    unused_141: BadPacket,
    unused_142: BadPacket,
    unused_143: BadPacket,
    unused_144: BadPacket,
    unused_145: BadPacket,
    unused_146: BadPacket,
    unused_147: BadPacket,
    unused_148: BadPacket,
    unused_149: BadPacket,
    unused_150: BadPacket,
    unused_151: BadPacket,
    unused_152: BadPacket,
    unused_153: BadPacket,
    unused_154: BadPacket,
    unused_155: BadPacket,
    unused_156: BadPacket,
    unused_157: BadPacket,
    unused_158: BadPacket,
    unused_159: BadPacket,
    unused_160: BadPacket,
    unused_161: BadPacket,
    unused_162: BadPacket,
    unused_163: BadPacket,
    unused_164: BadPacket,
    unused_165: BadPacket,
    unused_166: BadPacket,
    unused_167: BadPacket,
    unused_168: BadPacket,
    unused_169: BadPacket,
    unused_170: BadPacket,
    unused_171: BadPacket,
    unused_172: BadPacket,
    unused_173: BadPacket,
    unused_174: BadPacket,
    unused_175: BadPacket,
    unused_176: BadPacket,
    unused_177: BadPacket,
    unused_178: BadPacket,
    unused_179: BadPacket,
    unused_180: BadPacket,
    unused_181: BadPacket,
    unused_182: BadPacket,
    unused_183: BadPacket,
    unused_184: BadPacket,
    unused_185: BadPacket,
    unused_186: BadPacket,
    unused_187: BadPacket,
    unused_188: BadPacket,
    unused_189: BadPacket,
    unused_190: BadPacket,
    unused_191: BadPacket,
    unused_192: BadPacket,
    unused_193: BadPacket,
    unused_194: BadPacket,
    unused_195: BadPacket,
    unused_196: BadPacket,
    unused_197: BadPacket,
    unused_198: BadPacket,
    unused_199: BadPacket,
    statistic_200: UnimplementedPacket,
    unused_201: BadPacket,
    unused_202: BadPacket,
    unused_203: BadPacket,
    unused_204: BadPacket,
    unused_205: BadPacket,
    unused_206: BadPacket,
    unused_207: BadPacket,
    unused_208: BadPacket,
    unused_209: BadPacket,
    unused_210: BadPacket,
    unused_211: BadPacket,
    unused_212: BadPacket,
    unused_213: BadPacket,
    unused_214: BadPacket,
    unused_215: BadPacket,
    unused_216: BadPacket,
    unused_217: BadPacket,
    unused_218: BadPacket,
    unused_219: BadPacket,
    unused_220: BadPacket,
    unused_221: BadPacket,
    unused_222: BadPacket,
    unused_223: BadPacket,
    unused_224: BadPacket,
    unused_225: BadPacket,
    unused_226: BadPacket,
    unused_227: BadPacket,
    unused_228: BadPacket,
    unused_229: BadPacket,
    unused_230: BadPacket,
    unused_231: BadPacket,
    unused_232: BadPacket,
    unused_233: BadPacket,
    unused_234: BadPacket,
    unused_235: BadPacket,
    unused_236: BadPacket,
    unused_237: BadPacket,
    unused_238: BadPacket,
    unused_239: BadPacket,
    unused_240: BadPacket,
    unused_241: BadPacket,
    unused_242: BadPacket,
    unused_243: BadPacket,
    unused_244: BadPacket,
    unused_245: BadPacket,
    unused_246: BadPacket,
    unused_247: BadPacket,
    unused_248: BadPacket,
    unused_249: BadPacket,
    unused_250: BadPacket,
    unused_251: BadPacket,
    unused_252: BadPacket,
    unused_253: BadPacket,
    unused_254: BadPacket,
    kick_disconnect_255: Packet255KickDisconnect,
};
