const std = @import("std");
const zlox = @import("zlox");

const Common = @import("common.zig");
const Debug = @import("debug.zig");
const VM = @import("vm.zig");

pub fn main() !void {
    VM.init();
    const args = std.os.argv;

    if (args.len == 1) {
        try repl();
    } else if (args.len == 2) {
        // runFile(args[1]);
    } else {
        @panic("Usage: zlox [path]");
    }

    VM.free();
}

fn repl() !void {
    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    var line: [1024]u8 = undefined;
    var w: std.io.Writer = .fixed(&line);

    while (true) {
        std.debug.print("> ", .{});

        const lineLength = try stdin.streamDelimiter(&w, '\n');

        const lineRead = line[0..lineLength];

        std.debug.print("{s}", .{lineRead});
        // VM.interpret(lineRead);
    }
}

// fn runFile(path: [*:0]u8) void {
//     const source = readFile(path);
//     std.debug.print("{s}", .{source});
//     // const result = VM.interpret(source);
//     // std.debug.print("{s}", .{result});
// }

// fn readFile(path: [*:0]u8) !*const []u8 {
//     var alloc = std.heap.c_allocator;
//     defer _ = alloc.deinit();

//     var file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
//     defer file.close();

//     var read_buf: [2]u8 = undefined;
//     var file_reader: std.fs.File.Reader = file.reader(&read_buf);

//     const reader = &file_reader.interface;

//     var line = std.Io.Writer.Allocating.init(alloc);
//     defer line.deinit();

//     while (true) {
//         _ = try reader.streamDelimiter(&line.writer, '\n');
//         line.written();
//     }

//     return line;
// }
