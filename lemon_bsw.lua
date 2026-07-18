-- ============================================================
--  BSW HUB - AUTO LEMON (VeilUI v2.2)
--  made by baltazar.exe
--  migrate: use VeilUI instead of Rayfield
-- ============================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- stands available in workspace.<tycoon>.Purchases
local STANDS = {
	"Minigames", "LemonDash", "LemonX Ground", "Staircase", "Lemon Stand",
	"Lemon Labs", "LemonX", "Lemon Republic", "Lemon Depot", "Lemon Robotics",
	"Lemon Trading", "Hills",
}

local function setOf(list)
	local s = {}
	for _, v in ipairs(list) do s[v] = true end
	return s
end

local Config = {
	TycoonName = "",
	AutoLemon = false,
	WakeDelay = 0.5,
	AutoUpgrade = true,
	UpgradeDelay = 0.5,
	UpgradeStands = setOf(STANDS),
	UpgradeArg = 1,
	AutoPurchase = false,
	PurchaseDelay = 1.0,
	PurchaseStands = setOf(STANDS),
	AutoCashTP = false,
	CashScanDelay = 0.1,
	AutoAcceptOffers = false,
	AntiAFK = true,
	AutoClickFruits = false,
	ClickFruitsDelay = 0.3,
	AutoRebirth = false,
	RebirthMultiplier = 2,
	RebirthDelay = 5.0,
	AutoRejoin = false,
}

local stats = { upgrades = 0, purchases = 0, fruits = 0, rebirths = 0, session = os.clock() }

-- forward-declared so background loops (e.g. Auto Rebirth) can call Window:Notify
-- before the VeilUI window is actually created further down in this script
local Window

-- ============================================================
--  AUTO DETECT TYCOON
-- ============================================================
local function ownsTycoon(tycoon)
	local attrId = tycoon:GetAttribute("OwnerUserId") or tycoon:GetAttribute("ownerUserId")
	if attrId == LocalPlayer.UserId then return true end
	local attrOwner = tycoon:GetAttribute("Owner") or tycoon:GetAttribute("owner")
	if attrOwner == LocalPlayer.UserId or attrOwner == LocalPlayer.Name then return true end

	local owner = tycoon:FindFirstChild("Owner")
	if owner then
		local v = owner.Value
		if v == LocalPlayer then return true end
		if type(v) == "string" and v == LocalPlayer.Name then return true end
		if type(v) == "number" and v == LocalPlayer.UserId then return true end
	end

	for _, name in ipairs({ "OwnerName", "OwnerUserId", "Player" }) do
		local val = tycoon:FindFirstChild(name)
		if val then
			local v = val.Value
			if v == LocalPlayer then return true end
			if type(v) == "string" and v == LocalPlayer.Name then return true end
			if type(v) == "number" and v == LocalPlayer.UserId then return true end
		end
	end

	return false
end

local function findMyTycoon()
	for _, m in ipairs(Workspace:GetChildren()) do
		if m.Name:match("^Tycoon%d+$") and ownsTycoon(m) then
			return m
		end
	end
	return nil
end

local invalidatePurchaseCache
local setupCashListener

local MyTycoon
do
	local t0 = os.clock()
	repeat
		MyTycoon = findMyTycoon()
		if MyTycoon then break end
		task.wait(0.3)
	until os.clock() - t0 > 15
end

task.spawn(function()
	while not MyTycoon do
		task.wait(1)
		MyTycoon = findMyTycoon()
	end
end)

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(2)
	local found = findMyTycoon()
	if found and found ~= MyTycoon then
		MyTycoon = found
		invalidatePurchaseCache()
		setupCashListener()
	end
end)

task.spawn(function()
	local t0 = os.clock()
	repeat task.wait(0.5) until MyTycoon or os.clock() - t0 > 20
	setupCashListener()
end)

