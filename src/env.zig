const std = @import("std");
const c = @import("c.zig").c;

const errors = @import("errors.zig");
const Option = @import("opt.zig").Option;
const types = @import("types.zig");
const flags = @import("flags.zig");
const Txn = @import("txn.zig").Txn;

// 重新导出类型和标志，保持向后兼容
pub const DBI = types.DBI;
pub const Geometry = types.Geometry;

pub const EnvFlag = flags.EnvFlag;
pub const EnvFlagSet = flags.EnvFlagSet;
pub const envFlagsToInt = flags.envFlagsToInt;

pub const DBFlag = flags.DBFlag;
pub const DBFlagSet = flags.DBFlagSet;
pub const dbFlagsToInt = flags.dbFlagsToInt;

pub const CopyFlag = flags.CopyFlag;
pub const CopyFlagSet = flags.CopyFlagSet;
pub const copyFlagsToInt = flags.copyFlagsToInt;

pub const DBIState = flags.DBIState;
pub const DeleteMode = flags.DeleteMode;

/// MDBX 环境句柄
pub const Env = struct {
    env: ?*c.MDBX_env,

    const Self = @This();

    /// 创建新的环境实例
    pub fn init() errors.MDBXError!Self {
        var env_ptr: ?*c.MDBX_env = null;
        const rc = c.mdbx_env_create(&env_ptr);
        try errors.checkError(rc);
        return Self{ .env = env_ptr };
    }

    /// 关闭环境
    pub fn deinit(self: *Self) void {
        if (self.env) |env| {
            _ = c.mdbx_env_close(env);
            self.env = null;
        }
    }

    /// 设置内存映射大小
    pub fn setMapsize(self: *Self, size: usize) errors.MDBXError!void {
        const rc = c.mdbx_env_set_mapsize(self.env, size);
        try errors.checkError(rc);
    }

    /// 设置几何参数
    pub fn setGeometry(self: *Self, geo: Geometry) errors.MDBXError!void {
        const rc = c.mdbx_env_set_geometry(
            self.env,
            geo.lower,
            geo.now,
            geo.upper,
            geo.growth_step,
            geo.shrink_threshold,
            geo.pagesize,
        );
        try errors.checkError(rc);
    }

    /// 设置选项
    pub fn setOption(self: *Self, option: Option, value: u64) errors.MDBXError!void {
        const rc = c.mdbx_env_set_option(self.env, @intFromEnum(option), value);
        try errors.checkError(rc);
    }

    /// 获取选项值
    pub fn getOption(self: *Self, option: Option) errors.MDBXError!u64 {
        var value: u64 = 0;
        const rc = c.mdbx_env_get_option(self.env, @intFromEnum(option), &value);
        try errors.checkError(rc);
        return value;
    }

    /// 同步环境数据到磁盘
    pub fn sync(self: *Self, force: bool, nonblock: bool) errors.MDBXError!void {
        const rc = c.mdbx_env_sync_ex(self.env, force, nonblock);
        try errors.checkError(rc);
    }

    /// 关闭数据库句柄
    pub fn closeDBI(self: *Self, dbi: DBI) void {
        _ = c.mdbx_dbi_close(self.env, dbi);
    }

    /// 获取最大数据库数量
    pub fn getMaxdbs(self: *Self) errors.MDBXError!c_uint {
        var maxdbs: c_uint = 0;
        const rc = c.mdbx_env_get_maxdbs(self.env, &maxdbs);
        try errors.checkError(rc);
        return maxdbs;
    }

    /// 设置最大数据库数量
    pub fn setMaxdbs(self: *Self, maxdbs: c_uint) errors.MDBXError!void {
        const rc = c.mdbx_env_set_maxdbs(self.env, maxdbs);
        try errors.checkError(rc);
    }

    /// 获取最大读取器数量
    pub fn getMaxReaders(self: *Self) errors.MDBXError!c_uint {
        var readers: c_uint = 0;
        const rc = c.mdbx_env_get_maxreaders(self.env, &readers);
        try errors.checkError(rc);
        return readers;
    }

    /// 设置最大读取器数量
    pub fn setMaxReaders(self: *Self, readers: c_uint) errors.MDBXError!void {
        const rc = c.mdbx_env_set_maxreaders(self.env, readers);
        try errors.checkError(rc);
    }

    /// 获取同步字节阈值
    pub fn getSyncBytes(self: *Self) errors.MDBXError!usize {
        var bytes: usize = 0;
        const rc = c.mdbx_env_get_syncbytes(self.env, &bytes);
        try errors.checkError(rc);
        return bytes;
    }

    /// 设置同步字节阈值
    pub fn setSyncBytes(self: *Self, bytes: usize) errors.MDBXError!void {
        const rc = c.mdbx_env_set_syncbytes(self.env, bytes);
        try errors.checkError(rc);
    }

    /// 获取同步周期
    pub fn getSyncPeriod(self: *Self) errors.MDBXError!c_uint {
        var period: c_uint = 0;
        const rc = c.mdbx_env_get_syncperiod(self.env, &period);
        try errors.checkError(rc);
        return period;
    }

    /// 设置同步周期（秒为单位 * 65536）
    pub fn setSyncPeriod(self: *Self, period: c_uint) errors.MDBXError!void {
        const rc = c.mdbx_env_set_syncperiod(self.env, period);
        try errors.checkError(rc);
    }

    /// 获取文件描述符
    pub fn getFd(self: *Self) errors.MDBXError!c.mdbx_filehandle_t {
        var fd: c.mdbx_filehandle_t = undefined;
        const rc = c.mdbx_env_get_fd(self.env, &fd);
        try errors.checkError(rc);
        return fd;
    }

    /// 清理陈旧的读取器条目
    pub fn readerCheck(self: *Self) errors.MDBXError!c_int {
        var dead: c_int = 0;
        const rc = c.mdbx_reader_check(self.env, &dead);
        try errors.checkError(rc);
        return dead;
    }

    /// 获取数据库路径
    pub fn getPath(self: *Self) errors.MDBXError![*:0]const u8 {
        var path: [*:0]const u8 = undefined;
        const rc = c.mdbx_env_get_path(self.env, &path);
        try errors.checkError(rc);
        return path;
    }

    /// 获取最大键大小
    pub fn getMaxKeySize(self: *Self) errors.MDBXError!c_int {
        const size = c.mdbx_env_get_maxkeysize_ex(self.env, c.MDBX_DB_DEFAULTS);
        if (size < 0) {
            return errors.toError(@intCast(-size));
        }
        return size;
    }

    /// 设置环境标志
    pub fn setFlags(self: *Self, flags_set: EnvFlagSet, onoff: bool) errors.MDBXError!void {
        const c_flags = envFlagsToInt(flags_set);
        const rc = c.mdbx_env_set_flags(self.env, c_flags, onoff);
        try errors.checkError(rc);
    }

    /// 获取环境标志
    pub fn getFlags(self: *Self) errors.MDBXError!c_uint {
        var env_flags_raw: c_uint = 0;
        const rc = c.mdbx_env_get_flags(self.env, &env_flags_raw);
        try errors.checkError(rc);
        return env_flags_raw;
    }

    /// 复制环境到指定路径
    pub fn copy(self: *Self, path: [*:0]const u8, flags_set: CopyFlagSet) errors.MDBXError!void {
        const c_flags = copyFlagsToInt(flags_set);
        const rc = c.mdbx_env_copy(self.env, path, c_flags);
        try errors.checkError(rc);
    }

    /// 打开环境
    pub fn open(self: *Self, path: [*:0]const u8, flags_set: EnvFlagSet, mode: c.mdbx_mode_t) errors.MDBXError!void {
        const c_flags = envFlagsToInt(flags_set);
        const rc = c.mdbx_env_open(self.env, path, c_flags, mode);
        try errors.checkError(rc);
    }

    /// 开始新事务
    pub fn beginTxn(self: *Self, parent: ?*c.MDBX_txn, flags_set: flags.TxFlagSet) errors.MDBXError!Txn {
        return Txn.init(self.env.?, parent, flags_set);
    }

    /// 便利方法：开始只读事务
    pub fn beginReadTxn(self: *Self) errors.MDBXError!Txn {
        var txflags = flags.TxFlagSet.init(.{});
        txflags.insert(.read_only);
        return self.beginTxn(null, txflags);
    }

    /// 便利方法：开始读写事务
    pub fn beginWriteTxn(self: *Self) errors.MDBXError!Txn {
        return self.beginTxn(null, flags.TxFlagSet.init(.{}));
    }

    /// 删除环境（静态方法）
    pub fn delete(path: [*:0]const u8, mode: DeleteMode) errors.MDBXError!void {
        const rc = c.mdbx_env_delete(path, @intFromEnum(mode));
        try errors.checkError(rc);
    }

    /// 高级API: 在只读事务中执行函数
    ///
    /// 自动管理事务生命周期，发生错误时自动回滚。
    ///
    /// 使用示例：
    /// ```zig
    /// const result = try env.withReadTxn(struct {
    ///     fn callback(txn: *Txn) ![]const u8 {
    ///         const dbi = try txn.openDBI(null, DBFlagSet.init(.{}));
    ///         return try txn.getBytes(dbi, "key");
    ///     }
    /// }.callback);
    /// ```
    pub fn withReadTxn(self: *Self, comptime func: anytype) !ReturnType(func) {
        var tx_flags = flags.TxFlagSet.init(.{});
        tx_flags.insert(.read_only);
        var txn = try Txn.init(self.env.?, null, tx_flags);
        defer txn.abort();

        const result = try func(&txn);
        return result;
    }

    /// 高级API: 在读写事务中执行函数
    ///
    /// 自动管理事务生命周期，成功时自动提交，失败时自动回滚。
    ///
    /// 使用示例：
    /// ```zig
    /// try env.withWriteTxn(struct {
    ///     fn callback(txn: *Txn) !void {
    ///         const dbi = try txn.openDBI(null, DBFlagSet.init(.{ .create = true }));
    ///         try txn.put(dbi, "key", "value", PutFlagSet.init(.{}));
    ///     }
    /// }.callback);
    /// ```
    pub fn withWriteTxn(self: *Self, comptime func: anytype) !ReturnType(func) {
        var txn = try Txn.init(self.env.?, null, flags.TxFlagSet.init(.{}));
        errdefer txn.abort();

        const result = try func(&txn);
        try txn.commit();
        return result;
    }

    /// 辅助函数：获取函数的返回类型
    fn ReturnType(comptime func: anytype) type {
        const func_info = @typeInfo(@TypeOf(func));
        return switch (func_info) {
            .Fn => |f| f.return_type.?,
            else => @compileError("Expected function type"),
        };
    }
};

