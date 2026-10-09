//! Render finalized instructions. This module intentionally has no markup
//! parser dependency: static markup reaches it only as serialized byte strings.

const std = @import("std");
const core = @import("zeft_core");
const ir = @import("zeft_ir");

pub const Value = union(enum) {
    null,
    boolean: bool,
    number: f64,
    string: []const u8,
    object: Object,
    sequence: Sequence,
};

pub const Object = struct {
    pointer: *const anyopaque,
    get_property: *const fn (*const anyopaque, []const u8) ?Value,
};

pub const Sequence = struct {
    pointer: *const anyopaque,
    len: usize,
    get_index: *const fn (*const anyopaque, usize) ?Value,
};

pub const ContextEntry = struct { name: []const u8, value: Value };
pub const Callable = *const fn (std.mem.Allocator, ?*const anyopaque, []const Value) anyerror!Value;
pub const Registration = struct {
    name: []const u8,
    callback: Callable,
    user_data: ?*const anyopaque = null,
};
pub const RenderOptions = struct {
    allocator: std.mem.Allocator = std.heap.page_allocator,
    filters: []const Registration = &.{},
    functions: []const Registration = &.{},
    include_context: ?*anyopaque = null,
    include_resolver: ?*const fn (*anyopaque, []const u8, *std.Io.Writer, []const ContextEntry, core.OutputFormat, RenderOptions, core.SourceSpan) anyerror!RenderResult = null,
};
pub const RenderResult = union(enum) {
    success,
    failure: core.RenderDiagnostic,
};
const LocalValue = struct { slot: u32, value: Value };
const LoopFrame = struct { sequence: Sequence, index: usize, local_base: usize, span: core.SourceSpan };

pub fn isString(comptime T: type) bool {
    const type_info = @typeInfo(T);
    return (type_info == .pointer and type_info.pointer.size == .slice and type_info.pointer.child == u8) or
        (type_info == .array and type_info.array.child == u8) or
        (type_info == .pointer and type_info.pointer.size == .one and @typeInfo(type_info.pointer.child) == .array and
            @typeInfo(type_info.pointer.child).array.child == u8);
}

pub fn stringValue(comptime T: type, value: T) []const u8 {
    if (comptime isString(T)) {
        const type_info = @typeInfo(T);
        if (type_info == .array) return value[0..];
        if (type_info == .pointer and type_info.pointer.size == .one and @typeInfo(type_info.pointer.child) == .array) return value[0..];
        return value;
    }
    unreachable;
}

/// Adapt supported native context values without allocating or copying them.
/// Objects are Zig structs, sequences are arrays/slices, and scalar leaves are
/// byte strings in the initial access-only expression subset.
pub fn adapt(comptime T: type, pointer: *const T) Value {
    const type_info = @typeInfo(T);
    if (type_info == .pointer and type_info.pointer.size == .slice and type_info.pointer.child == u8) {
        return .{ .string = pointer.* };
    }
    if (type_info == .array and type_info.array.child == u8) {
        return .{ .string = pointer.*[0..] };
    }
    if (T == bool) return .{ .boolean = pointer.* };
    if (type_info == .pointer and type_info.pointer.size == .slice) {
        return .{ .sequence = .{
            .pointer = @ptrCast(pointer),
            .len = pointer.*.len,
            .get_index = sequenceIndex(T),
        } };
    }
    if (type_info == .array) {
        return .{ .sequence = .{
            .pointer = @ptrCast(pointer),
            .len = type_info.array.len,
            .get_index = sequenceIndex(T),
        } };
    }
    if (type_info == .@"struct") {
        return .{ .object = .{ .pointer = @ptrCast(pointer), .get_property = objectProperty(T) } };
    }
    @compileError("context values must be structs, arrays, slices, or byte strings");
}

