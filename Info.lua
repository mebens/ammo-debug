local Info = class("Info")

function Info:initialize(debug, title, func, graph, interval, numFunc)
  self.title = title
  self.source = func
  self.graphSource = numFunc or func
  self.graph = graph
  self.interval = interval or 1
  self.height = 50
  self.spacing = 5
  self.padding = 3
  
  self.dsettings = debug.settings
  self.dstyle = debug.style
  self.data = { min = 1, max = 1 }
  self.timer = self.interval
  self.alwaysRecord = self.graph
end

function Info:update(dt)
  if not (self.graph or self.alwaysRecord) then return end
  
  if self.timer <= 0 then
    local n = self.graphSource()
    self.timer = self.timer + self.interval
    
    if type(n) == "number" then
      self.data[#self.data + 1] = n
      self.data.min = math.min(self.data.min, n)
      self.data.max = math.max(self.data.max, n)
      
      local maxEntries = math.floor((self.dstyle.infoWidth - self.dstyle.padding * 2) / self.spacing)
      while #self.data > maxEntries do table.remove(self.data, 1) end
    end
  else
    self.timer = self.timer - dt
  end
end

function Info:draw(x, y)
  local s = self.dstyle
  local width = s.infoWidth - s.padding * 2
  local yOffset = s.font:getHeight()
  
  love.graphics.pushColor(s.color)
  love.graphics.setFont(s.font)
  love.graphics.printf(self.title .. s.infoSeparator .. tostring(self.source()), x, y, width)
  love.graphics.popColor()
  
  if self.dsettings.drawGraphs and self.graph then
    local x1, y1
    local x2, y2
    yOffset = yOffset + self.padding
    
    local lineStyle = love.graphics.getLineStyle()
    love.graphics.setLine(1, s.graphLineStyle)
    love.graphics.pushColor(s.graphColor)
    
    for i = 1, #self.data do
      local n = self.data[i]
      x2 = x + self.spacing * (i - 1)
      y2 = y + yOffset + self.height - self.height * (n / self.data.max)
      if not x1 then x1, y1 = x2, y2 end
      love.graphics.line(x1, y1, x2, y2)
      x1, y1 = x2, y2
    end
    
    yOffset = yOffset + self.height
    love.graphics.popColor()
    love.graphics.setLineStyle(lineStyle)
  end
  
  return yOffset
end

return Info
