const std = @import("std");
const zeft = @import("zeft");

test "integration suite is wired to the public module" {
    _ = std.testing.refAllDecls(zeft);
}

test "compile returns a categorized diagnostic with a source span" {
    const source = "<p>Hello</p>";
    var result = zeft.compile(std.testing.allocator, source, .{});
    switch (result) {
        .success => |*template| template.deinit(),
        .failure => |diagnostic| {
            try std.testing.expectEqual(zeft.CompileErrorKind.unsupported_syntax, diagnostic.kind);
            try std.testing.expectEqual(@as(?zeft.SourceSpan, .{ .start = 0, .end = source.len }), diagnostic.span);
        },
    }
}
