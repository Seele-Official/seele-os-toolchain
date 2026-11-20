# seele-toolchain

`riscv64-unknown-elf` 交叉工具链的 conda channel，供 riscv 的 c++ freestanding 项目使用。
channel 提供两个包：

| 包                              | 内容                                               |
| ------------------------------- | -------------------------------------------------- |
| `riscv64-unknown-elf-gcc`       | GCC 16.2.0（C/C++）、GNU binutils 2.47、`libgcc.a` |
| `riscv64-unknown-elf-libstdcxx` | freestanding libstdc++ 头文件                      |

channel 由 `vendor/` 里的预构建 GCC 与 `recipes/` 里的 recipe 组装。

## Structure

```text
recipes/riscv64-unknown-elf-gcc/          # GCC/binutils/libgcc 的源码 recipe
recipes/riscv64-unknown-elf-libstdcxx/    # 头文件包 recipe（从 GCC 源码生成）
vendor/riscv64-unknown-elf-gcc-*.conda    # 预构建 GCC
vendor/SHA256SUMS                         # 预构建包的校验和
tools/build-toolchain-channel.sh          # 组装并索引 .channel
tools/check-toolchain.sh                  # 在已安装环境里做编译探针
tools/repack-gcc-package.py               # 从原始单包生成 vendor/ 里的 GCC 包
docs/toolchain-packaging.md               # 包结构与打包流程说明
```

## Require

- linux-64；
- pixi ≥ 0.84（`pixi publish`、`pixi exec` 中的 `rattler-index`）。

## Build channel

```bash
pixi run channel
```

脚本依次执行：

1. 用 `vendor/SHA256SUMS` 校验预构建 GCC；
2. 把 GCC 包硬链接（跨文件系统时复制）到 `.channel/linux-64/`；
3. 运行 `rattler-index fs .channel` 建立索引；
4. 用 `pixi publish` 构建并发布 `riscv64-unknown-elf-libstdcxx`；
5. 再次索引，并确认 `repodata.json` 中同时包含两个包。

产物：

```text
.channel/linux-64/repodata.json
.channel/linux-64/riscv64-unknown-elf-gcc-16.2.0-*.conda
.channel/linux-64/riscv64-unknown-elf-libstdcxx-16.2.0-*.conda
```

## Usage

```toml
[workspace]
channels = ["conda-forge", "yourpath/toolchain/.channel"]

[dependencies]
riscv64-unknown-elf-gcc = "==16.2.0"
riscv64-unknown-elf-libstdcxx = "==16.2.0"
```
