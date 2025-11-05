const z_env = @import("z_env");
const builtin = @import("builtin");
const tag = builtin.target.os.tag;
const std = @import("std");
const print = std.debug.print;
const cli = @import("cli");
const log = std.log;
const c = @cImport(@cInclude("stdlib.h"));
const Allocator = std.mem.Allocator;

/// Holds the configuration for the CLI application, parsed from command-line arguments.
///
/// Fields:
///   - variable: The name of the environment variable to fetch.
///   - set_var: A string containing one or more environment variables to set, in "KEY=VALUE" format.
///   - keys_to_unset: A string containing one or more environment variable keys to unset.
///   - all_vars: A flag indicating whether to fetch all environment variables.
///   - ignore_env: A flag indicating whether to start with an empty environment.
pub var config = struct {
    variable: []const u8 = "",
    set_var: []const u8 = "",
    keys_to_unset: []const u8 = "",
    all_vars: bool = false,
    ignore_env: bool = false,
}{};

/// Defines custom errors for the application.
///
/// Errors:
///   - MissingEqualsError: Returned when setting a variable without the "KEY=VALUE" format.
///   - MutuallyExclusiveParameterError: Returned when conflicting command-line parameters are used.
const errors = error{
    MissingEqualsError,
    MutuallyExclusiveParameterError,
};

