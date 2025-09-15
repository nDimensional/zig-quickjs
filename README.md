# zig-quickjs

Status: WIP. The majority of the Runtime, Context, and Value methods are exposed. Methods relating to custom classes, callbacks, and system integration are mostly missing.

## Installation

Requires Zig `0.15.1`.

```
zig fetch --save=quickjs \
  https://github.com/nDimensional/zig-quickjs/archive/{COMMIT}.tar.gz
```

## API

### Primitives

```zig
pub const Atom: (type);
pub const Value: (type);

pub const NULL: Value;
pub const UNDEFINED: Value;
pub const FALSE: Value;
pub const TRUE: Value;
pub const UNINITIALIZED: Value;
// pub const EXCEPTION: Value;

pub const TypedArrayType = enum(c_int) {
    Uint8ClampedArray,
    Int8Array,
    Uint8Array,
    Int16Array,
    Uint16Array,
    Int32Array,
    Uint32Array,
    BigInt64Array,
    BigUint64Array,
    Float16Array,
    Float32Array,
    Float64Array,
    _,
};
```

### Runtime

```zig
pub const Runtime = struct {
    pub inline fn init() Runtime
    pub inline fn deinit(self: Runtime) void
    pub inline fn setMemoryLimit(self: Runtime, limit: usize) void
    pub inline fn setGCThreshold(self: Runtime, gc_threshold: usize) void
    pub inline fn getGCThreshold(self: Runtime) usize
    pub inline fn setMaxStackSize(self: Runtime, stack_size: usize) void
    pub inline fn updateStackTop(self: Runtime) void
    pub inline fn setRuntimeInfo(self: Runtime, info: []const u8) void
    pub inline fn setDumpFlags(self: Runtime, flags: u64) void
    pub inline fn getDumpFlags(self: Runtime) u64
    pub inline fn setRuntimeOpaque(self: Runtime, ptr: ?*anyopaque) void
    pub inline fn getRuntimeOpaque(self: Runtime) ?*anyopaque
    pub inline fn runGC(self: Runtime) void
    pub inline fn isLiveObject(self: Runtime, obj: Value) bool
    // pub inline fn markValue(self: Runtime, val: Value, mark_func: c.JS_MarkFunc) void
    pub inline fn freeValueRT(self: Runtime, val: Value) void
    pub inline fn dupValueRT(self: Runtime, val: Value) Value
    pub inline fn newClassID(self: Runtime) !ClassID
    pub inline fn isRegisteredClass(self: Runtime, class_id: ClassID) bool
    // pub inline fn newClass(self: Runtime, class_id: ClassID, class_def: *const c.JSClassDef) !void
    pub inline fn isJobPending(self: Runtime) bool
    pub inline fn executePendingJob(self: Runtime) !?Context

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
    pub inline fn computeMemoryUsage(self: Runtime) MemoryUsage
    pub inline fn dumpMemoryUsage(self: Runtime, usage: *const MemoryUsage, file: std.fs.File) void
    // pub inline fn setSharedArrayBufferFunctions(self: Runtime, functions: *const c.JSSharedArrayBufferFunctions) void
    // pub inline fn setInterruptHandler(self: Runtime, cb: ?c.JSInterruptHandler, ptr: ?*anyopaque) void
    pub inline fn setCanBlock(self: Runtime, can_block: bool) void
    // pub inline fn setHostPromiseRejectionTracker(self: Runtime, cb: ?c.JSHostPromiseRejectionTracker, ptr: ?*anyopaque) void
    // pub inline fn setModuleLoaderFunc(self: Runtime, module_normalize: ?c.JSModuleNormalizeFunc, module_loader: ?c.JSModuleLoaderFunc, ptr: ?*anyopaque) void
    pub inline fn calloc(self: Runtime, count: usize, size: usize) ?*anyopaque
    pub inline fn malloc(self: Runtime, size: usize) ?*anyopaque
    pub inline fn free(self: Runtime, ptr: ?*anyopaque) void
    pub inline fn realloc(self: Runtime, ptr: ?*anyopaque, size: usize) ?*anyopaque
    pub inline fn mallocz(self: Runtime, size: usize) ?*anyopaque
    pub inline fn mallocUsableSize(self: Runtime, ptr: ?*const anyopaque) usize
    // pub inline fn addRuntimeFinalizer(self: Runtime, finalizer: c.JSRuntimeFinalizer, arg: ?*anyopaque) !void
};
```

### Context

