const std = @import("std");
const io = @import("io");
const network = @import("network");
const net = @import("net");
const queue = @import("spsc_queue");

const World = @import("terrain").World;

// TODO: better logging (detailed full packet list print?)

const InQueue = queue.SpscQueue(net.InboundPacket, true);
const OutQueue = queue.SpscQueue(net.OutboundPacket, true);

/// Running flag
var server_running: std.atomic.Value(bool) = undefined;
/// Ingame time keeper
var game_time: std.atomic.Value(i64) = undefined;
/// Timestamp of the last packet released
var last_packet_ms: std.atomic.Value(i64) = undefined;

fn receiverThread(alloc: std.mem.Allocator, in_stream: *std.Io.Reader, in_queue: *InQueue) !void {
    while (server_running.load(.acquire)) {
        // Read packet
        const incoming_packet = net.readPacket(alloc, in_stream) catch |e| {
            // Stop server on error (TODO: recoverable errors?)
            server_running.store(false, .release);
            if (e == error.EndOfStream) {
                std.debug.print("Server closed socket.\n", .{});
            } else {
                std.debug.print("{}\n", .{e});
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpStackTrace(trace.*);
                }
            }
            continue;
        };

        const now = std.time.milliTimestamp();
        last_packet_ms.store(now, .unordered);

        // Enqueue or handle locally
        switch (incoming_packet) {
            .keep_alive_0 => {},
            .update_time_4 => |time| game_time.store(time.time, .unordered),
            else => in_queue.push(incoming_packet),
        }

        // TEMPORARY: helps with seeing the prints in the right order
        std.Thread.sleep(1000);
    }
}

fn senderThread(alloc: std.mem.Allocator, out_stream: *std.Io.Writer, out_queue: *OutQueue) !void {
    _ = alloc;
    var last_sent = std.time.milliTimestamp();

    while (server_running.load(.acquire)) {
        if (out_queue.front()) |new_packet| {
            const packet = new_packet.*;
            out_queue.pop();

            // Serialize packet
            try packet.send(out_stream);

            // TODO: deinit packets that are allocated

            last_sent = std.time.milliTimestamp();
        } else {
            // Sleep for 100 microsecond
            std.Thread.sleep(100000);

            // Keepalive-er
            if (std.time.milliTimestamp() - last_sent > 1000) {
                last_sent = std.time.milliTimestamp();
                const ka = net.server_bound.Packet0KeepAlive{};
                try ka.send(out_stream);
                //std.debug.print("KeepAlive\n", .{});
            }
        }
    }
}

// TODO: omit reference to out_queue
fn enqueuePacket(out_queue: *OutQueue, packet: anytype) void {
    std.debug.assert(out_queue.tryPush(net.OutboundPacket.encapsulate(packet)));
}

var last_tick: i64 = 0;
/// TEMPORARY function to manage tick rate
fn shouldTick() bool {
    if (std.time.milliTimestamp() - last_tick >= 50) {
        last_tick = std.time.milliTimestamp();
        return true;
    } else {
        return false;
    }
}

