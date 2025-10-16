# Cursor类型化API - Brownfield Story

## Story Title

**Cursor类型化便捷方法 - Brownfield Addition**

## User Story

**作为** zmdbx库的使用者，
**我想要** 能够在使用游标遍历数据时直接读取类型化的数值，
**以便** 我在迭代处理数据时不需要手动进行类型转换，提高代码简洁性。

## Story Context

### Existing System Integration

- **集成点**: `src/cursor.zig` 中的 `Cursor` 结构体
- **技术栈**: Zig 0.15.2, libmdbx C绑定
- **遵循模式**:
  - 已有的 `getBytes()` 便捷方法（返回字节切片）
  - 使用 `inline` 函数保证零成本抽象
  - 完整的中文注释和文档
- **依赖关系**:
  - **依赖于** `typed-value-api.md` 故事（Val的类型化API）
  - 内部使用Val的`to_TYPE()`方法进行转换
- **触点**:
  - 现有的`Cursor.get()`方法（返回`{key: Val, data: Val}`）
  - 现有的`Cursor.getBytes()`方法（返回`{key: []const u8, data: []const u8}`）
  - 现有的`Cursor.put()`方法
  - CursorOp枚举（游标操作类型）

### Current Pain Point

使用游标遍历数值型数据时需要重复转换：

```zig
// 当前方式 - 每次迭代都需要手动转换
var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
defer cursor.close();

var result = try cursor.get(null, null, .first);
while (true) {
    const key = result.key.toBytes();
    const value_bytes = result.data.toBytes();
    const score = try std.mem.bytesToValue(i32, value_bytes[0..@sizeOf(i32)]);

    std.debug.print("key: {s}, score: {}\n", .{key, score});

    result = cursor.get(null, null, .next) catch |err| {
        if (err == error.NotFound) break;
        return err;
    };
}
```

## Acceptance Criteria

### Functional Requirements

**FR1: Cursor类型化读取方法 - data转换**
- Cursor结构体提供 `get_i8()`, `get_i16()`, `get_i32()`, `get_i64()`, `get_i128()` 方法
- Cursor结构体提供 `get_u8()`, `get_u16()`, `get_u32()`, `get_u64()`, `get_u128()` 方法
- 所有方法返回 `struct { key: []const u8, data: TYPE }`
- 所有方法接受与现有`get()`相同的参数：`key: ?[]const u8, data: ?[]const u8, op: CursorOp`

**FR2: Cursor类型化写入方法 - data转换**
- Cursor结构体提供 `put_i8()`, `put_i16()`, `put_i32()`, `put_i64()`, `put_i128()` 方法
- Cursor结构体提供 `put_u8()`, `put_u16()`, `put_u32()`, `put_u64()`, `put_u128()` 方法
- 所有方法接受参数：`key: []const u8, value: TYPE, flags_set: PutFlagSet`
- 内部使用Val的`from_TYPE()`方法进行转换

**FR3: 保持一致性**
- 方法签名与现有的`get()`和`getBytes()`保持一致
- 错误处理方式与现有方法一致
- 支持所有CursorOp操作（first, last, next, prev, set_range等）

### Integration Requirements

**IR1: 向后兼容性**
- 现有的 `get()`, `getBytes()`, `put()` 方法继续正常工作
- 不修改Cursor结构体的内部字段
- 不影响现有的游标遍历代码

**IR2: 遵循现有模式**
- 所有新方法使用 `inline` 关键字
- 参考`getBytes()`的实现模式
- 添加完整的中文注释

**IR3: 与Val API集成**
- 新方法内部使用Val的类型化API
- 依赖关系明确：需要先实现Val的类型化API

### Quality Requirements

**QR1: 测试覆盖**
- 为所有新增的类型化方法添加单元测试
- 测试游标遍历场景（first → next → ... → NotFound）
- 测试范围查询场景（set_range）
- 测试错误情况（如数据长度不匹配）

**QR2: 文档更新**
- 更新 `docs/API_CHEATSHEET.md` 添加新API
- 在README.md的Cursor部分添加使用示例
- 创建新的示例文件展示类型化游标使用
- 为新方法添加完整的代码注释

**QR3: 无性能回归**
- 使用 `inline` 确保零成本抽象
- 游标遍历性能不受影响
- 现有benchmark不受影响

## Technical Notes

### Integration Approach

在 `src/cursor.zig` 的 `Cursor` 结构体中添加新方法：

