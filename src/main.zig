const std = @import("std");
const tdb = @import("./lib.zig");

pub fn main() !void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	const allocator = gpa.allocator();
	defer _ = gpa.deinit();

	var db = try tdb.DB.open(allocator, "./data/test");
	defer db.close();
	try db.insert("country", "United Kingdom");


	const dir = try std.fs.cwd().openDir("./data/test", .{});
	var reader = try tdb.WAL.Reader.init(allocator, dir);
    defer reader.deinit();

    try reader.process_log();

    // var memtable = tdb.MemTable.init(allocator);
    // defer memtable.deinit();

    // try memtable.set("name", "James Errington");
    // try memtable.set("country", "United Kingdom");

    // std.debug.print("Hello {?s}!\n", .{memtable.get("name")});

    // var iter = memtable.entries.iterator();
    // while (iter.next()) |node| {
    //     std.debug.print("{s}: {s}\n", .{node.key, node.value});
    // }

    // var writer = try tdb.WAL.Writer.init(allocator);
    // defer writer.deinit();

    // try writer.log_set("name", "James Errington");
    // try writer.log_set("country", "United Kingdom");
    // try writer.log_set("city", "St Albans");
    // try writer.log_commit();

    // var reader = try tdb.WAL.Reader.init(allocator);
    // defer reader.deinit();

    // try reader.process_log();
}