fn objectProperty(comptime T: type) *const fn (*const anyopaque, []const u8) ?Value {
    return struct {
        fn get(pointer: *const anyopaque, name: []const u8) ?Value {
            const value: *const T = @ptrCast(@alignCast(pointer));
            inline for (@typeInfo(T).@"struct".fields) |field| {
                if (std.mem.eql(u8, name, field.name)) return adapt(field.type, &@field(value.*, field.name));
            }
            return null;
        }
    }.get;
}

fn sequenceIndex(comptime T: type) *const fn (*const anyopaque, usize) ?Value {
    return struct {
        fn get(pointer: *const anyopaque, index: usize) ?Value {
            const value: *const T = @ptrCast(@alignCast(pointer));
            const type_info = @typeInfo(T);
            if (type_info == .array) {
                if (index >= type_info.array.len) return null;
                return adapt(type_info.array.child, &value.*[index]);
            }
            if (type_info == .pointer and type_info.pointer.size == .slice) {
                if (index >= value.*.len) return null;
                return adapt(type_info.pointer.child, &value.*[index]);
            }
            unreachable;
        }
    }.get;
}

pub fn render(
    program: ir.Program,
    writer: *std.Io.Writer,
    context: []const ContextEntry,
    format: core.OutputFormat,
) anyerror!RenderResult {
    return renderWithOptions(program, writer, context, format, .{});
}

pub fn renderWithOptions(
    program: ir.Program,
    writer: *std.Io.Writer,
    context: []const ContextEntry,
    format: core.OutputFormat,
    options: RenderOptions,
) anyerror!RenderResult {
    var scratch = std.heap.ArenaAllocator.init(options.allocator);
    defer scratch.deinit();
    const render_allocator = scratch.allocator();
    const locals = try render_allocator.alloc(LocalValue, program.instructions.len);
    var local_count: usize = 0;
    const loops = try render_allocator.alloc(LoopFrame, program.instructions.len);
    var loop_count: usize = 0;
    var pc: usize = 0;
    while (pc < program.instructions.len) : (pc += 1) {
        const instruction = program.instructions[pc];
        switch (instruction.data) {
            .write_static => |id| try writer.writeAll(program.strings[id]),
            .write_expression => |write| {
                const value = switch (evaluateExpression(program, write.expression_id, context, options, scratch.allocator(), locals[0..local_count])) {
                    .success => |result| result,
                    .failure => |diagnostic| return .{ .failure = diagnostic },
                };
                switch (value) {
                    .string => |string| try writeEscaped(writer, string, write.escape_context, format),
                    .null => {},
                    .boolean => |boolean| try writeEscaped(writer, if (boolean) "true" else "false", write.escape_context, format),
                    .number => |number| try writer.print("{d}", .{number}),
                    else => return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } },
                }
            },
            .jump_if_false => |branch| {
                const value = switch (evaluateExpression(program, branch.expression_id, context, options, scratch.allocator(), locals[0..local_count])) {
                    .success => |result| result,
                    .failure => |diagnostic| return .{ .failure = diagnostic },
                };
                switch (value) {
                    .boolean => |condition| {
                        if (!condition) pc = branch.target - 1;
                    },
                    else => return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } },
                }
            },
            .jump => |target| pc = target - 1,
            .loop_begin => |begin| {
                const iterable = switch (evaluateExpression(program, begin.expression_id, context, options, scratch.allocator(), locals[0..local_count])) {
                    .success => |result| result,
                    .failure => |diagnostic| return .{ .failure = diagnostic },
                };
                const sequence = switch (iterable) {
                    .sequence => |value| value,
                    else => return .{ .failure = .{ .kind = .non_iterable, .span = instruction.span } },
                };
                if (sequence.len == 0) {
                    pc = begin.exit_target - 1;
                    continue;
                }
                if (loop_count >= loops.len or local_count >= locals.len) return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                const item = sequence.get_index(sequence.pointer, 0) orelse return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                loops[loop_count] = .{ .sequence = sequence, .index = 0, .local_base = local_count, .span = instruction.span };
                loop_count += 1;
                locals[local_count] = .{ .slot = begin.slot, .value = item };
                local_count += 1;
            },
            .loop_next => |next| {
                if (loop_count == 0) return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                const frame = &loops[loop_count - 1];
                frame.index += 1;
                if (frame.index >= frame.sequence.len) {
                    local_count = frame.local_base;
                    loop_count -= 1;
                    pc = next.exit_target - 1;
                } else {
                    const item = frame.sequence.get_index(frame.sequence.pointer, frame.index) orelse return .{ .failure = .{ .kind = .invalid_operand, .span = frame.span } };
                    locals[frame.local_base].value = item;
                    pc = next.body_target - 1;
                }
            },
            .loop_break => |target| {
                if (loop_count == 0) return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                local_count = loops[loop_count - 1].local_base;
                loop_count -= 1;
                pc = target - 1;
            },
            .loop_continue => |target| pc = target - 1,
            .include => |include| {
                const identity = program.strings[include.identity];
                const resolver = options.include_resolver orelse return .{ .failure = .{
                    .kind = .missing_include,
                    .span = instruction.span,
                    .include_identity = identity,
                } };
                const resolver_context = options.include_context orelse return .{ .failure = .{
                    .kind = .missing_include,
                    .span = instruction.span,
                    .include_identity = identity,
                } };
                switch (try resolver(resolver_context, identity, writer, context, format, options, instruction.span)) {
                    .success => {},
                    .failure => |diagnostic| return .{ .failure = diagnostic },
                }
            },
            .end => return .success,
        }
    }
    return .{ .failure = .{ .kind = .invalid_operand } };
}

