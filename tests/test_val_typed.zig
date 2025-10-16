// Val类型化API测试
// 测试Val的from_TYPE()和to_TYPE()方法

const std = @import("std");
const testing = std.testing;
const zmdbx = @import("zmdbx");
const Val = zmdbx.Val;

// ==================== 有符号整数测试 ====================

test "Val.from_i8 and to_i8" {
    const value: i8 = -128;
    const val = Val.from_i8(value);
    const result = try val.to_i8();
    try testing.expectEqual(value, result);
}

test "Val.from_i8 and to_i8 - positive" {
    const value: i8 = 127;
    const val = Val.from_i8(value);
    const result = try val.to_i8();
    try testing.expectEqual(value, result);
}

test "Val.from_i8 and to_i8 - zero" {
    const value: i8 = 0;
    const val = Val.from_i8(value);
    const result = try val.to_i8();
    try testing.expectEqual(value, result);
}

test "Val.from_i16 and to_i16" {
    const value: i16 = -32768;
    const val = Val.from_i16(value);
    const result = try val.to_i16();
    try testing.expectEqual(value, result);
}

test "Val.from_i16 and to_i16 - positive" {
    const value: i16 = 32767;
    const val = Val.from_i16(value);
    const result = try val.to_i16();
    try testing.expectEqual(value, result);
}

test "Val.from_i32 and to_i32" {
    const value: i32 = -2147483648;
    const val = Val.from_i32(value);
    const result = try val.to_i32();
    try testing.expectEqual(value, result);
}

test "Val.from_i32 and to_i32 - positive" {
    const value: i32 = 2147483647;
    const val = Val.from_i32(value);
    const result = try val.to_i32();
    try testing.expectEqual(value, result);
}

test "Val.from_i64 and to_i64" {
    const value: i64 = -9223372036854775808;
    const val = Val.from_i64(value);
    const result = try val.to_i64();
    try testing.expectEqual(value, result);
}

test "Val.from_i64 and to_i64 - positive" {
    const value: i64 = 9223372036854775807;
    const val = Val.from_i64(value);
    const result = try val.to_i64();
    try testing.expectEqual(value, result);
}

test "Val.from_i128 and to_i128" {
    const value: i128 = -170141183460469231731687303715884105728;
    const val = Val.from_i128(value);
    const result = try val.to_i128();
    try testing.expectEqual(value, result);
}

test "Val.from_i128 and to_i128 - positive" {
    const value: i128 = 170141183460469231731687303715884105727;
    const val = Val.from_i128(value);
    const result = try val.to_i128();
    try testing.expectEqual(value, result);
}

// ==================== 无符号整数测试 ====================

test "Val.from_u8 and to_u8" {
    const value: u8 = 255;
    const val = Val.from_u8(value);
    const result = try val.to_u8();
    try testing.expectEqual(value, result);
}

test "Val.from_u8 and to_u8 - zero" {
    const value: u8 = 0;
    const val = Val.from_u8(value);
    const result = try val.to_u8();
    try testing.expectEqual(value, result);
}

test "Val.from_u16 and to_u16" {
    const value: u16 = 65535;
    const val = Val.from_u16(value);
    const result = try val.to_u16();
    try testing.expectEqual(value, result);
}

test "Val.from_u16 and to_u16 - mid" {
    const value: u16 = 32768;
    const val = Val.from_u16(value);
    const result = try val.to_u16();
    try testing.expectEqual(value, result);
}

test "Val.from_u32 and to_u32" {
    const value: u32 = 4294967295;
    const val = Val.from_u32(value);
    const result = try val.to_u32();
    try testing.expectEqual(value, result);
}

test "Val.from_u32 and to_u32 - mid" {
    const value: u32 = 2147483648;
    const val = Val.from_u32(value);
    const result = try val.to_u32();
    try testing.expectEqual(value, result);
}

test "Val.from_u64 and to_u64" {
    const value: u64 = 18446744073709551615;
    const val = Val.from_u64(value);
    const result = try val.to_u64();
    try testing.expectEqual(value, result);
}

