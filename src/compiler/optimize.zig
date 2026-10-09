//! Semantics-preserving Render IR optimization passes.

const std = @import("std");
const zeft = @import("zeft_core");
const ir = @import("zeft_ir");

/// Merge adjacent static output instructions. This pass is valid even when it
/// finds nothing to change, so callers always run it in the compile pipeline.
pub fn optimize(
    allocator: std.mem.Allocator,
    program: ir.Program,
) std.mem.Allocator.Error!ir.Program {
    const folded_expressions = try foldExpressions(allocator, program.expressions);
    var strings: std.ArrayList([]const u8) = .empty;
    var instructions: std.ArrayList(ir.Instruction) = .empty;
    const old_to_new = try allocator.alloc(u32, program.instructions.len + 1);
    defer allocator.free(old_to_new);
    const targeted = try allocator.alloc(bool, program.instructions.len + 1);
    const old_string_to_new = try allocator.alloc(?ir.StringId, program.strings.len);
    @memset(old_string_to_new, null);
    defer allocator.free(old_string_to_new);
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
    var static_run: std.ArrayList(u8) = .empty;
    var static_run_span: ?zeft.SourceSpan = null;

    for (program.instructions, 0..) |instruction, old_index| {
        switch (instruction.data) {
            .write_static => |old_id| {
                const bytes = program.strings[old_id];
                if (targeted[old_index]) try flushStaticRun(
                    allocator,
                    &strings,
                    &instructions,
                    &static_run,
                    &static_run_span,
                );
                old_to_new[old_index] = @intCast(instructions.items.len);
                if (bytes.len == 0) {
                    continue;
                }
                if (static_run_span == null) static_run_span = instruction.span;
                static_run_span.?.start = @min(static_run_span.?.start, instruction.span.start);
                static_run_span.?.end = @max(static_run_span.?.end, instruction.span.end);
                try static_run.appendSlice(allocator, bytes);
            },
            else => {
                try flushStaticRun(
                    allocator,
                    &strings,
                    &instructions,
                    &static_run,
                    &static_run_span,
                );
                if (instruction.data == .include) {
                    const include = instruction.data.include;
                    std.debug.assert(include.identity < program.strings.len);
                    const mapped = old_string_to_new[include.identity] orelse blk: {
                        const id = std.math.cast(ir.StringId, strings.items.len) orelse unreachable;
                        try strings.append(
                            allocator,
                            try allocator.dupe(
                                u8,
                                program.strings[include.identity],
                            ),
                        );
                        old_string_to_new[include.identity] = id;
                        break :blk id;
                    };
                    old_to_new[old_index] = @intCast(instructions.items.len);
                    var rewritten = instruction;
                    rewritten.data.include.identity = mapped;
                    try instructions.append(allocator, rewritten);
                } else {
                    old_to_new[old_index] = @intCast(instructions.items.len);
                    try instructions.append(allocator, instruction);
                }
            },
        }
    }
    try flushStaticRun(allocator, &strings, &instructions, &static_run, &static_run_span);
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
    validateDestinations(instructions.items);

    const simplified = try simplifyAndPrune(allocator, instructions.items, folded_expressions);
    instructions.deinit(allocator);
    instructions.items = simplified;
    validateDestinations(instructions.items);

    // Thread destinations through unconditional jumps. This retains source
    // instructions and spans while removing an extra VM dispatch at runtime.
    for (instructions.items) |*instruction| switch (instruction.data) {
        .jump_if_false => |*branch| branch.target = threadJump(instructions.items, branch.target),
        .jump => |*target| target.* = threadJump(instructions.items, target.*),
        .loop_begin => |*begin| begin.exit_target = threadJump(
            instructions.items,
            begin.exit_target,
        ),

        .loop_next => |*next| {
            next.body_target = threadJump(instructions.items, next.body_target);
            next.exit_target = threadJump(instructions.items, next.exit_target);
        },
        .loop_break => |*target| target.* = threadJump(instructions.items, target.*),
        .loop_continue => |*target| target.* = threadJump(instructions.items, target.*),
        else => {},
    };

    // Check that all references into the rewritten string table remain valid.
    for (instructions.items) |instruction| switch (instruction.data) {
        .write_static => |id| std.debug.assert(id < strings.items.len),
        .include => |include| std.debug.assert(include.identity < strings.items.len),
        else => {},
    };
    validateDestinations(instructions.items);

    return .{
        .strings = try strings.toOwnedSlice(allocator),
        .symbols = program.symbols,
        .expressions = folded_expressions,
        .instructions = instructions.items,
    };
}

