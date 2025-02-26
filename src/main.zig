//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");

pub fn main() !void {
    //const arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    var commandBuffer = [_]u8{0} ** 128;
    var messageBuffer = [_]u8{0} ** 512;
    var usernameb = [_]u8{0} ** 32;
    var username: []u8 = undefined;
    var commanding = true;
    var isServer = false;
    var address: std.net.Address = undefined;
    var playercount: u8 = 0;
    var parser = Peeker{
        .buf = &commandBuffer,
    };
    while (commanding) {
        defer commandBuffer = [_]u8{0} ** 128;
        _ = stdin.readUntilDelimiter(&commandBuffer, '\n') catch |err| {
            try stdout.print("Command failed due to: {s}\n", .{@errorName(err)});
            break;
        };
        const cmd = parser.untilOrEnd(' ');
        isServer = std.mem.eql(u8, cmd, "host");
        const name = parser.untilOrEnd(' ');
        var port = parser.untilOrEnd(' ');
        if (isServer) {
            playercount = parser.untilOrEnd('\r');
        } else {
            const uname = parser.untilOrEnd('\r');
            std.mem.copyForwards(u8, usernameb[0..], uname);
            username = usernameb[0..uname.len];
        }
        const prt = std.fmt.parseInt(u16, port, 10) catch |err| {
            try stdout.print("invalid port number: {d} , err: {s}\n", .{ port, @errorName(err) });
            break;
        };
        address = std.net.Address.parseIp(name, prt) catch |err| {
            try stdout.print("invalid ip definition: name: {s} , port: {d}, err: {s}\n", .{ name, prt, @errorName(err) });
            break;
        };
        commanding = false;
        try stdout.print("server: {any} at: {any}\n", .{ isServer, address });
    }
    if (isServer) {
        var server = try address.listen(.{});
        const client = try server.accept();
        defer server.deinit();
        while (true) {
            messageBuffer = [_]u8{0} ** 512;
            try client.stream.read(&messageBuffer) catch |err| {
                switch (err) {
                    .ConnectionResetByPeer => {
                        const client = try server.accept();
                    },
                }
            };
            try stdout.print("client: {any} sent message: {s}\n", .{ client.address, messageBuffer });
        }
    } else {
        const server = try std.net.tcpConnectToAddress(address);
        while (true) {
            //commandBuffer = [_]u8{0} ** 128;
            //std.mem.copyForwards(u8, commandBuffer[0..], username[0..]);
            //commandBuffer[username.len] = ':';
            _ = try stdin.readUntilDelimiter(commandBuffer[0..], '\r');
            try server.writer().print("{s}:{s}", .{ username, commandBuffer });
        }
    }
    //std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 25532);
}

pub const Peeker = struct {
    pos: usize = 0,
    buf: []u8 = undefined,
    pub fn untilOrEnd(self: *Peeker, ch: u8) []u8 {
        const start: usize = self.pos;
        if (std.mem.indexOfScalarPos(u8, self.buf, self.pos, ch)) |next| {
            self.pos = next + 1;
        } else {
            self.pos = self.buf.len - 1;
        }
        return self.buf[start .. self.pos - 1];
    }
};
