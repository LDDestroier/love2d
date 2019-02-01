love.window.setMode(1280, 720)

local scr_x, scr_y = love.graphics.getWidth(), love.graphics.getHeight()
local mx, my = scr_x, scr_y

local mainDir = "data/"
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
	debug = {}, -- messages in top left corner of screen
}

cbor = require(game.dir.lib .. "cbor")

local control = {
	moveUp = "w",
	moveDown = "s",
	moveRight = "d",
	moveLeft = "a",
}

local player = {
	x = 0,				-- onscreen X
	y = 0,				-- onscreen Y
	xadj = 3,			-- adjust sprite X
	yadj = -175,		-- adjust sprite Y
	px = 2,				-- panel-grid X
	py = 2,				-- panel-grid Y
	state = "normal",	-- normal, hurt, etc.
	health = 1000,
	aura = 0,
	name = "Player",
	status = {				-- statuses are set to numbers indicating their duration
		stunned = 0,		-- stunned and unable to move
		grounded = 0,		-- mashed into ground
		angry = 0,			-- deals double damage
	},
	tint = {
		1,					-- red
		1,					-- green
		1,					-- blue
		1					-- alpha
	},
	cooldown = {			-- cooldown for specific actions
		move = 0,
		cameraMod = 0
	},
	maxCooldown = {
		move = 10,
		cameraMod = 1
	},
	meta = {				-- other player-specific values, like for animation
		playerBob = 0,		-- 0-360 value for bobbing the player up and down
		stretchX = 1,		-- multiplier for sprite width (origin = center)
		stretchY = 1,		-- multiplier for sprite height (origin = bottom)
		doRender = true,	-- whether or not to draw the player sprite
		nextMoveX = 0,
		nextMoveY = 0,
	},
	loadout = {
		[1] = nil,
		[2] = nil,
		[3] = nil,
		[4] = nil
	},
	folder = {}
}

local map = {
	panels = {},
	scrollX = -74,
	scrollY = -40,
	zoom = 100,
	panelWidth = 128,
	panelHeight = 64
}

