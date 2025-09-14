const std = @import("std");

const quickjs = @import("quickjs");

test "Initialize a context" {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const r = try quickjs.Runtime.init(allocator);
    defer r.deinit();

    const c = quickjs.Context.init(r);
    defer c.deinit();

    // try std.testing.expectEqual(r.ptr, c.getRuntime().ptr);
}

test "Create objects and manipulate properties" {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const r = try quickjs.Runtime.init(allocator);
    defer r.deinit();

    const c = quickjs.Context.init(r);
    defer c.deinit();

    // Create a new object
    const obj = c.newObject();
    defer c.freeValue(obj);

    { // Set and get a string property
        const value = c.newString("test value");
        try c.setPropertyStr(obj, "stringProp", value);

        const retrieved_value = c.getPropertyStr(obj, "stringProp");
        defer c.freeValue(retrieved_value);
        try std.testing.expect(c.isSameValue(value, retrieved_value));

        const value_as_str = try c.toCStringLen(retrieved_value);
        defer c.freeCString(value_as_str);
        try std.testing.expectEqualSentinel(u8, 0, "test value", value_as_str);
    }

    { // Set and get a number property
        const value = c.newInt32(42);
        try c.setPropertyStr(obj, "numProp", value);

        const retrieved_value = c.getPropertyStr(obj, "numProp");
        defer c.freeValue(retrieved_value);
        try std.testing.expect(c.isNumber(retrieved_value));

        const value_as_int = try c.toInt32(retrieved_value);
        try std.testing.expectEqual(@as(i32, 42), value_as_int);
    }

    { // Set and get a boolean property
        const value = c.newBool(true);
        try c.setPropertyStr(obj, "boolProp", value);

        const retrieved_value = c.getPropertyStr(obj, "boolProp");
        defer c.freeValue(retrieved_value);
        try std.testing.expect(c.isBool(retrieved_value));

        const value_as_bool = try c.toBool(retrieved_value);
        try std.testing.expectEqual(@as(bool, true), value_as_bool);
    }
}

test "Array creation and manipulation" {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const r = try quickjs.Runtime.init(allocator);
    defer r.deinit();

    const c = quickjs.Context.init(r);
    defer c.deinit();

    // Create an array
    const arr = c.newArray();
    defer c.freeValue(arr);

    try std.testing.expect(c.isArray(arr));

    // Add elements to the array
    for (0..5) |i| {
        const val = c.newInt32(@intCast(i * 10));
        try c.setPropertyUint32(arr, @intCast(i), val);
    }

    // Read back array elements
    for (0..5) |i| {
        const val = c.getPropertyUint32(arr, @intCast(i));
        defer c.freeValue(val);

        const numVal = try c.toInt32(val);
        try std.testing.expectEqual(@as(i32, @intCast(i * 10)), numVal);
    }
}

test "Object property existence and deletion" {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const r = try quickjs.Runtime.init(allocator);
    defer r.deinit();

    const c = quickjs.Context.init(r);
    defer c.deinit();

    // Create an object
    const obj = c.newObject();
    defer c.freeValue(obj);

    // Set a property
    const val = c.newString("test");
    try c.setPropertyStr(obj, "testProp", val);

    // Check property existence using atom API
    const propAtom = c.newAtom("testProp");
    defer c.freeAtom(propAtom);

    const exists = try c.hasProperty(obj, propAtom);
    try std.testing.expect(exists);

    // Delete the property
    _ = try c.deleteProperty(obj, propAtom, 0);

    // Verify it no longer exists
    const afterDelete = try c.hasProperty(obj, propAtom);
    try std.testing.expect(!afterDelete);
}

