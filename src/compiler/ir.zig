//! Expression and linear render intermediate representations.

const zeft = @import("zeft_core");
const analysis = @import("zeft_analysis");

pub const StringId = u32;
pub const ExpressionId = u32;
pub const Operator = enum { not, negate, or_, and_, equal, not_equal, less, less_equal, greater, greater_equal, add, subtract, multiply, divide, modulo };

pub const EscapeContext = enum {
    text,
    attribute,
};

pub const ExpressionInstruction = struct {
    span: zeft.SourceSpan,
    data: Data,

    pub const Data = union(enum) {
        load_root_symbol: analysis.SymbolId,
        load_local: u32,
        push_literal: Literal,
        get_property: []const u8,
        get_index: usize,
        get_index_dynamic,
        unary: Operator,
        binary: Operator,
        jump_if_false: u32,
        jump_if_true: u32,
        jump: u32,
        call_function: struct { name: []const u8, argument_count: u16 },
        call_filter: struct { name: []const u8, argument_count: u16 },
        return_value,
    };
};

pub const Literal = union(enum) { null, boolean: bool, number: f64, string: []const u8 };

pub const ExpressionProgram = struct {
    instructions: []ExpressionInstruction,
};

pub const Instruction = struct {
    span: zeft.SourceSpan,
    data: Data,

    pub const Data = union(enum) {
        write_static: StringId,
        write_expression: struct {
            expression_id: ExpressionId,
            escape_context: EscapeContext,
        },
        jump_if_false: struct { expression_id: ExpressionId, target: u32 },
        jump: u32,
        loop_begin: struct { expression_id: ExpressionId, slot: u32, exit_target: u32 },
        loop_next: struct { body_target: u32, exit_target: u32 },
        loop_break: u32,
        loop_continue: u32,
        include: struct { identity: StringId },
        end,
    };
};

pub const Program = struct {
    strings: [][]const u8,
    symbols: []analysis.Symbol,
    expressions: []ExpressionProgram,
    instructions: []Instruction,
};
