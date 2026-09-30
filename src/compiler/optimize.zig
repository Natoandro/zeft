//! Semantics-preserving Render IR optimization passes.

const std = @import("std");
const zeft = @import("zeft_core");
const ir = @import("zeft_ir");

/// Merge adjacent static output instructions. This pass is valid even when it
/// finds nothing to change, so callers always run it in the compile pipeline.
pub fn optimize(allocator: std.mem.Allocator, program: ir.Program) std.mem.Allocator.Error!ir.Program {
    var strings: std.ArrayList([]const u8) = .empty;
    var instructions: std.ArrayList(ir.Instruction) = .empty;
    var previous_string_owned = false;

    for (program.instructions) |instruction| {
        switch (instruction.data) {
            .write_static => |old_id| {
                const bytes = program.strings[old_id];
                if (instructions.items.len > 0 and instructions.items[instructions.items.len - 1].data == .write_static) {
                    const previous = &instructions.items[instructions.items.len - 1];
                    const previous_id = previous.data.write_static;
                    const previous_bytes = strings.items[previous_id];
                    const merged = try concatenate(allocator, previous_bytes, bytes);
                    if (previous_string_owned) allocator.free(@constCast(previous_bytes));
                    strings.items[previous_id] = merged;
                    previous_string_owned = true;
                    previous.span = .{
                        .start = @min(previous.span.start, instruction.span.start),
                        .end = @max(previous.span.end, instruction.span.end),
                    };
                } else {
                    const new_id = std.math.cast(ir.StringId, strings.items.len) orelse unreachable;
                    try strings.append(allocator, bytes);
                    var rewritten = instruction;
                    rewritten.data = .{ .write_static = new_id };
                    try instructions.append(allocator, rewritten);
                    previous_string_owned = false;
                }
            },
            .write_expression, .end => {
                try instructions.append(allocator, instruction);
                previous_string_owned = false;
            },
        }
    }

    // Check that all static-write references remain valid after rewriting.
    for (instructions.items) |instruction| switch (instruction.data) {
        .write_static => |id| std.debug.assert(id < strings.items.len),
        else => {},
    };

    return .{
        .strings = try strings.toOwnedSlice(allocator),
        .symbols = program.symbols,
        .expressions = program.expressions,
        .instructions = try instructions.toOwnedSlice(allocator),
    };
}

fn concatenate(
    allocator: std.mem.Allocator,
    first: []const u8,
    second: []const u8,
) std.mem.Allocator.Error![]const u8 {
    const combined = try allocator.alloc(u8, first.len + second.len);
    @memcpy(combined[0..first.len], first);
    @memcpy(combined[first.len..], second);
    return combined;
}

test "merges adjacent static writes and preserves surrounding instructions" {
    const strings = [_][]const u8{ "<p>", "hello", "!", "</p>" };
    const instructions = [_]ir.Instruction{
        .{ .span = .{ .start = 0, .end = 3 }, .data = .{ .write_static = 0 } },
        .{ .span = .{ .start = 3, .end = 8 }, .data = .{ .write_static = 1 } },
        .{ .span = .{ .start = 8, .end = 9 }, .data = .{ .write_static = 2 } },
        .{ .span = .{ .start = 9, .end = 10 }, .data = .{ .write_expression = .{ .expression_id = 0, .escape_context = .text } } },
        .{ .span = .{ .start = 10, .end = 14 }, .data = .{ .write_static = 3 } },
        .{ .span = .{ .start = 14, .end = 14 }, .data = .end },
    };
    const program: ir.Program = .{
        .strings = @constCast(&strings),
        .symbols = &.{},
        .expressions = &.{},
        .instructions = @constCast(&instructions),
    };
    const optimized = try optimize(std.testing.allocator, program);
    defer {
        std.testing.allocator.free(optimized.strings[0]);
        std.testing.allocator.free(optimized.strings);
        std.testing.allocator.free(optimized.instructions);
    }

    try std.testing.expectEqual(@as(usize, 4), optimized.instructions.len);
    try std.testing.expectEqual(@as(usize, 2), optimized.strings.len);
    try std.testing.expectEqualStrings("<p>hello!", optimized.strings[0]);
    try std.testing.expectEqualStrings("</p>", optimized.strings[1]);
    try std.testing.expectEqual(@as(zeft.SourceSpan, .{ .start = 0, .end = 9 }), optimized.instructions[0].span);
    try std.testing.expectEqual(ir.Instruction.Data.write_expression, std.meta.activeTag(optimized.instructions[1].data));
}

test "optimizer succeeds when no adjacent static writes exist" {
    const instructions = [_]ir.Instruction{
        .{ .span = .{ .start = 0, .end = 1 }, .data = .{ .write_static = 0 } },
        .{ .span = .{ .start = 1, .end = 2 }, .data = .{ .write_expression = .{ .expression_id = 0, .escape_context = .text } } },
        .{ .span = .{ .start = 2, .end = 2 }, .data = .end },
    };
    const program: ir.Program = .{
        .strings = @constCast(&[_][]const u8{"x"}),
        .symbols = &.{},
        .expressions = &.{},
        .instructions = @constCast(&instructions),
    };
    const optimized = try optimize(std.testing.allocator, program);
    defer std.testing.allocator.free(optimized.strings);
    defer std.testing.allocator.free(optimized.instructions);
    try std.testing.expectEqual(@as(usize, 1), optimized.strings.len);
    try std.testing.expectEqual(@as(usize, 3), optimized.instructions.len);
}
