debug = {}
debug.path = ({...})[1]:gsub("%.debug$", "")
local Info = require(debug.path .. ".Info")

-- PROPERTIES/SETTINGS --

debug.opened = false
debug.active = false
debug.visible = false
debug.y = -1000

debug.input = ""
debug.history = { index = 0 }
debug.buffer = { index = 0 }
debug.info = {}
debug.commands = {}

debug.settings = {
  -- booleans
  alwaysShowInfo = false, -- show info even when console is closed
  drawGraphs = false,
  pauseWorld = true, -- pause world when console is opened
  printOutput = false, -- debug.log will also print to the standard output
  tween = true,
  
  -- limits
  bufferLimit = 1000, -- maximum lines in the buffer
  historyLimit = 100, -- maximum entries in the command history
  
  -- timing
  multiEraseTime = 0.35,
  multiEraseCharTime = 0.025,
  cursorBlinkTime = 0.5,
  openTime = 0.1,
  
  -- spacial
  height = 400,
  infoWidth = 300,
  borderSize = 2,
  padding = 10,
  
  -- colors
  color = { 240, 240, 240, 255 },
  bgColor = { 0, 0, 0, 200 },
  borderColor = { 200, 200, 200, 220 },
  graphColor = { 180, 180, 180, 255 },
  graphTextColor = { 255, 255, 255, 255 },
  
  -- text
  font = love.graphics.newFont(debug.path:gsub("%.", "/") .. "/inconsolata.otf", 18),
  graphFont = love.graphics.newFont(debug.path:gsub("%.", "/") .. "/inconsolata.otf", 14),
  prompt = "> ",
  cursor = "|",
  infoSeparator = ": ",
  
  -- other
  initFile = "debug-init", -- if present, this batch file will be executed on initialisation
  graphLineStyle = "rough"
}

-- keyboard controls
debug.controls = {
  open = "`",
  pause = "",
  toggleInfo = "",
  toggleGraphs = "",
  up = "pageup",
  down = "pagedown",
  historyUp = "up",
  historyDown = "down",
  erase = "backspace",
  execute = "return"
}

-- LOCAL --

-- a few timer variables
local timers = {
  multiErase = 0,
  multiEraseChar = 0,
  blink = -debug.settings.cursorBlinkTime -- negative = cursor off, positive = cursor on
}