test "Value type checking" {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const r = try quickjs.Runtime.init(allocator);
    defer r.deinit();

    const c = quickjs.Context.init(r);
    defer c.deinit();

    const strVal = c.newString("test string");
    defer c.freeValue(strVal);
    try std.testing.expect(c.isString(strVal));
    try std.testing.expect(!c.isNumber(strVal));

    const numVal = c.newInt32(42);
    defer c.freeValue(numVal);
    try std.testing.expect(c.isNumber(numVal));
    try std.testing.expect(!c.isString(numVal));

    const objVal = c.newObject();
    defer c.freeValue(objVal);
    try std.testing.expect(c.isObject(objVal));
    try std.testing.expect(!c.isArray(objVal));

    const arrVal = c.newArray();
    defer c.freeValue(arrVal);
    try std.testing.expect(c.isArray(arrVal));
    try std.testing.expect(c.isObject(arrVal)); // Arrays are also objects
}

test "JavaScript evaluation" {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const r = try quickjs.Runtime.init(allocator);
    defer r.deinit();

    const c = quickjs.Context.init(r);
    defer c.deinit();

    // Basic expression evaluation
    const result1 = try c.eval("40 + 2", "test.js", .{});
    defer c.freeValue(result1);
    try std.testing.expect(c.isNumber(result1));
    try std.testing.expectEqual(@as(i32, 42), try c.toInt32(result1));

    // Object creation in JS
    const result2 = try c.eval("({a: 1, b: 'test'})", "test.js", .{});
    defer c.freeValue(result2);
    try std.testing.expect(c.isObject(result2));

    // Check object property
    const propValue = c.getPropertyStr(result2, "b");
    defer c.freeValue(propValue);
    try std.testing.expect(c.isString(propValue));

    // Array creation in JS
    const result3 = try c.eval("[1, 2, 3, 4, 5]", "test.js", .{});
    defer c.freeValue(result3);
    try std.testing.expect(c.isArray(result3));

    // Access array element
    const element = c.getPropertyUint32(result3, 2);
    defer c.freeValue(element);
    try std.testing.expect(c.isNumber(element));
    try std.testing.expectEqual(@as(i32, 3), try c.toInt32(element));
}

test "JavaScript function creation and calling" {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const r = try quickjs.Runtime.init(allocator);
    defer r.deinit();

    const c = quickjs.Context.init(r);
    defer c.deinit();

    // Define a function in JavaScript
    const jsFn = try c.eval("function add(a, b) { return a + b; }; add", "test.js", .{});
    defer c.freeValue(jsFn);

    try std.testing.expect(c.isFunction(jsFn));

    // Call the function
    var args: [2]quickjs.Value = undefined;
    args[0] = c.newInt32(40);
    args[1] = c.newInt32(2);

    const this_val = quickjs.NULL; // No this value needed
    const result = c.call(jsFn, this_val, &args);
    defer c.freeValue(result);

    try std.testing.expect(c.isNumber(result));
    try std.testing.expectEqual(@as(i32, 42), try c.toInt32(result));

    // Check undefined for missing arguments
    const global = c.getGlobalObject();
    defer c.freeValue(global);

    _ = try c.eval("function testArgs(a, b) { return [a, b]; }", "test.js", .{});
    const testFn = c.getPropertyStr(global, "testArgs");
    defer c.freeValue(testFn);

    var single_arg: [1]quickjs.Value = undefined;
    single_arg[0] = c.newInt32(123);

    const result2 = c.call(testFn, this_val, &single_arg);
    defer c.freeValue(result2);

    try std.testing.expect(c.isArray(result2));

    const first = c.getPropertyUint32(result2, 0);
    defer c.freeValue(first);
    try std.testing.expectEqual(@as(i32, 123), try c.toInt32(first));

    const second = c.getPropertyUint32(result2, 1);
    defer c.freeValue(second);
    try std.testing.expect(c.isUndefined(second));
}

