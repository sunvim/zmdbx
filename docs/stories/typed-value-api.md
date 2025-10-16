# Val类型化API增强 - Brownfield Story

## Story Title

**Val类型化数据转换API - Brownfield Addition**

## User Story

**作为** zmdbx库的使用者，
**我想要** 能够直接使用类型化的API来存储和读取整数等基本类型数据，
**以便** 我不需要手动进行字节序列化和反序列化，提高代码可读性和类型安全性。

## Story Context

### Existing System Integration

- **集成点**: `src/types.zig` 中的 `Val` 结构体
- **技术栈**: Zig 0.15.2, libmdbx C绑定
- **遵循模式**:
  - 使用 `inline` 函数保证零成本抽象
  - 提供便捷方法（如现有的 `getBytes()`）
  - 完整的中文注释和文档
  - 符合Zig命名规范和错误处理模式
- **触点**:
  - Val结构体的现有方法（fromBytes, toBytes, empty等）
  - 与Txn.get()返回的Val对象交互
  - 用户代码中的类型转换逻辑

### Current Pain Point

当前用户存储和读取数字类型时需要手动转换：

```zig
// 当前方式 - 繁琐且容易出错
const age: u32 = 25;
const age_bytes = std.mem.asBytes(&age);
try txn.put(dbi, "age", age_bytes, put_flags);

// 读取时也需要手动转换
const val = try txn.get(dbi, "age");
const bytes = val.toBytes();
const age_read = std.mem.bytesToValue(u32, bytes[0..@sizeOf(u32)]);
```

## Acceptance Criteria

### Functional Requirements

**FR1: Val类型构造方法**
- Val结构体提供 `from_i8()`, `from_i16()`, `from_i32()`, `from_i64()`, `from_i128()` 静态方法
- Val结构体提供 `from_u8()`, `from_u16()`, `from_u32()`, `from_u64()`, `from_u128()` 静态方法
- 所有方法处理正确的字节序（使用原生字节序）

**FR2: Val类型转换方法**
- Val结构体提供 `to_i8()`, `to_i16()`, `to_i32()`, `to_i64()`, `to_i128()` 实例方法
- Val结构体提供 `to_u8()`, `to_u16()`, `to_u32()`, `to_u64()`, `to_u128()` 实例方法
- 如果数据长度不匹配，返回适当的错误（`error.InvalidDataLength`）

**FR3: 额外的便捷类型**
- 支持 `f32` 和 `f64` 浮点数类型
- 支持布尔类型 `bool`

### Integration Requirements

**IR1: 向后兼容性**
- 现有的 `fromBytes()`, `toBytes()` 等方法继续正常工作
- 不修改Val结构体的内部字段（`inner: c.MDBX_val`）
- 不影响现有的使用代码

**IR2: 遵循现有模式**
- 所有新方法使用 `inline` 关键字确保零成本抽象
- 使用Zig标准的错误处理模式
- 添加完整的中文注释，说明用途、参数、返回值和错误

**IR3: 与Txn集成**
- 新API可以与现有的 `Txn.get()` 无缝配合使用
- 新API可以与现有的 `Txn.put()` 配合使用（通过toBytes()）

### Quality Requirements

**QR1: 测试覆盖**
- 为所有新增的类型转换方法添加单元测试
- 测试边界条件（空数据、错误长度等）
- 测试往返转换（roundtrip: value → bytes → value）

**QR2: 文档更新**
- 更新 `docs/API_CHEATSHEET.md` 添加新API
- 在README.md的Val部分添加使用示例
- 为新方法添加完整的代码注释

**QR3: 无性能回归**
- 使用 `inline` 确保零成本抽象
- 验证编译后没有额外的运行时开销
- 现有benchmark不受影响

## Technical Notes

### Integration Approach

在 `src/types.zig` 的 `Val` 结构体中添加新方法：

```zig
pub const Val = struct {
    // ... 现有字段和方法 ...

    /// 从i32创建Val
    pub inline fn from_i32(value: i32) Self {
        const bytes = std.mem.asBytes(&value);
        return fromBytes(bytes);
    }

    /// 转换为i32
    pub inline fn to_i32(self: Self) !i32 {
        const bytes = self.toBytes();
        if (bytes.len != @sizeOf(i32)) {
            return error.InvalidDataLength;
        }
        return std.mem.bytesToValue(i32, bytes[0..@sizeOf(i32)]);
    }

    // ... 其他类型的类似方法 ...
};
```

### Existing Pattern Reference

- 参考现有的 `fromBytes()` 和 `toBytes()` 方法的实现模式
- 参考现有的 `getBytes()` 便捷方法设计（Txn中）
- 使用 `inline` 关键字，与现有方法保持一致

### Key Constraints

