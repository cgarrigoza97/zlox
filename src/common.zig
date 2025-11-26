const std = @import("std");
const Memory = @import("memory.zig");
const Value = @import("value.zig");

pub const OpCode = enum(u8) { op_constant, op_return };

pub const Chunk = struct {
    count: usize,
    capacity: usize,
    code: ?[*]u8,
    lines: ?[*]usize,
    constants: Value.ValueArray,

    pub fn init() Chunk {
        return .{ .count = 0, .capacity = 0, .code = null, .lines = null, .constants = Value.ValueArray.init() };
    }

    pub fn write(self: *Chunk, byte: u8, line: usize) void {
        if (self.capacity < self.count + 1) {
            const oldCapacity = self.capacity;
            self.capacity = Memory.growCapacity(oldCapacity);
            self.code = Memory.growArray(u8, self.code, oldCapacity, self.capacity);
            self.lines = Memory.growArray(usize, self.lines, oldCapacity, self.capacity);
        }

        self.code.?[self.count] = byte;
        self.lines.?[self.count] = line;
        self.count += 1;
    }

    pub fn addConstant(self: *Chunk, value: Value.Value) usize {
        self.constants.write(value);
        return self.constants.count - 1;
    }

    pub fn free(self: *Chunk) void {
        Memory.freeArray(u8, self.code, self.capacity);
        Memory.freeArray(usize, self.lines, self.capacity);
        self.constants.free();
        self.* = init();
    }
};