test "Value conversion roundtrip tests" {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const r = try quickjs.Runtime.init(allocator);
    defer r.deinit();

    const c = quickjs.Context.init(r);
    defer c.deinit();

    // Test integer conversion roundtrip
    const int32_val = c.newInt32(42);
    defer c.freeValue(int32_val);
    const int32_result = try c.toInt32(int32_val);
    try std.testing.expectEqual(@as(i32, 42), int32_result);

    // Test uint32 conversion roundtrip
    const uint32_val = c.newUint32(4294967295); // max uint32
    defer c.freeValue(uint32_val);
    const uint32_result = try c.toUint32(uint32_val);
    try std.testing.expectEqual(@as(u32, 4294967295), uint32_result);

    // Test int64 conversion roundtrip
    const max_safe_int = (1 << 53) - 1;
    const int64_val = c.newInt64(max_safe_int); // max int64
    defer c.freeValue(int64_val);
    const int64_result = try c.toInt64(int64_val);
    try std.testing.expectEqual(@as(i64, max_safe_int), int64_result);

    // Test float64 conversion roundtrip
    const float64_val = c.newFloat64(3.14159265359);
    defer c.freeValue(float64_val);
    const float64_result = try c.toFloat64(float64_val);
    try std.testing.expectApproxEqAbs(@as(f64, 3.14159265359), float64_result, 0.0000000001);

    // Test string conversion roundtrip using toCString
    const test_str = "Hello, QuickJS!";
    const str_val = c.newString(test_str);
    defer c.freeValue(str_val);

    const c_str = try c.toCString(str_val);
    defer c.freeCString(c_str);

    const slice = std.mem.span(c_str);
    try std.testing.expectEqualStrings(test_str, slice);

    // Test boolean conversion roundtrip
    const bool_val = c.newBool(true);
    defer c.freeValue(bool_val);
    const bool_result = try c.toBool(bool_val);
    try std.testing.expectEqual(true, bool_result);
}

test "Atom API" {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const r = try quickjs.Runtime.init(allocator);
    defer r.deinit();

    const c = quickjs.Context.init(r);
    defer c.deinit();

    // Create atom from string
    const atom = c.newAtom("testProperty");
    defer c.freeAtom(atom);

    // Convert atom to value
    const atom_value = c.atomToValue(atom);
    defer c.freeValue(atom_value);
    try std.testing.expect(c.isString(atom_value));

    // Convert atom to string
    const atom_string = c.atomToString(atom);
    defer c.freeValue(atom_string);
    try std.testing.expect(c.isString(atom_string));

    // Test atom C string conversion
    const atom_cstr = try c.atomToCString(atom);
    defer c.freeCString(atom_cstr);
    const atom_slice = std.mem.span(atom_cstr);
    try std.testing.expectEqualStrings("testProperty", atom_slice);

    // Create atom from uint32
    const num_atom = c.newAtomUint32(42);
    defer c.freeAtom(num_atom);

    // Test atom duplication
    const dup_atom = c.dupAtom(atom);
    defer c.freeAtom(dup_atom);

    // Test valueToAtom
    const str_val = c.newString("testProperty");
    defer c.freeValue(str_val);
    const val_atom = c.valueToAtom(str_val);
    defer c.freeAtom(val_atom);
}

test "Error handling" {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const r = try quickjs.Runtime.init(allocator);
    defer r.deinit();

    const c = quickjs.Context.init(r);
    defer c.deinit();

    // Generate a syntax error
    try std.testing.expectError(error.Exception, c.eval("function(){", "test.js", .{}));
    try std.testing.expect(c.hasException());

    // Get the exception
    const exception = c.getException();
    defer c.freeValue(exception);
    try std.testing.expect(c.isError(exception));

    // Create custom errors
    const type_error = c.throwTypeError("Test type error");
    defer c.freeValue(type_error);

    const range_error = c.throwRangeError("Test range error");
    defer c.freeValue(range_error);

    const ref_error = c.throwReferenceError("Test reference error");
    defer c.freeValue(ref_error);

    // Test try/catch in JS
    const try_catch_result = try c.eval(
        \\(function() {
        \\  try {
        \\    throw new Error('Test error');
        \\  } catch (e) {
        \\    return e.message;
        \\  }
        \\})()
    , "test.js", .{});
    defer c.freeValue(try_catch_result);

    try std.testing.expect(c.isString(try_catch_result));
    const c_str = try c.toCString(try_catch_result);
    defer c.freeCString(c_str);
    const str_slice = std.mem.span(c_str);
    try std.testing.expectEqualStrings("Test error", str_slice);
}

