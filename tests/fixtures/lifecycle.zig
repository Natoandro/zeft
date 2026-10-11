//! Named scenario registrations for the lifecycle suite.
pub const harness_ids = [_][]const u8{
    "LC-001/source-and-options-ownership",
    "LC-002/static-writer-error",
    "LC-003/dynamic-writer-error-scratch",
    "LC-004/include-writer-error-scratch",
    "LC-005/callback-error-scratch",
    "LC-006/diagnostic-error-scratch",
    "LC-007/overlapping-compiled-renders",
    "LC-008/active-child-eviction-and-reload",
    "LC-009/byte-array-context-storage",
};

pub const lifecycle = .{
    .array = .{ .output = "byte" },
    .array_nested = .{ .template = "{{ record.bytes }}" },
    .array_root = .{ .template = "{{ bytes }}" },
    .callback_error = .{ .template = "{{ value | fail }}" },
    .child = .{ .template = "{{ value | copy }}" },
    .concurrent = .{ .template = "{#if show}{#for item in items}{{ hold(item) }}{/for}{:else}{{ hold(fallback) }}{/if}" },
    .concurrent_first = .{ .output = "AB" },
    .concurrent_second = .{ .output = "other" },
    .diagnostic = .{ .template = "{{ value | copy }}{{ absent }}" },
    .dynamic = .{ .template = "{{ value | copy }}" },
    .held_child = .{ .template = "old:{{ hold(value) }}", .output = "Aold:valueZ" },
    .new_child = .{ .template = "new:{{ value }}", .output = "Anew:valueZ" },
    .ownership = .{ .template = "<root><item>{{ value }}</item></root>", .output = "<root>\n\t<item>&lt;owned&gt;</item>\n</root>\n" },
    .parent = .{ .template = "A{% include \"child\" %}Z" },
    .static = .{ .template = "static output" },
};
