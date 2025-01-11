const c = @cImport({
    @cInclude("mdbx.h");
});
const Option = @import("opt.zig").Option;

const tx = @import("txn.zig");

const Self = @This();

// fields definitions:
Env: ?*c.MDBX_env,

// method definitions:
pub fn open_env(self: *Self) !void {
    var env_ptr: ?*c.MDBX_env = null;
    const rc = c.mdbx_env_create(&env_ptr);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
    self.Env = env_ptr;
}

pub fn close_env(self: *Self) void {
    if (self.Env != null) {
        c.mdbx_env_close(self.Env);
        self.Env = null;
    }
}

pub fn set_mapsize(self: *Self, size: usize) !void {
    const rc = c.mdbx_env_set_mapsize(self.Env, size);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
}

pub const Geometry = struct {
    lower: isize,
    now: isize,
    upper: isize,
    growth_step: isize,
    shrink_threshold: isize,
    pagesize: isize,
};

// SetGeometry Set all size-related parameters of environment, including page size
// and the min/max size of the memory map. ingroup c_settings
pub fn set_geometry(self: *Self, geo: *Geometry) !void {
    const rc = c.mdbx_env_set_geometry(self.Env, geo.lower, geo.now, geo.upper, geo.growth_step, geo.shrink_threshold, geo.pagesize);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
}

pub fn set_option(self: *Self, option: Option, arg: u32) !void {
    const rc = c.mdbx_env_set_option(self.Env, option, arg);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
}

pub fn get_option(self: *Self, option: Option) !u64 {
    var arg: u64 = 0;
    const rc = c.mdbx_env_get_option(self.Env, option, &arg);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
    return arg;
}

pub fn sync(self: *Self, force: bool, nonblock: bool) !void {
    const rc = c.mdbx_env_sync_ex(self.Env, force, nonblock);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
}

const DBI = c.MDBX_dbi;

// CloseDBI Close a database handle. Normally unnecessary.
// ingroup c_dbi
pub fn closeDBI(self: *Self, dbi: DBI) void {
    c.mdbx_dbi_close(self.Env, dbi);
}

// GetMaxDBS Controls the maximum number of named databases for the environment.
//
// details By default only unnamed key-value database could used and
// appropriate value should set by `MDBX_opt_max_db` to using any more named
// subDB(s). To reduce overhead, use the minimum sufficient value. This option
// may only set after ref mdbx_env_create() and before ref mdbx_env_open().
//
// see mdbx_env_set_maxdbs() see mdbx_env_get_maxdbs()
pub fn get_maxdbs(self: *Self) !DBI {
    var maxdbs: DBI = 0;
    const rc = c.mdbx_env_get_maxdbs(self.Env, &maxdbs);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
    return maxdbs;
}

// SetMaxDBS Controls the maximum number of named databases for the environment.
//
// details By default only unnamed key-value database could used and
// appropriate value should set by `MDBX_opt_max_db` to using any more named
// subDB(s). To reduce overhead, use the minimum sufficient value. This option
// may only set after ref mdbx_env_create() and before ref mdbx_env_open().
//
// see mdbx_env_set_maxdbs() see mdbx_env_get_maxdbs()
pub fn set_maxdbs(self: *Self, maxdbs: DBI) !void {
    const rc = c.mdbx_env_set_maxdbs(self.Env, maxdbs);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
}

// GetMaxReaders Defines the maximum number of threads/reader slots
// for all processes interacting with the database.
//
// details This defines the number of slots in the lock table that is used to
// track readers in the the environment. The default is about 100 for 4K
// system page size. Starting a read-only transaction normally ties a lock
// table slot to the current thread until the environment closes or the thread
// exits. If ref MDBX_NOTLS is in use, ref mdbx_txn_begin() instead ties the
// slot to the ref MDBX_txn object until it or the ref MDBX_env object is
// destroyed. This option may only set after ref mdbx_env_create() and before
// ref mdbx_env_open(), and has an effect only when the database is opened by
// the first process interacts with the database.
//
// see mdbx_env_set_maxreaders() see mdbx_env_get_maxreaders()
pub fn get_max_readers(self: *Self) !usize {
    var readers: usize = 0;
    const rc = c.mdbx_env_get_maxreaders(self.Env, &readers);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
    return readers;
}

// SetMaxReaders Defines the maximum number of threads/reader slots
// for all processes interacting with the database.
//
// details This defines the number of slots in the lock table that is used to
// track readers in the the environment. The default is about 100 for 4K
// system page size. Starting a read-only transaction normally ties a lock
// table slot to the current thread until the environment closes or the thread
// exits. If ref MDBX_NOTLS is in use, ref mdbx_txn_begin() instead ties the
// slot to the ref MDBX_txn object until it or the ref MDBX_env object is
// destroyed. This option may only set after ref mdbx_env_create() and before
// ref mdbx_env_open(), and has an effect only when the database is opened by
// the first process interacts with the database.
//
// see mdbx_env_set_maxreaders() see mdbx_env_get_maxreaders()
pub fn set_max_readers(self: *Self, readers: usize) !void {
    const rc = c.mdbx_env_set_maxreaders(self.Env, readers);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
}

// GetSyncBytes Controls interprocess/shared threshold to force flush the data
// buffers to disk, if ref MDBX_SAFE_NOSYNC is used.
//
// see mdbx_env_set_syncbytes() see mdbx_env_get_syncbytes()
pub fn get_sync_bytes(self: *Self) !usize {
    var bytes: usize = 0;
    const rc = c.mdbx_env_get_syncbytes(self.Env, &bytes);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
    return bytes;
}

