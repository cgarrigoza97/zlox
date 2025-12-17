const std = @import("std");
const zlox = @import("zlox");

const Common = @import("common.zig");
const Debug = @import("debug.zig");
const VM = @import("vm.zig");

pub fn main() !void {
    VM.init();
    const allocator = std.heap.c_allocator;
    var argv = try std.process.argsWithAllocator(allocator);
    defer argv.deinit();

    _ = argv.skip();

    if (argv.next()) |s| {
        const path = std.mem.sliceTo(s, 0);
        try runFile(allocator, path);
    } else {
        try repl();
    }

    VM.free();
}

fn repl() !void {
    while (true) {
        var stdin_buffer: [1024]u8 = undefined;
        var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
        const stdin = &stdin_reader.interface;
        std.debug.print("> ", .{});

        var line: [1024]u8 = undefined;
        var w: std.Io.Writer = .fixed(&line);

        const lineLength = try stdin.streamDelimiter(&w, '\n');

        // Add the null terminator.
        line[lineLength - 1] = 0;
        const lineRead = line[0..lineLength];

        _ = VM.interpret(lineRead);
    }
}

fn runFile(allocator: std.mem.Allocator, path: [:0]const u8) !void {
    const source = try readFile(allocator, path);
    const result = VM.interpret(source);

    if (result == VM.InterpretResult.interpret_compile_error) {
        std.process.exit(65);
    }

    if (result == VM.InterpretResult.interpret_runtime_error) {
        std.process.exit(70);
    }
}

fn readFile(allocator: std.mem.Allocator, path: [:0]const u8) ![]u8 {
    var file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch {
        std.debug.print("Could not open file {s}.\n", .{path});
        std.process.exit(74);
    };
    defer file.close();

    const fileStat = try file.stat();

    var read_buf: [2]u8 = undefined;
    var file_reader: std.fs.File.Reader = file.reader(&read_buf);

    const buffer: []u8 = allocator.alloc(u8, fileStat.size) catch {
        std.debug.print("Not enough memory to read {s}.\n", .{path});
        std.process.exit(74);
    };
    const reader = &file_reader.interface;
    reader.readSliceAll(buffer) catch {
        std.debug.print("Could not read file {s}.\n", .{path});
        std.process.exit(74);
    };

    return buffer;
}
