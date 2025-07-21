import assert from "node:assert";

import { module, exports, memory } from "./test-mod.mjs";

export class Runtime {
  #ptr: number;
  #live: boolean;

  constructor() {
    this.#ptr = exports.newRuntime();
    this.#live = this.#ptr !== 0;
  }

  get ptr() {
    return this.#ptr;
  }

  [Symbol.dispose]() {
    this.free();
  }

  free() {
    assert(this.#live, "runtime not alive");
    this.#live = false;
    exports.JS_FreeRuntime(this.#ptr);
  }

  setMemoryLimit(limit: number) {
    assert(this.#live, "runtime not alive");
    exports.JS_SetMemoryLimit(limit);
  }

  setGCThreshold(limit: number) {
    assert(this.#live, "runtime not alive");
    exports.JS_SetGCThreshold(this.#ptr, limit);
  }

  getGCThreshold() {
    assert(this.#live, "runtime not alive");
    return exports.JS_GetGCThreshold(this.#ptr);
  }

  setMaxStackSize(size: number) {
    assert(this.#live, "runtime not alive");
    exports.JS_SetMaxStackSize(this.#ptr, size);
  }

  runGC() {
    assert(this.#live, "runtime not alive");
    exports.JS_RunGC(this.#ptr);
  }
}

const intrinsics = {
  BaseObjects: exports.JS_AddIntrinsicBaseObjects,
  Date: exports.JS_AddIntrinsicDate,
  Eval: exports.JS_AddIntrinsicEval,
  RegExpCompiler: exports.JS_AddIntrinsicRegExpCompiler,
  RegExp: exports.JS_AddIntrinsicRegExp,
  JSON: exports.JS_AddIntrinsicJSON,
  Proxy: exports.JS_AddIntrinsicProxy,
  MapSet: exports.JS_AddIntrinsicMapSet,
  TypedArrays: exports.JS_AddIntrinsicTypedArrays,
  Promise: exports.JS_AddIntrinsicPromise,
  BigInt: exports.JS_AddIntrinsicBigInt,
  WeakRef: exports.JS_AddIntrinsicWeakRef,
  Performance: exports.JS_AddPerformance,
};

const TAG = {
  FIRST: (module.instance.exports.TAG_FIRST as WebAssembly.Global).value,
  BIG_INT: (module.instance.exports.TAG_BIG_INT as WebAssembly.Global).value,
  SYMBOL: (module.instance.exports.TAG_SYMBOL as WebAssembly.Global).value,
  STRING: (module.instance.exports.TAG_STRING as WebAssembly.Global).value,
  MODULE: (module.instance.exports.TAG_MODULE as WebAssembly.Global).value,
  FUNCTION_BYTECODE: (
    module.instance.exports.TAG_FUNCTION_BYTECODE as WebAssembly.Global
  ).value,
  OBJECT: (module.instance.exports.TAG_OBJECT as WebAssembly.Global).value,
  INT: (module.instance.exports.TAG_INT as WebAssembly.Global).value,
  BOOL: (module.instance.exports.TAG_BOOL as WebAssembly.Global).value,
  NULL: (module.instance.exports.TAG_NULL as WebAssembly.Global).value,
  UNDEFINED: (module.instance.exports.TAG_UNDEFINED as WebAssembly.Global)
    .value,
  UNINITIALIZED: (
    module.instance.exports.TAG_UNINITIALIZED as WebAssembly.Global
  ).value,
  CATCH_OFFSET: (module.instance.exports.TAG_CATCH_OFFSET as WebAssembly.Global)
    .value,
  EXCEPTION: (module.instance.exports.TAG_EXCEPTION as WebAssembly.Global)
    .value,
  SHORT_BIG_INT: (
    module.instance.exports.TAG_SHORT_BIG_INT as WebAssembly.Global
  ).value,
  FLOAT64: (module.instance.exports.TAG_FLOAT64 as WebAssembly.Global).value,
};

export class Context {
  #runtime: Runtime;
  #ptr: number;
  #live: boolean;

  constructor(
    runtime: Runtime,
    options: Record<keyof typeof intrinsics, boolean> | null = null,
  ) {
    this.#runtime = runtime;

    if (options) {
      this.#ptr = exports.JS_NewContextRaw(runtime.ptr);
      for (const [name, handle] of Object.entries(intrinsics)) {
        if (options[name as keyof typeof intrinsics]) {
          handle(this.#ptr);
        }
      }
    } else {
      this.#ptr = exports.JS_NewContext(runtime.ptr);
    }

    this.#live = this.#ptr !== 0;
  }

  get runtime() {
    return this.#runtime;
  }

  get ptr() {
    return this.#ptr;
  }

  [Symbol.dispose]() {
    this.free();
  }

  free() {
    assert(this.#live, "context not alive");
    this.#live = false;
    exports.JS_FreeContext(this.#ptr);
  }

  hasException() {
    assert(this.#live, "context not alive");
    return Boolean(exports.JS_HasException(this.#ptr));
  }

  isEqual(a: Value, b: Value) {
    assert(this.#live, "context not alive");
    exports.JS_IsEqual(this.#ptr, a.ref, b.ref);
  }

  isStrictEqual(a: Value, b: Value) {
    assert(this.#live, "context not alive");
    exports.JS_IsStrictEqual(this.#ptr, a.ref, b.ref);
  }

  isSameValue(a: Value, b: Value) {
    assert(this.#live, "context not alive");
    exports.JS_IsSameValue(this.#ptr, a.ref, b.ref);
  }

  /** Similar to same-value equality, but +0 and -0 are considered equal. */
  isSameValueZero(a: Value, b: Value) {
    assert(this.#live, "context not alive");
    exports.JS_IsSameValueZero(this.#ptr, a.ref, b.ref);
  }

  newBoolean(value: boolean) {
    assert(this.#live, "context not alive");
    return new Value(this, exports.newBool(this.#ptr, value));
  }

  newInt32(value: number) {
    assert(this.#live, "context not alive");
    return new Value(this, exports.newInt32(this.#ptr, value));
  }

  newFloat64(value: number) {
    assert(this.#live, "context not alive");
    return new Value(this, exports.newFloat64(this.#ptr, value));
  }

  newNumber(value: number) {
    assert(this.#live, "context not alive");
    return new Value(this, exports.newFloat64(this.#ptr, value));
  }

  newString(value: string) {
    assert(this.#live, "context not alive");
    const data = new TextEncoder().encode(value);
    const ptr = exports.alloc(data.byteLength);
    new Uint8Array(memory.buffer, ptr, data.byteLength).set(data);
    return new Value(this, exports.newString(this.#ptr, ptr, data.byteLength));
  }

  newObject() {
    return new Value(this, exports.JS_NewObject(this.#ptr));
  }

  eval(code: string) {
    const input = new TextEncoder().encode(code);
    const inputPtr = exports.alloc(input.length);
    new Uint8Array(memory.buffer, inputPtr, input.length).set(input);
    const filename = 0;
    const evalFlags = 0;
    return new Value(
      this,
      exports.JS_Eval(this.#ptr, inputPtr, code.length, filename, evalFlags),
    );
  }
}

export class Value {
  #context: Context;
  #ref: bigint;
  #tag: number;
  #live: boolean;

  constructor(context: Context, ref: bigint) {
    this.#context = context;
    this.#tag = exports.getTag(ref);
    this.#ref = ref;
    this.#live = true;
  }

  get context() {
    return this.#context;
  }

  get tag() {
    return this.#tag;
  }

  get ref() {
    return this.#ref;
  }

  [Symbol.dispose]() {
    this.free();
  }

  free() {
    assert(this.#live, "value not alive");
    this.#live = false;
    exports.JS_FreeValue(this.#context.ptr, this.#ref);
  }

  typeof() {
    switch (this.tag) {
      case TAG.BIG_INT:
      case TAG.SHORT_BIG_INT:
        return "bigint";
      case TAG.SYMBOL:
        return "symbol";
      case TAG.STRING:
        return "string";
      case TAG.NULL:
      case TAG.MODULE:
      case TAG.FUNCTION_BYTECODE:
      case TAG.OBJECT:
        return "object";
      case TAG.INT:
      case TAG.FLOAT64:
        return "number";
      case TAG.BOOL:
        return "boolean";
      case TAG.UNDEFINED:
      case TAG.UNINITIALIZED:
        return "undefined";
      default:
        throw new Error("invalid value");
    }
  }

  isBoolean() {
    return this.tag === TAG.BOOL;
  }

  isNumber() {
    return this.tag === TAG.INT || this.tag === TAG.FLOAT64;
  }

  isInt32() {
    return this.tag === TAG.INT;
  }

  isFloat64() {
    return this.tag === TAG.FLOAT64;
  }

  isBigInt() {
    return this.tag === TAG.BIG_INT || this.tag === TAG.SHORT_BIG_INT;
  }

  isNull() {
    return this.tag === TAG.NULL;
  }

  isUndefined() {
    return this.tag === TAG.UNDEFINED;
  }

  isException() {
    return this.tag === TAG.EXCEPTION;
  }

  isUninitialized() {
    return this.tag === TAG.UNINITIALIZED;
  }

  isString() {
    return this.tag === TAG.STRING;
  }

  isSymbol() {
    return this.tag === TAG.SYMBOL;
  }

  isObject() {
    return this.tag === TAG.OBJECT;
  }

  isFunction() {
    return this.tag === TAG.FUNCTION_BYTECODE;
  }

  isModule() {
    return this.tag === TAG.MODULE;
  }

  getBoolean() {
    assert(this.#live, "value not alive");
    const ret = exports.JS_ToBool(this.#context.ptr, this.#ref);
    assert(ret !== -1, "failed to get boolean value");
    return Boolean(ret);
  }

  getInt32() {
    assert(this.#live, "value not alive");
    return exports.getInt32(this.#context.ptr, this.#ref);
  }

  getFloat64() {
    assert(this.#live, "value not alive");
    return exports.getFloat64(this.#context.ptr, this.#ref);
  }

  getNumber() {
    assert(this.#live, "value not alive");
    return exports.getFloat64(this.#context.ptr, this.#ref);
  }

  getString() {
    assert(this.#live, "value not alive");
    const str = exports.getStringRef(this.#context.ptr, this.#ref);
    const len = Number(str >> 32n);
    const ptr = Number(str & 0xffffffffn);
    return new TextDecoder().decode(new Uint8Array(memory.buffer, ptr, len));
  }
}
