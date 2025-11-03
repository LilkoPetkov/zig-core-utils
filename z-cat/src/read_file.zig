const std = @import("std");
const os = std.os.linux;
const print = std.debug.print;
const cf = @import("config.zig");

pub fn readFile() !void {
    const file = try std.fs.cwd().openFile(cf.config.file, .{});
    defer file.close();

    const file_size = (try file.stat()).size;
    const data = try std.posix.mmap(
        null,
        file_size,
        std.posix.PROT.READ,
        .{ .TYPE = .SHARED },
        file.handle,
        0,
    );
    defer std.posix.munmap(data);

    // var ln: usize = 0;
    var iter = std.mem.splitScalar(u8, data, '\n');

    print("{any}", .{processFile(&iter)});
}

fn processFile(iter: *std.mem.SplitIterator(u8, .scalar)) !void {
    var ln: usize = 0;

    if (cf.config.show_ends and cf.config.line_number) {
        while (iter.next()) |line| {
            print("      {d}  {s}$\n", .{ ln, line });
            ln += 1;
        }
    } else if (cf.config.line_number) {
        while (iter.next()) |line| {
            print("      {d}  {s}\n", .{ ln, line });
            ln += 1;
        }
    } else if (cf.config.show_ends) {
        while (iter.next()) |line| {
            print("{s}$\n", .{line});
            ln += 1;
        }
    } else if (cf.config.number_nonblank) {
        while (iter.next()) |line| {
            if (line.len == 0) {
                continue;
            }

            print("      {d}  {s}\n", .{ ln, line });
            ln += 1;
        }
    } else {
        while (iter.next()) |line| {
            print("{s}\n", .{line});
        }
    }
}
