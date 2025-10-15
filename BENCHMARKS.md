# MDBX Performance Benchmarks

## 运行基准测试

由于 Zig 的 Debug 模式包含严格的运行时安全检查（包括对齐检查），而 MDBX 在 ARM64 平台上利用未对齐访问优化性能，因此建议使用 Release 模式运行 benchmark：

### 推荐方式（ReleaseFast）：
```bash
zig build bench -Doptimize=ReleaseFast
```

### 或者使用 ReleaseSafe（保留错误处理）：
```bash
zig build bench -Doptimize=ReleaseSafe
```

## 为什么 Debug 模式会失败？

- Zig 的 Debug 模式包含未对齐访问检查
- MDBX 在 ARM64 上使用未对齐访问优化（`MDBX_UNALIGNED_OK=8`）
- 这两者在 Debug 模式下会冲突
- Release 模式关闭了这些运行时检查，因此可以正常运行

## Benchmark 测试项

1. 顺序写入 (100,000 条记录)
2. 随机写入 (50,000 条记录)
3. 顺序读取 (100,000 条记录)
4. 随机读取 (50,000 次)
5. 混合操作 (读写删, 50,000 次)
6. 批量删除 (50,000 条记录)

## 性能提示

- 调整 `setGeometry` 参数可以优化性能
- 使用 `write_map` 标志可以提高写入性能
- 根据你的使用场景调整事务大小