fn threadJump(instructions: []const ir.Instruction, initial: u32) u32 {
    var target = initial;
    var steps: usize = 0;
    while (target < instructions.len and instructions[target].data == .jump and steps <
        instructions.len) : (steps += 1)
    {
        const next = instructions[target].data.jump;
        if (next == target) break;
        target = next;
    }
    return target;
}

fn validateDestinations(instructions: []const ir.Instruction) void {
    for (instructions) |instruction| switch (instruction.data) {
        .jump_if_false => |branch| std.debug.assert(branch.target <= instructions.len),
        .jump => |target| std.debug.assert(target <= instructions.len),
        .loop_begin => |begin| std.debug.assert(begin.exit_target <= instructions.len),
        .loop_next => |next| {
            std.debug.assert(next.body_target < instructions.len);
            std.debug.assert(next.exit_target <= instructions.len);
        },
        .loop_break, .loop_continue => |target| std.debug.assert(target <= instructions.len),
        else => {},
    };
}

fn simplifyAndPrune(
    allocator: std.mem.Allocator,
    instructions: []const ir.Instruction,
    expressions: []const ir.ExpressionProgram,
) std.mem.Allocator.Error![]ir.Instruction {
    const rewritten = try allocator.dupe(ir.Instruction, instructions);
    defer allocator.free(rewritten);
    for (rewritten, 0..) |*instruction, pc| {
        if (instruction.data == .jump_if_false) {
            const branch = instruction.data.jump_if_false;
            if (constantBoolean(expressions, branch.expression_id)) |value| {
                instruction.data = .{ .jump = if (value) @intCast(pc + 1) else branch.target };
            }
        }
    }
    validateDestinations(rewritten);
    const reachable = try allocator.alloc(bool, rewritten.len + 1);
    defer allocator.free(reachable);
    @memset(reachable, false);
    var queue: std.ArrayList(usize) = .empty;
    defer queue.deinit(allocator);
    try queue.append(allocator, 0);
    while (queue.items.len > 0) {
        const pc = queue.pop().?;
        if (pc >= rewritten.len or reachable[pc]) continue;
        reachable[pc] = true;
        const instruction = rewritten[pc];
        switch (instruction.data) {
            .end => {},
            .jump => |target| try queue.append(allocator, target),
            .jump_if_false => |branch| {
                if (constantBoolean(expressions, branch.expression_id)) |value| {
                    if (value) try queue.append(
                        allocator,
                        pc + 1,
                    ) else try queue.append(
                        allocator,
                        branch.target,
                    );
                } else {
                    try queue.append(allocator, branch.target);
                    try queue.append(allocator, pc + 1);
                }
            },
            .loop_begin => |begin| {
                try queue.append(allocator, begin.exit_target);
                try queue.append(allocator, pc + 1);
            },
            .loop_next => |next| {
                try queue.append(allocator, next.body_target);
                try queue.append(allocator, next.exit_target);
            },
            .loop_break => |target| try queue.append(allocator, target),
            .loop_continue => |target| try queue.append(allocator, target),
            else => try queue.append(allocator, pc + 1),
        }
    }

    const mapping = try allocator.alloc(u32, rewritten.len + 1);
    defer allocator.free(mapping);
    var compacted: std.ArrayList(ir.Instruction) = .empty;
    for (rewritten, 0..) |instruction, index| {
        mapping[index] = @intCast(compacted.items.len);
        if (reachable[index]) try compacted.append(allocator, instruction);
    }
    mapping[rewritten.len] = @intCast(compacted.items.len);
    for (compacted.items) |*instruction| switch (instruction.data) {
        .jump_if_false => |*branch| branch.target = mapping[branch.target],
        .jump => |*target| target.* = mapping[target.*],
        .loop_begin => |*begin| begin.exit_target = mapping[begin.exit_target],
        .loop_next => |*next| {
            next.body_target = mapping[next.body_target];
            next.exit_target = mapping[next.exit_target];
        },
        .loop_break, .loop_continue => |*target| target.* = mapping[target.*],
        else => {},
    };
    validateDestinations(compacted.items);
    return compacted.toOwnedSlice(allocator);
}

