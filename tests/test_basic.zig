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

    try env.open(test_path, zmdbx.EnvFlagSet.init(.{}), 0o755);

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
        var txn = try env.beginWriteTxn();
        defer txn.abort();

        var db_flags = zmdbx.DBFlagSet.init(.{});
        db_flags.insert(.create);
        const dbi = try txn.openDBI(null, db_flags);
        try txn.put(dbi, "test_key", "test_value", zmdbx.PutFlagSet.init(.{}));
        try txn.commit();
    }

    // 读取数据
    {
        var txn = try env.beginReadTxn();
        defer txn.abort();

        const dbi = try txn.openDBI(null, zmdbx.DBFlagSet.init(.{}));
        const value = try txn.getBytes(dbi, "test_key");

        try testing.expectEqualStrings("test_value", value);
    }
}

test "Multiple puts and gets" {
    const test_path = "./test_db_multiple";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, zmdbx.EnvFlagSet.init(.{}), 0o755);

    // 写入多条数据
    {
        var txn = try env.beginWriteTxn();
        defer txn.abort();

        var db_flags = zmdbx.DBFlagSet.init(.{});
        db_flags.insert(.create);
        const dbi = try txn.openDBI(null, db_flags);
        const put_flags = zmdbx.PutFlagSet.init(.{});
        try txn.put(dbi, "key1", "value1", put_flags);
        try txn.put(dbi, "key2", "value2", put_flags);
        try txn.put(dbi, "key3", "value3", put_flags);
        try txn.commit();
    }

    // 读取并验证
    {
        var txn = try env.beginReadTxn();
        defer txn.abort();

        const dbi = try txn.openDBI(null, zmdbx.DBFlagSet.init(.{}));

        const v1 = try txn.getBytes(dbi, "key1");
        const v2 = try txn.getBytes(dbi, "key2");
        const v3 = try txn.getBytes(dbi, "key3");

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

    try env.open(test_path, zmdbx.EnvFlagSet.init(.{}), 0o755);

    // 写入数据
    {
        var txn = try env.beginWriteTxn();
        defer txn.abort();

        var db_flags = zmdbx.DBFlagSet.init(.{});
        db_flags.insert(.create);
        const dbi = try txn.openDBI(null, db_flags);
        try txn.put(dbi, "to_delete", "will_be_deleted", zmdbx.PutFlagSet.init(.{}));
        try txn.commit();
    }

    // 删除数据
    {
        var txn = try env.beginWriteTxn();
        defer txn.abort();

        const dbi = try txn.openDBI(null, zmdbx.DBFlagSet.init(.{}));
        try txn.del(dbi, "to_delete", null);
        try txn.commit();
    }

    // 验证已删除
    {
        var txn = try env.beginReadTxn();
        defer txn.abort();

        const dbi = try txn.openDBI(null, zmdbx.DBFlagSet.init(.{}));
        const result = txn.getBytes(dbi, "to_delete");

        try testing.expectError(error.NotFound, result);
    }
}

test "Transaction abort" {
    const test_path = "./test_db_abort";
    std.fs.cwd().deleteTree(test_path) catch {};

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_path, zmdbx.EnvFlagSet.init(.{}), 0o755);

    // 写入但中止
    {
        var txn = try env.beginWriteTxn();
        var db_flags = zmdbx.DBFlagSet.init(.{});
        db_flags.insert(.create);
        const dbi = try txn.openDBI(null, db_flags);
        try txn.put(dbi, "aborted_key", "should_not_exist", zmdbx.PutFlagSet.init(.{}));
        txn.abort(); // 显式中止，不提交
    }

    // 验证数据未写入
    {
        var txn = try env.beginReadTxn();
        defer txn.abort();

        const dbi = try txn.openDBI(null, zmdbx.DBFlagSet.init(.{}));
        const result = txn.getBytes(dbi, "aborted_key");

        try testing.expectError(error.NotFound, result);
    }
}