/// The main entry point of the application.
/// It initializes the command-line interface, defines the available commands and options,
/// and runs the application logic based on the user's input.
pub fn main() !void {
    var r = try cli.AppRunner.init(std.heap.page_allocator);

    const app = cli.App{
        .command = cli.Command{
            .name = "env",
            .options = try r.allocOptions(&.{
                .{
                    .short_alias = 'f',
                    .long_name = "fetch",
                    .help = "fetch single environment variables\n./z-env -f PATH",
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
                .{
                    .short_alias = 's',
                    .long_name = "set",
                    .help = "set environment variable for the current process",
                    .required = false,
                    .value_ref = r.mkRef(&config.set_var),
                },
                .{
                    .short_alias = 'u',
                    .long_name = "unset",
                    .help = "unset environment variable for the current process",
                    .required = false,
                    .value_ref = r.mkRef(&config.keys_to_unset),
                },
                .{
                    .short_alias = 'i',
                    .long_name = "ignore-environment",
                    .help = "start with a new, empty environment, used for setting variables and fetching all vars",
                    .required = false,
                    .value_ref = r.mkRef(&config.ignore_env),
                },
            }),
            .target = cli.CommandTarget{
                .action = cli.CommandAction{ .exec = processCommand },
            },
        },
    };
    return r.run(&app);
}

/// Validates the command-line arguments to ensure that mutually exclusive parameters are not used together.
///
/// This function checks for the following invalid combinations:
///   - Using `-f`/`--fetch` and `-a`/`--all` at the same time.
///   - Using `-f`/`--fetch` and `-i`/`--ignore-environment` at the same time.
///   - Using `-s`/`--set` or `-u`/`--unset` with `-a`/`--all` or `-f`/`--fetch`.
///
/// If an invalid combination is found, it prints an error message and returns a `MutuallyExclusiveParameterError`.
fn commandValidations() !void {
    if (config.variable.len > 0 and config.all_vars) {
        print("-f/--fetch and -a/--all are mutually exclusive\n", .{});
        return errors.MutuallyExclusiveParameterError;
    }
    if (config.ignore_env and config.variable.len > 0) {
        print("-f/--fetch and -i/--ignore-environment are mutually exclusive\n", .{});
        return errors.MutuallyExclusiveParameterError;
    }
    if ((!std.mem.eql(u8, config.set_var, "") or !std.mem.eql(u8, config.keys_to_unset, "")) and (config.all_vars or config.variable.len > 0)) {
        print("-s/--set and -u/--unset are mutually exclusive with -a/--a and -f/--fetch\n", .{});
        return errors.MutuallyExclusiveParameterError;
    }
}

/// Processes the command based on the parsed CLI configuration.
/// This function acts as a dispatcher, deciding whether to fetch all environment variables
/// or a single one based on the user-provided flags.
pub fn processCommand() !void {
    try commandValidations();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    if (config.variable.len == 0) {
        try fetchAllEnvVars(allocator, stdout);
    } else {
        try fetchSingleVar(allocator, config.variable, stdout);
    }
}

/// Fetches and prints all environment variables to standard output.
/// Before fetching, it checks if any variables need to be set or unset and performs
/// those actions first.
///
/// Parameters:
///   - allocator: An allocator for memory management.
fn fetchAllEnvVars(allocator: Allocator, stdout: *std.Io.Writer) !void {
    if (config.ignore_env) {
        ignoreCurrentEnv();
    }
    if (!std.mem.eql(u8, config.set_var, "")) {
        try setVar(allocator);
    } else if (!std.mem.eql(u8, config.keys_to_unset, "")) {
        try unsetVar(allocator);
    }

    var env_vars = try std.process.getEnvMap(allocator);
    defer env_vars.deinit();

    if (env_vars.count() == 0) {
        return;
    }

    var it = env_vars.iterator();

    while (it.next()) |entry| {
        try stdout.print("{s}={s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        try stdout.flush();
    }
}

/// Fetches and prints a single environment variable.
/// If the variable is not found, an error is logged.
///
/// Parameters:
///   - allocator: An allocator for memory management.
///   - var_name: The name of the environment variable to fetch.
fn fetchSingleVar(allocator: Allocator, var_name: []const u8, stdout: *std.Io.Writer) !void {
    const path_var = std.process.getEnvVarOwned(allocator, var_name) catch |err| {
        log.err("'{s}' not found on the system: {}", .{ var_name, err });
        return;
    };
    defer allocator.free(path_var);

    try stdout.print("{s}", .{path_var});
    try stdout.flush();
}

/// Sets one or more environment variables.
/// It parses the input string, which is expected to be in the format "KEY=VALUE".
/// Multiple variables can be set if they are provided in the input string, separated by spaces.
///
/// Parameters:
///   - allocator: An allocator for memory management.
fn setVar(allocator: Allocator) !void {
    var found_equal_sign: bool = false;
    var key: []const u8 = undefined;
    var value: []const u8 = undefined;

    const entries = processInput(config.set_var);

    for (entries) |entry| {
        found_equal_sign = false;
        for (entry, 0..) |symbol, idx| {
            if (symbol == 61) {
                key = entry[0..idx];
                value = entry[idx + 1 ..];

                var key_buf = try allocator.alloc(u8, key.len + 1);
                @memcpy(key_buf[0..key.len], key);
                key_buf[key.len] = 0;

                var val_buf = try allocator.alloc(u8, value.len + 1);
                @memcpy(val_buf, value);
                val_buf[value.len] = 0;

                const key_c: [:0]const u8 = key_buf[0.. :0];
                const val_c: [:0]const u8 = val_buf[0.. :0];

                _ = c.setenv(key_c, val_c, 1);

                allocator.free(key_buf);
                allocator.free(val_buf);

                found_equal_sign = true;
            }
        }
    }

    if (!found_equal_sign) return errors.MissingEqualsError;
}

/// Unsets one or more environment variables.
/// It takes a space-separated string of keys to be removed from the environment.
///
/// Parameters:
///   - allocator: An allocator for memory management.
fn unsetVar(allocator: Allocator) !void {
    const entries = processInput(config.keys_to_unset);

    for (entries) |entry| {
        var entry_buf = try allocator.alloc(u8, entry.len + 1);
        @memcpy(entry_buf, entry);
        entry_buf[entry.len] = 0;

        const entry_c: [:0]const u8 = entry_buf[0.. :0];

        _ = c.unsetenv(entry_c);
        allocator.free(entry_buf);
    }
}

/// A helper function to process a space-separated input string into a slice of strings.
/// This is used to parse multiple arguments for setting or unsetting variables.
///
/// Parameters:
///   - input: The raw input string to be processed.
///
/// Returns:
///   A slice of byte slices, where each inner slice is a single entry from the input.
fn processInput(input: []const u8) [][]u8 {
    var buf: [256][512]u8 = undefined;
    var entries: [256][]u8 = undefined;
    var last_found_idx: u16 = 0;

    var i: usize = 0;
    var start: usize = 0;

    while (i <= input.len) : (i += 1) {
        const char = if (i < input.len) input[i] else ' ';
        if (char == ' ' or i == input.len) {
            if (i > start) {
                const len = i - start;
                if (last_found_idx >= buf.len) break;
                if (len > buf[last_found_idx].len) break;

                @memcpy(buf[last_found_idx][0..len], input[start..i]);
                entries[last_found_idx] = buf[last_found_idx][0..len];
                last_found_idx += 1;
            }
            start = i + 1;
        }
    }

    return entries[0..last_found_idx];
}

/// Clears all environment variables for the current process.
/// This function is a wrapper around the `clearenv` C function and is used
/// when the `--ignore-environment` flag is provided.
fn ignoreCurrentEnv() void {
    _ = c.clearenv();
}
