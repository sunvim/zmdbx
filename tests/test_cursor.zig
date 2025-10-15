// 游标功能测试

const std = @import("std");
const testing = std.testing;
const zmdbx = @import("zmdbx");

test "Cursor basic iteration" {
    const test_path = "./test_db_cursor";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, .defaults, 0o755);

    // 写入测试数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);
        try txn.put(dbi, "a", "1", .upsert);
        try txn.put(dbi, "b", "2", .upsert);
        try txn.put(dbi, "c", "3", .upsert);
        try txn.commit();
    }

    // 使用游标遍历
    {
        var txn = try env.beginTxn(null, .read_only);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);
        var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
        defer cursor.close();

        // 第一条记录
        var result = try cursor.get(null, null, .first);
        try testing.expectEqualStrings("a", result.key);
        try testing.expectEqualStrings("1", result.data);

        // 下一条
        result = try cursor.get(null, null, .next);
        try testing.expectEqualStrings("b", result.key);
        try testing.expectEqualStrings("2", result.data);

        // 再下一条
        result = try cursor.get(null, null, .next);
        try testing.expectEqualStrings("c", result.key);
        try testing.expectEqualStrings("3", result.data);

        // 已到末尾
        const end_result = cursor.get(null, null, .next);
        try testing.expectError(error.NotFound, end_result);
    }
}

test "Cursor set_range" {
    const test_path = "./test_db_cursor_range";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, .defaults, 0o755);

    // 写入测试数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);
        try txn.put(dbi, "key001", "a", .upsert);
        try txn.put(dbi, "key005", "b", .upsert);
        try txn.put(dbi, "key010", "c", .upsert);
        try txn.commit();
    }

    // 查找 >= key005 的记录
    {
        var txn = try env.beginTxn(null, .read_only);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);
        var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
        defer cursor.close();

        var result = try cursor.get("key005", null, .set_range);
        try testing.expectEqualStrings("key005", result.key);
        try testing.expectEqualStrings("b", result.data);
    }
}

test "Cursor last and prev" {
    const test_path = "./test_db_cursor_rev";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, .defaults, 0o755);

    // 写入测试数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);
        try txn.put(dbi, "1", "a", .upsert);
        try txn.put(dbi, "2", "b", .upsert);
        try txn.put(dbi, "3", "c", .upsert);
        try txn.commit();
    }

    // 从后向前遍历
    {
        var txn = try zmdbx.beginTxn(null, .read_only);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);
        var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
        defer cursor.close();

        // 最后一条
        var result = try cursor.get(null, null, .last);
        try testing.expectEqualStrings("3", result.key);

        // 前一条
        result = try cursor.get(null, null, .prev);
        try testing.expectEqualStrings("2", result.key);

        // 再前一条
        result = try cursor.get(null, null, .prev);
        try testing.expectEqualStrings("1", result.key);
    }
}
