import fs from "node:fs";

import { Module } from "./wasi-minimal.mjs";

const wasi = new Module({
  env: {},
  args: [],
  fds: [
    { type: 2, handle: fs },
    { type: 2, handle: fs },
    { type: 2, handle: fs },
  ],
});

const source = fs.readFileSync("./zig-out/bin/quickjs.wasm");

export const module = await WebAssembly.instantiate(source, {
  wasi_snapshot_preview1: wasi.exports,
  env: {
    print: (ptr: number, len: number) => {
      // const { buffer } = module.instance.exports.memory as WebAssembly.Memory;
      const message = new TextDecoder().decode(
        new Uint8Array(memory.buffer, ptr, len),
      );

      console.log(message);
    },
    throwError: (ptr: number, len: number) => {
      // const { buffer } = module.instance.exports.memory as WebAssembly.Memory;
      const message = new TextDecoder().decode(
        new Uint8Array(memory.buffer, ptr, len),
      );

      throw new Error(message);
    },
  },
});

export const exports = module.instance.exports as Record<string, Function>;
export const memory = module.instance.exports.memory as WebAssembly.Memory;

wasi.memory = memory;