-- ============================================================
--  RESOLVE REMOTE
-- ============================================================
local function getTycoon()
	if Config.TycoonName ~= "" then
		return Workspace:FindFirstChild(Config.TycoonName)
	end
	MyTycoon = MyTycoon or findMyTycoon()
	return MyTycoon
end

local function getRemote()
	local tycoon = getTycoon()
	if not tycoon then return nil end
	local remotes = tycoon:FindFirstChild("Remotes")
	if not remotes then return nil end
	return remotes:FindFirstChild("WakeIncomeStream")
end

local function getPhoneOfferRemote()
	local tycoon = getTycoon()
	if not tycoon then return nil end
	local remotes = tycoon:FindFirstChild("Remotes")
	if not remotes then return nil end
	return remotes:FindFirstChild("PhoneOffer")
end

local function getRoot()
	local char = LocalPlayer.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

local function getUpgradeRemote(standName)
	local tycoon = getTycoon()
	if not tycoon then return nil end
	local purchases = tycoon:FindFirstChild("Purchases")
	if not purchases then return nil end
	local node = purchases:FindFirstChild(standName)
	if not node then return nil end
	node = node:FindFirstChild(standName)
	if not node then return nil end
	node = node:FindFirstChild(standName)
	if not node then return nil end
	return node:FindFirstChild("Upgrade")
end

-- ============================================================
--  CASH / PRICE HELPERS
-- ============================================================
local WORD_MULT = {
	thousand=1e3, million=1e6, billion=1e9, trillion=1e12,
	quadrillion=1e15, quintillion=1e18, sextillion=1e21,
	septillion=1e24, octillion=1e27, nonillion=1e30,
}
local SHORT_MULT = {
	K=1e3, M=1e6, B=1e9, T=1e12,
	Qa=1e15, Qi=1e18, Sx=1e21, Sp=1e24, Oc=1e27, No=1e30,
}
local BIG_MAGS = {}

do
	local BASE = {
		[0]="thousand",[1]="million",[2]="billion",[3]="trillion",[4]="quadrillion",
		[5]="quintillion",[6]="sextillion",[7]="septillion",[8]="octillion",[9]="nonillion",
		[10]="decillion",[11]="undecillion",[12]="duodecillion",[13]="tredecillion",
		[14]="quattuordecillion",[15]="quindecillion",[16]="sexdecillion",
		[17]="septendecillion",[18]="octodecillion",[19]="novemdecillion",
	}
	local ROOT = {
		[2]="vigintillion",[3]="trigintillion",[4]="quadragintillion",[5]="quinquagintillion",
		[6]="sexagintillion",[7]="septuagintillion",[8]="octogintillion",[9]="nonagintillion",
		[10]="centillion",
	}
	local PREFIX = {
		[0]="",[1]="un",[2]="duo",[3]="tres",[4]="quattuor",[5]="quin",
		[6]="sex",[7]="septen",[8]="octo",[9]="novem",
	}
	for n = 0, 100 do
		local name
		if n < 20 then
			name = BASE[n]
		else
			name = PREFIX[n % 10] .. ROOT[math.floor(n / 10)]
		end
		if name and name ~= "" then
			WORD_MULT[name] = 10 ^ ((n + 1) * 3)
		end
	end

	for name, mult in pairs(WORD_MULT) do
		table.insert(BIG_MAGS, { mult, name })
	end
	table.sort(BIG_MAGS, function(a, b) return a[1] > b[1] end)
end

local function formatBig(n)
	if not n or n ~= n then return "?" end
	for _, pair in ipairs(BIG_MAGS) do
		if n >= pair[1] then
			return ("%.3f %s"):format(n / pair[1], pair[2])
		end
	end
	return tostring(math.floor(n))
end

local function parsePrice(text)
	if not text or text == "" then return nil end
	local clean = text:gsub("[%$,]", ""):match("^%s*(.-)%s*$")
	local n, word = clean:lower():match("([%d%.]+)%s+(%a+)")
	if n and word then
		local m = WORD_MULT[word]
		if m then return tonumber(n) * m end
	end
	local num, suf = clean:match("([%d%.]+)%s*(%a*)")
	num = tonumber(num)
	if num then
		return num * (SHORT_MULT[suf:upper()] or 1)
	end
	return nil
