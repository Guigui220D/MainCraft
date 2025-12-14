const std = @import("std");
const nbt = @import("nbt");
const network = @import("network");
const net = @import("net");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const alloc = gpa.allocator();

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

    try net.handshake(&writer.interface);

    while (true) {
        try net.readPacket(&reader.interface);
    }
}
