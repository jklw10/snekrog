const std = @import("std");
const utils = @import("utils.zig");
const display = @import("display.zig");
const EndToken: u8 = 250;

pub fn vlock(vtype: type) type {
    return struct {
        const Self = @This();
        lock: std.Thread.Mutex = .{},
        value: vtype,
        pub fn lockfor(self: *Self, t: void) void {
            self.lock.lock();
            t;
            self.lock.unlock();
        }
    };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    var commandBuffer = [_]u8{0} ** 128;
    var messageBuffer = [_]u8{0} ** 512;
    _ = .{ stdin, stdout, &messageBuffer };
    var usernameb = [_]u8{0} ** 32;
    var username: []u8 = undefined;
    var commanding = true;
    var isServer = false;
    var address: std.net.Address = undefined;
    var playerCount: usize = 0;
    var maxPlayers: usize = 0;
    var parser = Peeker{
        .buf = &commandBuffer,
    };
    while (commanding) {
        defer commandBuffer = [_]u8{0} ** 128;
        _ = stdin.readUntilDelimiter(&commandBuffer, '\n') catch |err| {
            std.debug.print("Command failed due to: {s}\n", .{@errorName(err)});
            break;
        };
        const cmd = parser.untilOrEnd(' ');
        isServer = std.mem.eql(u8, cmd, "host");
        const name = parser.untilOrEnd(' ');
        const port = parser.untilOrEnd(' ');
        if (isServer) {
            const count = parser.untilOrEnd('\r');
            maxPlayers = std.fmt.parseInt(u8, count, 10) catch |err| {
                std.debug.print("invalid player count: {d} , err: {s}\n", .{ count, @errorName(err) });
                break;
            };
        } else {
            const uname = parser.untilOrEnd('\r');
            std.mem.copyForwards(u8, usernameb[0..], uname);
            username = usernameb[0..uname.len];
        }
        const prt = std.fmt.parseInt(u16, port, 10) catch |err| {
            std.debug.print("invalid port number: {d} , err: {s}\n", .{ port, @errorName(err) });
            break;
        };
        address = std.net.Address.parseIp(name, prt) catch |err| {
            std.debug.print("invalid ip definition: name: {s} , port: {d}, err: {s}\n", .{ name, prt, @errorName(err) });
            break;
        };
        commanding = false;
        std.debug.print("server: {any} at: {any}\n", .{ isServer, address });
    }

    if (isServer) {
        var server = try address.listen(.{ .force_nonblocking = true });

        var clients: []std.net.Server.Connection = try arena.allocator().alloc(std.net.Server.Connection, maxPlayers);
        const lval = .{
            .clients = &clients,
            .playerCount = &playerCount,
        };
        var clLock = vlock(@TypeOf(lval)){ .value = lval };
        defer server.deinit();
        var t = try std.Thread.spawn(.{}, acceptor, .{ &server, &clLock, maxPlayers });
        _ = &t;
        while (true) {}
    } else {
        const server = try std.net.tcpConnectToAddress(address);
        while (true) {
            commandBuffer = [_]u8{0} ** 128;
            //std.mem.copyForwards(u8, commandBuffer[0..], username[0..]);
            //commandBuffer[username.len] = ':';
            const msize = try stdin.readUntilDelimiter(commandBuffer[0..], '\r');
            try stdin.skipBytes(1, .{}); //skip the newline at the end >:)
            try server.writer().print("{s}:{s}" ++ .{EndToken}, .{ username, commandBuffer[0..msize.len] });
        }
    }
    //std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 25532);
}

fn acceptor(server: *std.net.Server, clients: anytype, maxPlayers: usize) !void {
    while (true) {
        if (clients.value.playerCount.* < maxPlayers) {
            if (try tryaccept(server)) |pc| {
                clients.lockfor({
                    std.debug.print("pj", .{});
                    clients.value.clients.*[clients.value.playerCount.*] = pc;
                    clients.value.playerCount.* += 1;
                });
            }
        }

        if (clients.value.playerCount.* <= 0) continue;
        var messageBuffer = [_]u8{0} ** 512;
        for (0..clients.value.playerCount.*) |i| {
            var client = &clients.value.clients.*[i];
            _ = client.stream.reader().readUntilDelimiter(&messageBuffer, EndToken) catch |err| {
                switch (err) {
                    error.ConnectionResetByPeer => {
                        if (try tryaccept(server)) |pc| {
                            client.* = pc;
                        } else {
                            continue;
                        }
                    },
                    else => return err,
                }
            };
            std.debug.print("client: {any} sent message: {s}\r\n", .{ client.address, messageBuffer });
        }
    }
}

pub fn tryaccept(server: *std.net.Server) !?std.net.Server.Connection {
    if (server.*.accept()) |pc| {
        return pc;
    } else |err| {
        switch (err) {
            error.WouldBlock => return null,
            else => return err,
        }
    }
}
pub fn Map(size: ivec2) type {
    return struct {
        data: []u8 = [_]u8{0} ** (size.x * size.y),
        pub fn set(self: Map, pos: ivec2, ch: u8) void {
            self.data[pos.x + pos.y * size.x] = ch;
        }
        pub fn get(self: Map, pos: ivec2) u8 {
            return self.data[pos.x + pos.y * size.x];
        }
    };
}
pub const ivec2 = utils.vec2(i8);
pub const visible: Map(.{ .x = 16, .y = 16 }) = .{};
pub const world: Map(.{ .x = 128, .y = 128 }) = .{};

pub fn render(writer: anytype) void {
    _ = writer;
}

pub const Filter = struct {
    pub fn toServer(text: []u8) void {
        var pos = 0;
        while (std.mem.indexOfScalarPos(u8, text, pos, EndToken)) |next| {
            pos = next;
            text[pos] = 251;
        }
    }
    pub fn toClient(text: []u8) void {
        var pos = 0;
        while (std.mem.indexOfScalarPos(u8, text, pos, 251)) |next| {
            pos = next;
            text[pos] = EndToken;
        }
    }
};

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
