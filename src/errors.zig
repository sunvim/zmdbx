const c = @import("c.zig").c;

/// MDBX 错误类型
pub const MDBXError = error{
    /// 键/数据对已存在
    KeyExist,
    /// 键/数据对未找到 (EOF)
    NotFound,
    /// 指定的键在数据库中未找到
    PageNotFound,
    /// 数据库已损坏
    Corrupted,
    /// 库中发生问题（这是一个 bug）
    Panic,
    /// 文件不是有效的 MDBX 文件
    VersionMismatch,
    /// 环境版本不匹配
    Invalid,
    /// 环境 mapsize 已达上限
    MapFull,
    /// 环境 maxdbs 已达上限
    DbsFull,
    /// 环境 maxreaders 已达上限
    ReadersFull,
    /// 事务有太多脏页
    TxnFull,
    /// 游标栈太深 - 内部错误
    CursorFull,
    /// 页面没有足够空间 - 内部错误
    PageFull,
    /// 无法扩展 mapsize
    UnableExtendMapsize,
    /// 操作和数据库不兼容，或数据库标志已更改
    Incompatible,
    /// 读取器锁表槽的无效重用
    BadRSlot,
    /// 事务必须中止、有子事务或无效
    BadTxn,
    /// 不支持的键/数据库名称/数据大小
    BadValSize,
    /// 指定的 DBI 意外更改
    BadDbi,
    /// 问题
    Problem,
    /// 最后一个进程未释放锁（仅 Windows）
    Busy,
    /// 多值
    Emultival,
    /// 错误签名
    EbadSign,
    /// 想要恢复
    WannaRecovery,
    /// 键不匹配
    EkeyMismatch,
    /// 太大
    TooLarge,
    /// 线程不匹配
    ThreadMismatch,
    /// 事务重叠
    TxnOverlapping,
    /// 积压耗尽
    BacklogDepleted,
    /// 重复的 CLK
    DuplicatedClk,
    /// 无数据
    Enodata,
    /// 无效参数
    Einval,
    /// 访问被拒绝
    Eaccess,
    /// 内存不足
    Enomem,
    /// 只读文件系统
    Erofs,
    /// 功能未实现
    Enosys,
    /// I/O 错误
    Eio,
    /// 操作不允许
    Eperm,
    /// 中断的系统调用
    Eintr,
    /// 文件不存在
    Enofile,
    /// 远程 I/O 错误
    Eremote,
};

/// 将 MDBX C 错误码转换为 Zig 错误
pub fn toError(rc: c_int) MDBXError {
    return switch (rc) {
        c.MDBX_SUCCESS => unreachable, // 成功不应该调用此函数
        c.MDBX_KEYEXIST => error.KeyExist,
        c.MDBX_NOTFOUND => error.NotFound,
        c.MDBX_PAGE_NOTFOUND => error.PageNotFound,
        c.MDBX_CORRUPTED => error.Corrupted,
        c.MDBX_PANIC => error.Panic,
        c.MDBX_VERSION_MISMATCH => error.VersionMismatch,
        c.MDBX_INVALID => error.Invalid,
        c.MDBX_MAP_FULL => error.MapFull,
        c.MDBX_DBS_FULL => error.DbsFull,
        c.MDBX_READERS_FULL => error.ReadersFull,
        c.MDBX_TXN_FULL => error.TxnFull,
        c.MDBX_CURSOR_FULL => error.CursorFull,
        c.MDBX_PAGE_FULL => error.PageFull,
        c.MDBX_UNABLE_EXTEND_MAPSIZE => error.UnableExtendMapsize,
        c.MDBX_INCOMPATIBLE => error.Incompatible,
        c.MDBX_BAD_RSLOT => error.BadRSlot,
        c.MDBX_BAD_TXN => error.BadTxn,
        c.MDBX_BAD_VALSIZE => error.BadValSize,
        c.MDBX_BAD_DBI => error.BadDbi,
        c.MDBX_PROBLEM => error.Problem,
        c.MDBX_BUSY => error.Busy,
        c.MDBX_EMULTIVAL => error.Emultival,
        c.MDBX_EBADSIGN => error.EbadSign,
        c.MDBX_WANNA_RECOVERY => error.WannaRecovery,
        c.MDBX_EKEYMISMATCH => error.EkeyMismatch,
        c.MDBX_TOO_LARGE => error.TooLarge,
        c.MDBX_THREAD_MISMATCH => error.ThreadMismatch,
        c.MDBX_TXN_OVERLAPPING => error.TxnOverlapping,
        c.MDBX_BACKLOG_DEPLETED => error.BacklogDepleted,
        c.MDBX_DUPLICATED_CLK => error.DuplicatedClk,
        c.MDBX_ENODATA => error.Enodata,
        c.MDBX_EINVAL => error.Einval,
        c.MDBX_EACCESS => error.Eaccess,
        c.MDBX_ENOMEM => error.Enomem,
        c.MDBX_EROFS => error.Erofs,
        c.MDBX_ENOSYS => error.Enosys,
        c.MDBX_EIO => error.Eio,
        c.MDBX_EPERM => error.Eperm,
        c.MDBX_EINTR => error.Eintr,
        c.MDBX_ENOFILE => error.Enofile,
        c.MDBX_EREMOTE => error.Eremote,
        else => error.Problem, // 未知错误默认返回 Problem
    };
}

