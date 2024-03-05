const std = @import("std");

const Tree = @This();
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const K = []const u8;
const V = []const u8;

const Color = enum(u1) {
    Red,
    Black,
};

const Node = struct {
    key: K,
    value: V,
    parent: ?*Node = null,
    left: ?*Node = null,
    right: ?*Node = null,
    color: Color = .Red,
};

root: ?*Node = null,

pub fn deinit(self: Tree, allocator: Allocator) void {
    deinit_subtree(self.root, allocator);
}

fn deinit_subtree(root: ?*const Node, allocator: Allocator) void {
    if (root) |node| {
        deinit_subtree(node.left, allocator);
        deinit_subtree(node.right, allocator);
        allocator.destroy(node);
    }
}

pub fn search(self: Tree, key: K) ?*const Node {
    return search_subtree(self.root, key);
}

fn search_subtree(root: ?*Node, key: K) ?*const Node {
    if (root) |node| {
        return switch (std.mem.order(u8, key, node.key)) {
            .lt => search_subtree(node.left, key),
            .gt => search_subtree(node.right, key),
            .eq => node,
        };
    }

    return null;
}

pub fn insert(self: *Tree, allocator: Allocator, key: K, value: V) Allocator.Error!void {
    var temp = Node{ .key = key, .value = value };

    const edge = find_empty_edge(&self.root, &temp);
    if (edge.* == &temp) {
        return;
    }

    const node = try allocator.create(Node);
    node.* = .{ .key = key, .value = value, .parent = temp.parent };
    edge.* = node;

    if (edge == &self.root) {
        assert(node.parent == null);
        node.color = .Black;
        return;
    }

    var curr = node;
    // Since every node except the root has a parent, if we passed the last check we must have a parent
    assert(curr.parent != null);
    while (curr.parent.?.color == .Red) {
        // Since the root is always Black we must have a grandparent
        assert(curr.parent.?.parent != null);

        if (curr.parent.? == curr.parent.?.parent.?.right) {
            const uncle = curr.parent.?.parent.?.left;

            if (uncle == null or uncle.?.color == .Black) {
                if (curr == curr.parent.?.left) {
                    curr = curr.parent.?;
                    self.rotate_right(curr);
                }
                curr.parent.?.color = .Black;
                curr.parent.?.parent.?.color = .Red;
                self.rotate_left(curr.parent.?.parent.?);
            } else {
                uncle.?.color = .Black;
                curr.parent.?.color = .Black;
                curr.parent.?.parent.?.color = .Red;
                curr = curr.parent.?.parent.?;
            }
        } else {
            const uncle = curr.parent.?.parent.?.right;

            if (uncle == null or uncle.?.color == .Black) {
                if (curr == curr.parent.?.right) {
                    curr = curr.parent.?;
                    self.rotate_left(curr);
                }
                curr.parent.?.color = .Black;
                curr.parent.?.parent.?.color = .Red;
                self.rotate_right(curr.parent.?.parent.?);
            } else {
                uncle.?.color = .Black;
                curr.parent.?.color = .Black;
                curr.parent.?.parent.?.color = .Red;
                curr = curr.parent.?.parent.?;
            }
        }

        if (curr == self.root) {
            break;
        }
        assert(curr.parent != null);
    }
    self.root.?.color = .Black;
}

fn rotate_left(self: *Tree, x: *Node) void {
    assert(x.right != null);
    const y = x.right.?;
    x.right = y.left;

    if (y.left != null) {
        y.left.?.parent = x;
    }

    y.parent = x.parent;
    if (x.parent == null) {
        assert(x == self.root);
        self.root = y;
    } else if (x == x.parent.?.left) {
        x.parent.?.left = y;
    } else {
        x.parent.?.right = y;
    }

    y.left = x;
    x.parent = y;
}

fn rotate_right(self: *Tree, x: *Node) void {
    assert(x.left != null);
    const y = x.left.?;
    x.left = y.right;

    if (y.right != null) {
        y.right.?.parent = x;
    }

    y.parent = x.parent;
    if (x.parent == null) {
        assert(x == self.root);
        self.root = y;
    } else if (x == x.parent.?.left) {
        x.parent.?.left = y;
    } else {
        x.parent.?.right = y;
    }

    y.right = x;
    x.parent = y;
}