// SetSyncBytes Controls interprocess/shared threshold to force flush the data
// buffers to disk, if ref MDBX_SAFE_NOSYNC is used.
//
// see mdbx_env_set_syncbytes() see mdbx_env_get_syncbytes()
pub fn set_sync_bytes(self: *Self, bytes: usize) !void {
    const rc = c.mdbx_env_set_syncbytes(self.Env, bytes);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
}

// GetSyncPeriod Controls interprocess/shared relative period since the last
// unsteady commit to force flush the data buffers to disk,
// if ref MDBX_SAFE_NOSYNC is used.
// see mdbx_env_set_syncperiod() see mdbx_env_get_syncperiod()
pub fn get_sync_period(self: *Self) !usize {
    var period: usize = 0;
    const rc = c.mdbx_env_get_syncperiod(self.Env, &period);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
    return period;
}

// SetSyncPeriod Controls interprocess/shared relative period since the last
// unsteady commit to force flush the data buffers to disk,
// if ref MDBX_SAFE_NOSYNC is used.
// see mdbx_env_set_syncperiod() see mdbx_env_get_syncperiod()
pub fn set_sync_period(self: *Self, period: usize) !void {
    const rc = c.mdbx_env_set_syncperiod(self.Env, period);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
}

// GetRPAugmentLimit Controls the in-process limit to grow a list of reclaimed/recycled
// page's numbers for finding a sequence of contiguous pages for large data
// items.
//
// details A long values requires allocation of contiguous database pages.
// To find such sequences, it may be necessary to accumulate very large lists,
// especially when placing very long values (more than a megabyte) in a large
// databases (several tens of gigabytes), which is much expensive in extreme
// cases. This threshold allows you to avoid such costs by allocating new
// pages at the end of the database (with its possible growth on disk),
// instead of further accumulating/reclaiming Garbage Collection records.
//
// On the other hand, too small threshold will lead to unreasonable database
// growth, or/and to the inability of put long values.
//
// The `MDBX_opt_rp_augment_limit` controls described limit for the current
// process. Default is 262144, it is usually enough for most cases.
pub fn get_rp_augment_limit(_: *Self) !usize {
    return try get_option(Option.OptRpAugmentLimit);
}

// SetRPAugmentLimit Controls the in-process limit to grow a list of reclaimed/recycled
// page's numbers for finding a sequence of contiguous pages for large data
// items.
//
// details A long values requires allocation of contiguous database pages.
// To find such sequences, it may be necessary to accumulate very large lists,
// especially when placing very long values (more than a megabyte) in a large
// databases (several tens of gigabytes), which is much expensive in extreme
// cases. This threshold allows you to avoid such costs by allocating new
// pages at the end of the database (with its possible growth on disk),
// instead of further accumulating/reclaiming Garbage Collection records.
//
// On the other hand, too small threshold will lead to unreasonable database
// growth, or/and to the inability of put long values.
//
// The `MDBX_opt_rp_augment_limit` controls described limit for the current
// process. Default is 262144, it is usually enough for most cases.
pub fn set_rp_augment_limit(_: *Self, limit: usize) !void {
    return try set_option(Option.OptRpAugmentLimit, limit);
}

// GetLooseLimit Controls the in-process limit to grow a cache of dirty
// pages for reuse in the current transaction.
//
// details A 'dirty page' refers to a page that has been updated in memory
// only, the changes to a dirty page are not yet stored on disk.
// To reduce overhead, it is reasonable to release not all such pages
// immediately, but to leave some ones in cache for reuse in the current
// transaction.
//
// The `MDBX_opt_loose_limit` allows you to set a limit for such cache inside
// the current process. Should be in the range 0..255, default is 64.
pub fn get_loose_limit(_: *Self) !u8 {
    return try get_option(Option.OptLooseLimit);
}

// SetLooseLimit Controls the in-process limit to grow a cache of dirty
// pages for reuse in the current transaction.
//
// details A 'dirty page' refers to a page that has been updated in memory
// only, the changes to a dirty page are not yet stored on disk.
// To reduce overhead, it is reasonable to release not all such pages
// immediately, but to leave some ones in cache for reuse in the current
// transaction.
//
// The `MDBX_opt_loose_limit` allows you to set a limit for such cache inside
// the current process. Should be in the range 0..255, default is 64.
pub fn set_loose_limit(_: *Self, limit: u8) !void {
    return try set_option(Option.OptLooseLimit, limit);
}

// GetDPReserveLimit Controls the in-process limit of a pre-allocated memory items
// for dirty pages.
//
// details A 'dirty page' refers to a page that has been updated in memory
// only, the changes to a dirty page are not yet stored on disk.
// Without ref MDBX_WRITEMAP dirty pages are allocated from memory and
// released when a transaction is committed. To reduce overhead, it is
// reasonable to release not all ones, but to leave some allocations in
// reserve for reuse in the next transaction(s).
//
// The `MDBX_opt_dp_reserve_limit` allows you to set a limit for such reserve
// inside the current process. Default is 1024.
pub fn get_dp_reserve_limit(_: *Self) !usize {
    return try get_option(Option.OptDpReserveLimit);
}

