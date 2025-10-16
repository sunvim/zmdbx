// 环境构建器模块
//
// 提供流畅的 Builder 模式 API 来配置和创建 MDBX 环境。

const std = @import("std");
const c = @import("c.zig").c;

const errors = @import("errors.zig");
const types = @import("types.zig");
const flags = @import("flags.zig");
const Env = @import("env.zig").Env;

/// 环境构建器
///
/// 使用 Builder 模式提供流畅的 API 来配置 MDBX 环境。
///
/// 使用示例：
/// ```zig
/// var env = try EnvBuilder.init()
///     .setMaxDbs(10)
///     .setMaxReaders(126)
///     .setGeometry(.{
///         .lower = 1 << 20,    // 1MB
///         .now = 10 << 20,     // 10MB
///         .upper = 100 << 20,  // 100MB
///     })
///     .addFlag(.no_sub_dir)
///     .addFlag(.coalesce)
///     .open("/path/to/db", 0o644);
/// defer env.deinit();
/// ```
pub const EnvBuilder = struct {
    env: Env,
    flags_set: flags.EnvFlagSet,
    geometry: ?types.Geometry,
    maxdbs: ?c_uint,
    maxreaders: ?c_uint,
    sync_bytes: ?usize,
    sync_period: ?c_uint,

    const Self = @This();

    /// 创建新的环境构建器
    pub fn init() errors.MDBXError!Self {
        return .{
            .env = try Env.init(),
            .flags_set = flags.EnvFlagSet.init(.{}),
            .geometry = null,
            .maxdbs = null,
            .maxreaders = null,
            .sync_bytes = null,
            .sync_period = null,
        };
    }

    /// 设置最大数据库数量
    pub fn setMaxDbs(self: Self, maxdbs: c_uint) Self {
        var builder = self;
        builder.maxdbs = maxdbs;
        return builder;
    }

    /// 设置最大读取器数量
    pub fn setMaxReaders(self: Self, readers: c_uint) Self {
        var builder = self;
        builder.maxreaders = readers;
        return builder;
    }

    /// 设置几何参数
    pub fn setGeometry(self: Self, geo: types.Geometry) Self {
        var builder = self;
        builder.geometry = geo;
        return builder;
    }

    /// 设置同步字节阈值
    pub fn setSyncBytes(self: Self, bytes: usize) Self {
        var builder = self;
        builder.sync_bytes = bytes;
        return builder;
    }

    /// 设置同步周期（秒 * 65536）
    pub fn setSyncPeriod(self: Self, period: c_uint) Self {
        var builder = self;
        builder.sync_period = period;
        return builder;
    }

    /// 添加环境标志
    pub fn addFlag(self: Self, flag: flags.EnvFlag) Self {
        var builder = self;
        builder.flags_set.insert(flag);
        return builder;
    }

    /// 添加多个环境标志
    pub fn addFlags(self: Self, flag_set: flags.EnvFlagSet) Self {
        var builder = self;
        var iter = flag_set.iterator();
        while (iter.next()) |flag| {
            builder.flags_set.insert(flag);
        }
        return builder;
    }

    /// 打开环境并应用所有配置
    ///
    /// 这个方法会消费 builder 并返回配置好的环境。
    /// 如果发生错误，环境会被自动清理。
    pub fn open(self: Self, path: [*:0]const u8, mode: c.mdbx_mode_t) errors.MDBXError!Env {
        var env = self.env;
        errdefer env.deinit();

        // 应用几何配置
        if (self.geometry) |geo| {
            try env.setGeometry(geo);
        }

        // 应用数据库数量配置
        if (self.maxdbs) |maxdbs| {
            try env.setMaxdbs(maxdbs);
        }

        // 应用读取器数量配置
        if (self.maxreaders) |readers| {
            try env.setMaxReaders(readers);
        }

        // 应用同步配置
        if (self.sync_bytes) |bytes| {
            try env.setSyncBytes(bytes);
        }

        if (self.sync_period) |period| {
            try env.setSyncPeriod(period);
        }

        // 打开环境
        try env.open(path, self.flags_set, mode);

        return env;
    }

    /// 仅构建环境而不打开
    ///
    /// 用于需要手动控制打开时机的场景。
    /// 调用者需要负责调用 env.open()。
    pub fn build(self: Self) errors.MDBXError!Env {
        var env = self.env;
        errdefer env.deinit();

        // 应用几何配置
        if (self.geometry) |geo| {
            try env.setGeometry(geo);
        }

        // 应用数据库数量配置
        if (self.maxdbs) |maxdbs| {
            try env.setMaxdbs(maxdbs);
        }

        // 应用读取器数量配置
        if (self.maxreaders) |readers| {
            try env.setMaxReaders(readers);
        }

        // 应用同步配置
        if (self.sync_bytes) |bytes| {
            try env.setSyncBytes(bytes);
        }

        if (self.sync_period) |period| {
            try env.setSyncPeriod(period);
        }

        return env;
    }
};

// 单元测试
test "EnvBuilder basic usage" {
    const testing = std.testing;

    var builder = try EnvBuilder.init();
    _ = builder.setMaxDbs(10)
        .setMaxReaders(126)
        .addFlag(.no_sub_dir)
        .addFlag(.coalesce);

    // 验证配置已设置
    try testing.expectEqual(@as(?c_uint, 10), builder.maxdbs);
    try testing.expectEqual(@as(?c_uint, 126), builder.maxreaders);
    try testing.expect(builder.flags_set.contains(.no_sub_dir));
    try testing.expect(builder.flags_set.contains(.coalesce));

    // 清理（不打开环境）
    builder.env.deinit();
}

test "EnvBuilder with geometry" {
    const testing = std.testing;

    var builder = try EnvBuilder.init();
    _ = builder.setGeometry(.{
        .lower = 1 << 20,
        .now = 10 << 20,
        .upper = 100 << 20,
    });

    try testing.expect(builder.geometry != null);
    if (builder.geometry) |geo| {
        try testing.expectEqual(@as(isize, 1 << 20), geo.lower);
        try testing.expectEqual(@as(isize, 10 << 20), geo.now);
        try testing.expectEqual(@as(isize, 100 << 20), geo.upper);
    }

    builder.env.deinit();
}