fn find_empty_edge(root: *?*Node, node: *Node) *?*Node {
    var edge: *?*Node = root;

    if (root.*) |_| {
        var curr = root.*;
        while (curr) |curr_node| {
            node.parent = curr_node;
            switch (std.mem.order(u8, node.key, curr_node.key)) {
                .lt => {
                    edge = &(curr_node.left);
                    curr = curr_node.left;
                },
                .gt => {
                    edge = &(curr_node.right);
                    curr = curr_node.right;
                },
                .eq => {
                    curr_node.*.value = node.value;
                    return @ptrCast(@constCast(&node));
                },
            }
        }
    }

    return edge;
}

fn insert_into(root: ?*Node, node: *Node, allocator: Allocator) *Node {
    if (root) |rootnode| {
        node.parent = rootnode;
        switch (std.mem.order(u8, node.key, rootnode.key)) {
            .lt => rootnode.left = insert_into(rootnode.left, node, allocator),
            .gt => rootnode.right = insert_into(rootnode.right, node, allocator),
            .eq => {
                rootnode.value = node.value;
                allocator.destroy(node);
            }
        }

        return rootnode;
    }

    return node;
}

pub fn iterator(self: Tree) Iterator {
    return .{ .node = self.root, .started = false };
}

const Iterator = struct {
    node: ?*const Node,
    started: bool,

    pub fn next(self: *Iterator) ?*const Node {
        if (self.node) |node| {
            if (!self.started) {
                self.node = least_left(node);
            } else {
                if (node.right) |right| {
                    self.node = least_left(right);
                } else {
                    var parent = node.parent;
                    while (parent != null and self.node == parent.?.right) {
                        self.node = parent;
                        parent = parent.?.parent;
                    }
                    self.node = parent;
                }
            }
        }

        self.started = true;
        return self.node;
    }

    fn least_left(node: ?*const Node) ?*const Node {
        var curr = node;
        while (curr != null and curr.?.left != null) {
            curr = curr.?.left;
        }
        return curr;
    }
};

const t = std.testing;
test "Deinit" {
    var tree = Tree{};

    try tree.insert(t.allocator, "7", "seven");
    try tree.insert(t.allocator, "4", "four");
    try tree.insert(t.allocator, "5", "five");
    try tree.insert(t.allocator, "5", "cinq");

    tree.deinit(t.allocator);
}

test "Iterator" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var tree = Tree{};
    try tree.insert(allocator, "7", "");
    try tree.insert(allocator, "4", "");
    try tree.insert(allocator, "5", "");
    try tree.insert(allocator, "3", "");
    try tree.insert(allocator, "2", "");
    try tree.insert(allocator, "6", "");
    try tree.insert(allocator, "8", "");

    var iter = tree.iterator();
    try t.expect(std.mem.eql(u8, iter.next().?.key, "2"));
    try t.expect(std.mem.eql(u8, iter.next().?.key, "3"));
    try t.expect(std.mem.eql(u8, iter.next().?.key, "4"));
    try t.expect(std.mem.eql(u8, iter.next().?.key, "5"));
    try t.expect(std.mem.eql(u8, iter.next().?.key, "6"));
    try t.expect(std.mem.eql(u8, iter.next().?.key, "7"));
    try t.expect(std.mem.eql(u8, iter.next().?.key, "8"));
    try t.expect(iter.next() == null);
}

test "Search" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var tree = Tree{};
    try tree.insert(allocator, "7", "seven");
    try tree.insert(allocator, "4", "four");
    try tree.insert(allocator, "5", "five");

    try t.expect(std.mem.eql(u8, tree.search("7").?.value, "seven"));
    try t.expect(std.mem.eql(u8, tree.search("4").?.value, "four"));
    try t.expect(std.mem.eql(u8, tree.search("5").?.value, "five"));
    try t.expect(tree.search("8") == null);

}

test "Insert Duplicate" {
    var tree = Tree{};
    try tree.insert(t.allocator, "7", "seven");
    try t.expect(std.mem.eql(u8, tree.search("7").?.value, "seven"));

    try tree.insert(t.allocator, "7", "sept");
    try t.expect(std.mem.eql(u8, tree.search("7").?.value, "sept"));

    tree.deinit(t.allocator);
}

