# Txn类型化便捷API - Brownfield Story

## Story Title

**Txn类型化便捷方法 - Brownfield Addition**

## User Story

**作为** zmdbx库的使用者，
**我想要** 能够直接在事务对象上使用类型化的get和put方法，
**以便** 我可以用一行代码完成类型化数据的存储和读取，无需手动调用Val的转换方法。

## Story Context

### Existing System Integration

- **集成点**: `src/txn.zig` 中的 `Txn` 结构体
- **技术栈**: Zig 0.15.2, libmdbx C绑定
- **遵循模式**:
  - 已有的 `getBytes()` 便捷方法（返回`[]const u8`而非`Val`）
  - 使用 `inline` 函数保证零成本抽象
  - 完整的中文注释和文档
- **依赖关系**:
  - **依赖于** `typed-value-api.md` 故事（Val的类型化API）
  - 内部使用Val的`from_TYPE()`和`to_TYPE()`方法
- **触点**:
  - 现有的`Txn.get()`和`Txn.put()`方法
  - 现有的`Txn.getBytes()`便捷方法
  - DBI、PutFlagSet等类型

### Current Pain Point

即使有了Val的类型化API，用户仍需要多行代码：

```zig
// 使用Val API - 仍然有些繁琐
const age: u32 = 25;
const age_val = zmdbx.Val.from_u32(age);
try txn.put(dbi, "age", age_val.toBytes(), put_flags);

// 读取时也需要两步
const val = try txn.get(dbi, "age");
const age_read = try val.to_u32();
```

## Acceptance Criteria

### Functional Requirements

**FR1: Txn类型化写入方法**
- Txn结构体提供 `put_i8()`, `put_i16()`, `put_i32()`, `put_i64()`, `put_i128()` 方法
- Txn结构体提供 `put_u8()`, `put_u16()`, `put_u32()`, `put_u64()`, `put_u128()` 方法
- 所有方法接受DBI、key、value和flags参数
- 内部使用Val的`from_TYPE()`方法进行转换

**FR2: Txn类型化读取方法**
- Txn结构体提供 `get_i8()`, `get_i16()`, `get_i32()`, `get_i64()`, `get_i128()` 方法
- Txn结构体提供 `get_u8()`, `get_u16()`, `get_u32()`, `get_u64()`, `get_u128()` 方法
- 所有方法接受DBI和key参数
- 内部使用Val的`to_TYPE()`方法进行转换
- 传递底层的错误（包括`error.InvalidDataLength`）

**FR3: 保持一致性**
- 方法签名与现有的`put()`和`getBytes()`保持一致
- 错误处理方式与现有方法一致

### Integration Requirements

**IR1: 向后兼容性**
- 现有的 `get()`, `put()`, `getBytes()` 方法继续正常工作
- 不修改Txn结构体的内部字段
- 不影响现有的使用代码

**IR2: 遵循现有模式**
- 所有新方法使用 `inline` 关键字
- 参考`getBytes()`的实现模式（便捷包装器）
- 添加完整的中文注释

**IR3: 与Val API集成**
- 新方法内部使用Val的类型化API
- 依赖关系明确：需要先实现Val的类型化API

### Quality Requirements

**QR1: 测试覆盖**
- 为所有新增的类型化方法添加单元测试
- 测试往返操作（put然后get）
- 测试错误情况（如数据长度不匹配）

**QR2: 文档更新**
- 更新 `docs/API_CHEATSHEET.md` 添加新API
- 在README.md的Txn部分添加使用示例
- 更新快速开始部分使用新API
- 为新方法添加完整的代码注释

**QR3: 无性能回归**
- 使用 `inline` 确保零成本抽象
- 验证编译后没有额外的运行时开销
- 现有benchmark不受影响

## Technical Notes

### Integration Approach

在 `src/txn.zig` 的 `Txn` 结构体中添加新方法：

