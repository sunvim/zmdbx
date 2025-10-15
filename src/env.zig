const std = @import("std");
const c_import = @import("c.zig");
const c = c_import.c;

const errors = @import("errors.zig");
const Option = @import("opt.zig").Option;
const Txn = @import("txn.zig").Txn;
const TxFlags = @import("txn.zig").TxFlags;

/// 数据库实例句柄
pub const DBI = c.MDBX_dbi;

/// 几何配置参数
pub const Geometry = struct {
    lower: isize = -1,
    now: isize = -1,
    upper: isize = -1,
    growth_step: isize = -1,
    shrink_threshold: isize = -1,
    pagesize: isize = -1,
};

/// 环境标志
/// 注意: MDBX_ENV_DEFAULTS 和 MDBX_SYNC_DURABLE 的值都是 0
/// 因此只保留 defaults，sync_durable 可以通过 defaults 来表示
pub const EnvFlags = enum(c.MDBX_env_flags_t) {
    defaults = c.MDBX_ENV_DEFAULTS,
    validation = c.MDBX_VALIDATION,
    no_sub_dir = c.MDBX_NOSUBDIR,
    read_only = c.MDBX_RDONLY,
    exclusive = c.MDBX_EXCLUSIVE,
    accede = c.MDBX_ACCEDE,
    write_map = c.MDBX_WRITEMAP,
    no_tls = c.MDBX_NOTLS,
    no_read_ahead = c.MDBX_NORDAHEAD,
    no_mem_init = c.MDBX_NOMEMINIT,
    coalesce = c.MDBX_COALESCE,
    lifo_reclaim = c.MDBX_LIFORECLAIM,
    page_perturb = c.MDBX_PAGEPERTURB,
    no_meta_sync = c.MDBX_NOMETASYNC,
    safe_no_sync = c.MDBX_SAFE_NOSYNC,
    utterly_no_sync = c.MDBX_UTTERLY_NOSYNC,
};

/// 数据库标志
pub const DBFlags = enum(c.MDBX_db_flags_t) {
    defaults = c.MDBX_DB_DEFAULTS,
    reverse_key = c.MDBX_REVERSEKEY,
    dup_sort = c.MDBX_DUPSORT,
    integer_key = c.MDBX_INTEGERKEY,
    dup_fixed = c.MDBX_DUPFIXED,
    integer_dup = c.MDBX_INTEGERDUP,
    reverse_dup = c.MDBX_REVERSEDUP,
    create = c.MDBX_CREATE,
    db_accede = c.MDBX_DB_ACCEDE,
};

/// 复制标志
pub const CopyFlags = enum(c.MDBX_copy_flags_t) {
    defaults = c.MDBX_CP_DEFAULTS,
    compact = c.MDBX_CP_COMPACT,
    force_dynamic_size = c.MDBX_CP_FORCE_DYNAMIC_SIZE,
};

/// DBI 状态
pub const DBIState = enum(c.MDBX_dbi_state_t) {
    dirty = c.MDBX_DBI_DIRTY,
    stale = c.MDBX_DBI_STALE,
    fresh = c.MDBX_DBI_FRESH,
    creat = c.MDBX_DBI_CREAT,
};

/// 删除模式
pub const DeleteMode = enum(c.MDBX_env_delete_mode_t) {
    just_delete = c.MDBX_ENV_JUST_DELETE,
    ensure_unused = c.MDBX_ENV_ENSURE_UNUSED,
    wait_for_unused = c.MDBX_ENV_WAIT_UNUSED,
};

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
        const size = c.mdbx_env_get_maxkeysize_ex(self.env, @intFromEnum(DBFlags.defaults));
        if (size < 0) {
            return errors.toError(@intCast(-size));
        }
        return size;
    }

    /// 设置环境标志
    pub fn setFlags(self: *Self, flags: EnvFlags, onoff: bool) errors.MDBXError!void {
        const rc = c.mdbx_env_set_flags(self.env, @intFromEnum(flags), onoff);
        try errors.checkError(rc);
    }

    /// 获取环境标志
    pub fn getFlags(self: *Self) errors.MDBXError!c_uint {
        var flags: c_uint = 0;
        const rc = c.mdbx_env_get_flags(self.env, &flags);
        try errors.checkError(rc);
        return flags;
    }

    /// 复制环境到指定路径
    pub fn copy(self: *Self, path: [*:0]const u8, flags: CopyFlags) errors.MDBXError!void {
        const rc = c.mdbx_env_copy(self.env, path, @intFromEnum(flags));
        try errors.checkError(rc);
    }

    /// 打开环境
    pub fn open(self: *Self, path: [*:0]const u8, flags: EnvFlags, mode: c.mdbx_mode_t) errors.MDBXError!void {
        const rc = c.mdbx_env_open(self.env, path, @intFromEnum(flags), mode);
        try errors.checkError(rc);
    }

    /// 开始新事务
    pub fn beginTxn(self: *Self, parent: ?*c.MDBX_txn, flags: TxFlags) errors.MDBXError!Txn {
        return Txn.init(self.env.?, parent, flags);
    }

    /// 删除环境（静态方法）
    pub fn delete(path: [*:0]const u8, mode: DeleteMode) errors.MDBXError!void {
        const rc = c.mdbx_env_delete(path, @intFromEnum(mode));
        try errors.checkError(rc);
    }
};
