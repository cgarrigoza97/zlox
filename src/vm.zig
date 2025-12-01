const std = @import("std");
const config = @import("config");

const Common = @import("common.zig");
const Value = @import("value.zig");
const Debug = @import("debug.zig");

const stack_max = 256;

pub const InterpretResult = enum(u8) { interpret_ok, interpret_compile_error, interpret_runtime_error };

pub const VM = struct { chunk: *Common.Chunk, ip: ?[*]u8, stack: [stack_max]Value.Value, stackTop: [*]Value.Value };

var vm: VM = undefined;

fn resetStack() void {
    vm.stackTop = &vm.stack;
}

pub fn init() void {
    resetStack();
}

pub fn free() void {}

pub fn push(value: Value.Value) void {
    vm.stackTop[0] = value;
    vm.stackTop += 1;
}

pub fn pop() Value.Value {
    vm.stackTop -= 1;
    return vm.stackTop[0];
}

inline fn readByte() u8 {
    if (vm.ip) |ptr| {
        const byte = ptr[0];
        vm.ip = ptr + 1;
        return byte;
    }
    @panic("null IP");
}

inline fn readConstant() Value.Value {
    return vm.chunk.constants.values.?[readByte()];
}

inline fn binaryOp(comptime op: anytype) void {
    const b = pop();
    const a = pop();
    push(op(a, b));
}

inline fn add(a: Value.Value, b: Value.Value) Value.Value {
    return a + b;
}

inline fn sub(a: Value.Value, b: Value.Value) Value.Value {
    return a - b;
}

inline fn mult(a: Value.Value, b: Value.Value) Value.Value {
    return a * b;
}

inline fn div(a: Value.Value, b: Value.Value) Value.Value {
    return a / b;
}

fn run() InterpretResult {
    while (true) {
        if (config.debug_trace_execution) {
            std.debug.print("          ", .{});
            var i: usize = 0;
            while (i < stack_max) : (i += 1) {
                std.debug.print("[ ", .{});
                Value.printValue(vm.stack[i]);
                std.debug.print(" ]", .{});
            }
            std.debug.print("\n", .{});

            _ = Debug.disassembleInstruction(vm.chunk, @intFromPtr(vm.ip) - @intFromPtr(vm.chunk.code));
        }

        const instruction: u8 = readByte();

        switch (instruction) {
            @intFromEnum(Common.OpCode.op_constant) => {
                const constant = readConstant();
                push(constant);
                break;
            },
            @intFromEnum(Common.OpCode.op_add) => {
                binaryOp(add);
                break;
            },
            @intFromEnum(Common.OpCode.op_subtract) => {
                binaryOp(sub);
                break;
            },
            @intFromEnum(Common.OpCode.op_multiply) => {
                binaryOp(mult);
                break;
            },
            @intFromEnum(Common.OpCode.op_divide) => {
                binaryOp(div);
                break;
            },
            @intFromEnum(Common.OpCode.op_negate) => {
                push(-pop());
                break;
            },
            @intFromEnum(Common.OpCode.op_return) => {
                Value.printValue(pop());
                std.debug.print("\n", .{});
                return InterpretResult.interpret_ok;
            },
            else => continue,
        }
    }

    return InterpretResult.interpret_ok;
}

pub fn interpret(chunk: *Common.Chunk) InterpretResult {
    vm.chunk = chunk;
    vm.ip = vm.chunk.code;

    return run();
}
