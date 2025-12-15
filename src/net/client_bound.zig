//! All clientbound packets and methods to read them

const std = @import("std");
const net = @import("net.zig");
const string = @import("string.zig");
const Packets = @import("packets.zig").Packets;

pub const BadPacket = struct {
    pub fn receive(_: std.mem.Allocator, _: *std.Io.Reader) !@This() {
        return error.BadPacket;
    }
};

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
        try string.discardString(stream);
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
        const name = try string.readString(stream, alloc);
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

pub const Packet24MobSpawn = struct {
    entity_id: i32,
    entity_type: i8,
    x_position: i32,
    y_position: i32,
    z_position: i32,
    yaw: i8,
    pitch: i8,

    and_more: void,

    pub fn receive(_: std.mem.Allocator, stream: *std.Io.Reader) !@This() {
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

        // TODO: read supplementary data for real
        // TEMPORARY: discarding all entity data

        while (true) {
            // 127 is the end marker
            if (try stream.takeByte() == 127)
                break;
        }
        return ret;
    }
};

// Union of any inbound packet
pub const InboundPacket = union(Packets) {
    keep_alive_0: Packet0KeepAlive,
    login_1: Packet1Login,
    handshake_2: Packet2Handshake,
    chat_3: BadPacket,
    update_time_4: Packet4UpdateTime,
    player_inventory_5: BadPacket,
    spawn_position_6: Packet6SpawnPosition,
    use_entity_7: BadPacket,
    update_health_8: BadPacket,
    respawn_9: BadPacket,
    flying_10: BadPacket,
    player_position_11: BadPacket,
    player_look_12: BadPacket,
    player_look_move_13: BadPacket,
    block_dig_14: BadPacket,
    place_15: BadPacket,
    block_item_switch_16: BadPacket,
    sleep_17: BadPacket,
    animation_18: BadPacket,
    entity_action_19: BadPacket,
    named_entity_spawn_20: BadPacket,
    pickup_spawn_21: BadPacket,
    collect_22: BadPacket,
    vehicle_spawn_23: BadPacket,
    mob_spawn_24: Packet24MobSpawn,
    entity_painting_25: BadPacket,
    unused_26: BadPacket,
    position_27: BadPacket,
    entity_velocity_28: BadPacket,
    destroy_entity_29: BadPacket,
    entity_30: BadPacket,
    rel_entity_move_31: BadPacket,
    entity_look_32: BadPacket,
    rel_entity_move_look_33: BadPacket,
    entity_teleport_34: BadPacket,
    unused_35: BadPacket,
    unused_36: BadPacket,
    unused_37: BadPacket,
    entity_status_38: BadPacket,
    attach_entity_39: BadPacket,
    entity_metadata_40: BadPacket,
    unused_41: BadPacket,
    unused_42: BadPacket,
    unused_43: BadPacket,
    unused_44: BadPacket,
    unused_45: BadPacket,
    unused_46: BadPacket,
    unused_47: BadPacket,
    unused_48: BadPacket,
    unused_49: BadPacket,
    pre_chunk_50: BadPacket,
    map_chunk_51: BadPacket,
    multi_block_change_52: BadPacket,
    block_change_53: BadPacket,
    play_note_block_54: BadPacket,
    unused_55: BadPacket,
    unused_56: BadPacket,
    unused_57: BadPacket,
    unused_58: BadPacket,
    unused_59: BadPacket,
    explosion_60: BadPacket,
    door_change_61: BadPacket,
    unused_62: BadPacket,
    unused_63: BadPacket,
    unused_64: BadPacket,
    unused_65: BadPacket,
    unused_66: BadPacket,
    unused_67: BadPacket,
    unused_68: BadPacket,
    unused_69: BadPacket,
    bed_70: BadPacket,
    weather_71: BadPacket,
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
    open_window_100: BadPacket,
    close_window_101: BadPacket,
    window_click_102: BadPacket,
    set_slot_103: BadPacket,
    window_items_104: BadPacket,
    update_progress_bar_105: BadPacket,
    transaction_106: BadPacket,
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
    update_sign_130: BadPacket,
    map_data_131: BadPacket,
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
    statistic_200: BadPacket,
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
    kick_disconnect_255: BadPacket,
};
