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

    // ==================== 类型化便捷方法 ====================
    // 以下方法提供类型安全的游标操作，自动处理类型转换

    // ---------- 有符号整数类型 ----------

    /// 使用游标获取i8类型的数据
    pub inline fn get_i8(self: *Self, key: ?[]const u8, data: ?[]const u8, op: CursorOp) errors.MDBXError!struct { key: []const u8, data: i8 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_i8(),
        };
    }

    /// 使用游标存储i8类型的数据
    pub inline fn put_i8(self: *Self, key: []const u8, value: i8, flags_set: PutFlagSet) errors.MDBXError!void {
        const val = Val.from_i8(value);
        return self.put(key, val.toBytes(), flags_set);
    }

    /// 使用游标获取i16类型的数据
    pub inline fn get_i16(self: *Self, key: ?[]const u8, data: ?[]const u8, op: CursorOp) errors.MDBXError!struct { key: []const u8, data: i16 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_i16(),
        };
    }

    /// 使用游标存储i16类型的数据
    pub inline fn put_i16(self: *Self, key: []const u8, value: i16, flags_set: PutFlagSet) errors.MDBXError!void {
        const val = Val.from_i16(value);
        return self.put(key, val.toBytes(), flags_set);
    }

    /// 使用游标获取i32类型的数据
    pub inline fn get_i32(self: *Self, key: ?[]const u8, data: ?[]const u8, op: CursorOp) errors.MDBXError!struct { key: []const u8, data: i32 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_i32(),
        };
    }

    /// 使用游标存储i32类型的数据
    pub inline fn put_i32(self: *Self, key: []const u8, value: i32, flags_set: PutFlagSet) errors.MDBXError!void {
        const val = Val.from_i32(value);
        return self.put(key, val.toBytes(), flags_set);
    }

    /// 使用游标获取i64类型的数据
    pub inline fn get_i64(self: *Self, key: ?[]const u8, data: ?[]const u8, op: CursorOp) errors.MDBXError!struct { key: []const u8, data: i64 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_i64(),
        };
    }

    /// 使用游标存储i64类型的数据
    pub inline fn put_i64(self: *Self, key: []const u8, value: i64, flags_set: PutFlagSet) errors.MDBXError!void {
        const val = Val.from_i64(value);
        return self.put(key, val.toBytes(), flags_set);
    }

    /// 使用游标获取i128类型的数据
    pub inline fn get_i128(self: *Self, key: ?[]const u8, data: ?[]const u8, op: CursorOp) errors.MDBXError!struct { key: []const u8, data: i128 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_i128(),
        };
    }

    /// 使用游标存储i128类型的数据
    pub inline fn put_i128(self: *Self, key: []const u8, value: i128, flags_set: PutFlagSet) errors.MDBXError!void {
        const val = Val.from_i128(value);
        return self.put(key, val.toBytes(), flags_set);
    }

    // ---------- 无符号整数类型 ----------

    /// 使用游标获取u8类型的数据
    pub inline fn get_u8(self: *Self, key: ?[]const u8, data: ?[]const u8, op: CursorOp) errors.MDBXError!struct { key: []const u8, data: u8 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_u8(),
        };
    }

    /// 使用游标存储u8类型的数据
    pub inline fn put_u8(self: *Self, key: []const u8, value: u8, flags_set: PutFlagSet) errors.MDBXError!void {
        const val = Val.from_u8(value);
        return self.put(key, val.toBytes(), flags_set);
    }

    /// 使用游标获取u16类型的数据
    pub inline fn get_u16(self: *Self, key: ?[]const u8, data: ?[]const u8, op: CursorOp) errors.MDBXError!struct { key: []const u8, data: u16 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_u16(),
        };
    }

    /// 使用游标存储u16类型的数据
    pub inline fn put_u16(self: *Self, key: []const u8, value: u16, flags_set: PutFlagSet) errors.MDBXError!void {
        const val = Val.from_u16(value);
        return self.put(key, val.toBytes(), flags_set);
    }

    /// 使用游标获取u32类型的数据
    pub inline fn get_u32(self: *Self, key: ?[]const u8, data: ?[]const u8, op: CursorOp) errors.MDBXError!struct { key: []const u8, data: u32 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_u32(),
        };
    }

    /// 使用游标存储u32类型的数据
    pub inline fn put_u32(self: *Self, key: []const u8, value: u32, flags_set: PutFlagSet) errors.MDBXError!void {
        const val = Val.from_u32(value);
        return self.put(key, val.toBytes(), flags_set);
    }

    /// 使用游标获取u64类型的数据
    pub inline fn get_u64(self: *Self, key: ?[]const u8, data: ?[]const u8, op: CursorOp) errors.MDBXError!struct { key: []const u8, data: u64 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_u64(),
        };
    }

    /// 使用游标存储u64类型的数据
    pub inline fn put_u64(self: *Self, key: []const u8, value: u64, flags_set: PutFlagSet) errors.MDBXError!void {
        const val = Val.from_u64(value);
        return self.put(key, val.toBytes(), flags_set);
    }

    /// 使用游标获取u128类型的数据
    pub inline fn get_u128(self: *Self, key: ?[]const u8, data: ?[]const u8, op: CursorOp) errors.MDBXError!struct { key: []const u8, data: u128 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_u128(),
        };
    }

    /// 使用游标存储u128类型的数据
    pub inline fn put_u128(self: *Self, key: []const u8, value: u128, flags_set: PutFlagSet) errors.MDBXError!void {
        const val = Val.from_u128(value);
        return self.put(key, val.toBytes(), flags_set);
    }

    // ---------- 浮点数类型 ----------

    /// 使用游标获取f16类型的数据
    pub inline fn get_f16(self: *Self, key: ?[]const u8, data: ?[]const u8, op: CursorOp) errors.MDBXError!struct { key: []const u8, data: f16 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_f16(),
        };
    }

    /// 使用游标存储f16类型的数据
    pub inline fn put_f16(self: *Self, key: []const u8, value: f16, flags_set: PutFlagSet) errors.MDBXError!void {
        const val = Val.from_f16(value);
        return self.put(key, val.toBytes(), flags_set);
    }

    /// 使用游标获取f32类型的数据
    pub inline fn get_f32(self: *Self, key: ?[]const u8, data: ?[]const u8, op: CursorOp) errors.MDBXError!struct { key: []const u8, data: f32 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_f32(),
        };
    }

    /// 使用游标存储f32类型的数据
    pub inline fn put_f32(self: *Self, key: []const u8, value: f32, flags_set: PutFlagSet) errors.MDBXError!void {
        const val = Val.from_f32(value);
        return self.put(key, val.toBytes(), flags_set);
    }

    /// 使用游标获取f64类型的数据
    pub inline fn get_f64(self: *Self, key: ?[]const u8, data: ?[]const u8, op: CursorOp) errors.MDBXError!struct { key: []const u8, data: f64 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_f64(),
        };
    }

    /// 使用游标存储f64类型的数据
    pub inline fn put_f64(self: *Self, key: []const u8, value: f64, flags_set: PutFlagSet) errors.MDBXError!void {
        const val = Val.from_f64(value);
        return self.put(key, val.toBytes(), flags_set);
    }

    /// 使用游标获取f80类型的数据
    pub inline fn get_f80(self: *Self, key: ?[]const u8, data: ?[]const u8, op: CursorOp) errors.MDBXError!struct { key: []const u8, data: f80 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_f80(),
        };
    }

    /// 使用游标存储f80类型的数据
    pub inline fn put_f80(self: *Self, key: []const u8, value: f80, flags_set: PutFlagSet) errors.MDBXError!void {
        const val = Val.from_f80(value);
        return self.put(key, val.toBytes(), flags_set);
    }

    /// 使用游标获取f128类型的数据
    pub inline fn get_f128(self: *Self, key: ?[]const u8, data: ?[]const u8, op: CursorOp) errors.MDBXError!struct { key: []const u8, data: f128 } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_f128(),
        };
    }

    /// 使用游标存储f128类型的数据
    pub inline fn put_f128(self: *Self, key: []const u8, value: f128, flags_set: PutFlagSet) errors.MDBXError!void {
        const val = Val.from_f128(value);
        return self.put(key, val.toBytes(), flags_set);
    }

    /// 使用游标获取c_longdouble类型的数据
    pub inline fn get_c_longdouble(self: *Self, key: ?[]const u8, data: ?[]const u8, op: CursorOp) errors.MDBXError!struct { key: []const u8, data: c_longdouble } {
        const result = try self.get(key, data, op);
        return .{
            .key = result.key.toBytes(),
            .data = try result.data.to_c_longdouble(),
        };
    }

    /// 使用游标存储c_longdouble类型的数据
    pub inline fn put_c_longdouble(self: *Self, key: []const u8, value: c_longdouble, flags_set: PutFlagSet) errors.MDBXError!void {
        const val = Val.from_c_longdouble(value);
        return self.put(key, val.toBytes(), flags_set);
    }
};
