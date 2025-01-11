const std = @import("std");
const c = @cImport({
    @cInclude("mdbx.h");
});

const Self = @This();
