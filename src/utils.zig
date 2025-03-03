pub fn vec2(t: type) type {
    return struct {
        x: t,
        y: t,
        pub fn add(self: @This(), other: @This()) @This() {
            self.x += other.x;
            self.y += other.y;
            return self;
        }
        pub fn mul(self: @This(), other: @This()) @This() {
            self.x *= other.x;
            self.y *= other.y;
            return self;
        }
        pub fn sub(self: @This(), other: @This()) @This() {
            self.x -= other.x;
            self.y -= other.y;
            return self;
        }
        pub fn div(self: @This(), other: @This()) @This() {
            self.x /= other.x;
            self.y /= other.y;
            return self;
        }
        pub fn mod(self: @This(), other: @This()) @This() {
            self.x %= other.x;
            self.y %= other.y;
            return self;
        }
    };
}