const ExpressionResult = union(enum) {
    success: Value,
    failure: core.RenderDiagnostic,
};

fn evaluateExpression(
    program: ir.Program,
    expression_id: ir.ExpressionId,
    context: []const ContextEntry,
    options: RenderOptions,
    allocator: std.mem.Allocator,
    locals: []const LocalValue,
) ExpressionResult {
    if (expression_id >= program.expressions.len) return .{ .failure = .{ .kind = .invalid_operand } };
    const expression = program.expressions[expression_id];
    // Expression evaluation is render-local and stack based. Keep a generous
    // fixed cap so rendering does not allocate; malformed/deep programs fail
    // with the normal invalid-operand diagnostic.
    var stack: [256]Value = undefined;
    var depth: usize = 0;
    var pc: usize = 0;
    while (pc < expression.instructions.len) : (pc += 1) {
        const instruction = expression.instructions[pc];
        switch (instruction.data) {
            .load_root_symbol => |symbol_id| {
                if (symbol_id >= program.symbols.len) return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                const name = program.symbols[symbol_id].name;
                var found = false;
                for (context) |entry| {
                    if (std.mem.eql(u8, name, entry.name)) {
                        if (depth >= stack.len) return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                        stack[depth] = entry.value;
                        depth += 1;
                        found = true;
                        break;
                    }
                }
                if (!found) return .{ .failure = .{ .kind = .missing_variable, .span = instruction.span } };
            },
            .load_local => |slot| {
                var found: ?Value = null;
                var local_index = locals.len;
                while (local_index > 0) {
                    local_index -= 1;
                    if (locals[local_index].slot == slot) {
                        found = locals[local_index].value;
                        break;
                    }
                }
                const value = found orelse return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                if (depth >= stack.len) return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                stack[depth] = value;
                depth += 1;
            },
            .push_literal => |literal| {
                if (depth >= stack.len) return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                stack[depth] = switch (literal) {
                    .null => .null,
                    .boolean => |v| .{ .boolean = v },
                    .number => |v| .{ .number = v },
                    .string => |v| .{ .string = v },
                };
                depth += 1;
            },
            .get_property => |name| {
                if (depth == 0) return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                const current = stack[depth - 1];
                const next: ?Value = switch (current) {
                    .object => |object| object.get_property(object.pointer, name),
                    else => null,
                };
                stack[depth - 1] = next orelse return .{ .failure = .{ .kind = .invalid_property_access, .span = instruction.span } };
            },
            .get_index => |index| {
                if (depth == 0) return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                const current = stack[depth - 1];
                const next: ?Value = switch (current) {
                    .sequence => |sequence| if (index < sequence.len) sequence.get_index(sequence.pointer, index) else null,
                    else => null,
                };
                stack[depth - 1] = next orelse return .{ .failure = .{ .kind = .invalid_property_access, .span = instruction.span } };
            },
            .unary => |op| {
                if (depth == 0) return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                stack[depth - 1] = switch (op) {
                    .not => switch (stack[depth - 1]) {
                        .boolean => |v| .{ .boolean = !v },
                        else => return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } },
                    },
                    .negate => switch (stack[depth - 1]) {
                        .number => |v| .{ .number = -v },
                        else => return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } },
                    },
                    else => return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } },
                };
            },
            .jump_if_false => |target| {
                if (depth == 0) return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                switch (stack[depth - 1]) {
                    .boolean => |v| if (!v) {
                        pc = target - 1;
                    } else {
                        depth -= 1;
                    },
                    else => return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } },
                }
            },
            .jump_if_true => |target| {
                if (depth == 0) return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                switch (stack[depth - 1]) {
                    .boolean => |v| if (v) {
                        pc = target - 1;
                    } else {
                        depth -= 1;
                    },
                    else => return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } },
                }
            },
            .jump => |target| {
                pc = target - 1;
            },
            .call_function => |call| {
                const count: usize = call.argument_count;
                if (count > depth) return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                const args = stack[depth - count .. depth];
                const function = findRegistration(options.functions, call.name) orelse findBuiltinFunction(call.name);
                const result = if (function) |registered|
                    registered.callback(allocator, registered.user_data, args) catch return .{ .failure = .{ .kind = .function_failure, .span = instruction.span } }
                else
                    return .{ .failure = .{ .kind = .function_failure, .span = instruction.span } };
                depth -= count;
                stack[depth] = result;
                depth += 1;
            },
            .call_filter => |call| {
                const count: usize = call.argument_count;
                if (count > depth or count == 0) return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                const args = stack[depth - count .. depth];
                const filter = findRegistration(options.filters, call.name) orelse findBuiltinFilter(call.name);
                const result = if (filter) |registered|
                    registered.callback(allocator, registered.user_data, args) catch return .{ .failure = .{ .kind = .filter_failure, .span = instruction.span } }
                else
                    return .{ .failure = .{ .kind = .filter_failure, .span = instruction.span } };
                depth -= count;
                stack[depth] = result;
                depth += 1;
            },
            .binary => |op| {
                if (depth < 2) return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
                const right = stack[depth - 1];
                const left = stack[depth - 2];
                depth -= 1;
                stack[depth - 1] = applyBinary(op, left, right) orelse return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
            },
            .return_value => return if (depth == 1) .{ .success = stack[0] } else .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } },
        }
    }
    return .{ .failure = .{ .kind = .invalid_operand } };
}