/// 检查 MDBX 返回码，如果失败则返回错误
pub fn checkError(rc: c_int) MDBXError!void {
    if (rc != c.MDBX_SUCCESS) {
        return toError(rc);
    }
}

/// 错误枚举（保留用于需要模式匹配的场景）
pub const Error = enum(c.enum_MDBX_error_t) {
    Success = c.MDBX_SUCCESS,
    ResultFalse = c.MDBX_RESULT_FALSE,
    ResultTrue = c.MDBX_RESULT_TRUE,
    KeyExist = c.MDBX_KEYEXIST,
    FirstLmdbErrcode = c.MDBX_FIRST_LMDB_ERRCODE,
    NotFound = c.MDBX_NOTFOUND,
    PageNotFound = c.MDBX_PAGE_NOTFOUND,
    Corrupted = c.MDBX_CORRUPTED,
    Panic = c.MDBX_PANIC,
    VersionMismatch = c.MDBX_VERSION_MISMATCH,
    Invalid = c.MDBX_INVALID,
    MapFull = c.MDBX_MAP_FULL,
    DbsFull = c.MDBX_DBS_FULL,
    ReadersFull = c.MDBX_READERS_FULL,
    TxnFull = c.MDBX_TXN_FULL,
    CursorFull = c.MDBX_CURSOR_FULL,
    PageFull = c.MDBX_PAGE_FULL,
    UnableExtendMapsize = c.MDBX_UNABLE_EXTEND_MAPSIZE,
    Incompatible = c.MDBX_INCOMPATIBLE,
    BadRSlot = c.MDBX_BAD_RSLOT,
    BadTxn = c.MDBX_BAD_TXN,
    BadValSize = c.MDBX_BAD_VALSIZE,
    BadDbi = c.MDBX_BAD_DBI,
    Problem = c.MDBX_PROBLEM,
    LastLmdbErrCode = c.MDBX_LAST_LMDB_ERRCODE,
    Busy = c.MDBX_BUSY,
    FirstAddedErrCode = c.MDBX_FIRST_ADDED_ERRCODE,
    Emultival = c.MDBX_EMULTIVAL,
    EbadSign = c.MDBX_EBADSIGN,
    WannaRecovery = c.MDBX_WANNA_RECOVERY,
    EkeyMismatch = c.MDBX_EKEYMISMATCH,
    TooLarge = c.MDBX_TOO_LARGE,
    ThreadMismatch = c.MDBX_THREAD_MISMATCH,
    TxnOverlapping = c.MDBX_TXN_OVERLAPPING,
    BacklogDepleted = c.MDBX_BACKLOG_DEPLETED,
    DuplicatedClk = c.MDBX_DUPLICATED_CLK,
    LastAddedErrCode = c.MDBX_LAST_ADDED_ERRCODE,
    Enodata = c.MDBX_ENODATA,
    Einval = c.MDBX_EINVAL,
    Eaccess = c.MDBX_EACCESS,
    Enomem = c.MDBX_ENOMEM,
    Erofs = c.MDBX_EROFS,
    Enosys = c.MDBX_ENOSYS,
    Eio = c.MDBX_EIO,
    Eperm = c.MDBX_EPERM,
    Eintr = c.MDBX_EINTR,
    Enofile = c.MDBX_ENOFILE,
    Eremote = c.MDBX_EREMOTE,
};
