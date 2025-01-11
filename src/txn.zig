const c = @cImport({
    @cInclude("mdbx.h");
});

const env = @import("env.zig");

pub const TxFlags = enum(c.MDBX_txn_flags) {
    // TxReadWrite Start read-write transaction.
    //
    // Only one write transaction may be active at a time. Writes are fully
    // serialized, which guarantees that writers can never deadlock.
    ReadWrite = c.MDBX_TXN_READWRITE,

    // TxReadOnly Start read-only transaction.
    //
    // There can be multiple read-only transactions simultaneously that do not
    // block each other and a write transactions.
    ReadOnly = c.MDBX_TXN_RDONLY,

    // TxReadOnlyPrepare Prepare but not start read-only transaction.
    //
    // Transaction will not be started immediately, but created transaction handle
    // will be ready for use with ref mdbx_txn_renew(). This flag allows to
    // preallocate memory and assign a reader slot, thus avoiding these operations
    // at the next start of the transaction.
    ReadOnlyPrepare = c.MDBX_TXN_RDONLY_PREPARE,

    // TxTry Do not block when starting a write transaction.
    Try = c.MDBX_TXN_TRY,

    // TxNoMetaSync Exactly the same as ref MDBX_NOMETASYNC,
    // but for this transaction only
    NoMetaSync = c.MDBX_TXN_NOMETASYNC,

    // TxNoSync Exactly the same as ref MDBX_SAFE_NOSYNC,
    // but for this transaction only
    NoSync = c.MDBX_TXN_NOSYNC,
};

pub const PutFlags = enum(c.MDBX_put_flags_t) {
    // PutUpsert Upsertion by default (without any other flags)
    Upsert = c.MDBX_UPSERT,

    // PutNoOverwrite Don't write if the key already exists.
    NoOverwrite = c.MDBX_NOOVERWRITE,

    // PutNoDupData Don't write if the key and data pair already exist.
    NoDupData = c.MDBX_NODUPDATA,

    // PutCurrent Update the data of the key to the current key.
    Current = c.MDBX_CURRENT,

    // PutAllDups Has effect only for ref MDBX_DUPSORT databases.
    // For deletion: remove all multi-values (aka duplicates) for given key.
    // For upsertion: replace all multi-values for given key with a new one.
    AllDups = c.MDBX_ALLDUPS,

    // PutReserve Reserve space for data, don't write it.
    Reserve = c.MDBX_RESERVE,

    // PutAppend Append the data to the end of the database.
    Append = c.MDBX_APPEND,

    // PutAppendDup Append the data to the end of the database.
    AppendDup = c.MDBX_APPENDDUP,

    // PutMultiple Only for ref MDBX_DUPFIXED.
    // Store multiple data items in one call.
    Multiple = c.MDBX_MULTIPLE,
};

pub const TxInfo = c.MDBX_txn_info;

env: *c.MDBX_env,
txn: *c.MDBX_txn,

const Self = @This();

// Info Return information about the MDBX transaction.
pub fn Info(self: *Self) !*TxInfo {
    var info: *TxInfo = undefined;
    const rc = c.mdbx_txn_info(self.txn, &info, true);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
    return info;
}

pub fn commit(self: *Self) !void {
    const rc = c.mdbx_txn_commit(self.txn);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
}

pub fn abort(self: *Self) !void {
    const rc = c.mdbx_txn_abort(self.txn);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
}

// Break Marks transaction as broken.
// ingroup c_transactions
//
// Function keeps the transaction handle and corresponding locks, but makes
// impossible to perform any operations within a broken transaction.
// Broken transaction must then be aborted explicitly later.
//
// param [in] txn  A transaction handle returned by ref mdbx_txn_begin().
//
// see mdbx_txn_abort() see mdbx_txn_reset() see mdbx_txn_commit()
// returns A non-zero error value on failure and 0 on success.
pub fn TxBreak(self: *Self) !void {
    const rc = c.mdbx_txn_break(self.txn);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
}

pub fn reset(self: *Self) !void {
    const rc = c.mdbx_txn_reset(self.txn);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
}

pub fn renew(self: *Self) !void {
    const rc = c.mdbx_txn_renew(self.txn);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
}

pub fn openDBI(self: *Self, name: []const u8, flags: env.DBFlags) !env.DBI {
    var dbi: env.DBI = undefined;
    const rc = c.mdbx_dbi_open(self.txn, name, flags, &dbi);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
    return dbi;
}

pub fn get(self: *Self, dbi: env.DBI, key: []const u8) ![]const u8 {
    var val: []const u8 = undefined;
    const rc = c.mdbx_get(self.txn, dbi, key, &val);
    if (rc != 0) {
        return error.MDBXError{ .code = rc };
    }
    return val;
}