fn constantBoolean(expressions: []const ir.ExpressionProgram, id: ir.ExpressionId) ?bool {
    if (id >= expressions.len) return null;
    const instructions = expressions[id].instructions;
    if (instructions.len != 2 or instructions[0].data != .push_literal or
        instructions[1].data != .return_value) return null;
    return switch (instructions[0].data.push_literal) {
        .boolean => |value| value,
        else => null,
    };
}

/// Fold literal unary and binary operations. The replacement keeps the full
/// source span of the folded expression so later runtime diagnostics continue
/// to refer to original template bytes.
fn foldExpressions(
    allocator: std.mem.Allocator,
    programs: []ir.ExpressionProgram,
) std.mem.Allocator.Error![]ir.ExpressionProgram {
    const result = try allocator.alloc(ir.ExpressionProgram, programs.len);
    for (programs, 0..) |program, expression_index| {
        var output: std.ArrayList(ir.ExpressionInstruction) = .empty;
        const mapping = try allocator.alloc(u32, program.instructions.len + 1);
        defer allocator.free(mapping);
        const targets = try allocator.alloc(bool, program.instructions.len + 1);
        defer allocator.free(targets);
        @memset(targets, false);
        for (program.instructions) |instruction| switch (instruction.data) {
            .jump, .jump_if_false, .jump_if_true => |target| targets[target] = true,
            else => {},
        };
        var block_start: usize = 0;
        for (program.instructions, 0..) |instruction, pc| {
            // Folding must not combine values from different jump paths.
            if (targets[pc]) block_start = output.items.len;
            mapping[pc] = @intCast(output.items.len);
            if (instruction.data == .unary and output.items.len > block_start and
                output.items[output.items.len - 1].data == .push_literal)
            {
                const previous = output.items[output.items.len - 1];
                if (foldUnary(instruction.data.unary, previous.data.push_literal)) |literal| {
                    output.items[output.items.len - 1] = .{
                        .span = .{
                            .start = @min(
                                previous.span.start,
                                instruction.span.start,
                            ),
                            .end = @max(
                                previous.span.end,
                                instruction.span.end,
                            ),
                        },
                        .data = .{ .push_literal = literal },
                    };
                    continue;
                }
            }
            if (instruction.data == .binary and output.items.len >= block_start + 2 and
                output.items[output.items.len - 1].data == .push_literal and
                output.items[output.items.len - 2].data == .push_literal)
            {
                const right = output.items[output.items.len - 1];
                const left = output.items[output.items.len - 2];
                if (foldBinary(
                    instruction.data.binary,
                    left.data.push_literal,
                    right.data.push_literal,
                )) |literal| {
                    output.items.len -= 2;
                    try output.append(allocator, .{
                        .span = .{
                            .start = @min(
                                left.span.start,
                                instruction.span.start,
                            ),
                            .end = @max(
                                right.span.end,
                                instruction.span.end,
                            ),
                        },
                        .data = .{ .push_literal = literal },
                    });
                    continue;
                }
            }
            try output.append(allocator, instruction);
        }
        mapping[program.instructions.len] = @intCast(output.items.len);
        for (output.items) |*instruction| switch (instruction.data) {
            .jump => |target| instruction.data.jump = mapping[target],
            .jump_if_false => |target| instruction.data.jump_if_false = mapping[target],
            .jump_if_true => |target| instruction.data.jump_if_true = mapping[target],
            else => {},
        };
        result[expression_index] = .{ .instructions = try output.toOwnedSlice(allocator) };
    }
    return result;
}

