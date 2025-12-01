const std = @import("std");
const zlox = @import("zlox");

const Common = @import("common.zig");
const Debug = @import("debug.zig");
const VM = @import("vm.zig");

pub fn main() !void {
    VM.init();
    var chunk = Common.Chunk.init();

    var constant = chunk.addConstant(1.2);
    chunk.write(@intFromEnum(Common.OpCode.op_constant), 123);
    chunk.write(@intCast(constant), 123);

    constant = chunk.addConstant(3.4);
    chunk.write(@intFromEnum(Common.OpCode.op_constant), 123);
    chunk.write(@intCast(constant), 123);

    chunk.write(@intFromEnum(Common.OpCode.op_add), 123);

    constant = chunk.addConstant(5.6);
    chunk.write(@intFromEnum(Common.OpCode.op_constant), 123);
    chunk.write(@intCast(constant), 123);

    chunk.write(@intFromEnum(Common.OpCode.op_divide), 123);
    chunk.write(@intFromEnum(Common.OpCode.op_negate), 123);

    chunk.write(@intFromEnum(Common.OpCode.op_return), 123);

    Debug.disassembleChunk(&chunk, "test chunk");
    _ = VM.interpret(&chunk);
    VM.free();
    chunk.free();
}
