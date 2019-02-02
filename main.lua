love.window.setMode(1280, 720)
love.window.setTitle("game test")

local scr_x, scr_y = love.graphics.getWidth(), love.graphics.getHeight()
local mx, my = scr_x, scr_y

local mainDir = "data/"
local you = 1 -- entity ID that you play as

local game = {
	meta = {
		backgroundMod = 0
	},
	dir = {
		main = mainDir,
		images = mainDir .. "images/",
		chipdata = mainDir .. "chipdata/",
		maps = mainDir .. "maps/",
		lib = mainDir .. "lib/",
	},
	map = {
		name = "testmap.cbor"
	},
	editor = {
		active = false,
		message = "Started.",
		panel = {
			panelType = "normal",
			owner = 0,
			crackLevel = 0,
			elevation = 0,
		}
	},
	chips = {},
	entityTypes = {},
	debug = {}, -- messages in top left corner of screen
}

cbor = require(game.dir.lib .. "cbor")
--eList[entity.py]
local control = {}

local getControl = function()
	return {
		moveUp 		= love.keyboard.isDown("w"),
		moveDown 	= love.keyboard.isDown("s"),
		moveRight 	= love.keyboard.isDown("d"),
		moveLeft 	= love.keyboard.isDown("a"),
		shootUp 	= love.keyboard.isDown("up"),
		shootDown 	= love.keyboard.isDown("down"),
		shootLeft 	= love.keyboard.isDown("left"),
		shootRight 	= love.keyboard.isDown("right")
	}
end

game.entityTypes = {
	["player"] = {
		name = "Player",
		spriteset = "player",
	}
}

local newEntity = function(px, py, entityType, owner, other)
	-- do not add any fuckin' userdata values
	other = other or {}
	return {
		x = 0,								-- onscreen X, determined afterwards
		y = 0,								-- onscreen Y, also determined afterwards
		xadj = other.xadj or 3,				-- adjust sprite X
		yadj = other.yadj or -180,			-- adjust sprite Y
		px = px or 0,						-- panel-grid X
		py = py or 0,						-- panel-grid Y
		direction = other.direction or 1,	-- 1 = right, -1 = left
		state = other.state or "stand",		-- normal, hurt, etc.
		health = other.health or 1000,
		maxHealth = other.maxHealth or 1000,
		aura = other.aura or 0,				-- while above zero, attacks that deal less than the value are ignored
		owner = owner or 1,					-- which panels belong to this entity
		name = other.name or game.entityTypes[entityType].name,
		spriteset = other.spriteset or game.entityTypes[entityType].spriteset,
		status = other.status or {			-- statuses are set to numbers indicating their duration
			stunned = 0,		-- stunned and unable to move
			grounded = 0,		-- mashed into ground
			angry = 0,			-- deals double damage
		},
		tint = other.tint or {
			1,					-- red
			1,					-- green
			1,					-- blue
			1					-- alpha
		},
		maxCooldown = other.maxCooldown or { -- cooldown for specific actions and states
			move = 10,		-- 1 movement per 10 frames
			attack = 20,	-- attacking with chip
			cameraMod = 1,	-- higher = slower camera
			iframes = 64,	-- invincible while above 0
		},
		cooldown = other.cooldown or {
			move = 0,
			attack = 0,
			cameraMod = 0,
			iframes = 0,
		},
		meta = other.meta or {	-- other player-specific values, like for animation
			playerBob = 0,		-- 0-360 value for bobbing the player up and down
			stretchX = 1,		-- multiplier for sprite width (origin = center)
			stretchY = 1,		-- multiplier for sprite height (origin = bottom)
			doRender = true,	-- whether or not to draw the sprite
			nextMoveX = 0,
			nextMoveY = 0,
		},
		loadout = other.loadout or {
			[1] = nil,
			[2] = nil,
			[3] = nil,
			[4] = nil
		},
		folder = other.folder or {}
	}
end

local map = {
	panels = {},
	scrollX = -74,
	scrollY = -40,
	zoom = 100,
	panelWidth = 128,
	panelHeight = 64,
	entities = {},
	projectiles = {}
}

