-- ============================================================
--  BSW HUB - MAIN LOADER
--  Detect game PlaceId and load the correct script
--
--  HOW TO USE:
--  1. Paste this entire script into your executor (Wave, Synapse, etc)
--  2. It automatically detects which game you are in and loads the script
--  3. Settings are saved locally in VeilUI/config
--
--  HOSTING:
--  Change the BASE_URL below to point to your site
--  Ex: https://baltasoftware.com/scripts/
-- ============================================================

-- GitHub raw base URL
local BASE_URL = "https://raw.githubusercontent.com/Baltazarexe/bswui/main/"

-- Mapping: PlaceId -> script (without .lua)
local GAME_MAP = {
	[79268393072444] = "lemon_bsw",      -- Lemon Tycoon
	[121125129560252] = "mineworld_bsw", -- Mine World
	-- [123456789] = "fish_bsw",          -- Fishing Simulator (example)
	-- [987654321] = "slime_bsw",         -- Slime Farm (example)
	-- [111111111] = "sw_bsw",            -- Sword Warriors (example)
	-- add more games here
}

local PlaceId = tostring(game.PlaceId)
local scriptName = GAME_MAP[tonumber(PlaceId)]

if not scriptName then
	warn("[BSW] PlaceId not found: " .. PlaceId)
	warn("[BSW] Available games:")
	for pid, name in pairs(GAME_MAP) do
		warn("  " .. pid .. " -> " .. name)
	end
	return
end

-- Try to load from site (hosted) or fallback to local file
local scriptUrl = BASE_URL .. scriptName .. ".lua"
local scriptContent

-- Try HttpGet first (hosted on internet)
local ok = pcall(function()
	if typeof(game.HttpGet) == "function" then
		scriptContent = game:HttpGet(scriptUrl)
	end
end)

-- Fallback: try local file if HttpGet fails
if not ok or not scriptContent then
	warn("[BSW] Failed to load from " .. scriptUrl)
	warn("[BSW] Trying to load local file: " .. scriptName .. ".lua")

	pcall(function()
		scriptContent = readfile(scriptName .. ".lua")
	end)
end

if not scriptContent then
	warn("[BSW] ERROR: Could not load script from any source")
	warn("[BSW] Make sure the file exists on the site or in the local folder")
	return
end

-- Execute the script
local success, err = pcall(function()
	loadstring(scriptContent)()
end)

if not success then
	warn("[BSW] ERROR executing script: " .. tostring(err))
else
	print("[BSW] Script loaded successfully!")
end
