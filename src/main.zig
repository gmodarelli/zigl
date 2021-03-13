const std = @import("std");
const App = @import("core.zig").App;

pub fn main() !void {
    var app: App = undefined;
    try app.init(1920, 1080);
    defer app.deinit();

    app.run();
}
