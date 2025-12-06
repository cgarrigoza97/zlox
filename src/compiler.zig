const std = @import("std");
const Scanner = @import("scanner.zig");

pub fn compile(source: []u8) void {
    Scanner.initScanner(source);

    var line: i32 = -1;
    while (true) {
        const token = Scanner.scanToken();
        if (token.line != line) {
            std.debug.print("{d:4} ", .{token.line});
            line = @intCast(token.line);
        } else {
            std.debug.print("{d:2} '{s}'\n", .{
                token.tokenType,
                source[token.start .. token.start + token.length],
            });

            if (token.tokenType == Scanner.TokenType.eof) {
                break;
            }
        }
    }
}