// SetDPReserveLimit Controls the in-process limit of a pre-allocated memory items
// for dirty pages.
//
// details A 'dirty page' refers to a page that has been updated in memory
// only, the changes to a dirty page are not yet stored on disk.
// Without ref MDBX_WRITEMAP dirty pages are allocated from memory and
// released when a transaction is committed. To reduce overhead, it is
// reasonable to release not all ones, but to leave some allocations in
// reserve for reuse in the next transaction(s).
//
// The `MDBX_opt_dp_reserve_limit` allows you to set a limit for such reserve
// inside the current process. Default is 1024.
pub fn set_dp_reserve_limit(_: *Self, limit: usize) !void {
    return try set_option(Option.OptDpReserveLimit, limit);
}

// GetTxDPLimit Controls the in-process limit of dirty pages
// for a write transaction.
//
// details A 'dirty page' refers to a page that has been updated in memory
// only, the changes to a dirty page are not yet stored on disk.
// Without ref MDBX_WRITEMAP dirty pages are allocated from memory and will
// be busy until are written to disk. Therefore for a large transactions is
// reasonable to limit dirty pages collecting above an some threshold but
// spill to disk instead.
//
// The `MDBX_opt_txn_dp_limit` controls described threshold for the current
// process. Default is 65536, it is usually enough for most cases.
pub fn get_txn_dp_limit(_: *Self) !usize {
    return try get_option(Option.OptTxnDpLimit);
}

// SetTxDPLimit Controls the in-process limit of dirty pages
// for a write transaction.
//
// details A 'dirty page' refers to a page that has been updated in memory
// only, the changes to a dirty page are not yet stored on disk.
// Without ref MDBX_WRITEMAP dirty pages are allocated from memory and will
// be busy until are written to disk. Therefore for a large transactions is
// reasonable to limit dirty pages collecting above an some threshold but
// spill to disk instead.
//
// The `MDBX_opt_txn_dp_limit` controls described threshold for the current
// process. Default is 65536, it is usually enough for most cases.
pub fn set_txn_dp_limit(_: *Self, limit: usize) !void {
    return try set_option(Option.OptTxnDpLimit, limit);
}

// GetTxDPInitial Controls the in-process initial allocation size for dirty pages
// list of a write transaction. Default is 1024.
pub fn get_tx_dp_initial(_: *Self) !usize {
    return try get_option(Option.OptTxnDpInitial);
}

// SetTxDPInitial Controls the in-process initial allocation size for dirty pages
// list of a write transaction. Default is 1024.
pub fn set_tx_dp_initial(_: *Self, initial: usize) !void {
    return try set_option(Option.OptTxnDpInitial, initial);
}

// GetSpillMinDenominator Controls the in-process how minimal part of the dirty pages should
// be spilled when necessary.
//
// details The `MDBX_opt_spill_min_denominator` defines the denominator for
// limiting from the bottom for part of the current dirty pages should be
// spilled when the free room for a new dirty pages (i.e. distance to the
// `MDBX_opt_txn_dp_limit` threshold) is not enough to perform requested
// operation.
// Exactly `min_pages_to_spill = dirty_pages / N`,
// where `N` is the value set by `MDBX_opt_spill_min_denominator`.
//
// Should be in the range 0..255, where zero means no restriction at the
// bottom. Default is 8, i.e. at least the 1/8 of the current dirty pages
// should be spilled when reached the condition described above.
pub fn get_spill_min_denominator(_: *Self) !u8 {
    return try get_option(Option.OptSpillMinDenominator);
}

pub fn set_spill_min_denominator(_: *Self, min: u8) !void {
    return try set_option(Option.OptSpillMinDenominator, min);
}

// GetSpillMaxDenominator Controls the in-process how maximal part of the dirty pages may be
// spilled when necessary.
//
// details The `MDBX_opt_spill_max_denominator` defines the denominator for
// limiting from the top for part of the current dirty pages may be spilled
// when the free room for a new dirty pages (i.e. distance to the
// `MDBX_opt_txn_dp_limit` threshold) is not enough to perform requested
// operation.
// Exactly `max_pages_to_spill = dirty_pages - dirty_pages / N`,
// where `N` is the value set by `MDBX_opt_spill_max_denominator`.
//
// Should be in the range 0..255, where zero means no limit, i.e. all dirty
// pages could be spilled. Default is 8, i.e. no more than 7/8 of the current
// dirty pages may be spilled when reached the condition described above.
pub fn get_spill_max_denominator(_: *Self) !u8 {
    return try get_option(Option.OptSpillMaxDenominator);
}

pub fn set_spill_max_denominator(_: *Self, max: u8) !void {
    return try set_option(Option.OptSpillMaxDenominator, max);
}

// GetSpillParent4ChildDeominator Controls the in-process how much of the parent transaction dirty
// pages will be spilled while start each child transaction.
//
// details The `MDBX_opt_spill_parent4child_denominator` defines the
// denominator to determine how much of parent transaction dirty pages will be
// spilled explicitly while start each child transaction.
// Exactly `pages_to_spill = dirty_pages / N`,
// where `N` is the value set by `MDBX_opt_spill_parent4child_denominator`.
//
// For a stack of nested transactions each dirty page could be spilled only
// once, and parent's dirty pages couldn't be spilled while child
// transaction(s) are running. Therefore a child transaction could reach
// ref MDBX_TXN_FULL when parent(s) transaction has  spilled too less (and
// child reach the limit of dirty pages), either when parent(s) has spilled
// too more (since child can't spill already spilled pages). So there is no
// universal golden ratio.
//
// Should be in the range 0..255, where zero means no explicit spilling will
// be performed during starting nested transactions.
// Default is 0, i.e. by default no spilling performed during starting nested
// transactions, that correspond historically behaviour.
pub fn get_spill_parent4child_denominator(_: *Self) !u8 {
    return try get_option(Option.OptSpillParent4ChildDenominator);
}

