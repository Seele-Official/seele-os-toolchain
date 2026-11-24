# riscv64-unknown-elf-gcc

Recipe for the freestanding RISC-V 64-bit cross compiler:

- GCC 16.2.0 (C and C++, `-ffreestanding`, no newlib)
- GNU binutils 2.47 (`as`, `ld`, `ar`, `nm`, `objcopy`, `objdump`, ...)
- `libgcc.a` for compiler helpers

Does **not** include a C library, `libstdc++.a`, `libsupc++`, `libatomic`, or `libgcov`. Freestanding `libstdc++` headers are packaged separately in [`../riscv64-unknown-elf-libstdcxx`](../riscv64-unknown-elf-libstdcxx/README.md).

## Build

From the repository root:

```bash
pixi run build-gcc
```

A clean source build takes roughly 20–30 minutes and stages the `.conda` package in `dist/linux-64/`. `build.sh` respects `SEELE_TOOLCHAIN_JOBS` (defaulting to `CPU_COUNT`, fallback `4`, capped at `8`).

Host binaries are compiled against `conda-forge`'s `sysroot_linux-64 2.28` (`${{ stdlib('c') }}` + `[workspace.build-variants]` in `pixi.toml`), recording `__glibc >=2.28,<3.0.a0` in package metadata.

## Upstream Sources

| Component | Version | Source                                            |
| --------- | ------- | ------------------------------------------------- |
| GCC       | 16.2.0  | <https://ftp.gnu.org/gnu/gcc/gcc-16.2.0/>         |
| binutils  | 2.47    | <https://ftp.gnu.org/gnu/binutils/binutils-2.47/> |

Both tarballs are verified by SHA-256 in `recipe.yaml`.

## Build Configuration

GCC:

| Switch                                                                      | Effect                                                |
| --------------------------------------------------------------------------- | ----------------------------------------------------- |
| `--enable-languages=c,c++ --disable-bootstrap --without-headers`            | C/C++ only, freestanding, no stage-2 bootstrap        |
| `--with-arch=rv64gc --with-abi=lp64d --disable-multilib`                    | Default `-march`/`-mabi`, single multilib             |
| `--disable-libatomic`                                                       | `libatomic` disabled (unsupported on `*-elf` targets) |
| `--disable-gcov`                                                            | No `libgcov`                                          |
| `--disable-libssp --disable-libquadmath --disable-libgomp --disable-libvtv` | Target runtime libraries disabled                     |
| `--with-system-zlib --without-zstd`                                         | Use conda `libzlib`; avoid optional `zstd` ABI coupling |

binutils:

| Switch                                                       | Effect                                                 |
| ------------------------------------------------------------ | ------------------------------------------------------ |
| `--disable-gdb --disable-gprof --disable-gold --disable-sim` | No debugger, profiler, gold linker, or simulator       |
| `--with-system-zlib --without-zstd`                          | Use conda `libzlib`; avoid optional `zstd` ABI coupling |
| `--enable-deterministic-archives`                            | Deterministic `ar` archives                            |

## Tests

`recipe.yaml` defines smoke checks for `riscv64-unknown-elf-gcc`, `g++`, `ld`, and `libgcc.a`. Because `pixi publish` skips recipe tests, run them explicitly with `rattler-build build --test` when verifying recipe changes.
