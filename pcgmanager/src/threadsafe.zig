const std = @import("std");

pub fn ThreadSafe(comptime T: type) type {
    return struct {
        const Self = @This();

        data: T,
        mutex: std.Thread.Mutex,
        cv: std.Thread.Condition,

        pub fn init(data: T) Self {
            return .{ .data = data, .mutex = .{}, .cv = .{} };
        }

        pub fn set(self: *Self, data: T) void {
            {
                self.mutex.lock();
                defer self.mutex.unlock();
                self.data = data;
            }
            self.cv.signal();
        }

        pub fn get(self: *Self) T {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.data;
        }

        pub fn wait_until(self: *Self, data: T) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            while (self.data != data) {
                self.cv.wait(&self.mutex);
            }
        }
    };
}
