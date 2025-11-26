const std = @import("std");
const zlox = @import("zlox");

const Common = @import("common.zig");
const Debug = @import("debug.zig");

pub fn main() !void {
    var chunk = Common.Chunk.init();

    const constant = chunk.addConstant(1.2);
    chunk.write(@intFromEnum(Common.OpCode.op_constant), 123);
    chunk.write(@intCast(constant), 123);

    chunk.write(@intFromEnum(Common.OpCode.op_return), 123);

    Debug.disassembleChunk(&chunk, "test chunk");
    chunk.free();
}
