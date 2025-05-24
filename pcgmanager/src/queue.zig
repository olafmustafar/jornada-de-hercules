const std = @import("std");

pub fn Queue(comptime Child: type) type {
    return struct {
        const Self = @This();
        const Node = struct {
            data: Child,
            next: ?*Node,
        };
        gpa: std.mem.Allocator,
        start: ?*Node,
        end: ?*Node,

        pub fn init(gpa: std.mem.Allocator) Self {
            return Self{
                .gpa = gpa,
                .start = null,
                .end = null,
            };
        }

        pub fn deinit(self: *Self) void{
            while (self.dequeue()) |_| {}
            self = undefined;
        }

        pub fn enqueue(self: *Self, value: Child) !void {
            const node = try self.gpa.create(Node);
            node.* = .{ .data = value, .next = null };
            if (self.end) |end| end.next = node //
            else self.start = node;
            self.end = node;
        }
        pub fn dequeue(self: *Self) ?Child {
            const start = self.start orelse return null;
            defer self.gpa.destroy(start);
            if (start.next) |next|
                self.start = next
            else {
                self.start = null;
                self.end = null;
            }
            return start.data;
        }

        pub fn last(self: *Self) ?Child {
            const start = self.start orelse return null;
            return start.data;
        }

    };
}