end

local function getItemPrice(entry)
	if entry.cachedPrice ~= nil then return entry.cachedPrice end
	for _, d in ipairs(entry.item:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text and d.Text:find("%$") then
			local p = parsePrice(d.Text)
			if p and p > 0 then
				entry.cachedPrice = p
				return p
			end
		end
	end
	entry.cachedPrice = false
	return nil
end

local PlayerCash = math.huge

setupCashListener = function()
	local tycoon = getTycoon()
	if not tycoon then return end
	local values = tycoon:FindFirstChild("Values")
	if not values then return end
	local cashNames = { "Cash", "Money", "Balance", "Coins" }
	local cashVal
	for _, name in ipairs(cashNames) do
		cashVal = values:FindFirstChild(name)
		if cashVal then break end
	end
	if not cashVal then
		for _, v in ipairs(values:GetChildren()) do
			if v:IsA("NumberValue") or v:IsA("StringValue") then
				cashVal = v
				break
			end
		end
	end
	if not cashVal then return end
	local function updateCash()
		local raw = cashVal.Value
		if type(raw) == "number" then
			PlayerCash = raw
		elseif type(raw) == "string" then
			PlayerCash = parsePrice(raw) or math.huge
		end
	end
	updateCash()
	cashVal.Changed:Connect(updateCash)
end

-- ============================================================
--  AUTO PURCHASE
-- ============================================================
local PAD_NAMES = { button=true, pad=true, hitbox=true, buypad=true, buypart=true }
local padCooldown = setmetatable({}, { __mode = "k" })

local function isButtonPad(obj)
	if not obj:IsA("BasePart") then return false end
	return PAD_NAMES[obj.Name:lower()] == true
end

local function touchPad(pad)
	if not pad or not pad.Parent then return end
	local root = getRoot()
	if not root then return end
	if typeof(firetouchinterest) == "function" then
		pcall(firetouchinterest, root, pad, 0)
		task.wait(0.05)
		pcall(firetouchinterest, root, pad, 1)
	end
	local function tryCD(obj)
		if not obj then return end
		local cd = obj:FindFirstChildWhichIsA("ClickDetector")
		if cd and typeof(fireclickdetector) == "function" then
			local prev = cd.MaxActivationDistance
			cd.MaxActivationDistance = 9999
			pcall(fireclickdetector, cd)
			cd.MaxActivationDistance = prev
		end
	end
	tryCD(pad)
	tryCD(pad.Parent)
end

local function collectPads(tycoon)
	local pads = {}
	for _, d in ipairs(tycoon:GetDescendants()) do
		if isButtonPad(d) then
			table.insert(pads, d)
		end
	end
	return pads
end

local function purchaseAllPads()
	local tycoon = getTycoon()
	if not tycoon then return 0 end
	local pads = collectPads(tycoon)
	if #pads == 0 then return 0 end

	local root = getRoot()
	local rootPos = root and root.Position
	if rootPos then
		table.sort(pads, function(a, b)
			return (a.Position - rootPos).Magnitude < (b.Position - rootPos).Magnitude
		end)
	end

	local count = 0
	for i, pad in ipairs(pads) do
		task.spawn(function()
			task.wait((i - 1) * 0.05)
			touchPad(pad)
		end)
		count = count + 1
		stats.purchases = stats.purchases + 1
	end
	return count
end

invalidatePurchaseCache = function()
	padCooldown = setmetatable({}, { __mode = "k" })
end

task.spawn(function()
	local t0 = os.clock()
	repeat task.wait(0.5) until MyTycoon or os.clock() - t0 > 20
	local tycoon = getTycoon()
	if not tycoon then return end
	tycoon.DescendantAdded:Connect(function(obj)
		if not Config.AutoPurchase then return end
		if not isButtonPad(obj) then return end
		if padCooldown[obj] then return end
		padCooldown[obj] = true
		task.wait(0.15)
		touchPad(obj)
		task.wait(2)
		padCooldown[obj] = nil
	end)
end)

-- ============================================================
--  AUTO LEMON LOOP
-- ============================================================
task.spawn(function()
	while true do
		task.wait(Config.WakeDelay)
		if Config.AutoLemon then
			local r = getRemote()
			if r then
				for _, stand in ipairs(STANDS) do
					local arg = (stand:gsub("%s", ""))
					pcall(function() r:InvokeServer(arg) end)
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
--  AUTO REJOIN
-- ============================================================
local TeleportService = game:GetService("TeleportService")
local PLACE_ID = game.PlaceId

local function tryRejoin()
	if not Config.AutoRejoin then return end
	pcall(function()
		local players = Players:GetPlayers()
		if #players <= 1 then
			TeleportService:Teleport(PLACE_ID, LocalPlayer)
		else
			TeleportService:TeleportToPlaceInstance(PLACE_ID, game.JobId, LocalPlayer)
		end
	end)
end

pcall(function()
	game:GetService("GuiService").ErrorMessageChanged:Connect(function()
		if Config.AutoRejoin then task.wait(0.5); tryRejoin() end
	end)
end)

task.spawn(function()
	local cg = game:GetService("CoreGui")
	cg.DescendantAdded:Connect(function(d)
		if not Config.AutoRejoin then return end
		local n = string.lower(d.Name)
		if n:find("disconnect") or n:find("reconnect") or n:find("errorprompt") then
			task.wait(0.5); tryRejoin()
		end
	end)
end)

TeleportService.TeleportInitFailed:Connect(function(_, _, _)
	if Config.AutoRejoin then task.wait(2); tryRejoin() end
end)

-- ============================================================
--  AUTO ACCEPT PHONE OFFERS
-- ============================================================
task.spawn(function()
	while true do
		task.wait(1.0)
		if Config.AutoAcceptOffers then
			local r = getPhoneOfferRemote()
			if r then
				pcall(function() r:FireServer("Accept") end)
			end
		end
	end
end)

-- ============================================================
--  AUTO TP CASH DROPS
-- ============================================================
local function tpToDrop(drop)
	if not Config.AutoCashTP then return end
	if not drop or not drop.Parent then return end
	local root = getRoot()
	if not root then return end
	local pos
	if drop:IsA("BasePart") then
		pos = drop.Position
	elseif drop:IsA("Model") then
		local pp = drop.PrimaryPart or drop:FindFirstChildWhichIsA("BasePart")
		if pp then pos = pp.Position end
	end
	if not pos then return end
	root.CFrame = CFrame.new(pos)
	if typeof(firetouchinterest) == "function" then
		local part = drop:IsA("BasePart") and drop or drop:FindFirstChildWhichIsA("BasePart", true)
		if part then
			firetouchinterest(root, part, 0)
			firetouchinterest(root, part, 1)
		end
	end
end

task.spawn(function()
	local cashDrops = Workspace:FindFirstChild("CashDrops")
	while not cashDrops do
		task.wait(0.5)
		cashDrops = Workspace:FindFirstChild("CashDrops")
	end

	cashDrops.ChildAdded:Connect(function(drop)
		task.wait(0.05)
		tpToDrop(drop)
	end)

	while true do
		task.wait(Config.CashScanDelay)
		if Config.AutoCashTP then
			for _, drop in ipairs(cashDrops:GetChildren()) do
				tpToDrop(drop)
			end
		end
	end
end)

-- ============================================================
--  AUTO UPGRADE LOOP
-- ============================================================
local upgradeLevel = {}

task.spawn(function()
	while true do
		task.wait(Config.UpgradeDelay)
		if Config.AutoUpgrade then
			for stand, _ in pairs(Config.UpgradeStands) do
				local r = getUpgradeRemote(stand)
				if r then
					local lvl = upgradeLevel[stand] or Config.UpgradeArg
					local ok = pcall(function() r:InvokeServer(lvl) end)
					if ok then
						upgradeLevel[stand] = lvl + 1
						stats.upgrades = stats.upgrades + 1
					end
				end
			end
		end
	end
end)

-- ============================================================
--  AUTO REBIRTH
-- ============================================================
local function getRebirthRemote()
	local tycoon = getTycoon()
	if not tycoon then return nil end
	local remotes = tycoon:FindFirstChild("Remotes")
	if not remotes then return nil end
	return remotes:FindFirstChild("Rebirth")
end

local function readInvestorContainer(container)
	if not container then return nil end
	for _, child in ipairs(container:GetDescendants()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			if child.Name ~= "What" then
				local val = parsePrice(child.Text)
				if val and val > 0 then return val end
			end
		end
	end
	return nil
end

local function getInvestorRatio()
	local pg = LocalPlayer:FindFirstChildWhichIsA("PlayerGui")
	if not pg then return nil, nil, nil end
	local rebirthGui = pg:FindFirstChild("Rebirth")
	if not rebirthGui then return nil, nil, nil end
	local menu = rebirthGui:FindFirstChild("InvestorsMenu")
	if not menu then return nil, nil, nil end
	local body = menu:FindFirstChild("Body")
	if not body then return nil, nil, nil end

	local current  = readInvestorContainer(body:FindFirstChild("Amount"))
	local potential = readInvestorContainer(body:FindFirstChild("Potential"))

	if not current or not potential or current <= 0 then return nil, current, potential end
	return potential / current, current, potential
end

local TrackedInvestorsHuge = nil

task.spawn(function()
	local t0 = os.clock()
	repeat task.wait(0.5) until MyTycoon or os.clock() - t0 > 20
	local tycoon = getTycoon()
	if not tycoon then return end
	local remotes = tycoon:FindFirstChild("Remotes")
	if not remotes then return end
	local rebirthedEvt = remotes:FindFirstChild("Rebirthed")
	if rebirthedEvt then
		rebirthedEvt.OnClientEvent:Connect(function(newInvestorsHuge)
			if type(newInvestorsHuge) == "number" and newInvestorsHuge == newInvestorsHuge then
				TrackedInvestorsHuge = newInvestorsHuge
			end
		end)
	end
end)

local function getCurrentInvestors()
	local _, cur, _ = getInvestorRatio()
	if cur and cur > 0 then return cur end
	if TrackedInvestorsHuge then
		return math.pow(10, TrackedInvestorsHuge)
	end
	return nil
end

task.spawn(function()
	while true do
		task.wait(Config.RebirthDelay)
		if Config.AutoRebirth then
			local ratio = getInvestorRatio()
			if ratio and ratio >= Config.RebirthMultiplier then
				local r = getRebirthRemote()
				if r then
					local ok = pcall(function() r:InvokeServer(nil) end)
					if ok then stats.rebirths = stats.rebirths + 1 end
				end
			end
		end
	end
end)

-- ============================================================
--  AUTO CLICK FRUITS
-- ============================================================
local treeCache = {}
local treeCacheDirty = true

local function rebuildTreeCache()
	treeCache = {}
	for _, tycoon in ipairs(Workspace:GetChildren()) do
		if tycoon.Name:match("^Tycoon%d+$") then
			for _, desc in ipairs(tycoon:GetDescendants()) do
				if desc.Name:lower():find("tree") and desc:FindFirstChild("Fruit") then
					table.insert(treeCache, desc)
				end
			end
		end
	end
	treeCacheDirty = false
end

task.spawn(function()
	local t0 = os.clock()
	repeat task.wait(0.5) until MyTycoon or os.clock() - t0 > 20
	local tycoon = getTycoon()
	if not tycoon then return end
	tycoon.DescendantAdded:Connect(function(d)
		if d.Name == "Fruit" or d.Name == "ClickPart" then treeCacheDirty = true end
	end)
	tycoon.DescendantRemoving:Connect(function(d)
		if d.Name == "Fruit" or d.Name == "ClickPart" then treeCacheDirty = true end
	end)
end)

local function clickAllFruits()
	local root = getRoot()
	if not root then return 0 end

	if treeCacheDirty then rebuildTreeCache() end
	if #treeCache == 0 then return 0 end

	local fti = typeof(firetouchinterest) == "function" and firetouchinterest or nil
	local fcd = typeof(fireclickdetector) == "function" and fireclickdetector or nil
	local count = 0

	for _, tree in ipairs(treeCache) do
		if tree and tree.Parent then
			for _, fruit in ipairs(tree:GetChildren()) do
				if not Config.AutoClickFruits then return count end
				local cp = fruit.Name == "Fruit" and fruit:FindFirstChild("ClickPart")
				if cp and cp:IsA("BasePart") then
					root.CFrame = CFrame.new(cp.Position + Vector3.new(0, 2.5, 0))
					task.wait(Config.ClickFruitsDelay)

					if fti then
						pcall(fti, root, cp, 0)
						pcall(fti, root, cp, 1)
					end
					if fcd then
						local cd = cp:FindFirstChildWhichIsA("ClickDetector")
						if cd then pcall(fcd, cd) end
					end
					count = count + 1
					stats.fruits = stats.fruits + 1
				end
			end
		end
	end

	return count
end

task.spawn(function()
	while true do
		if Config.AutoClickFruits then
			clickAllFruits()
		end
		task.wait(0.5)
	end
end)

-- ============================================================
--  AUTO PURCHASE LOOP
-- ============================================================
task.spawn(function()
	while true do
		task.wait(Config.PurchaseDelay)
		if Config.AutoPurchase then
			purchaseAllPads()
		end
	end
end)

-- ============================================================
--  UI VEIL
-- ============================================================
-- Load VeilUI from GitHub
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
	Subtitle = "Lemon Tycoon",
	Theme = "Balta",
	Transparency = 0.06,
	Blur = false,
	HideName = false,
	ToggleKey = Enum.KeyCode.K,
	ConfigurationSaving = { Enabled = true, FolderName = "BSWHub", FileName = "LemonConfig" },
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

MainTab:CreateSection("Status")
MainTab:CreateLabel("Tycoon: " .. (MyTycoon and MyTycoon.Name or "DETECTING..."))

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
	Name = "Auto Wake (all stands)",
	Description = "Automatically wake all stands",
	Flag = "AutoLemon",
	CurrentValue = Config.AutoLemon,
	Callback = function(v) Config.AutoLemon = v end,
})

MainTab:CreateToggle({
	Name = "Auto Accept Phone Offers",
	Description = "Accept phone offers automatically",
	Flag = "AutoAcceptOffers",
	CurrentValue = Config.AutoAcceptOffers,
	Callback = function(v) Config.AutoAcceptOffers = v end,
})

MainTab:CreateToggle({
	Name = "Anti AFK",
	Flag = "AntiAFK",
	CurrentValue = Config.AntiAFK,
	Callback = function(v) Config.AntiAFK = v end,
})

MainTab:CreateToggle({
	Name = "Auto Rejoin",
	Description = "Rejoin when disconnected",
	Flag = "AutoRejoin",
	CurrentValue = Config.AutoRejoin,
	Callback = function(v) Config.AutoRejoin = v end,
})

MainTab:CreateToggle({
	Name = "Auto Click Fruits",
	Description = "Collect fruits automatically",
	Flag = "AutoClickFruits",
	CurrentValue = Config.AutoClickFruits,
	Callback = function(v) Config.AutoClickFruits = v end,
})

MainTab:CreateSlider({
	Name = "Fruit Click Delay",
	Range = { 0.05, 2 },
	Increment = 0.05,
	Suffix = "s",
	CurrentValue = Config.ClickFruitsDelay,
	Flag = "ClickFruitsDelay",
	Callback = function(v) Config.ClickFruitsDelay = v end,
})

-- ── AUTO CASH TAB ────────────────────────────────────────
local CashTab = Window:CreateTab("Cash")
CashTab:CreateSection("Cash Drops")
CashTab:CreateToggle({
	Name = "Auto TP Cash Drops",
	Description = "Automatically teleport to cash drops",
	Flag = "AutoCashTP",
	CurrentValue = Config.AutoCashTP,
	Callback = function(v) Config.AutoCashTP = v end,
})

CashTab:CreateSlider({
	Name = "Scan Delay",
	Range = { 0.05, 1 },
	Increment = 0.05,
	Suffix = "s",
	CurrentValue = Config.CashScanDelay,
	Flag = "CashScanDelay",
	Callback = function(v) Config.CashScanDelay = v end,
})

-- ── AUTO UPGRADE TAB ─────────────────────────────────────
local UpgradeTab = Window:CreateTab("Upgrade")
UpgradeTab:CreateSection("Stands")
UpgradeTab:CreateToggle({
	Name = "Auto Upgrade Stands",
	Flag = "AutoUpgrade",
	CurrentValue = Config.AutoUpgrade,
	Callback = function(v) Config.AutoUpgrade = v end,
})

UpgradeTab:CreateSlider({
	Name = "Upgrade Delay",
	Range = { 0.05, 5 },
	Increment = 0.05,
	Suffix = "s",
	CurrentValue = Config.UpgradeDelay,
	Flag = "UpgradeDelay",
	Callback = function(v) Config.UpgradeDelay = v end,
})

-- ── AUTO PURCHASE TAB ────────────────────────────────────
local PurchaseTab = Window:CreateTab("Purchase")
PurchaseTab:CreateSection("Items")
PurchaseTab:CreateToggle({
	Name = "Auto Purchase Items",
	Description = "Click purchase buttons automatically",
	Flag = "AutoPurchase",
	CurrentValue = Config.AutoPurchase,
	Callback = function(v) Config.AutoPurchase = v end,
})

PurchaseTab:CreateSlider({
	Name = "Purchase Delay",
	Range = { 0.1, 5 },
	Increment = 0.1,
	Suffix = "s",
	CurrentValue = Config.PurchaseDelay,
	Flag = "PurchaseDelay",
	Callback = function(v) Config.PurchaseDelay = v end,
})

-- ── AUTO REBIRTH TAB ─────────────────────────────────────
local RebirthTab = Window:CreateTab("Rebirth")
RebirthTab:CreateSection("Auto Rebirth")
RebirthTab:CreateToggle({
	Name = "Auto Rebirth",
	Description = "Rebirths automatically once the investor multiplier is reached",
	Flag = "AutoRebirth",
	CurrentValue = Config.AutoRebirth,
	Callback = function(v) Config.AutoRebirth = v end,
})

RebirthTab:CreateSlider({
	Name = "Rebirth Multiplier",
	Description = "Rebirth once potential investors are this many times your current investors",
	Range = { 2, 10 },
	Increment = 1,
	CurrentValue = Config.RebirthMultiplier,
	Flag = "RebirthMultiplier",
	Callback = function(v) Config.RebirthMultiplier = v end,
})

RebirthTab:CreateSlider({
	Name = "Check Delay",
	Range = { 1, 30 },
	Increment = 1,
	Suffix = "s",
	CurrentValue = Config.RebirthDelay,
	Flag = "RebirthDelay",
	Callback = function(v) Config.RebirthDelay = v end,
})

-- ── INFO TAB ─────────────────────────────────────────────
local InfoTab = Window:CreateTab("Info")
InfoTab:CreateParagraph({
	Title = "BSW Hub - Lemon Tycoon",
	Content = "Automatic script for Lemon Tycoon. Configure options in the tabs above.",
})

InfoTab:CreateDivider()
InfoTab:CreateLabel("v2.2 | BSW UI")

Window:Notify({ Title = "Loaded", Content = "BSW Lemon started successfully.", Type = "Success" })
