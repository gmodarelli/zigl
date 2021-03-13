const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var app: core.App = undefined;
    try app.init(1920, 1080);
    defer app.deinit();

    app.run();
}
