local tArg = {...}

local info = {
	fullName = "BackCannon",
	description = "Fires a projectile that spawns 4 panels forwards and aims backwards.",
	spriteset = "cannon",	-- which sprites to use
	initAmount = 99,		-- how many you start with
	penetrates = false,		-- goes through entities
	damage = 80,			-- holy shit this attack deals damage woaH
	lifespan = 500,			-- amount of PANELS to travel before dissapating
	damageLife = 0,			-- amount of frames to leave damaging trail, set to 1 for none
}

local data = tArg[1]	-- all info on projectile
local p_act = tArg[2]	-- panel actions
local assets = tArg[3]	-- music, sfx, images

if not data then
	return info
end

if data.frame == 1 then
	love.audio.stop(assets.sfx.backcannon)
	love.audio.play(assets.sfx.backcannon)
	data.px = data.initX + 3.5
else
	data.px = data.px - 0.1
end

local ppx, ppy = math.floor(data.px + 1), math.floor(data.py + 0.5) -- centered X/Y of projectile

repeat
	if data.noGoAreas[ppy] then
		if data.noGoAreas[ppy][ppx] then
			break
		end
	end
	p_act.setDamage(ppx, ppy, data.damage, data.owner, data.damageLife)
until true

return data.frame > info.lifespan, data
