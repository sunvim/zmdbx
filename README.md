# zmdbx

🚀 **高性能、类型安全的 MDBX Zig 语言绑定**

`zmdbx` 是 [libmdbx](https://github.com/erthink/libmdbx) 的 Zig 语言绑定库，提供了简洁、符合 Zig 风格的 API，完全兼容 Zig 0.15.2。

## ✨ 特性

- ✅ **类型安全**: 充分利用 Zig 的类型系统，避免运行时错误
- ✅ **零成本抽象**: 直接映射到 C API，无性能损失
- ✅ **符合 Zig 风格**: 遵循 Zig 命名规范和错误处理模式
- ✅ **完整的 API 覆盖**: 支持环境管理、事务、游标等核心功能
- ✅ **优秀的文档**: 完整的中文注释和使用示例
- ✅ **经过测试**: 包含单元测试和性能压测

## 📦 安装

### 使用 Zig 包管理器

1. 将 zmdbx 添加到你的项目：

```bash
zig fetch --save https://github.com/sunvim/zmdbx/archive/main.tar.gz
```

2. 在 `build.zig` 中添加依赖：

```zig
const zmdbx = b.dependency("zmdbx", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zmdbx", zmdbx.module("zmdbx"));
```

### 手动安装

1. 克隆仓库并初始化子模块：

```bash
git clone https://github.com/sunvim/zmdbx.git
cd zmdbx
git submodule update --init --recursive
```

2. 构建库：

```bash
zig build
```

## 🚀 快速开始

```zig
const std = @import("std");
const zmdbx = @import("zmdbx");

pub fn main() !void {
    // 1. 创建环境
    var env = try zmdbx.Env.init();
    defer env.deinit();

    // 2. 打开数据库
    try env.open("./mydb", .defaults, 0o644);

    // 3. 开始事务
    var txn = try env.beginTxn(null, .read_write);
    defer txn.abort(); // 确保异常时中止

    // 4. 打开数据库实例
    const dbi = try txn.openDBI(null, .create);

    // 5. 写入数据
    try txn.put(dbi, "name", "张三", .upsert);
    try txn.put(dbi, "age", "25", .upsert);

    // 6. 读取数据
    const name = try txn.get(dbi, "name");
    std.debug.print("name: {s}\n", .{name});

    // 7. 提交事务
    try txn.commit();
}
```

## 📚 文档

### 核心概念

#### 环境 (Environment)

环境是 MDBX 数据库的顶层容器：

```zig
var env = try zmdbx.Env.init();
defer env.deinit();

// 设置数据库大小
try env.setGeometry(.{
    .lower = 1024 * 1024,      // 最小 1MB
    .now = 10 * 1024 * 1024,   // 初始 10MB
    .upper = 100 * 1024 * 1024, // 最大 100MB
    .growth_step = 1024 * 1024,
    .shrink_threshold = -1,
    .pagesize = -1,
});

try env.open("./mydb", .defaults, 0o644);
```

#### 事务 (Transaction)

事务提供 ACID 保证：

```zig
// 读写事务
var write_txn = try env.beginTxn(null, .read_write);
defer write_txn.abort();

// 只读事务
var read_txn = try env.beginTxn(null, .read_only);
defer read_txn.abort();
```

#### 游标 (Cursor)

游标用于高效遍历数据：

```zig
var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
defer cursor.close();

// 遍历所有记录
var result = try cursor.get(null, null, .first);
while (true) {
    std.debug.print("key: {s}, value: {s}\n", .{result.key, result.data});
    result = cursor.get(null, null, .next) catch |err| {
        if (err == error.NotFound) break;
        return err;
    };
}
```

### API 参考

#### Env (环境)

| 方法 | 描述 |
|------|------|
| `init()` | 创建新环境 |
| `deinit()` | 关闭环境 |
| `open(path, flags, mode)` | 打开数据库 |
| `setGeometry(geo)` | 设置数据库几何参数 |
| `setMaxdbs(n)` | 设置最大数据库数量 |
| `beginTxn(parent, flags)` | 开始新事务 |

#### Txn (事务)

| 方法 | 描述 |
|------|------|
| `init(env, parent, flags)` | 创建事务 |
| `commit()` | 提交事务 |
| `abort()` | 中止事务 |
| `openDBI(name, flags)` | 打开数据库实例 |
| `get(dbi, key)` | 获取数据 |
| `put(dbi, key, data, flags)` | 写入数据 |
| `del(dbi, key, data)` | 删除数据 |

#### Cursor (游标)

| 方法 | 描述 |
|------|------|
| `open(txn, dbi)` | 打开游标 |
| `close()` | 关闭游标 |
| `get(key, data, op)` | 获取数据 |
| `put(key, data, flags)` | 写入数据 |
| `del(flags)` | 删除当前项 |

## 📖 示例

查看 `examples/` 目录获取完整示例：

- **basic_usage.zig** - 基本使用示例
- **cursor_usage.zig** - 游标遍历示例
- **batch_operations.zig** - 批量操作示例

运行示例：

```bash
zig build-exe examples/basic_usage.zig
./basic_usage
```

## 🧪 测试

### 运行单元测试

```bash
zig build test
```

### 运行性能压测

**重要**: 由于 Zig Debug 模式的运行时安全检查，benchmark 必须使用 Release 模式运行：

```bash
# 推荐：使用 ReleaseFast 模式
zig build bench -Doptimize=ReleaseFast

# 或者使用 ReleaseSafe 模式（保留错误处理）
zig build bench -Doptimize=ReleaseSafe
```

更多详情请参阅 [BENCHMARKS.md](BENCHMARKS.md)。

典型性能指标（在 ARM64 硬件上，ReleaseFast 模式）：

| 操作 | 吞吐量 |
|------|--------|
| 顺序写入 (10万条) | ~57,000 ops/s |
| 随机写入 (5万条) | ~77,000 ops/s |
| 顺序读取 (10万条) | ~109,000 ops/s |
| 随机读取 (5万次) | ~107,000 ops/s |
| 混合操作 (读写删 5万次) | ~91,000 ops/s |
| 批量删除 (5万条) | ~102,000 ops/s |

## 🛠 开发

### 构建

```bash
zig build
```

### 清理

```bash
zig build clean
```

### 代码格式化

```bash
zig fmt src/*.zig
```

## 📝 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 🤝 贡献

欢迎贡献！请随时提交 Issue 或 Pull Request。

### 贡献指南

1. Fork 本仓库
2. 创建你的特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交你的更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启一个 Pull Request

## 🙏 致谢

- [libmdbx](https://github.com/erthink/libmdbx) - 优秀的嵌入式数据库引擎
- [Zig](https://ziglang.org/) - 强大的系统编程语言

## 📮 联系方式

如有问题或建议，请通过以下方式联系：

- 提交 Issue: https://github.com/your-repo/zmdbx/issues
- Email: your-email@example.com

---

⭐ 如果这个项目对你有帮助，请给它一个星标！
