# riscv64-unknown-elf-libstdcxx

Pixi package containing the freestanding libstdc++ headers for the
`riscv64-unknown-elf` cross compiler.

- Generated from the GCC 16.2.0 sources with `--disable-hosted-libstdcxx`;
- no `libstdc++.a`, no `libsupc++`, no libc headers;
- installs into `riscv64-unknown-elf/include/c++/16.2.0`, where the compiler's `g++`
  searches by default;
- depends on `riscv64-unknown-elf-gcc ==16.2.0`.

The headers are not part of the compiler package. A project that uses them installs this
package as well.

## Build

```bash
pixi publish --path recipes/riscv64-unknown-elf-libstdcxx \
    --target-dir "$PWD/.channel/linux-64"
rattler-index fs .channel
```

`bash tools/build-toolchain-channel.sh` runs this and indexes the channel in one step.
The build needs the cross compiler, so the channel must already contain and index
`riscv64-unknown-elf-gcc`; `pixi.toml` lists it in `channels` for that reason.

## Source

The GCC 16.2.0 tarball (same SHA-256 as the compiler recipe). The build script
configures `libstdc++-v3` on its own — not as part of a GCC build — against the cross
compiler from the channel, runs `make install-data` (headers only), moves the generated
`bits/*` headers next to the source headers, and drops the hosted-only `ext/pb_ds` tree.

The headers are the ones GCC 16.2.0 generates with `--disable-hosted-libstdcxx`. A
cold package build takes about two to three minutes, mostly configuring; a rebuild
reuses the build tree and takes about half a minute.

## Tests

`recipe.yaml` checks that:

- `$PREFIX/riscv64-unknown-elf/include/c++/16.2.0/bits/c++config.h` exists;
- `<type_traits>` compiles with
  `-std=c++23 -march=rv64gc -mabi=lp64d -ffreestanding -D_GLIBCXX_NO_ASSERTIONS`;
- the resulting object has no undefined symbols.

`pixi publish` does not execute recipe tests; `tools/check-toolchain.sh` is the workspace
check.
