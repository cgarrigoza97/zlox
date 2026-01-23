const std = @import("std");

const Memory = @import("memory.zig");
const VM = @import("vm.zig");
const Value = @import("value.zig");

pub inline fn allocateObj(comptime T: type, objectType: ObjType) *T {
    const objString: *T = @ptrCast(@alignCast(allocateObject(@sizeOf(T), objectType)));
    return objString;
}

pub inline fn allocateObject(size: usize, objectType: ObjType) *Obj {
    const object: *Obj = @ptrCast(@alignCast(Memory.reallocate(null, 0, size)));
    object.objType = objectType;

    if (VM.vm.objects) |objs| {
        object.next = objs;
        VM.vm.objects = object;
    }

    return object;
}

pub inline fn objType(value: Value.Value) ObjType {
    return value.as.obj.objType;
}

pub inline fn isString(value: Value.Value) bool {
    return isObjType(value, .string);
}

pub inline fn isObjType(value: Value.Value, objectType: ObjType) bool {
    return Value.isObj(value) and Value.asObj(value).objType == objectType;
}

pub inline fn asString(value: *Obj) *ObjString {
    return @fieldParentPtr("obj", value);
}

pub inline fn asZString(value: *Obj) *[]u8 {
    return asString(value).chars;
}

pub const ObjType = enum(u8) {
    string,
};

pub const Obj = struct { objType: ObjType, next: *Obj };

pub const ObjString = struct {
    obj: Obj,
    length: usize,
    chars: *[]u8,
};

pub fn copyString(chars: []u8) *ObjString {
    const opaque_ptr = Memory.allocate(u8, chars.len + 1) orelse @panic("Out of memory");
    const ptr: [*]u8 = @ptrCast(opaque_ptr);
    const heapChars = ptr[0 .. chars.len + 1];
    @memcpy(heapChars[0..chars.len], chars);
    heapChars[chars.len] = 0;
    return allocateString(heapChars);
}

pub fn printObject(value: Value.Value) void {
    switch (objType(value)) {
        .string => {
            const stringToPrint: []u8 = @ptrCast(asZString(Value.asObj(value)));
            std.debug.print("{s}", .{stringToPrint});
        },
    }
}

fn allocateString(chars: []u8) *ObjString {
    var slice = chars;
    var string = allocateObj(ObjString, .string);
    string.length = chars.len;
    string.chars = &slice;
    return string;
}

pub fn takeString(chars: []u8) *ObjString {
    return allocateString(chars);
}