```zig
pub const Txn = struct {
    // ... 现有字段和方法 ...

    /// 存储i32类型数据到数据库
    ///
    /// 这是put()的便捷包装器，自动处理i32到字节的转换。
    ///
    /// 参数：
    ///   dbi - 数据库实例句柄
    ///   key - 键的字节切片
    ///   value - i32类型的值
    ///   flags_set - Put操作标志集合
    ///
    /// 错误：
    ///   MDBXError - 底层MDBX操作错误
    pub inline fn put_i32(
        self: *Self,
        dbi: DBI,
        key: []const u8,
        value: i32,
        flags_set: PutFlagSet
    ) errors.MDBXError!void {
        const val = Val.from_i32(value);
        return self.put(dbi, key, val.toBytes(), flags_set);
    }

    /// 从数据库获取i32类型数据
    ///
    /// 这是get()的便捷包装器，自动处理字节到i32的转换。
    ///
    /// 参数：
    ///   dbi - 数据库实例句柄
    ///   key - 键的字节切片
    ///
    /// 返回：
    ///   i32类型的值
    ///
    /// 错误：
    ///   MDBXError - 底层MDBX操作错误
    ///   InvalidDataLength - 数据长度与i32不匹配
    pub inline fn get_i32(self: *Self, dbi: DBI, key: []const u8) !i32 {
        const val = try self.get(dbi, key);
        return val.to_i32();
    }

    // ... 其他类型的类似方法 ...
};
```

### Existing Pattern Reference

- 参考 `getBytes()` 的实现：
  ```zig
  pub fn getBytes(self: *Self, dbi: DBI, key: []const u8) errors.MDBXError![]const u8 {
      const val = try self.get(dbi, key);
      return val.toBytes();
  }
  ```
- 新的类型化方法遵循相同的模式：调用底层方法 + 转换

### Key Constraints

1. **依赖顺序**: 必须先实现Val的类型化API（typed-value-api.md）
2. **零成本抽象**: 使用 `inline` 确保编译器优化
3. **错误传递**: 正确传递所有可能的错误类型
4. **类型安全**: 编译时类型检查，无运行时类型转换

### Implementation Scope

**核心类型**（本Story）
- 有符号整数：i8, i16, i32, i64, i128
- 无符号整数：u8, u16, u32, u64, u128
- 每种类型2个方法（get和put）= 20个方法

## Definition of Done

- [x] FR1: 所有整数类型的put方法已实现
- [x] FR2: 所有整数类型的get方法已实现
- [x] IR1: 向后兼容性验证通过
- [x] IR2: 新方法遵循现有代码模式
- [x] IR3: 与Val API集成验证通过
- [x] QR1: 单元测试添加并通过
- [x] QR2: 文档更新完成
- [x] QR3: 性能benchmark无回归

## Risk and Compatibility Check

### Minimal Risk Assessment

**Primary Risk**:
- 与Val API的耦合：如果Val API设计有问题，会影响Txn API

**Mitigation**:
- 先实现并验证Val API
- 确保Val API稳定后再实现Txn API
- 保持薄包装器设计，便于调整

**Rollback**:
- 纯新增API，不修改现有代码
- 如需回滚，直接删除新增方法即可
- 不影响数据库内容和格式

### Compatibility Verification

- [x] **无破坏性变更**: 只添加新方法，不修改现有API
- [x] **数据库兼容**: 不改变数据存储格式
- [x] **性能影响**: 使用inline，性能影响可忽略不计
- [x] **设计模式**: 遵循getBytes()的便捷方法模式

## Validation Checklist

### Scope Validation

- [x] **单次开发会话**: 预计2-3小时可完成
  - 20个方法（10种类型 × 2方向）
  - 每个方法约5-7行代码（含注释）

- [x] **集成简单**: 只在Txn结构体内添加方法
  - 依赖已实现的Val API
  - 无复杂依赖

- [x] **遵循现有模式**: 完全照搬getBytes()模式

- [x] **无架构设计**: 不需要新的架构决策

### Clarity Check

