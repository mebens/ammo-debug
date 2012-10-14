local modified = {}
debug.live = true

local function convertPath(path)
  path = path:gsub("%.", "/")
  
  for p in package.path:gmatch("[^;]+") do
    local x = p:gsub("%?", path):gsub("^%./", "")
    if love.filesystem.exists(x) then return x end
  end
end

function debug.check(path)
  if path then
    local file = convertPath(path)
    
    if file then
      local mod = love.filesystem.getLastModified(file)
      if modified[path] and mod ~= modified[path] then debug.reload(path) end
      modified[path] = mod
    end
  else
    for path in pairs(package.loaded) do debug.check(path) end
  end
end

function debug.reload(path)
  path = convertPath(path)
  if not path then return "File doesn't exist" end
  
  local t = setmetatable({}, { __index = _G, __newindex = function(t, k, v)
    if type(_G[k]) ~= "table" then rawset(t, k, v) end
  end })
  
  local func, err = loadfile(path)
  if not func then return err end
  
  setfenv(func, t)
  local status, err = pcall(func)
  if not status then return err end
  for k, v in pairs(t) do _G[k] = v end
end

function debug.focus(f)
  if f then debug.check() end
end

function debug.commands:reload(path)
  return debug.reload(path)
end

if not love.focus then love.focus = debug.focus end
