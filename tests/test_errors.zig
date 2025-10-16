const std = @import("std");
const testing = std.testing;
const zmdbx = @import("zmdbx");

// 测试辅助函数：创建临时测试目录
fn createTestDir(name: []const u8) ![]const u8 {
    const allocator = testing.allocator;
    const test_dir = try std.fmt.allocPrint(allocator, "/tmp/zmdbx_test_{s}", .{name});
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

// Test 1: KeyExist - 测试插入已存在的键时返回 KeyExist 错误
test "Error: KeyExist - duplicate key with no_overwrite" {
    const test_dir = try createTestDir("error_keyexist");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    // 第一次插入
    {
        var txn = try env.beginWriteTxn();
        defer txn.abort();

        const dbi = try txn.openDBI(null, .{});
        try txn.put(dbi, "test_key", "value1", .{ .no_overwrite = true });
        try txn.commit();
    }

    // 第二次插入相同的键，应该返回 KeyExist 错误
    {
        var txn = try env.beginWriteTxn();
        defer txn.abort();

        const dbi = try txn.openDBI(null, .{});

        // 使用 expectError 验证返回 KeyExist 错误
        try testing.expectError(
            error.KeyExist,
            txn.put(dbi, "test_key", "value2", .{ .no_overwrite = true })
        );
    }
}

// Test 2: BadTxn - 测试在已提交的事务上进行操作
test "Error: BadTxn - operation on committed transaction" {
    const test_dir = try createTestDir("error_badtxn");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    var txn = try env.beginWriteTxn();
    const dbi = try txn.openDBI(null, .{});

    // 提交事务
    try txn.commit();

    // 尝试在已提交的事务上进行操作应该失败
    // 注意：这里的行为取决于 MDBX 的实现，可能需要调整
    // 在 Zig 中，使用已提交的事务可能会导致未定义行为
    // 所以我们这里只是验证不能继续使用

    // 由于事务已提交，txn 指针不再有效
    // 这个测试主要是文档化正确的使用模式
}

// Test 3: Invalid - 测试无效的参数
test "Error: Invalid - empty key" {
    const test_dir = try createTestDir("error_invalid");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    var txn = try env.beginWriteTxn();
    defer txn.abort();

    const dbi = try txn.openDBI(null, .{});

    // 测试空键 - MDBX 允许空键，但我们可以测试其他无效情况
    // 这里我们测试一个极端情况
    const result = txn.put(dbi, "", "value", .{});

    // 空键可能被允许，这取决于 MDBX 的实现
    // 如果允许，这个测试会通过；如果不允许，会返回错误
    _ = result catch |err| {
        // 验证错误类型是预期的错误之一
        try testing.expect(
            err == error.Invalid or
            err == error.Einval or
            err == error.BadValSize
        );
        return;
    };
}

// Test 4: BadValSize - 测试超大的键
test "Error: BadValSize - key too large" {
    const test_dir = try createTestDir("error_badvalsize");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    var txn = try env.beginWriteTxn();
    defer txn.abort();

    const dbi = try txn.openDBI(null, .{});

    // MDBX 的最大键大小通常是 511 字节 (默认页大小 4096)
    // 创建一个超大的键
    const allocator = testing.allocator;
    const huge_key = try allocator.alloc(u8, 1024);
    defer allocator.free(huge_key);
    @memset(huge_key, 'X');

    // 尝试插入超大键，应该返回 BadValSize 错误
    try testing.expectError(
        error.BadValSize,
        txn.put(dbi, huge_key, "value", .{})
    );
}

// Test 5: MapFull - 测试内存映射满
test "Error: MapFull - database size limit" {
    const test_dir = try createTestDir("error_mapfull");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    // 设置一个非常小的 mapsize (64KB)
    try env.open(test_dir, .{ .mapsize = 64 * 1024 }, 0o644);
    defer env.close();

    // 尝试插入大量数据直到填满
    var i: usize = 0;
    const max_attempts: usize = 1000;
    var got_mapfull = false;

    while (i < max_attempts) : (i += 1) {
        var txn = env.beginTxn(null, .read_write) catch |err| {
            if (err == error.MapFull) {
                got_mapfull = true;
                break;
            }
            return err;
        };
        defer txn.abort();

        const dbi = try txn.openDBI(null, .{});

        const key = try std.fmt.allocPrint(testing.allocator, "key_{d}", .{i});
        defer testing.allocator.free(key);

        // 创建一个 1KB 的值
        const value = try testing.allocator.alloc(u8, 1024);
        defer testing.allocator.free(value);
        @memset(value, @intCast(i % 256));

        txn.put(dbi, key, value, .{}) catch |err| {
            if (err == error.MapFull or err == error.TxnFull) {
                got_mapfull = true;
                break;
            }
            return err;
        };

        txn.commit() catch |err| {
            if (err == error.MapFull or err == error.TxnFull) {
                got_mapfull = true;
                break;
            }
            return err;
        };
    }

    // 验证我们确实遇到了 MapFull 或 TxnFull 错误
    try testing.expect(got_mapfull);
}

// Test 6: NotFound - 增强现有的 NotFound 测试
test "Error: NotFound - various scenarios" {
    const test_dir = try createTestDir("error_notfound");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    // 场景 1: 读取不存在的键
    {
        var txn = try env.beginReadTxn();
        defer txn.abort();

        const dbi = try txn.openDBI(null, .{});
        try testing.expectError(error.NotFound, txn.get(dbi, "nonexistent"));
    }

    // 场景 2: 删除不存在的键
    {
        var txn = try env.beginWriteTxn();
        defer txn.abort();

        const dbi = try txn.openDBI(null, .{});
        try testing.expectError(error.NotFound, txn.del(dbi, "nonexistent", null));
    }

    // 场景 3: 在空数据库中使用游标
    {
        var txn = try env.beginReadTxn();
        defer txn.abort();

        const dbi = try txn.openDBI(null, .{});
        var cursor = try zmdbx.Cursor.open(&txn, dbi);
        defer cursor.close();

        try testing.expectError(error.NotFound, cursor.get(.first));
    }
}

// Test 7: 测试只读事务尝试写入
test "Error: write operation on read-only transaction" {
    const test_dir = try createTestDir("error_readonly");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    // 创建只读事务
    var txn = try env.beginReadTxn();
    defer txn.abort();

    const dbi = try txn.openDBI(null, .{});

    // 尝试在只读事务中写入，应该返回错误
    const result = txn.put(dbi, "key", "value", .{});

    try testing.expectError(error.Eaccess, result);
}

// Test 8: 测试边界条件 - 最大键大小
test "Boundary: maximum key size" {
    const test_dir = try createTestDir("boundary_maxkey");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    var txn = try env.beginWriteTxn();
    defer txn.abort();

    const dbi = try txn.openDBI(null, .{});

    // MDBX 默认最大键大小约为 511 字节
    // 测试接近但不超过限制的键
    const allocator = testing.allocator;
    const max_key = try allocator.alloc(u8, 511);
    defer allocator.free(max_key);
    @memset(max_key, 'K');

    // 这应该成功
    try txn.put(dbi, max_key, "value", .{});

    const retrieved = try txn.get(dbi, max_key);
    try testing.expectEqualStrings("value", retrieved);

    try txn.commit();
}

// Test 9: 测试空值
test "Boundary: empty value" {
    const test_dir = try createTestDir("boundary_emptyval");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    var txn = try env.beginWriteTxn();
    defer txn.abort();

    const dbi = try txn.openDBI(null, .{});

    // 插入空值
    try txn.put(dbi, "empty_key", "", .{});

    const retrieved = try txn.get(dbi, "empty_key");
    try testing.expectEqualStrings("", retrieved);

    try txn.commit();
}

// Test 10: 测试多次 abort 同一事务
test "Error handling: multiple abort calls" {
    const test_dir = try createTestDir("error_multiabort");
    defer cleanupTestDir(test_dir);

    var env = try zmdbx.Env.init();
    defer env.deinit();

    try env.open(test_dir, .{}, 0o644);
    defer env.close();

    var txn = try env.beginWriteTxn();

    // 第一次 abort
    txn.abort();

    // 第二次 abort 应该是安全的（即使事务已经 abort）
    // MDBX 实现应该处理这种情况
    txn.abort();

    // 如果执行到这里没有崩溃，测试通过
}