test "Val.from_u64 and to_u64 - mid" {
    const value: u64 = 9223372036854775808;
    const val = Val.from_u64(value);
    const result = try val.to_u64();
    try testing.expectEqual(value, result);
}

test "Val.from_u128 and to_u128" {
    const value: u128 = 340282366920938463463374607431768211455;
    const val = Val.from_u128(value);
    const result = try val.to_u128();
    try testing.expectEqual(value, result);
}

test "Val.from_u128 and to_u128 - mid" {
    const value: u128 = 170141183460469231731687303715884105728;
    const val = Val.from_u128(value);
    const result = try val.to_u128();
    try testing.expectEqual(value, result);
}

// ==================== 错误情况测试 ====================

test "Val.to_i32 with wrong length - error" {
    // 创建一个i8的Val，尝试转换为i32应该失败
    const value: i8 = 42;
    const val = Val.from_i8(value);
    const result = val.to_i32();
    try testing.expectError(error.InvalidDataLength, result);
}

test "Val.to_u64 with wrong length - error" {
    // 创建一个u16的Val，尝试转换为u64应该失败
    const value: u16 = 1000;
    const val = Val.from_u16(value);
    const result = val.to_u64();
    try testing.expectError(error.InvalidDataLength, result);
}

test "Val.to_i128 with empty Val - error" {
    const val = Val.empty();
    const result = val.to_i128();
    try testing.expectError(error.InvalidDataLength, result);
}

test "Val.to_u32 with mismatched type - error" {
    // 创建i32的Val，尝试转换为u32应该成功（相同大小）
    // 但这会导致数值的解释不同
    const value: i32 = -1;
    const val = Val.from_i32(value);
    const result = try val.to_u32(); // 不会报错，因为长度匹配
    // 但值会不同（-1 as i32 会被解释为一个很大的u32）
    try testing.expect(result != @as(u32, @bitCast(value)));
    // 实际上它们的位模式相同
    try testing.expectEqual(@as(u32, @bitCast(value)), result);
}

// ==================== 实际使用场景测试 ====================

test "Val typed API - practical usage" {
    // 模拟实际使用场景：存储玩家分数
    const player_score: i32 = 1500;
    const player_level: u8 = 25;
    const player_gold: u64 = 999999;

    // 创建Val
    const score_val = Val.from_i32(player_score);
    const level_val = Val.from_u8(player_level);
    const gold_val = Val.from_u64(player_gold);

    // 转换回来
    const score = try score_val.to_i32();
    const level = try level_val.to_u8();
    const gold = try gold_val.to_u64();

    // 验证
    try testing.expectEqual(player_score, score);
    try testing.expectEqual(player_level, level);
    try testing.expectEqual(player_gold, gold);
}

test "Val typed API - roundtrip all signed types" {
    // 测试所有有符号类型的往返转换
    {
        const v: i8 = -42;
        try testing.expectEqual(v, try Val.from_i8(v).to_i8());
    }
    {
        const v: i16 = -1000;
        try testing.expectEqual(v, try Val.from_i16(v).to_i16());
    }
    {
        const v: i32 = -100000;
        try testing.expectEqual(v, try Val.from_i32(v).to_i32());
    }
    {
        const v: i64 = -10000000000;
        try testing.expectEqual(v, try Val.from_i64(v).to_i64());
    }
    {
        const v: i128 = -1000000000000000000000;
        try testing.expectEqual(v, try Val.from_i128(v).to_i128());
    }
}

test "Val typed API - roundtrip all unsigned types" {
    // 测试所有无符号类型的往返转换
    {
        const v: u8 = 200;
        try testing.expectEqual(v, try Val.from_u8(v).to_u8());
    }
    {
        const v: u16 = 50000;
        try testing.expectEqual(v, try Val.from_u16(v).to_u16());
    }
    {
        const v: u32 = 3000000000;
        try testing.expectEqual(v, try Val.from_u32(v).to_u32());
    }
    {
        const v: u64 = 15000000000000000000;
        try testing.expectEqual(v, try Val.from_u64(v).to_u64());
    }
    {
        const v: u128 = 250000000000000000000000000000000000000;
        try testing.expectEqual(v, try Val.from_u128(v).to_u128());
    }
}

// ==================== 浮点数测试 ====================

