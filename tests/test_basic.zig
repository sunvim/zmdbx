// 基本功能单元测试

const std = @import("std");
const testing = std.testing;
const zmdbx = @import("zmdbx");

test "Env init and deinit" {
    var env = try zmdbx.Env.init();
    defer env.deinit();

    try testing.expect(env.env != null);
}

test "Env open and close" {
    const test_path = "./test_db_basic";

    // 清理测试目录
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, .defaults, 0o755);

    // 验证环境已打开
    try testing.expect(env.env != null);
}

test "Basic put and get" {
    const test_path = "./test_db_putget";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, .defaults, 0o755);

    // 写入数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);
        try txn.put(dbi, "test_key", "test_value", .upsert);
        try txn.commit();
    }

    // 读取数据
    {
        var txn = try env.beginTxn(null, .read_only);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);
        const value = try txn.get(dbi, "test_key");

        try testing.expectEqualStrings("test_value", value);
    }
}

test "Multiple puts and gets" {
    const test_path = "./test_db_multiple";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, .defaults, 0o755);

    // 写入多条数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);
        try txn.put(dbi, "key1", "value1", .upsert);
        try txn.put(dbi, "key2", "value2", .upsert);
        try txn.put(dbi, "key3", "value3", .upsert);
        try txn.commit();
    }

    // 读取并验证
    {
        var txn = try env.beginTxn(null, .read_only);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);

        const v1 = try txn.get(dbi, "key1");
        const v2 = try txn.get(dbi, "key2");
        const v3 = try txn.get(dbi, "key3");

        try testing.expectEqualStrings("value1", v1);
        try testing.expectEqualStrings("value2", v2);
        try testing.expectEqualStrings("value3", v3);
    }
}

test "Delete operation" {
    const test_path = "./test_db_delete";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, .defaults, 0o755);

    // 写入数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .create);
        try txn.put(dbi, "to_delete", "will_be_deleted", .upsert);
        try txn.commit();
    }

    // 删除数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);
        try txn.del(dbi, "to_delete", null);
        try txn.commit();
    }

    // 验证已删除
    {
        var txn = try env.beginTxn(null, .read_only);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);
        const result = txn.get(dbi, "to_delete");

        try testing.expectError(error.NotFound, result);
    }
}

test "Transaction abort" {
    const test_path = "./test_db_abort";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, .defaults, 0o755);

    // 写入但中止
    {
        var txn = try env.beginTxn(null, .read_write);
        const dbi = try txn.openDBI(null, .create);
        try txn.put(dbi, "aborted_key", "should_not_exist", .upsert);
        txn.abort(); // 显式中止，不提交
    }

    // 验证数据未写入
    {
        var txn = try env.beginTxn(null, .read_only);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .defaults);
        const result = txn.get(dbi, "aborted_key");

        try testing.expectError(error.NotFound, result);
    }
}
