-- ============================================================
--  BSW HUB - AUTO STRENGTH TRAINING (VeilUI v2.2)
--  made by baltazar.exe
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = game:GetService("Players").LocalPlayer

local NetworkFunctions = ReplicatedStorage["shared/network@globalFunctions"]
local NetworkEvents = ReplicatedStorage["shared/network@globalEvents"]

-- captured via Cobalt: these are all RemoteEvents (FireServer), not RemoteFunctions
local TrainingTickRemote = NetworkFunctions.trainingTick
local SkillcheckRemote = NetworkFunctions.trainingSkillcheckBonus
local BoostButtonRemote = NetworkEvents.analyticsBoostButtonClicked

local Config = {
	AutoTrain = false,
	TrainTickValue = 478,   -- captured live value; server doesn't appear to validate this strictly
	TrainDelay = 0.5,       -- matches trainingIntervalSeconds from game data
	AutoSkillcheck = false,
	SkillcheckScore = 90,   -- fallback-only: 0-100, used if getconnections isn't supported by the executor
	SkillcheckDelay = 0.1,
	AntiAFK = true,
	HidePopups = false,
}

local stats = { ticks = 0, skillchecks = 0, session = os.clock() }

local Window

-- ============================================================
--  AUTO TRAIN (weight training tick)
-- ============================================================
task.spawn(function()
	while true do
		task.wait(Config.TrainDelay)
		if Config.AutoTrain then
			local ok = pcall(function()
				TrainingTickRemote:FireServer(Config.TrainTickValue)
			end)
			if ok then stats.ticks = stats.ticks + 1 end
		end
	end
end)

-- ============================================================
--  AUTO SKILLCHECK
--  The purple target is an invisible round TextButton (BackgroundTransparency=1,
--  Text="", UICorner radius 0.5) whose Activated event runs the real hit logic
--  (removes the circle, computes the score, fires the bonus + analytics remotes).
--  We find that button and fire its Activated connections directly so it behaves
--  exactly like a real click. If the executor doesn't support getconnections we
--  fall back to firing the remotes blindly (works, but won't dismiss the circle).
-- ============================================================
local supportsGetConnections = typeof(getconnections) == "function"

local function findSkillcheckButton()
	local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not PlayerGui then return nil end
	for _, inst in ipairs(PlayerGui:GetDescendants()) do
		if inst:IsA("TextButton") and inst.BackgroundTransparency == 1 and inst.Text == "" then
			local corner = inst:FindFirstChildOfClass("UICorner")
			if corner and corner.CornerRadius == UDim.new(0.5, 0) then
				local size = inst.Size
				if size.X.Offset > 50 and math.abs(size.X.Offset - size.Y.Offset) < 2 then
					return inst
				end
			end
		end
	end
	return nil
end

local function clickSkillcheckTarget()
	local button = findSkillcheckButton()

	if button and supportsGetConnections then
		local ok, conns = pcall(getconnections, button.Activated)
		if ok and conns and #conns > 0 then
			for _, c in ipairs(conns) do
				pcall(function() c:Fire() end)
			end
			return true
		end
	end

	if button then
		-- fallback: blind remote fire when we found the button but can't invoke it directly
		pcall(function()
			SkillcheckRemote:FireServer(Config.SkillcheckScore)
			BoostButtonRemote:FireServer()
		end)
		return true
	end

	return false
end

task.spawn(function()
	while true do
		task.wait(Config.SkillcheckDelay)
		if Config.AutoSkillcheck then
			local hit = clickSkillcheckTarget()
			if hit then stats.skillchecks = stats.skillchecks + 1 end
		end
	end
end)

-- ============================================================
--  HIDE POPUPS (+100 Power flytext, SPIN wheel prompt, x2 target icon)
-- ============================================================
local function shouldHidePopup(inst)
	if not inst:IsA("GuiObject") then return false end
	if inst.Name:find("PowerFly") then return true end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") then
		local text = inst.Text
		if text then
			if text:match("^%+%d+ Power$") then return true end
			if text == "SPIN" then return true end
			if text == "x2" then return true end
		end
	end
	return false
end

task.spawn(function()
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

	PlayerGui.DescendantAdded:Connect(function(inst)
		if Config.HidePopups and shouldHidePopup(inst) then
			inst.Visible = false
		end
	end)

	while true do
		task.wait(1)
		if Config.HidePopups then
			for _, inst in ipairs(PlayerGui:GetDescendants()) do
				if shouldHidePopup(inst) then
					inst.Visible = false
				end
			end
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
	ToggleKey = Enum.KeyCode.K,
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

MainTab:CreateSection("Weight Training")
MainTab:CreateToggle({
	Name = "Auto Train",
	Description = "Automatically fires training ticks (equip a weight first)",
	Flag = "AutoTrain",
	CurrentValue = Config.AutoTrain,
	Callback = function(v) Config.AutoTrain = v end,
})

MainTab:CreateSlider({
	Name = "Train Tick Delay",
	Range = { 0.1, 2 },
	Increment = 0.1,
	Suffix = "s",
	CurrentValue = Config.TrainDelay,
	Flag = "TrainDelay",
	Callback = function(v) Config.TrainDelay = v end,
})

MainTab:CreateSection("Skillcheck (Frenzy)")
MainTab:CreateToggle({
	Name = "Auto Skillcheck",
	Description = "Automatically hits the purple skillcheck target for frenzy bonus",
	Flag = "AutoSkillcheck",
	CurrentValue = Config.AutoSkillcheck,
	Callback = function(v) Config.AutoSkillcheck = v end,
})

MainTab:CreateSlider({
	Name = "Skillcheck Score (fallback)",
	Description = "Only used if your executor doesn't support getconnections",
	Range = { 0, 100 },
	Increment = 1,
	CurrentValue = Config.SkillcheckScore,
	Flag = "SkillcheckScore",
	Callback = function(v) Config.SkillcheckScore = v end,
})

MainTab:CreateSlider({
	Name = "Skillcheck Check Rate",
	Description = "How often to check for a target to hit",
	Range = { 0.05, 1 },
	Increment = 0.05,
	Suffix = "s",
	CurrentValue = Config.SkillcheckDelay,
	Flag = "SkillcheckDelay",
	Callback = function(v) Config.SkillcheckDelay = v end,
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

MainTab:CreateToggle({
	Name = "Hide Popups",
	Description = "Hides the +Power flytext, SPIN wheel and x2 target icon",
	Flag = "HidePopups",
	CurrentValue = Config.HidePopups,
	Callback = function(v) Config.HidePopups = v end,
})

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
	Content = "Automatic script for weight training + skillcheck frenzy. Configure options above.",
})

InfoTab:CreateDivider()
InfoTab:CreateLabel("v1.1 | BSW UI")

Window:Notify({ Title = "Loaded", Content = "BSW Strength Training started successfully.", Type = "Success" })