test "Val.from_f32 and to_f32" {
    const value: f32 = 3.14159;
    const val = Val.from_f32(value);
    const result = try val.to_f32();
    try testing.expectEqual(value, result);
}

test "Val.from_f32 and to_f32 - negative" {
    const value: f32 = -123.456;
    const val = Val.from_f32(value);
    const result = try val.to_f32();
    try testing.expectEqual(value, result);
}

test "Val.from_f32 and to_f32 - zero" {
    const value: f32 = 0.0;
    const val = Val.from_f32(value);
    const result = try val.to_f32();
    try testing.expectEqual(value, result);
}

test "Val.from_f32 and to_f32 - special values" {
    // 测试特殊浮点数值
    const inf = std.math.inf(f32);
    const neg_inf = -std.math.inf(f32);

    try testing.expectEqual(inf, try Val.from_f32(inf).to_f32());
    try testing.expectEqual(neg_inf, try Val.from_f32(neg_inf).to_f32());
}

test "Val.from_f64 and to_f64" {
    const value: f64 = 3.141592653589793;
    const val = Val.from_f64(value);
    const result = try val.to_f64();
    try testing.expectEqual(value, result);
}

test "Val.from_f64 and to_f64 - negative" {
    const value: f64 = -123456.789012;
    const val = Val.from_f64(value);
    const result = try val.to_f64();
    try testing.expectEqual(value, result);
}

test "Val.from_f64 and to_f64 - zero" {
    const value: f64 = 0.0;
    const val = Val.from_f64(value);
    const result = try val.to_f64();
    try testing.expectEqual(value, result);
}

test "Val.from_f64 and to_f64 - special values" {
    const inf = std.math.inf(f64);
    const neg_inf = -std.math.inf(f64);

    try testing.expectEqual(inf, try Val.from_f64(inf).to_f64());
    try testing.expectEqual(neg_inf, try Val.from_f64(neg_inf).to_f64());
}

test "Val.from_f64 and to_f64 - very small number" {
    const value: f64 = 1.23e-308;
    const val = Val.from_f64(value);
    const result = try val.to_f64();
    try testing.expectEqual(value, result);
}

test "Val.from_f64 and to_f64 - very large number" {
    const value: f64 = 1.23e308;
    const val = Val.from_f64(value);
    const result = try val.to_f64();
    try testing.expectEqual(value, result);
}

test "Val typed API - roundtrip float types" {
    // 测试浮点类型的往返转换
    {
        const v: f32 = 2.718281828;
        try testing.expectEqual(v, try Val.from_f32(v).to_f32());
    }
    {
        const v: f64 = 2.718281828459045;
        try testing.expectEqual(v, try Val.from_f64(v).to_f64());
    }
}

test "Val.to_f32 with wrong length - error" {
    // 创建一个f64的Val，尝试转换为f32应该失败
    const value: f64 = 3.14;
    const val = Val.from_f64(value);
    const result = val.to_f32();
    try testing.expectError(error.InvalidDataLength, result);
}

test "Val typed API - practical usage with floats" {
    // 模拟实际使用场景：存储物理量
    const temperature: f32 = 36.5;  // 体温
    const pi: f64 = 3.141592653589793;  // 圆周率

    // 创建Val
    const temp_val = Val.from_f32(temperature);
    const pi_val = Val.from_f64(pi);

    // 转换回来
    const temp = try temp_val.to_f32();
    const pi_result = try pi_val.to_f64();

    // 验证
    try testing.expectEqual(temperature, temp);
    try testing.expectEqual(pi, pi_result);
}

// ==================== 其他浮点数类型测试 ====================

test "Val.from_f16 and to_f16" {
    const value: f16 = 3.14;
    const val = Val.from_f16(value);
    const result = try val.to_f16();
    try testing.expectEqual(value, result);
}

test "Val.from_f16 and to_f16 - negative" {
    const value: f16 = -123.5;
    const val = Val.from_f16(value);
    const result = try val.to_f16();
    try testing.expectEqual(value, result);
}

test "Val.from_f16 and to_f16 - zero" {
    const value: f16 = 0.0;
    const val = Val.from_f16(value);
    const result = try val.to_f16();
    try testing.expectEqual(value, result);
}

