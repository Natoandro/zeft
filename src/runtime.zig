//! Render finalized instructions. This module intentionally has no markup
//! parser dependency: static markup reaches it only as serialized byte strings.

const std = @import("std");
const core = @import("zeft_core");
const ir = @import("zeft_ir");

pub const Value = union(enum) {
    null,
    invalid,
    boolean: bool,
    integer: i64,
    float: f64,
    string: []const u8,
    trusted_html: []const u8,
    trusted_xml: []const u8,
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
pub const IncludeResolver = struct {
    context: *anyopaque,
    resolve: *const fn (
        *anyopaque,
        []const u8,
        *std.Io.Writer,
        []const ContextEntry,
        core.OutputFormat,
        RenderOptions,
        core.SourceSpan,
    ) anyerror!RenderResult,
};
pub const RenderOptions = struct {
    allocator: std.mem.Allocator = std.heap.page_allocator,
    callables: []const Registration = &.{},
    include_resolver: ?IncludeResolver = null,
};
pub const RenderResult = union(enum) {
    success,
    failure: core.RenderDiagnostic,
};
const LocalValue = struct { slot: u32, value: Value };
const LoopFrame = struct {
    sequence: Sequence,
    index: usize,
    local_base: usize,
    span: core.SourceSpan,
};

pub fn isString(comptime T: type) bool {
    const type_info = @typeInfo(T);
    return (type_info == .pointer and type_info.pointer.size == .slice and
        type_info.pointer.child == u8) or
        (type_info == .array and type_info.array.child == u8) or
        (type_info == .pointer and type_info.pointer.size == .one and
            @typeInfo(type_info.pointer.child) == .array and
            @typeInfo(type_info.pointer.child).array.child == u8);
}

pub fn stringValue(comptime T: type, pointer: *const T) []const u8 {
    if (comptime isString(T)) {
        const type_info = @typeInfo(T);
        if (type_info == .array) return pointer[0..];
        if (type_info == .pointer and type_info.pointer.size == .one and
            @typeInfo(type_info.pointer.child) == .array) return pointer.*[0..];
        return pointer.*;
    }
    unreachable;
}

/// Adapt supported native context values without allocating or copying them.
pub fn adapt(comptime T: type, pointer: *const T) Value {
    const type_info = @typeInfo(T);
    if (type_info == .pointer and type_info.pointer.size == .slice and
        type_info.pointer.child == u8)
    {
        return .{ .string = pointer.* };
    }
    if (type_info == .array and type_info.array.child == u8) {
        return .{ .string = pointer[0..] };
    }
    if (T == bool) return .{ .boolean = pointer.* };
    if (type_info == .int) {
        const adapted = std.math.cast(i64, pointer.*) orelse return .invalid;
        return .{ .integer = adapted };
    }
    if (type_info == .float) return .{ .float = @floatCast(pointer.*) };
    if (type_info == .optional) {
        if (pointer.*) |*value| return adapt(type_info.optional.child, value);
        return .null;
    }
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
    @compileError("unsupported context value type");
}

pub fn isAggregate(comptime T: type) bool {
    if (isString(T)) return false;
    return switch (@typeInfo(T)) {
        .array, .@"struct" => true,
        .pointer => |pointer| pointer.size == .slice,
        .optional => |optional| isAggregate(optional.child),
        else => false,
    };
}

fn objectProperty(comptime T: type) *const fn (*const anyopaque, []const u8) ?Value {
    return struct {
        fn get(pointer: *const anyopaque, name: []const u8) ?Value {
            const value: *const T = @ptrCast(@alignCast(pointer));
            inline for (@typeInfo(T).@"struct".fields) |field| {
                if (std.mem.eql(
                    u8,
                    name,
                    field.name,
                )) return adapt(
                    field.type,
                    &@field(
                        value.*,
                        field.name,
                    ),
                );
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
                const value = switch (try evaluateExpression(
                    program,
                    write.expression_id,
                    context,
                    options,
                    scratch.allocator(),
                    locals[0..local_count],
                )) {
                    .success => |result| result,
                    .failure => |diagnostic| return .{ .failure = diagnostic },
                };
                switch (value) {
                    .string => |string| try writeEscaped(
                        writer,
                        string,
                        write.escape_context,
                        format,
                    ),
                    .trusted_html => |bytes| {
                        if (format != .html or write.escape_context != .text) return .{
                            .failure = .{
                                .kind = .invalid_operand,
                                .span = instruction.span,
                            },
                        };
                        try writer.writeAll(bytes);
                    },
                    .trusted_xml => |bytes| {
                        if (format != .xml or write.escape_context != .text) return .{
                            .failure = .{
                                .kind = .invalid_operand,
                                .span = instruction.span,
                            },
                        };
                        try writer.writeAll(bytes);
                    },
                    .null => {},
                    .boolean => |boolean| try writeEscaped(
                        writer,
                        if (boolean) "true" else "false",
                        write.escape_context,
                        format,
                    ),
                    .float => |number| try writer.print("{d}", .{number}),
                    .integer => |integer| try writer.print("{d}", .{integer}),
                    else => return .{ .failure = .{
                        .kind = .invalid_operand,
                        .span = instruction.span,
                    } },
                }
            },
            .jump_if_false => |branch| {
                const value = switch (try evaluateExpression(
                    program,
                    branch.expression_id,
                    context,
                    options,
                    scratch.allocator(),
                    locals[0..local_count],
                )) {
                    .success => |result| result,
                    .failure => |diagnostic| return .{ .failure = diagnostic },
                };
                switch (value) {
                    .boolean => |condition| {
                        if (!condition) pc = branch.target - 1;
                    },
                    else => return .{ .failure = .{
                        .kind = .invalid_operand,
                        .span = instruction.span,
                    } },
                }
            },
            .jump => |target| pc = target - 1,
            .loop_begin => |begin| {
                const iterable = switch (try evaluateExpression(
                    program,
                    begin.expression_id,
                    context,
                    options,
                    scratch.allocator(),
                    locals[0..local_count],
                )) {
                    .success => |result| result,
                    .failure => |diagnostic| return .{ .failure = diagnostic },
                };
                const sequence = switch (iterable) {
                    .sequence => |value| value,
                    .invalid => return .{ .failure = .{
                        .kind = .invalid_operand,
                        .span = instruction.span,
                    } },
                    else => return .{ .failure = .{
                        .kind = .non_iterable,
                        .span = instruction.span,
                    } },
                };
                if (sequence.len == 0) {
                    pc = begin.exit_target - 1;
                    continue;
                }
                if (loop_count >= loops.len or local_count >= locals.len) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                const item = sequence.get_index(
                    sequence.pointer,
                    0,
                ) orelse return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                loops[loop_count] = .{
                    .sequence = sequence,
                    .index = 0,
                    .local_base = local_count,
                    .span = instruction.span,
                };
                loop_count += 1;
                locals[local_count] = .{ .slot = begin.slot, .value = item };
                local_count += 1;
            },
            .loop_next => |next| {
                if (loop_count == 0) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                const frame = &loops[loop_count - 1];
                frame.index += 1;
                if (frame.index >= frame.sequence.len) {
                    local_count = frame.local_base;
                    loop_count -= 1;
                    pc = next.exit_target - 1;
                } else {
                    const item = frame.sequence.get_index(
                        frame.sequence.pointer,
                        frame.index,
                    ) orelse return .{ .failure = .{
                        .kind = .invalid_operand,
                        .span = frame.span,
                    } };
                    locals[frame.local_base].value = item;
                    pc = next.body_target - 1;
                }
            },
            .loop_break => |target| {
                if (loop_count == 0) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
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
                switch (try resolver.resolve(
                    resolver.context,
                    identity,
                    writer,
                    context,
                    format,
                    options,
                    instruction.span,
                )) {
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
) std.mem.Allocator.Error!ExpressionResult {
    if (expression_id >= program.expressions.len)
        return .{ .failure = .{ .kind = .invalid_operand } };
    const expression = program.expressions[expression_id];
    // An acyclic expression can push at most one value per instruction.
    // Keep ordinary expressions on the stack and spill larger programs to scratch.
    var inline_stack: [256]Value = undefined;
    const stack = if (expression.instructions.len <= inline_stack.len)
        inline_stack[0..]
    else
        try allocator.alloc(Value, expression.instructions.len);
    var depth: usize = 0;
    var pc: usize = 0;
    while (pc < expression.instructions.len) : (pc += 1) {
        const instruction = expression.instructions[pc];
        switch (instruction.data) {
            .load_root_symbol => |symbol_id| {
                if (symbol_id >= program.symbols.len) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                const name = program.symbols[symbol_id].name;
                var found = false;
                for (context) |entry| {
                    if (std.mem.eql(u8, name, entry.name)) {
                        if (entry.value == .invalid) return .{ .failure = .{
                            .kind = .invalid_operand,
                            .span = instruction.span,
                        } };
                        if (depth >= stack.len) return .{ .failure = .{
                            .kind = .invalid_operand,
                            .span = instruction.span,
                        } };
                        stack[depth] = entry.value;
                        depth += 1;
                        found = true;
                        break;
                    }
                }
                if (!found) return .{ .failure = .{
                    .kind = .missing_variable,
                    .span = instruction.span,
                } };
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
                const value = found orelse return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                if (depth >= stack.len) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                stack[depth] = value;
                depth += 1;
            },
            .push_literal => |literal| {
                if (depth >= stack.len) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                stack[depth] = switch (literal) {
                    .null => .null,
                    .boolean => |v| .{ .boolean = v },
                    .number => |v| .{ .float = v },
                    .string => |v| .{ .string = v },
                };
                depth += 1;
            },
            .get_property => |name| {
                if (depth == 0) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                const current = stack[depth - 1];
                if (current == .invalid) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                const next: ?Value = switch (current) {
                    .object => |object| object.get_property(object.pointer, name),
                    else => null,
                };
                stack[depth - 1] = next orelse return .{ .failure = .{
                    .kind = .invalid_property_access,
                    .span = instruction.span,
                } };
            },
            .get_index => |index| {
                if (depth == 0) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                const current = stack[depth - 1];
                if (current == .invalid) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                const next: ?Value = switch (current) {
                    .sequence => |sequence| if (index < sequence.len) sequence.get_index(
                        sequence.pointer,
                        index,
                    ) else null,
                    else => null,
                };
                stack[depth - 1] = next orelse return .{ .failure = .{
                    .kind = .invalid_property_access,
                    .span = instruction.span,
                } };
            },
            .get_index_dynamic => {
                if (depth < 2) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                const selector = stack[depth - 1];
                const current = stack[depth - 2];
                if (selector == .invalid or current == .invalid) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                const index: usize = switch (selector) {
                    .integer => |value| if (value < 0) return .{ .failure = .{
                        .kind = .invalid_property_access,
                        .span = instruction.span,
                    } } else @intCast(value),
                    .float => |value| blk: {
                        // The rounded floating limit is exclusive, avoiding an
                        // out-of-range float-to-integer conversion at usize max.
                        if (!std.math.isFinite(value) or value < 0 or @trunc(value) != value or
                            value >= @as(
                                f64,
                                @floatFromInt(std.math.maxInt(usize)),
                            ))
                            return .{ .failure = .{
                                .kind = .invalid_property_access,
                                .span = instruction.span,
                            } };
                        break :blk @intFromFloat(value);
                    },
                    else => return .{ .failure = .{
                        .kind = .invalid_property_access,
                        .span = instruction.span,
                    } },
                };
                const next: ?Value = switch (current) {
                    .sequence => |sequence| if (index < sequence.len) sequence.get_index(
                        sequence.pointer,
                        index,
                    ) else null,
                    else => null,
                };
                depth -= 1;
                stack[depth - 1] = next orelse return .{ .failure = .{
                    .kind = .invalid_property_access,
                    .span = instruction.span,
                } };
            },
            .unary => |op| {
                if (depth == 0) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                stack[depth - 1] = switch (op) {
                    .not => switch (stack[depth - 1]) {
                        .boolean => |v| .{ .boolean = !v },
                        else => return .{ .failure = .{
                            .kind = .invalid_operand,
                            .span = instruction.span,
                        } },
                    },
                    .negate => switch (stack[depth - 1]) {
                        .float => |v| .{ .float = -v },
                        .integer => |v| .{ .integer = std.math.sub(i64, 0, v) catch return .{
                            .failure = .{ .kind = .invalid_operand, .span = instruction.span },
                        } },
                        else => return .{ .failure = .{
                            .kind = .invalid_operand,
                            .span = instruction.span,
                        } },
                    },
                    else => return .{ .failure = .{
                        .kind = .invalid_operand,
                        .span = instruction.span,
                    } },
                };
            },
            .require_boolean => {
                if (depth == 0 or stack[depth - 1] != .boolean) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
            },
            .jump_if_false => |target| {
                if (depth == 0) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                switch (stack[depth - 1]) {
                    .boolean => |v| if (!v) {
                        pc = target - 1;
                    } else {
                        depth -= 1;
                    },
                    else => return .{ .failure = .{
                        .kind = .invalid_operand,
                        .span = instruction.span,
                    } },
                }
            },
            .jump_if_true => |target| {
                if (depth == 0) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                switch (stack[depth - 1]) {
                    .boolean => |v| if (v) {
                        pc = target - 1;
                    } else {
                        depth -= 1;
                    },
                    else => return .{ .failure = .{
                        .kind = .invalid_operand,
                        .span = instruction.span,
                    } },
                }
            },
            .jump => |target| {
                pc = target - 1;
            },
            .call => |call| {
                const count: usize = call.argument_count;
                if (count > depth) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                const args = stack[depth - count .. depth];
                for (args) |arg| if (arg == .invalid) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                const function = findRegistration(
                    options.callables,
                    call.name,
                ) orelse findBuiltinCallable(call.name);
                const result = if (function) |registered|
                    registered.callback(
                        allocator,
                        registered.user_data,
                        args,
                    ) catch |err| {
                        if (err == error.OutOfMemory) return error.OutOfMemory;
                        return .{ .failure = .{
                            .kind = .callable_failure,
                            .span = instruction.span,
                            .callback_error = @errorName(err),
                        } };
                    }
                else
                    return .{ .failure = .{ .kind = .callable_failure, .span = instruction.span } };
                depth -= count;
                stack[depth] = result;
                depth += 1;
            },
            .binary => |op| {
                if (depth < 2) return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
                const right = stack[depth - 1];
                const left = stack[depth - 2];
                depth -= 1;
                stack[depth - 1] = applyBinary(
                    op,
                    left,
                    right,
                ) orelse return .{ .failure = .{
                    .kind = .invalid_operand,
                    .span = instruction.span,
                } };
            },
            .return_value => return if (depth == 1) .{ .success = stack[0] } else .{ .failure = .{
                .kind = .invalid_operand,
                .span = instruction.span,
            } },
        }
    }
    return .{ .failure = .{ .kind = .invalid_operand } };
}

fn findRegistration(registrations: []const Registration, name: []const u8) ?Registration {
    for (registrations) |registration| if (std.mem.eql(
        u8,
        name,
        registration.name,
    )) return registration;
    return null;
}

fn findBuiltinCallable(name: []const u8) ?Registration {
    if (std.mem.eql(u8, name, "length")) return .{ .name = "length", .callback = builtinLength };
    if (std.mem.eql(u8, name, "default")) return .{ .name = "default", .callback = builtinDefault };
    if (std.mem.eql(u8, name, "upper")) return .{ .name = "upper", .callback = builtinUpper };
    if (std.mem.eql(u8, name, "lower")) return .{ .name = "lower", .callback = builtinLower };
    if (std.mem.eql(u8, name, "trim")) return .{ .name = "trim", .callback = builtinTrim };
    return null;
}

fn builtinLength(_: std.mem.Allocator, _: ?*const anyopaque, args: []const Value) anyerror!Value {
    if (args.len != 1) return error.InvalidArguments;
    return switch (args[0]) {
        .string => |value| .{ .float = @floatFromInt(value.len) },
        .sequence => |value| .{ .float = @floatFromInt(value.len) },
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

fn builtinUpper(
    allocator: std.mem.Allocator,
    _: ?*const anyopaque,
    args: []const Value,
) anyerror!Value {
    return mapCase(allocator, args, true);
}

fn builtinLower(
    allocator: std.mem.Allocator,
    _: ?*const anyopaque,
    args: []const Value,
) anyerror!Value {
    return mapCase(allocator, args, false);
}

fn mapCase(allocator: std.mem.Allocator, args: []const Value, uppercase: bool) anyerror!Value {
    if (args.len != 1) return error.InvalidArguments;
    const input = switch (args[0]) {
        .string => |value| value,
        else => return error.InvalidArguments,
    };
    const output = try allocator.dupe(u8, input);
    for (output) |*byte| {
        byte.* = if (uppercase) std.ascii.toUpper(byte.*) else std.ascii.toLower(byte.*);
    }
    return .{ .string = output };
}

fn builtinTrim(
    allocator: std.mem.Allocator,
    _: ?*const anyopaque,
    args: []const Value,
) anyerror!Value {
    if (args.len != 1) return error.InvalidArguments;
    const input = switch (args[0]) {
        .string => |value| value,
        else => return error.InvalidArguments,
    };
    return .{ .string = try allocator.dupe(u8, std.mem.trim(u8, input, " \t\r\n")) };
}

fn applyBinary(op: ir.Operator, left: Value, right: Value) ?Value {
    if (op == .equal or op == .not_equal) {
        if (left == .null or right == .null) {
            const equal = left == .null and right == .null;
            return .{ .boolean = if (op == .equal) equal else !equal };
        }
        if ((left == .integer or left == .float) and
            (right == .integer or right == .float))
        {
            const equal = numericCompare(left, right) == .eq;
            return .{ .boolean = if (op == .equal) equal else !equal };
        }
        if (std.meta.activeTag(left) != std.meta.activeTag(right)) return null;
        const equal = switch (left) {
            .null => right == .null,
            .boolean => |a| switch (right) {
                .boolean => |b| a == b,
                else => false,
            },
            .float => |a| switch (right) {
                .float => |b| a == b,
                else => false,
            },
            .integer => |a| switch (right) {
                .integer => |b| a == b,
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
    if ((left == .integer or left == .float) and
        (right == .integer or right == .float))
    {
        if (op == .less or op == .less_equal or op == .greater or op == .greater_equal) {
            const order = numericCompare(left, right) orelse return .{ .boolean = false };
            return .{ .boolean = switch (op) {
                .less => order == .lt,
                .less_equal => order != .gt,
                .greater => order == .gt,
                .greater_equal => order != .lt,
                else => unreachable,
            } };
        }
        if (op == .divide) {
            const a = asFloat(left);
            const b = asFloat(right);
            return if (b == 0) null else .{ .float = a / b };
        }
        if (left == .integer and right == .integer) {
            return applyIntegerBinary(op, left.integer, right.integer);
        }
        if ((left == .integer and right == .float) or
            (left == .float and right == .integer))
        {
            const float_value = if (left == .float) left.float else right.float;
            if (exactI64(float_value)) |converted| {
                const a = if (left == .integer) left.integer else converted;
                const b = if (right == .integer) right.integer else converted;
                return applyIntegerBinary(op, a, b);
            }
        }
        const a = asFloat(left);
        const b = asFloat(right);
        return switch (op) {
            .add => .{ .float = a + b },
            .subtract => .{ .float = a - b },
            .multiply => .{ .float = a * b },
            .modulo => if (b == 0) null else .{ .float = @rem(a, b) },
            else => null,
        };
    }
    return null;
}

fn applyIntegerBinary(op: ir.Operator, a: i64, b: i64) ?Value {
    return switch (op) {
        .add => .{ .integer = std.math.add(i64, a, b) catch return null },
        .subtract => .{ .integer = std.math.sub(i64, a, b) catch return null },
        .multiply => .{ .integer = std.math.mul(i64, a, b) catch return null },
        .modulo => if (b == 0 or
            (a == std.math.minInt(i64) and b == -1)) null else .{ .integer = @rem(a, b) },
        else => null,
    };
}

fn numericCompare(left: Value, right: Value) ?std.math.Order {
    if (left == .integer and right == .integer)
        return std.math.order(left.integer, right.integer);
    if (left == .float and right == .float) {
        if (std.math.isNan(left.float) or std.math.isNan(right.float)) return null;
        return std.math.order(left.float, right.float);
    }
    if (left == .integer or right == .integer) {
        const float_value = if (left == .float) left.float else right.float;
        if (exactI64(float_value)) |converted| {
            const a = if (left == .integer) left.integer else converted;
            const b = if (right == .integer) right.integer else converted;
            return std.math.order(a, b);
        }
    }
    const a = asFloat(left);
    const b = asFloat(right);
    if (std.math.isNan(a) or std.math.isNan(b)) return null;
    return std.math.order(a, b);
}

fn exactI64(value: f64) ?i64 {
    if (!std.math.isFinite(value) or @trunc(value) != value or
        value < -9223372036854775808.0 or value >= 9223372036854775808.0)
        return null;
    return @intFromFloat(value);
}

fn asFloat(value: Value) f64 {
    return switch (value) {
        .integer => |integer| @floatFromInt(integer),
        .float => |number| number,
        else => unreachable,
    };
}

fn writeEscaped(
    writer: *std.Io.Writer,
    value: []const u8,
    context: ir.EscapeContext,
    format: core.OutputFormat,
) anyerror!void {
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
