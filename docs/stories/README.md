# zmdbx Stories - 产品需求规划

## 📋 Overview

本目录包含zmdbx项目的产品需求文档，采用Epic和Story的组织方式。

## 📊 当前Epic

### Epic: zmdbx类型化API增强

**文件**: [epic-typed-api.md](./epic-typed-api.md)

**状态**: 📋 Ready for Implementation

**目标**: 为zmdbx提供类型安全且用户友好的API，允许用户直接存储和读取基本数字类型

**优先级**: High

**总Story Points**: 8-9点

**预计时间**:
- 核心功能（推荐MVP）: 6小时
- 完整功能: 9小时

---

## 📖 Stories列表

### Story 1: Val类型化数据转换API ⭐ 核心

**文件**: [typed-value-api.md](./typed-value-api.md)

**优先级**: High | **Story Points**: 3 | **预计**: 3小时

**状态**: ✅ Ready for Implementation

**依赖**: 无

**描述**: 为Val结构体添加类型化的构造和转换方法

**关键功能**:
- 添加 `from_i8()` 到 `from_i128()` 和 `from_u8()` 到 `from_u128()` 静态方法
- 添加 `to_i8()` 到 `to_i128()` 和 `to_u8()` 到 `to_u128()` 实例方法
- 支持所有基本整数类型的双向转换

**价值**: 为所有类型化API提供底层转换能力

---

### Story 2: Txn类型化便捷方法 ⭐ 重要

**文件**: [typed-transaction-api.md](./typed-transaction-api.md)

**优先级**: Medium | **Story Points**: 3 | **预计**: 3小时

**状态**: ✅ Ready for Implementation

**依赖**: Story 1

**描述**: 为Txn结构体添加类型化的get和put便捷方法

**关键功能**:
- 添加 `get_i8()` 到 `get_i128()` 和 `get_u8()` 到 `get_u128()` 方法
- 添加 `put_i8()` 到 `put_i128()` 和 `put_u8()` 到 `put_u128()` 方法
- 一行代码完成类型化的存储和读取

**价值**: 用户最常用的直接操作API，最大化用户体验提升

**使用示例**:
```zig
// 写入 - 一行代码
try txn.put_u32(dbi, "age", 25, put_flags);

// 读取 - 一行代码
const age = try txn.get_u32(dbi, "age");
```

---

### Story 3: Cursor类型化API 🔄 可选

**文件**: [typed-cursor-api.md](./typed-cursor-api.md)

**优先级**: Low | **Story Points**: 2-3 | **预计**: 3小时

**状态**: ✅ Ready for Implementation (优先级低，可选)

**依赖**: Story 1

**描述**: 为Cursor结构体添加类型化的get和put方法

**关键功能**:
- 添加 `get_i8()` 到 `get_i128()` 和 `get_u8()` 到 `get_u128()` 方法
- 添加 `put_i8()` 到 `put_i128()` 和 `put_u8()` 到 `put_u128()` 方法
- 简化游标遍历中的类型转换

**价值**: 提供API完整性，覆盖游标遍历场景

**使用示例**:
```zig
var result = try cursor.get_i32(null, null, .first);
while (true) {
    const score = result.data; // 直接是i32类型！
    // ... 处理 score ...
    result = cursor.get_i32(null, null, .next) catch break;
}
```

---

## 🎯 实施建议

### 推荐的MVP（最小可行产品）

**实施**: Story 1 + Story 2

**理由**:
- 覆盖90%的用户使用场景
- 6 Story Points，约6小时工作量
- Cursor使用频率较低，可以后续补充

**实施顺序**:
1. Story 1: Val类型化API（3小时）
2. Story 2: Txn类型化API（3小时）

### 完整实施（可选）

**实施**: Story 1 + Story 2 + Story 3

**理由**:
- 提供完整的API体验
- 8-9 Story Points，约9小时工作量
- API完整性和一致性

**实施顺序**:
1. Story 1: Val类型化API（3小时）
2. Story 2: Txn类型化API（3小时）
3. Story 3: Cursor类型化API（3小时）

---

## 📈 依赖关系图

```
Story 1: Val类型化API (核心基础)
    ↓
    ├── Story 2: Txn类型化API (重要，常用)
    └── Story 3: Cursor类型化API (可选，低频)
```

**说明**:
- Story 2 和 Story 3 都依赖 Story 1
- Story 2 和 Story 3 之间无依赖，可以并行实施

---

## 📊 工作量统计

