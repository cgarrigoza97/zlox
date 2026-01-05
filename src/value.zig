const std = @import("std");

const Memory = @import("memory.zig");
const Object = @import("object.zig");

pub const ValueType = enum(u8) {
    bool,
    nil,
    number,
    obj,
};

// pub const Value = f64;
pub const Value = struct {
    valueType: ValueType,
    as: union {
        boolean: bool,
        number: f64,
        obj: *Object.Obj,
    },
};

pub inline fn numberVal(value: f64) Value {
    return .{ .as = .{ .number = value }, .valueType = .number };
}

pub inline fn objVal(value: *Object.Obj) Value {
    return .{ .as = .{ .obj = value }, .valueType = .obj };
}

pub inline fn booleanVal(value: bool) Value {
    return .{ .as = .{ .boolean = value }, .valueType = .bool };
}

pub inline fn nilVal() Value {
    return .{ .as = .{ .boolean = false }, .valueType = .nil };
}

pub inline fn asNumber(value: Value) f64 {
    return value.as.number;
}

pub inline fn asObj(value: Value) *Object.Obj {
    return value.as.obj;
}

pub inline fn asBoolean(value: Value) bool {
    return value.as.boolean;
}

pub inline fn isNumber(value: Value) bool {
    return value.valueType == .number;
}

pub inline fn isObj(value: Value) bool {
    return value.valueType == .obj;
}

pub inline fn isBoolean(value: Value) bool {
    return value.valueType == .bool;
}

pub inline fn isNil(value: Value) bool {
    return value.valueType == .nil;
}

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
    switch (value.valueType) {
        .bool => std.debug.print("{s}", .{if (asBoolean(value)) "true" else "false"}),
        .nil => std.debug.print("nil", .{}),
        .number => std.debug.print("{d}", .{asNumber(value)}),
        .obj => Object.printObject(value),
    }
}

pub fn valuesEqual(a: Value, b: Value) bool {
    if (a.valueType != b.valueType) return false;
    switch (a.valueType) {
        .bool => return asBoolean(a) == asBoolean(b),
        .nil => return true,
        .number => return asNumber(a) == asNumber(b),
        .obj => {
            const aString = Object.asString(asObj(a));
            const bString = Object.asString(asObj(b));

            const aSlice: []const u8 = @ptrCast(aString.chars);
            const bSlice: []const u8 = @ptrCast(bString.chars);

            return aString.length == bString.length and std.mem.eql(u8, aSlice, bSlice);
        },
    }
}
