-- ============================================================
--  BSW HUB - MINE WORLD (VeilUI v2.2)
--  made by baltazar.exe
--  migrate: use VeilUI instead of Rayfield
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Net = ReplicatedStorage:WaitForChild("Net", 10)
local CollectDockOre = Net and Net:WaitForChild("RequestCollectDockOre", 10)

local Config = {
	AutoCollect = false,
	CollectRate = 20,   -- fires per second
	CycleDelay = 0.1,   -- pause between full dockMin..dockMax sweeps
	DockMin = 1,
	DockMax = 22,
	AutoSell = false,
	SellDelay = 1,
}

local Window

-- ============================================================
--  SELL PROMPT
-- ============================================================
-- The sell is a ProximityPrompt ("Sell All") on your own platform, not a
-- remote: workspace.FarmStar.Platforms[yourUserId] ... FS_SellPrompt.
-- Cached, and re-resolved if the platform is rebuilt.
local sellPrompt
local function getSellPrompt()
	if sellPrompt and sellPrompt.Parent then
		return sellPrompt
	end
	sellPrompt = nil
	local farmStar = workspace:FindFirstChild("FarmStar")
	local platforms = farmStar and farmStar:FindFirstChild("Platforms")
	local myPlatform = platforms and platforms:FindFirstChild(tostring(LocalPlayer.UserId))
	if not myPlatform then return nil end
	for _, d in ipairs(myPlatform:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Name == "FS_SellPrompt" then
			sellPrompt = d
			break
		end
	end
	return sellPrompt
end

task.spawn(function()
	while true do
		if Config.AutoSell then
			local prompt = getSellPrompt()
			if prompt and typeof(fireproximityprompt) == "function" then
				pcall(function()
					fireproximityprompt(prompt)
				end)
			end
		end
		task.wait(Config.SellDelay)
	end
end)

-- ============================================================
--  AUTO COLLECT DOCK ORE
-- ============================================================
task.spawn(function()
	while true do
		if Config.AutoCollect and CollectDockOre then
			local perFireDelay = 1 / math.max(Config.CollectRate, 1)
			for i = Config.DockMin, Config.DockMax do
				if not Config.AutoCollect then break end
				pcall(function()
					CollectDockOre:FireServer({ dockIndex = i })
				end)
				task.wait(perFireDelay)
			end
		end
		task.wait(Config.CycleDelay)
	end
end)

-- ============================================================
--  UI VEIL
-- ============================================================
local Veil
local ok = pcall(function()
	Veil = loadstring(game:HttpGet("https://raw.githubusercontent.com/Baltazarexe/bswui/main/uilib.lua"))()
end)

if not ok or not Veil then
	warn("[BSW] VeilUI failed to load")
	return
end

if not CollectDockOre then
	warn("[BSW] RequestCollectDockOre not found")
end

local DISCORD_LINK = "https://discord.gg/2aHSqGXj9u"

Window = Veil.CreateWindow({
	Title = "BSW Hub",
	Subtitle = "Mine World",
	Theme = "Balta",
	Transparency = 0.06,
	Blur = false,
	HideName = false,
	ToggleKey = Enum.KeyCode.K,
	ConfigurationSaving = { Enabled = true, FolderName = "BSWHub", FileName = "MineWorldConfig" },
})

-- ── MAIN TAB ─────────────────────────────────────────────
local MainTab = Window:CreateTab("Main")
MainTab:CreateButton({
	Name = "Join Discord",
	Description = "Copy Discord invite link",
	Callback = function()
		if typeof(setclipboard) == "function" then
			setclipboard(DISCORD_LINK)
			Window:Notify({ Title = "Copied!", Content = "Discord link copied to clipboard.", Type = "Success" })
		end
	end,
})

MainTab:CreateSection("General")
MainTab:CreateKeybind({
	Name = "Menu Toggle Key",
	CurrentKeybind = "K",
	Flag = "MenuToggleKey",
	Callback = function(key)
		Window:SetToggleKey(key)
	end,
})

MainTab:CreateSection("Dock Ore")
MainTab:CreateToggle({
	Name = "Auto Collect Dock Ore",
	Flag = "AutoCollect",
	CurrentValue = Config.AutoCollect,
	Callback = function(v) Config.AutoCollect = v end,
})

MainTab:CreateSection("Selling")
MainTab:CreateToggle({
	Name = "Auto Sell",
	Description = "Fires the Sell All prompt on your platform",
	Flag = "AutoSell",
	CurrentValue = Config.AutoSell,
	Callback = function(v) Config.AutoSell = v end,
})

-- ── INFO TAB ─────────────────────────────────────────────
local InfoTab = Window:CreateTab("Info")
InfoTab:CreateParagraph({
	Title = "BSW Hub - Mine World",
	Content = "Automatic script for Mine World. Configure options above.",
})

InfoTab:CreateDivider()
InfoTab:CreateLabel("v1.0 | BSW UI")

Window:Notify({ Title = "Loaded", Content = "BSW Mine World started successfully.", Type = "Success" })
