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
//   try env.open("/path/to/db", .defaults, 0o644);
//
//   var txn = try env.beginTxn(null, .read_write);
//   defer txn.abort();
//
//   const dbi = try txn.openDBI(null, .create);
//   try txn.put(dbi, "key", "value", .upsert);
//   try txn.commit();

const std = @import("std");

// 核心模块
pub const Env = @import("env.zig").Env;
pub const Txn = @import("txn.zig").Txn;
pub const Cursor = @import("cursor.zig").Cursor;
pub const errors = @import("errors.zig");
pub const opt = @import("opt.zig");

// 类型导出
pub const DBI = @import("env.zig").DBI;
pub const Geometry = @import("env.zig").Geometry;

// 标志类型
pub const EnvFlags = @import("env.zig").EnvFlags;
pub const DBFlags = @import("env.zig").DBFlags;
pub const CopyFlags = @import("env.zig").CopyFlags;
pub const DBIState = @import("env.zig").DBIState;
pub const DeleteMode = @import("env.zig").DeleteMode;

pub const TxFlags = @import("txn.zig").TxFlags;
pub const PutFlags = @import("txn.zig").PutFlags;
pub const TxInfo = @import("txn.zig").TxInfo;

pub const CursorOp = @import("cursor.zig").CursorOp;

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
