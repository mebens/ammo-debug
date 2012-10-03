-- commands for modifying the world
local t = {}

function t:pause()
  if ammo.world then ammo.world.active = not ammo.world.active end
end

function t:hide()
  if ammo.world then ammo.world.visible = not ammo.world.visible end
end

function t:step()
  ammo.world:update(dt or love.timer.getDelta())
end

function t:backstep()
  ammo.world:update(-(dt or love.timer.getDelta()))
end

return t
