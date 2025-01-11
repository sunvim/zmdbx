const c = @cImport({
    @cInclude("mdbx.h");
});

pub const Error = enum(c.enum_MDBX_error_t) {
    // Success brief Successful result.
    Success = c.MDBX_SUCCESS,

    RESULT_FALSE = c.MDBX_RESULT_FALSE,

    RESULT_TRUE = c.MDBX_RESULT_TRUE,

    // KeyExist brief The key/data pair already exists.
    KeyExist = c.MDBX_KEYEXIST,

    FIRST_LMDB_ERRCODE = c.MDBX_FIRST_LMDB_ERRCODE,

    // NotFound brief The key/data pair was not found (EOF).
    NotFound = c.MDBX_NOTFOUND,

    // PageNotFound brief The specified key was not found in the database.
    PageNotFound = c.MDBX_PAGE_NOTFOUND,

    // Corrupted brief The database is corrupted.
    Corrupted = c.MDBX_CORRUPTED,

    // Panic brief A problem occurred in the library. This is a bug.
    Panic = c.MDBX_PANIC,

    // VersionMismatch brief File is not a valid MDBX file.
    VersionMismatch = c.MDBX_VERSION_MISMATCH,

    // Invalid brief Environment version mismatch.
    Invalid = c.MDBX_INVALID,

    // MapFull brief Environment mapsize reached.
    MapFull = c.MDBX_MAP_FULL,

    // DbsFull brief Environment maxdbs reached.
    DbsFull = c.MDBX_DBS_FULL,

    // ReadersFull brief Environment maxreaders reached.
    ReadersFull = c.MDBX_READERS_FULL,

    // TxnFull brief Txn has too many dirty pages.
    TxnFull = c.MDBX_TXN_FULL,

    // CursorFull brief Cursor stack too deep - internal error.
    CursorFull = c.MDBX_CURSOR_FULL,

    // PageFull brief Page has not enough space - internal error.
    PageFull = c.MDBX_PAGE_FULL,

    UNABLE_EXTEND_MAPSIZE = c.MDBX_UNABLE_EXTEND_MAPSIZE,

    // Incompatible brief Operation and DB incompatible, or DB flags changed.
    Incompatible = c.MDBX_INCOMPATIBLE,

    // BadRSlot brief Invalid reuse of reader locktable slot.
    BadRSlot = c.MDBX_BAD_RSLOT,

    // BadTxn brief Transaction must abort, has a child, or is invalid.
    BadTxn = c.MDBX_BAD_TXN,

    // BadValSize brief Unsupported size of key/DB name/data, or
    BadValSize = c.MDBX_BAD_VALSIZE,

    // BadDbi brief The specified DBI was changed unexpectedly.
    BadDbi = c.MDBX_BAD_DBI,

    Problem = c.MDBX_PROBLEM,

    LastLMDBErrCode = c.MDBX_LAST_LMDB_ERRCODE,

    // Busy brief The last process did not release a lock. (Windows only)
    Busy = c.MDBX_BUSY,

    FirstAddedErrCode = c.MDBX_FIRST_ADDED_ERRCODE,

    EMultival = c.MDBX_EMULTIVAL,

    EBadSign = c.MDBX_EBADSIGN,

    WannaRecovery = c.MDBX_WANNA_RECOVERY,

    EKeyMismatch = c.MDBX_EKEYMISMATCH,

    TooLarge = c.MDBX_TOO_LARGE,

    ThreadMismatch = c.MDBX_THREAD_MISMATCH,

    TxnOverlapping = c.MDBX_TXN_OVERLAPPING,

    BacklogDepleted = c.MDBX_BACKLOG_DEPLETED,

    DuplicatedClk = c.MDBX_DUPLICATED_CLK,

    LastAddedErrCode = c.MDBX_LAST_ADDED_ERRCODE,

    ENODATA = c.MDBX_ENODATA,

    EINVAL = c.MDBX_EINVAL,

    EACCESS = c.MDBX_EACCESS,

    ENOMEM = c.MDBX_ENOMEM,

    EROFS = c.MDBX_EROFS,

    ENOSYS = c.MDBX_ENOSYS,

    EIO = c.MDBX_EIO,

    EPERM = c.MDBX_EPERM,

    EINTR = c.MDBX_EINTR,

    ENOFILE = c.MDBX_ENOFILE,

    EREMOTE = c.MDBX_EREMOTE,
};
