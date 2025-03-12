const utils = @import("utils.zig");
const std = @import("std");
const gl = @import("zgl");

const v2 = utils.vec2(i8);
const vsize = utils.vec2(usize);

const Buffer = struct {
    handle: gl.Buffer,
    target: gl.BufferTarget,
    usage: gl.BufferUsage,
    attribute: ?u32,
    itemtype: type,
    dimension: ?u8,
    datacount: usize = 0,
    pub fn create(target: gl.BufferTarget, usage: gl.BufferUsage, itemtype: type) Buffer {
        return Buffer{
            .handle = gl.Buffer.create(),
            .target = target,
            .usage = usage,
            .itemtype = itemtype,
        };
    }
    pub fn use(self: Buffer) void {
        gl.bindBuffer(self.handle, self.target);
    }
    pub fn setData(self: Buffer, items: []align(1) self.itemtype) void {
        self.use();
        self.datacount = items.len;
        gl.bufferData(self.target, self.itemtype, items, self.usage);
    }
    pub fn enable(self: Buffer) void {
        self.use();
        if (self.attribute) |attribute| {
            gl.vertexAttribIPointer(attribute, self.dimension, self.itemtype, false, self.dimension, 0);
            gl.enableVertexAttribArray(attribute);
        } else return error.noAttribute;
    }
};
const EBO = struct {
    IBO: Buffer = Buffer.create(gl.BufferTarget.element_array_buffer, gl.BufferUsage.static_draw, u32),
    VBO: []Buffer,
    VAO: gl.VertexArray,
    pub fn create(indices: []u32, vertData: []Buffer) EBO {
        const vao = gl.VertexArray.create();
        gl.bindVertexArray(vao);
        for (vertData) |vbo| {
            vbo.enable();
        }
        const ibo = Buffer.create(gl.BufferTarget.element_array_buffer, gl.BufferUsage.static_draw, u32);
        ibo.setData(indices);
        return EBO{
            .VAO = vao,
            .VBO = vertData,
            .IBO = ibo,
        };
    }
    pub fn use(self: EBO) void {
        gl.bindVertexArray(self.VAO);
    }
};
const Texture = struct {
    const Format = enum(u8) {
        color4,
        float3,
        float,
        depth,
    };
    handle: gl.Texture,
    target: []u8,
    format: Format,
    pub fn create(format: Format, size: vsize, target: []u8) Texture {
        var handle = gl.Texture.create(gl.TextureTarget.@"2d");
        var self = Texture{
            .handle = handle,
            .target = target,
            .format = format,
        };
        handle.bind(gl.TextureTarget.@"2d");
        const f = switch (format) {
            .color4 => gl.TextureInternalFormat.rgba,
            .float3 => gl.TextureInternalFormat.rgb32f,
            .float => gl.TextureInternalFormat.r32f,
            .depth => gl.TextureInternalFormat.depth_component,
        };
        switch (format) {
            .depth => self.depth(),
            else => self.default(),
        }
        handle.storage2D(1, f, size.x, size.y);
    }
    pub fn depth(self: Texture) void {
        self.handle.parameter(.compare_mode, .none);
        self.handle.parameter(.min_filter, .nearest);
        self.handle.parameter(.mag_filter, .nearest);
        self.handle.parameter(.wrap_s, .clamp_to_edge);
        self.handle.parameter(.wrap_t, .clamp_to_edge);
        self.handle.parameter(.compare_func, .lequal);
    }
    pub fn default(self: Texture) void {
        self.handle.parameter(.min_filter, .linear);
        self.handle.parameter(.mag_filter, .linear);
        self.handle.parameter(.wrap_s, .clamp_to_edge);
        self.handle.parameter(.wrap_t, .clamp_to_edge);
    }
};

const FrameBuffer = struct {
    handle: gl.Framebuffer = gl.Framebuffer.create(),
    pub const default = create(0);
    pub fn create(texture: Texture) FrameBuffer {
        var self = FrameBuffer{};
        self.handle.texture2D(.draw_buffer, .draw_buffer, .color4, texture, 0);
        return self;
    }
};
const Program = struct {
    handle: gl.Program,
    pub fn create(paths: [2][]u8, allocator: std.mem.Allocator) !Program {
        var handle: gl.Program = gl.Program.create();
        const shad1 = try loadShader(paths[0], gl.ShaderType.vertex, allocator);
        const shad2 = try loadShader(paths[1], gl.ShaderType.fragment, allocator);
        handle.attach(shad1);
        defer handle.detach(shad1);
        handle.attach(shad2);
        defer handle.detach(shad2);
        handle.link();
        if (gl.getProgram(handle, gl.ProgramParameter.link_status) == 0) {
            std.debug.print("shader compiler error: {s}", try handle.getCompileLog(allocator));
            return error.ProgramLinkFail;
        }
        return Program{
            .handle = handle,
        };
    }
    pub fn loadShader(shaderPath: []u8, stype: gl.ShaderType, allocator: std.mem.Allocator) !gl.Shader {
        const handle = gl.Shader.create(stype);
        const file = try std.fs.cwd().openFile(shaderPath, .{});
        defer file.close();
        const shader = try file.reader().readAllAlloc(allocator, 1_000_000_000); //i certainly hope your shader isn't a gigabyte in size
        handle.source(1, &[1][]u8{shader});
        handle.compile();
        if (handle.get(gl.ShaderParameter.compile_status) == 0) {
            std.debug.print("shader compiler error: {s}", try handle.getCompileLog(allocator));
            return error.shaderCompilationFail;
        }
        return handle;
    }
};
const Square = struct {
    ebo: EBO,
    program: Program,
    framebuffer: FrameBuffer,
    textures: Texture,
    pub fn make(allocator: std.mem.Allocator) !Square {
        var verts = Buffer.create(gl.BufferTarget.array_buffer, gl.BufferUsage, f32);
        verts.attribute = 0;
        verts.setData([]f32{ 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0 });
        const buf = [_]Buffer{
            verts,
        };

        const ebo = EBO.create([_]u32{ 0, 1, 2, 1, 2, 3 }, buf);
        const prog = try Program.create([2][]u8{ "shaders/square.vert", "shaders/square.frag" }, allocator);
        const fb = FrameBuffer.default;
        const tx = Texture.create(.color4, .{ .x = 1, .y = 1 }, "");
        return Square{
            .ebo = ebo,
            .program = prog,
            .framebuffer = fb,
            .textures = tx,
        };
    }
    pub fn use(self: Square) void {
        self.program.use();
        self.framebuffer.use();
        self.ebo.use();
        self.textures.use();
    }
};
//const fbt = gl.FramebufferTarget.draw_buffer;
//const outputBuffer = gl.Framebuffer.create();
//const program = gl.Program.create();
//const t2d = gl.TextureTarget.@"2d";
//const texture = gl.Texture.create(t2d);
const square = Square.make();
const gldisplay = struct {
    pub fn showAt(pos: v2, sprite: u8) void {
        square.use();
        _ = pos;
        _ = sprite;
    }
    pub fn init() void {}
};
