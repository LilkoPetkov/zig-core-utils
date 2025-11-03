const std = @import("std");
const cli = @import("cli");
const print = std.debug.print;
const cat_zig = @import("cat_zig");
const rf = @import("read_file.zig");
const cf = @import("config.zig");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var r = try cli.AppRunner.init(std.heap.page_allocator);

    const app = cli.App{
        .command = cli.Command{
            .name = "cat",
            .options = try r.allocOptions(&.{
                .{
                    .short_alias = 'f',
                    .long_name = "file_path",
                    .help = "path to file",
                    .required = false,
                    .value_ref = r.mkRef(&cf.config.file),
                },

                .{
                    .short_alias = 'n',
                    .long_name = "num_line",
                    .help = "show line numbers",
                    .value_ref = r.mkRef(&cf.config.line_number),
                },
                .{
                    .short_alias = 'e',
                    .long_name = "show_ends",
                    .help = "show '$' at the end of lines",
                    .value_ref = r.mkRef(&cf.config.show_ends),
                },
                .{
                    .short_alias = 'b',
                    .long_name = "number_nonblank",
                    .help = "number nonempty output lines",
                    .value_ref = r.mkRef(&cf.config.number_nonblank),
                },
            }),
            .target = cli.CommandTarget{
                .action = cli.CommandAction{ .exec = rf.readFile },
            },
        },
    };
    return r.run(&app);
}