test "Red Black Insertion" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var tree = Tree{};
    try tree.insert(allocator, "h", "");
    try t.expect(std.mem.eql(u8, tree.root.?.key, "h"));
    try t.expect(tree.root.?.color == .Black);

    try tree.insert(allocator, "r", "");
    try t.expect(std.mem.eql(u8, tree.root.?.key, "h"));
    try t.expect(tree.root.?.color == .Black);
    try t.expect(std.mem.eql(u8, tree.root.?.right.?.key, "r"));
    try t.expect(tree.root.?.right.?.color == .Red);

    try tree.insert(allocator, "e", "");
    try t.expect(std.mem.eql(u8, tree.root.?.key, "h"));
    try t.expect(tree.root.?.color == .Black);
    try t.expect(std.mem.eql(u8, tree.root.?.right.?.key, "r"));
    try t.expect(tree.root.?.right.?.color == .Red);
    try t.expect(std.mem.eql(u8, tree.root.?.left.?.key, "e"));
    try t.expect(tree.root.?.left.?.color == .Red);

    try tree.insert(allocator, "o", "");
    try t.expect(std.mem.eql(u8, tree.root.?.key, "h"));
    try t.expect(tree.root.?.color == .Black);
    try t.expect(std.mem.eql(u8, tree.root.?.right.?.key, "r"));
    try t.expect(tree.root.?.right.?.color == .Black);
    try t.expect(std.mem.eql(u8, tree.root.?.left.?.key, "e"));
    try t.expect(tree.root.?.left.?.color == .Black);
    try t.expect(std.mem.eql(u8, tree.root.?.right.?.left.?.key, "o"));
    try t.expect(tree.root.?.right.?.left.?.color == .Red);

    try tree.insert(allocator, "q", "");
    try t.expect(std.mem.eql(u8, tree.root.?.key, "h"));
    try t.expect(tree.root.?.color == .Black);
    try t.expect(std.mem.eql(u8, tree.root.?.right.?.key, "q"));
    try t.expect(tree.root.?.right.?.color == .Black);
    try t.expect(std.mem.eql(u8, tree.root.?.left.?.key, "e"));
    try t.expect(tree.root.?.left.?.color == .Black);
    try t.expect(std.mem.eql(u8, tree.root.?.right.?.left.?.key, "o"));
    try t.expect(tree.root.?.right.?.left.?.color == .Red);
    try t.expect(std.mem.eql(u8, tree.root.?.right.?.right.?.key, "r"));
    try t.expect(tree.root.?.right.?.right.?.color == .Red);

    try tree.insert(allocator, "y", "");
    try t.expect(std.mem.eql(u8, tree.root.?.key, "h"));
    try t.expect(tree.root.?.color == .Black);
    try t.expect(std.mem.eql(u8, tree.root.?.right.?.key, "q"));
    try t.expect(tree.root.?.right.?.color == .Red);
    try t.expect(std.mem.eql(u8, tree.root.?.left.?.key, "e"));
    try t.expect(tree.root.?.left.?.color == .Black);
    try t.expect(std.mem.eql(u8, tree.root.?.right.?.left.?.key, "o"));
    try t.expect(tree.root.?.right.?.left.?.color == .Black);
    try t.expect(std.mem.eql(u8, tree.root.?.right.?.right.?.key, "r"));
    try t.expect(tree.root.?.right.?.right.?.color == .Black);
    try t.expect(std.mem.eql(u8, tree.root.?.right.?.right.?.right.?.key, "y"));
    try t.expect(tree.root.?.right.?.right.?.right.?.color == .Red);

    try tree.insert(allocator, "z", "");
    try t.expect(std.mem.eql(u8, tree.root.?.key, "h"));
    try t.expect(tree.root.?.color == .Black);
    try t.expect(std.mem.eql(u8, tree.root.?.right.?.key, "q"));
    try t.expect(tree.root.?.right.?.color == .Red);
    try t.expect(std.mem.eql(u8, tree.root.?.left.?.key, "e"));
    try t.expect(tree.root.?.left.?.color == .Black);
    try t.expect(std.mem.eql(u8, tree.root.?.right.?.left.?.key, "o"));
    try t.expect(tree.root.?.right.?.left.?.color == .Black);
    try t.expect(std.mem.eql(u8, tree.root.?.right.?.right.?.key, "y"));
    try t.expect(tree.root.?.right.?.right.?.color == .Black);
    try t.expect(std.mem.eql(u8, tree.root.?.right.?.right.?.right.?.key, "z"));
    try t.expect(tree.root.?.right.?.right.?.right.?.color == .Red);
    try t.expect(std.mem.eql(u8, tree.root.?.right.?.right.?.left.?.key, "r"));
    try t.expect(tree.root.?.right.?.right.?.left.?.color == .Red);
}