pub fn set_spill_parent4child_denominator(_: *Self, denominator: u8) !void {
    return try set_option(Option.OptSpillParent4ChildDenominator, denominator);
}

// GetMergeThreshold16Dot16Percent Controls the in-process threshold of semi-empty pages merge.
// warning This is experimental option and subject for change or removal.
// details This option controls the in-process threshold of minimum page
// fill, as used space of percentage of a page. Neighbour pages emptier than
// this value are candidates for merging. The threshold value is specified
// in 1/65536 of percent, which is equivalent to the 16-dot-16 fixed point
// format. The specified value must be in the range from 12.5% (almost empty)
// to 50% (half empty) which corresponds to the range from 8192 and to 32768
// in units respectively.
pub fn get_merge_threshold16_dot_16_percent(_: *Self) !u32 {
    return try get_option(Option.OptMergeThreshold16Dot16Percent);
}

pub fn set_merge_threshold16_dot_16_percent(_: *Self, percent: u32) !void {
    return try set_option(Option.OptMergeThreshold16Dot16Percent, percent);
}

// FD returns the open file descriptor (or Windows file handle) for the given
// environment.  An error is returned if the environment has not been
// successfully Opened (where C API just retruns an invalid handle).
//
// See mdbx_env_get_fd.
pub fn get_fd(self: *Self) !i64 {
    var fd: i64 = 0;
    const rc = c.mdbx_env_get_fd(self.Env, &fd);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
    return fd;
}

// ReaderCheck clears stale entries from the reader lock table and returns the
// number of entries cleared.
//
// See mdbx_reader_check()
pub fn read_check(self: *Self) !isize {
    var dead: isize = 0;
    const rc = c.mdbx_reader_check(self.Env, &dead);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
    return dead;
}

// Path returns the path argument passed to Open.  Path returns a non-nil error
// if env.Open() was not previously called.
//
// See mdbx_env_get_path.
pub fn get_path(self: *Self) ![]const u8 {
    var path: []const u8 = undefined;
    const rc = c.mdbx_env_get_path(self.Env, &path);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
    return path;
}

// MaxKeySize returns the maximum allowed length for a key.
//
// See mdbx_env_get_maxkeysize.
pub fn get_max_key_size(self: *Self) !usize {
    if (Self.Env == null) {
        return error.MDBXError{ .code = c.MDBX_EINVAL };
    }
    return c.mdbx_env_get_maxkeysize_ex(self.Env, DBFlags.DBDefaults);
}

