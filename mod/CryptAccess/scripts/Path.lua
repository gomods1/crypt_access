-- Route finding over the tiles the player knows (breadth-first, four directions).
-- Walls block unless the player can dig them (digging costs extra steps); doors are passable;
-- unknown tiles block. N speaks the route to the scanner's selected thing as segments:
-- "3 right, 2 down, dig 1 up". The beacon sounds from the route's next turning point.

local Tile = require("necro.game.tile.Tile")
local Collision = require("necro.game.tile.Collision")

local Keys = require("CryptAccess.Keys")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local World = require("CryptAccess.World")

local Path = {}

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local MAX_NODES = 6000

local trapTiles = {}

--- Visible traps: routes avoid them (a trap tile costs 10 steps).
local function collectTraps()
	trapTiles = {}
	local Entities = require("system.game.Entities")
	for e in Entities.entitiesWithComponents({ "trap", "position" }) do
		if World.category(e) == "trap" and World.isVisible(e) then
			trapTiles[e.position.x .. "," .. e.position.y] = true
		end
	end
end

--- Cost to enter a tile: 1 floor, 3 diggable wall, 10 trap, nil blocked.
local function cost(x, y, digStrength, tx, ty)
	if x == tx and y == ty then
		return 1
	end
	if not World.isTileKnown(x, y) then
		return nil
	end
	local ok, info = pcall(Tile.getInfo, x, y)
	if not ok or type(info) ~= "table" or not info.name then
		return nil
	end
	if info.isDoor then
		return 1
	end
	if info.isWall or info.isLocked then
		local r = info.digResistance
		if info.isWall and r and r ~= false and r <= digStrength and bit.band(info.collision or 0, Collision.Type.BORDER) == 0 then
			return 3
		end
		return nil
	end
	if info.stepDamage then
		return 8 -- lava: only if there is no other way
	end
	if trapTiles[x .. "," .. y] then
		return 10
	end
	return 1
end

--- Returns a list of {x, y, dig} steps from the player to (tx, ty), or nil.
--- With goal (a function x, y -> bool) instead of a target, stops at the nearest tile it accepts.
function Path.find(tx, ty, goal)
	local px, py = World.playerPosition()
	if not px then
		return nil
	end
	local digStrength = World.digStrength()
	collectTraps()
	local key = function(x, y)
		return x .. "," .. y
	end
	-- Dijkstra with small integer costs: buckets by distance.
	local dist = { [key(px, py)] = 0 }
	local prev = {}
	local buckets = { [0] = { { px, py } } }
	local d, maxD, visited = 0, 0, 0
	while d <= maxD do
		local bucket = buckets[d]
		if bucket then
			for _, node in ipairs(bucket) do
				local x, y = node[1], node[2]
				local k = key(x, y)
				if dist[k] == d then
					visited = visited + 1
					if visited > MAX_NODES then
						return nil
					end
					if (goal and d > 0 and goal(x, y)) or (not goal and x == tx and y == ty) then
						local steps = {}
						while prev[k] do
							local p = prev[k]
							table.insert(steps, 1, { x = x, y = y, dig = p.dig })
							x, y = p.x, p.y
							k = key(x, y)
						end
						return steps
					end
					for _, dir in ipairs(DIRS) do
						local nx, ny = x + dir[1], y + dir[2]
						local c = cost(nx, ny, digStrength, tx, ty)
						if c then
							local nk = key(nx, ny)
							local nd = d + c
							if dist[nk] == nil or nd < dist[nk] then
								dist[nk] = nd
								prev[nk] = { x = x, y = y, dig = c == 3 }
								buckets[nd] = buckets[nd] or {}
								table.insert(buckets[nd], { nx, ny })
								if nd > maxD then
									maxD = nd
								end
							end
						end
					end
				end
			end
		end
		d = d + 1
	end
	return nil
end

local function dirKey(dx, dy)
	if dx > 0 then
		return "right"
	elseif dx < 0 then
		return "left"
	elseif dy > 0 then
		return "down"
	end
	return "up"
end

--- Groups steps into runs: { {dir="right", n=3, dig=false}, ... }.
function Path.segments(steps)
	local px, py = World.playerPosition()
	local segments = {}
	local x, y = px, py
	for _, step in ipairs(steps) do
		local dir = dirKey(step.x - x, step.y - y)
		local last = segments[#segments]
		if last and last.dir == dir and not step.dig and not last.dig then
			last.n = last.n + 1
		else
			segments[#segments + 1] = { dir = dir, n = 1, dig = step.dig, x = step.x, y = step.y }
		end
		segments[#segments].endX, segments[#segments].endY = step.x, step.y
		x, y = step.x, step.y
	end
	return segments
end

function Path.describe(segments, limit)
	local parts = {}
	for i, seg in ipairs(segments) do
		if limit and i > limit then
			parts[#parts + 1] = Strings.get("path.more", { n = #segments - limit })
			break
		end
		local key = seg.dig and "path.dig" or "path.walk"
		parts[#parts + 1] = Strings.get(key, { n = seg.n, dir = Strings.get("dirname." .. seg.dir) })
	end
	return table.concat(parts, ", ")
end

--- The first turning point of the route to (tx, ty), for the beacon.
function Path.nextWaypoint(tx, ty)
	local steps = Path.find(tx, ty)
	if not steps or #steps == 0 then
		return nil
	end
	local segments = Path.segments(steps)
	return segments[1].endX, segments[1].endY, #steps
end

--- A known, walkable tile next to an unknown one: the edge of the explored map.
local function isFrontier(x, y)
	if World.isBlocking(x, y) then
		return false
	end
	for _, dir in ipairs(DIRS) do
		if not World.isTileKnown(x + dir[1], y + dir[2]) then
			return true
		end
	end
	return false
end

local frontier = false

--- The nearest unexplored edge, as a scanner-like target {x, y, name}.
function Path.frontierTarget()
	local steps = Path.find(nil, nil, isFrontier)
	if not steps or #steps == 0 then
		return nil
	end
	local last = steps[#steps]
	return { x = last.x, y = last.y, name = Strings.get("path.unexplored"), category = "frontier", steps = steps }
end

function Path.speakFrontier()
	local target = Path.frontierTarget()
	if not target then
		frontier = false
		Speech.say(Strings.get("path.allExplored"), true)
		return
	end
	frontier = target
	frontier.time = require("system.utils.Timer").getGlobalTime()
	Speech.say(Strings.get("path.route", { name = target.name, route = Path.describe(Path.segments(target.steps), 6) }), true)
end

--- The last unexplored target spoken with U (the beacon can follow it).
function Path.lastFrontier()
	return frontier or nil
end

function Path.speakRoute()
	local Scanner = require("CryptAccess.Scanner")
	local target = Scanner.selected()
	if not target then
		Speech.say(Strings.get("beacon.noTarget"), true)
		return
	end
	local steps = Path.find(target.x, target.y)
	if not steps then
		Speech.say(Strings.get("path.none", { name = target.name }), true)
		return
	end
	if #steps == 0 then
		Speech.say(Strings.get("dir.here"), true)
		return
	end
	Speech.say(Strings.get("path.route", { name = target.name, route = Path.describe(Path.segments(steps), 6) }), true)
end

Keys.bind({ key = "n", id = "path", when = World.playing, fn = Path.speakRoute })
Keys.bind({ key = "u", id = "unexplored", when = World.playing, fn = Path.speakFrontier })

return Path
