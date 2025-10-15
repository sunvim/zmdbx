const std = @import("std");
const c_import = @import("c.zig");
const c = c_import.c;

const errors = @import("errors.zig");
const Env = @import("env.zig");

/// 游标操作类型
pub const CursorOp = enum(c.MDBX_cursor_op) {
    /// 定位到第一个键
    first = c.MDBX_FIRST,
    /// 定位到第一个大于等于指定键的数据
    first_dup = c.MDBX_FIRST_DUP,
    /// 定位到指定键的第一个数据项（用于 DUPSORT）
    get_both = c.MDBX_GET_BOTH,
    /// 定位到大于等于指定键和数据的位置（用于 DUPSORT）
    get_both_range = c.MDBX_GET_BOTH_RANGE,
    /// 返回当前位置的键/数据对
    get_current = c.MDBX_GET_CURRENT,
    /// 返回包含指定键的多个数据（用于 MDBX_DUPFIXED）
    get_multiple = c.MDBX_GET_MULTIPLE,
    /// 定位到最后一个键
    last = c.MDBX_LAST,
    /// 定位到最后一个数据项（用于 DUPSORT）
    last_dup = c.MDBX_LAST_DUP,
    /// 定位到下一个键
    next = c.MDBX_NEXT,
    /// 定位到下一个数据项（用于 DUPSORT）
    next_dup = c.MDBX_NEXT_DUP,
    /// 移动到下一个具有多个数据值的键（用于 MDBX_DUPFIXED）
    next_multiple = c.MDBX_NEXT_MULTIPLE,
    /// 移动到下一个键（即使当前键有多个数据项）
    next_nodup = c.MDBX_NEXT_NODUP,
    /// 定位到前一个键
    prev = c.MDBX_PREV,
    /// 定位到前一个数据项（用于 DUPSORT）
    prev_dup = c.MDBX_PREV_DUP,
    /// 移动到前一个键（即使当前键有多个数据项）
    prev_nodup = c.MDBX_PREV_NODUP,
    /// 定位到指定键
    set = c.MDBX_SET,
    /// 定位到指定键（如果不存在则定位到下一个键）
    set_key = c.MDBX_SET_KEY,
    /// 定位到大于等于指定键的键
    set_range = c.MDBX_SET_RANGE,
    /// 定位到小于等于指定键的键
    set_lowerbound = c.MDBX_SET_LOWERBOUND,
    /// 定位到上一个小于指定键的键
    set_upperbound = c.MDBX_SET_UPPERBOUND,
};

/// 游标句柄
pub const Cursor = struct {
    cursor: ?*c.MDBX_cursor,

    const Self = @This();

    /// 打开游标
    pub fn open(transaction: *c.MDBX_txn, database: Env.DBI) errors.MDBXError!Self {
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
    pub fn dbi(self: *Self) Env.DBI {
        return c.mdbx_cursor_dbi(self.cursor);
    }

    /// 使用游标获取数据
    pub fn get(
        self: *Self,
        key: ?[]const u8,
        data: ?[]const u8,
        op: CursorOp,
    ) errors.MDBXError!struct { key: []const u8, data: []const u8 } {
        var key_val: c.MDBX_val = undefined;
        var data_val: c.MDBX_val = undefined;

        if (key) |k| {
            key_val = c.MDBX_val{
                .iov_base = @constCast(@ptrCast(k.ptr)),
                .iov_len = k.len,
            };
        }

        if (data) |d| {
            data_val = c.MDBX_val{
                .iov_base = @constCast(@ptrCast(d.ptr)),
                .iov_len = d.len,
            };
        }

        const key_ptr = if (key != null) &key_val else null;
        const data_ptr = if (data != null) &data_val else null;

        const rc = c.mdbx_cursor_get(self.cursor, key_ptr, data_ptr, @intFromEnum(op));
        try errors.checkError(rc);

        const result_key: [*]const u8 = @ptrCast(key_val.iov_base);
        const result_data: [*]const u8 = @ptrCast(data_val.iov_base);

        return .{
            .key = result_key[0..key_val.iov_len],
            .data = result_data[0..data_val.iov_len],
        };
    }

    /// 使用游标插入或更新数据
    pub fn put(
        self: *Self,
        key: []const u8,
        data: []const u8,
        flags: c.MDBX_put_flags_t,
    ) errors.MDBXError!void {
        var key_val = c.MDBX_val{
            .iov_base = @constCast(@ptrCast(key.ptr)),
            .iov_len = key.len,
        };
        var data_val = c.MDBX_val{
            .iov_base = @constCast(@ptrCast(data.ptr)),
            .iov_len = data.len,
        };

        const rc = c.mdbx_cursor_put(self.cursor, &key_val, &data_val, flags);
        try errors.checkError(rc);
    }

    /// 使用游标删除当前键/数据对
    pub fn del(self: *Self, flags: c.MDBX_put_flags_t) errors.MDBXError!void {
        const rc = c.mdbx_cursor_del(self.cursor, flags);
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
