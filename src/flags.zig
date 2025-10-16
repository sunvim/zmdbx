// 标志和枚举类型定义模块
//
// 本模块包含所有 MDBX 操作使用的标志和枚举类型。
// 标志类型设计允许按位组合，提供了类型安全的 API。

const std = @import("std");
const c = @import("c.zig").c;

/// 环境标志
///
/// 用于配置 MDBX 环境的行为。
/// 可以使用 EnvFlagSet 组合多个标志。
pub const EnvFlag = enum {
    /// 启用额外的数据库结构和页面内容验证
    validation,

    /// 不使用子目录存储数据库文件
    no_sub_dir,

    /// 以只读模式打开环境
    read_only,

    /// 独占访问模式
    exclusive,

    /// 接受现有环境（即使被其他进程使用）
    accede,

    /// 使用写入映射模式
    write_map,

    /// 不使用线程局部存储
    no_tls,

    /// 禁用预读
    no_read_ahead,

    /// 不初始化内存（性能优化，但可能有安全隐患）
    no_mem_init,

    /// 合并空闲页面
    coalesce,

    /// LIFO 回收策略
    lifo_reclaim,

    /// 页面扰动（用于测试）
    page_perturb,

    /// 不同步元数据
    no_meta_sync,

    /// 安全的无同步模式
    safe_no_sync,

    /// 完全无同步模式（性能最高，但崩溃可能丢失数据）
    utterly_no_sync,

    /// 转换为 C API 标志值
    pub inline fn toInt(self: EnvFlag) c.MDBX_env_flags_t {
        return switch (self) {
            .validation => c.MDBX_VALIDATION,
            .no_sub_dir => c.MDBX_NOSUBDIR,
            .read_only => c.MDBX_RDONLY,
            .exclusive => c.MDBX_EXCLUSIVE,
            .accede => c.MDBX_ACCEDE,
            .write_map => c.MDBX_WRITEMAP,
            .no_tls => c.MDBX_NOTLS,
            .no_read_ahead => c.MDBX_NORDAHEAD,
            .no_mem_init => c.MDBX_NOMEMINIT,
            .coalesce => c.MDBX_COALESCE,
            .lifo_reclaim => c.MDBX_LIFORECLAIM,
            .page_perturb => c.MDBX_PAGEPERTURB,
            .no_meta_sync => c.MDBX_NOMETASYNC,
            .safe_no_sync => c.MDBX_SAFE_NOSYNC,
            .utterly_no_sync => c.MDBX_UTTERLY_NOSYNC,
        };
    }
};

/// 环境标志集合
///
/// 允许组合多个环境标志。
pub const EnvFlagSet = std.EnumSet(EnvFlag);

/// 将标志集合转换为 C API 使用的位掩码
pub inline fn envFlagsToInt(flags: EnvFlagSet) c.MDBX_env_flags_t {
    if (flags.count() == 0) {
        return c.MDBX_ENV_DEFAULTS;
    }

    var result: c.MDBX_env_flags_t = 0;
    var iter = flags.iterator();
    while (iter.next()) |flag| {
        result |= flag.toInt();
    }
    return result;
}

/// 数据库标志
pub const DBFlag = enum {
    /// 键按反向排序
    reverse_key,

    /// 允许重复键（排序的重复项）
    dup_sort,

    /// 键是固定大小的整数
    integer_key,

    /// 重复数据项是固定大小
    dup_fixed,

    /// 重复数据项是整数
    integer_dup,

    /// 反向排序重复数据
    reverse_dup,

    /// 如果数据库不存在则创建
    create,

    /// 接受现有数据库
    db_accede,

    pub inline fn toInt(self: DBFlag) c.MDBX_db_flags_t {
        return switch (self) {
            .reverse_key => c.MDBX_REVERSEKEY,
            .dup_sort => c.MDBX_DUPSORT,
            .integer_key => c.MDBX_INTEGERKEY,
            .dup_fixed => c.MDBX_DUPFIXED,
            .integer_dup => c.MDBX_INTEGERDUP,
            .reverse_dup => c.MDBX_REVERSEDUP,
            .create => c.MDBX_CREATE,
            .db_accede => c.MDBX_DB_ACCEDE,
        };
    }
};

