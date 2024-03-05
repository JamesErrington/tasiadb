const std = @import("std");
const RBTree = @import("./rbtree.zig");

const Allocator = std.mem.Allocator;

const K = []const u8;
const V = []const u8;

pub const MemTable = struct {
    arena: std.heap.ArenaAllocator,
    entries: RBTree,
    size_bytes: usize,

    pub fn init(allocator: Allocator) MemTable {
        return .{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .entries = RBTree{},
            .size_bytes = 0,
        };
    }

    pub fn deinit(self: MemTable) void {
        self.arena.deinit();
        self.entries = RBTree{};
    } 

    pub fn set(self: *MemTable, key: K, value: V) Allocator.Error!void {
        // This will be wrong when the same key changes value, but we can assert
        // true_size_bytes <= size_bytes
        self.size_bytes += key.len + value.len;
        try self.entries.insert(self.arena.allocator(), key, value);
    }

    pub fn get(self: MemTable, key: V) ?V {
        if (self.entries.search(key)) |node| {
            return node.value;
        }

        return null;
    }
};

pub const WAL = struct {
    pub const Entry = struct {
        key: K,
        value: V,
    };

    
};