local images = {
	panel = {
		normal = love.graphics.newImage(game.dir.images .. "panels/normal.png"),
	},
	player = {
		stand = love.graphics.newImage(game.dir.images .. "entities/player/stand.png")
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
		elevation = elevation or 0
	}
end

local isPositionWalkable = function(px, py)
	local output = false
	if map.panels[py] then
		if map.panels[py][px] then
			if map.panels[py][px].crackLevel ~= 2 then
				if map.panels[py][px].owner ~= 2 then
					output = true
				end
			end
		end
	end
	return output
end

-- make demo map
for y = 1, 3 do
	map.panels[y] = {}
	for x = 1, 6 do
		map.panels[y][x] = newPanel(x, y, "normal",

		(x <= 2 and
			1
		or x >= 5 and
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

						if map.panels[y][x].owner == 1 then
							love.graphics.setColor(1, 0.75, 0.75, (not game.editor.active and love.keyboard.isDown("1")) and 0.25 or 1)
						elseif map.panels[y][x].owner == 2 then
							love.graphics.setColor(0.75, 0.75, 1, (not game.editor.active and love.keyboard.isDown("3")) and 0.25 or 1)
						else
							love.graphics.setColor(1, 1, 1, (not game.editor.active and love.keyboard.isDown("2")) and 0.25 or 1)
						end

						if math.random(1, 4) == 1 then
							-- fluxuate panel colors slightly
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
	-- draw player
	if player.meta.doRender then
		love.graphics.setColor(1, 1, 1, love.keyboard.isDown("space") and 0.25 or 1)
		local bobMult = math.sin(math.rad(player.meta.playerBob) * 1) * 0.05 + 0.05
		love.graphics.setColor(player.tint[1], player.tint[2], player.tint[3], player.tint[4])
		love.graphics.draw(
			images.player.stand,
			player.px * map.panelWidth + player.xadj - map.scrollX - (0.5 * (player.meta.stretchX - 1) * images.player.stand:getWidth()),
			player.py * map.panelHeight + player.yadj - map.scrollY + (bobMult * images.player.stand:getHeight()),
			0,
			player.meta.stretchX,
			player.meta.stretchY - bobMult
		)
	end
end

local anims = {
	moveCompress = function(player, step, maxStep)
		player.meta.stretchX = math.abs(maxStep - (2 * step)) / maxStep
		player.tint[4] = math.abs(maxStep - (2 * step)) / maxStep + 0.5
		player.tint[1] = math.abs(maxStep - (2 * step)) / maxStep
		player.tint[2] = math.abs(maxStep - (2 * step)) / maxStep
		player.tint[3] = math.abs(maxStep - (2 * step)) / maxStep
	end,
}

local playerControl = function(player)
	-- player movement
	anims.moveCompress(player, player.cooldown.move, player.maxCooldown.move)
	if player.cooldown.move == 0 then
		player.nextMoveX = 0
		player.nextMoveY = 0
		repeat
			if love.keyboard.isDown(control.moveUp) then
				player.nextMoveY = -1
				player.cooldown.move = player.maxCooldown.move
			end
			if love.keyboard.isDown(control.moveDown) then
				player.nextMoveY = 1
				player.cooldown.move = player.maxCooldown.move
			end
			if love.keyboard.isDown(control.moveRight) then
				player.nextMoveX = 1
				player.cooldown.move = player.maxCooldown.move
			end
			if love.keyboard.isDown(control.moveLeft) then
				player.nextMoveX = -1
				player.cooldown.move = player.maxCooldown.move
			end
		until true
		if not isPositionWalkable(player.nextMoveX + player.px, player.nextMoveY + player.py) then
			player.cooldown.move = 0
		end
	else
		if player.cooldown.move == player.maxCooldown.move / 2 then
			if isPositionWalkable(player.nextMoveX + player.px, player.nextMoveY + player.py) then
				player.px = player.px + player.nextMoveX
				player.py = player.py + player.nextMoveY
			end
		end
		player.cooldown.move = player.cooldown.move - 1
	end
end

local cameraControl = function()
	if love.keyboard.isDown(control.moveRight) then
		map.scrollX = map.scrollX + 5
	end
	if love.keyboard.isDown(control.moveLeft) then
		map.scrollX = map.scrollX - 5
	end
	if love.keyboard.isDown(control.moveUp) then
		map.scrollY = map.scrollY - 5
	end
	if love.keyboard.isDown(control.moveDown) then
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

function love.update()
	if love.window.getFullscreen() then
		cameraDistance = {
			x = scr_x / 2.4,
			y = scr_y / 2.8
		}
	else
		cameraDistance = {
			x = scr_x / 4,
			y = scr_y / 4
		}
	end
	game.meta.backgroundMod = (game.meta.backgroundMod + 1) % 10000
	player.meta.playerBob = (player.meta.playerBob + 1) % 360
	if game.editor.active then
		cameraControl()
	else
		playerControl(player)
		-- camera movement
		player.x = player.px * map.panelWidth + player.xadj - map.scrollX
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

function love.keypressed( key, scancode, isrepeat )
	if game.editor.active then

		if key == "0" then
			game.editor.panel.owner = 0
		elseif key == "1" then
			game.editor.panel.owner = 1
		elseif key == "2" then
			game.editor.panel.owner = 2
		end

		if key == "o" then
			local contents = cbor.encode(map)
			love.filesystem.write("map.cbor", contents)
			game.editor.message = "Saved to map.cbor"
		elseif key == "p" then
			local contents = love.filesystem.read("map.cbor")
			map = cbor.decode(contents)
			game.editor.message = "Loaded from map.cbor"
		end
	end
	if not isrepeat then
		if key == "space" then
			game.editor.active = not game.editor.active
		elseif key == "f11" then
			love.window.setMode(1280, 720, {fullscreen = not love.window.getFullscreen()})
			scr_x, scr_y = love.graphics.getWidth(), love.graphics.getHeight()
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
			player.px = px
			player.py = py
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