pub const EnvFlag = enum(c.MDBX_env_flags_t) {
    EnvDefaults = c.MDBX_ENV_DEFAULTS,
    EnvValidation = c.MDBX_VALIDATION,
    // EnvNoSubDir No environment directory.
    //
    // By default, MDBX creates its environment in a directory whose pathname is
    // given in path, and creates its data and lock files under that directory.
    // With this option, path is used as-is for the database rootDB data file.
    // The database lock file is the path with "-lck" appended.
    //
    // - with `MDBX_NOSUBDIR` = in a filesystem we have the pair of MDBX-files
    //   which names derived from given pathname by appending predefined suffixes.
    //
    // - without `MDBX_NOSUBDIR` = in a filesystem we have the MDBX-directory with
    //   given pathname, within that a pair of MDBX-files with predefined names.
    //
    // This flag affects only at new environment creating by ref mdbx_env_open(),
    // otherwise at opening an existing environment libmdbx will choice this
    // automatically.
    EnvNoSubDir = c.MDBX_NOSUBDIR,
    // EnvReadOnly Read only mode.
    //
    // Open the environment in read-only mode. No write operations will be
    // allowed. MDBX will still modify the lock file - except on read-only
    // filesystems, where MDBX does not use locks.
    //
    // - with `MDBX_RDONLY` = open environment in read-only mode.
    //   MDBX supports pure read-only mode (i.e. without opening LCK-file) only
    //   when environment directory and/or both files are not writable (and the
    //   LCK-file may be missing). In such case allowing file(s) to be placed
    //   on a network read-only share.
    //
    // - without `MDBX_RDONLY` = open environment in read-write mode.
    //
    // This flag affects only at environment opening but can't be changed after.
    EnvReadOnly = c.MDBX_RDONLY,

    // EnvExclusive Open environment in exclusive/monopolistic mode.
    //
    // `MDBX_EXCLUSIVE` flag can be used as a replacement for `MDB_NOLOCK`,
    // which don't supported by MDBX.
    // In this way, you can get the minimal overhead, but with the correct
    // multi-process and multi-thread locking.
    //
    // - with `MDBX_EXCLUSIVE` = open environment in exclusive/monopolistic mode
    //   or return ref MDBX_BUSY if environment already used by other process.
    //   The rootDB feature of the exclusive mode is the ability to open the
    //   environment placed on a network share.
    //
    // - without `MDBX_EXCLUSIVE` = open environment in cooperative mode,
    //   i.e. for multi-process access/interaction/cooperation.
    //   The rootDB requirements of the cooperative mode are:
    //
    //   1. data files MUST be placed in the LOCAL file system,
    //      but NOT on a network share.
    //   2. environment MUST be opened only by LOCAL processes,
    //      but NOT over a network.
    //   3. OS kernel (i.e. file system and memory mapping implementation) and
    //      all processes that open the given environment MUST be running
    //      in the physically single RAM with cache-coherency. The only
    //      exception for cache-consistency requirement is Linux on MIPS
    //      architecture, but this case has not been tested for a long time).
    //
    // This flag affects only at environment opening but can't be changed after.
    EnvExclusive = c.MDBX_EXCLUSIVE,

    // EnvAccede Using database/environment which already opened by another process(es).
    //
    // The `MDBX_ACCEDE` flag is useful to avoid ref MDBX_INCOMPATIBLE error
    // while opening the database/environment which is already used by another
    // process(es) with unknown mode/flags. In such cases, if there is a
    // difference in the specified flags (ref MDBX_NOMETASYNC,
    // ref MDBX_SAFE_NOSYNC, ref MDBX_UTTERLY_NOSYNC, ref MDBX_LIFORECLAIM,
    // ref MDBX_COALESCE and ref MDBX_NORDAHEAD), instead of returning an error,
    // the database will be opened in a compatibility with the already used mode.
    //
    // `MDBX_ACCEDE` has no effect if the current process is the only one either
    // opening the DB in read-only mode or other process(es) uses the DB in
    // read-only mode.
    EnvAccede = c.MDBX_ACCEDE,

    // EnvWriteMap Map data into memory with write permission.
    //
    // Use a writeable memory map unless ref MDBX_RDONLY is set. This uses fewer
    // mallocs and requires much less work for tracking database pages, but
    // loses protection from application bugs like wild pointer writes and other
    // bad updates into the database. This may be slightly faster for DBs that
    // fit entirely in RAM, but is slower for DBs larger than RAM. Also adds the
    // possibility for stray application writes thru pointers to silently
    // corrupt the database.
    //
    // - with `MDBX_WRITEMAP` = all data will be mapped into memory in the
    //   read-write mode. This offers a significant performance benefit, since the
    //   data will be modified directly in mapped memory and then flushed to disk
    //   by single system call, without any memory management nor copying.
    //
    // - without `MDBX_WRITEMAP` = data will be mapped into memory in the
    //   read-only mode. This requires stocking all modified database pages in
    //   memory and then writing them to disk through file operations.
    //
    // warning On the other hand, `MDBX_WRITEMAP` adds the possibility for stray
    // application writes thru pointers to silently corrupt the database.
    //
    // note The `MDBX_WRITEMAP` mode is incompatible with nested transactions,
    // since this is unreasonable. I.e. nested transactions requires mallocation
    // of database pages and more work for tracking ones, which neuters a
    // performance boost caused by the `MDBX_WRITEMAP` mode.
    //
    // This flag affects only at environment opening but can't be changed after.
    EnvWriteMap = c.MDBX_WRITEMAP,

    // EnvNoTLS Tie reader locktable slots to read-only transactions
    // instead of to threads.
    //
    // Don't use Thread-Local Storage, instead tie reader locktable slots to
    // ref MDBX_txn objects instead of to threads. So, ref mdbx_txn_reset()
    // keeps the slot reserved for the ref MDBX_txn object. A thread may use
    // parallel read-only transactions. And a read-only transaction may span
    // threads if you synchronizes its use.
    //
    // Applications that multiplex many user threads over individual OS threads
    // need this option. Such an application must also serialize the write
    // transactions in an OS thread, since MDBX's write locking is unaware of
    // the user threads.
    //
    // note Regardless to `MDBX_NOTLS` flag a write transaction entirely should
    // always be used in one thread from start to finish. MDBX checks this in a
    // reasonable manner and return the ref MDBX_THREAD_MISMATCH error in rules
    // violation.
    //
    // This flag affects only at environment opening but can't be changed after.
    EnvNoTLS = c.MDBX_NOTLS,

    // EnvNoReadAhead Don't do readahead.
    //
    // Turn off readahead. Most operating systems perform readahead on read
    // requests by default. This option turns it off if the OS supports it.
    // Turning it off may help random read performance when the DB is larger
    // than RAM and system RAM is full.
    //
    // By default libmdbx dynamically enables/disables readahead depending on
    // the actual database size and currently available memory. On the other
    // hand, such automation has some limitation, i.e. could be performed only
    // when DB size changing but can't tracks and reacts changing a free RAM
    // availability, since it changes independently and asynchronously.
    //
    // note The mdbx_is_readahead_reasonable() function allows to quickly find
    // out whether to use readahead or not based on the size of the data and the
    // amount of available memory.
    //
    // This flag affects only at environment opening and can't be changed after.
    EnvNoReadAhead = c.MDBX_NORDAHEAD,

    // EnvNoMemInit Don't initialize malloc'ed memory before writing to datafile.
    //
    // Don't initialize malloc'ed memory before writing to unused spaces in the
    // data file. By default, memory for pages written to the data file is
    // obtained using malloc. While these pages may be reused in subsequent
    // transactions, freshly malloc'ed pages will be initialized to zeroes before
    // use. This avoids persisting leftover data from other code (that used the
    // heap and subsequently freed the memory) into the data file.
    //
    // Note that many other system libraries may allocate and free memory from
    // the heap for arbitrary uses. E.g., stdio may use the heap for file I/O
    // buffers. This initialization step has a modest performance cost so some
    // applications may want to disable it using this flag. This option can be a
    // problem for applications which handle sensitive data like passwords, and
    // it makes memory checkers like Valgrind noisy. This flag is not needed
    // with ref MDBX_WRITEMAP, which writes directly to the mmap instead of using
    // malloc for pages. The initialization is also skipped if ref MDBX_RESERVE
    // is used; the caller is expected to overwrite all of the memory that was
    // reserved in that case.
    //
    // This flag may be changed at any time using `mdbx_env_set_flags()`.
    EnvNoMemInit = c.MDBX_NOMEMINIT,

    // EnvCoalesce Aims to coalesce a Garbage Collection items.
    //
    // With `MDBX_COALESCE` flag MDBX will aims to coalesce items while recycling
    // a Garbage Collection. Technically, when possible short lists of pages
    // will be combined into longer ones, but to fit on one database page. As a
    // result, there will be fewer items in Garbage Collection and a page lists
    // are longer, which slightly increases the likelihood of returning pages to
    // Unallocated space and reducing the database file.
    //
    // This flag may be changed at any time using mdbx_env_set_flags().
    EnvCoalesce = c.MDBX_COALESCE,

    // EnvLIFOReclaim LIFO policy for recycling a Garbage Collection items.
    //
    // `MDBX_LIFORECLAIM` flag turns on LIFO policy for recycling a Garbage
    // Collection items, instead of FIFO by default. On systems with a disk
    // write-back cache, this can significantly increase write performance, up
    // to several times in a best case scenario.
    //
    // LIFO recycling policy means that for reuse pages will be taken which became
    // unused the lastest (i.e. just now or most recently). Therefore the loop of
    // database pages circulation becomes as short as possible. In other words,
    // the number of pages, that are overwritten in memory and on disk during a
    // series of write transactions, will be as small as possible. Thus creates
    // ideal conditions for the efficient operation of the disk write-back cache.
    //
    // ref MDBX_LIFORECLAIM is compatible with all no-sync flags, but gives NO
    // noticeable impact in combination with ref MDBX_SAFE_NOSYNC or
    // ref MDBX_UTTERLY_NOSYN-Because MDBX will reused pages only before the
    // last "steady" MVCC-snapshot, i.e. the loop length of database pages
    // circulation will be mostly defined by frequency of calling
    // ref mdbx_env_sync() rather than LIFO and FIFO difference.
    //
    // This flag may be changed at any time using mdbx_env_set_flags().
    EnvLIFOReclaim = c.MDBX_LIFORECLAIM,

    EnvPagePerTurb = c.MDBX_PAGEPERTURB,

    // SYNC MODES

    // defgroup sync_modes SYNC MODES
    //
    // attention Using any combination of ref MDBX_SAFE_NOSYNC, ref
    // MDBX_NOMETASYNC and especially ref MDBX_UTTERLY_NOSYNC is always a deal to
    // reduce durability for gain write performance. You must know exactly what
    // you are doing and what risks you are taking!
    //
    // note for LMDB users: ref MDBX_SAFE_NOSYNC is NOT similar to LMDB_NOSYNC,
    // but ref MDBX_UTTERLY_NOSYNC is exactly match LMDB_NOSYN-See details
    // below.
    //
    // THE SCENE:
    // - The DAT-file contains several MVCC-snapshots of B-tree at same time,
    //   each of those B-tree has its own root page.
    // - Each of meta pages at the beginning of the DAT file contains a
    //   pointer to the root page of B-tree which is the result of the particular
    //   transaction, and a number of this transaction.
    // - For data durability, MDBX must first write all MVCC-snapshot data
    //   pages and ensure that are written to the disk, then update a meta page
    //   with the new transaction number and a pointer to the corresponding new
    //   root page, and flush any buffers yet again.
    // - Thus during commit a I/O buffers should be flushed to the disk twice;
    //   i.e. fdatasync(), FlushFileBuffers() or similar syscall should be
    //   called twice for each commit. This is very expensive for performance,
    //   but guaranteed durability even on unexpected system failure or power
    //   outage. Of course, provided that the operating system and the
    //   underlying hardware (e.g. disk) work correctly.
    //
    // TRADE-OFF:
    // By skipping some stages described above, you can significantly benefit in
    // speed, while partially or completely losing in the guarantee of data
    // durability and/or consistency in the event of system or power failure.
    // Moreover, if for any reason disk write order is not preserved, then at
    // moment of a system crash, a meta-page with a pointer to the new B-tree may
    // be written to disk, while the itself B-tree not yet. In that case, the
    // database will be corrupted!
    //
    // see MDBX_SYNC_DURABLE see MDBX_NOMETASYNC see MDBX_SAFE_NOSYNC
    // see MDBX_UTTERLY_NOSYNC

    // EnvSyncDurable Default robust and durable sync mode.
    //
    // Metadata is written and flushed to disk after a data is written and
    // flushed, which guarantees the integrity of the database in the event
    // of a crash at any time.
    //
    // attention Please do not use other modes until you have studied all the
    // details and are sure. Otherwise, you may lose your users' data, as happens
    // in [Miranda NG](https://www.miranda-ng.org/) messenger.
    EnvSyncDurable = c.MDBX_SYNC_DURABLE,

    // EnvNoMetaSync Don't sync the meta-page after commit.
    //
    // Flush system buffers to disk only once per transaction commit, omit the
    // metadata flush. Defer that until the system flushes files to disk,
    // or next non-ref MDBX_RDONLY commit or ref mdbx_env_sync(). Depending on
    // the platform and hardware, with ref MDBX_NOMETASYNC you may get a doubling
    // of write performance.
    //
    // This trade-off maintains database integrity, but a system crash may
    // undo the last committed transaction. I.e. it preserves the ACI
    // (atomicity, consistency, isolation) but not D (durability) database
    // property.
    //
    // `MDBX_NOMETASYNC` flag may be changed at any time using
    // ref mdbx_env_set_flags() or by passing to ref mdbx_txn_begin() for
    // particular write transaction. see sync_modes
    EnvNoMetaSync = c.MDBX_NOMETASYNC,

    // EnvSafeNoSync Don't sync anything but keep previous steady commits.
    //
    // Like ref MDBX_UTTERLY_NOSYNC the `MDBX_SAFE_NOSYNC` flag disable similarly
    // flush system buffers to disk when committing a transaction. But there is a
    // huge difference in how are recycled the MVCC snapshots corresponding to
    // previous "steady" transactions (see below).
    //
    // With ref MDBX_WRITEMAP the `MDBX_SAFE_NOSYNC` instructs MDBX to use
    // asynchronous mmap-flushes to disk. Asynchronous mmap-flushes means that
    // actually all writes will scheduled and performed by operation system on it
    // own manner, i.e. unordered. MDBX itself just notify operating system that
    // it would be nice to write data to disk, but no more.
    //
    // Depending on the platform and hardware, with `MDBX_SAFE_NOSYNC` you may get
    // a multiple increase of write performance, even 10 times or more.
    //
    // In contrast to ref MDBX_UTTERLY_NOSYNC mode, with `MDBX_SAFE_NOSYNC` flag
    // MDBX will keeps untouched pages within B-tree of the last transaction
    // "steady" which was synced to disk completely. This has big implications for
    // both data durability and (unfortunately) performance:
    //  - a system crash can't corrupt the database, but you will lose the last
    //    transactions; because MDBX will rollback to last steady commit since it
    //    kept explicitly.
    //  - the last steady transaction makes an effect similar to "long-lived" read
    //    transaction (see above in the ref restrictions section) since prevents
    //    reuse of pages freed by newer write transactions, thus the any data
    //    changes will be placed in newly allocated pages.
    //  - to avoid rapid database growth, the system will sync data and issue
    //    a steady commit-point to resume reuse pages, each time there is
    //    insufficient space and before increasing the size of the file on disk.
    //
    // In other words, with `MDBX_SAFE_NOSYNC` flag MDBX insures you from the
    // whole database corruption, at the cost increasing database size and/or
    // number of disk IOPs. So, `MDBX_SAFE_NOSYNC` flag could be used with
    // ref mdbx_env_sync() as alternatively for batch committing or nested
    // transaction (in some cases). As well, auto-sync feature exposed by
    // ref mdbx_env_set_syncbytes() and ref mdbx_env_set_syncperiod() functions
    // could be very useful with `MDBX_SAFE_NOSYNC` flag.
    //
    // The number and volume of of disk IOPs with MDBX_SAFE_NOSYNC flag will
    // exactly the as without any no-sync flags. However, you should expect a
    // larger process's [work set](https://bit.ly/2kA2tFX) and significantly worse
    // a [locality of reference](https://bit.ly/2mbYq2J), due to the more
    // intensive allocation of previously unused pages and increase the size of
    // the database.
    //
    // `MDBX_SAFE_NOSYNC` flag may be changed at any time using
    // ref mdbx_env_set_flags() or by passing to ref mdbx_txn_begin() for
    // particular write transaction.
    EnvSafeNoSync = c.MDBX_SAFE_NOSYNC,

    // EnvUtterlyNoSync Don't sync anything and wipe previous steady commits.
    //
    // Don't flush system buffers to disk when committing a transaction. This
    // optimization means a system crash can corrupt the database, if buffers are
    // not yet flushed to disk. Depending on the platform and hardware, with
    // `MDBX_UTTERLY_NOSYNC` you may get a multiple increase of write performance,
    // even 100 times or more.
    //
    // If the filesystem preserves write order (which is rare and never provided
    // unless explicitly noted) and the ref MDBX_WRITEMAP and ref
    // MDBX_LIFORECLAIM flags are not used, then a system crash can't corrupt the
    // database, but you can lose the last transactions, if at least one buffer is
    // not yet flushed to disk. The risk is governed by how often the system
    // flushes dirty buffers to disk and how often ref mdbx_env_sync() is called.
    // So, transactions exhibit ACI (atomicity, consistency, isolation) properties
    // and only lose `D` (durability). I.e. database integrity is maintained, but
    // a system crash may undo the final transactions.
    //
    // Otherwise, if the filesystem not preserves write order (which is
    // typically) or ref MDBX_WRITEMAP or ref MDBX_LIFORECLAIM flags are used,
    // you should expect the corrupted database after a system crash.
    //
    // So, most important thing about `MDBX_UTTERLY_NOSYNC`:
    //  - a system crash immediately after commit the write transaction
    //    high likely lead to database corruption.
    //  - successful completion of mdbx_env_sync(force = true) after one or
    //    more committed transactions guarantees consistency and durability.
    //  - BUT by committing two or more transactions you back database into
    //    a weak state, in which a system crash may lead to database corruption!
    //    In case single transaction after mdbx_env_sync, you may lose transaction
    //    itself, but not a whole database.
    //
    // Nevertheless, `MDBX_UTTERLY_NOSYNC` provides "weak" durability in case
    // of an application crash (but no durability on system failure), and
    // therefore may be very useful in scenarios where data durability is
    // not required over a system failure (e.g for short-lived data), or if you
    // can take such risk.
    //
    // `MDBX_UTTERLY_NOSYNC` flag may be changed at any time using
    // ref mdbx_env_set_flags(), but don't has effect if passed to
    // ref mdbx_txn_begin() for particular write transaction. see sync_modes
    EnvUtterlyNoSync = c.MDBX_UTTERLY_NOSYNC,
};

