const std = @import("std");

const VM = @import("vm.zig");
const Object = @import("object.zig");

pub fn growCapacity(capacity: usize) usize {
    return if (capacity < 8) 8 else capacity * 2;
}

pub fn growArray(comptime T: type, pointer: ?[*]T, oldCount: usize, newCount: usize) ?[*]T {
    const ptr_opaque: ?*anyopaque = if (pointer) |p| @ptrCast(p) else null;

    const raw = reallocate(ptr_opaque, @sizeOf(T) * oldCount, @sizeOf(T) * newCount);

    return @ptrCast(@alignCast(raw));
}

pub fn freeArray(comptime T: type, pointer: ?[*]T, oldCount: usize) void {
    const ptr_opaque: ?*anyopaque = if (pointer) |p| @ptrCast(p) else null;
    _ = reallocate(ptr_opaque, @sizeOf(T) * oldCount, 0);
}

pub fn freeString(chars: *[]u8, size: usize) void {
    const ptr_opaque: ?*anyopaque = @ptrCast(chars);
    _ = reallocate(ptr_opaque, @sizeOf(u8) * size, 0);
}

pub fn reallocate(pointer: ?*anyopaque, oldSize: usize, newSize: usize) ?*anyopaque {
    const allocator = std.heap.c_allocator;

    if (newSize == 0) {
        if (pointer) |ptr| {
            const bytes = @as([*]u8, @ptrCast(ptr))[0..oldSize];
            allocator.free(bytes);
        }
        return null;
    }

    if (pointer) |ptr| {
        const old_bytes = @as([*]u8, @ptrCast(ptr))[0..oldSize];
        const new_bytes = allocator.realloc(old_bytes, newSize) catch return null;
        return new_bytes.ptr;
    } else {
        const new_bytes = allocator.alloc(u8, newSize) catch return null;
        return new_bytes.ptr;
    }
}

fn freeObject(object: *Object.Obj) void {
    switch (object.objType) {
        .string => {
            const string: *Object.ObjString = @ptrCast(object);
            freeString(string.chars, string.length + 1);
            free(Object.ObjString, object);
        },
    }
}

pub fn freeObjects() void {
    var object = VM.vm.objects;
    while (object != null) {
        if (object) |obj| {
            const next = obj.next;

            freeObject(obj);
            object = next;
        }
    }
}

pub inline fn free(comptime T: type, pointer: ?*anyopaque) void {
    _ = reallocate(pointer, @sizeOf(T), 0);
}

pub fn allocate(comptime T: type, count: usize) ?*anyopaque {
    return reallocate(null, 0, @sizeOf(T) * count);
}
