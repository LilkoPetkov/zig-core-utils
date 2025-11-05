pub const packages = struct {
    pub const @"cli-0.10.0-2eKe_5kEAQBeHqKxUHNTGnETzu81rqKWwT1WPt1jXBt0" = struct {
        pub const build_root = "/home/lpetkov/.cache/zig/p/cli-0.10.0-2eKe_5kEAQBeHqKxUHNTGnETzu81rqKWwT1WPt1jXBt0";
        pub const build_zig = @import("cli-0.10.0-2eKe_5kEAQBeHqKxUHNTGnETzu81rqKWwT1WPt1jXBt0");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "cli", "cli-0.10.0-2eKe_5kEAQBeHqKxUHNTGnETzu81rqKWwT1WPt1jXBt0" },
};