fn foldUnary(op: ir.Operator, literal: ir.Literal) ?ir.Literal {
    return switch (op) {
        .not => switch (literal) {
            .boolean => |v| .{ .boolean = !v },
            else => null,
        },
        .negate => switch (literal) {
            .number => |v| .{ .number = -v },
            else => null,
        },
        else => null,
    };
}

fn foldBinary(op: ir.Operator, left: ir.Literal, right: ir.Literal) ?ir.Literal {
    if (op == .equal or op == .not_equal) {
        if (std.meta.activeTag(left) != std.meta.activeTag(right)) return null;
        const equal = switch (left) {
            .null => right == .null,
            .boolean => |a| switch (right) {
                .boolean => |b| a == b,
                else => false,
            },
            .number => |a| switch (right) {
                .number => |b| a == b,
                else => false,
            },
            .string => |a| switch (right) {
                .string => |b| std.mem.eql(u8, a, b),
                else => false,
            },
        };
        return .{ .boolean = if (op == .equal) equal else !equal };
    }
    const a = switch (left) {
        .number => |n| n,
        else => return null,
    };
    const b = switch (right) {
        .number => |n| n,
        else => return null,
    };
    return switch (op) {
        .add => .{ .number = a + b },
        .subtract => .{ .number = a - b },
        .multiply => .{ .number = a * b },
        .divide => if (b == 0) null else .{ .number = a / b },
        .modulo => if (b == 0) null else .{ .number = @rem(a, b) },
        .less => .{ .boolean = a < b },
        .less_equal => .{ .boolean = a <= b },
        .greater => .{ .boolean = a > b },
        .greater_equal => .{ .boolean = a >= b },
        else => null,
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

fn flushStaticRun(
    allocator: std.mem.Allocator,
    strings: *std.ArrayList([]const u8),
    instructions: *std.ArrayList(ir.Instruction),
    bytes: *std.ArrayList(u8),
    span: *?zeft.SourceSpan,
) std.mem.Allocator.Error!void {
    if (bytes.items.len == 0) return;
    const id = std.math.cast(ir.StringId, strings.items.len) orelse unreachable;
    try strings.append(allocator, try bytes.toOwnedSlice(allocator));
    try instructions.append(allocator, .{ .span = span.*.?, .data = .{ .write_static = id } });
    span.* = null;
}

test "merges adjacent static writes and preserves surrounding instructions" {
    const strings = [_][]const u8{ "<p>", "hello", "!", "</p>" };
    const instructions = [_]ir.Instruction{
        .{ .span = .{ .start = 0, .end = 3 }, .data = .{ .write_static = 0 } },
        .{ .span = .{ .start = 3, .end = 8 }, .data = .{ .write_static = 1 } },
        .{ .span = .{ .start = 8, .end = 9 }, .data = .{ .write_static = 2 } },
        .{
            .span = .{
                .start = 9,
                .end = 10,
            },
            .data = .{ .write_expression = .{
                .expression_id = 0,
                .escape_context = .text,
            } },
        },
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
        for (optimized.strings) |value| std.testing.allocator.free(value);
        std.testing.allocator.free(optimized.strings);
        std.testing.allocator.free(optimized.instructions);
    }

    try std.testing.expectEqual(@as(usize, 4), optimized.instructions.len);
    try std.testing.expectEqual(@as(usize, 2), optimized.strings.len);
    try std.testing.expectEqualStrings("<p>hello!", optimized.strings[0]);
    try std.testing.expectEqualStrings("</p>", optimized.strings[1]);
    try std.testing.expectEqual(
        @as(
            zeft.SourceSpan,
            .{
                .start = 0,
                .end = 9,
            },
        ),
        optimized.instructions[0].span,
    );
    try std.testing.expectEqual(
        ir.Instruction.Data.write_expression,
        std.meta.activeTag(optimized.instructions[1].data),
    );
}

test "optimizer succeeds when no adjacent static writes exist" {
    const instructions = [_]ir.Instruction{
        .{ .span = .{ .start = 0, .end = 1 }, .data = .{ .write_static = 0 } },
        .{
            .span = .{
                .start = 1,
                .end = 2,
            },
            .data = .{ .write_expression = .{
                .expression_id = 0,
                .escape_context = .text,
            } },
        },
        .{ .span = .{ .start = 2, .end = 2 }, .data = .end },
    };
    const program: ir.Program = .{
        .strings = @constCast(&[_][]const u8{"x"}),
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
    try std.testing.expectEqual(@as(usize, 1), optimized.strings.len);
    try std.testing.expectEqual(@as(usize, 3), optimized.instructions.len);
}

test "optimizer preserves branch destinations when writes merge nearby" {
    const strings = [_][]const u8{ "then", "else", ":" };
    const instructions = [_]ir.Instruction{
        .{
            .span = .{
                .start = 0,
                .end = 1,
            },
            .data = .{ .jump_if_false = .{
                .expression_id = 0,
                .target = 3,
            } },
        },
        .{ .span = .{ .start = 1, .end = 2 }, .data = .{ .write_static = 0 } },
        .{ .span = .{ .start = 2, .end = 3 }, .data = .{ .jump = 5 } },
        .{ .span = .{ .start = 3, .end = 4 }, .data = .{ .write_static = 1 } },
        .{ .span = .{ .start = 4, .end = 5 }, .data = .{ .write_static = 2 } },
        .{ .span = .{ .start = 5, .end = 5 }, .data = .end },
    };
    const program: ir.Program = .{
        .strings = @constCast(&strings),
        .symbols = &.{},
        .expressions = &.{},
        .instructions = @constCast(&instructions),
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const optimized = try optimize(arena.allocator(), program);
    try std.testing.expectEqual(@as(u32, 3), optimized.instructions[0].data.jump_if_false.target);
    try std.testing.expectEqual(@as(u32, 4), optimized.instructions[2].data.jump);
    try std.testing.expectEqualStrings("else:", optimized.strings[1]);
}

test "folds constant expression operations and retains the original source span" {
    const source = [_]ir.ExpressionInstruction{
        .{ .span = .{ .start = 2, .end = 3 }, .data = .{ .push_literal = .{ .number = 2 } } },
        .{ .span = .{ .start = 6, .end = 7 }, .data = .{ .push_literal = .{ .number = 3 } } },
        .{ .span = .{ .start = 4, .end = 5 }, .data = .{ .binary = .multiply } },
        .{ .span = .{ .start = 0, .end = 1 }, .data = .{ .push_literal = .{ .number = 1 } } },
        .{ .span = .{ .start = 8, .end = 9 }, .data = .{ .binary = .add } },
        .{ .span = .{ .start = 0, .end = 9 }, .data = .return_value },
    };
    const expressions = [_]ir.ExpressionProgram{.{ .instructions = @constCast(&source) }};
    const optimized = try foldExpressions(std.testing.allocator, @constCast(&expressions));
    defer {
        for (optimized) |expression| std.testing.allocator.free(expression.instructions);
        std.testing.allocator.free(optimized);
    }
    try std.testing.expectEqual(@as(usize, 2), optimized[0].instructions.len);
    try std.testing.expectEqual(
        ir.ExpressionInstruction.Data.push_literal,
        std.meta.activeTag(optimized[0].instructions[0].data),
    );
    try std.testing.expectEqual(@as(f64, 7), optimized[0].instructions[0].data.push_literal.number);
    try std.testing.expectEqual(
        zeft.SourceSpan{
            .start = 2,
            .end = 9,
        },
        optimized[0].instructions[0].span,
    );
    try std.testing.expectEqual(
        ir.ExpressionInstruction.Data.return_value,
        std.meta.activeTag(optimized[0].instructions[1].data),
    );
}

test "does not fold division or modulo by zero" {
    inline for (.{ ir.Operator.divide, ir.Operator.modulo }) |operator| {
        const result = foldBinary(operator, .{ .number = 1 }, .{ .number = 0 });
        try std.testing.expect(result == null);
    }
}

test "threads unconditional jump destinations and removes empty static writes" {
    const strings = [_][]const u8{ "", "x" };
    const instructions = [_]ir.Instruction{
        .{ .span = .{ .start = 0, .end = 0 }, .data = .{ .write_static = 0 } },
        .{ .span = .{ .start = 0, .end = 1 }, .data = .{ .jump = 2 } },
        .{ .span = .{ .start = 1, .end = 1 }, .data = .{ .jump = 3 } },
        .{ .span = .{ .start = 1, .end = 2 }, .data = .{ .write_static = 1 } },
        .{ .span = .{ .start = 2, .end = 2 }, .data = .end },
    };
    const program: ir.Program = .{
        .strings = @constCast(&strings),
        .symbols = &.{},
        .expressions = &.{},
        .instructions = @constCast(&instructions),
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const optimized = try optimize(arena.allocator(), program);
    try std.testing.expectEqual(@as(usize, 4), optimized.instructions.len);
    try std.testing.expectEqual(@as(u32, 2), optimized.instructions[0].data.jump);
    try std.testing.expectEqualStrings("x", optimized.strings[0]);
}

test "constant conditions prune the unreachable branch and preserve selected spans" {
    const expression_instructions = [_]ir.ExpressionInstruction{
        .{ .span = .{ .start = 5, .end = 10 }, .data = .{ .push_literal = .{ .boolean = false } } },
        .{ .span = .{ .start = 5, .end = 10 }, .data = .return_value },
    };
    const expressions = [_]ir.ExpressionProgram{
        .{ .instructions = @constCast(&expression_instructions) },
    };
    const strings = [_][]const u8{ "discard", "keep" };
    const instructions = [_]ir.Instruction{
        .{
            .span = .{
                .start = 0,
                .end = 11,
            },
            .data = .{ .jump_if_false = .{
                .expression_id = 0,
                .target = 3,
            } },
        },
        .{ .span = .{ .start = 11, .end = 18 }, .data = .{ .write_static = 0 } },
        .{ .span = .{ .start = 18, .end = 18 }, .data = .{ .jump = 4 } },
        .{ .span = .{ .start = 25, .end = 29 }, .data = .{ .write_static = 1 } },
        .{ .span = .{ .start = 29, .end = 29 }, .data = .end },
    };
    const program: ir.Program = .{
        .strings = @constCast(&strings),
        .symbols = &.{},
        .expressions = @constCast(&expressions),
        .instructions = @constCast(&instructions),
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const optimized = try optimize(arena.allocator(), program);
    try std.testing.expectEqual(@as(usize, 3), optimized.instructions.len);
    try std.testing.expectEqual(
        ir.Instruction.Data.jump,
        std.meta.activeTag(optimized.instructions[0].data),
    );
    try std.testing.expectEqual(@as(u32, 1), optimized.instructions[0].data.jump);
    const selected_id = optimized.instructions[1].data.write_static;
    try std.testing.expectEqualStrings("keep", optimized.strings[selected_id]);
    try std.testing.expectEqual(
        zeft.SourceSpan{
            .start = 25,
            .end = 29,
        },
        optimized.instructions[1].span,
    );
}
