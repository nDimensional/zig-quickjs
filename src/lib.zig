const std = @import("std");
const c = @import("c.zig").c;

// pub const ClassID = u32;

pub const ArrayBuffer = struct {
    buffer: Value,
    byte_offset: usize,
    byte_length: usize,
    bytes_per_element: usize,
};

pub const Atom = c.JSAtom;
pub const Value = c.JSValue;

pub const NULL = Value{ .u = .{ .int32 = 0 }, .tag = c.JS_TAG_NULL };
pub const UNDEFINED = Value{ .u = .{ .int32 = 0 }, .tag = c.JS_TAG_UNDEFINED };
pub const FALSE = c.JS_FALSE;
pub const TRUE = c.JS_TRUE;
pub const EXCEPTION = c.JS_EXCEPTION;
pub const UNINITIALIZED = c.JS_UNINITIALIZED;

pub const TypedArrayType = enum(c_int) {
    Uint8ClampedArray = c.JS_TYPED_ARRAY_UINT8C,
    Int8Array = c.JS_TYPED_ARRAY_INT8,
    Uint8Array = c.JS_TYPED_ARRAY_UINT8,
    Int16Array = c.JS_TYPED_ARRAY_INT16,
    Uint16Array = c.JS_TYPED_ARRAY_UINT16,
    Int32Array = c.JS_TYPED_ARRAY_INT32,
    Uint32Array = c.JS_TYPED_ARRAY_UINT32,
    BigInt64Array = c.JS_TYPED_ARRAY_BIG_INT64,
    BigUint64Array = c.JS_TYPED_ARRAY_BIG_UINT64,
    Float16Array = c.JS_TYPED_ARRAY_FLOAT16,
    Float32Array = c.JS_TYPED_ARRAY_FLOAT32,
    Float64Array = c.JS_TYPED_ARRAY_FLOAT64,
    _,
};

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    ptr: ?*c.JSRuntime,

    fn js_calloc(runtime_ptr: ?*anyopaque, count: usize, size: usize) callconv(.c) ?*anyopaque {
        const runtime: *const Runtime = @ptrCast(@alignCast(runtime_ptr));
        const len = count * size;
        const result = runtime.allocator.alloc(u8, @sizeOf(usize) + len) catch |err|
            @panic(@errorName(err));
        @memset(result, 0);
        std.mem.writeInt(usize, result[0..@sizeOf(usize)], len, .little);
        return result[@sizeOf(usize)..].ptr;
    }

    fn js_malloc(runtime_ptr: ?*anyopaque, size: usize) callconv(.c) ?*anyopaque {
        const runtime: *const Runtime = @ptrCast(@alignCast(runtime_ptr));
        const result = runtime.allocator.alloc(u8, @sizeOf(usize) + size) catch |err|
            @panic(@errorName(err));
        std.mem.writeInt(usize, result[0..@sizeOf(usize)], size, .little);
        return result[@sizeOf(usize)..].ptr;
    }

    fn js_free(runtime_ptr: ?*anyopaque, ptr: ?*anyopaque) callconv(.c) void {
        const runtime: *const Runtime = @ptrCast(@alignCast(runtime_ptr));
        const result: [*]u8 = @ptrFromInt(@intFromPtr(ptr) - @sizeOf(usize));
        const len = std.mem.readInt(usize, result[0..@sizeOf(usize)], .little);
        runtime.allocator.free(result[0 .. @sizeOf(usize) + len]);
    }

    fn js_realloc(runtime_ptr: ?*anyopaque, ptr: ?*anyopaque, new_len: usize) callconv(.c) ?*anyopaque {
        const runtime: *const Runtime = @ptrCast(@alignCast(runtime_ptr));
        const old_ptr: [*]u8 = @ptrFromInt(@intFromPtr(ptr) - @sizeOf(usize));
        const old_len = std.mem.readInt(usize, old_ptr[0..@sizeOf(usize)], .little);
        const result = runtime.allocator.realloc(old_ptr[0 .. @sizeOf(usize) + old_len], @sizeOf(usize) + new_len) catch |err|
            @panic(@errorName(err));
        std.mem.writeInt(usize, result[0..@sizeOf(usize)], new_len, .little);
        return result[@sizeOf(usize)..].ptr;
    }

    fn js_malloc_usable_size(_: ?*const anyopaque) callconv(.c) usize {
        return 0;
    }

    const malloc_functions = c.JSMallocFunctions{
        .js_calloc = &js_calloc,
        .js_malloc = &js_malloc,
        .js_free = &js_free,
        .js_realloc = &js_realloc,
        .js_malloc_usable_size = null,
    };

    pub fn init(allocator: std.mem.Allocator) !*Runtime {
        const runtime = try allocator.create(Runtime);
        runtime.allocator = allocator;
        runtime.ptr = c.JS_NewRuntime2(&malloc_functions, @constCast(runtime));
        return runtime;
    }

    pub fn deinit(self: *const Runtime) void {
        c.JS_FreeRuntime(self.ptr);
        self.allocator.destroy(self);
    }

    /// use 0 to disable memory limit
    pub inline fn setMemoryLimit(self: *const Runtime, limit: usize) void {
        c.JS_SetMemoryLimit(self.ptr, limit);
    }

    pub inline fn setGCThreshold(self: *const Runtime, gc_threshold: usize) void {
        c.JS_SetGCThreshold(self.ptr, gc_threshold);
    }

    pub inline fn getGCThreshold(self: *const Runtime) usize {
        return c.JS_GetGCThreshold(self.ptr);
    }

    pub inline fn setMaxStackSize(self: *const Runtime, stack_size: usize) void {
        c.JS_SetMaxStackSize(self.ptr, stack_size);
    }

    pub inline fn updateStackTop(self: *const Runtime) void {
        c.JS_UpdateStackTop(self.ptr);
    }

    pub inline fn setRuntimeInfo(self: *const Runtime, info: []const u8) void {
        c.JS_SetRuntimeInfo(self.ptr, info.ptr);
    }

    pub inline fn setDumpFlags(self: *const Runtime, flags: u64) void {
        c.JS_SetDumpFlags(self.ptr, flags);
    }

    pub inline fn getDumpFlags(self: *const Runtime) u64 {
        return c.JS_GetDumpFlags(self.ptr);
    }

    pub inline fn setRuntimeOpaque(self: *const Runtime, ptr: ?*anyopaque) void {
        c.JS_SetRuntimeOpaque(self.ptr, ptr);
    }

    pub inline fn getRuntimeOpaque(self: *const Runtime) ?*anyopaque {
        return c.JS_GetRuntimeOpaque(self.ptr);
    }

    pub inline fn runGC(self: *const Runtime) void {
        c.JS_RunGC(self.ptr);
    }

    pub inline fn isLiveObject(self: *const Runtime, obj: Value) bool {
        return c.JS_IsLiveObject(self.ptr, obj);
    }

    pub inline fn markValue(self: *const Runtime, val: Value, mark_func: c.JS_MarkFunc) void {
        c.JS_MarkValue(self.ptr, val, mark_func);
    }

    pub inline fn freeValue(self: *const Runtime, val: Value) void {
        c.JS_FreeValueRT(self.ptr, val);
    }

    pub inline fn dupValue(self: *const Runtime, val: Value) Value {
        return c.JS_DupValueRT(self.ptr, val);
    }

    // pub inline fn newClassID(self: Runtime) !ClassID {
    //     var class_id: ClassID = c.JS_INVALID_CLASS_ID;
    //     if (c.JS_NewClassID(self.ptr, &class_id) == 0)
    //         return error.ClassIDFailed;

    //     return class_id;
    // }

    // pub inline fn isRegisteredClass(self: Runtime, class_id: ClassID) bool {
    //     return c.JS_IsRegisteredClass(self.ptr, class_id);
    // }

    // pub const ClassFinalizer = fn (?*Runtime, Value) void;
    // // pub const MarkFunc = fn (?*Runtime, ?*GCObjectHeader) void;
    // // pub const GCMark = fn (?*Runtime, Value, ?*const MarkFunc) void;
    // pub const ClassDef = struct {
    //     class_name: [*:0]const u8 = null,
    //     finalizer: ?*const ClassFinalizer = null,
    //     // gc_mark: ?*const JSClassGCMark = @import("std").mem.zeroes(?*const JSClassGCMark),
    //     // call: ?*const JSClassCall = @import("std").mem.zeroes(?*const JSClassCall),
    //     // exotic: [*c]JSClassExoticMethods = @import("std").mem.zeroes([*c]JSClassExoticMethods),
    // };

    // pub inline fn newClass(self: Runtime, class_id: ClassID, class_def: *const c.JSClassDef) !void {
    //     if (c.JS_NewClass(self.ptr, class_id, class_def) < 0)
    //         return error.NewClassFailed;
    // }

    // Job queue management
    pub inline fn isJobPending(self: *const Runtime) bool {
        return c.JS_IsJobPending(self.ptr);
    }

    pub inline fn executePendingJob(self: *const Runtime) !?Context {
        var pctx: ?*c.JSContext = null;
        const ret = c.JS_ExecutePendingJob(self.ptr, &pctx);
        if (ret < 0) return error.ExecuteJobFailed;
        if (pctx == null) return null;
        return Context{ .ptr = pctx };
    }

    pub const MemoryUsage = packed struct {
        malloc_size: i64,
        malloc_limit: i64,
        memory_used_size: i64,
        malloc_count: i64,
        memory_used_count: i64,
        atom_count: i64,
        atom_size: i64,
        str_count: i64,
        str_size: i64,
        obj_count: i64,
        obj_size: i64,
        prop_count: i64,
        prop_size: i64,
        shape_count: i64,
        shape_size: i64,
        js_func_count: i64,
        js_func_size: i64,
        js_func_code_size: i64,
        js_func_pc2line_count: i64,
        js_func_pc2line_size: i64,
        c_func_count: i64,
        array_count: i64,
        fast_array_count: i64,
        fast_array_elements: i64,
        binary_object_count: i64,
        binary_object_size: i64,
    };

    // Memory management utilities
    pub inline fn computeMemoryUsage(self: *const Runtime) MemoryUsage {
        var usage: c.JSMemoryUsage = undefined;
        c.JS_ComputeMemoryUsage(self.ptr, &usage);
        return .{
            .malloc_size = usage.malloc_size,
            .malloc_limit = usage.malloc_limit,
            .memory_used_size = usage.memory_used_size,
            .malloc_count = usage.malloc_count,
            .memory_used_count = usage.memory_used_count,
            .atom_count = usage.atom_count,
            .atom_size = usage.atom_size,
            .str_count = usage.str_count,
            .str_size = usage.str_size,
            .obj_count = usage.obj_count,
            .obj_size = usage.obj_size,
            .prop_count = usage.prop_count,
            .prop_size = usage.prop_size,
            .shape_count = usage.shape_count,
            .shape_size = usage.shape_size,
            .js_func_count = usage.js_func_count,
            .js_func_size = usage.js_func_size,
            .js_func_code_size = usage.js_func_code_size,
            .js_func_pc2line_count = usage.js_func_pc2line_count,
            .js_func_pc2line_size = usage.js_func_pc2line_size,
            .c_func_count = usage.c_func_count,
            .array_count = usage.array_count,
            .fast_array_count = usage.fast_array_count,
            .fast_array_elements = usage.fast_array_elements,
            .binary_object_count = usage.binary_object_count,
            .binary_object_size = usage.binary_object_size,
        };
    }

    pub inline fn dumpMemoryUsage(self: *const Runtime, usage: *const MemoryUsage, file: std.fs.File) void {
        c.JS_DumpMemoryUsage(file.handle, &.{
            .malloc_size = usage.malloc_size,
            .malloc_limit = usage.malloc_limit,
            .memory_used_size = usage.memory_used_size,
            .malloc_count = usage.malloc_count,
            .memory_used_count = usage.memory_used_count,
            .atom_count = usage.atom_count,
            .atom_size = usage.atom_size,
            .str_count = usage.str_count,
            .str_size = usage.str_size,
            .obj_count = usage.obj_count,
            .obj_size = usage.obj_size,
            .prop_count = usage.prop_count,
            .prop_size = usage.prop_size,
            .shape_count = usage.shape_count,
            .shape_size = usage.shape_size,
            .js_func_count = usage.js_func_count,
            .js_func_size = usage.js_func_size,
            .js_func_code_size = usage.js_func_code_size,
            .js_func_pc2line_count = usage.js_func_pc2line_count,
            .js_func_pc2line_size = usage.js_func_pc2line_size,
            .c_func_count = usage.c_func_count,
            .array_count = usage.array_count,
            .fast_array_count = usage.fast_array_count,
            .fast_array_elements = usage.fast_array_elements,
            .binary_object_count = usage.binary_object_count,
            .binary_object_size = usage.binary_object_size,
        }, self.ptr);
    }

    // Shared ArrayBuffer support
    // pub inline fn setSharedArrayBufferFunctions(self: Runtime, functions: *const c.JSSharedArrayBufferFunctions) void {
    //     c.JS_SetSharedArrayBufferFunctions(self.ptr, functions);
    // }

    // Host callbacks
    // pub inline fn setInterruptHandler(self: Runtime, cb: ?c.JSInterruptHandler, ptr: ?*anyopaque) void {
    //     c.JS_SetInterruptHandler(self.ptr, cb, ptr);
    // }

    pub inline fn setCanBlock(self: *const Runtime, can_block: bool) void {
        c.JS_SetCanBlock(self.ptr, can_block);
    }

    // pub inline fn setHostPromiseRejectionTracker(self: Runtime, cb: ?c.JSHostPromiseRejectionTracker, ptr: ?*anyopaque) void {
    //     c.JS_SetHostPromiseRejectionTracker(self.ptr, cb, ptr);
    // }

    // Module system
    // pub inline fn setModuleLoaderFunc(
    //     self: Runtime,
    //     module_normalize: ?c.JSModuleNormalizeFunc,
    //     module_loader: ?c.JSModuleLoaderFunc,
    //     ptr: ?*anyopaque,
    // ) void {
    //     c.JS_SetModuleLoaderFunc(self.ptr, module_normalize, module_loader, ptr);
    // }

    // Runtime finalizer
    // pub inline fn addRuntimeFinalizer(self: Runtime, finalizer: c.JSRuntimeFinalizer, arg: ?*anyopaque) !void {
    //     const ret = c.JS_AddRuntimeFinalizer(self.ptr, finalizer, arg);
    //     if (ret < 0) return error.AddFinalizerFailed;
    // }
};