/// Database 生命周期管理包装器
///
/// 自动管理 DBI 句柄的打开和关闭，防止资源泄漏。
///
/// 使用示例：
/// ```zig
/// var db = try Database.open(&env, null, DBFlagSet.init(.{ .create = true }));
/// defer db.close();
///
/// var txn = try env.beginWriteTxn();
/// defer txn.abort();
/// try txn.put(db.dbi, "key", "value", PutFlagSet.init(.{}));
/// try txn.commit();
/// ```
pub const Database = struct {
    env: *c.MDBX_env,
    dbi: DBI,
    closed: bool = false,

    const Self = @This();

    /// 打开数据库
    ///
    /// 注意：此函数内部创建一个临时事务来打开数据库。
    /// 如果在现有事务中打开数据库，请使用 Txn.openDBI() 方法。
    pub fn open(env: *Env, name: ?[*:0]const u8, flags_set: DBFlagSet) errors.MDBXError!Self {
        // 创建临时事务来打开数据库
        var txn = try Txn.init(env.env.?, null, flags.TxFlagSet.init(.{}));
        defer txn.abort();

        const dbi = try txn.openDBI(name, flags_set);

        // 注意：DBI 在事务提交后仍然有效
        try txn.commit();

        return Self{
            .env = env.env.?,
            .dbi = dbi,
        };
    }

    /// 关闭数据库
    pub fn close(self: *Self) void {
        if (!self.closed) {
            _ = c.mdbx_dbi_close(self.env, self.dbi);
            self.closed = true;
        }
    }
};

// 为了向后兼容，提供旧API的便利方法
/// 使用默认标志打开环境
pub fn openDefault(env: *Env, path: [*:0]const u8, mode: c.mdbx_mode_t) errors.MDBXError!void {
    return env.open(path, EnvFlagSet.init(.{}), mode);
}
