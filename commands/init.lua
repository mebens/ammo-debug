local path = debug.path .. ".commands."
debug.include(require(path .. "debug"))
debug.include(require(path .. "filesystem"))
debug.include(require(path .. "lua"))
debug.include(require(path .. "world"))
