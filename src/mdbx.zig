// MDBX Zig 绑定库
//
// 这是 libmdbx 的 Zig 语言绑定，提供了简洁且类型安全的 API。
//
// 基本使用:
//   const zmdbx = @import("mdbx.zig");
//
//   var env = try zmdbx.Env.init();
//   defer env.deinit();
//
//   try env.open("/path/to/db", zmdbx.EnvFlagSet.init(.{}), 0o644);
//
//   var txn = try env.beginWriteTxn();
//   defer txn.abort();
//
//   const dbi = try txn.openDBI(null, zmdbx.DBFlagSet.init(.{ .create = true }));
//   try txn.put(dbi, "key", "value", zmdbx.PutFlagSet.init(.{}));
//   try txn.commit();

const std = @import("std");

// 核心模块
pub const Env = @import("env.zig").Env;
pub const Txn = @import("txn.zig").Txn;
pub const Cursor = @import("cursor.zig").Cursor;
pub const errors = @import("errors.zig");
pub const opt = @import("opt.zig");

// 新模块导出
pub const types = @import("types.zig");
pub const flags = @import("flags.zig");

// 类型导出（从 types.zig）
pub const DBI = types.DBI;
pub const Geometry = types.Geometry;
pub const TxInfo = types.TxInfo;
pub const Val = types.Val;

// 环境标志（从 flags.zig）
pub const EnvFlag = flags.EnvFlag;
pub const EnvFlagSet = flags.EnvFlagSet;
pub const envFlagsToInt = flags.envFlagsToInt;

// 数据库标志（从 flags.zig）
pub const DBFlag = flags.DBFlag;
pub const DBFlagSet = flags.DBFlagSet;
pub const dbFlagsToInt = flags.dbFlagsToInt;

// 复制标志（从 flags.zig）
pub const CopyFlag = flags.CopyFlag;
pub const CopyFlagSet = flags.CopyFlagSet;
pub const copyFlagsToInt = flags.copyFlagsToInt;

// DBI 状态（从 flags.zig）
pub const DBIState = flags.DBIState;

// 删除模式（从 flags.zig）
pub const DeleteMode = flags.DeleteMode;

// 事务标志（从 flags.zig）
pub const TxFlag = flags.TxFlag;
pub const TxFlagSet = flags.TxFlagSet;
pub const txFlagsToInt = flags.txFlagsToInt;

// Put 操作标志（从 flags.zig）
pub const PutFlag = flags.PutFlag;
pub const PutFlagSet = flags.PutFlagSet;
pub const putFlagsToInt = flags.putFlagsToInt;

// 游标操作（从 flags.zig）
pub const CursorOp = flags.CursorOp;

// 选项
pub const Option = opt.Option;

// 错误类型
pub const MDBXError = errors.MDBXError;
pub const Error = errors.Error;

test "basic functionality" {
    const testing = std.testing;

    // 创建环境
    var env = try Env.init();
    defer env.deinit();

    // 测试通过
    try testing.expect(env.env != null);
}

test "Val type" {
    const testing = std.testing;

    const data = "Hello, MDBX!";
    const val = Val.fromBytes(data);

    const result = val.toBytes();
    try testing.expectEqualStrings(data, result);
}

test "Flag sets" {
    const testing = std.testing;

    // 测试环境标志组合
    var env_flags = EnvFlagSet.init(.{});
    env_flags.insert(.validation);
    env_flags.insert(.no_sub_dir);

    const c_flags = envFlagsToInt(env_flags);
    try testing.expect(c_flags != 0);

    // 测试数据库标志组合
    var db_flags = DBFlagSet.init(.{});
    db_flags.insert(.create);
    db_flags.insert(.dup_sort);

    const c_db_flags = dbFlagsToInt(db_flags);
    try testing.expect(c_db_flags != 0);
}
