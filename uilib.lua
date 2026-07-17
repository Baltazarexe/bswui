--[[
	VeilUI v2 - self-contained Roblox executor UI library
	Clean / modern look (Fluent-inspired): borderless rows, subtle hairlines,
	restrained accent usage, live theme switching and adjustable glass.

	Usage:
		local Veil = loadstring(readfile("uilib.lua"))()
		local Window = Veil.CreateWindow({
			Title = "My Hub",
			Subtitle = "v1.0",
			Theme = "Balta",           -- "Balta" (default) | "Dark" | "Midnight" | "Amethyst" | "Light" (or a table)
			Transparency = 0.08,       -- 0 = solid, higher = more glass
			Blur = false,              -- optional frosted-glass blur (off by default)
			HideName = false,          -- hide the display name/username in the sidebar card
			ToggleKey = Enum.KeyCode.RightShift,
			ConfigurationSaving = { Enabled = true, FolderName = "VeilUI", FileName = "config" },
		})
		local Tab = Window:CreateTab("Main")
		Tab:CreateToggle({ Name = "Auto Farm", Flag = "af", Callback = function(v) end })

		Window:SetTheme("Light")       -- live switch
		Window:SetTransparency(0.2)    -- live glass amount
		Window:SetNameHidden(true)     -- live switch, hides sidebar name/username
]]

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local Lighting         = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

local Veil = {}
Veil.__index = Veil

-- ── THEMES ───────────────────────────────────────────────────────────────
Veil.Themes = {
	-- baltasoftware.com brand: near-black with hot-pink accent (default)
	Balta = {
		Background = Color3.fromRGB(10, 10, 15),
		Panel      = Color3.fromRGB(18, 18, 26),
		PanelLight = Color3.fromRGB(27, 26, 38),
		Border     = Color3.fromRGB(58, 48, 68),
		Text       = Color3.fromRGB(245, 240, 248),
		SubText    = Color3.fromRGB(152, 142, 160),
		Accent     = Color3.fromRGB(255, 42, 125),
		Success    = Color3.fromRGB(72, 199, 142),
		Warning    = Color3.fromRGB(245, 183, 66),
		Error      = Color3.fromRGB(240, 84, 108),
	},
	-- near-black neutral (WindUI-like)
	Dark = {
		Background = Color3.fromRGB(10, 10, 14),
		Panel      = Color3.fromRGB(19, 19, 25),
		PanelLight = Color3.fromRGB(27, 27, 35),
		Border     = Color3.fromRGB(50, 51, 62),
		Text       = Color3.fromRGB(240, 241, 246),
		SubText    = Color3.fromRGB(138, 143, 158),
		Accent     = Color3.fromRGB(105, 130, 255),
		Success    = Color3.fromRGB(72, 199, 142),
		Warning    = Color3.fromRGB(245, 183, 66),
		Error      = Color3.fromRGB(240, 84, 108),
	},
	Midnight = {
		Background = Color3.fromRGB(7, 10, 16),
		Panel      = Color3.fromRGB(13, 17, 26),
		PanelLight = Color3.fromRGB(19, 25, 38),
		Border     = Color3.fromRGB(45, 55, 80),
		Text       = Color3.fromRGB(225, 235, 250),
		SubText    = Color3.fromRGB(120, 135, 165),
		Accent     = Color3.fromRGB(0, 200, 255),
		Success    = Color3.fromRGB(70, 235, 160),
		Warning    = Color3.fromRGB(255, 195, 60),
		Error      = Color3.fromRGB(255, 70, 100),
	},
	Amethyst = {
		Background = Color3.fromRGB(14, 11, 20),
		Panel      = Color3.fromRGB(22, 18, 32),
		PanelLight = Color3.fromRGB(31, 26, 45),
		Border     = Color3.fromRGB(60, 50, 90),
		Text       = Color3.fromRGB(238, 233, 250),
		SubText    = Color3.fromRGB(150, 140, 175),
		Accent     = Color3.fromRGB(167, 139, 250),
		Success    = Color3.fromRGB(94, 222, 158),
		Warning    = Color3.fromRGB(250, 190, 80),
		Error      = Color3.fromRGB(244, 92, 118),
	},
	Light = {
		Background = Color3.fromRGB(242, 243, 247),
		Panel      = Color3.fromRGB(255, 255, 255),
		PanelLight = Color3.fromRGB(233, 236, 243),
		Border     = Color3.fromRGB(208, 212, 222),
		Text       = Color3.fromRGB(26, 29, 38),
		SubText    = Color3.fromRGB(110, 117, 133),
		Accent     = Color3.fromRGB(79, 110, 247),
		Success    = Color3.fromRGB(34, 165, 110),
		Warning    = Color3.fromRGB(214, 150, 30),
		Error      = Color3.fromRGB(220, 60, 85),
	},
}

-- ── FONTS (BuilderSans = modern Roblox font; falls back to Gotham) ──────
local FONTS = (function()
	local ok = pcall(function() return Enum.Font.BuilderSansMedium end)
	if ok then
		return {
			Reg  = Enum.Font.BuilderSans,
			Med  = Enum.Font.BuilderSansMedium,
			Bold = Enum.Font.BuilderSansBold,
		}
	end
	return {
		Reg  = Enum.Font.Gotham,
		Med  = Enum.Font.GothamMedium,
		Bold = Enum.Font.GothamBold,
	}
end)()

-- ── HELPERS ──────────────────────────────────────────────────────────────
local function new(class, props, children)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			obj[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = obj
	end
	if props and props.Parent then
		obj.Parent = props.Parent
	end
	return obj
end

local function corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

local function stroke(color, thickness, transparency)
	return new("UIStroke", {
		Color = color or Color3.fromRGB(255, 255, 255),
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function pad(l, t, r, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0),
		PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or l or 0),
		PaddingBottom = UDim.new(0, b or t or 0),
	})
end

