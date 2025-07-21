import assert from "node:assert";

import { Runtime, Context } from "./test-lib.mjs";

{
  using runtime = new Runtime();
  console.log("got runtime", runtime);

  runtime.setMemoryLimit(64 * 1024);
  const limit = runtime.getGCThreshold();
  runtime.setGCThreshold(limit * 2);
  assert(runtime.getGCThreshold() === limit * 2);

  using context = new Context(runtime);
  console.log("got context", context);

  using t = context.newBoolean(false);
  console.log("got bool", t, t.getBoolean());

  using i = context.newInt32(-10);
  console.log("getInt32(-10)", i.getInt32());
  console.log("getFloat64(-10)", i.getFloat64());

  using j = context.newFloat64(Math.PI);
  console.log("getFloat64(Math.PI)", j.getFloat64());

  using k = context.newString("hello world!");
  console.log("getString()", k.getString());

  using o = context.newObject();
  console.log("got object", o);

  using res = context.eval("(9 + 2 * 3)");
  console.log("res", res, res.getFloat64());
}

// const context_ptr = exports.JS_NewContext(runtime_ptr);
// console.log("got context ptr", context_ptr);

// const input = "(1 + 2 * 3)";
// const input_ptr = exports.alloc(input.length);
// console.log("input_ptr:", input_ptr);
// new TextEncoder().encodeInto(input, new Uint8Array(exports.memory, input_ptr));

// const result = exports.JS_Eval(context_ptr, input_ptr, input.length, 0, 0);
// // console.log("RESULT", result, exports.JS_IsNumber(result));
// // if (exports.JS_IsException(result)) {
// //   return error.Exception;
// // } else {
// //   return result;
// // }

// console.log(exports.sizeOfValue());
// console.log(exports.sizeOfValue64());
// console.log(exports.isException(result));
// console.log(exports.isNumber(result));
// console.log(exports.hasException(context_ptr));
// console.log(exports.getException(context_ptr));
// // console.log(exports.isNumber(result));