test "ArrayBuffer and TypedArray support" {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const r = try quickjs.Runtime.init(allocator);
    defer r.deinit();

    const c = quickjs.Context.init(r);
    defer c.deinit();

    // Create a buffer of bytes
    var test_data = [_]u8{ 1, 2, 3, 4, 5 };

    // Create an ArrayBuffer
    const array_buffer = c.newArrayBufferCopy(&test_data);
    defer c.freeValue(array_buffer);

    try std.testing.expect(c.isArrayBuffer(array_buffer));

    // Get buffer content
    const buffer_content = try c.getArrayBuffer(array_buffer);
    try std.testing.expectEqual(@as(usize, 5), buffer_content.len);
    try std.testing.expectEqual(@as(u8, 1), buffer_content[0]);
    try std.testing.expectEqual(@as(u8, 5), buffer_content[4]);

    // Create a Uint8Array
    const uint8_array = c.newUint8ArrayCopy(&test_data);
    defer c.freeValue(uint8_array);

    // Get Uint8Array content
    const array_content = try c.getUint8Array(uint8_array);
    try std.testing.expectEqual(@as(usize, 5), array_content.len);
    try std.testing.expectEqual(@as(u8, 1), array_content[0]);
    try std.testing.expectEqual(@as(u8, 5), array_content[4]);

    // Test creating from JS
    const js_array = try c.eval("new Uint8Array([10, 20, 30, 40, 50])", "test.js", .{});
    defer c.freeValue(js_array);

    const js_array_content = try c.getUint8Array(js_array);
    try std.testing.expectEqual(@as(usize, 5), js_array_content.len);
    try std.testing.expectEqual(@as(u8, 10), js_array_content[0]);
    try std.testing.expectEqual(@as(u8, 50), js_array_content[4]);
}

test "JSON functions" {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const r = try quickjs.Runtime.init(allocator);
    defer r.deinit();

    const c = quickjs.Context.init(r);
    defer c.deinit();

    // Test JSON.parse via parseJSON
    const json_str = "{\"name\":\"test\",\"value\":42,\"nested\":{\"arr\":[1,2,3]}}";
    const parsed = c.parseJSON(json_str, "test.json");
    defer c.freeValue(parsed);

    try std.testing.expect(c.isObject(parsed));

    const name_prop = c.getPropertyStr(parsed, "name");
    defer c.freeValue(name_prop);
    try std.testing.expect(c.isString(name_prop));

    // Test JSON.stringify via jsonStringify
    const obj = try c.eval("({a: 1, b: \"test\", c: [1,2,3]})", "test.js", .{});
    defer c.freeValue(obj);

    const null_val = quickjs.NULL;
    const undefined_val = quickjs.UNDEFINED;

    const stringified = c.jsonStringify(obj, null_val, undefined_val);
    defer c.freeValue(stringified);

    try std.testing.expect(c.isString(stringified));

    const c_str = try c.toCString(stringified);
    defer c.freeCString(c_str);

    const str_slice = std.mem.span(c_str);
    try std.testing.expectEqualStrings("{\"a\":1,\"b\":\"test\",\"c\":[1,2,3]}", str_slice);
}

