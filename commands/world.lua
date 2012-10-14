-- commands for modifying the world
local t = {}

function t:pause()
  if ammo.world then ammo.world.active = not ammo.world.active end
end

function t:hide()
  if ammo.world then ammo.world.visible = not ammo.world.visible end
end

function t:step()
  if ammo.world then ammo.world:update(dt or love.timer.getDelta()) end
end

function t:backstep()
  if ammo.world then ammo.world:update(-(dt or love.timer.getDelta())) end
end

function t:recreate()
  if ammo.world then
    local world = ammo.world.class:new()
    world.active = ammo.world.active
    world.visible = ammo.world.visible
    ammo.world = world
    log(ammo.world.active, ammo.world.visible)
  end
end

return t
