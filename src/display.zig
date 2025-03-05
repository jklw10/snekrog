const utils = @import("utils");
const std = @import("std");
const gl = @import("zgl");

const v2 = utils.vec2(i8);

const gldisplay = struct {
    pub fn showAt(pos: v2, sprite: u8) void {
        _ = pos;
        _ = sprite;
    }
    pub fn init() void {}
};