- [x] **需求明确**: 清楚需要添加哪些方法
- [x] **集成点明确**: src/txn.zig的Txn结构体
- [x] **成功标准可测**: 可以通过单元测试验证
- [x] **回滚简单**: 删除新增方法即可

## Usage Example

实现后的使用示例（与第一个story的示例对比）：

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

    // 新API - 最简洁的类型化写入（一行代码！）
    const put_flags = zmdbx.PutFlagSet.init(.{});
    try txn.put_u32(dbi, "age", 25, put_flags);
    try txn.put_i64(dbi, "score", -1000, put_flags);
    try txn.put_u8(dbi, "level", 5, put_flags);

    try txn.commit();

    // 新API - 最简洁的类型化读取（一行代码！）
    var read_txn = try env.beginReadTxn();
    defer read_txn.abort();

    const dbi2 = try read_txn.openDBI(null, zmdbx.DBFlagSet.init(.{}));

    const age = try read_txn.get_u32(dbi2, "age");
    const score = try read_txn.get_i64(dbi2, "score");
    const level = try read_txn.get_u8(dbi2, "level");

    std.debug.print("age: {}\n", .{age});       // 输出: age: 25
    std.debug.print("score: {}\n", .{score});   // 输出: score: -1000
    std.debug.print("level: {}\n", .{level});   // 输出: level: 5
}
```

### 三种API方式对比

```zig
// 方式1: 原始API - 最灵活但最繁琐
const age: u32 = 25;
const age_bytes = std.mem.asBytes(&age);
try txn.put(dbi, "age", age_bytes, put_flags);
const val = try txn.get(dbi, "age");
const bytes = val.toBytes();
const age_read = std.mem.bytesToValue(u32, bytes[0..@sizeOf(u32)]);

// 方式2: Val API - 类型安全但需要两步
const age: u32 = 25;
const age_val = zmdbx.Val.from_u32(age);
try txn.put(dbi, "age", age_val.toBytes(), put_flags);
const val = try txn.get(dbi, "age");
const age_read = try val.to_u32();

// 方式3: Txn API - 最简洁（推荐）
try txn.put_u32(dbi, "age", 25, put_flags);
const age_read = try txn.get_u32(dbi, "age");
```

## Dependencies

### Story Dependencies

- **Depends On**: `typed-value-api.md` (Val类型化数据转换API)
  - 必须先实现Val的`from_TYPE()`和`to_TYPE()`方法
  - Txn方法内部调用Val的类型化方法

### Implementation Order

1. ✅ **先实现**: Val的类型化API
2. 🔄 **后实现**: Txn的类型化便捷方法（本Story）

## Estimated Effort

- **代码实现**: 1.5 小时（20个方法，每个约5-7行含注释）
- **单元测试**: 1 小时（测试所有类型的往返操作）
- **文档更新**: 0.5 小时（API文档和README示例）
- **总计**: 约 3 小时

## Success Metrics

- [ ] 所有整数类型（i8-i128, u8-u128）都有对应的get_/put_方法
- [ ] 所有新方法都有完整的中文注释
- [ ] 至少有10个单元测试覆盖核心功能
- [ ] README中有清晰的使用示例和API对比
- [ ] 快速开始部分更新为使用新API
- [ ] 现有的所有测试继续通过
- [ ] 无性能回归

## Relationship with Other Stories

### Related Stories

1. **typed-value-api.md** - Val类型化数据转换API
   - 关系：前置依赖
   - 提供底层的类型转换能力

2. **未来Story**: 类型化Cursor API
   - 关系：后续增强
   - 可能为Cursor也添加类型化方法

### Epic Consideration

如果还需要为Cursor添加类型化API，建议创建Epic：
- **Epic名称**: "zmdbx类型化API增强"
- **包含Stories**:
  1. Val类型化API
  2. Txn类型化API
  3. Cursor类型化API（可选）

---

**Story Status**: 📝 Ready for Implementation (需要先完成typed-value-api.md)
**Priority**: Medium
**Story Points**: 3
**Dependencies**: typed-value-api.md
**Created**: 2025-10-16
