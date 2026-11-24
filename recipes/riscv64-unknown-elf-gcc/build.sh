#!/usr/bin/env bash
set -euo pipefail

# Build a freestanding riscv64-unknown-elf GCC cross toolchain.  The layout is
# the standard GCC one:
#
#   $PREFIX/bin/riscv64-unknown-elf-{gcc,g++,as,ld,ar,nm,...}
#   $PREFIX/lib/gcc/riscv64-unknown-elf/16.2.0/{libgcc.a,include,...}
#   $PREFIX/riscv64-unknown-elf/include/c++/16.2.0/...
#
# Only libgcc is installed.  The kernel provides the C library, the C++ ABI
# and the heap, so libstdc++.a/libsupc++ are not built and libatomic is
# disabled (GCC does not support it for *-elf targets).  The libstdc++ headers
# live in the separate riscv64-unknown-elf-libstdcxx package.

TARGET="riscv64-unknown-elf"

# GCC's build is memory hungry.  Respect CPU_COUNT from conda-build, but cap
# it so a 16-core/16-GB CI machine does not OOM while compiling cc1plus.
JOBS="${SEELE_TOOLCHAIN_JOBS:-${CPU_COUNT:-4}}"
if [ "${JOBS}" -gt 8 ]; then
    JOBS=8
fi

export PATH="${PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${PREFIX}/lib:${LD_LIBRARY_PATH:-}"
export CFLAGS="${CFLAGS:-} -O2"
export CXXFLAGS="${CXXFLAGS:-} -O2"
# Keep an absolute rpath during the build; conda-build rewrites it to
# $ORIGIN-relative paths when packaging.
export LDFLAGS="${LDFLAGS:-} -Wl,-rpath,${PREFIX}/lib"

# Build out-of-tree inside SRC_DIR so every recipe build starts clean and
# reproducible (no stale config.cache carried across flag or sysroot changes).
BUILD_ROOT="${SRC_DIR}"

# ---------------------------------------------------------------------------
# GNU binutils
# ---------------------------------------------------------------------------
mkdir -p "${BUILD_ROOT}/build-binutils"
pushd "${BUILD_ROOT}/build-binutils"
"${SRC_DIR}/binutils/configure" \
    --target="${TARGET}" \
    --prefix="${PREFIX}" \
    --with-sysroot \
    --disable-nls \
    --disable-werror \
    --disable-gdb \
    --disable-gprof \
    --disable-gold \
    --disable-sim \
    --disable-libdecnumber \
    --disable-readline \
    --with-system-zlib \
    --without-zstd \
    --enable-deterministic-archives
make -j"${JOBS}"
make install
popd

# ---------------------------------------------------------------------------
# GCC (stage 1) and libgcc
# ---------------------------------------------------------------------------
mkdir -p "${BUILD_ROOT}/build-gcc"
pushd "${BUILD_ROOT}/build-gcc"
"${SRC_DIR}/gcc/configure" \
    --target="${TARGET}" \
    --prefix="${PREFIX}" \
    --disable-nls \
    --disable-werror \
    --disable-bootstrap \
    --enable-checking=release \
    --disable-multilib \
    --enable-languages=c,c++ \
    --disable-libssp \
    --disable-libquadmath \
    --disable-libgomp \
    --disable-libatomic \
    --disable-gcov \
    --disable-libvtv \
    --without-headers \
    --with-system-zlib \
    --without-zstd \
    --with-arch=rv64gc \
    --with-abi=lp64d \
    --with-gmp="${PREFIX}" \
    --with-mpfr="${PREFIX}" \
    --with-mpc="${PREFIX}" \
    --with-isl="${PREFIX}"
make -j"${JOBS}" all-gcc
make -j"${JOBS}" all-target-libgcc
make install-gcc
make install-target-libgcc
popd

# Documentation is not needed in the package and dwarfs the binaries.
rm -rf "${PREFIX}/share/man" "${PREFIX}/share/info" "${PREFIX}/share/locale"

# The package is only useful if these exist.
test -x "${PREFIX}/bin/${TARGET}-gcc"
test -x "${PREFIX}/bin/${TARGET}-g++"
test -f "$("${PREFIX}/bin/${TARGET}-gcc" -print-libgcc-file-name)"
