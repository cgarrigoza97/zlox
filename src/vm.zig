const std = @import("std");
const config = @import("config");

const Common = @import("common.zig");
const Memory = @import("memory.zig");
const Value = @import("value.zig");
const Compiler = @import("compiler.zig");
const Object = @import("object.zig");
const Debug = @import("debug.zig");

const stack_max = 256;

pub const InterpretResult = enum(u8) { interpret_ok, interpret_compile_error, interpret_runtime_error };

pub const VM = struct { chunk: *Common.Chunk, ip: ?[*]u8, stack: [stack_max]Value.Value, stackTop: usize, objects: ?*Object.Obj };

pub var vm: VM = undefined;

fn resetStack() void {
    vm.stackTop = 0;
}

fn runtimeError(comptime format: []const u8, args: anytype) void {
    std.debug.print(format, args);
    std.debug.print("\n", .{});

    const ip = vm.ip orelse unreachable;
    const code = vm.chunk.code orelse unreachable;
    const instruction: usize = @intCast(ip - code - 1);
    const lines = vm.chunk.lines orelse unreachable;
    const line = lines[instruction];

    std.debug.print("[line {}] in script\n", .{line});

    resetStack();
}

pub fn init() void {
    resetStack();
    vm.objects = null;
}

pub fn free() void {
    Memory.freeObjects();
}

pub fn push(value: Value.Value) void {
    vm.stack[vm.stackTop] = value;
    vm.stackTop += 1;
}

pub fn pop() Value.Value {
    vm.stackTop -= 1;
    return vm.stack[vm.stackTop];
}

fn peek(distance: usize) Value.Value {
    return vm.stack[vm.stackTop - 1 - distance];
}

fn isFalsey(value: Value.Value) bool {
    return Value.isNil(value) or (Value.isBoolean(value) and !Value.asBoolean(value));
}

fn concatenate() void {
    const b = Object.asString(Value.asObj(pop()));
    const a = Object.asString(Value.asObj(pop()));

    const length = a.length + b.length;

    const chars: []u8 = @ptrCast(Memory.allocate(u8, length + 1));
    const aSlice: []u8 = @ptrCast(a.chars);
    const bSlice: []u8 = @ptrCast(b.chars);
    @memcpy(chars[0..a.length], aSlice);
    @memcpy(chars[a.length..], bSlice);

    chars[length] = 0;

    const result = Object.takeString(chars);
    push(Value.objVal(&result.obj));
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

inline fn binaryOp(comptime valueType: anytype, comptime op: anytype) ?InterpretResult {
    if (!Value.isNumber(peek(0)) or !Value.isNumber(peek(1))) {
        runtimeError("Operands must be numbers", .{});
        return .interpret_runtime_error;
    }
    const b = Value.asNumber(pop());
    const a = Value.asNumber(pop());
    push(valueType(op(a, b)));

    return null;
}

inline fn add(a: f64, b: f64) f64 {
    return a + b;
}

inline fn sub(a: f64, b: f64) f64 {
    return a - b;
}

inline fn mult(a: f64, b: f64) f64 {
    return a * b;
}

inline fn div(a: f64, b: f64) f64 {
    return a / b;
}

inline fn greater(a: f64, b: f64) bool {
    return a > b;
}

inline fn less(a: f64, b: f64) bool {
    return a < b;
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
            @intFromEnum(Common.OpCode.op_nil) => {
                push(Value.nilVal());
                break;
            },
            @intFromEnum(Common.OpCode.op_true) => {
                push(Value.booleanVal(true));
                break;
            },
            @intFromEnum(Common.OpCode.op_false) => {
                push(Value.booleanVal(false));
                break;
            },
            @intFromEnum(Common.OpCode.op_equal) => {
                const b = pop();
                const a = pop();
                push(Value.booleanVal(Value.valuesEqual(a, b)));
                break;
            },
            @intFromEnum(Common.OpCode.op_greater) => {
                _ = binaryOp(Value.booleanVal, greater);
            },
            @intFromEnum(Common.OpCode.op_less) => {
                _ = binaryOp(Value.booleanVal, less);
            },
            @intFromEnum(Common.OpCode.op_add) => {
                if (Object.isString(peek(0)) and Object.isString(peek(1))) {
                    concatenate();
                } else if (Value.isNumber(peek(0)) and Value.isNumber(peek(1))) {
                    const b = Value.asNumber(pop());
                    const a = Value.asNumber(pop());
                    push(Value.numberVal(a + b));
                } else {
                    runtimeError("Operands must be two numbers or two strings.", .{});
                }
                break;
            },
            @intFromEnum(Common.OpCode.op_subtract) => {
                _ = binaryOp(Value.numberVal, sub);
                break;
            },
            @intFromEnum(Common.OpCode.op_multiply) => {
                _ = binaryOp(Value.numberVal, mult);
                break;
            },
            @intFromEnum(Common.OpCode.op_divide) => {
                _ = binaryOp(Value.numberVal, div);
                break;
            },
            @intFromEnum(Common.OpCode.op_not) => {
                push(Value.booleanVal(isFalsey(pop())));
                break;
            },
            @intFromEnum(Common.OpCode.op_negate) => {
                if (Value.isNumber(peek(0))) {
                    runtimeError("Operand must be a number.", .{});
                    return .interpret_runtime_error;
                }

                push(Value.numberVal(-Value.asNumber(pop())));
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

pub fn interpret(source: []u8) InterpretResult {
    var chunk = Common.Chunk.init();

    if (!Compiler.compile(source, &chunk)) {
        chunk.free();

        return .interpret_compile_error;
    }

    vm.chunk = &chunk;
    vm.ip = vm.chunk.code;

    const result = run();

    chunk.free();
    return result;
}
