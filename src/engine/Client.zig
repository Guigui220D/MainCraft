//! Client module, where the client game logic happens

const std = @import("std");
const network = @import("network");
const net = @import("net");
const queue = @import("spsc_queue");
const io = @import("io");

const Game = @import("Game.zig");
const Client = @This();

const InQueue = queue.SpscQueue(net.InboundPacket, true);
const OutQueue = queue.SpscQueue(net.OutboundPacket, true);

// arbitrary
const packet_queue_size = 32;
const stream_buf_size = 1024;

/// Allocator used by the client
alloc: std.mem.Allocator,

/// Server running flag
server_running: std.atomic.Value(bool),

/// Is the login complete
is_connected: bool,

/// TCP socket to the server
socket: network.Socket,

/// Timestamp of the last packet released
last_packet_ms: std.atomic.Value(i64),

// In/out net packet queues
/// Incoming net packets queue
in_queue: InQueue,
/// Outgoing net packets queue
out_queue: OutQueue,

// Threads
/// Ingoing packet decoder thread
in_thread: std.Thread,
/// Outgoing packet encoder thread
out_thread: std.Thread,

// Buffers for net readers/writers
/// Net reader (receiver) buffer
reader_buf: []u8,
/// Net writer (sender) buffer
writer_buf: []u8,

// Network stream readers/writers
/// Net reader (receiver)
reader: network.Socket.Reader,
/// Net writer (sender)
writer: network.Socket.Writer,

// Game data
/// Game structure
game: Game,

/// Initialize the client (connects to the server)
/// The address of the client and its components is kept, so make sure it stays valid
pub fn init(client: *Client, alloc: std.mem.Allocator, window: *io.GameWindow, address: []const u8, port: u16) !void {
    client.alloc = alloc;

    // General variables
    client.is_connected = false;

    // Game state
    try client.game.init(alloc, client, window);
    errdefer client.game.deinit();

    // Running flag
    client.server_running = .init(true);
    errdefer client.server_running.store(false, .release);

    // Initialize queues
    client.in_queue = try InQueue.initCapacity(alloc, packet_queue_size);
    errdefer client.in_queue.deinit();

    client.out_queue = try OutQueue.initCapacity(alloc, packet_queue_size);
    errdefer client.out_queue.deinit();

    // Connect socket
    client.socket = try network.connectToHost(alloc, address, port, .tcp);
    errdefer client.socket.close();

    // Initialize streams
    client.reader_buf = try alloc.alloc(u8, stream_buf_size);
    errdefer alloc.free(client.reader_buf);

    client.writer_buf = try alloc.alloc(u8, stream_buf_size);
    errdefer alloc.free(client.writer_buf);

    client.reader = client.socket.reader(client.reader_buf);
    client.writer = client.socket.writer(client.writer_buf);

    // Init timeout counter
    client.last_packet_ms.store(std.time.milliTimestamp(), .unordered);

    // Start threads
    client.in_thread = try std.Thread.spawn(.{}, receiverThread, .{client});
    errdefer client.in_thread.detach();

    client.out_thread = try std.Thread.spawn(.{}, senderThread, .{client});
    errdefer client.out_thread.detach();

    // Initiate handshake/login
    client.enqueuePacket(net.server_bound.Packet2Handshake{ .username = "MainCraft1" });
}

/// Deinit the client and disconnect
pub fn deinit(self: *Client) void {
    self.server_running.store(false, .release);
    std.Thread.sleep(100000000); // Give time (100ms) to the socket/thread to stop

    self.socket.close();

    self.out_thread.join();
    self.in_thread.join();

    // Free remaining packets
    while (self.in_queue.front()) |new_packet| {
        const packet = new_packet.*;
        self.in_queue.pop();

        packet.deinit(self.alloc);
    }

    self.alloc.free(self.writer_buf);
    self.alloc.free(self.reader_buf);

    self.out_queue.deinit();
    self.in_queue.deinit();

    self.game.deinit();
}

// TODO: better logging

/// Update the client
pub fn update(self: *Client, delta: f32) !bool {
    if (self.server_running.load(.acquire)) {
        // Pop new packet
        while (self.in_queue.front()) |new_packet| {
            const packet = new_packet.*;
            defer packet.deinit(self.alloc);
            self.in_queue.pop();

            switch (packet) {
                .login_1 => |login| {
                    std.debug.print("Login successful! {any}\n", .{login});
                    self.is_connected = true;
                },
                .handshake_2 => {
                    std.debug.print("Shaked hands!\n", .{});
                    self.enqueuePacket(net.server_bound.Packet1Login{ .username = "MainCraft1" });
                },
                .kick_disconnect_255 => |kick| {
                    std.debug.print("Kicked! Reason: \"{s}\"\n", .{kick.reason});
                    // Stop client
                    self.server_running.store(false, .release);
                },
                else => {
                    try self.game.handlePacket(packet);
                },
            }
        }

        // Check for timeout (3 seconds)
        const now = std.time.milliTimestamp();
        const last_packet = self.last_packet_ms.load(.unordered);
        if (now - last_packet > 3000) {
            std.debug.print("Timeout! Disconnecting.\n", .{});
            self.server_running.store(false, .release);
        }

        // Run game update
        _ = try self.game.update(delta);

        return true;
    } else {
        return false;
    }
}

/// Adds a server-bound packet to the queue for sending
pub fn enqueuePacket(self: *Client, packet: anytype) void {
    const pack = if (@TypeOf(packet) == net.OutboundPacket) packet else net.OutboundPacket.encapsulate(packet);

    if (!self.out_queue.tryPush(pack)) {
        std.debug.print("Couldn't enqueue outbounds packet! Something is stuck...", .{});
        self.server_running.store(false, .release);
    }
}

/// Receiver thread (in_thread) function
fn receiverThread(self: *Client) !void {
    const reader = &self.reader.interface;

    while (self.server_running.load(.acquire)) {
        // Read packet
        const incoming_packet = net.readPacket(self.alloc, reader) catch |e| {
            // Stop server on error (TODO: recoverable errors?)
            self.server_running.store(false, .release);
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
        self.last_packet_ms.store(now, .unordered);

        // Enqueue or handle locally
        switch (incoming_packet) {
            .keep_alive_0 => {},
            //.update_time_4 => |time| game_time.store(time.time, .unordered),
            else => self.in_queue.push(incoming_packet),
        }
    }
}

/// Sender thread (out_thread) function
fn senderThread(self: *Client) !void {
    const writer = &self.writer.interface;
    var last_sent = std.time.milliTimestamp();

    while (self.server_running.load(.acquire)) {
        if (self.out_queue.front()) |new_packet| {
            const packet = new_packet.*;
            self.out_queue.pop();

            // Serialize packet
            try packet.send(writer);

            last_sent = std.time.milliTimestamp();
        } else {
            // Sleep for 100 microsecond to avoid hogging cpu
            std.Thread.sleep(100000);

            // Keepalive every 1 sec when not sending anything
            if (std.time.milliTimestamp() - last_sent > 1000) {
                last_sent = std.time.milliTimestamp();
                const ka = net.server_bound.Packet0KeepAlive{};
                try ka.send(writer);
            }
        }
    }
}
