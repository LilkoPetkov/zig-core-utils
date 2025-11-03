const std = @import("std");
const log = std.log;
const cli = @import("cli");
const zig_rm = @import("zig_rm");
const Allocator = std.mem.Allocator;

pub var config = struct {
    file: []const u8 = undefined,
    directory: []const u8 = undefined,
    empty_directory: []const u8 = undefined,
    recursive: bool = false,
}{};

pub fn main() !void {
    var r = try cli.AppRunner.init(std.heap.page_allocator);

    const app = cli.App{
        .command = cli.Command{
            .name = "rm",
            .options = try r.allocOptions(&.{
                .{
                    .short_alias = 'f',
                    .long_name = "file_path",
                    .help = "path to file",
                    .required = false,
                    .value_ref = r.mkRef(&config.file),
                },
                .{
                    .short_alias = 'r',
                    .long_name = "directory_path",
                    .help = "path to directory",
                    .required = false,
                    .value_ref = r.mkRef(&config.directory),
                },
                .{
                    .short_alias = 'd',
                    .long_name = "empty_directory_path",
                    .help = "path to empty directory",
                    .required = false,
                    .value_ref = r.mkRef(&config.empty_directory),
                },
            }),
            .target = cli.CommandTarget{
                .action = cli.CommandAction{ .exec = rm },
            },
        },
    };
    return r.run(&app);
}

fn rm() !void {
    try remove(config.file);
}

fn remove(file_path: []const u8) !void {
    handle_args();

    if (config.file.len > 0) {
        glob_check();
        std.fs.deleteFileAbsolute(file_path) catch |err| {
            log.err("rm: cannot remove '{s}': {s})", .{ file_path, @errorName(err) });
            std.process.exit(1);
        };
    } else {
        const dir_path = if (config.directory.len > 0) config.directory else config.empty_directory;
        std.fs.Dir.access(std.fs.cwd(), dir_path, .{}) catch |err| {
            log.err("rm: cannot access '{s}': {s}", .{ dir_path, @errorName(err) });
            std.process.exit(1);
        };

        if (config.directory.len > 0) {
            std.fs.Dir.deleteTree(std.fs.cwd(), config.directory) catch |err| {
                log.err("rm: cannot remove directory '{s}': {s}", .{ config.directory, @errorName(err) });
                std.process.exit(1);
            };
        } else if (config.empty_directory.len > 0) {
            std.fs.Dir.deleteDir(std.fs.cwd(), config.empty_directory) catch |err| {
                log.err("rm: cannot remove empty directory '{s}': {s}", .{ config.empty_directory, @errorName(err) });
                std.process.exit(1);
            };
        }
    }
}

fn handle_args() void {
    var non_empty: u2 = 0;
    if (config.directory.len > 0) non_empty += 1;
    if (config.file.len > 0) non_empty += 1;
    if (config.empty_directory.len > 0) non_empty += 1;

    if (non_empty == 0) {
        log.err("rm: missing operand", .{});
        std.process.exit(1);
    }

    if (non_empty > 1) {
        log.err("rm: error: The options '--file_path', '--directory_path', and '--empty_directory_path' are mutually exclusive.", .{});
        std.process.exit(1);
    }
}

fn glob_check() void {
    // var has_wildcard = false;

    for (config.file) |char| {
        std.debug.print("{c}", .{char});
    }
}
