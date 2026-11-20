# 工具链打包与安装

本文说明 `seele-toolchain` 的 channel 结构、组装流程和打包约束。安装与使用步骤见
[README](../README.md)，两个包的具体内容见各自的 recipe README。

## 1. 包

| 包                              | 内容                                           | recipe                                  |
| ------------------------------- | ---------------------------------------------- | --------------------------------------- |
| `riscv64-unknown-elf-gcc`       | GCC 16.2.0（C/C++）、binutils 2.47、`libgcc.a` | `recipes/riscv64-unknown-elf-gcc`       |
| `riscv64-unknown-elf-libstdcxx` | freestanding libstdc++ 头文件                  | `recipes/riscv64-unknown-elf-libstdcxx` |

两个包的 `version` 都是 `16.2.0`；头文件包的 `run` 依赖固定为
`riscv64-unknown-elf-gcc ==16.2.0`。

## 2. channel 组装

```bash
pixi run channel        # bash tools/build-toolchain-channel.sh
```

`tools/build-toolchain-channel.sh` 的步骤：

1. 删除旧的 `.channel/`，创建 `.channel/linux-64/`；
2. 用 `vendor/SHA256SUMS` 校验预构建 GCC，并把它硬链接（跨文件系统时复制）到
   `.channel/linux-64/`；
3. 运行 `rattler-index fs .channel` 建立索引；
4. 用 `pixi publish --path recipes/riscv64-unknown-elf-libstdcxx` 构建并发布头文件包
   （`--target-dir .channel/linux-64 --force`）；
5. 再次运行 `rattler-index`，把新包加入索引；
6. 检查 `repodata.json` 中同时存在两个包，否则以非零状态退出。

头文件 recipe 的 workspace 把 `../../.channel` 列在 `channels` 里，configure 时从
该 channel 取 `riscv64-unknown-elf-gcc`，因此第 3 步必须先于第 4 步。

`rattler-index` 通过 `pixi exec -s rattler-index` 运行，不依赖任何 workspace 环境。

## 3. GCC 包

`recipes/riscv64-unknown-elf-gcc` 从源码构建 GCC 16.2.0 + binutils 2.47：

- 只安装 C/C++ 编译器、binutils 和 `libgcc.a`；
- 不安装 C 库、`libstdc++.a`、`libsupc++`、`libatomic`、`libgcov`；
- 默认 `-march=rv64gc -mabi=lp64d`，单 multilib；
- 源码 tarball 的 SHA-256 写在 `recipe.yaml` 里。

源码构建约 20–30 分钟。本地 channel 直接使用 `vendor/` 里的预构建包，不重建 GCC。
`vendor/` 里的包来自更早的单包 conda-build 制品，经
`tools/repack-gcc-package.py` 处理：

- 删除随包携带的 libstdc++ 头文件；
- 删除 `info/recipe`、`info/test`、`info/hash_input.json`；
- 重写 `info/about.json`；
- build number 从 `0` 升到 `1`，使重打包制品与原始包可区分。

需要重新生成时：

```bash
pixi publish --path recipes/riscv64-unknown-elf-gcc --target-dir vendor
```

把产物放入 `vendor/`，删除旧包，更新 `vendor/SHA256SUMS`，再运行
`pixi run channel`。

## 4. libstdc++ 头文件包

`recipes/riscv64-unknown-elf-libstdcxx` 从同一份 GCC 16.2.0 源码生成头文件：

1. 用 channel 里的交叉编译器单独 configure `libstdc++-v3`
   （`--disable-hosted-libstdcxx`、`--without-headers` 等，见 `build.sh`）；
2. `make install-data`，只安装头文件；
3. 把生成的 `bits/*` 头文件并到源码头文件旁边，删除临时的目标目录；
4. 删除 hosted-only 的 `ext/pb_ds`；
5. 安装到 `riscv64-unknown-elf/include/c++/16.2.0`；
6. 检查 `bits/c++config.h` 中 `_GLIBCXX_HOSTED` 为 `0`。

包中只有头文件，不含 `libstdc++.a`、`libsupc++` 或 C 库头文件。冷构建约 2–3
分钟，主要是 configure；构建目录保留在 work root 之外，之后的增量构建约半分钟。
