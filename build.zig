const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // This creates a "module", which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Every executable or library we compile will be based on one or more modules.
    const lib = b.addLibrary(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .name = "zmdbx",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/mdbx.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    lib.addCSourceFile(.{
        .file = b.path("mdbx/mdbx.c"),
        .flags = &.{
            "-DMDBX_BUILD_SHARED_LIBRARY=0",
            "-DMDBX_BUILD_FLAGS=\"\"",
            "-DMDBX_DEBUG=0",
            "-DNDEBUG=1",
            "-DMDBX_UNALIGNED_OK=0", // 禁用未对齐访问以避免 macOS 崩溃
            "-std=c11",
            "-Wno-unknown-pragmas",
            "-Wno-expansion-to-defined",
            "-Wno-date-time",
            "-fno-strict-aliasing",
            "-fvisibility=hidden",
        },
    });

    lib.addIncludePath(b.path("mdbx"));
    lib.linkLibC(); // 链接 C 标准库以提供 errno.h 等头文件

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/mdbx.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    lib_unit_tests.addCSourceFile(.{
        .file = b.path("mdbx/mdbx.c"),
        .flags = &.{
            "-DMDBX_BUILD_SHARED_LIBRARY=0",
            "-DMDBX_BUILD_FLAGS=\"\"",
            "-DMDBX_DEBUG=0",
            "-DNDEBUG=1",
            "-DMDBX_UNALIGNED_OK=0", // 禁用未对齐访问以避免 macOS 崩溃
            "-std=c11",
            "-Wno-unknown-pragmas",
            "-Wno-expansion-to-defined",
            "-Wno-date-time",
            "-fno-strict-aliasing",
            "-fvisibility=hidden",
        },
    });
    lib_unit_tests.addIncludePath(b.path("mdbx"));
    lib_unit_tests.linkLibC(); // 链接 C 标准库

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // 添加 benchmark 可执行文件
    const bench_exe = b.addExecutable(.{
        .name = "bench_performance",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/bench_performance.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // 为 benchmark 添加 zmdbx 模块依赖
    // 使用 lib.root_module 以确保 @cImport 的类型一致性
    bench_exe.root_module.addImport("zmdbx", lib.root_module);

    // 链接到已编译的 zmdbx 库，而不是重复编译 mdbx.c
    bench_exe.linkLibrary(lib);

    // 安装 benchmark 可执行文件
    b.installArtifact(bench_exe);

    // 创建运行 benchmark 的步骤
    const run_bench = b.addRunArtifact(bench_exe);
    run_bench.step.dependOn(b.getInstallStep());

    // 如果用户传递了参数，转发给 benchmark
    if (b.args) |args| {
        run_bench.addArgs(args);
    }

    // 创建 bench step
    const bench_step = b.step("bench", "Run performance benchmarks");
    bench_step.dependOn(&run_bench.step);

    // 添加同步模式对比测试
    const bench_sync_exe = b.addExecutable(.{
        .name = "bench_sync_modes",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/bench_sync_modes.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    bench_sync_exe.root_module.addImport("zmdbx", lib.root_module);
    bench_sync_exe.linkLibrary(lib);
    b.installArtifact(bench_sync_exe);

    const run_bench_sync = b.addRunArtifact(bench_sync_exe);
    run_bench_sync.step.dependOn(b.getInstallStep());

    const bench_sync_step = b.step("bench-sync", "Run sync mode comparison benchmarks");
    bench_sync_step.dependOn(&run_bench_sync.step);

    // 添加事务模式对比测试
    const bench_txn_exe = b.addExecutable(.{
        .name = "bench_transaction_patterns",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/bench_transaction_patterns.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    bench_txn_exe.root_module.addImport("zmdbx", lib.root_module);
    bench_txn_exe.linkLibrary(lib);
    b.installArtifact(bench_txn_exe);

    const run_bench_txn = b.addRunArtifact(bench_txn_exe);
    run_bench_txn.step.dependOn(b.getInstallStep());

    const bench_txn_step = b.step("bench-txn", "Run transaction pattern benchmarks");
    bench_txn_step.dependOn(&run_bench_txn.step);
}
