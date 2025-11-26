const std = @import("std");

const Memory = @import("memory.zig");

pub const Value = f64;

pub const ValueArray = struct {
    capacity: usize,
    count: usize,
    values: ?[*]Value,

    pub fn init() ValueArray {
        return .{
            .capacity = 0,
            .count = 0,
            .values = null,
        };
    }

    pub fn write(self: *ValueArray, value: Value) void {
        if (self.capacity < self.count + 1) {
            const oldCapacity = self.capacity;
            self.capacity = Memory.growCapacity(oldCapacity);
            self.values = Memory.growArray(Value, self.values, oldCapacity, self.capacity);
        }

        self.values.?[self.count] = value;
        self.count += 1;
    }

    pub fn free(self: *ValueArray) void {
        Memory.freeArray(Value, self.values, self.capacity);
        self.* = init();
    }
};

pub fn printValue(value: Value) void {
    std.debug.print("{d}", .{value});
}
