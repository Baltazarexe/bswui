-- ============================================================
--  BSW HUB - ORE INCREMENTAL (VeilUI v2.2)
--  made by baltazar.exe
--  migrate: use VeilUI instead of WindUI
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local ByteNetReliable = ReplicatedStorage:WaitForChild("ByteNetReliable", 10)
local UpgradeService = ReplicatedStorage
	:WaitForChild("Packages", 10)
	:WaitForChild("_Index", 10)
	:FindFirstChild("sleitnick_knit@1.7.0")
local BuyMaxUpgrade = UpgradeService
	and UpgradeService.knit.Services.UpgradeService.RE.BuyMaxUpgrade

local Config = {
	AutoTpOres = false,
	OreTpDelay = 0.3,
	AutoClickerBeach = false,
	AutoDropperCave = false,
	AutoFireStone = false,
	ClickDelay = 0.1,
	AntiAFK = true,
}

local Window

-- ============================================================
--  AUTO TP ORES
-- ============================================================
local function getRoot()
	local char = LocalPlayer.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

task.spawn(function()
	while true do
		if Config.AutoTpOres then
			local root = getRoot()
			local folder = workspace:FindFirstChild("SpawnedOres")
			if root and folder then
				for _, obj in ipairs(folder:GetChildren()) do
					if not Config.AutoTpOres then break end

					local part
					if obj:IsA("BasePart") then
						part = obj
					elseif obj:IsA("Model") then
						part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
					end

					if part then
						root.CFrame = CFrame.new(part.Position + Vector3.new(0, 8, 0))
						task.wait(Config.OreTpDelay)
					end
				end
			end
		end
		task.wait(1)
	end
end)

-- ============================================================
--  AUTO CLICKER (BEACH / CAVE DROPPER / UNDERWORLD FIRESTONE)
-- ============================================================
task.spawn(function()
	while true do
		task.wait(Config.ClickDelay)
		if Config.AutoClickerBeach and ByteNetReliable then
			pcall(function()
				ByteNetReliable:FireServer(buffer.fromstring("+"), nil)
			end)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.ClickDelay)
		if Config.AutoDropperCave and ByteNetReliable then
			pcall(function()
				ByteNetReliable:FireServer(buffer.fromstring("\x1F\f\x00ClickDropper"), nil)
			end)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.ClickDelay)
		if Config.AutoFireStone and ByteNetReliable then
			pcall(function()
				ByteNetReliable:FireServer(buffer.fromstring("-\v\x00Fire Stones"), nil)
			end)
		end
	end
end)

-- ============================================================
--  ANTI AFK
-- ============================================================
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
	if not Config.AntiAFK then return end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)

-- ============================================================
--  TELEPORTS (RUNES)
-- ============================================================
local RUNES = {
	{ Name = "Basic Rune", Pos = Vector3.new(-88, 9, 405) },
	{ Name = "Rebirth Rune", Pos = Vector3.new(-167, 9, 445) },
	{ Name = "Core Rune", Pos = Vector3.new(-306, 7, -261) },
	{ Name = "Prestige Rune", Pos = Vector3.new(-273, 7, -138) },
	{ Name = "Clicker Rune", Pos = Vector3.new(51, 9, -53) },
	{ Name = "Ascension Rune", Pos = Vector3.new(-51, 9, 78) },
	{ Name = "Gem Rune", Pos = Vector3.new(323, -100, 272) },
	{ Name = "Sacrifice Rune", Pos = Vector3.new(394, -100, 366) },
}

local function tpToPos(pos)
	local root = getRoot()
	if not root then return false end
	root.CFrame = CFrame.new(pos)
	return true
end

-- ============================================================
--  UPGRADES
-- ============================================================
local UPGRADES = {
	{ Name = "Max Ores Multiplier", Key = "Cubes Multiplier" },
	{ Name = "Max Faster Spawning", Key = "Faster Spawning" },
	{ Name = "Max Ore Capacity", Key = "Cubes Capacity" },
	{ Name = "Max Clicks Amount", Key = "Clicks Amount" },
	{ Name = "Max Crit Click Chance", Key = "Critical Click Chance" },
	{ Name = "Max Crit Click Multiplier", Key = "Critical Click Multiplier" },
	{ Name = "Max Auto Clicker", Key = "Auto Clicker" },
}

local function buyMaxUpgrade(key)
	if not BuyMaxUpgrade then return false end
	local ok = pcall(function()
		BuyMaxUpgrade:FireServer(key)
	end)
	return ok
end

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

local DISCORD_LINK = "https://discord.gg/2aHSqGXj9u"

Window = Veil.CreateWindow({
	Title = "BSW Hub",
	Subtitle = "Ore Incremental",
	Theme = "Balta",
	Transparency = 0.06,
	Blur = false,
	HideName = false,
	ToggleKey = Enum.KeyCode.K,
	ConfigurationSaving = { Enabled = true, FolderName = "BSWHub", FileName = "OreConfig" },
})

