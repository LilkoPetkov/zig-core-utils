const z_env = @import("z_env");
const std = @import("std");
const print = std.debug.print;
const cli = @import("cli");
const log = std.log;
const Allocator = std.mem.Allocator;

pub var config = struct {
    all_vars: bool = false,
    variable: []const u8 = "PATH",
}{};

pub fn main() !void {
    var r = try cli.AppRunner.init(std.heap.page_allocator);

    const app = cli.App{
        .command = cli.Command{
            .name = "rm",
            .options = try r.allocOptions(&.{
                .{
                    .short_alias = 's',
                    .long_name = "single_var",
                    .help = "fetch single environment variables",
                    .required = false,
                    .value_ref = r.mkRef(&config.variable),
                },
                .{
                    .short_alias = 'a',
                    .long_name = "all",
                    .help = "fetch all environment variables",
                    .required = false,
                    .value_ref = r.mkRef(&config.all_vars),
                },
            }),
            .target = cli.CommandTarget{
                .action = cli.CommandAction{ .exec = processCommand },
            },
        },
    };
    return r.run(&app);
}

pub fn processCommand() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    if (config.all_vars) {
        try fetchAllEnvVars(allocator);
    } else {
        try fetchSingleVar(allocator, config.variable);
    }
}

fn fetchAllEnvVars(allocator: Allocator) !void {
    var env_vars = try std.process.getEnvMap(allocator);
    defer env_vars.deinit();
    var it = env_vars.iterator();
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    while (it.next()) |entry| {
        try stdout.print("{s}={s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        try stdout.flush();
    }
}

fn fetchSingleVar(allocator: Allocator, var_name: []const u8) !void {
    const path_var = std.process.getEnvVarOwned(allocator, var_name) catch |err| {
        log.err("'{s}' not found on the system: {}", .{ var_name, err });
        return;
    };
    defer allocator.free(path_var);

    print("{s}={s}", .{ var_name, path_var });
}
