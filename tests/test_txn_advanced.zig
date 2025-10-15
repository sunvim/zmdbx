// 事务高级功能测试

const std = @import("std");
const testing = std.testing;
const zmdbx = @import("zmdbx");

// 测试辅助函数：创建临时测试目录
fn createTestDir(name: []const u8) ![]const u8 {
    const allocator = testing.allocator;
    const test_dir = try std.fmt.allocPrint(allocator, "/tmp/zmdbx_test_txn_{s}", .{name});
    std.fs.cwd().makeDir(test_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };
    return test_dir;
}

// 测试辅助函数：删除测试目录
fn cleanupTestDir(path: []const u8) void {
    std.fs.cwd().deleteTree(path) catch {};
    testing.allocator.free(path);
}

// Test 1: Transaction info - 获取事务信息
test "Txn info operation" {
    const test_dir = try createTestDir("info");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    // 创建写事务并获取信息
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .{});
        try txn.put(dbi, "key1", "value1", .{});

        // 获取事务信息
        const info = try txn.info();

        // 验证事务信息的基本字段
        try testing.expect(info.txn_id > 0);  // 事务 ID 应该大于 0
        try testing.expect(info.txn_space_used > 0);  // 应该有一些空间被使用

        try txn.commit();
    }

    // 创建只读事务并获取信息
    {
        var txn = try env.beginTxn(null, .read_only);
        defer txn.abort();

        const info = try txn.info();

        // 只读事务也应该有有效的 txn_id
        try testing.expect(info.txn_id > 0);
    }
}

// Test 2: Read-only transaction reset - 重置只读事务
test "Txn reset operation (read-only)" {
    const test_dir = try createTestDir("reset");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    // 先插入一些数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .{});
        try txn.put(dbi, "key1", "value1", .{});
        try txn.commit();
    }

    // 创建只读事务
    var txn = try env.beginTxn(null, .read_only);
    defer txn.abort();

    const dbi = try txn.openDBI(null, .{});

    // 读取数据
    const value1 = try txn.get(dbi, "key1");
    try testing.expectEqualStrings("value1", value1);

    // 重置事务
    try txn.reset();

    // 重置后不能使用事务
    // 注意：这里的行为依赖于 MDBX 实现
    // 重置后的事务需要通过 renew 才能继续使用
}

// Test 3: Read-only transaction renew - 续订只读事务
test "Txn renew operation (read-only)" {
    const test_dir = try createTestDir("renew");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    // 先插入一些数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .{});
        try txn.put(dbi, "key1", "value1", .{});
        try txn.commit();
    }

    // 创建只读事务
    var txn = try env.beginTxn(null, .read_only);
    defer txn.abort();

    const dbi = try txn.openDBI(null, .{});

    // 第一次读取
    const value1 = try txn.get(dbi, "key1");
    try testing.expectEqualStrings("value1", value1);

    // 重置事务
    try txn.reset();

    // 续订事务
    try txn.renew();

    // 续订后应该可以继续使用
    const value2 = try txn.get(dbi, "key1");
    try testing.expectEqualStrings("value1", value2);
}

// Test 4: Reset and renew cycle - 测试多次重置和续订
test "Txn reset-renew cycle" {
    const test_dir = try createTestDir("reset_renew_cycle");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    // 插入初始数据
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .{});
        try txn.put(dbi, "key1", "value1", .{});
        try txn.commit();
    }

    // 创建只读事务并多次重置/续订
    var txn = try env.beginTxn(null, .read_only);
    defer txn.abort();

    const dbi = try txn.openDBI(null, .{});

    // 循环测试 3 次重置/续订
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        // 读取数据
        const value = try txn.get(dbi, "key1");
        try testing.expectEqualStrings("value1", value);

        // 重置
        try txn.reset();

        // 续订
        try txn.renew();
    }

    // 最后一次验证
    const final_value = try txn.get(dbi, "key1");
    try testing.expectEqualStrings("value1", final_value);
}

// Test 5: Mark transaction as broken - 标记事务为损坏
test "Txn markBroken operation" {
    const test_dir = try createTestDir("markbroken");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    var txn = try env.beginTxn(null, .read_write);
    // 注意：不使用 defer txn.abort()，因为我们要手动处理

    const dbi = try txn.openDBI(null, .{});
    try txn.put(dbi, "key1", "value1", .{});

    // 标记事务为损坏
    try txn.markBroken();

    // 标记为损坏后，事务应该被中止
    // 这里我们手动 abort 来清理资源
    txn.abort();

    // 验证数据没有被提交
    {
        var read_txn = try env.beginTxn(null, .read_only);
        defer read_txn.abort();

        const read_dbi = try read_txn.openDBI(null, .{});
        try testing.expectError(error.NotFound, read_txn.get(read_dbi, "key1"));
    }
}

// Test 6: Transaction with multiple operations
test "Txn complex operations sequence" {
    const test_dir = try createTestDir("complex_ops");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    // 复杂的事务操作序列
    {
        var txn = try env.beginTxn(null, .read_write);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .{});

        // 插入多条数据
        try txn.put(dbi, "key1", "value1", .{});
        try txn.put(dbi, "key2", "value2", .{});
        try txn.put(dbi, "key3", "value3", .{});

        // 获取事务信息
        const info_before = try txn.info();
        try testing.expect(info_before.txn_space_used > 0);

        // 删除一条数据
        try txn.del(dbi, "key2", null);

        // 更新一条数据
        try txn.put(dbi, "key1", "new_value1", .{});

        // 再次获取事务信息
        const info_after = try txn.info();
        try testing.expect(info_after.txn_id == info_before.txn_id);

        try txn.commit();
    }

    // 验证最终结果
    {
        var txn = try env.beginTxn(null, .read_only);
        defer txn.abort();

        const dbi = try txn.openDBI(null, .{});

        const val1 = try txn.get(dbi, "key1");
        try testing.expectEqualStrings("new_value1", val1);

        try testing.expectError(error.NotFound, txn.get(dbi, "key2"));

        const val3 = try txn.get(dbi, "key3");
        try testing.expectEqualStrings("value3", val3);
    }
}

// Test 7: Read-only transaction cannot write
test "Txn read-only write restriction" {
    const test_dir = try createTestDir("readonly_write");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    var txn = try env.beginTxn(null, .read_only);
    defer txn.abort();

    const dbi = try txn.openDBI(null, .{});

    // 尝试在只读事务中写入应该失败
    try testing.expectError(error.Eaccess, txn.put(dbi, "key1", "value1", .{}));
}

// Test 8: Nested transaction info comparison
test "Txn info changes across operations" {
    const test_dir = try createTestDir("info_changes");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    var txn = try env.beginTxn(null, .read_write);
    defer txn.abort();

    const dbi = try txn.openDBI(null, .{});

    // 获取初始信息
    const info1 = try txn.info();

    // 插入数据
    try txn.put(dbi, "key1", "value1", .{});

    // 获取插入后信息
    const info2 = try txn.info();

    // 事务 ID 应该相同
    try testing.expectEqual(info1.txn_id, info2.txn_id);

    // 使用的空间应该增加
    try testing.expect(info2.txn_space_used >= info1.txn_space_used);

    try txn.commit();
}
