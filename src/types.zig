// 共享类型定义模块
//
// 本模块集中定义所有在多个模块间共享的类型，
// 避免类型定义分散和循环依赖问题。

const std = @import("std");
const c = @import("c.zig").c;

/// 数据库实例句柄
///
/// DBI 是一个无符号32位整数，用于标识打开的数据库实例。
/// 注意：DBI 的生命周期与创建它的事务和环境相关联。
pub const DBI = c.MDBX_dbi;

/// 几何配置参数
///
/// 用于配置数据库的大小限制和增长策略。
/// 所有尺寸参数以字节为单位。
pub const Geometry = struct {
    /// 数据库最小大小，-1 表示使用默认值
    lower: isize = -1,

    /// 数据库初始大小，-1 表示使用默认值
    now: isize = -1,

    /// 数据库最大大小，-1 表示使用默认值
    upper: isize = -1,

    /// 数据库增长步长，-1 表示使用默认值
    growth_step: isize = -1,

    /// 数据库收缩阈值，-1 表示使用默认值
    shrink_threshold: isize = -1,

    /// 页面大小，-1 表示使用系统默认值（通常是 4KB）
    pagesize: isize = -1,
};

/// 事务信息结构体
///
/// 包含事务的各种统计信息和元数据。
pub const TxInfo = c.MDBX_txn_info;

/// MDBX 值包装类型
///
/// 这是对 C 类型 MDBX_val 的类型安全包装，提供了：
/// 1. 类型安全的转换方法
/// 2. 避免直接使用 @ptrCast 和 @constCast
/// 3. 明确的生命周期语义
///
/// 重要：Val 实例引用的内存由 MDBX 内部管理，
/// 其生命周期与创建它的事务相关联。
/// 事务提交或中止后，Val 引用的内存可能失效。
pub const Val = struct {
    inner: c.MDBX_val,

    const Self = @This();

    /// 从 Zig 字节切片创建 Val
    ///
    /// 注意：这个方法执行指针类型转换，但不复制数据。
    /// 返回的 Val 引用原始切片的内存。
    ///
    /// 参数：
    ///   data - 字节切片，生命周期必须覆盖 Val 的使用期
    ///
    /// 返回：
    ///   Val 实例，引用传入切片的内存
    pub inline fn fromBytes(data: []const u8) Self {
        return .{
            .inner = .{
                // 使用 @intFromPtr 和 @ptrFromInt 进行类型安全的转换
                // 这避免了直接使用 @constCast，明确了我们在做什么
                .iov_base = @ptrFromInt(@intFromPtr(data.ptr)),
                .iov_len = data.len,
            },
        };
    }

    /// 从可变字节切片创建 Val
    ///
    /// 用于需要写入数据的场景（如 mdbx_get 填充数据）。
    ///
    /// 参数：
    ///   data - 可变字节切片
    ///
    /// 返回：
    ///   Val 实例，可用于接收 MDBX 写入的数据
    pub inline fn fromBytesMut(data: []u8) Self {
        return .{
            .inner = .{
                .iov_base = @ptrCast(data.ptr),
                .iov_len = data.len,
            },
        };
    }

    /// 创建空的 Val，用于接收数据
    ///
    /// 通常用于作为 out 参数传递给 MDBX API。
    ///
    /// 返回：
    ///   未初始化的 Val 实例
    pub inline fn empty() Self {
        return .{
            .inner = .{
                .iov_base = null,
                .iov_len = 0,
            },
        };
    }

    /// 将 Val 转换为 Zig 字节切片
    ///
    /// 警告：返回的切片引用 MDBX 内部管理的内存，
    /// 其生命周期受事务限制。事务结束后使用该切片将导致未定义行为。
    ///
    /// 返回：
    ///   const 字节切片，引用 MDBX 内部内存
    pub inline fn toBytes(self: Self) []const u8 {
        if (self.inner.iov_base == null) {
            return &[_]u8{};
        }
        const ptr: [*]const u8 = @ptrCast(self.inner.iov_base);
        return ptr[0..self.inner.iov_len];
    }

    /// 将 Val 转换为可变字节切片
    ///
    /// 警告：只应在确定 MDBX 允许修改该内存时使用。
    /// 错误使用可能导致数据损坏。
    ///
    /// 返回：
    ///   可变字节切片
    pub inline fn toBytesMut(self: Self) []u8 {
        if (self.inner.iov_base == null) {
            return &[_]u8{};
        }
        const ptr: [*]u8 = @ptrCast(self.inner.iov_base);
        return ptr[0..self.inner.iov_len];
    }

    /// 获取 C API 使用的指针
    ///
    /// 用于传递给底层 MDBX C 函数。
    ///
    /// 返回：
    ///   指向内部 MDBX_val 的指针
    pub inline fn asPtr(self: *Self) *c.MDBX_val {
        return &self.inner;
    }

    /// 获取 C API 使用的 const 指针
    ///
    /// 用于只读操作。
    ///
    /// 返回：
    ///   指向内部 MDBX_val 的 const 指针
    pub inline fn asConstPtr(self: *const Self) *const c.MDBX_val {
        return &self.inner;
    }

    /// 检查 Val 是否为空
    ///
    /// 返回：
    ///   true 如果 Val 不包含数据
    pub inline fn isEmpty(self: Self) bool {
        return self.inner.iov_len == 0;
    }

    /// 获取数据长度
    ///
    /// 返回：
    ///   数据字节数
    pub inline fn len(self: Self) usize {
        return self.inner.iov_len;
    }

    /// 复制数据到新的缓冲区
    ///
    /// 这个方法会分配新内存并复制数据，
    /// 返回的切片生命周期由调用方管理。
    ///
    /// 参数：
    ///   allocator - 内存分配器
    ///
    /// 返回：
    ///   新分配的字节切片，包含复制的数据
    ///
    /// 错误：
    ///   OutOfMemory - 内存分配失败
    pub fn clone(self: Self, allocator: std.mem.Allocator) ![]u8 {
        const bytes = self.toBytes();
        const copy = try allocator.alloc(u8, bytes.len);
        @memcpy(copy, bytes);
        return copy;
    }
};

// 编译期测试确保类型兼容性
comptime {
    // 确保 Val 的大小与 MDBX_val 一致
    if (@sizeOf(Val) != @sizeOf(c.MDBX_val)) {
        @compileError("Val size mismatch with MDBX_val");
    }

    // DBI 应该是整数类型
    const dbi_type_info = @typeInfo(DBI);
    if (dbi_type_info != .int) {
        @compileError("DBI must be an integer type");
    }
}

// 单元测试
test "Val.fromBytes and toBytes" {
    const data = "Hello, MDBX!";
    const val = Val.fromBytes(data);

    const result = val.toBytes();
    try std.testing.expectEqualStrings(data, result);
}

test "Val.empty" {
    const val = Val.empty();
    try std.testing.expect(val.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), val.len());
}

test "Val.clone" {
    const data = "Test data";
    const val = Val.fromBytes(data);

    const allocator = std.testing.allocator;
    const cloned = try val.clone(allocator);
    defer allocator.free(cloned);

    try std.testing.expectEqualStrings(data, cloned);
}