fn findRegistration(registrations: []const Registration, name: []const u8) ?Registration {
    for (registrations) |registration| if (std.mem.eql(u8, name, registration.name)) return registration;
    return null;
}

fn findBuiltinFunction(name: []const u8) ?Registration {
    if (std.mem.eql(u8, name, "length")) return .{ .name = "length", .callback = builtinLength };
    return null;
}

fn findBuiltinFilter(name: []const u8) ?Registration {
    if (std.mem.eql(u8, name, "default")) return .{ .name = "default", .callback = builtinDefault };
    if (std.mem.eql(u8, name, "upper")) return .{ .name = "upper", .callback = builtinUpper };
    if (std.mem.eql(u8, name, "lower")) return .{ .name = "lower", .callback = builtinLower };
    if (std.mem.eql(u8, name, "trim")) return .{ .name = "trim", .callback = builtinTrim };
    return null;
}

fn builtinLength(_: std.mem.Allocator, _: ?*const anyopaque, args: []const Value) anyerror!Value {
    if (args.len != 1) return error.InvalidArguments;
    return switch (args[0]) {
        .string => |value| .{ .number = @floatFromInt(value.len) },
        .sequence => |value| .{ .number = @floatFromInt(value.len) },
        else => error.InvalidArguments,
    };
}

