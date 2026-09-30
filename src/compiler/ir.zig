//! Initial Phase 1 expression and linear render intermediate representations.

const zeft = @import("zeft");
const analysis = @import("zeft_analysis");

pub const StringId = u32;
pub const ExpressionId = u32;

pub const EscapeMode = enum {
    html_text,
};

pub const ExpressionInstruction = struct {
    span: zeft.SourceSpan,
    data: Data,

    pub const Data = union(enum) {
        load_root_symbol: analysis.SymbolId,
        return_value,
    };
};

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
            escape_mode: EscapeMode,
        },
        end,
    };
};

pub const Program = struct {
    strings: [][]const u8,
    symbols: []analysis.Symbol,
    expressions: []ExpressionProgram,
    instructions: []Instruction,
};
