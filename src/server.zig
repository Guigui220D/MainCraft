const std = @import("std");
const network = @import("network");
const net = @import("net");

pub fn receiverThread(alloc: std.mem.Allocator, stream: *std.Io.Reader) !void {
    _ = alloc;
    _ = stream;
}

pub fn run(alloc: std.mem.Allocator) !void {
    try network.init();
    defer network.deinit();

    const sock = try network.connectToHost(alloc, "localhost", 25565, .tcp);
    defer sock.close();

    const local: network.EndPoint = try sock.getLocalEndPoint();
    const remote: network.EndPoint = try sock.getRemoteEndPoint();

    std.debug.print("local: {f}\n", .{local});
    std.debug.print("remote: {f}\n", .{remote});

    var buf_write: [1024]u8 = undefined;
    var writer = sock.writer(&buf_write);

    var buf_read: [1024]u8 = undefined;
    var reader = sock.reader(&buf_read);

    //const receiver_thread = try std.Thread.spawn(.{}, receiverThread, .{ alloc, &reader.interface });
    //receiver_thread.join();

    try net.handshake(&writer.interface);
    try net.readPacket(&reader.interface);
    try net.login(&writer.interface);

    while (true) {
        try net.readPacket(&reader.interface);
    }
}
