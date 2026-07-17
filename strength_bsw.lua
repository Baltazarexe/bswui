-- ============================================================
--  BSW HUB - AUTO STRENGTH TRAINING (VeilUI v2.2)
--  made by baltazar.exe
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = game:GetService("Players").LocalPlayer

local NetworkFunctions = ReplicatedStorage["shared/network@globalFunctions"]
local NetworkEvents = ReplicatedStorage["shared/network@globalEvents"]

local SkillcheckRemote = NetworkFunctions.trainingSkillcheckBonus
local BoostButtonRemote = NetworkEvents.analyticsBoostButtonClicked

local Config = {
	AutoSkillcheck = false,
	SkillcheckValue = 37,   -- untested guess; tweak in-game until bonus lands
	SkillcheckDelay = 0.3,
	AutoBoost = false,
	BoostDelay = 1.0,
	AntiAFK = true,
}

local stats = { skillchecks = 0, boosts = 0, session = os.clock() }

local Window

-- ============================================================
--  AUTO SKILLCHECK
-- ============================================================
task.spawn(function()
	while true do
		task.wait(Config.SkillcheckDelay)
		if Config.AutoSkillcheck then
			local ok = pcall(function()
				SkillcheckRemote:FireServer(Config.SkillcheckValue)
			end)
			if ok then stats.skillchecks = stats.skillchecks + 1 end
		end
	end
end)

-- ============================================================
--  AUTO BOOST 2x BUTTON
-- ============================================================
task.spawn(function()
	while true do
		task.wait(Config.BoostDelay)
		if Config.AutoBoost then
			local ok = pcall(function()
				BoostButtonRemote:FireServer()
			end)
			if ok then stats.boosts = stats.boosts + 1 end
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
	Subtitle = "Strength Training",
	Theme = "Balta",
	Transparency = 0.06,
	Blur = false,
	HideName = false,
	ToggleKey = Enum.KeyCode.RightShift,
	ConfigurationSaving = { Enabled = true, FolderName = "BSWHub", FileName = "StrengthConfig" },
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

MainTab:CreateSection("Training")
MainTab:CreateToggle({
	Name = "Auto Skillcheck",
	Description = "Automatically fires the training skillcheck bonus",
	Flag = "AutoSkillcheck",
	CurrentValue = Config.AutoSkillcheck,
	Callback = function(v) Config.AutoSkillcheck = v end,
})

MainTab:CreateSlider({
	Name = "Skillcheck Value",
	Description = "Value sent to trainingSkillcheckBonus (tweak until bonus lands consistently)",
	Range = { 0, 100 },
	Increment = 1,
	CurrentValue = Config.SkillcheckValue,
	Flag = "SkillcheckValue",
	Callback = function(v) Config.SkillcheckValue = v end,
})

MainTab:CreateSlider({
	Name = "Skillcheck Delay",
	Range = { 0.1, 2 },
	Increment = 0.1,
	Suffix = "s",
	CurrentValue = Config.SkillcheckDelay,
	Flag = "SkillcheckDelay",
	Callback = function(v) Config.SkillcheckDelay = v end,
})

MainTab:CreateSection("Boost")
MainTab:CreateToggle({
	Name = "Auto Click 2x Boost",
	Description = "Automatically clicks the 2x boost button",
	Flag = "AutoBoost",
	CurrentValue = Config.AutoBoost,
	Callback = function(v) Config.AutoBoost = v end,
})

MainTab:CreateSlider({
	Name = "Boost Click Delay",
	Range = { 0.2, 5 },
	Increment = 0.1,
	Suffix = "s",
	CurrentValue = Config.BoostDelay,
	Flag = "BoostDelay",
	Callback = function(v) Config.BoostDelay = v end,
})

MainTab:CreateSection("General")
MainTab:CreateToggle({
	Name = "Anti AFK",
	Flag = "AntiAFK",
	CurrentValue = Config.AntiAFK,
	Callback = function(v) Config.AntiAFK = v end,
})

-- ── INFO TAB ─────────────────────────────────────────────
local InfoTab = Window:CreateTab("Info")
InfoTab:CreateParagraph({
	Title = "BSW Hub - Strength Training",
	Content = "Automatic script for the training skillcheck + 2x boost button. Configure options above.",
})

InfoTab:CreateDivider()
InfoTab:CreateLabel("v1.0 | BSW UI")

Window:Notify({ Title = "Loaded", Content = "BSW Strength Training started successfully.", Type = "Success" })