pub fn set_flags(self: *Self, flags: EnvFlag, onoff: bool) !void {
    const rc = c.mdbx_env_set_flags(self.Env, flags, onoff);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
}

pub fn get_flags(self: *Self) !EnvFlag {
    var flags: EnvFlag = EnvFlag.EnvDefaults;
    const rc = c.mdbx_env_get_flags(self.Env, &flags);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
    return flags;
}

pub fn copy(self: *Self, path: []const u8, flags: CopyFlags) !void {
    const rc = c.mdbx_env_copy(self.Env, path, flags);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
}

pub fn open(self: *Self, path: []const u8, flags: EnvFlag, mode: u32) !void {
    const rc = c.mdbx_env_open(self.Env, path, flags, mode);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
}

pub const DBFlags = enum(c.MDBX_db_flags_t) {
    DBDefaults = c.MDBX_DB_DEFAULTS,
    // DBReverseKey Use reverse string keys
    DBReverseKey = c.MDBX_REVERSEKEY,

    // DBDupSort Use sorted duplicates, i.e. allow multi-values
    DBDupSort = c.MDBX_DUPSORT,

    // DBIntegerKey Numeric keys in native byte order either uint32_t or uint64_t. The keys
    // must all be of the same size and must be aligned while passing as
    // arguments.
    DBIntegerKey = c.MDBX_INTEGERKEY,

    // DBDupFixed With ref MDBX_DUPSORT; sorted dup items have fixed size
    DBDupFixed = c.MDBX_DUPFIXED,

    // DBIntegerGroup With ref MDBX_DUPSORT and with ref MDBX_DUPFIXED; dups are fixed size
    // ref MDBX_INTEGERKEY -style integers. The data values must all be of the
    // same size and must be aligned while passing as arguments.
    DBIntegerGroup = c.MDBX_INTEGERDUP,

    // DBReverseDup With ref MDBX_DUPSORT; use reverse string comparison
    DBReverseDup = c.MDBX_REVERSEDUP,

    // DBCreate Create DB if not already existing
    DBCreate = c.MDBX_CREATE,

    // DBAccede Opens an existing sub-database created with unknown flags.
    //
    // The `MDBX_DB_ACCEDE` flag is intend to open a existing sub-database which
    // was created with unknown flags (ref MDBX_REVERSEKEY, ref MDBX_DUPSORT,
    // ref MDBX_INTEGERKEY, ref MDBX_DUPFIXED, ref MDBX_INTEGERDUP and
    // ref MDBX_REVERSEDUP).
    //
    // In such cases, instead of returning the ref MDBX_INCOMPATIBLE error, the
    // sub-database will be opened with flags which it was created, and then an
    // application could determine the actual flags by ref mdbx_dbi_flags().
    DBAccede = c.MDBX_ACCEDE,
};

