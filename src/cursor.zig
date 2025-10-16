const std = @import("std");
const c = @import("c.zig").c;

const errors = @import("errors.zig");
const types = @import("types.zig");
const flags = @import("flags.zig");

// 重新导出类型
pub const DBI = types.DBI;
pub const Val = types.Val;
pub const CursorOp = flags.CursorOp;
pub const PutFlagSet = flags.PutFlagSet;
pub const putFlagsToInt = flags.putFlagsToInt;

/// 游标句柄
pub const Cursor = struct {
    cursor: ?*c.MDBX_cursor,

    const Self = @This();

    /// 打开游标
    pub fn open(transaction: *c.MDBX_txn, database: DBI) errors.MDBXError!Self {
        var cursor: ?*c.MDBX_cursor = null;
        const rc = c.mdbx_cursor_open(transaction, database, &cursor);
        try errors.checkError(rc);
        return Self{ .cursor = cursor };
    }

    /// 关闭游标
    pub fn close(self: *Self) void {
        if (self.cursor) |cur| {
            c.mdbx_cursor_close(cur);
            self.cursor = null;
        }
    }

    /// 续订游标（用于重新使用已关闭的游标）
    pub fn renew(self: *Self, transaction: *c.MDBX_txn) errors.MDBXError!void {
        const rc = c.mdbx_cursor_renew(transaction, self.cursor);
        try errors.checkError(rc);
    }

    /// 获取游标关联的事务
    pub fn txn(self: *Self) *c.MDBX_txn {
        return c.mdbx_cursor_txn(self.cursor);
    }

    /// 获取游标关联的 DBI
    pub fn dbi(self: *Self) DBI {
        return c.mdbx_cursor_dbi(self.cursor);
    }

    /// 使用游标获取数据（使用 Val 类型）
    ///
    /// 这是新的 API，使用 Val 类型提供更好的类型安全性。
    ///
    /// 参数：
    ///   key_val - 键的 Val，用于输入和输出
    ///   data_val - 数据的 Val，用于输入和输出
    ///   op - 游标操作类型
    ///
    /// 警告：key_val 和 data_val 在调用后会被更新为指向 MDBX 内部内存。
    /// 这些内存的生命周期与事务相关联。
    pub fn getRaw(
        self: *Self,
        key_val: *Val,
        data_val: *Val,
        op: CursorOp,
    ) errors.MDBXError!void {
        const rc = c.mdbx_cursor_get(self.cursor, key_val.asPtr(), data_val.asPtr(), @intFromEnum(op));
        try errors.checkError(rc);
    }

    /// 使用游标获取数据（便利方法）
    ///
    /// 返回键值对的便利结构体。
    ///
    /// 警告：返回的键值对引用 MDBX 内部内存，生命周期与事务相关联。
    pub fn get(
        self: *Self,
        key: ?[]const u8,
        data: ?[]const u8,
        op: CursorOp,
    ) errors.MDBXError!struct { key: Val, data: Val } {
        var key_val = if (key) |k| Val.fromBytes(k) else Val.empty();
        var data_val = if (data) |d| Val.fromBytes(d) else Val.empty();

        try self.getRaw(&key_val, &data_val, op);

        return .{
            .key = key_val,
            .data = data_val,
        };
    }

    /// 使用游标获取数据（返回字节切片）
    ///
    /// 这是最便利的方法，直接返回字节切片。
    ///
    /// 警告：返回的切片引用 MDBX 内部内存，生命周期与事务相关联。
    pub fn getBytes(
        self: *Self,
        key: ?[]const u8,
        data: ?[]const u8,
        op: CursorOp,
    ) errors.MDBXError!struct { key: []const u8, data: []const u8 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = result.data.toBytes(),
        };
    }

    /// 使用游标插入或更新数据
    pub fn put(
        self: *Self,
        key: []const u8,
        data: []const u8,
        flags_set: PutFlagSet,
    ) errors.MDBXError!void {
        var key_val = Val.fromBytes(key);
        var data_val = Val.fromBytes(data);

        const c_flags = putFlagsToInt(flags_set);
        const rc = c.mdbx_cursor_put(self.cursor, key_val.asPtr(), data_val.asPtr(), c_flags);
        try errors.checkError(rc);
    }

    /// 使用游标删除当前键/数据对
    pub fn del(self: *Self, flags_set: PutFlagSet) errors.MDBXError!void {
        const c_flags = putFlagsToInt(flags_set);
        const rc = c.mdbx_cursor_del(self.cursor, c_flags);
        try errors.checkError(rc);
    }

    /// 获取游标位置的项数量（用于 DUPSORT）
    pub fn count(self: *Self) errors.MDBXError!usize {
        var cnt: usize = 0;
        const rc = c.mdbx_cursor_count(self.cursor, &cnt);
        try errors.checkError(rc);
        return cnt;
    }

    /// 检查游标是否在 EOF 状态
    pub fn eof(self: *Self) errors.MDBXError!bool {
        const rc = c.mdbx_cursor_eof(self.cursor);
        if (rc == c.MDBX_RESULT_TRUE) return true;
        if (rc == c.MDBX_RESULT_FALSE) return false;
        return errors.toError(rc);
    }

    /// 检查游标是否在 BOF 状态（文件开头）
    pub fn onFirst(self: *Self) errors.MDBXError!bool {
        const rc = c.mdbx_cursor_on_first(self.cursor);
        if (rc == c.MDBX_RESULT_TRUE) return true;
        if (rc == c.MDBX_RESULT_FALSE) return false;
        return errors.toError(rc);
    }

    /// 检查游标是否在最后一条记录
    pub fn onLast(self: *Self) errors.MDBXError!bool {
        const rc = c.mdbx_cursor_on_last(self.cursor);
        if (rc == c.MDBX_RESULT_TRUE) return true;
        if (rc == c.MDBX_RESULT_FALSE) return false;
        return errors.toError(rc);
    }
};
