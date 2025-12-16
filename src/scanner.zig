const std = @import("std");

pub const TokenType = enum(u8) {
    // Single-character tokens.
    left_paren,
    right_paren,
    left_brace,
    right_brace,
    comma,
    dot,
    minus,
    plus,
    semicolon,
    slash,
    star,
    // One or two character tokens.
    bang,
    bang_equal,
    equal,
    equal_equal,
    greater,
    greater_equal,
    less,
    less_equal,
    // Literals.
    identifier,
    string,
    number,
    // Keywords.
    and_kw,
    class,
    else_kw,
    false,
    for_kw,
    fun,
    if_kw,
    nil,
    or_kw,
    print,
    return_kw,
    super_kw,
    this_kw,
    true_kw,
    var_kw,
    while_kw,

    error_kw,
    eof,
};

pub const Token = struct {
    tokenType: TokenType,
    start: *u8,
    length: usize,
    line: usize,
    message: ?[*:0]const u8,
};

pub const Scanner = struct {
    source: []u8,
    start: usize,
    current: usize,
    line: usize,
};

pub var scanner = Scanner{
    .source = undefined,
    .start = 0,
    .current = 0,
    .line = 0,
};

pub fn initScanner(source: []u8) void {
    scanner.source = source;
    scanner.line = 1;
}

pub fn scanToken() Token {
    skipWhitespace();
    scanner.start = scanner.current;

    if (isAtEnd()) {
        return makeToken(TokenType.eof);
    }

    const c = advance();
    if (isAlpha(c)) return identifier();

    if (isDigit(c)) return number();

    switch (c) {
        '(' => return makeToken(.left_paren),
        ')' => return makeToken(.right_paren),
        '{' => return makeToken(.left_brace),
        '}' => return makeToken(.right_brace),
        ';' => return makeToken(.semicolon),
        ',' => return makeToken(.comma),
        '.' => return makeToken(.dot),
        '-' => return makeToken(.minus),
        '+' => return makeToken(.plus),
        '/' => return makeToken(.slash),
        '*' => return makeToken(.star),
        '!' => return makeToken(if (match('=')) .bang_equal else .bang),
        '=' => return makeToken(if (match('=')) .equal_equal else .equal),
        '<' => return makeToken(if (match('=')) .less_equal else .less),
        '>' => return makeToken(if (match('=')) .greater_equal else .greater),
        '"' => return string(),
        else => {},
    }

    return errorToken("Unexpected character.");
}

fn isAtEnd() bool {
    return scanner.source.len - 1 == scanner.current;
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn identifierType() TokenType {
    switch (scanner.source[scanner.start]) {
        'a' => return checkKeyword(1, 2, "nd", .and_kw),
        'c' => return checkKeyword(1, 4, "lass", .class),
        'e' => return checkKeyword(1, 3, "lse", .else_kw),
        'f' => {
            if (scanner.current - scanner.start > 1) {
                switch (scanner.source[scanner.start + 1]) {
                    'a' => return checkKeyword(2, 3, "lse", .false),
                    'o' => return checkKeyword(2, 1, "r", .for_kw),
                    'u' => return checkKeyword(2, 1, "n", .fun),
                    else => return .identifier,
                }
            }
        },
        'i' => return checkKeyword(1, 1, "f", .if_kw),
        'n' => return checkKeyword(1, 2, "il", .nil),
        'o' => return checkKeyword(1, 1, "r", .or_kw),
        'p' => return checkKeyword(1, 4, "rint", .print),
        'r' => return checkKeyword(1, 5, "eturn", .return_kw),
        's' => return checkKeyword(1, 4, "uper", .super_kw),
        't' => {
            if (scanner.current - scanner.start > 1) {
                switch (scanner.source[scanner.start + 1]) {
                    'h' => return checkKeyword(2, 2, "is", .this_kw),
                    'r' => return checkKeyword(2, 2, "ue", .true_kw),
                    else => return .identifier,
                }
            }
        },
        'v' => return checkKeyword(1, 2, "ar", .var_kw),
        'w' => return checkKeyword(1, 4, "hile", .while_kw),
        else => return .identifier,
    }

    return .identifier;
}

fn makeToken(tokenType: TokenType) Token {
    std.debug.print("Making token \n", .{});
    std.debug.print("{c}\n", .{scanner.source[scanner.current]});
    return Token{ .tokenType = tokenType, .length = scanner.current - scanner.start, .line = scanner.line, .start = &scanner.source[scanner.start], .message = null };
}

fn errorToken(message: [*:0]const u8) Token {
    return Token{
        .length = std.mem.len(message),
        .line = scanner.line,
        .start = &scanner.source[scanner.start],
        .tokenType = TokenType.error_kw,
        .message = message,
    };
}

fn identifier() Token {
    while (isAlpha(peek()) or isDigit(peek())) {
        _ = advance();
    }

    return makeToken(identifierType());
}

fn string() Token {
    while (!isAtEnd() and peek() != '"') {
        if (peek() == '\n') {
            scanner.line += 1;
        }

        _ = advance();
    }

    if (isAtEnd()) {
        return errorToken("Unterminated string.");
    }

    _ = advance();

    return makeToken(.string);
}

fn number() Token {
    while (isDigit(peek())) {
        _ = advance();
    }

    if (peek() == '.' and isDigit(peekNext())) {
        _ = advance();
        while (isDigit(peek())) {
            _ = advance();
        }
    }

    return makeToken(.number);
}

fn checkKeyword(start: usize, length: usize, rest: []const u8, tokenType: TokenType) TokenType {
    if (scanner.current - scanner.start == start + length and std.mem.eql(u8, scanner.source[start .. length + start], rest)) {
        return tokenType;
    }

    return .identifier;
}

fn advance() u8 {
    scanner.current += 1;
    return scanner.source[scanner.current - 1];
}

fn match(expected: u8) bool {
    if (isAtEnd()) {
        return false;
    }

    if (scanner.source[scanner.current + 1] != expected) {
        return false;
    }

    scanner.current += 1;
    return true;
}

fn peek() u8 {
    return scanner.source[scanner.current];
}

fn peekNext() u8 {
    if (isAtEnd()) return 0;
    return scanner.source[scanner.current + 1];
}

fn skipWhitespace() void {
    while (true) {
        const c = peek();
        switch (c) {
            ' ', '\r', '\t' => {
                _ = advance();
                break;
            },
            '\n' => {
                scanner.line += 1;
                _ = advance();
                break;
            },
            '/' => {
                if (peekNext() == '/') {
                    while (!isAtEnd() and peek() != '\n') {
                        _ = advance();
                    }
                } else {
                    return;
                }
                break;
            },
            else => return,
        }
    }
}
