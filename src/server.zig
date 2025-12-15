const std = @import("std");
const network = @import("network");
const net = @import("net");
const queue = @import("spsc_queue");

// TODO: use mutex + ringbuffer instead? or std.Io.Queue when 0.16 comes out and network.zig updates?
const InQueue = queue.SpscQueue(net.InboundPacket, true);
// const OutQueue = std.Io.Queue(net.OutboundPacket);

pub fn receiverThread(alloc: std.mem.Allocator, in_stream: *std.Io.Reader, in_queue: *InQueue) !void {
    while (true) {
        const incoming_packet = try net.readPacket(alloc, in_stream);
        in_queue.push(incoming_packet);

        // TODO: handle locally packets that are very simple (keep alive, set time)
    }
}

pub fn run(alloc: std.mem.Allocator) !void {
    try network.init();
    defer network.deinit();

    // Connect TCP socket to server
    const sock = try network.connectToHost(alloc, "localhost", 25565, .tcp);
    defer sock.close();

    const local: network.EndPoint = try sock.getLocalEndPoint();
    const remote: network.EndPoint = try sock.getRemoteEndPoint();

    std.debug.print("local: {f}\n", .{local});
    std.debug.print("remote: {f}\n", .{remote});

    // Read/write buffers and interfaces to TCP socket
    var buf_write: [1024]u8 = undefined;
    var writer = sock.writer(&buf_write);

    var buf_read: [1024]u8 = undefined;
    var reader = sock.reader(&buf_read);

    // Incoming packet queue
    const in_queue_buf = try alloc.alloc(net.InboundPacket, 128);
    defer alloc.free(in_queue_buf);
    var in_queue = try InQueue.initCapacity(alloc, 128);
    defer in_queue.deinit();

    // Start thread
    // TODO: use io.Threaded later?
    var receiver_thread = try std.Thread.spawn(.{}, receiverThread, .{ alloc, &reader.interface, &in_queue });

    // Initiate handshake
    try net.handshake(&writer.interface);

    // Temporary: run the server for only 3 seconds
    const start_timestamp = std.time.milliTimestamp();
    while (std.time.milliTimestamp() - start_timestamp < 3000) {
        // Pop new packet
        if (in_queue.front()) |new_packet| {
            const packet = new_packet.*;
            in_queue.pop();

            switch (packet) {
                .handshake_2 => {
                    try net.login(&writer.interface);
                },
                else => {
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
    }

    // TODO: stop condition (this only works right now as the thread crashes from bad packet)
    receiver_thread.join();
}
