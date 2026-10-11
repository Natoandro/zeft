const runner = @import("fixture_runner.zig");
const whitespace_cases = @import("fixtures/whitespace.zig");
pub const Context = struct {
    name: []const u8 = "Ada",
    show: bool = true,
    items: []const []const u8 = &.{},
};
pub const Case = struct { fixture: runner.Success, context: Context };

test "named HTML and XML whitespace golden cases" {
    try runner.expectSuccessCases(whitespace_cases.success_cases);
}