### 核心功能（MVP）
| Story | Points | 预计时间 | 状态 |
|-------|--------|----------|------|
| Val类型化API | 3 | 3小时 | Ready |
| Txn类型化API | 3 | 3小时 | Ready |
| **总计** | **6** | **6小时** | - |

### 完整功能
| Story | Points | 预计时间 | 状态 |
|-------|--------|----------|------|
| Val类型化API | 3 | 3小时 | Ready |
| Txn类型化API | 3 | 3小时 | Ready |
| Cursor类型化API | 2-3 | 3小时 | Ready (可选) |
| **总计** | **8-9** | **9小时** | - |

---

## ✅ 质量标准

所有Story必须满足以下标准：

### 代码质量
- ✅ 使用 `inline` 关键字确保零成本抽象
- ✅ 完整的中文注释（说明用途、参数、返回值、错误）
- ✅ 遵循现有的代码风格和命名规范
- ✅ 符合Zig最佳实践

### 测试覆盖
- ✅ 每个方法至少1个单元测试
- ✅ 测试边界条件（最大值、最小值、零）
- ✅ 测试错误情况（数据长度不匹配）
- ✅ 测试往返转换（value → bytes → value）
- ✅ 所有现有测试继续通过

### 文档更新
- ✅ 更新 API_CHEATSHEET.md
- ✅ 更新 README.md 添加使用示例
- ✅ 为新方法添加完整的代码注释
- ✅ 在文档中说明字节序兼容性问题

### 性能要求
- ✅ 使用 `inline` 确保零成本抽象
- ✅ Benchmark验证无性能回归
- ✅ 与手动转换性能完全相同

---

## 🎯 成功标准

Epic成功完成的标准：

### 功能完整性
- [ ] 所有计划的Story已完成（至少Story 1和2）
- [ ] 所有类型化方法已实现并测试通过
- [ ] 文档和示例已更新

### 用户体验
- [ ] 用户可以用1行代码完成类型化操作（vs 之前的5-6行）
- [ ] 编译时类型检查，零运行时类型错误
- [ ] API直观易用，降低学习曲线

### 向后兼容
- [ ] 所有现有API继续正常工作
- [ ] 现有代码无需任何修改
- [ ] 数据库格式完全兼容

### 质量保证
- [ ] 所有测试通过（包括新增和现有测试）
- [ ] 无性能回归
- [ ] 文档完整清晰

---

## 📝 使用示例

### 改进前后对比

#### 之前：繁琐的手动转换
```zig
// 写入 - 5行代码
const age: u32 = 25;
const age_bytes = std.mem.asBytes(&age);
try txn.put(dbi, "age", age_bytes, put_flags);

// 读取 - 4行代码
const val = try txn.get(dbi, "age");
const bytes = val.toBytes();
const age_read = std.mem.bytesToValue(u32, bytes[0..@sizeOf(u32)]);
```

#### 之后：简洁的类型化API
```zig
// 写入 - 1行代码
try txn.put_u32(dbi, "age", 25, put_flags);

// 读取 - 1行代码
const age_read = try txn.get_u32(dbi, "age");
```

### 实际应用场景

```zig
// 游戏玩家数据管理
try txn.put_u32(dbi, "player:001:score", 1500, put_flags);
try txn.put_u8(dbi, "player:001:level", 25, put_flags);
try txn.put_i64(dbi, "player:001:exp", -100, put_flags);

// 读取并计算
const score = try txn.get_u32(dbi, "player:001:score");
const level = try txn.get_u8(dbi, "player:001:level");
const exp = try txn.get_i64(dbi, "player:001:exp");

std.debug.print("玩家: 分数={}, 等级={}, 经验={}\n", .{score, level, exp});
```

---

## 🚀 下一步

1. **选择实施范围**
   - 推荐：Story 1 + Story 2（MVP，6小时）
   - 完整：Story 1 + Story 2 + Story 3（9小时）

2. **按顺序实施**
   - 第一步：Story 1（Val类型化API）
   - 第二步：Story 2（Txn类型化API）
   - 第三步（可选）：Story 3（Cursor类型化API）

3. **每个Story完成后**
   - 运行所有测试确保无回归
   - 更新相应的文档
   - 创建示例代码

4. **Epic完成后**
   - 更新CHANGELOG
   - 发布Release Notes
   - 在README中突出新功能

---

## 📞 联系方式

如有问题或建议，请通过以下方式联系：

- 提交 Issue: https://github.com/sunvim/zmdbx/issues
- Email: mobussun@gmail.com

---

**文档版本**: v1.0
**创建日期**: 2025-10-16
**最后更新**: 2025-10-16
**产品经理**: John 📋