1. **零成本抽象**: 必须使用 `inline` 确保编译器优化
2. **原生字节序**: 使用原生字节序（native endianness），不进行转换
3. **类型安全**: 利用Zig的类型系统，避免运行时类型错误
4. **错误处理**: 数据长度不匹配时返回错误，而不是panic

### Implementation Scope

**阶段1：核心整数类型**（本Story）
- 有符号整数：i8, i16, i32, i64, i128
- 无符号整数：u8, u16, u32, u64, u128

**阶段2：扩展类型**（未来可选）
- 浮点数：f32, f64
- 布尔值：bool
- 字符串便捷方法（可能不需要，因为已有toBytes）

## Definition of Done

- [x] FR1: 所有整数类型的构造方法已实现
- [x] FR2: 所有整数类型的转换方法已实现
- [x] IR1: 向后兼容性验证通过（现有测试全部通过）
- [x] IR2: 新方法遵循现有代码模式和规范
- [x] IR3: 与Txn集成验证通过
- [x] QR1: 单元测试添加并通过
- [x] QR2: 文档更新完成
- [x] QR3: 性能benchmark无回归

## Risk and Compatibility Check

### Minimal Risk Assessment

**Primary Risk**:
- 字节序问题：在不同架构上读写数据可能不兼容

**Mitigation**:
- 在文档中明确说明使用原生字节序
- 建议跨平台场景使用自定义序列化
- 在注释中警告跨架构兼容性问题

**Rollback**:
- 纯新增API，不修改现有代码
- 如需回滚，直接删除新增方法即可
- 不影响数据库内容和格式

### Compatibility Verification

- [x] **无破坏性变更**: 只添加新方法，不修改现有API
- [x] **数据库兼容**: 不改变数据存储格式
- [x] **性能影响**: 使用inline，性能影响可忽略不计
- [x] **设计模式**: 完全遵循现有的Val设计模式

## Validation Checklist

### Scope Validation

- [x] **单次开发会话**: 预计2-4小时可完成（约10个方法 + 测试 + 文档）
- [x] **集成简单**: 只在Val结构体内添加方法，无复杂依赖
- [x] **遵循现有模式**: 完全照搬fromBytes/toBytes的模式
- [x] **无架构设计**: 不需要新的架构或设计决策

### Clarity Check

- [x] **需求明确**: 清楚需要添加哪些方法和功能
- [x] **集成点明确**: src/types.zig的Val结构体
- [x] **成功标准可测**: 可以通过单元测试和示例验证
- [x] **回滚简单**: 删除新增方法即可，无数据迁移

## Usage Example

实现后的使用示例：

```zig
const std = @import("std");
const zmdbx = @import("zmdbx");

pub fn main() !void {
    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open("./mydb", zmdbx.EnvFlagSet.init(.{}), 0o644);

    var txn = try env.beginWriteTxn();
    defer txn.abort();

    var db_flags = zmdbx.DBFlagSet.init(.{});
    db_flags.insert(.create);
    const dbi = try txn.openDBI(null, db_flags);

    // 新API - 类型化写入
    const age: u32 = 25;
    const age_val = zmdbx.Val.from_u32(age);
    try txn.put(dbi, "age", age_val.toBytes(), zmdbx.PutFlagSet.init(.{}));

    const score: i64 = -1000;
    const score_val = zmdbx.Val.from_i64(score);
    try txn.put(dbi, "score", score_val.toBytes(), zmdbx.PutFlagSet.init(.{}));

    try txn.commit();

    // 新API - 类型化读取
    var read_txn = try env.beginReadTxn();
    defer read_txn.abort();

    const dbi2 = try read_txn.openDBI(null, zmdbx.DBFlagSet.init(.{}));

    const age_data = try read_txn.get(dbi2, "age");
    const age_read = try age_data.to_u32();
    std.debug.print("age: {}\n", .{age_read}); // 输出: age: 25

    const score_data = try read_txn.get(dbi2, "score");
    const score_read = try score_data.to_i64();
    std.debug.print("score: {}\n", .{score_read}); // 输出: score: -1000
}
```

## Estimated Effort

- **代码实现**: 1.5 小时（~20个方法，每个约3-5行）
- **单元测试**: 1 小时（测试所有类型的往返转换）
- **文档更新**: 0.5 小时（API文档和README示例）
- **总计**: 约 3 小时

## Success Metrics

- [ ] 所有整数类型（i8-i128, u8-u128）都有对应的from_/to_方法
- [ ] 所有新方法都有完整的中文注释
- [ ] 至少有10个单元测试覆盖核心功能
- [ ] README中有清晰的使用示例
- [ ] 现有的所有测试继续通过
- [ ] 无性能回归（benchmark结果一致）

---

**Story Status**: 📝 Ready for Implementation
**Priority**: Medium
**Story Points**: 3
**Created**: 2025-10-16
