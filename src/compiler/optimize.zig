//! Semantics-preserving Render IR optimization passes.

const std = @import("std");
const zeft = @import("zeft_core");
const ir = @import("zeft_ir");

/// Merge adjacent static output instructions. This pass is valid even when it
/// finds nothing to change, so callers always run it in the compile pipeline.
pub fn optimize(allocator: std.mem.Allocator, program: ir.Program) std.mem.Allocator.Error!ir.Program {
    var strings: std.ArrayList([]const u8) = .empty;
    var instructions: std.ArrayList(ir.Instruction) = .empty;
    const old_to_new = try allocator.alloc(u32, program.instructions.len + 1);
    defer allocator.free(old_to_new);
    const targeted = try allocator.alloc(bool, program.instructions.len + 1);
    defer allocator.free(targeted);
    @memset(targeted, false);
    for (program.instructions) |instruction| switch (instruction.data) {
        .jump_if_false => |branch| markTarget(targeted, branch.target),
        .jump => |target| markTarget(targeted, target),
        .loop_begin => |begin| markTarget(targeted, begin.exit_target),
        .loop_next => |next| {
            markTarget(targeted, next.body_target);
            markTarget(targeted, next.exit_target);
        },
        .loop_break => |target| markTarget(targeted, target),
        .loop_continue => |target| markTarget(targeted, target),
        else => {},
    };
    var previous_string_owned = false;

    for (program.instructions, 0..) |instruction, old_index| {
        switch (instruction.data) {
            .write_static => |old_id| {
                const bytes = program.strings[old_id];
                if (!targeted[old_index] and instructions.items.len > 0 and instructions.items[instructions.items.len - 1].data == .write_static) {
                    const previous = &instructions.items[instructions.items.len - 1];
                    old_to_new[old_index] = @intCast(instructions.items.len - 1);
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
                    old_to_new[old_index] = @intCast(instructions.items.len);
                    const new_id = std.math.cast(ir.StringId, strings.items.len) orelse unreachable;
                    try strings.append(allocator, bytes);
                    var rewritten = instruction;
                    rewritten.data = .{ .write_static = new_id };
                    try instructions.append(allocator, rewritten);
                    previous_string_owned = false;
                }
            },
            else => {
                old_to_new[old_index] = @intCast(instructions.items.len);
                try instructions.append(allocator, instruction);
                previous_string_owned = false;
            },
        }
    }
    old_to_new[program.instructions.len] = @intCast(instructions.items.len);

    for (instructions.items) |*instruction| switch (instruction.data) {
        .jump_if_false => |*branch| branch.target = remapTarget(old_to_new, branch.target),
        .jump => |*target| target.* = remapTarget(old_to_new, target.*),
        .loop_begin => |*begin| begin.exit_target = remapTarget(old_to_new, begin.exit_target),
        .loop_next => |*next| {
            next.body_target = remapTarget(old_to_new, next.body_target);
            next.exit_target = remapTarget(old_to_new, next.exit_target);
        },
        .loop_break => |*target| target.* = remapTarget(old_to_new, target.*),
        .loop_continue => |*target| target.* = remapTarget(old_to_new, target.*),
        else => {},
    };

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

fn remapTarget(mapping: []const u32, target: u32) u32 {
    std.debug.assert(target < mapping.len);
    return mapping[target];
}

fn markTarget(targeted: []bool, target: u32) void {
    std.debug.assert(target < targeted.len);
    targeted[target] = true;
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

test "optimizer preserves branch destinations when writes merge nearby" {
    const strings = [_][]const u8{ "then", "else", ":" };
    const instructions = [_]ir.Instruction{
        .{ .span = .{ .start = 0, .end = 1 }, .data = .{ .jump_if_false = .{ .expression_id = 0, .target = 3 } } },
        .{ .span = .{ .start = 1, .end = 2 }, .data = .{ .write_static = 0 } },
        .{ .span = .{ .start = 2, .end = 3 }, .data = .{ .jump = 5 } },
        .{ .span = .{ .start = 3, .end = 4 }, .data = .{ .write_static = 1 } },
        .{ .span = .{ .start = 4, .end = 5 }, .data = .{ .write_static = 2 } },
        .{ .span = .{ .start = 5, .end = 5 }, .data = .end },
    };
    const program: ir.Program = .{ .strings = @constCast(&strings), .symbols = &.{}, .expressions = &.{}, .instructions = @constCast(&instructions) };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const optimized = try optimize(arena.allocator(), program);
    try std.testing.expectEqual(@as(u32, 3), optimized.instructions[0].data.jump_if_false.target);
    try std.testing.expectEqual(@as(u32, 4), optimized.instructions[2].data.jump);
    try std.testing.expectEqualStrings("else:", optimized.strings[1]);
}