local e_act = {
	isInvincible = function(entity)
		return entity.cooldown.iframes > 0
	end,
	isDead = function(entity)
		return entity.health <= 0
	end,
	isMoving = function(entity)
		return entity.cooldown.move ~= 0
	end,
	getPanel = function(entity)
		return (map.panels[entity.py] or {})[entity.px]
	end
}

local p_act = {
	setDamage = function(px, py, damage, damageOwner, damageLife)
		if map.panels[py] then
			if map.panels[py][px] then
				map.panels[py][px].damage = damage
				map.panels[py][px].damageOwner = damageOwner
				map.panels[py][px].damageLife = damageLife
			end
		end
	end,
	getDamage = function(px, py)
		if map.panels[py] then
			if map.panels[py][px] then
				return map.panels[py][px].damage, map.panels[py][px].damageOwner
			end
		end
		return 0, 0
	end,
	getEntities = function(px, py)
		local output = {}
		if map.panels[py] then
			if map.panels[py][px] then
				for id, entity in pairs(map.entities) do
					if entity.px == px and entity.py == py then
						output[id] = entity
					end
				end
			end
		end
		return output
	end
}

game.chips = {
	["cannon"] = {
		fullName = "Cannon",
		description = "Fires a single projectile forwards for medium damage. Does not penetrate targets.",
		spriteset = "cannon",
		path = "cannon.lua",	-- data file path
		initAmount = 3,			-- how many you start with
		penetrates = false,		-- goes through entities
		speed = 5,				-- pixels per frame
		damage = 100,			-- holy shit this attack deals damage woaH
		lifespan = 500,			-- amount of PANELS to travel before dissapating
		damageLife = 4,			-- amount of frames to leave damaging trail, set to 1 for none
	}
}

local newProjectile = function(px, py, pType, direction, owner)
	local output = {
		px = px,				-- starting X on panel grid
		py = py,				-- starting Y on panel grid
		direction = direction,	-- left (-1) or right (1)
		owner = owner,			-- ensures it won't collide with owner
		frame = 0,				-- iterates every frame
	}
	for k,v in pairs(game.chips[pType]) do
		output[k] = v
	end
	return output
end

map.entities[you] = newEntity(3, 2, "player", 1, {
	direction = 1
})
map.entities[2] = newEntity(5, 2, "player", 2, {
	direction = -1
})

local images = {
	panel = {
		normal = love.graphics.newImage(game.dir.images .. "panels/normal.png"),
	},
	player = {
		stand = love.graphics.newImage(game.dir.images .. "entities/player/stand.png")
	},
	projectiles = {
		cannon = love.graphics.newImage(game.dir.images .. "projectiles/cannon.png")
	}
}

local cameraDistance

for k,v in pairs(images) do
	for iType, image in pairs(v) do
		image:setFilter("nearest")
	end
end

local panelTypes = {
	["normal"] = {
		image = images.panel.normal,
		property = "normal",
	}
}

local newPanel = function(px, py, panelType, owner, crackLevel, elevation, info)
	return {
		panelType = panelType or "normal",
		crackLevel = crackLevel or 0,	-- 0 is solid, 1 is cracked, 2 is broken
		owner = owner or 1,				-- 1 is red, 2 is blue
		px = px or 0,					-- x on the panel grid
		py = py or 0,					-- y on the panel grid
		occupied = false,				-- whether or not someone or something is due to stand on it
		damage = 0,						-- if attacks pass over this, it's damage value becomes the sum of all attacks' damages on there
		damageOwner = 0,
		damageLife = 0,
		elevation = elevation or 0
	}
end

local isPositionWalkable = function(id, px, py)
	local output = false
	if map.panels[py] then
		if map.panels[py][px] then
			if map.panels[py][px].crackLevel ~= 2 then
				if map.panels[py][px].owner == map.entities[id].owner or map.panels[py][px].owner == 0 then
					if (not map.panels[py][px].occupied) or map.panels[py][px].occupied == id then
						output = true
					end
				end
			end
		end
	end
	return output
end

-- make demo map
for y = 1, 3 do
	map.panels[y] = {}
	for x = 1, 7 do
		map.panels[y][x] = newPanel(x, y, "normal",

		(x <= 1 and
			1
		or x >= 7 and
			2
		or
			0
		),

		0, 0, nil)
	end
end

