const std = @import("std");
const c = @import("c.zig").c;

const errors = @import("errors.zig");
const Env = @import("env.zig");

/// 事务标志
pub const TxFlags = enum(c.MDBX_txn_flags_t) {
    /// 启动读写事务
    ///
    /// 一次只能有一个写事务处于活动状态。写操作完全序列化，
    /// 这保证了写入者永远不会死锁。
    read_write = c.MDBX_TXN_READWRITE,

    /// 启动只读事务
    ///
    /// 可以有多个只读事务同时运行，它们不会相互阻塞，
    /// 也不会阻塞写事务。
    read_only = c.MDBX_TXN_RDONLY,

    /// 准备但不启动只读事务
    ///
    /// 事务不会立即启动，但创建的事务句柄可以用于 mdbx_txn_renew()。
    /// 此标志允许预分配内存并分配读取器槽，从而避免在下次启动事务时执行这些操作。
    read_only_prepare = c.MDBX_TXN_RDONLY_PREPARE,

    /// 启动写事务时不阻塞
    try_start = c.MDBX_TXN_TRY,

    /// 与 MDBX_NOMETASYNC 完全相同，但仅针对此事务
    no_meta_sync = c.MDBX_TXN_NOMETASYNC,

    /// 与 MDBX_SAFE_NOSYNC 完全相同，但仅针对此事务
    no_sync = c.MDBX_TXN_NOSYNC,
};

/// Put 操作标志
pub const PutFlags = enum(c.MDBX_put_flags_t) {
    /// 默认的更新插入操作（没有其他标志）
    upsert = c.MDBX_UPSERT,

    /// 如果键已存在则不写入
    no_overwrite = c.MDBX_NOOVERWRITE,

    /// 如果键和数据对已存在则不写入
    no_dup_data = c.MDBX_NODUPDATA,

    /// 将当前键的数据更新为新数据
    current = c.MDBX_CURRENT,

    /// 仅对 MDBX_DUPSORT 数据库有效
    /// 删除：删除给定键的所有多值（又名重复项）
    /// 更新插入：用新值替换给定键的所有多值
    all_dups = c.MDBX_ALLDUPS,

    /// 为数据预留空间，但不写入
    reserve = c.MDBX_RESERVE,

    /// 将数据追加到数据库末尾
    append = c.MDBX_APPEND,

    /// 将数据追加到数据库末尾
    append_dup = c.MDBX_APPENDDUP,

    /// 仅用于 MDBX_DUPFIXED，在一次调用中存储多个数据项
    multiple = c.MDBX_MULTIPLE,
};

/// 事务信息
pub const TxInfo = c.MDBX_txn_info;

/// 事务句柄
pub const Txn = struct {
    env: *c.MDBX_env,
    txn: ?*c.MDBX_txn,

    const Self = @This();

    /// 创建新事务
    pub fn init(env: *c.MDBX_env, parent: ?*c.MDBX_txn, flags: TxFlags) errors.MDBXError!Self {
        var txn: ?*c.MDBX_txn = null;
        const rc = c.mdbx_txn_begin(env, parent, @intFromEnum(flags), &txn);
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
    pub fn openDBI(self: *Self, name: ?[*:0]const u8, flags: Env.DBFlags) errors.MDBXError!Env.DBI {
        var dbi: Env.DBI = undefined;
        const rc = c.mdbx_dbi_open(self.txn, name, @intFromEnum(flags), &dbi);
        try errors.checkError(rc);
        return dbi;
    }

    /// 从数据库获取数据
    pub fn get(self: *Self, dbi: Env.DBI, key: []const u8) errors.MDBXError![]const u8 {
        var key_val = c.MDBX_val{
            .iov_base = @ptrCast(@constCast(key.ptr)),
            .iov_len = key.len,
        };
        var data_val: c.MDBX_val = undefined;

        const rc = c.mdbx_get(self.txn, dbi, &key_val, &data_val);
        try errors.checkError(rc);

        const data_ptr: [*]const u8 = @ptrCast(data_val.iov_base);
        return data_ptr[0..data_val.iov_len];
    }

    /// 存储数据到数据库
    pub fn put(self: *Self, dbi: Env.DBI, key: []const u8, data: []const u8, flags: PutFlags) errors.MDBXError!void {
        var key_val = c.MDBX_val{
            .iov_base = @ptrCast(@constCast(key.ptr)),
            .iov_len = key.len,
        };
        var data_val = c.MDBX_val{
            .iov_base = @ptrCast(@constCast(data.ptr)),
            .iov_len = data.len,
        };

        const rc = c.mdbx_put(self.txn, dbi, &key_val, &data_val, @intFromEnum(flags));
        try errors.checkError(rc);
    }

    /// 从数据库删除数据
    pub fn del(self: *Self, dbi: Env.DBI, key: []const u8, data: ?[]const u8) errors.MDBXError!void {
        var key_val = c.MDBX_val{
            .iov_base = @ptrCast(@constCast(key.ptr)),
            .iov_len = key.len,
        };

        var data_ptr: ?*c.MDBX_val = null;
        var data_val: c.MDBX_val = undefined;
        if (data) |d| {
            data_val = c.MDBX_val{
                .iov_base = @ptrCast(@constCast(d.ptr)),
                .iov_len = d.len,
            };
            data_ptr = &data_val;
        }

        const rc = c.mdbx_del(self.txn, dbi, &key_val, data_ptr);
        try errors.checkError(rc);
    }
};