pub fn run(alloc: std.mem.Allocator) !void {
    server_running = .init(true);
    game_time = .init(undefined);

    try network.init();
    defer network.deinit();

    // Connect TCP socket to server
    var sock = network.connectToHost(alloc, "localhost", 25565, .tcp) catch |e| {
        std.debug.print("Couldn't connect! {}\n", .{e});
        return;
    };

    const local: network.EndPoint = try sock.getLocalEndPoint();
    const remote: network.EndPoint = try sock.getRemoteEndPoint();

    std.debug.print("local: {f}\n", .{local});
    std.debug.print("remote: {f}\n", .{remote});

    {
        // Setup timeout system
        const now = std.time.milliTimestamp();
        last_packet_ms.store(now, .unordered);
    }

    // Read/write buffers and interfaces to TCP socket
    var buf_write: [1024]u8 = undefined;
    var writer = sock.writer(&buf_write);

    var buf_read: [1024]u8 = undefined;
    var reader = sock.reader(&buf_read);

    // Incoming packet queue // TODO: proper queue size?
    const in_queue_buf = try alloc.alloc(net.InboundPacket, 32);
    defer alloc.free(in_queue_buf);
    var in_queue = try InQueue.initCapacity(alloc, 32);
    defer in_queue.deinit();

    // Outgoing packet queue
    const out_queue_buf = try alloc.alloc(net.OutboundPacket, 32);
    defer alloc.free(out_queue_buf);
    var out_queue = try OutQueue.initCapacity(alloc, 32);
    defer out_queue.deinit();

    // Start threads
    // TODO: use io.Threaded later?
    var receiver_thread = try std.Thread.spawn(.{}, receiverThread, .{ alloc, &reader.interface, &in_queue });
    var sender_thread = try std.Thread.spawn(.{}, senderThread, .{ alloc, &writer.interface, &out_queue });

    // Initiate handshake
    enqueuePacket(&out_queue, net.server_bound.Packet2Handshake{ .username = "MainCraft1" });
    var is_connected = false;

    var window = try io.GameWindow.init();
    defer window.deinit();

    var world: World = try .init(alloc);
    defer world.deinit();

    //Temporary to satisfy server expecting us to match the expected position
    var last_plm = net.server_bound.Packet13PlayerLookMove{ .x_position = 10.5, .y_position = 66.0, .y_center_position = 66.62, .z_position = -118.5, .yaw = 0, .pitch = 0, .on_ground = false };

    while (server_running.load(.acquire)) {
        // Pop new packet
        while (in_queue.front()) |new_packet| {
            const packet = new_packet.*;
            in_queue.pop();

            switch (packet) {
                .login_1 => |login| {
                    std.debug.print("Login successful! {any}\n", .{login});
                    is_connected = true;
                },
                .handshake_2 => {
                    std.debug.print("Shaked hands!\n", .{});
                    enqueuePacket(&out_queue, net.server_bound.Packet1Login{ .username = "MainCraft1" });
                },
                .chat_3 => |chat| {
                    std.debug.print("\"{s}\"\n", .{chat.message});
                },
                .player_look_move_13 => |plm| {
                    last_plm = plm;
                    window.setPlayerMarker(.{ .x = plm.x_position, .y = plm.y_position, .z = plm.z_position });
                    std.debug.print("{any}\n", .{packet});
                },
                .pre_chunk_50 => |pc| {
                    try world.doPreChunk(.{ .x = pc.x_position, .z = pc.z_position }, pc.mode);
                },
                .map_chunk_51 => |mc| {
                    try world.doChunkMap(mc.x_position, mc.y_position, mc.z_position, mc.x_size, mc.y_size, mc.z_size, mc.data);
                },
                .kick_disconnect_255 => |kick| {
                    std.debug.print("Kicked! Reason: \"{s}\"\n", .{kick.reason});
                    // Stop client
                    server_running.store(false, .release);
                },
                inline else => |pack| {
                    if (!@hasDecl(@TypeOf(pack), "DonutPrint"))
                        std.debug.print("{any}\n", .{packet});
                },
            }

            // Deinit if there is a deinit function
            // TODO: does this generate lots of branches?
            switch (packet) {
                inline else => |p| {
                    if (@hasDecl(@TypeOf(p), "deinit")) {
                        p.deinit(alloc);
                    }
                },
            }
        }

        // Handle timeout (5 seconds)
        const now = std.time.milliTimestamp();
        const last_packet = last_packet_ms.load(.unordered);
        if (now - last_packet > 5000) {
            //std.debug.print("Timeout! Disconnecting.\n", .{});
            //server_running.store(false, .release);
        }

        if (is_connected and shouldTick()) {
            // run game prototype
            // Server should kick us after a while for flying
            //enqueuePacket(&out_queue, net.server_bound.Packet10OnGround{ .on_ground = true });
            last_plm.y_position -= 0.1;
            last_plm.y_center_position -= 0.1;
            if (last_plm.y_center_position < last_plm.y_position) {
                // TODO: whyyy?? why is this needed
                const swap = last_plm.y_center_position;
                last_plm.y_center_position = last_plm.y_position;
                last_plm.y_position = swap;
            }
            //std.debug.print("Dy: {}\n", .{last_plm.y_center_position - last_plm.y_position});
            enqueuePacket(&out_queue, last_plm);
        }

        if (window.hasClosed()) {
            std.debug.print("Closing!\n", .{});
            server_running.store(false, .release);
            continue;
        }

        window.update();
        window.beginDraw();
        window.drawWorld(world);
        window.endDraw();
    }

    sock.close();

    // Wait for receiver thread to stop too
    receiver_thread.join();
    sender_thread.join();
}
