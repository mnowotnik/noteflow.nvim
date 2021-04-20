import commonjs from "@rollup/plugin-commonjs";
import typescript from "@rollup/plugin-typescript";
import css from "rollup-plugin-css-only";
import svelte from "rollup-plugin-svelte";
import resolve from "@rollup/plugin-node-resolve";

const production = !process.env.ROLLUP_WATCH;

export default {
  input: "src/main.ts",
  output: {
    format: "iife",
    name: "app",
    file: "public/app.js",
  },
  plugins: [
    svelte({
      compilerOptions: {
        dev: !production,
      },
    }),
    css({ output: "bundle.css" }),
    resolve({
      browser: true,
      dedupe: ["svelte"],
    }),
    commonjs(),
    typescript({
      sourceMap: !production,
      inlineSources: !production,
    }),
  ],
  watch: {
    clearScreen: false,
  },
};