fn builtinDefault(_: std.mem.Allocator, _: ?*const anyopaque, args: []const Value) anyerror!Value {
    if (args.len != 2) return error.InvalidArguments;
    return switch (args[0]) {
        .null => args[1],
        .string => |value| if (value.len == 0) args[1] else args[0],
        else => args[0],
    };
}

fn builtinUpper(allocator: std.mem.Allocator, _: ?*const anyopaque, args: []const Value) anyerror!Value {
    return mapCase(allocator, args, true);
}

fn builtinLower(allocator: std.mem.Allocator, _: ?*const anyopaque, args: []const Value) anyerror!Value {
    return mapCase(allocator, args, false);
}

fn mapCase(allocator: std.mem.Allocator, args: []const Value, uppercase: bool) anyerror!Value {
    if (args.len != 1) return error.InvalidArguments;
    const input = switch (args[0]) {
        .string => |value| value,
        else => return error.InvalidArguments,
    };
    const output = try allocator.dupe(u8, input);
    for (output) |*byte| byte.* = if (uppercase) std.ascii.toUpper(byte.*) else std.ascii.toLower(byte.*);
    return .{ .string = output };
}

fn builtinTrim(allocator: std.mem.Allocator, _: ?*const anyopaque, args: []const Value) anyerror!Value {
    if (args.len != 1) return error.InvalidArguments;
    const input = switch (args[0]) {
        .string => |value| value,
        else => return error.InvalidArguments,
    };
    return .{ .string = try allocator.dupe(u8, std.mem.trim(u8, input, " \t\r\n")) };
}

fn applyBinary(op: ir.Operator, left: Value, right: Value) ?Value {
    if (op == .equal or op == .not_equal) {
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
            else => false,
        };
        return .{ .boolean = if (op == .equal) equal else !equal };
    }
    const a = if (left == .number) left.number else return null;
    const b = if (right == .number) right.number else return null;
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

fn writeEscaped(writer: *std.Io.Writer, value: []const u8, context: ir.EscapeContext, format: core.OutputFormat) anyerror!void {
    var segment_start: usize = 0;
    for (value, 0..) |byte, index| {
        const replacement: ?[]const u8 = switch (context) {
            .text => switch (byte) {
                '&' => "&amp;",
                '<' => "&lt;",
                '>' => "&gt;",
                else => null,
            },
            .attribute => switch (byte) {
                '&' => "&amp;",
                '<' => "&lt;",
                '>' => "&gt;",
                '"' => "&quot;",
                '\'' => if (format == .html) "&#39;" else "&apos;",
                else => null,
            },
        };
        if (replacement) |escaped| {
            try writer.writeAll(value[segment_start..index]);
            try writer.writeAll(escaped);
            segment_start = index + 1;
        }
    }
    try writer.writeAll(value[segment_start..]);
}

test "runtime writes serialized static bytes without markup interpretation" {
    const static_bytes = "<Root data-x='a &amp; b'><Child /></Root>";
    const strings = [_][]const u8{static_bytes};
    const instructions = [_]ir.Instruction{
        .{ .span = .{ .start = 0, .end = static_bytes.len }, .data = .{ .write_static = 0 } },
        .{ .span = .{ .start = static_bytes.len, .end = static_bytes.len }, .data = .end },
    };
    const program: ir.Program = .{
        .strings = @constCast(&strings),
        .symbols = &.{},
        .expressions = &.{},
        .instructions = @constCast(&instructions),
    };
    var output: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const result = try render(program, &writer, &.{}, .xml);
    try std.testing.expectEqual(RenderResult.success, result);
    try std.testing.expectEqualStrings(static_bytes, std.Io.Writer.buffered(&writer));
}
