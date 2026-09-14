const std = @import("std");

/// libmdbx 的 C 编译选项。
/// Zig 0.16 起，C 源文件 / include path / libc 链接都挂在 `std.Build.Module` 上，
/// 不再由 `std.Build.Step.Compile` 持有，因此这里把它抽成一个函数复用。
const mdbx_c_flags = &.{
    "-DMDBX_BUILD_SHARED_LIBRARY=0",
    "-DMDBX_BUILD_FLAGS=\"\"",
    "-DMDBX_DEBUG=0",
    "-DNDEBUG=1",
    "-DMDBX_UNALIGNED_OK=0", // 禁用未对齐访问，使用 memcpy 替代
    "-DMDBX_HAVE_BUILTIN_CPU_SUPPORTS=0", // 禁用运行时 CPU 特性检测，避免 AVX-512/AVX2/SSE2 依赖
    "-std=c11",
    "-Wno-unknown-pragmas",
    "-Wno-expansion-to-defined",
    "-Wno-date-time",
    "-fno-strict-aliasing",
    "-fvisibility=hidden",
    "-fno-sanitize=undefined", // 禁用 C 代码的未定义行为检查（包括对齐检查）
    // 性能优化选项
    "-O3", // 最高级别优化
    "-march=native", // 针对本地CPU优化
    "-mtune=native", // 针对本地CPU调优
    "-fomit-frame-pointer", // 省略栈帧指针
    "-funroll-loops", // 循环展开
    "-finline-functions", // 内联函数
};

/// 把一个 module 配置成「Zig 绑定 + 内嵌编译 libmdbx C 源码」的形态。
fn addMdbxSources(b: *std.Build, module: *std.Build.Module) void {
    module.addCSourceFile(.{
        .file = b.path("mdbx/mdbx.c"),
        .flags = mdbx_c_flags,
    });
    module.addIncludePath(b.path("mdbx"));
    module.link_libc = true; // 链接 C 标准库以提供 errno.h 等头文件
}

/// 创建一个以 src/mdbx.zig 为入口、内嵌 libmdbx 的模块。
fn createZmdbxModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = b.path("src/mdbx.zig"),
        .target = target,
        .optimize = optimize,
    });
    addMdbxSources(b, module);
    return module;
}

/// 创建一个以 `path` 为入口的模块，并把 `@import("zmdbx")` 指向本库
/// （用于 tests/ 与 examples/ 下的独立文件）。
///
/// 注意：`lib.root_module` 本身就带着 mdbx.c、include path 与 libc 链接，
/// `addImport` 会把它们全部带进消费者模块，所以消费者**不需要**再
/// `linkLibrary(lib)` —— 那会让 mdbx.c 同时出现在可执行文件和静态库里，
/// 多做一遍链接（冷构建实测约慢 17%），而静态库那份是死代码。
fn createConsumerModule(
    b: *std.Build,
    path: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    lib: *std.Build.Step.Compile,
) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = b.path(path),
        .target = target,
        .optimize = optimize,
    });
    module.addImport("zmdbx", lib.root_module);
    return module;
}

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
        .name = "zmdbx",
        .linkage = .static,
        .root_module = createZmdbxModule(b, target, optimize),
    });

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_module = createZmdbxModule(b, target, optimize),
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // tests/ 下的独立单元测试文件（各自带 runtime 测试用例）。
    const unit_test_files = [_][]const u8{
        "tests/test_basic.zig",
        "tests/test_cursor.zig",
        "tests/test_errors.zig",
        "tests/test_txn_advanced.zig",
        "tests/test_val_typed.zig",
        "tests/util.zig",
    };

    inline for (unit_test_files) |path| {
        const unit_tests = b.addTest(.{
            .root_module = createConsumerModule(b, path, target, optimize, lib),
        });
        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }

    // Benchmark / 对比测试：统一走这个 helper，避免每个都重复 4 行样板。
    const BenchSpec = struct {
        name: []const u8,
        step_name: []const u8,
        description: []const u8,
    };

    const bench_all_step = b.step("bench-all", "Run every benchmark in sequence (ReleaseFast recommended)");

    const benches = [_]BenchSpec{
        .{
            .name = "bench_performance",
            .step_name = "bench",
            .description = "Run performance benchmarks",
        },
        .{
            .name = "bench_sync_modes",
            .step_name = "bench-sync",
            .description = "Run sync mode comparison benchmarks",
        },
        .{
            .name = "bench_transaction_patterns",
            .step_name = "bench-txn",
            .description = "Run transaction pattern benchmarks",
        },
        .{
            .name = "bench_sync_modes_optimized",
            .step_name = "bench-sync-opt",
            .description = "Run optimized sync mode comparison benchmarks",
        },
    };

    inline for (benches) |spec| {
        const exe = b.addExecutable(.{
            .name = spec.name,
            // 只通过 `@import("zmdbx")` 复用 lib 的 module：module 本身就是
            // 「Zig 绑定 + mdbx.c + include path + libc」，import 会把它们全部
            // 带进本可执行文件。再额外 `linkLibrary(lib)` 会让 mdbx.c 同时进入
            // 可执行文件与静态库（命令行里出现两次，白多一遍链接），所以这里不再
            // 链静态库。
            .root_module = createConsumerModule(
                b,
                b.fmt("tests/{s}.zig", .{spec.name}),
                target,
                optimize,
                lib,
            ),
        });

        b.installArtifact(exe);

        const run_bench = b.addRunArtifact(exe);
        run_bench.step.dependOn(b.getInstallStep());

        // 如果用户传递了参数，转发给 benchmark
        if (b.args) |args| {
            run_bench.addArgs(args);
        }

        const bench_step = b.step(spec.step_name, spec.description);
        bench_step.dependOn(&run_bench.step);
        bench_all_step.dependOn(&run_bench.step);
    }

    // Examples：每个示例一个 executable，同时提供 `run-*` 步骤。
    const ExampleSpec = struct {
        name: []const u8,
        step_name: []const u8,
        description: []const u8,
    };

    const examples = [_]ExampleSpec{
        .{ .name = "basic_usage", .step_name = "run-basic", .description = "Run basic usage example" },
        .{ .name = "cursor_usage", .step_name = "run-cursor", .description = "Run cursor usage example" },
        .{ .name = "batch_operations", .step_name = "run-batch", .description = "Run batch operations example" },
        .{ .name = "high_performance_config", .step_name = "run-perf", .description = "Run high performance config example" },
    };

    inline for (examples) |spec| {
        const exe = b.addExecutable(.{
            .name = spec.name,
            .root_module = createConsumerModule(
                b,
                b.fmt("examples/{s}.zig", .{spec.name}),
                target,
                optimize,
                lib,
            ),
        });

        b.installArtifact(exe);

        const run_example = b.addRunArtifact(exe);
        run_example.step.dependOn(b.getInstallStep());
        if (b.args) |args| run_example.addArgs(args);

        const example_step = b.step(spec.step_name, spec.description);
        example_step.dependOn(&run_example.step);
    }

    // 清理构建产物。
    const clean_step = b.step("clean", "Remove .zig-cache and zig-out");
    const clean = b.addSystemCommand(&.{ "rm", "-rf", ".zig-cache", "zig-out" });
    clean_step.dependOn(&clean.step);
}
