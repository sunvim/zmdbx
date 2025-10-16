const std = @import("std");
const c = @import("c.zig").c;

const errors = @import("errors.zig");
const types = @import("types.zig");
const flags = @import("flags.zig");

// 重新导出类型，保持向后兼容
pub const DBI = types.DBI;
pub const TxInfo = types.TxInfo;
pub const Val = types.Val;

pub const TxFlag = flags.TxFlag;
pub const TxFlagSet = flags.TxFlagSet;
pub const txFlagsToInt = flags.txFlagsToInt;

pub const PutFlag = flags.PutFlag;
pub const PutFlagSet = flags.PutFlagSet;
pub const putFlagsToInt = flags.putFlagsToInt;

pub const DBFlag = flags.DBFlag;
pub const DBFlagSet = flags.DBFlagSet;
pub const dbFlagsToInt = flags.dbFlagsToInt;

/// 事务句柄
pub const Txn = struct {
    env: *c.MDBX_env,
    txn: ?*c.MDBX_txn,

    const Self = @This();

    /// 创建新事务
    pub fn init(env: *c.MDBX_env, parent: ?*c.MDBX_txn, flags_set: TxFlagSet) errors.MDBXError!Self {
        var txn: ?*c.MDBX_txn = null;
        const c_flags = txFlagsToInt(flags_set);
        const rc = c.mdbx_txn_begin(env, parent, c_flags, &txn);
        try errors.checkError(rc);
        return Self{
            .env = env,
            .txn = txn,
        };
    }

    /// 获取事务信息
    pub fn info(self: *Self) errors.MDBXError!TxInfo {
        var tx_info: TxInfo = undefined;
        const rc = c.mdbx_txn_info(self.txn, &tx_info, true);
        try errors.checkError(rc);
        return tx_info;
    }

    /// 提交事务
    pub fn commit(self: *Self) errors.MDBXError!void {
        const rc = c.mdbx_txn_commit(self.txn);
        self.txn = null; // 提交后事务句柄失效
        try errors.checkError(rc);
    }

    /// 中止事务
    pub fn abort(self: *Self) void {
        if (self.txn) |tx| {
            _ = c.mdbx_txn_abort(tx);
            self.txn = null;
        }
    }

    /// 将事务标记为损坏
    ///
    /// 该函数保留事务句柄和相应的锁，但使得在损坏的事务中无法执行任何操作。
    /// 损坏的事务必须在之后显式中止。
    pub fn markBroken(self: *Self) errors.MDBXError!void {
        const rc = c.mdbx_txn_break(self.txn);
        try errors.checkError(rc);
    }

    /// 重置只读事务
    pub fn reset(self: *Self) errors.MDBXError!void {
        const rc = c.mdbx_txn_reset(self.txn);
        try errors.checkError(rc);
    }

    /// 续订只读事务
    pub fn renew(self: *Self) errors.MDBXError!void {
        const rc = c.mdbx_txn_renew(self.txn);
        try errors.checkError(rc);
    }

    /// 打开数据库实例
    pub fn openDBI(self: *Self, name: ?[*:0]const u8, flags_set: DBFlagSet) errors.MDBXError!DBI {
        var dbi: DBI = undefined;
        const c_flags = dbFlagsToInt(flags_set);
        const rc = c.mdbx_dbi_open(self.txn, name, c_flags, &dbi);
        try errors.checkError(rc);
        return dbi;
    }

    /// 从数据库获取数据（使用 Val 类型）
    ///
    /// 警告：返回的 Val 引用 MDBX 内部管理的内存，
    /// 其生命周期与事务相关联。事务结束后使用该 Val 将导致未定义行为。
    ///
    /// 参数：
    ///   dbi - 数据库实例句柄
    ///   key - 键的字节切片
    ///
    /// 返回：
    ///   Val 实例，包含从数据库检索的值
    pub fn get(self: *Self, dbi: DBI, key: []const u8) errors.MDBXError!Val {
        var key_val = Val.fromBytes(key);
        var data_val = Val.empty();

        const rc = c.mdbx_get(self.txn, dbi, key_val.asPtr(), data_val.asPtr());
        try errors.checkError(rc);

        return data_val;
    }

    /// 从数据库获取数据（便利方法，直接返回字节切片）
    ///
    /// 这是 get() 的便利包装，直接返回字节切片而不是 Val。
    ///
    /// 警告：返回的切片引用 MDBX 内部管理的内存，
    /// 其生命周期与事务相关联。事务结束后使用该切片将导致未定义行为。
    pub fn getBytes(self: *Self, dbi: DBI, key: []const u8) errors.MDBXError![]const u8 {
        const val = try self.get(dbi, key);
        return val.toBytes();
    }

    /// 存储数据到数据库
    ///
    /// 参数：
    ///   dbi - 数据库实例句柄
    ///   key - 键的字节切片
    ///   data - 值的字节切片
    ///   flags_set - Put 操作标志集合
    pub fn put(self: *Self, dbi: DBI, key: []const u8, data: []const u8, flags_set: PutFlagSet) errors.MDBXError!void {
        var key_val = Val.fromBytes(key);
        var data_val = Val.fromBytes(data);

        const c_flags = putFlagsToInt(flags_set);
        const rc = c.mdbx_put(self.txn, dbi, key_val.asPtr(), data_val.asPtr(), c_flags);
        try errors.checkError(rc);
    }

    /// 从数据库删除数据
    ///
    /// 参数：
    ///   dbi - 数据库实例句柄
    ///   key - 键的字节切片
    ///   data - 可选的值字节切片，用于精确匹配删除
    pub fn del(self: *Self, dbi: DBI, key: []const u8, data: ?[]const u8) errors.MDBXError!void {
        var key_val = Val.fromBytes(key);

        var data_ptr: ?*c.MDBX_val = null;
        var data_val: Val = undefined;
        if (data) |d| {
            data_val = Val.fromBytes(d);
            data_ptr = data_val.asPtr();
        }

        const rc = c.mdbx_del(self.txn, dbi, key_val.asPtr(), data_ptr);
        try errors.checkError(rc);
    }
};

