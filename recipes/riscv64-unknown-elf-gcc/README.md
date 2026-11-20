# riscv64-unknown-elf-gcc

Pixi package for the freestanding RISC-V cross compiler:

- GCC 16.2.0, C and C++ (`-ffreestanding`, no newlib);
- GNU binutils 2.47 (`as`, `ld`, `ar`, `nm`, `objcopy`, ...);
- `libgcc.a` for compiler helpers.

The package does not contain a C library, `libstdc++.a`, `libsupc++`, `libatomic`, or
`libgcov`. Freestanding libstdc++ headers are provided by the separate
`riscv64-unknown-elf-libstdcxx` package.

## Build

```bash
pixi publish --path recipes/riscv64-unknown-elf-gcc \
    --target-dir "$PWD/.channel/linux-64"
rattler-index fs .channel
```

A source build takes roughly 20-30 minutes. The channel assembled by
`tools/build-toolchain-channel.sh` uses the pinned prebuilt artifact in
[`vendor/`](../../vendor) instead; see its README for provenance. To rebuild that
artifact:

```bash
pixi publish --path recipes/riscv64-unknown-elf-gcc --target-dir vendor
# replace the old package in vendor/ and update vendor/SHA256SUMS
```

`build.sh` uses `SEELE_TOOLCHAIN_JOBS` (default `CPU_COUNT`, fallback 4) parallel jobs,
capped at 8.

## Versions

| Component | Version | Source                                            |
| --------- | ------- | ------------------------------------------------- |
| GCC       | 16.2.0  | <https://ftp.gnu.org/gnu/gcc/gcc-16.2.0/>         |
| binutils  | 2.47    | <https://ftp.gnu.org/gnu/binutils/binutils-2.47/> |

`recipe.yaml` verifies both tarballs by SHA-256.

## Build configuration

GCC:

| Switch                                                                      | Effect                                                |
| --------------------------------------------------------------------------- | ----------------------------------------------------- |
| `--enable-languages=c,c++ --disable-bootstrap --without-headers`            | C/C++ only, freestanding, no stage-2 build            |
| `--with-arch=rv64gc --with-abi=lp64d --disable-multilib`                    | default `-march`/`-mabi`, single multilib             |
| `--disable-libatomic`                                                       | libatomic is not built (GCC does not support `*-elf`) |
| `--disable-gcov`                                                            | no libgcov                                            |
| `--disable-libssp --disable-libquadmath --disable-libgomp --disable-libvtv` | the corresponding runtime libraries are not built     |

binutils:

| Switch                                                       | Effect                                           |
| ------------------------------------------------------------ | ------------------------------------------------ |
| `--disable-gdb --disable-gprof --disable-gold --disable-sim` | no debugger, profiler, gold linker, or simulator |
| `--enable-deterministic-archives`                            | deterministic `ar` archives                      |

## Tests

`recipe.yaml` defines these checks:

- `riscv64-unknown-elf-gcc --version`, `riscv64-unknown-elf-g++ --version`, and
  `riscv64-unknown-elf-ld --version` succeed;
- `$(riscv64-unknown-elf-gcc -print-libgcc-file-name)` exists.

`pixi publish` does not execute recipe tests; run them with `rattler-build build --test` or
use `tools/check-toolchain.sh` from the workspace.
