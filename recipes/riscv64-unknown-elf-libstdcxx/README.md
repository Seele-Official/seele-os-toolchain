# riscv64-unknown-elf-libstdcxx

Recipe for the freestanding `libstdc++` headers matching `riscv64-unknown-elf-gcc ==16.2.0`:

- Generated from GCC 16.2.0 sources with `--disable-hosted-libstdcxx` and `--without-headers`
- Headers only: no `libstdc++.a`, no `libsupc++`, and no C library headers
- Installs into `riscv64-unknown-elf/include/c++/16.2.0`, on the cross compiler's default C++ include search path
- Pins `riscv64-unknown-elf-gcc ==16.2.0` at build and run time

## Build

From the repository root:

```bash
pixi run build-libstdcxx
```

The build takes roughly 3–4 minutes and stages the `.conda` package in `dist/linux-64/`. `pixi.toml` resolves `riscv64-unknown-elf-gcc` from `../../dist` first and falls back to <https://prefix.dev/seele-official/seele-os-toolchain>, so this recipe can be built standalone without recompiling GCC.

## How Headers Are Generated

`build.sh` configures `libstdc++-v3` standalone against the cross compiler, runs `make install-data` (headers only), moves target-generated `bits/*` headers into `include/c++/16.2.0/bits/`, removes the hosted-only `ext/pb_ds` tree, and verifies `#define _GLIBCXX_HOSTED 0` in `bits/c++config.h`.

## Tests

`recipe.yaml` checks that:

- `$PREFIX/riscv64-unknown-elf/include/c++/16.2.0/bits/c++config.h` exists
- `<type_traits>` compiles with `-std=c++26 -march=rv64gc -mabi=lp64d -ffreestanding -D_GLIBCXX_NO_ASSERTIONS`
- The resulting object file has no undefined symbols

Because `pixi publish` skips recipe tests, run them explicitly with `rattler-build build --test` when verifying recipe changes.
