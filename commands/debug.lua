-- commands for modifying the debug module
local t = {}

local function info(self, f, title, ...)
  local func, err = loadstring(self._joinWithSpaces(...))
  
  if err then
    return err
  else
    f(title, func)
  end
end

function t:mkcmd(...)
  local args = { ... }
  local name = args[1]
  table.remove(args, 1)
  local func, err = loadstring(self._joinWithSpaces(unpack(args)))
  
  if err then
    return err
  else
    local msg = 'Command "' .. name .. '" has been ' .. (self.commands[name] and "replaced." or "added.")
    self.commands[name] = func
    return msg
  end
end

function t:rmcmd(name)
  if self.commands[name] then
    self.commands[name] = nil
    return 'Command "' .. name .. '" has been removed.'
  else
    return 'No command named "' .. name .. '"'
  end
end

function t:addinfo(title, ...)
  info(self, self.addInfo, title, ...)
end

function t:rminfo(title)
  self.addInfo(title)
end

function t:info()
  self.settings.alwaysShowInfo = not self.settings.alwaysShowInfo
end

function t:graphs()
  self.settings.drawGraphs = not self.settings.drawGraphs
end

return t