```zig
pub const Cursor = struct {
    // ... 现有字段和方法 ...

    /// 使用游标获取数据（i32类型的data）
    ///
    /// 这是get()的便捷包装器，自动将data转换为i32类型。
    /// key仍然作为字节切片返回。
    ///
    /// 参数：
    ///   key - 可选的键，用于某些游标操作
    ///   data - 可选的数据，用于某些游标操作
    ///   op - 游标操作类型
    ///
    /// 返回：
    ///   包含key（字节切片）和data（i32）的结构体
    ///
    /// 错误：
    ///   MDBXError - 底层MDBX操作错误
    ///   InvalidDataLength - 数据长度与i32不匹配
    pub inline fn get_i32(
        self: *Self,
        key: ?[]const u8,
        data: ?[]const u8,
        op: CursorOp,
    ) !struct { key: []const u8, data: i32 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_i32(),
        };
    }

    /// 使用游标插入i32类型的数据
    ///
    /// 这是put()的便捷包装器，自动将i32转换为字节。
    ///
    /// 参数：
    ///   key - 键的字节切片
    ///   value - i32类型的值
    ///   flags_set - Put操作标志集合
    ///
    /// 错误：
    ///   MDBXError - 底层MDBX操作错误
    pub inline fn put_i32(
        self: *Self,
        key: []const u8,
        value: i32,
        flags_set: PutFlagSet,
    ) errors.MDBXError!void {
        const val = Val.from_i32(value);
        return self.put(key, val.toBytes(), flags_set);
    }

    // ... 其他类型的类似方法 ...
};
```

### Existing Pattern Reference

- 参考 `getBytes()` 的实现：
  ```zig
  pub fn getBytes(...) !struct { key: []const u8, data: []const u8 } {
      const result = try self.get(key, data, op);
      return .{
          .key = result.key.toBytes(),
          .data = result.data.toBytes(),
      };
  }
  ```
- 新的类型化方法遵循相同的模式，只是将data转换为具体类型

### Key Constraints

1. **依赖顺序**: 必须先实现Val的类型化API（typed-value-api.md）
2. **零成本抽象**: 使用 `inline` 确保编译器优化
3. **错误传递**: 正确传递所有可能的错误类型
4. **Key保持字符串**: 通常key是字符串标识符，只对data进行类型化

### Design Decision: Key vs Data

**决定**: 只对data进行类型化，key保持为 `[]const u8`

**理由**:
1. 在大多数用例中，key是字符串标识符（如"user:001"）
2. data才是需要存储和读取数值的部分
3. 保持API简洁，避免不必要的复杂性

**替代方案**（未来可选）:
- 如果需要类型化的key，可以单独创建方法
- 或者提供泛型方法支持自定义key/data转换

### Implementation Scope

**核心类型**（本Story）
- 有符号整数：i8, i16, i32, i64, i128
- 无符号整数：u8, u16, u32, u64, u128
- 每种类型2个方法（get和put）= 20个方法

## Definition of Done

- [x] FR1: 所有整数类型的get方法已实现
- [x] FR2: 所有整数类型的put方法已实现
- [x] IR1: 向后兼容性验证通过
- [x] IR2: 新方法遵循现有代码模式
- [x] IR3: 与Val API集成验证通过
- [x] QR1: 单元测试添加并通过
- [x] QR2: 文档和示例更新完成
- [x] QR3: 性能benchmark无回归

## Risk and Compatibility Check

### Minimal Risk Assessment

**Primary Risk**:
- 游标遍历中的类型转换错误可能导致迭代中断

**Mitigation**:
- 所有类型转换都有错误处理
- 单元测试覆盖各种遍历场景
- 错误信息清晰（如InvalidDataLength）

**Rollback**:
- 纯新增API，不修改现有代码
- 如需回滚，直接删除新增方法即可
- 不影响现有游标使用代码

### Compatibility Verification

- [x] **无破坏性变更**: 只添加新方法，不修改现有API
- [x] **性能影响**: 使用inline，性能影响可忽略不计
- [x] **设计模式**: 遵循getBytes()的便捷方法模式

## Validation Checklist

### Scope Validation

- [x] **单次开发会话**: 预计2-3小时可完成
  - 20个方法（10种类型 × 2方向）
  - 每个方法约6-8行代码（含注释）

- [x] **集成简单**: 只在Cursor结构体内添加方法
  - 依赖已实现的Val API
  - 无复杂依赖

- [x] **遵循现有模式**: 完全照搬getBytes()模式

- [x] **无架构设计**: 不需要新的架构决策

### Clarity Check

- [x] **需求明确**: 清楚需要添加哪些方法
- [x] **集成点明确**: src/cursor.zig的Cursor结构体
- [x] **成功标准可测**: 可以通过游标遍历测试验证
- [x] **回滚简单**: 删除新增方法即可

## Usage Example

实现后的使用示例：

