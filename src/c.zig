// 集中管理 C 导入，确保所有模块使用相同的 C 类型定义
pub const c = @cImport({
    @cInclude("mdbx.h");
});
