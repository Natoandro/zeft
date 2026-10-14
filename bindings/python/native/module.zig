const std = @import("std");
const zeft = @import("zeft");

const NativeTemplate = struct {
    template: zeft.CompiledTemplate,
};

/// Compiles source and returns an opaque owner handle to the CPython shim.
/// A return value of 1 means a compile diagnostic; -1 means allocation failure.
export fn zeft_template_compile(
    source: [*]const u8,
    source_len: usize,
    out_template: *?*NativeTemplate,
) c_int {
    const owner = std.heap.c_allocator.create(NativeTemplate) catch return -1;
    const result = zeft.compile(
        std.heap.c_allocator,
        source[0..source_len],
        .{},
    ) catch {
        std.heap.c_allocator.destroy(owner);
        return -1;
    };
    switch (result) {
        .success => |template| {
            owner.* = .{ .template = template };
            out_template.* = owner;
            return 0;
        },
        .failure => {
            std.heap.c_allocator.destroy(owner);
            return 1;
        },
    }
}

export fn zeft_template_release(raw: ?*NativeTemplate) void {
    const owner = raw orelse return;
    owner.template.deinit();
    std.heap.c_allocator.destroy(owner);
}