-- ── MAIN TAB ─────────────────────────────────────────────
local MainTab = Window:CreateTab("Main")

MainTab:CreateSection("Ores")
MainTab:CreateToggle({
	Name = "Auto Teleport Ores",
	Description = "Teleports to spawned ores automatically",
	Flag = "AutoTpOres",
	CurrentValue = Config.AutoTpOres,
	Callback = function(v) Config.AutoTpOres = v end,
})

MainTab:CreateSlider({
	Name = "Ore TP Delay",
	Range = { 0.05, 1 },
	Increment = 0.05,
	Suffix = "s",
	CurrentValue = Config.OreTpDelay,
	Flag = "OreTpDelay",
	Callback = function(v) Config.OreTpDelay = v end,
})

MainTab:CreateSection("Auto Clickers")
MainTab:CreateToggle({
	Name = "Auto Clicker (Beach)",
	Description = "Auto clicks in the beach map",
	Flag = "AutoClickerBeach",
	CurrentValue = Config.AutoClickerBeach,
	Callback = function(v) Config.AutoClickerBeach = v end,
})

MainTab:CreateToggle({
	Name = "Auto Dropper (Cave)",
	Description = "Auto clicks the dropper in the cave",
	Flag = "AutoDropperCave",
	CurrentValue = Config.AutoDropperCave,
	Callback = function(v) Config.AutoDropperCave = v end,
})

MainTab:CreateToggle({
	Name = "Auto FireStone (Underworld)",
	Description = "Auto clicks Firestone in the underworld",
	Flag = "AutoFireStone",
	CurrentValue = Config.AutoFireStone,
	Callback = function(v) Config.AutoFireStone = v end,
})

MainTab:CreateSlider({
	Name = "Click Delay",
	Range = { 0.05, 1 },
	Increment = 0.05,
	Suffix = "s",
	CurrentValue = Config.ClickDelay,
	Flag = "ClickDelay",
	Callback = function(v) Config.ClickDelay = v end,
})

-- ── TELEPORTS TAB ────────────────────────────────────────
local TeleportTab = Window:CreateTab("Teleports")
TeleportTab:CreateSection("Runes")
for _, rune in ipairs(RUNES) do
	TeleportTab:CreateButton({
		Name = rune.Name,
		Description = "Teleports you to " .. rune.Name,
		Callback = function()
			if tpToPos(rune.Pos) then
				Window:Notify({ Title = "Teleport", Content = "Teleported to " .. rune.Name, Type = "Success" })
			end
		end,
	})
end

-- ── UPGRADES TAB ─────────────────────────────────────────
local UpgradesTab = Window:CreateTab("Upgrades")
UpgradesTab:CreateSection("Max Upgrades")
for _, upgrade in ipairs(UPGRADES) do
	UpgradesTab:CreateButton({
		Name = upgrade.Name,
		Description = "Upgrades " .. upgrade.Key .. " to max",
		Callback = function()
			local success = buyMaxUpgrade(upgrade.Key)
			Window:Notify({
				Title = "Upgrade",
				Content = success and (upgrade.Key .. " maxed!") or "Failed to upgrade",
				Type = success and "Success" or "Error",
			})
		end,
	})
end

-- ── INFO TAB ─────────────────────────────────────────────
local InfoTab = Window:CreateTab("Info")
InfoTab:CreateParagraph({
	Title = "BSW Hub - Ore Incremental",
	Content = "Automatic script for Ore Incremental. Configure options in the tabs above.",
})

InfoTab:CreateSection("General")
InfoTab:CreateToggle({
	Name = "Anti AFK",
	Flag = "AntiAFK",
	CurrentValue = Config.AntiAFK,
	Callback = function(v) Config.AntiAFK = v end,
})

InfoTab:CreateKeybind({
	Name = "Menu Toggle Key",
	CurrentKeybind = "K",
	Flag = "MenuToggleKey",
	Callback = function(key)
		Window:SetToggleKey(key)
	end,
})

InfoTab:CreateToggle({
	Name = "Hide Name",
	Description = "Hides your display name/username in the sidebar",
	Flag = "HideNameToggle",
	CurrentValue = false,
	Callback = function(v) Window:SetNameHidden(v) end,
})

InfoTab:CreateButton({
	Name = "Join Discord",
	Description = "Copy Discord invite link",
	Callback = function()
		if typeof(setclipboard) == "function" then
			setclipboard(DISCORD_LINK)
			Window:Notify({ Title = "Copied!", Content = "Discord link copied to clipboard.", Type = "Success" })
		end
	end,
})

InfoTab:CreateDivider()
InfoTab:CreateLabel("v1.0 | BSW UI")

Window:Notify({ Title = "Loaded", Content = "BSW Ore Incremental started successfully.", Type = "Success" })