pub const DBFlagSet = std.EnumSet(DBFlag);

pub inline fn dbFlagsToInt(flags: DBFlagSet) c.MDBX_db_flags_t {
    if (flags.count() == 0) {
        return c.MDBX_DB_DEFAULTS;
    }

    var result: c.MDBX_db_flags_t = 0;
    var iter = flags.iterator();
    while (iter.next()) |flag| {
        result |= flag.toInt();
    }
    return result;
}

/// 事务标志
pub const TxFlag = enum {
    /// 启动只读事务
    read_only,

    /// 准备但不启动只读事务
    read_only_prepare,

    /// 启动写事务时不阻塞
    try_start,

    /// 仅此事务不同步元数据
    no_meta_sync,

    /// 仅此事务不同步
    no_sync,

    pub inline fn toInt(self: TxFlag) c.MDBX_txn_flags_t {
        return switch (self) {
            .read_only => c.MDBX_TXN_RDONLY,
            .read_only_prepare => c.MDBX_TXN_RDONLY_PREPARE,
            .try_start => c.MDBX_TXN_TRY,
            .no_meta_sync => c.MDBX_TXN_NOMETASYNC,
            .no_sync => c.MDBX_TXN_NOSYNC,
        };
    }
};

pub const TxFlagSet = std.EnumSet(TxFlag);

pub inline fn txFlagsToInt(flags: TxFlagSet) c.MDBX_txn_flags_t {
    if (flags.count() == 0) {
        return c.MDBX_TXN_READWRITE; // 默认读写事务
    }

    var result: c.MDBX_txn_flags_t = 0;
    var iter = flags.iterator();
    while (iter.next()) |flag| {
        result |= flag.toInt();
    }
    return result;
}

/// Put 操作标志
pub const PutFlag = enum {
    /// 如果键已存在则不写入
    no_overwrite,

    /// 如果键和数据对已存在则不写入
    no_dup_data,

    /// 将当前键的数据更新为新数据
    current,

    /// 删除/替换给定键的所有多值
    all_dups,

    /// 为数据预留空间，但不写入
    reserve,

    /// 将数据追加到数据库末尾
    append,

    /// 将重复数据追加到当前键
    append_dup,

    /// 存储多个数据项（仅用于 MDBX_DUPFIXED）
    multiple,

    pub inline fn toInt(self: PutFlag) c.MDBX_put_flags_t {
        return switch (self) {
            .no_overwrite => c.MDBX_NOOVERWRITE,
            .no_dup_data => c.MDBX_NODUPDATA,
            .current => c.MDBX_CURRENT,
            .all_dups => c.MDBX_ALLDUPS,
            .reserve => c.MDBX_RESERVE,
            .append => c.MDBX_APPEND,
            .append_dup => c.MDBX_APPENDDUP,
            .multiple => c.MDBX_MULTIPLE,
        };
    }
};

pub const PutFlagSet = std.EnumSet(PutFlag);

pub inline fn putFlagsToInt(flags: PutFlagSet) c.MDBX_put_flags_t {
    if (flags.count() == 0) {
        return c.MDBX_UPSERT; // 默认更新插入
    }

    var result: c.MDBX_put_flags_t = 0;
    var iter = flags.iterator();
    while (iter.next()) |flag| {
        result |= flag.toInt();
    }
    return result;
}

/// 复制标志
pub const CopyFlag = enum {
    /// 压缩复制（省略空闲空间）
    compact,

    /// 强制动态大小
    force_dynamic_size,

    pub inline fn toInt(self: CopyFlag) c.MDBX_copy_flags_t {
        return switch (self) {
            .compact => c.MDBX_CP_COMPACT,
            .force_dynamic_size => c.MDBX_CP_FORCE_DYNAMIC_SIZE,
        };
    }
};

