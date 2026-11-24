# Toolchain Packaging & Release Guide

This document describes the package architecture, host ABI constraints, build workflow, and release verification steps for <https://prefix.dev/seele-official/seele-os-toolchain>.

## 1. Package Split

The toolchain is split into two conda packages with matching version `16.2.0`:

| Package                         | Recipe                                    | Responsibility                                |
| ------------------------------- | ----------------------------------------- | --------------------------------------------- |
| `riscv64-unknown-elf-gcc`       | `recipes/riscv64-unknown-elf-gcc/`        | GCC 16.2.0 (C/C++), binutils 2.47, `libgcc.a` |
| `riscv64-unknown-elf-libstdcxx` | `recipes/riscv64-unknown-elf-libstdcxx/`  | Freestanding `libstdc++` headers only         |

Splitting the headers out of the compiler package allows pure-C projects to install only the compiler and lets header configuration changes iterate in a few minutes without recompiling GCC. `riscv64-unknown-elf-libstdcxx` pins `riscv64-unknown-elf-gcc ==16.2.0` at both build and run time.

## 2. Host ABI & Compatibility Policy

The packages are consumed on arbitrary `linux-64` workstations and CI runners, so host-side dependencies are deliberately constrained:

- **glibc 2.28 baseline**: `recipes/riscv64-unknown-elf-gcc/recipe.yaml` declares `${{ stdlib('c') }}` and `pixi.toml` pins `c_stdlib = ["sysroot"]` and `c_stdlib_version = ["2.28"]`. This compiles all host binaries against `conda-forge`'s `sysroot_linux-64 2.28` and automatically emits `__glibc >=2.28,<3.0.a0` in package metadata.
- **No optional `zstd` dependency**: Both binutils and GCC are configured with `--without-zstd` and `zstd` is omitted from `requirements.host`. Avoids coupling consumers (such as older QEMU builds) to `zstd` major/minor transitions on `conda-forge`.
- **Automatic `run_exports`**: Runtime shared-library constraints (`gmp`, `mpfr`, `mpc`, `isl`, `libzlib`, `libgcc`, `libstdcxx`, `__glibc`) come exclusively from `host`/`build` `run_exports` rather than manual `run` pins.
- **Clean out-of-tree builds**: Both `build.sh` scripts build inside `${SRC_DIR}` so every invocation starts with a fresh build tree and never inherits stale `config.cache` state from earlier builds.

## 3. Local Build Workflow

All build artifacts are staged into `dist/linux-64/` (gitignored) and indexed with `rattler-index` via `pixi exec`:

| Task                      | Behavior                                                                 |
| ------------------------- | ------------------------------------------------------------------------ |
| `pixi run build-gcc`      | Builds `riscv64-unknown-elf-gcc` into `dist/linux-64/` and indexes `dist/`. |
| `pixi run build-libstdcxx`| Initializes/indexes `dist/`, builds `riscv64-unknown-elf-libstdcxx`, and re-indexes `dist/`. |
| `pixi run build`          | Runs `build-gcc` followed by `build-libstdcxx` to reproduce the full channel from source. |
| `pixi run index`          | Creates or re-indexes `dist/` as a local conda channel.                  |
| `pixi run clean`          | Deletes `dist/`.                                                         |

`recipes/riscv64-unknown-elf-libstdcxx/pixi.toml` lists channels in order:

```toml
channels = [
    "../../dist",
    "https://prefix.dev/seele-official/seele-os-toolchain",
    "conda-forge",
]
```

- During `pixi run build`, `build-gcc` populates and indexes `dist/` first, so `build-libstdcxx` resolves the freshly built compiler from `../../dist`.
- During standalone `pixi run build-libstdcxx` (on a fresh clone with an empty `dist/`), `index` initializes an empty local repodata and Pixi falls back to the published compiler on `prefix.dev`.

## 4. Pre-Upload Verification

`pixi publish` does not execute recipe `tests:`. Before uploading a new build to `prefix.dev`:

1. **Inspect `info/index.json`** inside the generated `.conda` archive:
   - Confirm `__glibc >=2.28,<3.0.a0` is present on `riscv64-unknown-elf-gcc`.
   - Confirm no unexpected dependencies (such as `zstd` or unpinned `zlib`) leaked in.
   - Confirm `license` is `GPL-3.0-or-later WITH GCC-exception-3.1` and `info/licenses/` contains both `COPYING3` and `COPYING.RUNTIME`.
2. **Verify ELF symbol versions** on extracted host binaries (`bin/*` and `libexec/gcc/riscv64-unknown-elf/16.2.0/*`):
   ```bash
   readelf -V <binary> | grep -oE 'GLIBC_[0-9.]+' | sort -Vu | tail -n 5
   ```
   Every host ELF must stay at or below `GLIBC_2.28`.
3. **Run recipe tests** when changing recipes or configure flags:
   ```bash
   pixi exec -s rattler-build -- rattler-build build --recipe recipes/riscv64-unknown-elf-gcc --test
   ```
4. **End-to-end consumer check**: Install the staged packages into a consumer workspace (e.g., `seele-os`), build Release and Debug targets, and verify `riscv64-unknown-elf-nm -u` reports no unexpected undefined symbols.

## 5. Publishing to prefix.dev

Authenticate once (or provide `PREFIX_API_KEY` in CI):

```bash
pixi auth login https://prefix.dev
```

Upload all packages staged in `dist/linux-64/`:

```bash
pixi run upload
```

Bump `build.number` in the modified `recipe.yaml` whenever rebuilding the same upstream version so caches and resolvers pick up the new artifact cleanly.
