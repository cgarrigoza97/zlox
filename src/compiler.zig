const std = @import("std");
const config = @import("config");
const Scanner = @import("scanner.zig");
const Common = @import("common.zig");
const Value = @import("value.zig");
const debug = @import("debug.zig");

const Parser = struct { current: Scanner.Token, previous: Scanner.Token, hadError: bool, panicMode: bool };

const Precedence = enum(u8) {
    none,
    assignment, // =
    or_prec, // or
    and_prec, // and
    equality, // == !=
    comparison, // < > <= >=
    term, // + -
    factor, // * /
    unary, // ! -
    call, // . ()
    primary,
};

const ParseFn = *const fn () void;

const ParseRule = struct {
    prefix: ?ParseFn,
    infix: ?ParseFn,
    precedence: Precedence,
};

var parser = Parser{ .current = undefined, .previous = undefined, .hadError = false, .panicMode = false };
var compilingChunk: *Common.Chunk = undefined;

fn currentChunk() *Common.Chunk {
    return compilingChunk;
}

pub fn compile(source: []u8, chunk: *Common.Chunk) bool {
    Scanner.initScanner(source);
    compilingChunk = chunk;

    parser.hadError = false;
    parser.panicMode = false;

    advance();
    expression();

    consume(Scanner.TokenType.eof, "Expect end of expression.");
    endCompiler();
    return !parser.hadError;
}

fn advance() void {
    parser.previous = parser.current;

    while (true) {
        parser.current = Scanner.scanToken();

        if (parser.current.tokenType != Scanner.TokenType.error_kw) break;

        const slice: []const u8 = @ptrCast(parser.current.start);
        errorAtCurrent(slice[0..parser.current.length]);
    }
}

fn consume(tokenType: Scanner.TokenType, message: []const u8) void {
    if (parser.current.tokenType == tokenType) {
        advance();
        return;
    }

    errorAtCurrent(message);
}

fn emitByte(byte: u8) void {
    currentChunk().write(byte, parser.previous.line);
}

fn emitBytes(byte1: u8, byte2: u8) void {
    emitByte(byte1);
    emitByte(byte2);
}

fn emitReturn() void {
    emitByte(@intFromEnum(Common.OpCode.op_return));
}

fn makeConstant(value: Value.Value) u8 {
    const constant = currentChunk().addConstant(value);
    if (constant > std.math.maxInt(u8)) {
        errorFn("Too many constants in one chunk.");
        return 0;
    }

    return @intCast(constant);
}

fn emitConstant(value: Value.Value) void {
    emitBytes(@intFromEnum(Common.OpCode.op_constant), makeConstant(value));
}

fn endCompiler() void {
    emitReturn();

    if (config.debug_print_code) {
        if (!parser.hadError) {
            debug.disassembleChunk(currentChunk(), "code");
        }
    }
}

fn binary() void {
    const operatorType = parser.previous.tokenType;
    const rule = getRule(operatorType);
    const nextPrecedence = @intFromEnum(rule.precedence) + 1;
    parsePrecedence(@enumFromInt(nextPrecedence));

    switch (operatorType) {
        .bang_equal => emitBytes(@intFromEnum(Common.OpCode.op_equal), @intFromEnum(Common.OpCode.op_not)),
        .equal_equal => emitByte(@intFromEnum(Common.OpCode.op_equal)),
        .greater => emitByte(@intFromEnum(Common.OpCode.op_greater)),
        .greater_equal => emitBytes(@intFromEnum(Common.OpCode.op_less), @intFromEnum(Common.OpCode.op_not)),
        .less => emitByte(@intFromEnum(Common.OpCode.op_less)),
        .less_equal => emitBytes(@intFromEnum(Common.OpCode.op_greater), @intFromEnum(Common.OpCode.op_not)),
        .plus => emitByte(@intFromEnum(Common.OpCode.op_add)),
        .minus => emitByte(@intFromEnum(Common.OpCode.op_subtract)),
        .star => emitByte(@intFromEnum(Common.OpCode.op_multiply)),
        .slash => emitByte(@intFromEnum(Common.OpCode.op_divide)),
        else => return,
    }
}

fn literal() void {
    switch (parser.previous.tokenType) {
        .false => emitByte(@intFromEnum(Common.OpCode.op_false)),
        .nil => emitByte(@intFromEnum(Common.OpCode.op_nil)),
        .true_kw => emitByte(@intFromEnum(Common.OpCode.op_true)),
        else => return,
    }
}

fn grouping() void {
    expression();
    consume(.right_paren, "Expect ')' after expression");
}

fn number() void {
    const slice: []const u8 = @ptrCast(parser.previous.start);
    const value = std.fmt.parseFloat(f64, slice[0..parser.previous.length]) catch {
        std.debug.print("Could not parse", .{});
        std.process.exit(74);
    };
    emitConstant(Value.numberVal(value));
}