local function tween(obj, props, time, style, dir)
	local info = TweenInfo.new(time or 0.16, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

local function getGuiParent()
	local ok, hui = pcall(function() return gethui and gethui() end)
	if ok and hui then return hui end
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if pg then return pg end
	return game:GetService("CoreGui")
end

-- draggable with on-screen clamping
local function makeDraggable(dragTarget, moveTarget)
	moveTarget = moveTarget or dragTarget
	local dragging = false
	local dragStart, startPos
	local MARGIN = 48

	local function moveTo(delta)
		local cam = workspace.CurrentCamera
		local vp = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
		local size = moveTarget.AbsoluteSize
		local sx, sy = startPos.X.Scale, startPos.Y.Scale
		local goalX = startPos.X.Offset + delta.X
		local goalY = startPos.Y.Offset + delta.Y
		goalX = math.clamp(goalX, MARGIN - size.X - sx * vp.X, vp.X - MARGIN - sx * vp.X)
		goalY = math.clamp(goalY, MARGIN - size.Y - sy * vp.Y, vp.Y - MARGIN - sy * vp.Y)
		moveTarget.Position = UDim2.new(sx, goalX, sy, goalY)
	end

	dragTarget.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = moveTarget.Position
			local endedConn
			endedConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					endedConn:Disconnect()
				end
			end)
		end
	end)

	-- listen globally (not scoped to dragTarget) so fast drags that move the
	-- cursor outside the title bar's bounds don't get stuck mid-drag
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			moveTo(input.Position - dragStart)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

-- ── CONFIG SAVE/LOAD (best-effort, needs writefile/readfile) ─────────────
local function hasFileIO()
	return typeof(writefile) == "function" and typeof(readfile) == "function"
end

local function ensureFolder(folder)
	pcall(function()
		if not isfolder(folder) then
			makefolder(folder)
		end
	end)
end

