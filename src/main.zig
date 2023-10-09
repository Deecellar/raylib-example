const std = @import("std");

const raylib = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");
    @cInclude("raygui.h");
});

pub fn main() !void {
    raylib.InitWindow(800, 450, "raylib [core] example - basic window");

    raylib.SetTargetFPS(60);

    while (!raylib.WindowShouldClose()) {
        raylib.BeginDrawing();

        raylib.ClearBackground(raylib.RAYWHITE);

        // raygui button drawing
        if (raylib.GuiButton(raylib.Rectangle{ .height = 350, .width = 200, .x = 100, .y = 40 }, "PRESS ME") > 0) {
            try std.io.getStdOut().writeAll("Button pressed!\n");
        }
        raylib.EndDrawing();
    }

    raylib.CloseWindow();
}