// 向后兼容的便利函数
/// 创建只读事务
pub fn beginReadTxn(env: *c.MDBX_env) errors.MDBXError!Txn {
    var tx_flags = TxFlagSet.init(.{});
    tx_flags.insert(.read_only);
    return Txn.init(env, null, tx_flags);
}

/// 创建读写事务
pub fn beginWriteTxn(env: *c.MDBX_env) errors.MDBXError!Txn {
    return Txn.init(env, null, TxFlagSet.init(.{}));
}

/// 事务守卫 (RAII 模式)
///
/// TxnGuard 自动管理事务生命周期：
/// - 如果没有显式 commit，deinit 时会自动 abort
/// - 防止忘记清理事务导致的资源泄漏
/// - 提供更安全的事务管理
///
/// 使用示例：
/// ```zig
/// var guard = try TxnGuard.init(&env, null, TxFlagSet.init(.{}));
/// defer guard.deinit();  // 自动 abort 如果未 commit
///
/// const dbi = try guard.txn.openDBI(null, DBFlagSet.init(.{ .create = true }));
/// try guard.txn.put(dbi, "key", "value", PutFlagSet.init(.{}));
/// try guard.commit();  // 显式 commit
/// ```
pub const TxnGuard = struct {
    txn: Txn,
    committed: bool = false,

    const Self = @This();

    /// 创建新的事务守卫
    pub fn init(env: *c.MDBX_env, parent: ?*c.MDBX_txn, flags_set: TxFlagSet) errors.MDBXError!Self {
        return .{
            .txn = try Txn.init(env, parent, flags_set),
        };
    }

    /// 清理事务
    ///
    /// 如果事务未提交，会自动中止。
    pub fn deinit(self: *Self) void {
        if (!self.committed) {
            self.txn.abort();
        }
    }

    /// 提交事务
    ///
    /// 成功后将 committed 标记设为 true，
    /// 这样 deinit 就不会再次 abort。
    pub fn commit(self: *Self) errors.MDBXError!void {
        try self.txn.commit();
        self.committed = true;
    }

    /// 显式中止事务
    ///
    /// 调用后 committed 标记设为 true，
    /// 防止 deinit 时重复 abort。
    pub fn abort(self: *Self) void {
        self.txn.abort();
        self.committed = true; // 标记为已处理
    }

    /// 重置只读事务
    pub fn reset(self: *Self) errors.MDBXError!void {
        return self.txn.reset();
    }

    /// 续订只读事务
    pub fn renew(self: *Self) errors.MDBXError!void {
        return self.txn.renew();
    }
};
