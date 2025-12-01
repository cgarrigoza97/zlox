const std = @import("std");

const Common = @import("common.zig");
const Value = @import("value.zig");

pub fn disassembleChunk(chunk: *Common.Chunk, name: []const u8) void {
    std.debug.print("== {s} ==\n", .{name});

    var offset: usize = 0;
    while (offset < chunk.count) {
        offset = disassembleInstruction(chunk, offset);
    }
}

pub fn disassembleInstruction(chunk: *Common.Chunk, offset: usize) usize {
    std.debug.print("{:0>4} ", .{offset});
    if (offset > 0 and chunk.lines.?[offset] == chunk.lines.?[offset - 1]) {
        std.debug.print("   | ", .{});
    } else {
        std.debug.print("{:>4} ", .{chunk.lines.?[offset]});
    }

    const instruction = chunk.code.?[offset];
    switch (instruction) {
        @intFromEnum(Common.OpCode.op_constant) => {
            return constantInstruction("OP_CONSTANT", chunk, offset);
        },
        @intFromEnum(Common.OpCode.op_add) => {
            return simpleInstruction("OP_ADD", offset);
        },
        @intFromEnum(Common.OpCode.op_subtract) => {
            return simpleInstruction("OP_SUBTRACT", offset);
        },
        @intFromEnum(Common.OpCode.op_multiply) => {
            return simpleInstruction("OP_MULTIPLY", offset);
        },
        @intFromEnum(Common.OpCode.op_divide) => {
            return simpleInstruction("OP_DIVIDE", offset);
        },
        @intFromEnum(Common.OpCode.op_negate) => {
            return simpleInstruction("OP_NEGATE", offset);
        },
        @intFromEnum(Common.OpCode.op_return) => {
            return simpleInstruction("OP_RETURN", offset);
        },
        else => {
            std.debug.print("Unknown opcode {}\n", .{instruction});
            return offset + 1;
        },
    }
}

fn constantInstruction(name: []const u8, chunk: *Common.Chunk, offset: usize) usize {
    const constant = chunk.code.?[offset + 1];
    std.debug.print("{s:<16} {d:>4} '", .{ name, constant });
    Value.printValue(chunk.constants.values.?[constant]);
    std.debug.print("'\n", .{});
    return offset + 2;
}

fn simpleInstruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s}\n", .{name});
    return offset + 1;
}
