const std = @import("std");
const RBTree = @import("./rbtree.zig");

const Allocator = std.mem.Allocator;
const ByteList = std.ArrayListUnmanaged(u8);
const Crc32 = std.hash.Crc32;
const Dir = std.fs.Dir;
const File = std.fs.File;
const assert = std.debug.assert;

const K = []const u8;
const V = []const u8;

pub const DB = struct {
	const MEMTABLE_THRESHOLD_BYTES = 1024;

	dir: Dir,
	memtable: MemTable,
	wal_writer: WAL.Writer,

	pub fn open(allocator: Allocator, dirname: []const u8) !DB {
		const cwd = std.fs.cwd();

		try cwd.makePath(dirname);
		const dir = try cwd.openDir(dirname, .{ .iterate = true });

		return .{
			.dir = dir,
			.memtable = MemTable.init(allocator),
			.wal_writer = try WAL.Writer.init(allocator, dir),
		};
	}

	pub fn close(self: *DB) void {
		self.memtable.deinit();
		self.wal_writer.deinit();
		self.dir.close();
	}

	pub fn insert(self: *DB, key: K, value: V) !void {
		try self.wal_writer.log_set(key, value);
		try self.wal_writer.log_commit();
		try self.memtable.set(key, value);

		if (self.memtable.size_bytes >= MEMTABLE_THRESHOLD_BYTES) {
			std.debug.print("Time to flush memtable\n", .{});
		}
	}
};


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

    pub fn deinit(self: *MemTable) void {
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
    const MAX_KEY_LEN = std.math.maxInt(u32);
    const MAX_VAL_LEN = std.math.maxInt(u32);

    pub const LogType = enum(u8) {
    	Update,
     	Commit,
    };

    const LOG_HEADER_SIZE = @sizeOf(LogType) + @sizeOf(u32) + @sizeOf(u32);

    pub const Writer = struct {
        file: File,
        allocator: Allocator,
        buffer: ByteList,
        crc32: Crc32,

        pub fn init(allocator: Allocator, dir: Dir) !Writer {
            const file = try dir.createFile("wal.log", .{ .read = false, .truncate = false });

            return .{
                .file = file,
                .allocator = allocator,
                .buffer = ByteList{},
                .crc32 = Crc32.init(),
            };
        }

        pub fn deinit(self: *Writer) void {
	        self.file.close();
            self.buffer.deinit(self.allocator);
        }

        pub fn log_set(self: *Writer, key: K, value: V) Allocator.Error!void {
            assert(key.len > 0 and key.len < MAX_KEY_LEN);
            assert(value.len < MAX_VAL_LEN);
            const log_size = LOG_HEADER_SIZE + key.len + value.len;

            try self.buffer.ensureTotalCapacity(self.allocator, self.buffer.capacity + log_size);
            self.buffer.appendAssumeCapacity(@intFromEnum(LogType.Update));

            const key_len_bytes = std.mem.asBytes(&(@as(u32, @intCast(key.len))));
            self.buffer.appendSliceAssumeCapacity(key_len_bytes);
            const value_len_bytes = std.mem.asBytes(&(@as(u32, @intCast(value.len))));
            self.buffer.appendSliceAssumeCapacity(value_len_bytes);

            self.buffer.appendSliceAssumeCapacity(key);
            self.crc32.update(key);
            self.buffer.appendSliceAssumeCapacity(value);
            self.crc32.update(value);
        }

        pub fn log_commit(self: *Writer) !void {
	       	const checksum = self.crc32.final();
	       	const log_size = LOG_HEADER_SIZE;

	       	try self.buffer.ensureTotalCapacity(self.allocator, self.buffer.capacity + log_size);
	        self.buffer.appendAssumeCapacity(@intFromEnum(LogType.Commit));

	        const checksum_bytes = std.mem.asBytes(&(@as(u32, checksum)));
	        self.buffer.appendSliceAssumeCapacity(checksum_bytes);

			const padding_bytes = [_]u8{0} ** 4;
			self.buffer.appendSliceAssumeCapacity(&padding_bytes);

	        const written = try std.os.pwrite(self.file.handle, self.buffer.items, 0);
	        if (written != self.buffer.items.len) {
		        return error.IncompleteWrite;
	        }

			self.buffer.clearRetainingCapacity();
			self.crc32 = Crc32.init();
        }
    };

    pub const Reader = struct {
	   	file: File,
		allocator: Allocator,

		pub fn init(allocator: Allocator, dir: Dir) !Reader {
			const file = try dir.openFile("wal.log", .{ .mode = .read_only });

			return .{
				.file = file,
				.allocator = allocator,
			};
		}

		pub fn deinit(self: Reader) void {
			self.file.close();
		}

		pub fn process_log(self: Reader) !void {
			var crc32 = Crc32.init();

			var index: usize = 0;
			while (true) {
				var header = [_]u8{0} ** LOG_HEADER_SIZE;
				const header_read = try std.os.pread(self.file.handle, &header, index);
				if (header_read != LOG_HEADER_SIZE) {
					return;
				}
				index += LOG_HEADER_SIZE;

				const log_type: LogType = @enumFromInt(header[0]);
				switch (log_type) {
					.Update => {
						const key_len_bytes = header[1..5];
					    const key_len = std.mem.readVarInt(u32, key_len_bytes, .little);
						assert(key_len > 0 and key_len < MAX_KEY_LEN);

						const value_len_bytes = header[5..9];
					    const value_len = std.mem.readVarInt(u32, value_len_bytes, .little);
						// TODO: handle 0 length value
						assert(value_len > 0 and value_len < MAX_VAL_LEN);

						const data_size = key_len + value_len;
						const buffer = try self.allocator.alloc(u8, data_size);
						defer self.allocator.free(buffer);

						const read = try std.os.pread(self.file.handle, buffer, index);
						if (read != data_size) {
							return error.IncompleteRead;
						}
						index += data_size;
						crc32.update(buffer);

						const key = buffer[0..key_len];
						const value = buffer[key_len..data_size];
						std.debug.print("{s}: {s}\n", .{key, value});
					},
					.Commit => {
						const checksum_bytes = header[1..5];
						index += 4;
						const checksum = std.mem.readVarInt(u32, checksum_bytes, .little);
						if (checksum != crc32.final()) {
							return error.IncorrectChecksum;
						}

						crc32 = Crc32.init();
					},
				}
			}
		}
    };
};
