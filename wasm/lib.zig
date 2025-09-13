const std = @import("std");

// const quickjs = @import("quickjs");

const c = @import("c.zig").c;

extern fn print(ptr: [*]const u8, len: usize) void;

var log_buffer: [1024]u8 = undefined;
inline fn log(comptime fmt: []const u8, args: anytype) void {
    const msg = std.fmt.bufPrint(&log_buffer, fmt, args) catch |err|
        @panic(@errorName(err));
    print(msg.ptr, msg.len);
}

pub fn main() !void {
    log("OK wow", .{});
    c.foo(10);
}

const allocator = std.heap.wasm_allocator;

export fn alloc(len: usize) [*]u8 {
    const result = allocator.alloc(u8, len) catch |err| @panic(@errorName(err));
    return result.ptr;
}

const H = @max(8, @sizeOf(usize));

fn js_calloc(_: ?*anyopaque, count: usize, size: usize) callconv(.c) ?*anyopaque {
    const len = count * size;
    const result = allocator.alloc(u8, H + len) catch |err|
        @panic(@errorName(err));
    @memset(result, 0);
    std.mem.writeInt(usize, result[0..@sizeOf(usize)], len, .little);
    return result[H..].ptr;
}

fn js_malloc(_: ?*anyopaque, size: usize) callconv(.c) ?*anyopaque {
    const result = allocator.alloc(u8, H + size) catch |err|
        @panic(@errorName(err));
    std.mem.writeInt(usize, result[0..@sizeOf(usize)], size, .little);
    return result[H..].ptr;
}

fn js_free(_: ?*anyopaque, ptr: ?*anyopaque) callconv(.c) void {
    const result: [*]u8 = @ptrFromInt(@intFromPtr(ptr) - H);
    const len = std.mem.readInt(usize, result[0..@sizeOf(usize)], .little);
    allocator.free(result[0 .. H + len]);
}

fn js_realloc(_: ?*anyopaque, ptr: ?*anyopaque, new_len: usize) callconv(.c) ?*anyopaque {
    const old_ptr: [*]u8 = @ptrFromInt(@intFromPtr(ptr) - H);
    const old_len = std.mem.readInt(usize, old_ptr[0..@sizeOf(usize)], .little);
    const result = allocator.realloc(old_ptr[0 .. H + old_len], H + new_len) catch |err|
        @panic(@errorName(err));
    std.mem.writeInt(usize, result[0..@sizeOf(usize)], new_len, .little);
    return result[H..].ptr;
}

const malloc_functions = c.JSMallocFunctions{
    .js_calloc = &js_calloc,
    .js_malloc = &js_malloc,
    .js_free = &js_free,
    .js_realloc = &js_realloc,
    .js_malloc_usable_size = null,
};

export fn newRuntime() ?*c.JSRuntime {
    return c.JS_NewRuntime2(&malloc_functions, null);
}

export fn newContext(rt: *c.JSRuntime) ?*c.JSContext {
    return c.JS_NewContext(rt);
}

export const TAG_FIRST = c.JS_TAG_FIRST;
export const TAG_BIG_INT = c.JS_TAG_BIG_INT;
export const TAG_SYMBOL = c.JS_TAG_SYMBOL;
export const TAG_STRING = c.JS_TAG_STRING;
export const TAG_MODULE = c.JS_TAG_MODULE;
export const TAG_FUNCTION_BYTECODE = c.JS_TAG_FUNCTION_BYTECODE;
export const TAG_OBJECT = c.JS_TAG_OBJECT;
export const TAG_INT = c.JS_TAG_INT;
export const TAG_BOOL = c.JS_TAG_BOOL;
export const TAG_NULL = c.JS_TAG_NULL;
export const TAG_UNDEFINED = c.JS_TAG_UNDEFINED;
export const TAG_UNINITIALIZED = c.JS_TAG_UNINITIALIZED;
export const TAG_CATCH_OFFSET = c.JS_TAG_CATCH_OFFSET;
export const TAG_EXCEPTION = c.JS_TAG_EXCEPTION;
export const TAG_SHORT_BIG_INT = c.JS_TAG_SHORT_BIG_INT;
export const TAG_FLOAT64 = c.JS_TAG_FLOAT64;

export fn newBool(ctx: ?*c.JSContext, val: bool) c.JSValue {
    return c.JS_NewBool(ctx, val);
}

export fn newInt32(ctx: ?*c.JSContext, val: i32) c.JSValue {
    return c.JS_NewInt32(ctx, val);
}

export fn newFloat64(ctx: ?*c.JSContext, val: f64) c.JSValue {
    return c.JS_NewFloat64(ctx, val);
}

export fn newString(ctx: ?*c.JSContext, ptr: [*]const u8, len: usize) c.JSValue {
    return c.JS_NewStringLen(ctx, ptr, len);
}

export fn getTag(v: c.JSValue) i32 {
    return c.JS_VALUE_GET_TAG(v);
}

export fn getInt32(ctx: ?*c.JSContext, val: c.JSValue) i32 {
    var res: i32 = 0;
    return switch (c.JS_ToInt32(ctx, &res, val)) {
        -1 => 0,
        else => res,
    };
}

export fn getFloat64(ctx: ?*c.JSContext, val: c.JSValue) f64 {
    var res: f64 = 0;
    return switch (c.JS_ToFloat64(ctx, &res, val)) {
        -1 => std.math.nan(f64),
        else => res,
    };
}

const StringRef = u64;
export fn getStringRef(ctx: ?*c.JSContext, val: c.JSValue) StringRef {
    var len: usize = 0;
    const ptr = c.JS_ToCStringLen(ctx, &len, val);
    return (@as(u64, len) << 32) | @as(u64, @intFromPtr(ptr));
}

// export fn getInt32(ctx: ?*c.JSContext, val: c.JSValue) u64 {
//     var res: i32 = 0;
//     const ret = c.JS_ToInt32(ctx, &res, val);
//     var buf: [8]u8 = undefined;
//     std.mem.writeInt(i32, buf[0..4], res, .little);
//     std.mem.writeInt(i32, buf[4..8], ret, .little);
//     return std.mem.readInt(u64, &buf, .little);
// }

// export const JS_NewBool = c.JS_NewBool;

// export const freeRuntime = c.JS_FreeRuntime;
// export const setMemoryLimit = c.JS_SetMemoryLimit;

// export const newContext = c.JS_NewContext;
// export const freeContext = c.JS_FreeContext;

// export const JS_IsNumber = c.JS_IsNumber;
// export fn sizeOfValue() u32 {
//     return @intCast(@sizeOf(c.JSValue));
// }

// export fn sizeOfValue64() i64 {
//     return @intCast(@sizeOf(c.JSValue));
// }

// export fn isException(val: c.JSValue) bool {
//     return c.JS_IsException(val);
// }

// export fn hasException(ctx: *c.JSContext) bool {
//     return c.JS_HasException(ctx);
// }

// export fn getException(ctx: *c.JSContext) c.JSValue {
//     return c.JS_GetException(ctx);
// }