local tableSize = function(tbl)
	local top, bottom = 0, 0
	for k,v in pairs(tbl) do
		if tonumber(k) then
			top = math.max(top, k)
			bottom = math.min(bottom, k)
		end
	end
	return bottom, top
end

local render = function()
	-- draw panels
	local px, py
	local r, g, b, a
	local bottomY, topY = tableSize(map.panels)
	local bottomX, topX
	for y = bottomY, topY do
		if map.panels[y] then
			bottomX, topX = tableSize(map.panels[y] or {})
			for x = bottomX, topX do
				if type(map.panels[y][x]) == "table" then
					if map.panels[y][x].panelType then
						px = (x * map.panelWidth) - map.scrollX
						py = (y * map.panelHeight) - map.scrollY

						-- colorize panels according to ownership
						if p_act.getDamage(x, y) > 0 then
							love.graphics.setColor(1, 1, 0)
						else
							if map.panels[y][x].owner == 1 then
								love.graphics.setColor(1, 0.75, 0.75, (not game.editor.active and love.keyboard.isDown("1")) and 0.25 or 1)
							elseif map.panels[y][x].owner == 2 then
								love.graphics.setColor(0.75, 0.75, 1, (not game.editor.active and love.keyboard.isDown("3")) and 0.25 or 1)
							else
								love.graphics.setColor(1, 1, 1, (not game.editor.active and love.keyboard.isDown("2")) and 0.25 or 1)
							end
						end

						-- fluxuate panel colors slightly
						if math.random(1, 4) == 1 then
							r, g, b, a = love.graphics.getColor()
							love.graphics.setColor(
								r + math.random(-10, 10) / 300,
								g + math.random(-10, 10) / 300,
								b + math.random(-10, 10) / 300,
								a
							)
						end

						love.graphics.draw(
							panelTypes[map.panels[y][x].panelType].image,
							px,
							py,
							0,	-- rotate
							8,	-- scale X
							8	-- scale Y
						)
					end
				end
			end
		end
	end
	-- draw entities
	local ex, ey
	local eList = {} -- organize entities by py, for layering
	local low, high = 0, 0
	for id, entity in pairs(map.entities) do
		if entity.meta.doRender then
			eList[entity.py] = eList[entity.py] or {}
			eList[entity.py][#eList[entity.py] + 1] = {id, entity}
			low = math.min(low, entity.py)
			high = math.max(high, entity.py)
		end
	end
	local id
	for y = low, high do
		if eList[y] then
			for _, _e in pairs(eList[y]) do
				id, entity = _e[1], _e[2]
				entity.meta.playerBob = (map.entities[you].meta.playerBob + 1) % 360
				love.graphics.setColor(1, 1, 1, love.keyboard.isDown("space") and 0.25 or 1)
				local bobMult = math.sin(math.rad(entity.meta.playerBob) * 1) * 0.05 + 0.05
				love.graphics.setColor(unpack(entity.tint))
				ex = entity.px * map.panelWidth  - map.scrollX + (entity.xadj * entity.meta.stretchX * entity.direction)
				ey = entity.py * map.panelHeight - map.scrollY + entity.yadj
				love.graphics.draw(
					images[entity.spriteset].stand,
					ex - (0.5 * ((entity.meta.stretchX * entity.direction) - 1) * images[entity.spriteset].stand:getWidth() ),
					ey + (bobMult * images[entity.spriteset].stand:getHeight()),
					0,
					entity.meta.stretchX * entity.direction,
					entity.meta.stretchY - bobMult
				)
				love.graphics.printf(
					entity.health,
					ex - map.panelWidth * 0.5,
					ey - 10,
					map.panelWidth,
					"center",
					0,
					2,
					2
				)
			end
		end
	end
	love.graphics.setColor(1, 1, 1, 1)
	for id, projectile in pairs(map.projectiles) do
		love.graphics.draw(
			images.projectiles[projectile.spriteset],
			projectile.px * map.panelWidth - map.scrollX + (map.panelWidth),
			projectile.py * map.panelHeight - map.scrollY - (map.panelHeight / 2)
		)
	end
end

local anims = {
	moveCompress = function(player, step, maxStep)
		map.entities[you].meta.stretchX = math.abs(maxStep - (2 * step)) / maxStep
		map.entities[you].tint[4] = math.abs(maxStep - (2 * step)) / maxStep + 0.5
		map.entities[you].tint[1] = math.abs(maxStep - (2 * step)) / maxStep
		map.entities[you].tint[2] = math.abs(maxStep - (2 * step)) / maxStep
		map.entities[you].tint[3] = math.abs(maxStep - (2 * step)) / maxStep
	end,
}

local playerControl = function(id)
	local player = map.entities[id]
	-- player movement
	anims.moveCompress(player, player.cooldown.move, player.maxCooldown.move)
	if player.cooldown.move == 0 then
		player.meta.nextMoveX = 0
		player.meta.nextMoveY = 0
		repeat
			if player.cooldown.attack == 0 then
				if control.shootUp then
					map.projectiles[#map.projectiles + 1] = newProjectile(
						player.px,
						player.py,
						"cannon",
						player.direction,
						player.owner
					)
					player.cooldown.attack = player.maxCooldown.attack
				end
			else
				player.cooldown.attack = player.cooldown.attack - 1
			end
			if control.moveUp then
				player.meta.nextMoveY = -1
				player.cooldown.move = player.maxCooldown.move
			end
			if control.moveDown then
				player.meta.nextMoveY = 1
				player.cooldown.move = player.maxCooldown.move
			end
			if control.moveRight then
				player.meta.nextMoveX = 1
				player.cooldown.move = player.maxCooldown.move
			end
			if control.moveLeft then
				player.meta.nextMoveX = -1
				player.cooldown.move = player.maxCooldown.move
			end
		until true
		if not isPositionWalkable(id, player.meta.nextMoveX + player.px, player.meta.nextMoveY + player.py) then
			if (player.meta.nextMoveX ~= 0) and isPositionWalkable(id, player.meta.nextMoveX + player.px, player.py) then
				player.meta.nextMoveY = 0
			elseif (player.meta.nextMoveY ~= 0) and isPositionWalkable(id, player.px, player.meta.nextMoveY + player.py) then
				player.meta.nextMoveX = 0
			else
				player.cooldown.move = 0
				player.meta.nextMoveX = 0
				player.meta.nextMoveY = 0
			end
		end
	else
		if player.cooldown.move == player.maxCooldown.move / 2 then
			if isPositionWalkable(id, player.meta.nextMoveX + player.px, player.meta.nextMoveY + player.py) then
				player.px = player.px + player.meta.nextMoveX
				player.py = player.py + player.meta.nextMoveY
			end
		end
		player.cooldown.move = player.cooldown.move - 1
	end
end

local cameraControl = function()
	if control.moveRight then
		map.scrollX = map.scrollX + 5
	end
	if control.moveLeft then
		map.scrollX = map.scrollX - 5
	end
	if control.moveUp then
		map.scrollY = map.scrollY - 5
	end
	if control.moveDown then
		map.scrollY = map.scrollY + 5
	end
end

local distance = function(x1, y1, x2, y2)
	return math.sqrt( (x2 - x1)^2 + (y2 - y1)^2 )
end

local drawStaticBackground = function(_frame)
	local frame = _frame / 100
	local cx = math.sin(frame) * 200 + 200 + (map.scrollX / 2)
	local cy = math.cos(frame) * 170 + 170 + (map.scrollY / 2)
	local bigno = 100
	local cooldiv, color

	local points = {}
	local i = 0

	for y = math.random(-2, 0), scr_y, 9 - (cy % 3) do
		for x = math.random(-2, 0), scr_x, 9 - (cx % 3) do

			i = i + 1

			cooldiv = 0.125 * distance(-mx, -my, x + cx, y + cy)
			color   = (distance( mx,  my, x + cx, y + cy) + frame / bigno * cooldiv) / cooldiv

			points[i] = {
				x,
				y,
				(color * math.random(1,64) / 128) % 1,
				(color * math.random(1,32) / 128) % 1,
				(color * math.random(1,32) / 8  ) % 1,
				1
			}

		end
	end
	love.graphics.points(points)
end

local drawBoxBackground = function(_frame, alpha, boxSize)
	local frame = _frame * 3

	local boxWidth = boxSize
	local boxHeight = boxSize
	local rMaxFrame = boxWidth * 4
	local rFrame = frame % rMaxFrame

	local adjustX = ((frame % (rMaxFrame * 2)) > rMaxFrame and 0 or -boxWidth) - map.scrollX
	local adjustY = ((frame % (rMaxFrame * 2)) > rMaxFrame and 0 or -boxHeight) - map.scrollY

	local adjustColor = (frame % (rMaxFrame * 2)) > rMaxFrame and 1 or 0.6
	love.graphics.setColor(
		adjustColor,
		adjustColor,
		1,
		alpha
	)
	for y = -boxHeight * 8, scr_y + boxHeight * 8, boxHeight * 2 do
		for x = (-boxWidth * 8) * boxWidth * 2 + (y % (boxHeight * 4) / 2), scr_x + boxWidth * 8, boxWidth * 2 do

			love.graphics.rectangle(
				"fill",
				x + (math.max(0, rFrame - boxWidth)) + adjustX,
				y + adjustY,
				boxWidth - math.max(0, (rFrame + boxWidth) - rMaxFrame) - math.max(0, -rFrame + boxWidth),
				boxHeight
			)
		end
	end
end

function love.draw()
	drawStaticBackground(game.meta.backgroundMod)
	drawBoxBackground(game.meta.backgroundMod, 0.05, 256)
	drawBoxBackground(game.meta.backgroundMod * 1.5, 0.04, 128)
	render()
	if game.editor.active then
		love.graphics.setColor(0.1, 1, 0.1, 0.05)
		love.graphics.rectangle("fill", 1, 1, scr_x, scr_x)
		love.graphics.setColor(0.1, 0.5, 0.1, 1)
		local ownerTbl = {
			[0] = "Neutral",
			[1] = "Red",
			[2] = "Blue"
		}
		love.graphics.print("Editor active. (Panel = " .. ownerTbl[game.editor.panel.owner] .. ")", 250, 15, 0, 4, 4)
	end
	-- debugging
	if true then
		local i = 1
		love.graphics.setColor(1, 1, 1, 1)
		for name, value in pairs(game.debug) do
			love.graphics.print(name .. " = " .. tostring(value), 5, i * 15 - 10)
			i = i + 1
		end
	end
end

local handleOccupiedPanels = function(id)
	local x, y

	for py, row in pairs(map.panels) do
		for px, panel in pairs(row) do
			panel.occupied = false
		end
	end

	for id, entity in pairs(map.entities) do
		x = entity.px + entity.meta.nextMoveX
		y = entity.py + entity.meta.nextMoveY
		if map.panels[y] then
			if map.panels[y][x] then
				map.panels[y][x].occupied = id
			end
		end
		if map.panels[entity.py] then
			map.panels[entity.py][entity.px].occupied = id
		end
	end
end

runTick = function(id) -- controlled player
	local player = map.entities[id]
	control = getControl()
	if player then
		if love.window.getFullscreen() then
			cameraDistance = {
				x = scr_x / 2.4,
				y = scr_y / 2.8
			}
		else
			cameraDistance = {
				x = scr_x / 2.4,
				y = scr_y / 3.3
			}
		end
		game.meta.backgroundMod = (game.meta.backgroundMod + 1) % 10000
		if game.editor.active then
			cameraControl()
		else
			handleOccupiedPanels(id)
			playerControl(id)
			
			for y, row in pairs(map.panels) do
				for x, panel in pairs(row) do
					
					panel.damageLife = math.max(0, panel.damageLife - 1)
					if panel.damageLife == 0 then
						panel.damage = 0
						panel.damageOwner = 0
					end
				end
			end
			
			local doDeleteProjectile
			for id, projectile in pairs(map.projectiles) do
				doDeleteProjectile = false
				projectile.frame = projectile.frame + 1
				projectile.px = projectile.px + projectile.speed / map.panelWidth
				local ppx, ppy
				if projectile.frame >= projectile.lifespan then
					map.projectiles[id] = nil
				else
					ppx, ppy = math.floor(projectile.px + 1), math.floor(projectile.py + 0.5)
					for eid, entity in pairs(p_act.getEntities(ppx, ppy)) do
						--error(entity)
						local panel = e_act.getPanel(entity)
						if panel.px == ppx and panel.py == ppy then
							local damage, owner = p_act.getDamage(ppx, ppy)
							if (damage > 0) and (owner ~= eid) then
								entity.health = entity.health - damage
								panel.damage = 0
								panel.damageOwner = 0
								doDeleteProjectile = true
								break
							end
						end
					end
					if doDeleteProjectile then
						map.projectiles[id] = nil
						--doDeleteProjectile = false
					else
						p_act.setDamage(ppx, ppy, projectile.damage, projectile.owner, projectile.damageLife)
					end
				end
			end
			-- check for dead people
			for id, entity in pairs(map.entities) do
				if entity.health <= 0 then
					map.entities[id] = nil
				end
			end
			-- camera movement
			player.x = player.px * map.panelWidth  + player.xadj - map.scrollX
			player.y = player.py * map.panelHeight + player.yadj - map.scrollY
			if player.cooldown.cameraMod == 0 then
				if player.x < cameraDistance.x then
					map.scrollX = map.scrollX - 32
					player.cooldown.cameraMod = player.maxCooldown.cameraMod
				elseif player.x > scr_x - (cameraDistance.x + images.player.stand:getWidth()) then
					map.scrollX = map.scrollX + 32
					player.cooldown.cameraMod = player.maxCooldown.cameraMod
				end
				if player.y < cameraDistance.y then
					map.scrollY = map.scrollY - 32
					player.cooldown.cameraMod = player.maxCooldown.cameraMod
				elseif player.y > scr_y - (cameraDistance.y + images.player.stand:getHeight()) then
					map.scrollY = map.scrollY + 32
					player.cooldown.cameraMod = player.maxCooldown.cameraMod
				end
			else
				player.cooldown.cameraMod = player.cooldown.cameraMod - 1
			end
		end
		game.debug = {
			["game.editor.message"] = game.editor.message,
			["player.px"] = player.px,
			["player.py"] = player.py,
			["game.editor.active"] = game.editor.active,
			["game.editor.panel.owner"] = game.editor.panel.owner,
			["#map.panels"] = #map.panels
		}
	end
end

function love.update()
	runTick(you)
end

local saveMap = function(map, path)
	local contents = cbor.encode(map)
	love.filesystem.write("map.cbor", contents)
	game.editor.message = "Saved to map.cbor"
end

local loadMap = function(path)
	if love.filesystem.getInfo(path) then
		local contents = love.filesystem.read(path)
		map = cbor.decode(contents)
		game.editor.message = "Loaded from map.cbor"
	end
end

--loadMap("map.cbor")

function love.keypressed( key, scancode, isrepeat )
	if game.editor.active then

		if key == "0" then
			game.editor.panel.owner = 0
		elseif key == "1" then
			game.editor.panel.owner = 1
		elseif key == "2" then
			game.editor.panel.owner = 2
		end

	end
	if not isrepeat then
		if key == "space" then
			game.editor.active = not game.editor.active
		elseif key == "f11" then
			love.window.setMode(1280, 720, {fullscreen = not love.window.getFullscreen()})
			scr_x, scr_y = love.graphics.getWidth(), love.graphics.getHeight()
		elseif key == "o" then
			saveMap(map, "map.cbor")
		elseif key == "p" then
			loadMap("map.cbor")
		end
	end
end

local mouseActions = function(x, y, button)
	if game.editor.active then
		local px = math.floor((x - (map.panelWidth * 0) + map.scrollX) / map.panelWidth)
		local py = math.floor((y - (map.panelHeight * 0) + map.scrollY) / map.panelHeight)
		if button == 1 then
			map.panels[py] = map.panels[py] or {}
			map.panels[py][px] = newPanel(
				px,
				py,
				game.editor.panel.panelType,
				game.editor.panel.owner,
				game.editor.panel.crackLevel,
				game.editor.panel.elevation
			)
		elseif button == 2 then
			if map.panels[py] then
				map.panels[py][px] = nil
			end
		elseif button == 3 then
			map.entities[you].px = px
			map.entities[you].py = py
		end
	end
end

function love.mousepressed( x, y, button, istouch, presses )
	mouseActions(x, y, button)
end

function love.mousemoved( x, y, dx, dy, istouch )
	if love.mouse.isDown(1) then
		mouseActions(x, y, 1)
	elseif love.mouse.isDown(2) then
		mouseActions(x, y, 2)
	end
end