fn unary() void {
    const operatorType = parser.previous.tokenType;

    parsePrecedence(.unary);

    switch (operatorType) {
        .bang => emitByte(@intFromEnum(Common.OpCode.op_not)),
        .minus => emitByte(@intFromEnum(Common.OpCode.op_negate)),
        else => return,
    }
}

fn getRule(token: Scanner.TokenType) ParseRule {
    return switch (token) {
        .left_paren => .{ .prefix = grouping, .infix = null, .precedence = .none },
        .right_paren => .{ .prefix = null, .infix = null, .precedence = .none },
        .left_brace => .{ .prefix = null, .infix = null, .precedence = .none },
        .right_brace => .{ .prefix = null, .infix = null, .precedence = .none },
        .comma => .{ .prefix = null, .infix = null, .precedence = .none },
        .dot => .{ .prefix = null, .infix = null, .precedence = .none },
        .minus => .{ .prefix = unary, .infix = binary, .precedence = .term },
        .plus => .{ .prefix = null, .infix = binary, .precedence = .term },
        .semicolon => .{ .prefix = null, .infix = null, .precedence = .none },
        .slash => .{ .prefix = null, .infix = binary, .precedence = .factor },
        .star => .{ .prefix = null, .infix = binary, .precedence = .factor },
        .bang => .{ .prefix = unary, .infix = null, .precedence = .none },
        .bang_equal => .{ .prefix = null, .infix = binary, .precedence = .none },
        .equal => .{ .prefix = null, .infix = null, .precedence = .none },
        .equal_equal => .{ .prefix = null, .infix = binary, .precedence = .equality },
        .greater => .{ .prefix = null, .infix = binary, .precedence = .none },
        .greater_equal => .{ .prefix = null, .infix = binary, .precedence = .none },
        .less => .{ .prefix = null, .infix = binary, .precedence = .none },
        .less_equal => .{ .prefix = null, .infix = binary, .precedence = .none },
        .identifier => .{ .prefix = null, .infix = null, .precedence = .none },
        .string => .{ .prefix = null, .infix = null, .precedence = .none },
        .number => .{ .prefix = number, .infix = null, .precedence = .none },
        .class => .{ .prefix = null, .infix = null, .precedence = .none },
        .else_kw => .{ .prefix = null, .infix = null, .precedence = .none },
        .false => .{ .prefix = literal, .infix = null, .precedence = .none },
        .for_kw => .{ .prefix = null, .infix = null, .precedence = .none },
        .fun => .{ .prefix = null, .infix = null, .precedence = .none },
        .if_kw => .{ .prefix = null, .infix = null, .precedence = .none },
        .nil => .{ .prefix = literal, .infix = null, .precedence = .none },
        .print => .{ .prefix = null, .infix = null, .precedence = .none },
        .return_kw => .{ .prefix = null, .infix = null, .precedence = .none },
        .super_kw => .{ .prefix = null, .infix = null, .precedence = .none },
        .this_kw => .{ .prefix = null, .infix = null, .precedence = .none },
        .true_kw => .{ .prefix = literal, .infix = null, .precedence = .none },
        .var_kw => .{ .prefix = null, .infix = null, .precedence = .none },
        .while_kw => .{ .prefix = null, .infix = null, .precedence = .none },
        .error_kw => .{ .prefix = null, .infix = null, .precedence = .none },
        .eof => .{ .prefix = null, .infix = null, .precedence = .none },
        else => @panic("Unknown token type"),
    };
}

fn parsePrecedence(precedence: Precedence) void {
    advance();
    const prefixRule = getRule(parser.previous.tokenType).prefix;

    if (prefixRule) |rule| {
        rule();
    } else {
        errorFn("Expect expression.");
        return;
    }

    while (@intFromEnum(precedence) <= @intFromEnum(getRule(parser.current.tokenType).precedence)) {
        advance();
        const infixRule = getRule(parser.previous.tokenType).infix;
        if (infixRule) |rule| {
            rule();
        }
    }
}

fn expression() void {
    parsePrecedence(.assignment);
}

fn errorAtCurrent(message: []const u8) void {
    errorAt(&parser.current, message);
}

fn errorFn(message: []const u8) void {
    errorAt(&parser.previous, message);
}

fn errorAt(token: *Scanner.Token, message: []const u8) void {
    if (parser.panicMode) return;
    parser.panicMode = true;
    std.debug.print("[line {}] Error", .{token.line});

    if (token.tokenType == .eof) {
        std.debug.print(" at end", .{});
    } else if (token.tokenType == .error_kw) {
        // nothing
    } else {
        const slice: []const u8 = @ptrCast(token.start);
        std.debug.print(" at '{s}'", .{slice[0..token.length]});
    }

    std.debug.print(": {s}\n", .{message});
    parser.hadError = true;
}
