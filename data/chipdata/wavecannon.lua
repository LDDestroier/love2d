local tArg = {...}

local info = {
	fullName = "WaveCannon",
	description = "Fires a projectile forwards that moves in a wavy pattern. Penetrates targets.",
	spriteset = "cannon",	-- which sprites to use
	initAmount = 99,		-- how many you start with
	penetrates = true,		-- goes through entities
	damage = 80,			-- holy shit this attack deals damage woaH
	lifespan = 500,			-- amount of PANELS to travel before dissapating
	damageLife = 8,			-- amount of frames to leave damaging trail, set to 1 for none
}

local data = tArg[1]	-- all info on projectile
local p_act = tArg[2]	-- panel actions
local assets = tArg[3]	-- music, sfx, images

if not data then
	return info
end

if data.frame == 1 then
	love.audio.stop(assets.sfx.wavecannon)
	love.audio.play(assets.sfx.wavecannon)
end

data.px = data.px + 0.06
data.py = data.initY + math.sin(data.frame / 13)

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
