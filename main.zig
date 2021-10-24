const std = @import("std");
const zt = @import("zt");
const ig = @import("imgui");
const zg = zt.custom_components;

const SampleData = struct {
    counter: i32,
    slice: []const u64,
    text: []const u8,
    ptr: *const usize,
};

pub fn main() !void {
    run(SampleData{
        .counter = 0,
        .slice = &.{ 1, 2, 3 },
        .text = "foo",
        .ptr = &@as(usize, 1),
    });
}

pub fn run(data: anytype) void {
    const Context = zt.App(@TypeOf(data));

    var context = Context.begin(std.heap.c_allocator, data);

    context.settings.energySaving = false;

    while (context.open) {
        context.beginFrame();
        const viewport = ig.igGetMainViewport();
        ig.igSetNextWindowPos(viewport.*.Pos, 0, .{});
        ig.igSetNextWindowSize(viewport.*.Size, 0);
        var open = true;
        if (ig.igBegin(
            "The window",
            &open,
            ig.ImGuiWindowFlags_NoDecoration |
                ig.ImGuiWindowFlags_NoBackground |
                ig.ImGuiWindowFlags_AlwaysAutoResize |
                ig.ImGuiWindowFlags_NoSavedSettings |
                ig.ImGuiWindowFlags_NoFocusOnAppearing |
                ig.ImGuiWindowFlags_NoNav,
        )) {
            inspect(std.heap.c_allocator, "root", context.data);
            context.data.counter += 1;
        }
        ig.igEnd();
        context.endFrame();

        // Hacky way to check if stderr was closed
        const stderr = std.io.getStdErr().writer();
        stderr.print("Still alive!\n", .{}) catch return;
    }
    context.deinit();
}

fn inspect(allocator: *std.mem.Allocator, name: []const u8, thing: anytype) void {
    const T = @TypeOf(thing);
    if (treeNodeFmt("{s}: {s} = ", .{ name, @typeName(T) })) {
        switch (@typeInfo(T)) {
            .Int => zg.ztText("{d} 0o{o} 0b{b}", .{ thing, thing, thing }),
            .Struct => |info| {
                inline for (info.fields) |field_info| {
                    inspect(allocator, field_info.name, @field(thing, field_info.name));
                }
            },
            .Pointer => |info| {
                switch (info.size) {
                    .One => inspect(allocator, "*", thing.*),
                    .Many => zg.ztText("{any}", .{thing}),
                    .Slice => for (thing) |elem, i| {
                        inspect(allocator, zg.fmtTextForImgui("{}", .{i}), elem);
                    },
                    .C => zg.ztText("{any}", .{thing}),
                }
            },
            else => zg.ztText("{any}", .{thing}),
        }
        ig.igTreePop();
    } else {
        ig.igSameLine(0, 0);
        if (@typeInfo(T) == .Pointer and
            @typeInfo(T).Pointer.size == .Slice and
            @typeInfo(T).Pointer.child == u8)
            zg.ztText("{s}", .{thing})
        else
            zg.ztText("{any}", .{thing});
    }
}

fn treeNodeFmt(comptime fmt: []const u8, args: anytype) bool {
    const text = zg.fmtTextForImgui(fmt, args);
    return ig.igTreeNode_Str(text);
}