```zig
const std = @import("std");
const zmdbx = @import("zmdbx");

pub fn main() !void {
    var env = try zmdbx.Env.init();
    defer env.deinit();
    try env.open("./mydb", zmdbx.EnvFlagSet.init(.{}), 0o644);

    // 写入一些分数数据
    {
        var txn = try env.beginWriteTxn();
        defer txn.abort();

        var db_flags = zmdbx.DBFlagSet.init(.{});
        db_flags.insert(.create);
        const dbi = try txn.openDBI(null, db_flags);

        var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
        defer cursor.close();

        const put_flags = zmdbx.PutFlagSet.init(.{});

        // 新API - 类型化写入
        try cursor.put_i32("player:001", 1500, put_flags);
        try cursor.put_i32("player:002", 2300, put_flags);
        try cursor.put_i32("player:003", 1800, put_flags);
        try cursor.put_i32("player:004", 2100, put_flags);

        try txn.commit();
    }

    // 使用游标遍历并计算总分
    {
        var txn = try env.beginReadTxn();
        defer txn.abort();

        const dbi = try txn.openDBI(null, zmdbx.DBFlagSet.init(.{}));
        var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
        defer cursor.close();

        // 新API - 类型化读取（简洁的遍历！）
        var result = try cursor.get_i32(null, null, .first);
        var total_score: i32 = 0;
        var count: usize = 0;

        while (true) {
            count += 1;
            total_score += result.data;
            std.debug.print("[{d}] {s}: {}\n", .{ count, result.key, result.data });

            result = cursor.get_i32(null, null, .next) catch |err| {
                if (err == error.NotFound) break;
                return err;
            };
        }

        const avg_score = @divTrunc(total_score, @as(i32, @intCast(count)));
        std.debug.print("\n总计: {d} 名玩家, 平均分: {}\n", .{ count, avg_score });
    }
}
```

### 与现有API对比

```zig
// 方式1: 原始API - 繁琐
var result = try cursor.get(null, null, .first);
while (true) {
    const bytes = result.data.toBytes();
    const score = std.mem.bytesToValue(i32, bytes[0..@sizeOf(i32)]);
    // ... 处理 score ...
    result = cursor.get(null, null, .next) catch break;
}

// 方式2: 使用Val API - 仍需两步
var result = try cursor.get(null, null, .first);
while (true) {
    const score = try result.data.to_i32();
    // ... 处理 score ...
    result = cursor.get(null, null, .next) catch break;
}

// 方式3: Cursor类型化API - 最简洁（推荐）
var result = try cursor.get_i32(null, null, .first);
while (true) {
    const score = result.data; // 直接就是i32类型！
    // ... 处理 score ...
    result = cursor.get_i32(null, null, .next) catch break;
}
```

## Dependencies

### Story Dependencies

- **Depends On**: `typed-value-api.md` (Val类型化数据转换API)
  - 必须先实现Val的`from_TYPE()`和`to_TYPE()`方法
  - Cursor方法内部调用Val的类型化方法

### Implementation Order

1. ✅ **先实现**: Val的类型化API
2. 🔄 **可选先实现**: Txn的类型化API（独立，可并行）
3. 🔄 **后实现**: Cursor的类型化API（本Story）

## Estimated Effort

- **代码实现**: 1.5 小时（20个方法，每个约6-8行含注释）
- **单元测试**: 1 小时（测试游标遍历和范围查询）
- **示例和文档**: 0.5 小时（创建示例文件和更新文档）
- **总计**: 约 3 小时

## Success Metrics

- [ ] 所有整数类型（i8-i128, u8-u128）都有对应的get_/put_方法
- [ ] 所有新方法都有完整的中文注释
- [ ] 至少有10个单元测试覆盖游标遍历场景
- [ ] 创建了新的示例文件展示类型化游标使用
- [ ] README中有清晰的使用示例
- [ ] 现有的所有测试继续通过
- [ ] 无性能回归

## Priority and Scope

**Priority**: Low（可选）

**Rationale**:
- Cursor使用频率低于Txn直接操作
- 大多数用例通过Txn的类型化API已经满足
- 可以作为后续增强功能

**When to Implement**:
- 在Val和Txn的类型化API稳定后
- 如果用户反馈有游标类型化的需求
- 作为API完整性的补充

## Relationship with Other Stories

### Related Stories

1. **typed-value-api.md** - Val类型化数据转换API
   - 关系：前置依赖
   - 提供底层的类型转换能力

2. **typed-transaction-api.md** - Txn类型化便捷方法
   - 关系：并行/无依赖
   - 覆盖大部分直接操作场景

### Epic Organization

作为Epic的可选Story：
- **Epic名称**: "zmdbx类型化API增强"
- **包含Stories**:
  1. Val类型化API（核心）
  2. Txn类型化API（重要）
  3. Cursor类型化API（可选，本Story）

---

**Story Status**: 📝 Ready for Implementation (优先级低，可选)
**Priority**: Low
**Story Points**: 2-3
**Dependencies**: typed-value-api.md
**Created**: 2025-10-16