pub const CopyFlagSet = std.EnumSet(CopyFlag);

pub inline fn copyFlagsToInt(flags: CopyFlagSet) c.MDBX_copy_flags_t {
    if (flags.count() == 0) {
        return c.MDBX_CP_DEFAULTS;
    }

    var result: c.MDBX_copy_flags_t = 0;
    var iter = flags.iterator();
    while (iter.next()) |flag| {
        result |= flag.toInt();
    }
    return result;
}

/// DBI 状态（互斥枚举，不是位标志）
pub const DBIState = enum(c.MDBX_dbi_state_t) {
    dirty = c.MDBX_DBI_DIRTY,
    stale = c.MDBX_DBI_STALE,
    fresh = c.MDBX_DBI_FRESH,
    creat = c.MDBX_DBI_CREAT,
};

/// 删除模式（互斥枚举，不是位标志）
pub const DeleteMode = enum(c.MDBX_env_delete_mode_t) {
    /// 直接删除
    just_delete = c.MDBX_ENV_JUST_DELETE,

    /// 确保未被使用
    ensure_unused = c.MDBX_ENV_ENSURE_UNUSED,

    /// 等待直到未被使用
    wait_for_unused = c.MDBX_ENV_WAIT_UNUSED,
};

/// 游标操作类型（互斥枚举，不是位标志）
pub const CursorOp = enum(c.MDBX_cursor_op) {
    first = c.MDBX_FIRST,
    first_dup = c.MDBX_FIRST_DUP,
    get_both = c.MDBX_GET_BOTH,
    get_both_range = c.MDBX_GET_BOTH_RANGE,
    get_current = c.MDBX_GET_CURRENT,
    get_multiple = c.MDBX_GET_MULTIPLE,
    last = c.MDBX_LAST,
    last_dup = c.MDBX_LAST_DUP,
    next = c.MDBX_NEXT,
    next_dup = c.MDBX_NEXT_DUP,
    next_multiple = c.MDBX_NEXT_MULTIPLE,
    next_nodup = c.MDBX_NEXT_NODUP,
    prev = c.MDBX_PREV,
    prev_dup = c.MDBX_PREV_DUP,
    prev_nodup = c.MDBX_PREV_NODUP,
    set = c.MDBX_SET,
    set_key = c.MDBX_SET_KEY,
    set_range = c.MDBX_SET_RANGE,
    set_lowerbound = c.MDBX_SET_LOWERBOUND,
    set_upperbound = c.MDBX_SET_UPPERBOUND,
};

// 单元测试
test "EnvFlagSet combination" {
    var flags = EnvFlagSet.init(.{});
    flags.insert(.validation);
    flags.insert(.no_sub_dir);

    const c_flags = envFlagsToInt(flags);
    try std.testing.expect(c_flags & c.MDBX_VALIDATION != 0);
    try std.testing.expect(c_flags & c.MDBX_NOSUBDIR != 0);
}

test "DBFlagSet combination" {
    var flags = DBFlagSet.init(.{});
    flags.insert(.create);
    flags.insert(.dup_sort);

    const c_flags = dbFlagsToInt(flags);
    try std.testing.expect(c_flags & c.MDBX_CREATE != 0);
    try std.testing.expect(c_flags & c.MDBX_DUPSORT != 0);
}

test "Empty flag set returns default" {
    const env_flags = envFlagsToInt(EnvFlagSet.init(.{}));
    try std.testing.expectEqual(@as(c.MDBX_env_flags_t, c.MDBX_ENV_DEFAULTS), env_flags);

    const db_flags = dbFlagsToInt(DBFlagSet.init(.{}));
    try std.testing.expectEqual(@as(c.MDBX_db_flags_t, c.MDBX_DB_DEFAULTS), db_flags);
}