pub const CopyFlags = enum(c.MDBX_copy_flags_t) {
    CopyDefaults = c.MDBX_CP_DEFAULTS,

    // CopyCompact Compacting copy: omit free pages
    CopyCompact = c.MDBX_CP_COMPACT,

    // CopyForceDynamicSize Force to make resizeable copy, i.e. dynamic size instead of fixed
    CopyForceDynamicSize = c.MDBX_CP_FORCE_DYNAMIC_SIZE,
};

pub const DBIState = enum(c.MDBX_db_state_t) {
    // DB was written in this txn
    DBIStateDirty = c.MDBX_DBI_DIRTY,

    // Named-DB record is older than txnID
    DBIStateStale = c.MDBX_DBI_STALE,

    // Named-DB handle opened in this txn
    DBIStateFresh = c.MDBX_DBI_FRESH,

    // Named-DB handle created in this txn
    DBIStateCreat = c.MDBX_DBI_CREAT,
};

pub const DeleteMode = enum(c.MDBX_env_delete_mode_t) {
    // DeleteModeJustDelete brief Just delete the environment's files and directory if any.
    // note On POSIX systems, processes already working with the database will
    // continue to work without interference until it close the environment.
    // note On Windows, the behavior of `MDB_ENV_JUST_DELETE` is different
    // because the system does not support deleting files that are currently
    // memory mapped.
    DeleteModeJustDelete = c.MDBX_ENV_JUST_DELETE,

    // DeleteModeEnsureUnused brief Make sure that the environment is not being used by other
    // processes, or return an error otherwise.
    DeleteModeEnsureUnused = c.MDBX_ENV_ENSURE_UNUSED,

    // DeleteModeWaitForUnused brief Wait until other processes closes the environment before deletion.
    DeleteModeWaitForUnused = c.MDBX_ENV_WAIT4UNUSED,
};

pub fn beginTx(self: *Self, flags: tx.TxFlags) !*tx.Tx {
    var txn: *c.MDBX_txn = null;
    const rc = c.mdbx_txn_begin(self.Env, null, flags, &txn);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
    return &tx.Tx{ .Txn = txn, .Env = &self.Env };
}
