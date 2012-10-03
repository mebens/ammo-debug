-- commands for modifying the debug module
local t = {}

function t:mkcmd(...)
  local args = { ... }
  local name = args[1]
  table.remove(args, 1)
  local func, err = loadstring(joinWithSpaces(unpack(args)))
  
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
  local func, err = loadstring(joinWithSpaces(...))
  
  if err then
    return err
  else
    self.addInfo(title, func)
  end
end

function t:rminfo(title)
  self.addInfo(title)
end

return t