pub const Context = packed struct {
    ptr: ?*c.JSContext,

    pub inline fn init(runtime: *const Runtime) Context {
        return .{ .ptr = c.JS_NewContext(runtime.ptr) };
    }

    pub inline fn deinit(self: Context) void {
        c.JS_FreeContext(self.ptr);
    }

    // pub inline fn getRuntime(self: Context) Runtime {
    //     return .{ .ptr = c.JS_GetRuntime(self.ptr) };
    // }

    pub inline fn isEqual(self: Context, a: Value, b: Value) bool {
        return c.JS_IsEqual(self.ptr, a, b);
    }

    pub inline fn isStrictEqual(self: Context, a: Value, b: Value) bool {
        return c.JS_IsStrictEqual(self.ptr, a, b);
    }

    pub inline fn isSameValue(self: Context, a: Value, b: Value) bool {
        return c.JS_IsSameValue(self.ptr, a, b);
    }

    pub inline fn isSameValueZero(self: Context, a: Value, b: Value) bool {
        return c.JS_IsSameValueZero(self.ptr, a, b);
    }

    // Value creation methods

    pub inline fn dupValue(self: Context, value: Value) Value {
        return c.JS_DupValue(self.ptr, value);
    }

    pub inline fn newBool(_: Context, val: bool) Value {
        return c.JSValue{
            .u = c.JSValueUnion{
                .int32 = @as(c_int, @intFromBool(val)),
            },
            .tag = @as(i64, @bitCast(@as(c_longlong, c.JS_TAG_BOOL))),
        };
    }

    pub inline fn newInt32(self: Context, val: i32) Value {
        return c.JS_NewInt32(self.ptr, val);
    }

    pub inline fn newFloat64(self: Context, val: f64) Value {
        return c.JS_NewFloat64(self.ptr, val);
    }

    pub inline fn newInt64(self: Context, val: i64) Value {
        return c.JS_NewInt64(self.ptr, val);
    }

    pub inline fn newUint32(self: Context, val: u32) Value {
        return c.JS_NewUint32(self.ptr, val);
    }

    pub inline fn newString(self: Context, str: []const u8) Value {
        return c.JS_NewStringLen(self.ptr, str.ptr, str.len);
    }

    pub inline fn newSymbol(self: Context, description: []const u8, is_global: bool) Value {
        return c.JS_NewSymbol(self.ptr, description.ptr, is_global);
    }

    pub inline fn newAtomString(self: Context, str: []const u8) Value {
        return c.JS_NewAtomString(self.ptr, str.ptr);
    }

    pub inline fn newObject(self: Context) Value {
        return c.JS_NewObject(self.ptr);
    }

    pub inline fn newObjectClass(self: Context, class_id: i32) Value {
        return c.JS_NewObjectClass(self.ptr, class_id);
    }

    // pub inline fn newObjectProtoClass(self: Context, proto: Value, class_id: ClassID) Value {
    //     return c.JS_NewObjectProtoClass(self.ptr, proto, class_id);
    // }

    pub inline fn newArray(self: Context) Value {
        return c.JS_NewArray(self.ptr);
    }

    pub inline fn newDate(self: Context, epoch_ms: f64) Value {
        return c.JS_NewDate(self.ptr, epoch_ms);
    }

    pub inline fn newBigInt64(self: Context, val: i64) Value {
        return c.JS_NewBigInt64(self.ptr, val);
    }

    pub inline fn newBigUint64(self: Context, val: u64) Value {
        return c.JS_NewBigUint64(self.ptr, val);
    }

    // Value conversion methods
    pub inline fn toBool(self: Context, val: Value) !bool {
        const result = c.JS_ToBool(self.ptr, val);
        if (result == -1) return error.Exception;
        return result != 0;
    }

    pub inline fn toBoolean(self: Context, val: Value) Value {
        return self.newBool(c.JS_ToBool(self.ptr, val) != 0);
    }

    pub inline fn toNumber(self: Context, val: Value) Value {
        return c.JS_ToNumber(self.ptr, val);
    }

    pub inline fn toInt32(self: Context, val: Value) !i32 {
        var result: i32 = undefined;
        const ret = c.JS_ToInt32(self.ptr, &result, val);
        if (ret != 0) return error.Exception;
        return result;
    }

    pub inline fn toUint32(self: Context, val: Value) !u32 {
        var result: u32 = undefined;
        const ret = c.JS_ToUint32(self.ptr, &result, val);
        if (ret != 0) return error.Exception;
        return result;
    }

    pub inline fn toInt64(self: Context, val: Value) !i64 {
        var result: i64 = undefined;
        const ret = c.JS_ToInt64(self.ptr, &result, val);
        if (ret != 0) return error.Exception;
        return result;
    }

    pub inline fn toFloat64(self: Context, val: Value) !f64 {
        var result: f64 = undefined;
        const ret = c.JS_ToFloat64(self.ptr, &result, val);
        if (ret != 0) return error.Exception;
        return result;
    }

    pub inline fn toBigInt64(self: Context, val: Value) !i64 {
        var result: i64 = undefined;
        const ret = c.JS_ToBigInt64(self.ptr, &result, val);
        if (ret != 0) return error.Exception;
        return result;
    }

    pub inline fn toBigUint64(self: Context, val: Value) !u64 {
        var result: u64 = undefined;
        const ret = c.JS_ToBigUint64(self.ptr, &result, val);
        if (ret != 0) return error.Exception;
        return result;
    }

    pub inline fn toString(self: Context, val: Value) Value {
        return c.JS_ToString(self.ptr, val);
    }

    pub inline fn toCString(self: Context, val: Value) ![*:0]const u8 {
        return c.JS_ToCString(self.ptr, val) orelse error.Exception;
    }

    pub inline fn toCStringLen(self: Context, val: Value) ![:0]const u8 {
        var len: usize = undefined;
        const ptr = c.JS_ToCStringLen(self.ptr, &len, val) orelse
            return error.Exception;
        return ptr[0..len :0];
    }

    // pub inline fn toCStringOwned(self: Context, val: Value) ?[:0]const u8 {
    //     var len: usize = undefined;
    //     const str = c.JS_ToCStringLen(self.ptr, &len, val);
    //     if (str == null) return null;
    //     return str[0..len :0];
    // }

    pub inline fn freeCString(self: Context, ptr: [*:0]const u8) void {
        c.JS_FreeCString(self.ptr, ptr);
    }

    pub inline fn toPropertyKey(self: Context, val: Value) Value {
        return c.JS_ToPropertyKey(self.ptr, val);
    }

    pub inline fn toObject(self: Context, val: Value) Value {
        return c.JS_ToObject(self.ptr, val);
    }

    // Function, object, class, and prototype related methods
    pub inline fn isNumber(_: Context, self: Value) bool {
        return c.JS_IsNumber(self);
    }

    pub inline fn isNull(_: Context, self: Value) bool {
        return c.JS_IsNull(self);
    }

    pub inline fn isUndefined(_: Context, self: Value) bool {
        return c.JS_IsUndefined(self);
    }

    pub inline fn isUninitialized(_: Context, self: Value) bool {
        return c.JS_IsUninitialized(self);
    }

    pub inline fn isString(_: Context, self: Value) bool {
        return c.JS_IsString(self);
    }

    pub inline fn isSymbol(_: Context, self: Value) bool {
        return c.JS_IsSymbol(self);
    }

    pub inline fn isObject(_: Context, self: Value) bool {
        return c.JS_IsObject(self);
    }

    pub inline fn isBool(_: Context, self: Value) bool {
        return c.JS_IsBool(self);
    }

    pub inline fn isModule(_: Context, self: Value) bool {
        return c.JS_IsModule(self);
    }

    pub inline fn isArray(_: Context, self: Value) bool {
        return c.JS_IsArray(self);
    }

    pub inline fn isDate(_: Context, self: Value) bool {
        return c.JS_IsDate(self);
    }

    pub inline fn isException(_: Context, self: Value) bool {
        return c.JS_IsException(self);
    }

    pub inline fn isPromise(_: Context, self: Value) bool {
        return c.JS_IsPromise(self);
    }

    pub inline fn isRegExp(_: Context, self: Value) bool {
        return c.JS_IsRegExp(self);
    }

    pub inline fn isMap(_: Context, self: Value) bool {
        return c.JS_IsMap(self);
    }

    pub inline fn isProxy(_: Context, self: Value) bool {
        return c.JS_IsProxy(self);
    }

    pub inline fn isArrayBuffer(_: Context, self: Value) bool {
        return c.JS_IsArrayBuffer(self);
    }

    pub inline fn isFunction(self: Context, val: Value) bool {
        return c.JS_IsFunction(self.ptr, val);
    }

    pub inline fn isConstructor(self: Context, val: Value) bool {
        return c.JS_IsConstructor(self.ptr, val);
    }

    pub inline fn isError(self: Context, val: Value) bool {
        return c.JS_IsError(self.ptr, val);
    }

    pub inline fn isBigInt(self: Context, val: Value) bool {
        return c.JS_IsBigInt(self.ptr, val);
    }

    pub inline fn getPrototype(self: Context, val: Value) Value {
        return c.JS_GetPrototype(self.ptr, val);
    }

    pub inline fn setPrototype(self: Context, obj: Value, proto: Value) !void {
        const ret = c.JS_SetPrototype(self.ptr, obj, proto);
        if (ret < 0) return error.Exception;
    }

    pub inline fn getProxyTarget(self: Context, proxy: Value) Value {
        return c.JS_GetProxyTarget(self.ptr, proxy.val);
    }

    pub inline fn getProxyHandler(self: Context, proxy: Value) Value {
        return c.JS_GetProxyHandler(self.ptr, proxy.val);
    }

    // Error handling
    pub inline fn throwError(self: Context) Value {
        return c.JS_NewError(self.ptr);
    }

    pub inline fn throwTypeError(self: Context, fmt: [*:0]const u8) Value {
        return c.JS_ThrowTypeError(self.ptr, fmt);
    }

    pub inline fn throwSyntaxError(self: Context, fmt: [*:0]const u8) Value {
        return c.JS_ThrowSyntaxError(self.ptr, fmt);
    }

    pub inline fn throwReferenceError(self: Context, fmt: [*:0]const u8) Value {
        return c.JS_ThrowReferenceError(self.ptr, fmt);
    }

    pub inline fn throwRangeError(self: Context, fmt: [*:0]const u8) Value {
        return c.JS_ThrowRangeError(self.ptr, fmt);
    }

    pub inline fn throwInternalError(self: Context, fmt: [*:0]const u8) Value {
        return c.JS_ThrowInternalError(self.ptr, fmt);
    }

    pub inline fn throwOutOfMemory(self: Context) Value {
        return c.JS_ThrowOutOfMemory(self.ptr);
    }

    pub inline fn throw(self: Context, obj: Value) Value {
        return c.JS_Throw(self.ptr, obj);
    }

    pub inline fn getException(self: Context) Value {
        return c.JS_GetException(self.ptr);
    }

    pub inline fn hasException(self: Context) bool {
        return c.JS_HasException(self.ptr);
    }

    // Value lifecycle management
    pub inline fn freeValue(self: Context, val: Value) void {
        c.JS_FreeValue(self.ptr, val);
    }

    // Property access
    pub inline fn getProperty(self: Context, obj: Value, prop: Atom) Value {
        return c.JS_GetProperty(self.ptr, obj, prop);
    }

    pub inline fn getPropertyStr(self: Context, obj: Value, prop: [*:0]const u8) Value {
        return c.JS_GetPropertyStr(self.ptr, obj, prop);
    }

    pub inline fn getPropertyUint32(self: Context, obj: Value, idx: u32) Value {
        return c.JS_GetPropertyUint32(self.ptr, obj, idx);
    }

    pub inline fn getPropertyInt64(self: Context, obj: Value, idx: i64) Value {
        return c.JS_GetPropertyInt64(self.ptr, obj, idx);
    }

    pub inline fn setProperty(self: Context, obj: Value, prop: Atom, val: Value) !void {
        const ret = c.JS_SetProperty(self.ptr, obj, prop, val);
        if (ret < 0) return error.Exception;
    }

    pub inline fn setPropertyStr(self: Context, obj: Value, prop: [*:0]const u8, val: Value) !void {
        const ret = c.JS_SetPropertyStr(self.ptr, obj, prop, val);
        if (ret < 0) return error.Exception;
    }

    pub inline fn setPropertyUint32(self: Context, obj: Value, idx: u32, val: Value) !void {
        const ret = c.JS_SetPropertyUint32(self.ptr, obj, idx, val);
        if (ret < 0) return error.Exception;
    }

    pub inline fn setPropertyInt64(self: Context, obj: Value, idx: i64, val: Value) !void {
        const ret = c.JS_SetPropertyInt64(self.ptr, obj, idx, val);
        if (ret < 0) return error.Exception;
    }

    pub inline fn hasProperty(self: Context, obj: Value, prop: Atom) !bool {
        const ret = c.JS_HasProperty(self.ptr, obj, prop);
        if (ret < 0) return error.Exception;
        return ret != 0;
    }

    pub inline fn deleteProperty(self: Context, obj: Value, prop: Atom, flags: c_int) !bool {
        const ret = c.JS_DeleteProperty(self.ptr, obj, prop, flags);
        if (ret < 0) return error.Exception;
        return ret != 0;
    }

    // Execution and evaluation

    pub const EvalType = enum {
        global,
        module,
    };

    pub const EvalFlags = struct {
        type: EvalType = .global,
        strict: bool = false,
        compile_only: bool = false,
        backtrace_barrier: bool = false,
        async: bool = false,
    };

    pub inline fn eval(self: Context, input: []const u8, filename: [*:0]const u8, flags: EvalFlags) error{Exception}!Value {
        var c_flags: c_int = 0;

        // Set eval type flag
        switch (flags.type) {
            .global => c_flags |= c.JS_EVAL_TYPE_GLOBAL,
            .module => c_flags |= c.JS_EVAL_TYPE_MODULE,
        }

        // Set other flags
        if (flags.strict) c_flags |= c.JS_EVAL_FLAG_STRICT;
        if (flags.compile_only) c_flags |= c.JS_EVAL_FLAG_COMPILE_ONLY;
        if (flags.backtrace_barrier) c_flags |= c.JS_EVAL_FLAG_BACKTRACE_BARRIER;
        if (flags.async) c_flags |= c.JS_EVAL_FLAG_ASYNC;

        const result = c.JS_Eval(self.ptr, input.ptr, input.len, filename, c_flags);
        if (c.JS_IsException(result)) {
            return error.Exception;
        } else {
            return result;
        }
    }

    pub inline fn getGlobalObject(self: Context) Value {
        return c.JS_GetGlobalObject(self.ptr);
    }

    pub inline fn isInstanceOf(self: Context, val: Value, obj: Value) !bool {
        const ret = c.JS_IsInstanceOf(self.ptr, val, obj);
        if (ret < 0) return error.Exception;
        return ret != 0;
    }

    pub inline fn call(self: Context, func_obj: Value, this_obj: Value, args: []const Value) Value {
        return c.JS_Call(self.ptr, func_obj, this_obj, @intCast(args.len), @constCast(args.ptr));
    }

    pub inline fn callConstructor(self: Context, func_obj: Value, args: []const Value) Value {
        return c.JS_CallConstructor(self.ptr, func_obj, @intCast(args.len), args.ptr);
    }

    // ArrayBuffer related methods
    pub inline fn getArrayBuffer(self: Context, val: Value) ![]u8 {
        var size: usize = undefined;
        const ptr = c.JS_GetArrayBuffer(self.ptr, &size, val);
        if (ptr == null) return error.NotArrayBuffer;
        return ptr[0..size];
    }

    // pub inline fn newArrayBuffer(self: Context, buf: []u8, free_func: ?c.JSFreeArrayBufferDataFunc, ptr: ?*anyopaque, is_shared: bool) Value {
    //     return c.JS_NewArrayBuffer(self.ptr, buf.ptr, buf.len, free_func, ptr, is_shared);
    // }

    pub inline fn newArrayBufferCopy(self: Context, buf: []const u8) Value {
        return c.JS_NewArrayBufferCopy(self.ptr, buf.ptr, buf.len);
    }

    pub inline fn detachArrayBuffer(self: Context, obj: Value) void {
        c.JS_DetachArrayBuffer(self.ptr, obj);
    }

    pub inline fn getUint8Array(self: Context, obj: Value) ![]u8 {
        var size: usize = undefined;
        const ptr = c.JS_GetUint8Array(self.ptr, &size, obj);
        if (ptr == null) return error.TypeError;
        return ptr[0..size];
    }

    // pub inline fn newUint8Array(self: Context, buf: []u8, free_func: ?c.JSFreeArrayBufferDataFunc, ptr: ?*anyopaque, is_shared: bool) Value {
    //     return c.JS_NewUint8Array(self.ptr, buf.ptr, buf.len, free_func, ptr, is_shared);
    // }

    pub inline fn newUint8ArrayCopy(self: Context, buf: []const u8) Value {
        return c.JS_NewUint8ArrayCopy(self.ptr, buf.ptr, buf.len);
    }

    pub inline fn getTypedArrayType(self: Context, obj: Value) !TypedArrayType {
        _ = self;
        const type_int = c.JS_GetTypedArrayType(obj);
        if (type_int < 0) return error.TypeError;
        return @enumFromInt(type_int);
    }

    pub inline fn getTypedArrayBuffer(self: Context, obj: Value) !ArrayBuffer {
        var byte_offset: usize = undefined;
        var byte_length: usize = undefined;
        var bytes_per_element: usize = undefined;

        const buffer_val = c.JS_GetTypedArrayBuffer(self.ptr, obj, &byte_offset, &byte_length, &bytes_per_element);
        if (c.JS_IsException(buffer_val)) return error.Exception;

        return .{
            .buffer = buffer_val,
            .byte_offset = byte_offset,
            .byte_length = byte_length,
            .bytes_per_element = bytes_per_element,
        };
    }

    // Promise related methods
    pub const PromiseState = enum(c_int) {
        Pending = c.JS_PROMISE_PENDING,
        Fulfilled = c.JS_PROMISE_FULFILLED,
        Rejected = c.JS_PROMISE_REJECTED,
    };

    pub inline fn promiseState(self: Context, promise: Value) PromiseState {
        return @enumFromInt(c.JS_PromiseState(self.ptr, promise));
    }

    pub inline fn promiseResult(self: Context, promise: Value) Value {
        return c.JS_PromiseResult(self.ptr, promise);
    }

    // JSON methods
    pub inline fn parseJSON(self: Context, buf: []const u8, filename: [*:0]const u8) Value {
        return c.JS_ParseJSON(self.ptr, buf.ptr, buf.len, filename);
    }

    pub inline fn jsonStringify(self: Context, obj: Value, replacer: Value, space: Value) Value {
        return c.JS_JSONStringify(self.ptr, obj, replacer, space);
    }

    // Atom handling
    pub inline fn newAtom(self: Context, str: []const u8) Atom {
        return c.JS_NewAtomLen(self.ptr, str.ptr, str.len);
    }

    pub inline fn newAtomUint32(self: Context, n: u32) Atom {
        return c.JS_NewAtomUInt32(self.ptr, n);
    }

    pub inline fn dupAtom(self: Context, atom: Atom) Atom {
        return c.JS_DupAtom(self.ptr, atom);
    }

    pub inline fn freeAtom(self: Context, atom: Atom) void {
        c.JS_FreeAtom(self.ptr, atom);
    }

    pub inline fn atomToValue(self: Context, atom: Atom) Value {
        return c.JS_AtomToValue(self.ptr, atom);
    }

    pub inline fn atomToString(self: Context, atom: Atom) Value {
        return c.JS_AtomToString(self.ptr, atom);
    }

    pub inline fn atomToCString(self: Context, atom: Atom) ![*:0]const u8 {
        return c.JS_AtomToCString(self.ptr, atom) orelse return error.Exception;
    }

    pub inline fn valueToAtom(self: Context, val: Value) Atom {
        return c.JS_ValueToAtom(self.ptr, val);
    }

    // Property descriptors and enumeration
    pub const PropertyEnumFlags = packed struct {
        strings: bool = true,
        symbols: bool = false,
        private: bool = false,
        enum_only: bool = false,
        set_enum: bool = false,
    };

    // pub const PropertyEnum = packed struct {
    //     is_enumerable: bool,
    //     atom: Atom,
    // };

    // typedef struct JSPropertyEnum {
    //     bool is_enumerable;
    //     JSAtom atom;
    // } JSPropertyEnum;

    // pub inline fn getOwnPropertyNames(self: Context, obj: Value, flags: PropertyEnumFlags) ![]const c.JSPropertyEnum {
    //     var c_flags: c_int = 0;
    //     if (flags.strings) c_flags |= c.JS_GPN_STRING_MASK;
    //     if (flags.symbols) c_flags |= c.JS_GPN_SYMBOL_MASK;
    //     if (flags.private) c_flags |= c.JS_GPN_PRIVATE_MASK;
    //     if (flags.enum_only) c_flags |= c.JS_GPN_ENUM_ONLY;
    //     if (flags.set_enum) c_flags |= c.JS_GPN_SET_ENUM;

    //     var ptab: [*c]c.JSPropertyEnum = undefined;
    //     var len: u32 = 0;

    //     const ret = c.JS_GetOwnPropertyNames(self.ptr, &ptab, &len, obj, c_flags);
    //     if (ret < 0) return error.Exception;

    //     return ptab[0..len];
    // }

    // pub inline fn freePropertyEnum(self: Context, tab: []const c.JSPropertyEnum) void {
    //     c.JS_FreePropertyEnum(self.ptr, @constCast(tab.ptr), @intCast(tab.len));
    // }

    // Property descriptor structure

    pub const PropertyFlags = packed struct {
        configurable: bool,
        writable: bool,
        enumerable: bool,
        normal: bool,
        getset: bool,

        pub fn fromInt(flags: c_int) PropertyFlags {
            return .{
                .configurable = ((flags | c.JS_PROP_CONFIGURABLE) != 0),
                .writable = ((flags | c.JS_PROP_WRITABLE) != 0),
                .enumerable = ((flags | c.JS_PROP_ENUMERABLE) != 0),
                .normal = ((flags | c.JS_PROP_NORMAL) != 0),
                .getset = ((flags | c.JS_PROP_GETSET) != 0),
            };
        }

        pub fn toInt(self: PropertyFlags) c_int {
            var flags: c_int = 0;
            if (self.configurable) flags |= c.JS_PROP_CONFIGURABLE;
            if (self.writable) flags |= c.JS_PROP_WRITABLE;
            if (self.enumerable) flags |= c.JS_PROP_ENUMERABLE;
            if (self.normal) flags |= c.JS_PROP_NORMAL;
            if (self.getset) flags |= c.JS_PROP_GETSET;
            return flags;
        }
    };

    pub const PropertyDescriptor = struct {
        flags: PropertyFlags,
        value: Value,
        getter: Value,
        setter: Value,
    };

    pub inline fn getOwnProperty(self: Context, obj: Value, prop: Atom) !PropertyDescriptor {
        var desc: c.JSPropertyDescriptor = undefined;
        const ret = c.JS_GetOwnProperty(self.ptr, &desc, obj, prop);
        if (ret < 0) return error.Exception;
        if (ret == 0) return error.PropertyNotFound;

        return PropertyDescriptor{
            .flags = PropertyFlags.fromInt(desc.flags),
            .value = desc.value,
            .getter = desc.getter,
            .setter = desc.setter,
        };
    }

    // Object extensibility and related operations
    pub inline fn isExtensible(self: Context, obj: Value) !bool {
        const ret = c.JS_IsExtensible(self.ptr, obj);
        if (ret < 0) return error.Exception;
        return ret != 0;
    }

    pub inline fn preventExtensions(self: Context, obj: Value) !bool {
        const ret = c.JS_PreventExtensions(self.ptr, obj);
        if (ret < 0) return error.Exception;
        return ret != 0;
    }

    pub const DefinePropertyFlags = packed struct {
        configurable: bool = false,
        writable: bool = false,
        enumerable: bool = false,
        has_configurable: bool = false,
        has_writable: bool = false,
        has_enumerable: bool = false,
        has_get: bool = false,
        has_set: bool = false,
        has_value: bool = false,
        throw: bool = false,
        no_exotic: bool = false,

        pub fn toInt(self: DefinePropertyFlags) c_int {
            var flags: c_int = 0;
            if (self.configurable) flags |= c.JS_PROP_CONFIGURABLE;
            if (self.writable) flags |= c.JS_PROP_WRITABLE;
            if (self.enumerable) flags |= c.JS_PROP_ENUMERABLE;
            if (self.has_configurable) flags |= c.JS_PROP_HAS_CONFIGURABLE;
            if (self.has_writable) flags |= c.JS_PROP_HAS_WRITABLE;
            if (self.has_enumerable) flags |= c.JS_PROP_HAS_ENUMERABLE;
            if (self.has_get) flags |= c.JS_PROP_HAS_GET;
            if (self.has_set) flags |= c.JS_PROP_HAS_SET;
            if (self.has_value) flags |= c.JS_PROP_HAS_VALUE;
            if (self.throw) flags |= c.JS_PROP_THROW;
            return flags;
        }
    };

    pub inline fn defineProperty(self: Context, obj: Value, prop: Atom, val: Value, getter: Value, setter: Value, flags: DefinePropertyFlags) !bool {
        const c_flags = flags.toInt();
        const ret = c.JS_DefineProperty(self.ptr, obj, prop, val, getter, setter, c_flags);
        if (ret < 0) return error.Exception;
        return ret != 0;
    }

    pub inline fn definePropertyValue(self: Context, obj: Value, prop: Atom, val: Value, flags: DefinePropertyFlags) !bool {
        const c_flags = flags.toInt();
        const ret = c.JS_DefinePropertyValue(self.ptr, obj, prop, val, c_flags);
        if (ret < 0) return error.Exception;
        return ret != 0;
    }

    pub inline fn definePropertyValueStr(self: Context, obj: Value, prop: []const u8, val: Value, flags: PropertyFlags) !bool {
        const c_flags = flags.toInt();
        const ret = c.JS_DefinePropertyValueStr(self.ptr, obj, prop.ptr, val, c_flags);
        if (ret < 0) return error.Exception;
        return ret != 0;
    }

    pub inline fn definePropertyValueUint32(self: Context, obj: Value, idx: u32, val: Value, flags: PropertyFlags) !bool {
        const c_flags = flags.toInt();
        const ret = c.JS_DefinePropertyValueUint32(self.ptr, obj, idx, val, c_flags);
        if (ret < 0) return error.Exception;
        return ret != 0;
    }

    pub inline fn definePropertyGetSet(self: Context, obj: Value, prop: Atom, getter: Value, setter: Value, flags: PropertyFlags) !bool {
        const c_flags = flags.toInt();
        const ret = c.JS_DefinePropertyGetSet(self.ptr, obj, prop, getter, setter, c_flags);
        if (ret < 0) return error.Exception;
        return ret != 0;
    }

    // pub inline fn setOpaque(_: Context, obj: Value, ptr: ?*anyopaque) !void {
    //     if (c.JS_SetOpaque(obj, ptr) < 0)
    //         return error.OpaqueSetFailed;
    // }

    // pub inline fn getOpaque(_: Context, obj: Value, class_id: ClassID) ?*anyopaque {
    //     return c.JS_GetOpaque(obj, class_id);
    // }

    // pub inline fn getOpaque2(self: Context, obj: Value, class_id: ClassID) ?*anyopaque {
    //     return c.JS_GetOpaque2(self.ptr, obj, class_id);
    // }

    // // Class and prototype handling
    // pub inline fn setClassProto(self: Context, class_id: ClassID, proto: Value) void {
    //     c.JS_SetClassProto(self.ptr, class_id, proto);
    // }

    // pub inline fn getClassProto(self: Context, class_id: ClassID) Value {
    //     return c.JS_GetClassProto(self.ptr, class_id);
    // }

    pub inline fn getFunctionProto(self: Context) Value {
        return c.JS_GetFunctionProto(self.ptr);
    }

    // Intrinsic object loading
    pub inline fn addIntrinsicBaseObjects(self: Context) void {
        c.JS_AddIntrinsicBaseObjects(self.ptr);
    }

    pub inline fn addIntrinsicDate(self: Context) void {
        c.JS_AddIntrinsicDate(self.ptr);
    }

    pub inline fn addIntrinsicEval(self: Context) void {
        c.JS_AddIntrinsicEval(self.ptr);
    }

    pub inline fn addIntrinsicRegExpCompiler(self: Context) void {
        c.JS_AddIntrinsicRegExpCompiler(self.ptr);
    }

    pub inline fn addIntrinsicRegExp(self: Context) void {
        c.JS_AddIntrinsicRegExp(self.ptr);
    }

    pub inline fn addIntrinsicJSON(self: Context) void {
        c.JS_AddIntrinsicJSON(self.ptr);
    }

    pub inline fn addIntrinsicProxy(self: Context) void {
        c.JS_AddIntrinsicProxy(self.ptr);
    }

    pub inline fn addIntrinsicMapSet(self: Context) void {
        c.JS_AddIntrinsicMapSet(self.ptr);
    }

    pub inline fn addIntrinsicTypedArrays(self: Context) void {
        c.JS_AddIntrinsicTypedArrays(self.ptr);
    }

    pub inline fn addIntrinsicPromise(self: Context) void {
        c.JS_AddIntrinsicPromise(self.ptr);
    }

    pub inline fn addIntrinsicBigInt(self: Context) void {
        c.JS_AddIntrinsicBigInt(self.ptr);
    }

    pub inline fn addIntrinsicWeakRef(self: Context) void {
        c.JS_AddIntrinsicWeakRef(self.ptr);
    }

    pub inline fn addPerformance(self: Context) void {
        c.JS_AddPerformance(self.ptr);
    }

    // // C function integration
    // pub inline fn newCFunction(self: Context, func: c.JSCFunction, name: []const u8, length: c_int) Value {
    //     return c.JS_NewCFunction(self.ptr, func, name.ptr, length);
    // }

    // pub inline fn newCFunction2(self: Context, func: c.JSCFunction, name: []const u8, length: c_int, cproto: c.JSCFunctionEnum, magic: c_int) Value {
    //     return c.JS_NewCFunction2(self.ptr, func, name.ptr, length, cproto, magic);
    // }

    // pub inline fn newCFunctionMagic(self: Context, func: c.JSCFunctionMagic, name: []const u8, length: c_int, cproto: c.JSCFunctionEnum, magic: c_int) Value {
    //     return c.JS_NewCFunctionMagic(self.ptr, func, name.ptr, length, cproto, magic);
    // }

    pub inline fn setConstructor(self: Context, func_obj: Value, proto: Value) void {
        c.JS_SetConstructor(self.ptr, func_obj, proto);
    }

    pub inline fn setConstructorBit(self: Context, func_obj: Value, val: bool) bool {
        return c.JS_SetConstructorBit(self.ptr, func_obj, val) != 0;
    }

    // pub inline fn newCFunctionData(self: Context, func: c.JSCFunctionData, length: c_int, magic: c_int, data: []const Value) Value {
    //     return c.JS_NewCFunctionData(self.ptr, func, length, magic, data.len, data.ptr);
    // }

    // Module type
    pub const Module = struct {
        ptr: *c.JSModuleDef,
    };

    // Module support
    pub inline fn getModuleNamespace(self: Context, m: Module) Value {
        return c.JS_GetModuleNamespace(self.ptr, m.ptr);
    }

    pub inline fn getModuleName(self: Context, m: Module) Atom {
        return c.JS_GetModuleName(self.ptr, m.ptr);
    }

    pub inline fn getImportMeta(self: Context, m: Module) Value {
        return c.JS_GetImportMeta(self.ptr, m.ptr);
    }

    pub inline fn resolveModule(self: Context, obj: Value) !void {
        const ret = c.JS_ResolveModule(self.ptr, obj);
        if (ret < 0) return error.ModuleResolutionFailed;
    }

    pub inline fn evalFunction(self: Context, fun_obj: Value) Value {
        return c.JS_EvalFunction(self.ptr, fun_obj);
    }

    pub inline fn getScriptOrModuleName(self: Context, n_stack_levels: i32) Atom {
        return c.JS_GetScriptOrModuleName(self.ptr, n_stack_levels);
    }

    pub inline fn loadModule(self: Context, basename: ?[]const u8, filename: []const u8) Value {
        const basename_ptr = if (basename) |b| b.ptr else null;
        return c.JS_LoadModule(self.ptr, basename_ptr, filename.ptr);
    }

    // C module creation helpers
    pub inline fn newCModule(self: Context, name: []const u8, func: c.JSModuleInitFunc) ?Module {
        const ptr = c.JS_NewCModule(self.ptr, name.ptr, func);
        return if (ptr != null) Module{ .ptr = ptr.? } else null;
    }

    pub inline fn addModuleExport(self: Context, m: Module, name: []const u8) !void {
        const ret = c.JS_AddModuleExport(self.ptr, m.ptr, name.ptr);
        if (ret < 0) return error.ModuleExportFailed;
    }

    pub inline fn setModuleExport(self: Context, m: Module, name: []const u8, val: Value) !void {
        const ret = c.JS_SetModuleExport(self.ptr, m.ptr, name.ptr, val);
        if (ret < 0) return error.ModuleExportFailed;
    }

    // // Job queue management
    // pub inline fn enqueueJob(self: Context, job_func: c.JSJobFunc, args: []const Value) !void {
    //     const ret = c.JS_EnqueueJob(self.ptr, job_func, args.len, args.ptr);
    //     if (ret < 0) return error.EnqueueJobFailed;
    // }

    // Object serialization
    pub const WriteObjectFlags = packed struct {
        bytecode: bool = false,
        sab: bool = false,
        reference: bool = false,
        strip_source: bool = false,
        strip_debug: bool = false,
    };

    pub inline fn writeObject(self: Context, obj: Value, flags: WriteObjectFlags) ![]u8 {
        var c_flags: c_int = 0;
        if (flags.bytecode) c_flags |= c.JS_WRITE_OBJ_BYTECODE;
        if (flags.sab) c_flags |= c.JS_WRITE_OBJ_SAB;
        if (flags.reference) c_flags |= c.JS_WRITE_OBJ_REFERENCE;
        if (flags.strip_source) c_flags |= c.JS_WRITE_OBJ_STRIP_SOURCE;
        if (flags.strip_debug) c_flags |= c.JS_WRITE_OBJ_STRIP_DEBUG;

        var size: usize = undefined;
        const ptr = c.JS_WriteObject(self.ptr, &size, obj, c_flags);
        if (ptr == null) return error.SerializationFailed;
        return ptr[0..size];
    }

    pub const ReadObjectFlags = packed struct {
        bytecode: bool = false,
        sab: bool = false,
        reference: bool = false,
    };

    pub inline fn readObject(self: Context, buf: []const u8, flags: ReadObjectFlags) Value {
        var c_flags: c_int = 0;
        if (flags.bytecode) c_flags |= c.JS_READ_OBJ_BYTECODE;
        if (flags.sab) c_flags |= c.JS_READ_OBJ_SAB;
        if (flags.reference) c_flags |= c.JS_READ_OBJ_REFERENCE;

        return c.JS_ReadObject(self.ptr, buf.ptr, buf.len, c_flags);
    }

    // Memory allocation functions
    pub inline fn malloc(self: Context, size: usize) ?*anyopaque {
        return c.js_malloc(self.ptr, size);
    }

    pub inline fn calloc(self: Context, count: usize, size: usize) ?*anyopaque {
        return c.js_calloc(self.ptr, count, size);
    }

    pub inline fn free(self: Context, ptr: ?*anyopaque) void {
        c.js_free(self.ptr, ptr);
    }

    pub inline fn realloc(self: Context, ptr: ?*anyopaque, size: usize) ?*anyopaque {
        return c.js_realloc(self.ptr, ptr, size);
    }

    pub inline fn mallocz(self: Context, size: usize) ?*anyopaque {
        return c.js_mallocz(self.ptr, size);
    }

    pub inline fn strdup(self: Context, str: []const u8) ?[*:0]u8 {
        return c.js_strdup(self.ptr, str.ptr);
    }

    pub inline fn strndup(self: Context, str: []const u8, n: usize) ?[*:0]u8 {
        return c.js_strndup(self.ptr, str.ptr, n);
    }

    pub inline fn mallocUsableSize(self: Context, ptr: ?*const anyopaque) usize {
        return c.js_malloc_usable_size(self.ptr, ptr);
    }
};
