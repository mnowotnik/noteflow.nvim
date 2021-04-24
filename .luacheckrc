cache = false
std = luajit
codes = true
self = false

-- https://luacheck.readthedocs.io/en/stable/warnings.html
ignore = {
  "212", -- Unused argument
  "122", -- Indirectly setting a readonly global
}

read_globals = {
  "vim",
}