test "Object prototype operations" {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const r = try quickjs.Runtime.init(allocator);
    defer r.deinit();

    const c = quickjs.Context.init(r);
    defer c.deinit();

    // Create objects
    const obj = c.newObject();
    defer c.freeValue(obj);

    const proto = c.newObject();
    defer c.freeValue(proto);

    // Set property on prototype
    const test_val = c.newString("from prototype");
    try c.setPropertyStr(proto, "testProp", test_val);

    // Set prototype
    try c.setPrototype(obj, proto);

    // Get prototype
    const retrieved_proto = c.getPrototype(obj);
    defer c.freeValue(retrieved_proto);

    // Verify prototype property is accessible from object
    const inherited_prop = c.getPropertyStr(obj, "testProp");
    defer c.freeValue(inherited_prop);

    try std.testing.expect(c.isString(inherited_prop));

    // Test Object.defineProperty style API
    const new_prop = c.newString("direct property");
    const atom = c.newAtom("newProp");
    defer c.freeAtom(atom);

    _ = try c.definePropertyValue(obj, atom, new_prop, .{
        // .configurable = true,
        // .writable = true,
        // .enumerable = true,
        // .has_configurable = true,
        // .has_writable = true,
        // .has_enumerable = true,
        // .has_value = true,
    });

    const defined_prop = c.getPropertyStr(obj, "newProp");
    defer c.freeValue(defined_prop);

    try std.testing.expect(c.isString(defined_prop));
}

// test "getOwnPropertyNames and property enumeration" {
//     const r = quickjs.Runtime.init();
//     defer r.deinit();

//     const c = quickjs.Context.init(r);
//     defer c.deinit();

//     // Create an object with various properties
//     const obj = try c.eval(
//         \\({
//         \\  numProp: 42,
//         \\  strProp: "test",
//         \\  objProp: { nested: true },
//         \\  [Symbol.for('symbolProp')]: 'symbol value',
//         \\})
//     , "test.js", .{});
//     defer c.freeValue(obj);

//     // Get own property names (only strings, not symbols)
//     const props = try c.getOwnPropertyNames(obj, .{
//         .strings = true,
//         .symbols = false,
//     });
//     defer c.freePropertyEnum(props);

//     // There should be 3 string properties
//     try std.testing.expectEqual(@as(usize, 3), props.len);

//     // Check individual properties by converting atoms to strings
//     var found_num_prop = false;
//     var found_str_prop = false;
//     var found_obj_prop = false;

//     for (props) |prop| {
//         const prop_str = c.atomToString(prop.atom);
//         defer c.freeValue(prop_str);

//         const c_str = c.toCString(prop_str) orelse return error.InvalidString;
//         defer c.freeCString(c_str);

//         const str = std.mem.span(c_str);

//         if (std.mem.eql(u8, str, "numProp")) {
//             found_num_prop = true;
//         } else if (std.mem.eql(u8, str, "strProp")) {
//             found_str_prop = true;
//         } else if (std.mem.eql(u8, str, "objProp")) {
//             found_obj_prop = true;
//         }
//     }

//     try std.testing.expect(found_num_prop);
//     try std.testing.expect(found_str_prop);
//     try std.testing.expect(found_obj_prop);

//     // Now get all properties including symbols
//     const all_props = try c.getOwnPropertyNames(obj, .{
//         .strings = true,
//         .symbols = true,
//     });
//     defer c.freePropertyEnum(all_props);

//     // std.log.warn("@sizeOf(@TypeOf(all_props[0])): {d}", .{@sizeOf(@TypeOf(all_props[0]))});
//     // std.log.warn("@sizeOf(quickjs.Context.PropertyEnum): {d}", .{@sizeOf(quickjs.Context.PropertyEnum)});
//     comptime {
//         std.debug.assert(@sizeOf(@TypeOf(all_props[0])) == @sizeOf(quickjs.Context.PropertyEnum));
//     }

//     // There should be 4 properties (3 strings + 1 symbol)
//     try std.testing.expectEqual(@as(usize, 4), all_props.len);

//     // Test property descriptor by getting one property's descriptor
//     const name_atom = c.newAtom("strProp");
//     defer c.freeAtom(name_atom);

//     const desc = try c.getOwnProperty(obj, name_atom);

//     // The property should have a string value
//     try std.testing.expect(c.isString(desc.value));

//     // The property should be enumerable by default
//     try std.testing.expect(desc.flags.enumerable);
// }