-- removes the last character from the input line
local function removeCharacter()
  debug.input = debug.input:sub(1, #debug.input - 1)
end

-- adds the item to the table, making sure the table's length hasn't exceeded the limit
local function addTo(t, v, limit)
  t[#t + 1] = v
  if #t > limit then table.remove(t, 1) end
  t.index = #t
end

-- adds the text to the buffer, making sure to split it into separate lines
local function addToBuffer(str)
  for line in str:gmatch("[^\n]+") do
    addTo(debug.buffer, line, debug.settings.bufferLimit)
  end
end

-- compile an argument as a string if possible
local function compileArg(arg)
  if arg:sub(1, 1) == "$" then
    arg = debug.runCommand(arg:match("^$(.+)$$"), true)
  else  
    local func = loadstring("return " .. arg)
    
    if func then
      arg = func()
    else
      debug.log("Couldn't compile argument #" .. (index - 1) .. " as string.")
    end
  end
  
  return arg
end

-- run a batch file
local function runBatch(file)
  for line in love.filesystem.lines(file) do debug.runCommand(line) end
end

-- both these are used by the tween in moveConsole
local function openEnd()
  debug.active = true
end

local function closeEnd()
  debug.visible = false
end

-- change the console's position depending on debug.opened
local function moveConsole(doTween)
  local y = debug.opened and 0 or -debug.settings.height - debug.settings.borderSize
  if doTween == nil then doTween = true end
  
  if doTween and ammo.ext.tweens then
    debug.tween = AttrTween:new(debug, debug.settings.openTime, { y = y }, nil, debug.opened and openEnd or closeEnd)
    debug.tween:start()
    
    if debug.opened then
      debug.visible = true
    else
      debug.active = false
    end
  else
    debug.y = y
    debug.active = debug.opened
    debug.visible = debug.opened
  end
end

-- handles the execution of the current input line
local function handleInput()
  addToBuffer(debug.settings.prompt .. debug.input)
  debug.runCommand(debug.input)
  addTo(debug.history, debug.input, debug.settings.bufferLimit)
  debug.history.index = #debug.history + 1  
  debug.input = ""
end

-- displays the currently selected line in the history
local function handleHistory()
  local i = debug.history.index
  if #debug.history == 0 then return end
  
  if i == #debug.history + 1 then
    debug.input = ""
  else
    debug.input = debug.history[i]
  end
end

-- resets the console
local function reset()
  debug.buffer = { index = 0 }
  debug.log("==== ammo-debug 0.1 ====")
  
  -- initialisation file
  if love.filesystem.exists(debug.settings.initFile) then
    runBatch(debug.settings.initFile)
  end
end

-- joins a list of strings, separating them with spaces
function debug._joinWithSpaces(...)
  local str = ""
  local args = { ... }
  
  for i, v in ipairs(args) do
    if type(v) == "boolean" then
      v = v and "true" or "false"
    else
      v = tostring(v)
    end
    
    str = str .. v .. (i == #args and "" or " ")
  end
  
  return str
end

-- FUNCTIONS --

function debug.init()
  debug.y = -debug.settings.height
  reset()
  if debug.live then debug.check() end
  
  -- default info graphs
  debug.addGraph("FPS", love.timer.getFPS)
  debug.addGraph("Memory", function() return ("%.2f MB"):format(collectgarbage("count") / 1024) end, function() return collectgarbage("count") / 1024 end)
  debug.addGraph("Entities", function() return ammo.world and ammo.world.count or nil end)
end

function debug.log(...)
  local msg = debug._joinWithSpaces(...)
  addToBuffer(msg)
  if debug.settings.printOutput then print(msg) end
end

function debug.runCommand(line, ret)
  local terms = {}
  local quotes = false
  
  -- split and compile terms
  for t in line:gmatch("[^%s]+") do
    if quotes then
      terms[#terms] = terms[#terms] .. " " .. t
    else
      terms[#terms + 1] = t
      quotes = t:match("^[\"'$]")
    end
    
    if quotes and t:sub(-1) == quotes then
      quotes = false
      terms[#terms] = compileArg(terms[#terms])
    end
  end
  
  if terms[1] then
    local cmd = debug.commands[terms[1]]
    
    if cmd then
      terms[1] = debug -- replace the name with the self argument
      local result, msg = pcall(cmd, unpack(terms))
      
      if msg then
        if ret then
          return msg
        else
          debug.log(msg)
        end
      end
    else
      debug.log('No command named "' .. terms[1] .. '"')
    end
  end
end

function debug.addInfo(title, func)
  debug.info[#debug.info + 1] = Info:new(debug, title, func, false)
  debug.info.keys[title] = #debug.info
end

function debug.addGraph(title, func, funcOrInterval, interval)
  local info
  
  if type(funcOrInterval) == "function" then
    info = Info:new(debug, title, func, true, interval, funcOrInterval)
  else
    info = Info:new(debug, title, func, true, funcOrInterval)
  end
  
  debug.info[#debug.info + 1] = info
end

function debug.removeInfo(title)
  for i = 1, #debug.info do
    if debug.info[i].title == title then
      table.remove(debug.info, i)
      break
    end
  end
end

function debug.include(t)
  for k, v in pairs(t) do 
    if type(v) == "function" then
      debug.commands[k] = v
    elseif k == "help" then
      for cmd, docs in pairs(v) do debug.help[cmd] = docs end
    end
  end
end

function debug.open(tween)
  debug.opened = true
  moveConsole(tween or debug.settings.tween)
end

function debug.close(tween)
  debug.opened = false
  moveConsole(tween or debug.settings.tween)
end

function debug.toggle(tween)
  debug.opened = not debug.opened
  moveConsole(tween or debug.settings.tween)
end

-- CALLBACKS --

function debug.update(dt)
  if debug.active then
    -- erasing characters
    if love.keyboard.isDown(debug.controls.erase) and #debug.input > 0 then
      if timers.multiErase == 0 then
        removeCharacter() -- first character when pressed
      elseif timers.multiErase > debug.settings.multiEraseTime then
        -- rapidly erasing multiple characters
        if timers.multiEraseChar <= 0 then
          removeCharacter()
          timers.multiEraseChar = timers.multiEraseChar + debug.settings.multiEraseCharTime
        else
          timers.multiEraseChar = timers.multiEraseChar - dt
        end
      end
      
      timers.multiErase = timers.multiErase + dt
    else
      timers.multiErase = 0
      timers.multiEraseChar = 0
    end
    
    -- cursor blink
    if timers.blink >= debug.settings.cursorBlinkTime then
      timers.blink = -debug.settings.cursorBlinkTime
    else
      timers.blink = timers.blink + dt
    end
  end
  
  for _, info in ipairs(debug.info) do info:update(dt) end
  if debug.tween and debug.tween.active then debug.tween:update(dt) end
end

function debug.draw()
  local s = debug.settings
  
  if debug.visible then
    -- background
    love.graphics.pushColor(s.bgColor)
    love.graphics.rectangle("fill", 0, debug.y, love.graphics.width, s.height)
    love.graphics.popColor()
    
    -- border
    love.graphics.pushColor(s.borderColor)
    love.graphics.rectangle("fill", 0, debug.y + s.height, love.graphics.width, s.borderSize)
    love.graphics.popColor()
    
    -- text
    local str = ""
    local rows = math.floor((s.height - s.padding * 2) / s.font:getHeight())
    local begin = math.max(debug.buffer.index - rows + 2, 1) -- add 2: one for the input line, another for keeping it in bounds (not sure why its needed)
      
    for i = begin, debug.buffer.index do
      str = str .. debug.buffer[i] .. "\n"
    end
    
    str = str .. s.prompt .. debug.input
    if timers.blink > 0 then str = str .. s.cursor end
    love.graphics.setFont(s.font)
    love.graphics.printf(str, s.padding, debug.y + s.padding, love.graphics.width - s.infoWidth - s.padding * 2)
  end
  
  if debug.visible or s.alwaysShowInfo then
    local x = love.graphics.width - s.infoWidth + s.padding
    local y = (s.alwaysShowInfo and 0 or debug.y) + s.padding
    for _, info in ipairs(debug.info) do y = y + info:draw(x, y) end
  end
end

function debug.keypressed(key, code)
  local c = debug.controls
  
  if key == c.open then
    debug.toggle()
    if debug.settings.pauseWorld and ammo.world then ammo.world.active = not debug.opened end
  elseif key == c.pause then
    if ammo.world then ammo.world.active = not ammo.world.active end
  elseif key == c.toggleInfo then
    debug.settings.alwaysShowInfo = not debug.settings.alwaysShowInfo
  elseif key == c.toggleGraphs then
    debug.settings.drawGraphs = not debug.settings.drawGraphs
  elseif debug.active then
    if key == c.execute then
      handleInput()
    elseif key == c.historyUp then
      debug.history.index = math.max(debug.history.index - 1, 1)
      handleHistory()
    elseif key == c.historyDown then
      -- have to use if statement since handleHistory shouldn't be called if index is already one over #history
      if debug.history.index < #debug.history + 1 then
        debug.history.index = debug.history.index + 1
        handleHistory()
      end
    elseif key == c.up then
      debug.buffer.index = math.max(debug.buffer.index - 1, 0)
    elseif key == c.down then
      debug.buffer.index = math.min(debug.buffer.index + 1, #debug.buffer)
    elseif code > 31 and code < 127 then
      -- ^ those are the printable characters
      debug.input = debug.input .. string.char(code)
    end
  end
end

-- ESSENTIAL COMMANDS --

function debug.commands:lua(...)
  local func, err = loadstring(self._joinWithSpaces(...))
  
  if err then
    return err
  else
    local result, msg = pcall(func)
    return msg
  end
end

-- works like the Lua interpreter
debug.commands["="] = function(self, ...)
  return self.commands.lua(self, "return", ...)
end

function debug.commands:bat(file)
  if love.filesystem.exists(file) then
    runBatch(file)
  else
    return "File doesn't exist."
  end
end

debug.commands["repeat"] = function(self, times, ...)
  local cmd = debug._joinWithSpaces(...)
  for i = 1, tonumber(times) do self.runCommand(cmd) end
end

function debug.commands:clear()
  self.buffer = { index = 0 }
end

function debug.commands:echo(...)
  return self._joinWithSpaces(...)
end

debug.commands.reset = reset

function debug.commands:help(cmd)
  if not cmd then
    for name in pairs(self.commands) do
      local str = name
      local docs = self.help[name]
      
      if docs then
        if docs.args then str = str .. " " .. docs.args end
        if docs.summary then str = str .. " -- " .. docs.summary end
      end
      
      self.log(str)
    end
  elseif self.commands[cmd] then
    local docs = self.help[cmd]
    
    if docs then
      local str = "SYNTAX\n" .. cmd
      if docs.args then str = str .. " " .. docs.args end
      if docs.summary then str = str .. "\n \nSUMMARY\n" .. docs.summary end
      if docs.description then str = str .. "\n \nDESCRIPTION\n" .. docs.description end
      if docs.example then str = str .. "\n \nEXAMPLE\n" .. docs.example end
      return str
    else
      return 'No documentation for "' .. cmd .. '"'
    end
  else
    return 'No command named "' .. cmd .. '"'
  end
end

-- COMMAND DOCUMENTATION --

debug.help = {
  lua = {
    args = "code...",
    summary = "Compiles and executes Lua code. Returns the result.",
    example = "> lua function globalFunc() return 3 ^ 2 end\n> lua return globalFunc()\n9"
  },
  
  ["="] = {
    args = "code...",
    summary = "Executes Lua code, but also prefixes the return statement to the code.",
    description = "Compiles and executes Lua code, much like the lua command.\nHowever, it prefixes the return statement to the code.\nFor example, \"= 3 + 4\" is the same as \"lua return 3 + 4\"."
  },
  
  bat = {
    args = "file",
    summary = "Executes a batch file containing multiple commands.",
    description = "Executes a batch file. A batch file is a text which contains multiple commands which can be executed on the console."
  },
  
  ["repeat"] = {
    args = "num-times command [args...]",
    summary = "Repeats a command multiple times.",
    example = "> repeat 3 echo hello\nhello\nhello\nhello"
  },
  
  clear = {
    summary = "Clears the console's text buffer."
  },
  
  echo = {
    args = "text...",
    summary = "Outputs the text given.",
    example = "> echo foo bar \"la la\"\nfoo bar la la"
  },
  
  help = {
    args = "[command]",
    summary = "Lists all available commands or provides documentation for a specific command."
  }
}
