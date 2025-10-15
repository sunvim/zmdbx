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
        var txn = try env.beginTxn(null, .read_only);
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

// Test: Cursor put - 使用游标插入数据
test "Cursor put operation" {
    const test_path = "./test_db_cursor_put";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, .defaults, 0o755);

    // 使用游标插入数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);
        var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
        defer cursor.close();

        // 使用游标插入多条数据
        try cursor.put("key1", "value1", .upsert);
        try cursor.put("key2", "value2", .upsert);
        try cursor.put("key3", "value3", .upsert);

        try txn.commit();
    }

    // 验证数据已插入
    {
        var txn = try env.beginTxn(null, .read_only);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);

        const val1 = try txn.get(dbi, "key1");
        try testing.expectEqualStrings("value1", val1);

        const val2 = try txn.get(dbi, "key2");
        try testing.expectEqualStrings("value2", val2);

        const val3 = try txn.get(dbi, "key3");
        try testing.expectEqualStrings("value3", val3);
    }
}

// Test: Cursor delete - 使用游标删除数据
test "Cursor delete operation" {
    const test_path = "./test_db_cursor_del";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, .defaults, 0o755);

    // 先插入数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);
        try txn.put(dbi, "key1", "value1", .upsert);
        try txn.put(dbi, "key2", "value2", .upsert);
        try txn.put(dbi, "key3", "value3", .upsert);
        try txn.commit();
    }

    // 使用游标删除数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);
        var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
        defer cursor.close();

        // 定位到 key2 并删除
        _ = try cursor.get("key2", null, .set_range);
        try cursor.del(.current);

        try txn.commit();
    }

    // 验证 key2 已删除，其他键仍存在
    {
        var txn = try env.beginTxn(null, .read_only);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);

        _ = try txn.get(dbi, "key1");  // 应该存在
        try testing.expectError(error.NotFound, txn.get(dbi, "key2"));  // 已删除
        _ = try txn.get(dbi, "key3");  // 应该存在
    }
}

// Test: Cursor count - 统计重复键的数量
test "Cursor count operation" {
    const test_path = "./test_db_cursor_count";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, .defaults, 0o755);

    // 在常规数据库中，每个键只有一个值，count 应该返回 1
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);
        try txn.put(dbi, "key1", "value1", .upsert);
        try txn.commit();
    }

    {
        var txn = try env.beginTxn(null, .read_only);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);
        var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
        defer cursor.close();

        _ = try cursor.get("key1", null, .set_range);
        const count = try cursor.count();
        try testing.expectEqual(@as(usize, 1), count);
    }
}

// Test: Cursor eof - 检查是否到达末尾
test "Cursor eof check" {
    const test_path = "./test_db_cursor_eof";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, .defaults, 0o755);

    // 插入数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);
        try txn.put(dbi, "key1", "value1", .upsert);
        try txn.commit();
    }

    {
        var txn = try env.beginTxn(null, .read_only);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);
        var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
        defer cursor.close();

        // 定位到第一条记录
        _ = try cursor.get(null, null, .first);
        try testing.expect(!cursor.eof());  // 不在 EOF

        // 尝试移到下一条（不存在）
        _ = cursor.get(null, null, .next) catch {};
        try testing.expect(cursor.eof());  // 现在在 EOF
    }
}

// Test: Cursor onFirst - 检查是否在第一条记录
test "Cursor onFirst check" {
    const test_path = "./test_db_cursor_onfirst";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, .defaults, 0o755);

    // 插入多条数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);
        try txn.put(dbi, "key1", "value1", .upsert);
        try txn.put(dbi, "key2", "value2", .upsert);
        try txn.commit();
    }

    {
        var txn = try env.beginTxn(null, .read_only);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);
        var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
        defer cursor.close();

        // 定位到第一条
        _ = try cursor.get(null, null, .first);
        try testing.expect(cursor.onFirst());  // 在第一条

        // 移到下一条
        _ = try cursor.get(null, null, .next);
        try testing.expect(!cursor.onFirst());  // 不在第一条
    }
}

// Test: Cursor onLast - 检查是否在最后一条记录
test "Cursor onLast check" {
    const test_path = "./test_db_cursor_onlast";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, .defaults, 0o755);

    // 插入多条数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);
        try txn.put(dbi, "key1", "value1", .upsert);
        try txn.put(dbi, "key2", "value2", .upsert);
        try txn.commit();
    }

    {
        var txn = try env.beginTxn(null, .read_only);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);
        var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
        defer cursor.close();

        // 定位到最后一条
        _ = try cursor.get(null, null, .last);
        try testing.expect(cursor.onLast());  // 在最后一条

        // 移到前一条
        _ = try cursor.get(null, null, .prev);
        try testing.expect(!cursor.onLast());  // 不在最后一条
    }
}

// Test: Cursor renew - 续订游标
test "Cursor renew operation" {
    const test_path = "./test_db_cursor_renew";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, .defaults, 0o755);

    // 插入数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);
        try txn.put(dbi, "key1", "value1", .upsert);
        try txn.commit();
    }

    // 创建只读事务和游标
    var txn = try env.beginTxn(null, .read_only);
    defer txn.abort();

    const dbi = try txn.openDBI(null, .defaults);
    var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
    defer cursor.close();

    // 使用游标
    _ = try cursor.get(null, null, .first);

    // 续订游标到新事务
    var new_txn = try env.beginTxn(null, .read_only);
    defer new_txn.abort();

    try cursor.renew(new_txn.txn.?);

    // 验证游标可以继续使用
    const result = try cursor.get(null, null, .first);
    try testing.expectEqualStrings("key1", result.key);
}

// Test: Cursor txn and dbi - 获取关联的事务和数据库句柄
test "Cursor txn and dbi accessors" {
    const test_path = "./test_db_cursor_accessors";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, .defaults, 0o755);

    var txn = try env.beginTxn(null, .read_write);
    defer txn.abort();

    const dbi = try txn.openDBI(null, .create);
    var cursor = try zmdbx.Cursor.open(txn.txn.?, dbi);
    defer cursor.close();

    // 获取游标关联的事务
    const cursor_txn = cursor.txn();
    try testing.expect(cursor_txn == txn.txn.?);

    // 获取游标关联的 DBI
    const cursor_dbi = cursor.dbi();
    try testing.expectEqual(dbi, cursor_dbi);
}
