const std = @import("std");
const network = @import("network");
const net = @import("net");
const queue = @import("spsc_queue");

// TODO: better logging (detailed full packet list print?)

const InQueue = queue.SpscQueue(net.InboundPacket, true);
const OutQueue = queue.SpscQueue(net.OutboundPacket, true);

/// Running flag
var server_running: std.atomic.Value(bool) = undefined;
/// Ingame time keeper
var game_time: std.atomic.Value(i64) = undefined;
/// Timestamp of the last packet released
var last_packet_ms: std.atomic.Value(i64) = undefined;

pub fn receiverThread(alloc: std.mem.Allocator, in_stream: *std.Io.Reader, in_queue: *InQueue) !void {
    while (server_running.load(.acquire)) {
        // Read packet
        const incoming_packet = net.readPacket(alloc, in_stream) catch |e| {
            server_running.store(false, .release);
            std.debug.print("{}\n", .{e});
            if (@errorReturnTrace()) |trace| {
                std.debug.dumpStackTrace(trace.*);
            }
            continue;
        };

        const now = std.time.milliTimestamp();
        last_packet_ms.store(now, .unordered);

        // Enqueue or handle locally
        switch (incoming_packet) {
            .keep_alive_0 => {},
            .update_time_4 => |time| game_time.store(time.time, .unordered),
            .kick_disconnect_255 => |_| {
                // Stop server
                server_running.store(false, .release);
                // Push anyways (for message)
                in_queue.push(incoming_packet);
            },
            else => in_queue.push(incoming_packet),
        }

        // TEMPORARY: helps with seeing the prints in the right order
        std.Thread.sleep(1000);
    }
}

pub fn senderThread(alloc: std.mem.Allocator, out_stream: *std.Io.Writer, out_queue: *OutQueue) !void {
    _ = alloc;
    var last_sent = std.time.milliTimestamp();

    while (server_running.load(.acquire)) {
        if (out_queue.front()) |new_packet| {
            const packet = new_packet.*;
            out_queue.pop();

            // Serialize packet
            switch (packet) {
                inline else => |p| {
                    const PacketT = @TypeOf(p);
                    if (PacketT != void and @hasDecl(PacketT, "send")) {
                        // TODO: catch different errors
                        try p.send(out_stream);
                    } else {
                        std.debug.print("No send function for queued packet!\n", .{});
                    }
                },
            }

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

pub fn run(alloc: std.mem.Allocator) !void {
    server_running = .init(true);
    game_time = .init(undefined);

    try network.init();
    defer network.deinit();

    // Connect TCP socket to server
    var sock = try network.connectToHost(alloc, "localhost", 25565, .tcp);

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
    try net.handshake(&writer.interface);

    while (server_running.load(.acquire)) {
        // Pop new packet
        if (in_queue.front()) |new_packet| {
            const packet = new_packet.*;
            in_queue.pop();

            switch (packet) {
                .login_1 => |login| {
                    std.debug.print("Login successful! {any}\n", .{login});
                },
                .handshake_2 => {
                    std.debug.print("Shaked hands!\n", .{});
                    try net.login(&writer.interface);
                },
                .chat_3 => |chat| {
                    std.debug.print("\"{s}\"\n", .{chat.message});
                },
                .kick_disconnect_255 => |kick| {
                    std.debug.print("Kicked! Reason: \"{s}\"\n", .{kick.reason});
                    // Stop client
                    server_running.store(false, .release);
                },
                else => {
                    //std.debug.print("{any}\n", .{packet});
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
        } else {
            // Sleep for 100 microsecond
            std.Thread.sleep(100000);
            // Handle timeout (5 seconds)
            const now = std.time.milliTimestamp();
            const last_packet = last_packet_ms.load(.unordered);
            if (now - last_packet > 5000) {
                std.debug.print("Timeout! Disconnecting.\n", .{});
                server_running.store(false, .release);
            }
        }

        // TODO: watch time
    }

    sock.close();

    // Wait for receiver thread to stop too
    receiver_thread.join();
    sender_thread.join();
}
