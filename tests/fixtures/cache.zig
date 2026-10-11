//! Named scenario registrations for the cache suite.
pub const harness_ids = [_][]const u8{ "CA-001", "CA-002", "CA-003", "CA-004", "CA-005", "CA-006", "CA-007" };

pub const includes = .{
    .child = .{ .template = "<p>{{ value }}</p>" },
    .child_v2 = .{ .template = "<b>{{ value }}</b>" },
    .cycle_a = .{ .template = "A{% include \"b\" %}" },
    .cycle_b = .{ .template = "B{% include \"a\" %}" },
    .invalid = .{ .template = "<div/>" },
    .leaf = .{ .template = "<i>{{ value }}</i>" },
    .missing = .{ .template = "{% include \"absent\" %}" },
    .nested = .{ .template = "<section>{% include \"leaf\" %}</section>", .output = "<main><section><i>&lt;Ada&gt;</i></section>|<section><i>&lt;Ada&gt;</i></section></main>" },
    .options = .{ .template = "<root>\n <item>{{ value }}</item>\n</root>\n" },
    .options_compact = .{ .output = "<root><item>&lt;Ada&gt;</item></root>" },
    .options_preserve = .{ .output = "<root>\n <item>&lt;Ada&gt;</item>\n</root>\n" },
    .options_pretty = .{ .output = "<root>\n  <item>&lt;Ada&gt;</item>\n</root>\n" },
    .options_tab = .{ .output = "<root>\n\t<item>&lt;Ada&gt;</item>\n</root>\n" },
    .root = .{ .template = "<main>{% include \"child\" %}|{% include \"child\" %}</main>", .output = "<main><p>&lt;Ada&gt;</p>|<p>&lt;Ada&gt;</p></main>" },
    .root_child_v2 = .{ .output = "<main><b>&lt;Ada&gt;</b>|<b>&lt;Ada&gt;</b></main>" },
    .root_v2 = .{ .template = "<aside>{% include \"child\" %}</aside>", .output = "<aside><b>&lt;Ada&gt;</b></aside>" },
};
