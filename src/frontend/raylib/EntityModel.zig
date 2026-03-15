//! An entity's visual representation
//! This is specific to the IO and can be modified independently of the entity's actual representation

const std = @import("std");
const rl = @import("raylib");
const coord = @import("coord");
const Entity = @import("engine").entities.Entity;
const GameWindow = @import("GameWindow.zig");
const DrawContext = @import("DrawContext.zig");

const EntityModel = @This();

const frame_duration_us = 10000;

entity: *Entity,
anim_frame: i32,
animation: ?*rl.ModelAnimation,
model: ?*const rl.Model,
time_buf_us: usize,
display_str_buf: [32]u8,
display_str_len: usize,

pub fn initForEntity(_: std.mem.Allocator, entity: *Entity, game_window: *GameWindow) !EntityModel {
    var ret: EntityModel = .{
        .entity = entity,
        .anim_frame = 0,
        .time_buf_us = 0,
        .animation = null,
        .model = if (entity.data == .player) game_window.ressource_manager.models.get("character-a.glb").? else null,
        .display_str_buf = undefined,
        .display_str_len = 0,
    };

    if (entity.data == .player) {
        const slice = try std.fmt.bufPrintZ(&ret.display_str_buf, "{s} {}", .{ entity.data.player.username, entity.id });
        ret.display_str_len = slice.len;
    } else {
        const slice = try std.fmt.bufPrintZ(&ret.display_str_buf, "{}", .{entity.id});
        ret.display_str_len = slice.len;
    }

    return ret;
}

pub fn startAnimation(_: *EntityModel, _: u8) void {
    //std.debug.print("Entity {}: animation {}\n", .{ self.entity.id, anim });
    // TODO: animations
}

pub fn deinit(_: EntityModel, _: std.mem.Allocator) void {}

pub fn draw(self: EntityModel, context: DrawContext) void {
    const pos = self.entity.pos;
    var rl_pos: rl.Vector3 = .{ .x = @floatCast(pos.x), .y = @floatCast(pos.y), .z = @floatCast(pos.z) };

    if (self.model) |model| {
        if (self.animation) |anim| {
            rl.updateModelAnimation(model.*, anim.*, self.anim_frame);
        } else {
            // TODO: reset pose
        }
        rl.drawModel(model.*, rl_pos, 0.7, .white);
    } else {
        // TODO: draw text on top of player's head
        // TODO: all models
        rl_pos = rl_pos.add(.{ .x = 0, .y = 0.5, .z = 0 });
        switch (self.entity.data) {
            .item => rl.drawSphere(rl_pos, 0.4, .sky_blue),
            .painting => {},
            .arrow => rl.drawSphere(rl_pos, 0.1, .beige),
            .snowball => rl.drawSphere(rl_pos, 0.4, .white),
            .primed_tnt => rl.drawCube(rl_pos, 1.0, 1.0, 1.0, .red),
            .falling_sand => rl.drawCube(rl_pos, 1.0, 1.0, 1.0, .yellow),
            .minecart => rl.drawCube(rl_pos, 1.1, 0.75, 1.1, .gray),
            .boat => rl.drawCube(rl_pos, 1.1, 0.75, 1.1, .brown),
            .mob => {}, // Does that even exist??
            .monster => {}, // Does that even exist??
            .creeper => rl.drawSphere(rl_pos, 0.4, .green),
            .skeleton => rl.drawSphere(rl_pos, 0.4, .gray),
            .giant => rl.drawSphere(rl_pos, 1, .dark_green),
            .zombie => rl.drawSphere(rl_pos, 0.4, .dark_green),
            .slime => rl.drawCube(rl_pos, 1.0, 1.0, 1.0, .green),
            .ghast => rl.drawCube(rl_pos, 1.5, 1.5, 1.5, .white),
            .pig_zombie => rl.drawSphere(rl_pos, 0.4, .magenta),
            .pig => rl.drawSphere(rl_pos, 0.4, .pink),
            .sheep => rl.drawSphere(rl_pos, 0.4, .black),
            .cow => rl.drawSphere(rl_pos, 0.4, .brown),
            .chicken => rl.drawSphere(rl_pos, 0.4, .white),
            .squid => rl.drawSphere(rl_pos, 0.4, .dark_blue),
            .wolf => rl.drawSphere(rl_pos, 0.4, .red),
            .player => unreachable,
        }
    }

    if (rl_pos.distanceSqr(context.camera.position) < 200) {
        const text_pos = rl.getWorldToScreen(rl_pos.add(.{ .x = 0, .y = 1.2, .z = 0 }), context.camera);
        const text: [:0]const u8 = @ptrCast(self.display_str_buf[0..self.display_str_len]);
        const font_size = 20;

        // TODO: is this fine?
        context.camera.end();
        rl.drawText(
            text,
            @as(i32, @intFromFloat(text_pos.x)) - @divFloor(rl.measureText(text, font_size), 2),
            @intFromFloat(text_pos.y),
            font_size,
            .black,
        );
        context.camera.begin();
    }
}

pub fn update(self: *EntityModel, us: usize) void {
    if (self.model == null)
        return;

    if (self.animation) |anim| {
        self.time_buf_us += us;
        while (us > frame_duration_us) {
            us -= frame_duration_us;
            self.anim_frame += 1;
        }

        if (self.anim_frame >= anim.frameCount) {
            self.animation = null;
        }
    }
}
