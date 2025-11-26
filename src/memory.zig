const std = @import("std");

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

fn reallocate(pointer: ?*anyopaque, oldSize: usize, newSize: usize) ?*anyopaque {
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