```zig
pub const Context = struct {
    pub inline fn init(runtime: Runtime) Context
    pub inline fn deinit(self: Context) void

    pub inline fn getRuntime(self: Context) Runtime

    pub inline fn isEqual(self: Context, a: Value, b: Value) bool
    pub inline fn isStrictEqual(self: Context, a: Value, b: Value) bool
    pub inline fn isSameValue(self: Context, a: Value, b: Value) bool
    pub inline fn isSameValueZero(self: Context, a: Value, b: Value) bool

    pub inline fn freeValue(self: Context, val: Value) void
    pub inline fn dupValue(self: Context, value: Value) Value
    pub inline fn newBool(self: Context, val: bool) Value
    pub inline fn newInt32(self: Context, val: i32) Value
    pub inline fn newFloat64(self: Context, val: f64) Value
    pub inline fn newInt64(self: Context, val: i64) Value
    pub inline fn newUint32(self: Context, val: u32) Value
    pub inline fn newString(self: Context, str: []const u8) Value
    pub inline fn newSymbol(self: Context, description: []const u8, is_global: bool) Value
    pub inline fn newAtomString(self: Context, str: []const u8) Value
    pub inline fn newObject(self: Context) Value
    pub inline fn newArray(self: Context) Value
    pub inline fn newDate(self: Context, epoch_ms: f64) Value
    pub inline fn newBigInt64(self: Context, val: i64) Value
    pub inline fn newBigUint64(self: Context, val: u64) Value

    pub inline fn toBool(self: Context, val: Value) !bool
    pub inline fn toBoolean(self: Context, val: Value) Value
    pub inline fn toNumber(self: Context, val: Value) Value
    pub inline fn toInt32(self: Context, val: Value) !i32
    pub inline fn toUint32(self: Context, val: Value) !u32
    pub inline fn toInt64(self: Context, val: Value) !i64
    pub inline fn toFloat64(self: Context, val: Value) !f64
    pub inline fn toBigInt64(self: Context, val: Value) !i64
    pub inline fn toBigUint64(self: Context, val: Value) !u64
    pub inline fn toString(self: Context, val: Value) Value
    pub inline fn toCString(self: Context, val: Value) ?[*:0]const u8
    pub inline fn toCStringLen(self: Context, val: Value) ?struct { str: [*:0]const u8, len: usize }
    // pub inline fn toCStringOwned(self: Context, val: Value) ?[:0]const u8
    pub inline fn freeCString(self: Context, ptr: [*:0]const u8) void
    pub inline fn toPropertyKey(self: Context, val: Value) Value
    pub inline fn toObject(self: Context, val: Value) Value
    pub inline fn isNumber(self: Context, value: Value) bool
    pub inline fn isNull(self: Context, value: Value) bool
    pub inline fn isUndefined(self: Context, value: Value) bool
    pub inline fn isUninitialized(self: Context, value: Value) bool
    pub inline fn isString(self: Context, value: Value) bool
    pub inline fn isSymbol(self: Context, value: Value) bool
    pub inline fn isObject(self: Context, value: Value) bool
    pub inline fn isBool(self: Context, value: Value) bool
    pub inline fn isModule(self: Context, value: Value) bool
    pub inline fn isArray(self: Context, value: Value) bool
    pub inline fn isDate(self: Context, value: Value) bool
    pub inline fn isException(self: Context, value: Value) bool
    pub inline fn isPromise(self: Context, value: Value) bool
    pub inline fn isRegExp(self: Context, value: Value) bool
    pub inline fn isMap(self: Context, value: Value) bool
    pub inline fn isProxy(self: Context, value: Value) bool
    pub inline fn isArrayBuffer(self: Context, value: Value) bool
    pub inline fn isFunction(self: Context, val: Value) bool
    pub inline fn isConstructor(self: Context, val: Value) bool
    pub inline fn isError(self: Context, val: Value) bool
    pub inline fn isBigInt(self: Context, val: Value) bool
    pub inline fn getPrototype(self: Context, val: Value) Value
    pub inline fn setPrototype(self: Context, obj: Value, proto: Value) !void
    pub inline fn getProxyTarget(self: Context, proxy: Value) Value
    pub inline fn getProxyHandler(self: Context, proxy: Value) Value
    pub inline fn throwError(self: Context) Value
    pub inline fn throwTypeError(self: Context, fmt: [*:0]const u8) Value
    pub inline fn throwSyntaxError(self: Context, fmt: [*:0]const u8) Value
    pub inline fn throwReferenceError(self: Context, fmt: [*:0]const u8) Value
    pub inline fn throwRangeError(self: Context, fmt: [*:0]const u8) Value
    pub inline fn throwInternalError(self: Context, fmt: [*:0]const u8) Value
    pub inline fn throwOutOfMemory(self: Context) Value
    pub inline fn throw(self: Context, obj: Value) Value
    pub inline fn getException(self: Context) Value
    pub inline fn hasException(self: Context) bool
    pub inline fn getProperty(self: Context, obj: Value, prop: Atom) Value
    pub inline fn getPropertyStr(self: Context, obj: Value, prop: []const u8) Value
    pub inline fn getPropertyUint32(self: Context, obj: Value, idx: u32) Value
    pub inline fn getPropertyInt64(self: Context, obj: Value, idx: i64) Value
    pub inline fn setProperty(self: Context, obj: Value, prop: Atom, val: Value) !void
    pub inline fn setPropertyStr(self: Context, obj: Value, prop: []const u8, val: Value) !void
    pub inline fn setPropertyUint32(self: Context, obj: Value, idx: u32, val: Value) !void
    pub inline fn setPropertyInt64(self: Context, obj: Value, idx: i64, val: Value) !void
    pub inline fn hasProperty(self: Context, obj: Value, prop: Atom) !bool
    pub inline fn deleteProperty(self: Context, obj: Value, prop: Atom, flags: c_int) !bool
    pub inline fn eval(self: Context, input: []const u8, filename: []const u8, flags: EvalFlags) Value
    pub inline fn getGlobalObject(self: Context) Value
    pub inline fn isInstanceOf(self: Context, val: Value, obj: Value) !bool
    pub inline fn call(self: Context, func_obj: Value, this_obj: Value, args: []const Value) Value
    pub inline fn callConstructor(self: Context, func_obj: Value, args: []const Value) Value
    pub inline fn getArrayBuffer(self: Context, val: Value) ![]u8
    // pub inline fn newArrayBuffer(self: Context, buf: []u8, free_func: ?c.JSFreeArrayBufferDataFunc, ptr: ?*anyopaque, is_shared: bool) Value
    pub inline fn newArrayBufferCopy(self: Context, buf: []const u8) Value
    pub inline fn detachArrayBuffer(self: Context, obj: Value) void
    pub inline fn getUint8Array(self: Context, obj: Value) ![]u8
    // pub inline fn newUint8Array(self: Context, buf: []u8, free_func: ?c.JSFreeArrayBufferDataFunc, ptr: ?*anyopaque, is_shared: bool) Value
    pub inline fn newUint8ArrayCopy(self: Context, buf: []const u8) Value
    pub inline fn getTypedArrayType(self: Context, obj: Value) ?TypedArrayType
    pub inline fn getTypedArrayBuffer(self: Context, obj: Value) !struct { buffer: Value, byte_offset: usize, byte_length: usize, bytes_per_element: usize }
    pub inline fn promiseState(self: Context, promise: Value) PromiseState
    pub inline fn promiseResult(self: Context, promise: Value) Value
    pub inline fn parseJSON(self: Context, buf: []const u8, filename: []const u8) Value
    pub inline fn jsonStringify(self: Context, obj: Value, replacer: Value, space: Value) Value
    pub inline fn newAtom(self: Context, str: []const u8) Atom
    pub inline fn newAtomUint32(self: Context, n: u32) Atom
    pub inline fn dupAtom(self: Context, atom: Atom) Atom
    pub inline fn freeAtom(self: Context, atom: Atom) void
    pub inline fn atomToValue(self: Context, atom: Atom) Value
    pub inline fn atomToString(self: Context, atom: Atom) Value
    pub inline fn atomToCString(self: Context, atom: Atom) ?[*:0]const u8
    pub inline fn valueToAtom(self: Context, val: Value) Atom
    // pub inline fn getOwnPropertyNames(self: Context, obj: Value, flags: PropertyEnumFlags) ![]c.JSPropertyEnum
    // pub inline fn freePropertyEnum(self: Context, tab: []c.JSPropertyEnum) void
    pub inline fn getOwnProperty(self: Context, obj: Value, prop: Atom) !PropertyDescriptor
    pub inline fn isExtensible(self: Context, obj: Value) !bool
    pub inline fn preventExtensions(self: Context, obj: Value) !bool
    pub inline fn defineProperty(self: Context, obj: Value, prop: Atom, val: Value, getter: Value, setter: Value, flags: PropertyFlags) !bool
    pub inline fn definePropertyValue(self: Context, obj: Value, prop: Atom, val: Value, flags: PropertyFlags) !bool
    pub inline fn definePropertyValueStr(self: Context, obj: Value, prop: []const u8, val: Value, flags: PropertyFlags) !bool
    pub inline fn definePropertyValueUint32(self: Context, obj: Value, idx: u32, val: Value, flags: PropertyFlags) !bool
    pub inline fn definePropertyGetSet(self: Context, obj: Value, prop: Atom, getter: Value, setter: Value, flags: PropertyFlags) !bool
    pub inline fn setOpaque(_: Context, obj: Value, ptr: ?*anyopaque) !void
    pub inline fn getOpaque(_: Context, obj: Value, class_id: ClassID) ?*anyopaque
    pub inline fn getOpaque2(self: Context, obj: Value, class_id: ClassID) ?*anyopaque
    pub inline fn setClassProto(self: Context, class_id: ClassID, proto: Value) void
    pub inline fn getClassProto(self: Context, class_id: ClassID) Value
    pub inline fn getFunctionProto(self: Context) Value
    pub inline fn addIntrinsicBaseObjects(self: Context) void
    pub inline fn addIntrinsicDate(self: Context) void
    pub inline fn addIntrinsicEval(self: Context) void
    pub inline fn addIntrinsicRegExpCompiler(self: Context) void
    pub inline fn addIntrinsicRegExp(self: Context) void
    pub inline fn addIntrinsicJSON(self: Context) void
    pub inline fn addIntrinsicProxy(self: Context) void
    pub inline fn addIntrinsicMapSet(self: Context) void
    pub inline fn addIntrinsicTypedArrays(self: Context) void
    pub inline fn addIntrinsicPromise(self: Context) void
    pub inline fn addIntrinsicBigInt(self: Context) void
    pub inline fn addIntrinsicWeakRef(self: Context) void
    pub inline fn addPerformance(self: Context) void
    // pub inline fn newCFunction(self: Context, func: c.JSCFunction, name: []const u8, length: c_int) Value
    // pub inline fn newCFunction2(self: Context, func: c.JSCFunction, name: []const u8, length: c_int, cproto: c.JSCFunctionEnum, magic: c_int) Value
    // pub inline fn newCFunctionMagic(self: Context, func: c.JSCFunctionMagic, name: []const u8, length: c_int, cproto: c.JSCFunctionEnum, magic: c_int) Value
    pub inline fn setConstructor(self: Context, func_obj: Value, proto: Value) void
    pub inline fn setConstructorBit(self: Context, func_obj: Value, val: bool) bool
    // pub inline fn newCFunctionData(self: Context, func: c.JSCFunctionData, length: c_int, magic: c_int, data: []const Value) Value
    pub inline fn getModuleNamespace(self: Context, m: Module) Value
    pub inline fn getModuleName(self: Context, m: Module) Atom
    pub inline fn getImportMeta(self: Context, m: Module) Value
    pub inline fn resolveModule(self: Context, obj: Value) !void
    pub inline fn evalFunction(self: Context, fun_obj: Value) Value
    pub inline fn getScriptOrModuleName(self: Context, n_stack_levels: i32) Atom
    pub inline fn loadModule(self: Context, basename: ?[]const u8, filename: []const u8) Value
    // pub inline fn newCModule(self: Context, name: []const u8, func: c.JSModuleInitFunc) ?Module
    pub inline fn addModuleExport(self: Context, m: Module, name: []const u8) !void
    pub inline fn setModuleExport(self: Context, m: Module, name: []const u8, val: Value) !void
    // pub inline fn enqueueJob(self: Context, job_func: c.JSJobFunc, args: []const Value) !void
    pub inline fn writeObject(self: Context, obj: Value, flags: WriteObjectFlags) ![]u8
    pub inline fn readObject(self: Context, buf: []const u8, flags: ReadObjectFlags) Value
    pub inline fn malloc(self: Context, size: usize) ?*anyopaque
    pub inline fn calloc(self: Context, count: usize, size: usize) ?*anyopaque
    pub inline fn free(self: Context, ptr: ?*anyopaque) void
    pub inline fn realloc(self: Context, ptr: ?*anyopaque, size: usize) ?*anyopaque
    pub inline fn mallocz(self: Context, size: usize) ?*anyopaque
    pub inline fn strdup(self: Context, str: []const u8) ?[*:0]u8
    pub inline fn strndup(self: Context, str: []const u8, n: usize) ?[*:0]u8
    pub inline fn mallocUsableSize(self: Context, ptr: ?*const anyopaque) usize
};
```