test "Val.from_f80 and to_f80" {
    const value: f80 = 3.141592653589793238;
    const val = Val.from_f80(value);
    const result = try val.to_f80();
    try testing.expectEqual(value, result);
}

test "Val.from_f80 and to_f80 - negative" {
    const value: f80 = -123456.789012345;
    const val = Val.from_f80(value);
    const result = try val.to_f80();
    try testing.expectEqual(value, result);
}

test "Val.from_f80 and to_f80 - zero" {
    const value: f80 = 0.0;
    const val = Val.from_f80(value);
    const result = try val.to_f80();
    try testing.expectEqual(value, result);
}

test "Val.from_f128 and to_f128" {
    const value: f128 = 3.14159265358979323846264338327950288;
    const val = Val.from_f128(value);
    const result = try val.to_f128();
    try testing.expectEqual(value, result);
}

test "Val.from_f128 and to_f128 - negative" {
    const value: f128 = -1.23456789012345678901234567890123e30;
    const val = Val.from_f128(value);
    const result = try val.to_f128();
    try testing.expectEqual(value, result);
}

test "Val.from_f128 and to_f128 - zero" {
    const value: f128 = 0.0;
    const val = Val.from_f128(value);
    const result = try val.to_f128();
    try testing.expectEqual(value, result);
}

test "Val.from_f128 and to_f128 - very small number" {
    const value: f128 = 1.23e-4000;
    const val = Val.from_f128(value);
    const result = try val.to_f128();
    try testing.expectEqual(value, result);
}

test "Val.from_f128 and to_f128 - very large number" {
    const value: f128 = 1.23e4000;
    const val = Val.from_f128(value);
    const result = try val.to_f128();
    try testing.expectEqual(value, result);
}

test "Val.from_c_longdouble and to_c_longdouble" {
    const value: c_longdouble = 3.141592653589793;
    const val = Val.from_c_longdouble(value);
    const result = try val.to_c_longdouble();
    try testing.expectEqual(value, result);
}

test "Val.from_c_longdouble and to_c_longdouble - negative" {
    const value: c_longdouble = -123456.789012;
    const val = Val.from_c_longdouble(value);
    const result = try val.to_c_longdouble();
    try testing.expectEqual(value, result);
}

test "Val.from_c_longdouble and to_c_longdouble - zero" {
    const value: c_longdouble = 0.0;
    const val = Val.from_c_longdouble(value);
    const result = try val.to_c_longdouble();
    try testing.expectEqual(value, result);
}

test "Val.to_f16 with wrong length - error" {
    const value: f32 = 3.14;
    const val = Val.from_f32(value);
    const result = val.to_f16();
    try testing.expectError(error.InvalidDataLength, result);
}

test "Val.to_f80 with wrong length - error" {
    const value: f64 = 3.14;
    const val = Val.from_f64(value);
    const result = val.to_f80();
    try testing.expectError(error.InvalidDataLength, result);
}

test "Val.to_f128 with wrong length - error" {
    const value: f64 = 3.14;
    const val = Val.from_f64(value);
    const result = val.to_f128();
    try testing.expectError(error.InvalidDataLength, result);
}

test "Val typed API - roundtrip all float types" {
    // 测试所有浮点类型的往返转换
    {
        const v: f16 = 1.5;
        try testing.expectEqual(v, try Val.from_f16(v).to_f16());
    }
    {
        const v: f32 = 2.718281828;
        try testing.expectEqual(v, try Val.from_f32(v).to_f32());
    }
    {
        const v: f64 = 2.718281828459045;
        try testing.expectEqual(v, try Val.from_f64(v).to_f64());
    }
    {
        const v: f80 = 2.71828182845904523536;
        try testing.expectEqual(v, try Val.from_f80(v).to_f80());
    }
    {
        const v: f128 = 2.7182818284590452353602874713527;
        try testing.expectEqual(v, try Val.from_f128(v).to_f128());
    }
    {
        const v: c_longdouble = 3.14159;
        try testing.expectEqual(v, try Val.from_c_longdouble(v).to_c_longdouble());
    }
}