-- ══════════════════════════════════════════════════════════════════════════
--  WINDOW
-- ══════════════════════════════════════════════════════════════════════════
function Veil.CreateWindow(opts)
	opts = opts or {}
	local title = opts.Title or "Veil UI"
	local subtitle = opts.Subtitle or ""
	local toggleKey = opts.ToggleKey or Enum.KeyCode.RightShift
	local blurEnabled = opts.Blur == true -- blur is opt-in (off by default)

	-- ── live theme system ────────────────────────────────────────────
	-- T is mutated in place so every closure reading T.* stays fresh.
	-- paint() registers a re-colorer that runs now and on every theme change.
	local T = {}
	local customAccent = opts.Accent
	local accentC
	local glassAmt = math.clamp(opts.Transparency or 0.08, 0, 0.9)

	local paints = {}
	local function repaint()
		for _, f in ipairs(paints) do
			pcall(f)
		end
	end
	local function paint(fn)
		paints[#paints + 1] = fn
		pcall(fn)
	end
	local function applyTheme(ref)
		local src = (type(ref) == "table" and ref) or Veil.Themes[ref] or Veil.Themes.Balta
		for k, v in pairs(src) do T[k] = v end
		accentC = customAccent or T.Accent
		repaint()
	end
	applyTheme(opts.Theme or "Balta")

	-- ── config persistence ───────────────────────────────────────────
	local cfgEnabled = opts.ConfigurationSaving and opts.ConfigurationSaving.Enabled and hasFileIO()
	local cfgFolder = (opts.ConfigurationSaving and opts.ConfigurationSaving.FolderName) or "VeilUI"
	local cfgFile = (opts.ConfigurationSaving and opts.ConfigurationSaving.FileName) or "config"
	local cfgPath = cfgFolder .. "/" .. cfgFile .. ".json"
	local flagStore = {}
	local flagSetters = {}

	local connections = {}
	local function addConn(conn)
		if conn then connections[#connections + 1] = conn end
		return conn
	end

	if cfgEnabled then
		ensureFolder(cfgFolder)
		pcall(function()
			if isfile(cfgPath) then
				local raw = readfile(cfgPath)
				local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
				if ok and type(decoded) == "table" then
					flagStore = decoded
				end
			end
		end)
	end

	local function saveConfig()
		if not cfgEnabled then return end
		pcall(function()
			writefile(cfgPath, HttpService:JSONEncode(flagStore))
		end)
	end

	-- ── reload safety ────────────────────────────────────────────────
	local guiParent = getGuiParent()
	for _, g in ipairs(guiParent:GetChildren()) do
		if g.Name == "VeilUI_" .. title then
			g:Destroy()
		end
	end
	local oldBlur = Lighting:FindFirstChild("VeilAcrylic")
	if oldBlur then oldBlur:Destroy() end

	local screenGui = new("ScreenGui", {
		Name = "VeilUI_" .. title,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
		Parent = guiParent,
	})

	-- acrylic blur behind the translucent window
	local acrylicBlur = Instance.new("BlurEffect")
	acrylicBlur.Name = "VeilAcrylic"
	acrylicBlur.Size = 0
	acrylicBlur.Parent = Lighting
	local function setBlur(on)
		tween(acrylicBlur, { Size = (on and blurEnabled) and 16 or 0 }, 0.25)
	end

	-- soft drop shadow
	new("ImageLabel", {
		Name = "Shadow",
		Image = "rbxassetid://5028857084",
		ImageColor3 = Color3.fromRGB(0, 0, 0),
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(24, 24, 276, 276),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 8),
		Size = UDim2.new(1, 70, 1, 70),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = screenGui,
	})

	local main = new("Frame", {
		Name = "Main",
		Size = UDim2.fromOffset(600, 420),
		Position = UDim2.new(0.5, -300, 0.5, -210),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = screenGui,
	}, { corner(14) })

	local mainStroke = stroke(nil, 1, 0.6)
	mainStroke.Parent = main
	paint(function()
		main.BackgroundColor3 = T.Background
		main.BackgroundTransparency = glassAmt
		mainStroke.Color = T.Border
	end)

	-- ── top bar ──────────────────────────────────────────────────────
	local topBar = new("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = main,
	})

	-- rounded-square "app icon" with the first letter of the title
	local iconBox = new("Frame", {
		Name = "Icon",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(0, 14, 0, 10),
		BorderSizePixel = 0,
		Parent = topBar,
	}, { corner(8) })
	local iconLetter = new("TextLabel", {
		Text = string.upper(string.sub(title, 1, 1)),
		Font = FONTS.Bold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = iconBox,
	})
	paint(function() iconBox.BackgroundColor3 = accentC end)

	local titleLbl = new("TextLabel", {
		Text = title,
		Font = FONTS.Bold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -160, 0, 18),
		Position = UDim2.new(0, 48, 0, 6),
		Parent = topBar,
	})
	local subtitleLbl = new("TextLabel", {
		Text = subtitle,
		Font = FONTS.Reg,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -160, 0, 13),
		Position = UDim2.new(0, 48, 0, 25),
		Parent = topBar,
	})
	paint(function()
		titleLbl.TextColor3 = T.Text
		subtitleLbl.TextColor3 = T.SubText
	end)

	-- window buttons (round hover pills)
	local function windowButton(text, xOffset)
		local btn = new("TextButton", {
			Text = text,
			Font = FONTS.Bold,
			TextSize = 14,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.new(1, xOffset, 0, 9),
			Parent = topBar,
		}, { corner(14) })
		paint(function()
			btn.TextColor3 = T.SubText
			btn.BackgroundColor3 = T.PanelLight
		end)
		btn.MouseEnter:Connect(function()
			tween(btn, { BackgroundTransparency = 0.2, TextColor3 = T.Text }, 0.1)
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, { BackgroundTransparency = 1, TextColor3 = T.SubText }, 0.1)
		end)
		return btn
	end
	local minimizeBtn = windowButton("–", -72)
	local closeBtn = windowButton("×", -38)

	-- hairline under the top bar
	local topDivider = new("Frame", {
		Size = UDim2.new(1, -24, 0, 1),
		Position = UDim2.new(0, 12, 0, 46),
		BorderSizePixel = 0,
		BackgroundTransparency = 0.5,
		Parent = main,
	})
	paint(function() topDivider.BackgroundColor3 = T.Border end)

	makeDraggable(topBar, main)

	-- ── sidebar ──────────────────────────────────────────────────────
	local sidebar = new("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 148, 1, -47),
		Position = UDim2.new(0, 0, 0, 47),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = main,
	})
	local sideDivider = new("Frame", {
		Size = UDim2.new(0, 1, 1, -24),
		Position = UDim2.new(1, 0, 0, 12),
		BorderSizePixel = 0,
		BackgroundTransparency = 0.6,
		Parent = sidebar,
	})
	paint(function() sideDivider.BackgroundColor3 = T.Border end)

	local sidebarList = new("ScrollingFrame", {
		Size = UDim2.new(1, -1, 1, -76),
		Position = UDim2.new(0, 0, 0, 6),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = sidebar,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		pad(10, 0, 10, 0),
	})
	paint(function() sidebarList.ScrollBarImageColor3 = T.Border end)

	-- user card pinned to the sidebar bottom (avatar + names)
	local userCard = new("Frame", {
		Size = UDim2.new(1, -20, 0, 54),
		Position = UDim2.new(0, 10, 1, -62),
		BorderSizePixel = 0,
		Parent = sidebar,
	}, { corner(10) })
	paint(function()
		userCard.BackgroundColor3 = T.Panel
		userCard.BackgroundTransparency = 0.15
	end)
	local avatar = new("ImageLabel", {
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.new(0, 10, 0.5, -16),
		BorderSizePixel = 0,
		Parent = userCard,
	}, { corner(16) })
	paint(function() avatar.BackgroundColor3 = T.PanelLight end)
	task.spawn(function()
		local ok, thumb = pcall(function()
			return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and thumb then avatar.Image = thumb end
	end)
	local realDisplayName = (LocalPlayer and LocalPlayer.DisplayName) or "Player"
	local realUserName = "@" .. ((LocalPlayer and LocalPlayer.Name) or "player")
	local nameHidden = opts.HideName == true

	local dispName = new("TextLabel", {
		Text = realDisplayName,
		Font = FONTS.Bold,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -56, 0, 15),
		Position = UDim2.new(0, 48, 0, 11),
		Parent = userCard,
	})
	local userName = new("TextLabel", {
		Text = realUserName,
		Font = FONTS.Reg,
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -56, 0, 13),
		Position = UDim2.new(0, 48, 0, 27),
		Parent = userCard,
	})
	paint(function()
		dispName.TextColor3 = T.Text
		userName.TextColor3 = T.SubText
	end)

	-- hides the display name / username in the sidebar card (avatar stays)
	local function applyNameHidden()
		dispName.Text = nameHidden and "Hidden" or realDisplayName
		userName.Text = nameHidden and "••••••••" or realUserName
	end
	applyNameHidden()

	-- ── content ──────────────────────────────────────────────────────
	local contentArea = new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -149, 1, -47),
		Position = UDim2.new(0, 149, 0, 47),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = main,
	})

	-- ── notifications ────────────────────────────────────────────────
	local notifyHolder = new("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 290, 1, -32),
		BackgroundTransparency = 1,
		Parent = screenGui,
	}, {
		new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 8),
		}),
	})

	-- ── minimize / close / toggle ────────────────────────────────────
	local minimized = false
	local prevSize = main.Size
	minimizeBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			prevSize = main.Size
			tween(main, { Size = UDim2.fromOffset(prevSize.X.Offset, 47) }, 0.2)
			sidebar.Visible = false
			contentArea.Visible = false
		else
			tween(main, { Size = prevSize }, 0.2)
			task.delay(0.2, function()
				sidebar.Visible = true
				contentArea.Visible = true
			end)
		end
	end)

	local visible = true
	closeBtn.MouseButton1Click:Connect(function()
		visible = false
		setBlur(false)
		screenGui.Enabled = false
	end)

	addConn(UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == toggleKey then
			visible = not visible
			screenGui.Enabled = visible
			setBlur(visible)
		end
	end))

	-- ── window object ────────────────────────────────────────────────
	local Window = setmetatable({}, Veil)
	Window._screenGui = screenGui
	Window._main = main
	Window._sidebar = sidebarList
	Window._content = contentArea
	Window._notify = notifyHolder
	Window._tabs = {}
	Window._firstTab = nil
	Window._cfgEnabled = cfgEnabled
	Window._flagStore = flagStore
	Window._flagSetters = flagSetters
	Window._saveConfig = saveConfig

	function Window:SetTheme(ref)
		applyTheme(ref)
	end

	function Window:SetAccent(color)
		customAccent = color
		accentC = color or T.Accent
		repaint()
	end

	function Window:SetTransparency(v)
		glassAmt = math.clamp(v or 0, 0, 0.9)
		repaint()
	end

	function Window:SetNameHidden(hidden)
		nameHidden = hidden == true
		applyNameHidden()
	end

	local notifyOrder = 0
	function Window:Notify(o)
		o = o or {}
		local kind = o.Type or "Info"
		local color = ({
			Info = accentC, Success = T.Success, Warning = T.Warning, Error = T.Error,
		})[kind] or accentC

		-- cap simultaneous notifications (drop oldest)
		do
			local cards = {}
			for _, c in ipairs(notifyHolder:GetChildren()) do
				if c:IsA("Frame") then cards[#cards + 1] = c end
			end
			table.sort(cards, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
			for i = 1, #cards - 4 do cards[i]:Destroy() end
		end

		notifyOrder += 1
		local card = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = T.Panel,
			BorderSizePixel = 0,
			LayoutOrder = notifyOrder,
			Parent = notifyHolder,
		}, { corner(10), stroke(T.Border, 1, 0.6), pad(12, 10, 12, 10) })

		new("Frame", {
			Size = UDim2.new(0, 3, 1, -8),
			Position = UDim2.new(0, -6, 0, 4),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = card,
		}, { corner(2) })

		new("TextLabel", {
			Text = o.Title or "Notification",
			Font = FONTS.Bold,
			TextSize = 13,
			TextColor3 = T.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -6, 0, 16),
			Position = UDim2.fromOffset(6, 0),
			Parent = card,
		})
		local body = new("TextLabel", {
			Text = o.Content or "",
			Font = FONTS.Reg,
			TextSize = 12,
			TextColor3 = T.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -6, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(6, 18),
			Parent = card,
		})

		card.BackgroundTransparency = 1
		body.TextTransparency = 1
		card.Position = UDim2.fromOffset(20, 0)
		tween(card, { BackgroundTransparency = 0.05, Position = UDim2.fromOffset(0, 0) }, 0.18)
		tween(body, { TextTransparency = 0 }, 0.18)

		local dismissed = false
		local function dismiss()
			if dismissed then return end
			dismissed = true
			if card.Parent then
				tween(card, { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 0) }, 0.18)
				tween(body, { TextTransparency = 1 }, 0.18)
				task.delay(0.18, function() card:Destroy() end)
			end
		end

		card.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dismiss()
			end
		end)

		task.delay(o.Duration or 4, dismiss)
	end

	function Window:Destroy()
		for _, c in ipairs(connections) do
			pcall(function() c:Disconnect() end)
		end
		table.clear(connections)
		if acrylicBlur then acrylicBlur:Destroy() end
		screenGui:Destroy()
	end

	function Window:_registerFlag(flag, setter, default)
		if not flag then return default end
		flagSetters[flag] = setter
		if Window._flagStore[flag] ~= nil then
			return Window._flagStore[flag]
		end
		return default
	end

	function Window:_setFlag(flag, value)
		if not flag then return end
		Window._flagStore[flag] = value
		Window._saveConfig()
	end

	-- ── TAB ──────────────────────────────────────────────────────────
	function Window:CreateTab(name, icon)
		local tabBtn = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = sidebarList,
		}, { corner(8) })

		local activeBar = new("Frame", {
			Size = UDim2.new(0, 3, 0, 16),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = tabBtn,
		}, { corner(2) })

		-- optional icon (pass an asset id number or "rbxassetid://..." string)
		local iconImg
		if icon then
			iconImg = new("ImageLabel", {
				Image = (type(icon) == "number" and ("rbxassetid://" .. icon)) or tostring(icon),
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(16, 16),
				Position = UDim2.new(0, 11, 0.5, -8),
				Parent = tabBtn,
			})
		end

		local label = new("TextLabel", {
			Text = name,
			Font = FONTS.Med,
			TextSize = 14,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.fromOffset(iconImg and 34 or 12, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = tabBtn,
		})

		local page = new("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			Parent = contentArea,
		}, {
			new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			pad(16, 12, 16, 16),
		})
		paint(function() page.ScrollBarImageColor3 = T.Border end)

		local Tab = { _page = page, _btn = tabBtn, _label = label, _bar = activeBar, _icon = iconImg }

		-- theme-aware tab state (snaps colors on theme change)
		paint(function()
			local active = page.Visible
			tabBtn.BackgroundColor3 = T.PanelLight
			tabBtn.BackgroundTransparency = active and 0.15 or 1
			label.TextColor3 = active and T.Text or T.SubText
			activeBar.BackgroundColor3 = accentC
			activeBar.BackgroundTransparency = active and 0 or 1
			if iconImg then iconImg.ImageColor3 = active and T.Text or T.SubText end
		end)

		local function activate()
			for _, t in pairs(Window._tabs) do
				t._page.Visible = false
				tween(t._btn, { BackgroundTransparency = 1 }, 0.12)
				tween(t._label, { TextColor3 = T.SubText }, 0.12)
				tween(t._bar, { BackgroundTransparency = 1 }, 0.12)
				if t._icon then tween(t._icon, { ImageColor3 = T.SubText }, 0.12) end
			end
			page.Visible = true
			tween(tabBtn, { BackgroundTransparency = 0.15 }, 0.12)
			tween(label, { TextColor3 = T.Text }, 0.12)
			tween(activeBar, { BackgroundTransparency = 0 }, 0.12)
			if iconImg then tween(iconImg, { ImageColor3 = T.Text }, 0.12) end
		end
		Tab._activate = activate

		tabBtn.MouseButton1Click:Connect(activate)
		tabBtn.MouseEnter:Connect(function()
			if page.Visible then return end
			tween(tabBtn, { BackgroundTransparency = 0.6 }, 0.1)
		end)
		tabBtn.MouseLeave:Connect(function()
			if page.Visible then return end
			tween(tabBtn, { BackgroundTransparency = 1 }, 0.1)
		end)

		Window._tabs[#Window._tabs + 1] = Tab
		if not Window._firstTab then
			Window._firstTab = Tab
			activate()
		end

		-- ── COMPONENT PRIMITIVES ─────────────────────────────────
		-- borderless translucent row; hover is handled by callers
		local function baseRow(height)
			local row = new("Frame", {
				Size = UDim2.new(1, 0, 0, height or 44),
				BorderSizePixel = 0,
				Parent = page,
			}, { corner(10) })
			paint(function()
				row.BackgroundColor3 = T.Panel
				row.BackgroundTransparency = 0.15
			end)
			return row
		end

		local function rowHover(hitbox, row)
			hitbox.MouseEnter:Connect(function()
				tween(row, { BackgroundColor3 = T.PanelLight, BackgroundTransparency = 0.05 }, 0.1)
			end)
			hitbox.MouseLeave:Connect(function()
				tween(row, { BackgroundColor3 = T.Panel, BackgroundTransparency = 0.15 }, 0.1)
			end)
		end

		-- name label; when desc is given the row shows name + smaller subtext
		local function rowLabel(row, text, rightInset, desc)
			local w = -(rightInset or 24) - 14
			local lbl = new("TextLabel", {
				Text = text,
				Font = FONTS.Med,
				TextSize = 14,
				BackgroundTransparency = 1,
				Size = desc and UDim2.new(1, w, 0, 17) or UDim2.new(1, w, 1, 0),
				Position = desc and UDim2.fromOffset(14, 9) or UDim2.fromOffset(14, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
			paint(function() lbl.TextColor3 = T.Text end)
			if desc then
				local d = new("TextLabel", {
					Text = desc,
					Font = FONTS.Reg,
					TextSize = 11,
					TextTruncate = Enum.TextTruncate.AtEnd,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, w, 0, 13),
					Position = UDim2.fromOffset(14, 28),
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = row,
				})
				paint(function() d.TextColor3 = T.SubText end)
			end
			return lbl
		end

		-- small control container (dropdown display / keybind / input)
		local function controlBox(parent, width, height)
			local box = new("Frame", {
				Size = UDim2.fromOffset(width, height or 28),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				BorderSizePixel = 0,
				Parent = parent,
			}, { corner(6) })
			local bStroke = stroke(nil, 1, 0.75)
			bStroke.Parent = box
			paint(function()
				box.BackgroundColor3 = T.PanelLight
				bStroke.Color = T.Border
			end)
			return box, bStroke
		end

		-- ── BUTTON ───────────────────────────────────────────────
		function Tab:CreateButton(o)
			o = o or {}
			local desc = o.Description or o.Desc
			local row = baseRow(desc and 50 or 44)
			local btn = new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Parent = row,
			})
			rowLabel(row, o.Name or "Button", 34, desc)
			local chevron = new("TextLabel", {
				Text = "›",
				Font = FONTS.Bold,
				TextSize = 17,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 20, 1, 0),
				Position = UDim2.new(1, -30, 0, 0),
				Parent = row,
			})
			paint(function() chevron.TextColor3 = T.SubText end)

			rowHover(btn, row)
			btn.MouseEnter:Connect(function()
				tween(chevron, { TextColor3 = accentC, Position = UDim2.new(1, -26, 0, 0) }, 0.12)
			end)
			btn.MouseLeave:Connect(function()
				tween(chevron, { TextColor3 = T.SubText, Position = UDim2.new(1, -30, 0, 0) }, 0.12)
			end)
			btn.MouseButton1Click:Connect(function()
				tween(row, { BackgroundTransparency = 0 }, 0.06)
				task.delay(0.06, function()
					if row.Parent then tween(row, { BackgroundTransparency = 0.05 }, 0.15) end
				end)
				if o.Callback then
					local ok, err = pcall(o.Callback)
					if not ok then warn("[VeilUI] button error: " .. tostring(err)) end
				end
			end)
			return { Instance = row }
		end

		-- ── TOGGLE ───────────────────────────────────────────────
		function Tab:CreateToggle(o)
			o = o or {}
			local flag = o.Flag
			local state = Window:_registerFlag(flag, nil, o.CurrentValue == true)

			local desc = o.Description or o.Desc
			local row = baseRow(desc and 50 or 44)
			rowLabel(row, o.Name or "Toggle", 64, desc)

			local switchBg = new("Frame", {
				Size = UDim2.fromOffset(40, 22),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				BorderSizePixel = 0,
				Parent = row,
			}, { corner(11) })
			local knob = new("Frame", {
				Size = UDim2.fromOffset(16, 16),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderSizePixel = 0,
				Parent = switchBg,
			}, { corner(8) })
			paint(function()
				switchBg.BackgroundColor3 = state and accentC or T.Border
			end)

			local clickArea = new("TextButton", {
				Text = "", AutoButtonColor = false,
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Parent = row,
			})
			rowHover(clickArea, row)

			local Toggle = {}
			local function apply(v, fire)
				state = v == true
				tween(switchBg, { BackgroundColor3 = state and accentC or T.Border }, 0.15)
				tween(knob, { Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, 0.15)
				Window:_setFlag(flag, state)
				if fire and o.Callback then
					local ok, err = pcall(o.Callback, state)
					if not ok then warn("[VeilUI] toggle error: " .. tostring(err)) end
				end
			end

			clickArea.MouseButton1Click:Connect(function() apply(not state, true) end)
			Window._flagSetters[flag or ("__anon" .. tostring(row))] = function(v) apply(v, false) end

			function Toggle:Set(v) apply(v, true) end
			function Toggle:Get() return state end

			if o.Callback then
				task.spawn(function()
					local ok, err = pcall(o.Callback, state)
					if not ok then warn("[VeilUI] toggle init error: " .. tostring(err)) end
				end)
			end

			return Toggle
		end

		-- ── SLIDER ───────────────────────────────────────────────
		function Tab:CreateSlider(o)
			o = o or {}
			local flag = o.Flag
			local min = (o.Range and o.Range[1]) or 0
			local max = (o.Range and o.Range[2]) or 100
			local increment = o.Increment or 1
			local suffix = o.Suffix or ""
			local value = Window:_registerFlag(flag, nil, o.CurrentValue or min)

			local row = baseRow(54)
			local lbl = new("TextLabel", {
				Text = o.Name or "Slider",
				Font = FONTS.Med,
				TextSize = 14,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -100, 0, 18),
				Position = UDim2.fromOffset(14, 8),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
			local valueLabel = new("TextLabel", {
				Text = string.format("%.2g", value) .. suffix,
				Font = FONTS.Bold,
				TextSize = 13,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 80, 0, 18),
				Position = UDim2.new(1, -94, 0, 8),
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = row,
			})
			paint(function()
				lbl.TextColor3 = T.Text
				valueLabel.TextColor3 = accentC
			end)

			local track = new("Frame", {
				Size = UDim2.new(1, -28, 0, 4),
				Position = UDim2.new(0, 14, 1, -15),
				BorderSizePixel = 0,
				Parent = row,
			}, { corner(2) })
			local frac0 = (value - min) / math.max(max - min, 1e-9)
			local fill = new("Frame", {
				Size = UDim2.new(frac0, 0, 1, 0),
				BorderSizePixel = 0,
				Parent = track,
			}, { corner(2) })
			local knob = new("Frame", {
				Size = UDim2.fromOffset(12, 12),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(frac0, 0, 0.5, 0),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderSizePixel = 0,
				ZIndex = 2,
				Parent = track,
			}, { corner(6), stroke(Color3.fromRGB(0, 0, 0), 1, 0.85) })
			paint(function()
				track.BackgroundColor3 = T.Border
				fill.BackgroundColor3 = accentC
			end)

			local Slider = {}

			local function setFromAlpha(alpha, fire)
				alpha = math.clamp(alpha, 0, 1)
				local raw = min + (max - min) * alpha
				raw = math.floor(raw / increment + 0.5) * increment
				raw = math.clamp(raw, min, max)
				value = raw
				local frac = (value - min) / math.max(max - min, 1e-9)
				fill.Size = UDim2.new(frac, 0, 1, 0)
				knob.Position = UDim2.new(frac, 0, 0.5, 0)
				valueLabel.Text = tostring(value) .. suffix
				Window:_setFlag(flag, value)
				if fire and o.Callback then
					local ok, err = pcall(o.Callback, value)
					if not ok then warn("[VeilUI] slider error: " .. tostring(err)) end
				end
			end

			track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					setFromAlpha((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, true)

					-- listen globally only while dragging, then disconnect
					local moveConn, endConn
					moveConn = addConn(UserInputService.InputChanged:Connect(function(i)
						if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
							setFromAlpha((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, true)
						end
					end))
					endConn = addConn(UserInputService.InputEnded:Connect(function(i)
						if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
							if moveConn then moveConn:Disconnect() end
							if endConn then endConn:Disconnect() end
						end
					end))
				end
			end)

			Window._flagSetters[flag or ("__anon" .. tostring(row))] = function(v)
				setFromAlpha((v - min) / math.max(max - min, 1e-9), false)
			end

			function Slider:Set(v)
				setFromAlpha((v - min) / math.max(max - min, 1e-9), true)
			end
			function Slider:Get() return value end

			return Slider
		end

		-- ── INPUT ────────────────────────────────────────────────
		function Tab:CreateInput(o)
			o = o or {}
			local flag = o.Flag
			local row = baseRow(44)
			rowLabel(row, o.Name or "Input", 160)

			local boxHolder, boxStroke = controlBox(row, 150)
			local box = new("TextBox", {
				Text = tostring(Window:_registerFlag(flag, nil, o.CurrentValue or "")),
				PlaceholderText = o.PlaceholderText or o.Placeholder or "",
				Font = FONTS.Reg,
				TextSize = 12,
				ClearTextOnFocus = false,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				Parent = boxHolder,
			}, { pad(9, 0, 9, 0) })
			paint(function()
				box.TextColor3 = T.Text
				box.PlaceholderColor3 = T.SubText
			end)

			box.Focused:Connect(function()
				tween(boxStroke, { Color = accentC, Transparency = 0.2 }, 0.12)
			end)
			box.FocusLost:Connect(function(_enter)
				tween(boxStroke, { Color = T.Border, Transparency = 0.75 }, 0.12)
				Window:_setFlag(flag, box.Text)
				if o.Callback then
					local ok, err = pcall(o.Callback, box.Text)
					if not ok then warn("[VeilUI] input error: " .. tostring(err)) end
				end
			end)

			Window._flagSetters[flag or ("__anon" .. tostring(row))] = function(v) box.Text = tostring(v) end

			local Input = {}
			function Input:Set(v) box.Text = tostring(v) end
			function Input:Get() return box.Text end
			return Input
		end

		-- ── DROPDOWN ─────────────────────────────────────────────
		function Tab:CreateDropdown(o)
			o = o or {}
			local flag = o.Flag
			local options = o.Options or {}
			local multi = o.MultipleOptions == true
			local selected = {}

			local initial = Window:_registerFlag(flag, nil, o.CurrentOption)
			if type(initial) == "table" then
				for _, v in ipairs(initial) do selected[v] = true end
			elseif type(initial) == "string" then
				selected[initial] = true
			end

			local row = baseRow(44)
			rowLabel(row, o.Name or "Dropdown", 150)

			local function selectedText()
				local names = {}
				for opt in pairs(selected) do names[#names + 1] = opt end
				if #names == 0 then return "Select..." end
				table.sort(names)
				return table.concat(names, ", ")
			end

			local dispHolder = controlBox(row, 140)
			dispHolder.AnchorPoint = Vector2.new(1, 0)
			dispHolder.Position = UDim2.new(1, -12, 0, 8)
			local display = new("TextButton", {
				Text = selectedText(),
				Font = FONTS.Reg,
				TextSize = 12,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				Parent = dispHolder,
			}, { pad(9, 0, 22, 0) })
			local caret = new("TextLabel", {
				Text = "▾",
				Font = FONTS.Bold,
				TextSize = 11,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(14, 14),
				Position = UDim2.new(1, -12, 0.5, 0),
				Parent = dispHolder,
			})
			paint(function()
				display.TextColor3 = T.Text
				caret.TextColor3 = T.SubText
			end)

			local listH = math.min(math.max(#options, 1) * 30 + 8, 158)
			local listFrame = new("Frame", {
				Size = UDim2.new(1, -24, 0, listH),
				Position = UDim2.new(0, 12, 0, 50),
				BorderSizePixel = 0,
				Visible = false,
				Parent = row,
			}, { corner(8) })
			local listStroke = stroke(nil, 1, 0.7)
			listStroke.Parent = listFrame
			paint(function()
				listFrame.BackgroundColor3 = T.PanelLight
				listFrame.BackgroundTransparency = 0.05
				listStroke.Color = T.Border
			end)
			local listScroll = new("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 3,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = listFrame,
			}, {
				new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
				pad(4, 4, 4, 4),
			})
			paint(function() listScroll.ScrollBarImageColor3 = T.Border end)

			local Dropdown = {}

			local function fireCallback()
				local names = {}
				for opt in pairs(selected) do names[#names + 1] = opt end
				table.sort(names)
				Window:_setFlag(flag, multi and names or names[1])
				display.Text = selectedText()
				if o.Callback then
					local ok, err = pcall(o.Callback, multi and names or names[1])
					if not ok then warn("[VeilUI] dropdown error: " .. tostring(err)) end
				end
			end

			local function closeList()
				listFrame.Visible = false
				row.Size = UDim2.new(1, 0, 0, 44)
				tween(caret, { Rotation = 0 }, 0.15)
			end

			for _, opt in ipairs(options) do
				local optBtn = new("TextButton", {
					Text = opt,
					Font = FONTS.Reg,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					AutoButtonColor = false,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 28),
					Parent = listScroll,
				}, { corner(6), pad(8, 0, 8, 0) })
				paint(function()
					optBtn.TextColor3 = selected[opt] and accentC or T.Text
					optBtn.BackgroundColor3 = T.Panel
				end)
				optBtn.MouseEnter:Connect(function() tween(optBtn, { BackgroundTransparency = 0.3 }, 0.08) end)
				optBtn.MouseLeave:Connect(function() tween(optBtn, { BackgroundTransparency = 1 }, 0.08) end)
				optBtn.MouseButton1Click:Connect(function()
					if multi then
						selected[opt] = not selected[opt] or nil
						optBtn.TextColor3 = selected[opt] and accentC or T.Text
					else
						for k in pairs(selected) do selected[k] = nil end
						selected[opt] = true
						for _, child in ipairs(listScroll:GetChildren()) do
							if child:IsA("TextButton") then
								child.TextColor3 = (child == optBtn) and accentC or T.Text
							end
						end
						closeList()
					end
					fireCallback()
				end)
			end

			display.MouseButton1Click:Connect(function()
				local open = not listFrame.Visible
				if open then
					listFrame.Visible = true
					row.Size = UDim2.new(1, 0, 0, 50 + listH + 8)
					tween(caret, { Rotation = 180 }, 0.15)
				else
					closeList()
				end
			end)

			Window._flagSetters[flag or ("__anon" .. tostring(row))] = function(v)
				for k in pairs(selected) do selected[k] = nil end
				if type(v) == "table" then
					for _, n in ipairs(v) do selected[n] = true end
				elseif type(v) == "string" then
					selected[v] = true
				end
				display.Text = selectedText()
			end

			function Dropdown:Set(v)
				for k in pairs(selected) do selected[k] = nil end
				if type(v) == "table" then
					for _, n in ipairs(v) do selected[n] = true end
				else
					selected[v] = true
				end
				fireCallback()
			end
			function Dropdown:Get()
				local names = {}
				for opt in pairs(selected) do names[#names + 1] = opt end
				return multi and names or names[1]
			end

			return Dropdown
		end

		-- ── KEYBIND ──────────────────────────────────────────────
		function Tab:CreateKeybind(o)
			o = o or {}
			local flag = o.Flag
			local current = Window:_registerFlag(flag, nil, o.CurrentKeybind or "None")
			local listening = false

			local row = baseRow(44)
			rowLabel(row, o.Name or "Keybind", 110)

			local keyHolder, keyStroke = controlBox(row, 96)
			local keyBtn = new("TextButton", {
				Text = tostring(current),
				Font = FONTS.Bold,
				TextSize = 12,
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				Parent = keyHolder,
			})
			paint(function() keyBtn.TextColor3 = listening and accentC or T.SubText end)

			local Keybind = {}
			keyBtn.MouseButton1Click:Connect(function()
				listening = true
				keyBtn.Text = "..."
				tween(keyStroke, { Color = accentC, Transparency = 0.2 }, 0.12)
			end)

			local conn
			conn = UserInputService.InputBegan:Connect(function(input, _gpe)
				if not listening then return end
				if input.UserInputType == Enum.UserInputType.Keyboard then
					current = input.KeyCode.Name
					keyBtn.Text = current
					listening = false
					tween(keyStroke, { Color = T.Border, Transparency = 0.75 }, 0.12)
					Window:_setFlag(flag, current)
					if o.Callback then
						local ok, err = pcall(o.Callback, current)
						if not ok then warn("[VeilUI] keybind error: " .. tostring(err)) end
					end
				end
			end)
			row.Destroying:Connect(function() if conn then conn:Disconnect() end end)

			function Keybind:Get() return current end
			function Keybind:Set(v) current = v; keyBtn.Text = v end

			return Keybind
		end

		-- ── COLOR PICKER ─────────────────────────────────────────
		function Tab:CreateColorPicker(o)
			o = o or {}
			local flag = o.Flag
			local color = Window:_registerFlag(flag, nil, o.Color or Color3.fromRGB(255, 255, 255))
			if type(color) == "table" then
				color = Color3.new(color[1], color[2], color[3])
			end

			local row = baseRow(44)
			rowLabel(row, o.Name or "Color", 56)

			local swatch = new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = color,
				AnchorPoint = Vector2.new(1, 0.5),
				Size = UDim2.fromOffset(30, 22),
				Position = UDim2.new(1, -12, 0.5, 0),
				Parent = row,
			}, { corner(6) })
			local swStroke = stroke(nil, 1, 0.6)
			swStroke.Parent = swatch
			paint(function() swStroke.Color = T.Border end)

			local popout = new("Frame", {
				Size = UDim2.new(1, -24, 0, 96),
				Position = UDim2.new(0, 12, 0, 50),
				BorderSizePixel = 0,
				Visible = false,
				Parent = row,
			}, { corner(8), pad(10, 8, 10, 8) })
			local popStroke = stroke(nil, 1, 0.7)
			popStroke.Parent = popout
			paint(function()
				popout.BackgroundColor3 = T.PanelLight
				popout.BackgroundTransparency = 0.05
				popStroke.Color = T.Border
			end)
			new("UIListLayout", { Padding = UDim.new(0, 6), Parent = popout })

			local ColorPicker = {}
			local r, g, b = color.R * 255, color.G * 255, color.B * 255

			local function updateColor()
				color = Color3.fromRGB(r, g, b)
				swatch.BackgroundColor3 = color
				Window:_setFlag(flag, { color.R, color.G, color.B })
				if o.Callback then
					local ok, err = pcall(o.Callback, color)
					if not ok then warn("[VeilUI] colorpicker error: " .. tostring(err)) end
				end
			end

			local function makeChannel(name, chColor, initial, setter)
				local chRow = new("Frame", {
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
					Parent = popout,
				})
				local chLbl = new("TextLabel", {
					Text = name,
					Font = FONTS.Bold,
					TextSize = 10,
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(12, 22),
					Parent = chRow,
				})
				paint(function() chLbl.TextColor3 = T.SubText end)
				local track = new("Frame", {
					Size = UDim2.new(1, -22, 0, 4),
					Position = UDim2.new(0, 18, 0.5, -2),
					BorderSizePixel = 0,
					Parent = chRow,
				}, { corner(2) })
				local fill = new("Frame", {
					Size = UDim2.new(initial / 255, 0, 1, 0),
					BackgroundColor3 = chColor,
					BorderSizePixel = 0,
					Parent = track,
				}, { corner(2) })
				paint(function() track.BackgroundColor3 = T.Border end)
				local function setAlpha(a)
					a = math.clamp(a, 0, 1)
					fill.Size = UDim2.new(a, 0, 1, 0)
					setter(math.floor(a * 255))
					updateColor()
				end
				track.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						setAlpha((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X)
						local moveConn, endConn
						moveConn = addConn(UserInputService.InputChanged:Connect(function(i)
							if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
								setAlpha((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X)
							end
						end))
						endConn = addConn(UserInputService.InputEnded:Connect(function(i)
							if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
								if moveConn then moveConn:Disconnect() end
								if endConn then endConn:Disconnect() end
							end
						end))
					end
				end)
			end

			makeChannel("R", Color3.fromRGB(240, 90, 100), r, function(v) r = v end)
			makeChannel("G", Color3.fromRGB(90, 210, 130), g, function(v) g = v end)
			makeChannel("B", Color3.fromRGB(90, 140, 250), b, function(v) b = v end)

			swatch.MouseButton1Click:Connect(function()
				popout.Visible = not popout.Visible
				row.Size = UDim2.new(1, 0, 0, popout.Visible and (50 + 96 + 8) or 44)
			end)

			Window._flagSetters[flag or ("__anon" .. tostring(row))] = function(v)
				if type(v) == "table" then
					color = Color3.new(v[1], v[2], v[3])
					swatch.BackgroundColor3 = color
				end
			end

			function ColorPicker:Get() return color end
			function ColorPicker:Set(c) color = c; swatch.BackgroundColor3 = c end

			return ColorPicker
		end

		-- ── PARAGRAPH ────────────────────────────────────────────
		function Tab:CreateParagraph(o)
			o = o or {}
			local row = new("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BorderSizePixel = 0,
				Parent = page,
			}, { corner(8), pad(14, 11, 14, 11) })
			paint(function()
				row.BackgroundColor3 = T.Panel
				row.BackgroundTransparency = 0.15
			end)

			local titleLbl = new("TextLabel", {
				Text = o.Title or "",
				Font = FONTS.Bold,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 17),
				Parent = row,
			})
			local contentLbl = new("TextLabel", {
				Text = o.Content or "",
				Font = FONTS.Reg,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.new(0, 0, 0, 20),
				Parent = row,
			})
			paint(function()
				titleLbl.TextColor3 = T.Text
				contentLbl.TextColor3 = T.SubText
			end)

			local Paragraph = {}
			function Paragraph:Set(t)
				t = t or {}
				if t.Title then titleLbl.Text = t.Title end
				if t.Content then contentLbl.Text = t.Content end
			end
			return Paragraph
		end

		-- ── LABEL ────────────────────────────────────────────────
		function Tab:CreateLabel(text)
			local holder = new("Frame", {
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				Parent = page,
			})
			local lbl = new("TextLabel", {
				Text = text or "",
				Font = FONTS.Reg,
				TextSize = 12,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -8, 1, 0),
				Position = UDim2.fromOffset(4, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = holder,
			})
			paint(function() lbl.TextColor3 = T.SubText end)
			local Label = {}
			function Label:Set(t) lbl.Text = t end
			return Label
		end

		-- ── SECTION (grouped-list style header) ──────────────────
		function Tab:CreateSection(titleText)
			local holder = new("Frame", {
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Parent = page,
			})
			local lbl = new("TextLabel", {
				Text = string.upper(titleText or "Section"),
				Font = FONTS.Bold,
				TextSize = 11,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -8, 0, 14),
				Position = UDim2.new(0, 4, 1, -16),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = holder,
			})
			paint(function() lbl.TextColor3 = T.SubText end)
			local Section = {}
			function Section:Set(t) lbl.Text = string.upper(t or "") end
			return Section
		end

		-- ── DIVIDER ──────────────────────────────────────────────
		function Tab:CreateDivider()
			local line = new("Frame", {
				Size = UDim2.new(1, -8, 0, 1),
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
				Parent = page,
			})
			paint(function() line.BackgroundColor3 = T.Border end)
			return line
		end

		return Tab
	end

	-- intro: subtle fade + scale
	do
		local targetSize = main.Size
		local targetPos = main.Position
		main.Size = UDim2.new(targetSize.X.Scale, math.floor(targetSize.X.Offset * 0.96), targetSize.Y.Scale, math.floor(targetSize.Y.Offset * 0.96))
		main.Position = targetPos + UDim2.fromOffset(
			math.floor((targetSize.X.Offset - main.Size.X.Offset) / 2),
			math.floor((targetSize.Y.Offset - main.Size.Y.Offset) / 2)
		)
		main.BackgroundTransparency = 1
		mainStroke.Transparency = 1
		tween(main, { Size = targetSize, Position = targetPos, BackgroundTransparency = glassAmt }, 0.3, Enum.EasingStyle.Quint)
		tween(mainStroke, { Transparency = 0.6 }, 0.35)
		setBlur(true)
	end

	return Window
end

return Veil
