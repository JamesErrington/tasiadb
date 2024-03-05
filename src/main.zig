const std = @import("std");
const tdb = @import("./lib.zig");

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    var memtable = tdb.MemTable.init(allocator);

    try memtable.set("name", "James Errington");
    try memtable.set("country", "United Kingdom");

    std.debug.print("Hello {?s}!\n", .{memtable.get("name")});

    var iter = memtable.entries.iterator();
    while (iter.next()) |node| {
        std.debug.print("{s}: {s}\n", .{node.key, node.value});
    }
}
