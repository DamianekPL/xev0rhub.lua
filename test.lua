
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local XevorUI = {}
XevorUI.__index = XevorUI

export type Control = {
	Get: (self: Control) -> any,
	Set: (self: Control, value: any, silent: boolean?) -> (),
	Destroy: (self: Control) -> (),
}

local DEFAULT_THEME = {
	Background = Color3.fromRGB(22, 20, 31),
	Topbar = Color3.fromRGB(29, 26, 40),
	Sidebar = Color3.fromRGB(34, 30, 48),
	Panel = Color3.fromRGB(42, 37, 57),
	Field = Color3.fromRGB(28, 25, 39),
	Text = Color3.fromRGB(245, 240, 255),
	Muted = Color3.fromRGB(180, 166, 203),
	Accent = Color3.fromRGB(160, 91, 255),
	Line = Color3.fromRGB(88, 72, 116),
}

local NOTIFICATION_COLORS = {
	Info = DEFAULT_THEME.Accent,
	Success = Color3.fromRGB(78, 214, 155),
	Warning = Color3.fromRGB(255, 191, 87),
	Error = Color3.fromRGB(255, 106, 133),
}

local function make(className: string, properties: {[string]: any}?, parent: Instance?): any
	local instance = Instance.new(className)
	for property, value in pairs(properties or {}) do
		(instance :: any)[property] = value
	end
	instance.Parent = parent
	return instance
end

local function getPlayerGui(silent: boolean?)
	local player = Players.LocalPlayer
	if player then
		local playerGui = player:FindFirstChild("PlayerGui")
		if playerGui then
			return playerGui
		end
	end

	local root = nil
	if gethui then
		root = gethui()
	end
	if not root then
		root = game:GetService("CoreGui")
	end

	if not root then
		if silent then return nil end
		return nil
	end

	local existing = root:FindFirstChild("XevorUI_Root")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "XevorUI_Root"
	screenGui.ResetOnSpawn = false
	if syn and syn.protect_gui then
		syn.protect_gui(screenGui)
	end
	screenGui.Parent = root
	return screenGui
end

local function corner(parent: Instance, radius: number?)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end

local function stroke(parent: Instance, color: Color3)
	return make("UIStroke", { Color = color, Thickness = 1 }, parent)
end

local function padding(parent: Instance, left: number, right: number?)
	return make("UIPadding", {
		PaddingLeft = UDim.new(0, left),
		PaddingRight = UDim.new(0, right or left),
	}, parent)
end

local function isPrimaryInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function shallowMerge(base: {[string]: any}, override: {[string]: any}?): {[string]: any}
	local result = {}
	for key, value in pairs(base) do result[key] = value end
	for key, value in pairs(override or {}) do result[key] = value end
	return result
end

local function disconnectAll(connections: {RBXScriptConnection})
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end

local function tween(instance: Instance, duration: number, properties: {[string]: any}, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local animation = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), properties)
	animation:Play()
	return animation
end

local function addHover(button: GuiButton, normal: Color3, hovered: Color3)
	button.MouseEnter:Connect(function()
		tween(button, 0.12, { BackgroundColor3 = hovered })
		local scale = button:FindFirstChild("HoverScale") :: UIScale?
		if not scale then scale = make("UIScale", { Name = "HoverScale", Scale = 1 }, button) end
		tween(scale, 0.12, { Scale = 1.02 })
	end)
	button.MouseLeave:Connect(function()
		tween(button, 0.12, { BackgroundColor3 = normal })
		local scale = button:FindFirstChild("HoverScale") :: UIScale?
		if scale then tween(scale, 0.12, { Scale = 1 }) end
	end)
end

local function safeCallback(callback: ((...any) -> ())?, ...: any)
	if not callback then return end
	local ok, err = pcall(callback, ...)
	if not ok then warn("[XevorUI] Callback error:", err) end
end

local function serializeValue(value: any): any
	local valueType = typeof(value)
	if valueType == "Color3" then
		return { __type = "Color3", R = value.R, G = value.G, B = value.B }
	elseif valueType == "EnumItem" then
		return { __type = "EnumItem", EnumType = value.EnumType.Name, Name = value.Name }
	elseif type(value) == "table" then
		local result = {}
		for key, item in pairs(value) do
			result[key] = serializeValue(item)
		end
		return result
	end
	return value
end

local function deserializeValue(value: any): any
	if type(value) ~= "table" then return value end
	if value.__type == "Color3" then
		return Color3.new(value.R, value.G, value.B)
	elseif value.__type == "EnumItem" and value.EnumType and value.Name then
		local enumType = Enum[value.EnumType]
		return enumType and enumType[value.Name] or nil
	end
	local result = {}
	for key, item in pairs(value) do
		result[key] = deserializeValue(item)
	end
	return result
end

local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab
local Section = {}
Section.__index = Section

function XevorUI.CreateWindow(first: any, second: any?)
	-- Supports both XevorUI.CreateWindow(options) and XevorUI:CreateWindow(options).
	local options = first == XevorUI and second or first
	if type(options) == "string" then options = { Title = options } end
	options = options or {}
	local theme = shallowMerge(DEFAULT_THEME, options.Theme)
	local self = setmetatable({
		Title = options.Title or options.Name or "Xevor",
		Theme = theme,
		Tabs = {},
		Controls = {},
		Connections = {},
		ToggleKey = options.ToggleKey or Enum.KeyCode.RightControl,
		Destroyed = false,
	}, Window)

	local playerGui = getPlayerGui(false)
	if not playerGui then
		warn("[XevorUI] Window creation skipped because no GUI parent was available.")
		return nil
	end
	local old = playerGui:FindFirstChild("XevorUI")
	if old then old:Destroy() end

	self.Gui = make("ScreenGui", {
		Name = "XevorUI", ResetOnSpawn = false, DisplayOrder = options.DisplayOrder or 10,
		IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	self.Gui.Enabled = true

	self.Notifications = make("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(290, 400), BackgroundTransparency = 1,
	}, self.Gui)
	make("UIListLayout", {
		Padding = UDim.new(0, 7), HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Top, SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.Notifications)

	-- Compact default proportions: a focused menu rather than a full-screen panel.
	local size = options.Size or UDim2.fromOffset(720, 470)
	local window = make("Frame", {
		Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = options.Position or UDim2.fromScale(0.5, 0.5),
		Size = size, BackgroundColor3 = theme.Background, BorderSizePixel = 0, ClipsDescendants = true,
	}, self.Gui)
	corner(window, 8)
	stroke(window, Color3.fromRGB(9, 7, 13))
	self.Frame = window
	local openingScale = make("UIScale", { Scale = 0.94 }, window)
	tween(openingScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)

	local topbar = make("Frame", {
		Name = "Topbar", Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = theme.Topbar, BorderSizePixel = 0,
	}, window)
	corner(topbar, 8)
	make("Frame", { Position = UDim2.new(0, 0, 1, -8), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = theme.Topbar, BorderSizePixel = 0 }, topbar)
	make("TextLabel", {
		Position = UDim2.fromOffset(13, 0), Size = UDim2.new(1, -94, 1, 0), BackgroundTransparency = 1,
		Text = string.upper(self.Title) .. "  |  MAIN MENU", Font = Enum.Font.GothamBold, TextSize = 12,
		TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, topbar)

	local minimize = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -37, 0.5, 0), Size = UDim2.fromOffset(22, 24),
		BackgroundTransparency = 1, Text = "—", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = theme.Muted,
	}, topbar)
	minimize.Activated:Connect(function() self:SetMinimized(not self.Minimized) end)
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(22, 24),
		BackgroundTransparency = 1, Text = "×", Font = Enum.Font.Gotham, TextSize = 24, TextColor3 = theme.Muted,
	}, topbar)
	close.Activated:Connect(function() self:SetVisible(false) end)

	self.Sidebar = make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 34), Size = UDim2.new(0, 178, 1, -34), BackgroundColor3 = theme.Sidebar,
		BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = theme.Line,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	}, window)
	padding(self.Sidebar, 7)
	make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, self.Sidebar)
	self.Content = make("Frame", { Position = UDim2.fromOffset(178, 34), Size = UDim2.new(1, -178, 1, -34), BackgroundTransparency = 1 }, window)

	-- Dragging is intentionally attached to the top bar only, so controls remain usable on touch devices.
	local dragging, dragStart, startPosition = false, Vector2.zero, UDim2.new()
	table.insert(self.Connections, topbar.InputBegan:Connect(function(input)
		if isPrimaryInput(input) then dragging, dragStart, startPosition = true, input.Position, window.Position end
	end))
	table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			window.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
		end
	end))
	table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input) if isPrimaryInput(input) then dragging = false end end))
	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == self.ToggleKey then self:SetVisible(not self.Gui.Enabled) end
	end))
	if options.Watermark == true then self:Watermark() end

	return self
end

function XevorUI.new(title: string) return XevorUI.CreateWindow({ Title = title }) end

function XevorUI.LoadingScreen(options: {[string]: any}?)
	options = options or {}
	local playerGui = getPlayerGui(true)
	if not playerGui then return end

	local BLACK = Color3.fromRGB(8, 6, 14)
	local PURPLE = Color3.fromRGB(138, 43, 226)
	local PURPLE_BRIGHT = Color3.fromRGB(180, 80, 255)
	local PURPLE_DARK = Color3.fromRGB(45, 20, 70)
	local TEXT_COLOR = Color3.fromRGB(210, 190, 255)
	local CONSOLE_GREEN = Color3.fromRGB(120, 230, 130)
	local CONSOLE_CYAN = Color3.fromRGB(100, 220, 255)
	local CONSOLE_DIM = Color3.fromRGB(140, 130, 170)

	local gui = make("ScreenGui", {
		Name = options.Name or "XevorUI_LoadingScreen",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = options.DisplayOrder or 9999,
	}, playerGui)

	local completionSound = make("Sound", {
		Name = "LoadingCompleteSound",
		SoundId = options.SoundId or "rbxassetid://114652139804308",
		Volume = options.SoundVolume or 0.7,
		Looped = false,
	}, gui)

	local backdrop = make("Frame", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BorderSizePixel = 0,
	}, gui)

	make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 10, 45)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(12, 8, 22)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 3, 12)),
		}),
		Rotation = 45,
	}, backdrop)

	local grid = make("Frame", { Name = "Grid", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, backdrop)
	local gridSize = 40
	for x = 0, 1920, gridSize do
		make("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromOffset(x, 0), BackgroundColor3 = PURPLE_DARK, BackgroundTransparency = 0.92, BorderSizePixel = 0 }, grid)
	end
	for y = 0, 1080, gridSize do
		make("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, y), BackgroundColor3 = PURPLE_DARK, BackgroundTransparency = 0.92, BorderSizePixel = 0 }, grid)
	end

	local container = make("Frame", {
		Name = "Container",
		Size = UDim2.fromOffset(520, 340),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	}, backdrop)

	local title = make("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		Text = options.Title or "> Loading_Screen.exe",
		TextColor3 = PURPLE_BRIGHT,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, container)

	local statusLabel = make("TextLabel", {
		Name = "Status",
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 44),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		Text = options.Status or "Initializing...",
		TextColor3 = TEXT_COLOR,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, container)

	local barBg = make("Frame", {
		Name = "BarBg",
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.fromOffset(0, 76),
		BackgroundColor3 = PURPLE_DARK,
		BorderSizePixel = 0,
	}, container)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, barBg)

	local barFill = make("Frame", {
		Name = "BarFill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = PURPLE,
		BorderSizePixel = 0,
	}, barBg)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, barFill)
	make("UIGradient", { Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PURPLE),
		ColorSequenceKeypoint.new(0.5, PURPLE_BRIGHT),
		ColorSequenceKeypoint.new(1, PURPLE),
	}) }, barFill)

	local progressText = make("TextLabel", {
		Name = "ProgressText",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 92),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		Text = "0%",
		TextColor3 = CONSOLE_DIM,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, container)

	local consoleFrame = make("Frame", {
		Name = "Console",
		Size = UDim2.new(1, 0, 0, 140),
		Position = UDim2.fromOffset(0, 120),
		BackgroundColor3 = Color3.fromRGB(15, 10, 25),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, container)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, consoleFrame)
	make("UIStroke", { Color = PURPLE_DARK, Thickness = 1, Transparency = 0.3 }, consoleFrame)

	local consoleHeader = make("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Color3.fromRGB(25, 15, 40), BorderSizePixel = 0 }, consoleFrame)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, consoleHeader)

	local dotColors = { Color3.fromRGB(255, 95, 95), Color3.fromRGB(255, 190, 85), Color3.fromRGB(95, 200, 100) }
	for i, col in ipairs(dotColors) do
		local dot = make("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(8 + (i - 1) * 14, 8), BackgroundColor3 = col, BorderSizePixel = 0 }, consoleHeader)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
	end

	make("TextLabel", {
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(60, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		Text = options.ConsoleTitle or "loading_console.sh",
		TextColor3 = CONSOLE_DIM,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, consoleHeader)

	local consoleScroller = make("ScrollingFrame", {
		Name = "Log",
		Size = UDim2.new(1, -16, 1, -32),
		Position = UDim2.fromOffset(8, 28),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = PURPLE,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, consoleFrame)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, consoleScroller)

	local consoleLines = {}
	local lineOrder = 0

	local function addConsoleLine(text, color)
		lineOrder += 1
		local label = make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			Text = text,
			TextColor3 = color or CONSOLE_DIM,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			LayoutOrder = lineOrder,
		}, consoleScroller)
		table.insert(consoleLines, label)
		consoleScroller.CanvasPosition = Vector2.new(0, math.huge)
	end

	local function typewriter(label, text, speed)
		speed = speed or 0.02
		label.Text = ""
		for i = 1, #text do
			label.Text = string.sub(text, 1, i)
			task.wait(speed)
		end
	end

	local function setProgress(pct)
		pct = math.clamp(pct, 0, 100)
		TweenService:Create(barFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(pct / 100, 1) }):Play()
		progressText.Text = string.format("%d%%", math.floor(pct))
	end

	local function fadeOutAndDestroy()
		completionSound:Play()
		local fadeInfo = TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		local tweens = {}
		for _, desc in ipairs(gui:GetDescendants()) do
			if desc:IsA("TextLabel") then
				table.insert(tweens, TweenService:Create(desc, fadeInfo, { TextTransparency = 1 }))
			elseif desc:IsA("Frame") then
				table.insert(tweens, TweenService:Create(desc, fadeInfo, { BackgroundTransparency = 1 }))
			elseif desc:IsA("UIStroke") then
				table.insert(tweens, TweenService:Create(desc, fadeInfo, { Transparency = 1 }))
			elseif desc:IsA("ImageLabel") then
				table.insert(tweens, TweenService:Create(desc, fadeInfo, { ImageTransparency = 1, BackgroundTransparency = 1 }))
			end
		end
		for _, tw in ipairs(tweens) do tw:Play() end
		task.delay(1.1, function()
			if gui.Parent then gui:Destroy() end
			if options.OnComplete then safeCallback(options.OnComplete) end
		end)
	end

	local defaultSteps = options.Steps or {
		{ text = "[INFO] Booting loading sequence...", color = CONSOLE_CYAN, status = "Initializing...", progress = 5 },
		{ text = "[INFO] Getting system info...", color = CONSOLE_CYAN, status = "Getting info...", progress = 12 },
		{ text = "[INFO] Platform: Roblox Client", color = CONSOLE_DIM, status = "Getting info...", progress = 18 },
		{ text = "[INFO] SUNC: Retrieved successfully", color = CONSOLE_GREEN, status = "Getting SUNC...", progress = 28 },
		{ text = "[INFO] UNC: Retrieved successfully", color = CONSOLE_GREEN, status = "Getting UNC...", progress = 38 },
		{ text = "[INFO] Executor environment validated", color = CONSOLE_GREEN, status = "Validating environment...", progress = 45 },
		{ text = "[INFO] Downloading assets...", color = CONSOLE_CYAN, status = "Downloading assets...", progress = 52 },
		{ text = "[INFO] Fetching textures...", color = CONSOLE_DIM, status = "Downloading assets...", progress = 60 },
		{ text = "[INFO] Fetching meshes...", color = CONSOLE_DIM, status = "Downloading assets...", progress = 68 },
		{ text = "[INFO] Fetching audio...", color = CONSOLE_DIM, status = "Downloading assets...", progress = 75 },
		{ text = "[INFO] Caching assets locally...", color = CONSOLE_DIM, status = "Caching assets...", progress = 82 },
		{ text = "[INFO] Verifying integrity...", color = CONSOLE_CYAN, status = "Verifying load...", progress = 88 },
		{ text = "[INFO] All assets loaded successfully", color = CONSOLE_GREEN, status = "Checking load...", progress = 94 },
		{ text = "[OK] Everything loaded successfully!", color = CONSOLE_GREEN, status = "Load complete!", progress = 100 },
	}

	task.spawn(function()
		typewriter(title, options.Title or "> Loading_Screen.exe", 0.04)
		for _, step in ipairs(defaultSteps) do
			statusLabel.Text = step.status
			addConsoleLine(step.text, step.color)
			setProgress(step.progress)
			task.wait(step.delay or (math.random(25, 60) / 100))
		end
		statusLabel.Text = options.DoneText or "Ready!"
		task.wait(1.0)
		fadeOutAndDestroy()
	end)

	return gui
end

function XevorUI.ShowKeySystem(options: {[string]: any}?)
	options = options or {}
	local playerGui = getPlayerGui(true)
	if not playerGui then return end
	local old = playerGui:FindFirstChild("XevorPurpleKeySystem")
	if old then old:Destroy() end

	local C = {
		bg = Color3.fromRGB(22, 20, 31),
		bar = Color3.fromRGB(29, 26, 40),
		side = Color3.fromRGB(34, 30, 48),
		panel = Color3.fromRGB(42, 37, 57),
		field = Color3.fromRGB(28, 25, 39),
		text = Color3.fromRGB(245, 240, 255),
		muted = Color3.fromRGB(180, 166, 203),
		accent = Color3.fromRGB(160, 91, 255),
		line = Color3.fromRGB(88, 72, 116),
	}

	local function n(className, props, parent)
		local inst = Instance.new(className)
		for key, value in pairs(props or {}) do
			inst[key] = value
		end
		inst.Parent = parent
		return inst
	end

	local gui = n("ScreenGui", { Name = "XevorPurpleKeySystem", ResetOnSpawn = false }, playerGui)
	local popupSound = n("Sound", { Name = "KeySystemOpenSound", SoundId = options.SoundId or "rbxassetid://114652139804308", Volume = options.SoundVolume or 0.7, Looped = false }, gui)
	local win = n("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(610, 390), BackgroundColor3 = C.bg, BorderSizePixel = 0 }, gui)
	n("UICorner", { CornerRadius = UDim.new(0, 7) }, win)
	n("UIStroke", { Color = Color3.fromRGB(9, 7, 13), Thickness = 1 }, win)

	local top = n("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.bar, BorderSizePixel = 0 }, win)
	n("UICorner", { CornerRadius = UDim.new(0, 7) }, top)
	n("Frame", { Position = UDim2.new(0, 0, 1, -7), Size = UDim2.new(1, 0, 0, 7), BackgroundColor3 = C.bar, BorderSizePixel = 0 }, top)
	n("TextLabel", { Position = UDim2.fromOffset(11, 0), Size = UDim2.fromOffset(450, 30), BackgroundTransparency = 1, Text = "XEVOR  |  KEY SYSTEM", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, top)

	local exit = n("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(18, 20), BackgroundTransparency = 1, Text = "×", Font = Enum.Font.Gotham, TextSize = 22, TextColor3 = C.muted }, top)

	local side = n("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.fromOffset(196, 360), BackgroundColor3 = C.side, BorderSizePixel = 0 }, win)
	n("TextLabel", { Position = UDim2.fromOffset(15, 18), Size = UDim2.fromOffset(164, 19), BackgroundTransparency = 1, Text = "CHANGELOG", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, side)
	n("Frame", { Position = UDim2.fromOffset(14, 44), Size = UDim2.fromOffset(168, 2), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, side)
	n("TextLabel", { Position = UDim2.fromOffset(15, 63), Size = UDim2.fromOffset(164, 205), BackgroundTransparency = 1, Text = "v1.0  •  NEW\n\nWelcome to Xevor.\n\n• Purple user interface\n• Updated main menu\n• Key-system design\n\nMore updates soon.", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, side)

	local body = n("Frame", { Position = UDim2.fromOffset(196, 30), Size = UDim2.fromOffset(414, 360), BackgroundTransparency = 1 }, win)
	n("TextLabel", { Position = UDim2.fromOffset(25, 30), Size = UDim2.fromOffset(360, 23), BackgroundTransparency = 1, Text = "Enter your key", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, body)
	n("TextLabel", { Position = UDim2.fromOffset(25, 57), Size = UDim2.fromOffset(360, 20), BackgroundTransparency = 1, Text = "Paste your access key below to continue.", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left }, body)
	n("Frame", { Position = UDim2.fromOffset(25, 94), Size = UDim2.fromOffset(364, 2), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, body)

	local input = n("TextBox", { Position = UDim2.fromOffset(25, 119), Size = UDim2.fromOffset(364, 34), BackgroundColor3 = C.field, BorderSizePixel = 0, PlaceholderText = "Enter key here...", PlaceholderColor3 = C.muted, Text = "", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, body)
	n("UIStroke", { Color = C.line }, input)
	n("UIPadding", { PaddingLeft = UDim.new(0, 9) }, input)

	local function button(text, x, y, width, purple)
		local b = n("TextButton", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, 33), BackgroundColor3 = purple and C.accent or C.field, BorderSizePixel = 0, Text = text, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.text }, body)
		n("UIStroke", { Color = purple and C.accent or C.line }, b)
		return b
	end

	local get = button("GET KEY", 25, 170, 176, false)
	local verify = button("VERIFY KEY", 213, 170, 176, true)
	local discord = button("JOIN DISCORD", 25, 215, 364, false)

	local note = n("TextLabel", { Position = UDim2.fromOffset(25, 268), Size = UDim2.fromOffset(364, 20), BackgroundTransparency = 1, Text = "Design preview — no actions are connected.", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.muted }, body)

	local function revealMainMenu()
		if options.OnSuccess then
			safeCallback(options.OnSuccess)
		end
		if gui and gui.Parent then
			gui:Destroy()
		end
	end

	local function verifyKey()
		if input.Text == "" then
			note.Text = "Enter a key first."
			note.TextColor3 = C.accent
			return
		end

		local expected = options.Key or "XEVOR-ACCESS-KEY"
		local valid = false
		if type(options.Validate) == "function" then
			local ok, result = pcall(options.Validate, input.Text, expected)
			valid = ok and result == true
			if not ok then
				warn("[XevorUI] Key validation callback failed:", result)
			end
		else
			valid = input.Text == expected
		end

		if valid then
			note.Text = "Key verified successfully. Opening menu..."
			note.TextColor3 = Color3.fromRGB(78, 214, 155)
			task.delay(0.1, revealMainMenu)
		else
			note.Text = "Invalid key — please try again."
			note.TextColor3 = Color3.fromRGB(255, 106, 133)
		end
	end

	get.Activated:Connect(function()
		note.Text = "Get-key button pressed — design preview only."
		note.TextColor3 = C.accent
	end)

	verify.Activated:Connect(verifyKey)
	input.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			verifyKey()
		end
	end)

	discord.Activated:Connect(function()
		note.Text = "Join-Discord button pressed — design preview only."
		note.TextColor3 = C.accent
	end)

	popupSound:Play()
	exit.Activated:Connect(function()
		if gui and gui.Parent then
			gui:Destroy()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and gui and gui.Parent and input.KeyCode == Enum.KeyCode.RightShift then
			win.Visible = not win.Visible
		end
	end)

	return gui
end

function XevorUI.StartWithKeySystem(options: {[string]: any}?)
	options = options or {}
	local expectedKey = options.Key or "XEVOR-ACCESS-KEY"
	local windowOptions = options.WindowOptions or { Title = options.WindowTitle or "Xevor" }
	local mainMenu = nil
	local function openMainMenu()
		if options.OnMainMenu then
			safeCallback(options.OnMainMenu)
		elseif not mainMenu then
			mainMenu = XevorUI.CreateWindow(windowOptions)
		end
	end

	XevorUI.LoadingScreen({
		Title = options.LoadingTitle,
		Status = options.LoadingStatus,
		DoneText = options.DoneText,
		OnComplete = function()
			XevorUI.ShowKeySystem({
				Key = expectedKey,
				OnSuccess = openMainMenu,
			})
		end,
	})
end

function Window:SetVisible(visible: boolean)
	if self.Destroyed then return end
	if visible then
		if self.Gui.Enabled then return end
		self.Gui.Enabled = true
		local scale = self.Frame:FindFirstChild("WindowScale") :: UIScale?
		if not scale then scale = make("UIScale", { Name = "WindowScale", Scale = 0.94 }, self.Frame) end
		tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	else
		if not self.Gui.Enabled then return end
		local scale = self.Frame:FindFirstChild("WindowScale") :: UIScale?
		if not scale then scale = make("UIScale", { Name = "WindowScale", Scale = 1 }, self.Frame) end
		local hideTween = TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.94 })
		hideTween:Play()
		hideTween.Completed:Connect(function()
			if self.Gui then self.Gui.Enabled = false end
		end)
	end
end

function Window:SetMinimized(minimized: boolean)
	self.Minimized = minimized
	self.Sidebar.Visible = not minimized
	self.Content.Visible = not minimized
	if minimized then
		self.ExpandedSize = self.Frame.Size
		tween(self.Frame, 0.18, { Size = UDim2.new(self.Frame.Size.X.Scale, self.Frame.Size.X.Offset, 0, 34) })
	else
		tween(self.Frame, 0.18, { Size = self.ExpandedSize or self.Frame.Size })
		self.ExpandedSize = nil
	end
end

function Window:SetToggleKey(key: Enum.KeyCode) self.ToggleKey = key end

function Window:Notify(options: any, message: string?, duration: number?)
	if self.Destroyed then return end
	if type(options) == "string" then options = { Title = options, Content = message, Duration = duration } end
	options = options or {}
	local kind = options.Type or "Info"
	local accent = NOTIFICATION_COLORS[kind] or self.Theme.Accent
	local card = make("Frame", { Size = UDim2.fromOffset(290, 58), BackgroundColor3 = self.Theme.Panel, BorderSizePixel = 0 }, self.Notifications)
	corner(card, 6)
	stroke(card, self.Theme.Line)
	make("Frame", { Size = UDim2.fromOffset(4, 58), BackgroundColor3 = accent, BorderSizePixel = 0 }, card)
	make("TextLabel", { Position = UDim2.fromOffset(14, 7), Size = UDim2.new(1, -24, 0, 17), BackgroundTransparency = 1, Text = options.Title or self.Title, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = self.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left }, card)
	make("TextLabel", { Position = UDim2.fromOffset(14, 25), Size = UDim2.new(1, -24, 0, 25), BackgroundTransparency = 1, Text = options.Content or options.Message or "", TextWrapped = true, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = self.Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, card)
	TweenService:Create(card, TweenInfo.new(0.18), { BackgroundTransparency = 0 }):Play()
	task.delay(options.Duration or 3.5, function()
		if card.Parent then
			local tween = TweenService:Create(card, TweenInfo.new(0.18), { BackgroundTransparency = 1 })
			tween:Play(); tween.Completed:Wait()
			if card.Parent then card:Destroy() end
		end
	end)
	return card
end

-- Adds a compact performance watermark. It is optional and can be enabled at
-- creation with Watermark = true, or later with window:Watermark().
function Window:Watermark()
	if self.Destroyed then return end
	if self.WatermarkFrame then return self.WatermarkFrame end
	local frame = make("Frame", {
		Name = "Watermark", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(290, 31), BackgroundColor3 = self.Theme.Panel, BorderSizePixel = 0,
		ZIndex = 20,
	}, self.Gui)
	corner(frame, 6); stroke(frame, self.Theme.Line)
	make("Frame", { Position = UDim2.fromOffset(0, 5), Size = UDim2.fromOffset(3, 21), BackgroundColor3 = self.Theme.Accent, BorderSizePixel = 0, ZIndex = 21 }, frame)
	local label = make("TextLabel", {
		Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -18, 1, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = self.Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21,
	}, frame)
	self.WatermarkFrame = frame
	self.Notifications.Position = UDim2.new(1, -16, 0, 57)
	local frames, elapsed, fps = 0, 0, 0
	local connection = game:GetService("RunService").RenderStepped:Connect(function(delta)
		frames += 1; elapsed += delta
		if elapsed >= 1 then fps = math.floor(frames / elapsed + 0.5); frames, elapsed = 0, 0 end
		local ping = "-- ms"
		pcall(function() ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString() end)
		label.Text = string.format("%s  |  %s  |  %d FPS  |  %s", string.upper(self.Title), Players.LocalPlayer.Name, fps, ping)
	end)
	self.WatermarkConnection = connection
	table.insert(self.Connections, connection)
	return frame
end

function Window:RemoveWatermark()
	if self.WatermarkConnection then self.WatermarkConnection:Disconnect(); self.WatermarkConnection = nil end
	if self.WatermarkFrame then self.WatermarkFrame:Destroy(); self.WatermarkFrame = nil end
	if not self.Destroyed then self.Notifications.Position = UDim2.new(1, -16, 0, 16) end
end

function Window:CreateTab(options: any)
	if type(options) ~= "table" then options = { Name = options } end
	local name = options.Name or options.Title or "Tab"
	local tab = setmetatable({ Window = self, Name = name, Sections = {} }, Tab)
	tab.Page = make("ScrollingFrame", {
		Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
		ScrollBarThickness = 3, ScrollBarImageColor3 = self.Theme.Line, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	}, self.Content)
	local pagePadding = padding(tab.Page, 17)
	pagePadding.PaddingTop = UDim.new(0, 18)
	pagePadding.PaddingBottom = UDim.new(0, 18)
	make("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, tab.Page)
	tab.Button = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 31), BackgroundColor3 = self.Theme.Sidebar, BorderSizePixel = 0, Text = "   " .. name,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = self.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true,
	}, self.Sidebar)
	corner(tab.Button, 3)
	-- Keep the marker inside the tile, with a fixed inset. This prevents the
	-- purple stripe from looking detached or clipping through the side bar.
	tab.Indicator = make("Frame", { Position = UDim2.fromOffset(0, 5), Size = UDim2.fromOffset(3, 21), BackgroundColor3 = self.Theme.Accent, BorderSizePixel = 0, Visible = false }, tab.Button)
	tab.Button.Activated:Connect(function() self:SelectTab(tab) end)
	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then self:SelectTab(tab, true) end
	return tab
end

function Window:Tab(name: any) return self:CreateTab(name) end

function Window:SelectTab(tab: any, silent: boolean?)
	if self.Destroyed then return end
	for _, item in ipairs(self.Tabs) do
		local active = item == tab
		item.Page.Visible = active; item.Indicator.Visible = active
		tween(item.Button, 0.14, { BackgroundColor3 = active and Color3.fromRGB(57, 48, 75) or self.Theme.Sidebar })
		if active then
			local scale = item.Page:FindFirstChild("PageScale") :: UIScale?
			if not scale then scale = make("UIScale", { Name = "PageScale", Scale = 0.985 }, item.Page) end
			scale.Scale = 0.985
			tween(scale, 0.16, { Scale = 1 })
		end
	end
	self.ActiveTab = tab
	if not silent then self:Notify({ Content = tab.Name .. " tab opened.", Duration = 1.8 }) end
end

function Tab:CreateSection(options: any)
	if type(options) ~= "table" then options = { Name = options } end
	local section = setmetatable({ Tab = self, Window = self.Window, Controls = {}, Mode = options.Compact and "Compact" or "Expanded" }, Section)
	-- Cards deliberately have a compact fixed width like the reference UI.
	-- Override it per section with Width = 300 when a wider control is needed.
	section.Frame = make("Frame", { Name = options.Name or options.Title or "Section", Size = UDim2.fromOffset(options.Width or 262, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = self.Window.Theme.Panel, BorderSizePixel = 0 }, self.Page)
	corner(section.Frame, 2); stroke(section.Frame, self.Window.Theme.Line)
	local sectionScale = make("UIScale", { Scale = 0.97 }, section.Frame)
	tween(sectionScale, 0.16, { Scale = 1 })
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, section.Frame)

	local header = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, section.Frame)
	local headerPadding = make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8) }, header)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, header)
	make("TextLabel", { Size = UDim2.new(1, -16, 0, 29), BackgroundTransparency = 1, Text = string.upper(options.Name or options.Title or "SECTION"), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left }, header)
	if options.Subtitle then
		make("TextLabel", { Size = UDim2.new(1, -16, 0, 18), BackgroundTransparency = 1, Text = options.Subtitle, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = self.Window.Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left }, header)
	end
	if options.Description then
		make("TextLabel", { Size = UDim2.new(1, -16, 0, 30), BackgroundTransparency = 1, Text = options.Description, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = self.Window.Theme.Muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, header)
	end
	make("Frame", { Size = UDim2.new(1, -16, 0, 1), BackgroundColor3 = self.Window.Theme.Accent, BorderSizePixel = 0 }, header)

	section.Body = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, section.Frame)
	local bodyLayout = make("UIListLayout", { Padding = UDim.new(0, section.Mode == "Compact" and 2 or 3), SortOrder = Enum.SortOrder.LayoutOrder }, section.Body)
	make("UIPadding", { PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2) }, section.Body)

	function section:SetMode(mode: string)
		self.Mode = mode == "Compact" and "Compact" or "Expanded"
		bodyLayout.Padding = UDim.new(0, self.Mode == "Compact" and 2 or 3)
		local title = header:FindFirstChildOfClass("TextLabel")
		if title then
			title.TextSize = self.Mode == "Compact" and 10 or 11
		end
	end

	section:SetMode(section.Mode)
	table.insert(self.Sections, section)
	return section
end

function Tab:Section(name: any) return self:CreateSection(name) end

function Section:_register(flag: string?, control: Control): Control
	table.insert(self.Controls, control)
	if flag and flag ~= "" then
		if self.Window.Controls[flag] then warn("[XevorUI] Duplicate flag: " .. flag) end
		self.Window.Controls[flag] = control
	end
	return control
end

function Section:_row(height: number): Frame
	return make("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1 }, self.Body)
end

function Section:CreateLabel(options: any)
	if type(options) ~= "table" then options = { Content = options } end
	local label = make("TextLabel", { Size = UDim2.new(1, 0, 0, options.Height or 20), BackgroundTransparency = 1, Text = options.Content or options.Text or "Label", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = options.Color or self.Window.Theme.Muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center }, self.Body)
	return { Set = function(_, text: string) label.Text = text end, Get = function() return label.Text end, Destroy = function() label:Destroy() end }
end
function Section:Label(text: any) return self:CreateLabel(text) end

function Section:CreateParagraph(options: {[string]: any})
	options = options or {}
	local holder = self:_row(options.Height or 55)
	make("TextLabel", { Size = UDim2.new(1, 0, 0, 17), BackgroundTransparency = 1, Text = options.Title or options.Name or "Paragraph", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left }, holder)
	local body = make("TextLabel", { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 1, -18), BackgroundTransparency = 1, Text = options.Content or "", TextWrapped = true, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = self.Window.Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, holder)
	return { Set = function(_, text: string) body.Text = text end, Get = function() return body.Text end, Destroy = function() holder:Destroy() end }
end
function Section:Paragraph(title: string, content: string) return self:CreateParagraph({ Title = title, Content = content }) end

function Section:CreateDivider()
	return make("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = self.Window.Theme.Line, BorderSizePixel = 0 }, self.Body)
end
function Section:Divider() return self:CreateDivider() end

function Section:CreateButton(options: any)
	if type(options) ~= "table" then options = { Name = options } end
	local text = options.Name or options.Title or "Button"
	local button = make("TextButton", { Size = UDim2.new(1, 0, 0, 23), BackgroundColor3 = options.Color or self.Window.Theme.Field, BorderSizePixel = 0, Text = text, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false }, self.Body)
	corner(button, 1); stroke(button, self.Window.Theme.Line)
	local leftPadding = options.Icon and 28 or 8
	padding(button, leftPadding, 8)
	if options.Icon then
		make("ImageLabel", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, Image = options.Icon, ImageColor3 = options.IconColor or self.Window.Theme.Text, ScaleType = Enum.ScaleType.Fit }, button)
	end
	local normalColor = options.Color or self.Window.Theme.Field
	addHover(button, normalColor, normalColor:Lerp(self.Window.Theme.Accent, 0.16))
	button.Activated:Connect(function() safeCallback(options.Callback) end)
	return { Destroy = function() button:Destroy() end }
end
function Section:Button(text: string, callback: () -> ()) return self:CreateButton({ Name = text, Callback = callback }) end

function Section:CreateImage(options: {[string]: any})
	options = options or {}
	local image = make("ImageLabel", { Size = UDim2.new(1, 0, 0, options.Height or 100), BackgroundColor3 = self.Window.Theme.Field, BorderSizePixel = 0, Image = options.Image or options.Source or "", ScaleType = options.ScaleType or Enum.ScaleType.Fit, BackgroundTransparency = options.BackgroundTransparency or 0 }, self.Body)
	corner(image, options.CornerRadius or 6); stroke(image, self.Window.Theme.Line)
	return {
		Set = function(_, value) image.Image = tostring(value or "") end,
		Get = function() return image.Image end,
		Destroy = function() image:Destroy() end,
	}
end

function Section:CreateToggle(options: {[string]: any})
	options = options or {}
	local row = self:_row(22)
	make("TextLabel", { Size = UDim2.new(1, -45, 1, 0), BackgroundTransparency = 1, Text = options.Name or options.Title or "Toggle", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left }, row)
	local button = make("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(17, 17), BackgroundColor3 = self.Window.Theme.Field, BorderSizePixel = 0, Text = "", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = self.Window.Theme.Text, AutoButtonColor = false }, row)
	corner(button, 1); stroke(button, self.Window.Theme.Line)
	local knob = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(13, 13), BackgroundColor3 = self.Window.Theme.Muted, BorderSizePixel = 0 }, button)
	corner(knob, 1)
	local value = false
	local control: any = {}
	function control:Set(newValue: boolean, silent: boolean?)
		value = newValue == true
		button.Text = value and "✓" or ""
		knob.Visible = not value
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = value and self.Window.Theme.Accent or self.Window.Theme.Field }):Play()
		TweenService:Create(knob, TweenInfo.new(0.12), { BackgroundColor3 = self.Window.Theme.Muted }):Play()
		if not silent then safeCallback(options.Callback, value) end
	end
	function control:Get() return value end
	function control:Destroy() row:Destroy() end
	button.Activated:Connect(function() control:Set(not value) end)
	control:Set(options.CurrentValue == true or options.Default == true, true)
	return self:_register(options.Flag, control)
end
function Section:Toggle(text: string, default: boolean, callback: (boolean) -> ()) return self:CreateToggle({ Name = text, Default = default, Callback = callback }) end

-- A compact square alternative to Toggle. It uses exactly the same Flag,
-- Default/CurrentValue, Callback, Get and Set conventions as the toggle.
function Section:CreateCheckbox(options: {[string]: any})
	options = options or {}
	local row = self:_row(23)
	make("TextLabel", {
		Size = UDim2.new(1, -30, 1, 0), BackgroundTransparency = 1,
		Text = options.Name or options.Title or "Checkbox", Font = Enum.Font.Gotham,
		TextSize = 12, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local box = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(17, 17),
		BackgroundColor3 = self.Window.Theme.Field, BorderSizePixel = 0, Text = "", Font = Enum.Font.GothamBold,
		TextSize = 12, TextColor3 = self.Window.Theme.Text, AutoButtonColor = false,
	}, row)
	corner(box, 1); stroke(box, self.Window.Theme.Line)
	local value = false
	local control: any = {}
	function control:Set(newValue: boolean, silent: boolean?)
		value = newValue == true
		box.Text = value and "✓" or ""
		tween(box, 0.12, { BackgroundColor3 = value and self.Window.Theme.Accent or self.Window.Theme.Field })
		if not silent then safeCallback(options.Callback, value) end
	end
	function control:Get() return value end
	function control:Destroy() row:Destroy() end
	box.Activated:Connect(function() control:Set(not value) end)
	control:Set(options.CurrentValue == true or options.Default == true, true)
	return self:_register(options.Flag, control)
end
function Section:Checkbox(text: string, default: boolean, callback: (boolean) -> ())
	return self:CreateCheckbox({ Name = text, Default = default, Callback = callback })
end

function Section:CreateRadioGroup(options: {[string]: any})
	options = options or {}
	local values = options.Options or {}
	local current = options.CurrentValue or options.Default or values[1]
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, self.Body)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 17), BackgroundTransparency = 1,
		Text = options.Name or options.Title or "Radio Group", Font = Enum.Font.Gotham,
		TextSize = 12, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local list = make("Frame", {
		Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, row)
	make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local control: any = {}
	local buttons = {}

	local function refresh()
		for index, value in ipairs(values) do
			local button = buttons[index]
			if button then
				button.Text = (current == value and "●  " or "○  ") .. tostring(value)
			end
		end
	end

	local function setValue(value)
		if current == value then return end
		current = value
		refresh()
		safeCallback(options.Callback, current)
	end

	for _, value in ipairs(values) do
		local button = make("TextButton", {
			Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = self.Window.Theme.Panel,
			BorderSizePixel = 0, Text = "", Font = Enum.Font.Gotham, TextSize = 11,
			TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
		}, list)
		padding(button, 6)
		stroke(button, self.Window.Theme.Line)
		addHover(button, self.Window.Theme.Panel, self.Window.Theme.Panel:Lerp(self.Window.Theme.Accent, 0.08))
		button.Activated:Connect(function()
			setValue(value)
		end)
		table.insert(buttons, button)
	end

	function control:Get() return current end
	function control:Set(value, silent: boolean?)
		if not table.find(values, value) then return end
		current = value
		refresh()
		if not silent then safeCallback(options.Callback, current) end
	end
	function control:Destroy() row:Destroy() end

	refresh()
	return self:_register(options.Flag, control)
end
function Section:RadioGroup(text: string, options: {any}, default: any, callback: (any) -> ())
	return self:CreateRadioGroup({ Name = text, Options = options, Default = default, Callback = callback })
end

function Section:CreateSlider(options: {[string]: any})
	options = options or {}
	local range = options.Range or { options.Min or 0, options.Max or 100 }
	local minimum, maximum = tonumber(range[1]) or 0, tonumber(range[2]) or 100
	if maximum < minimum then minimum, maximum = maximum, minimum end
	local step = math.max(tonumber(options.Increment or options.Step) or 1, 0.0001)
	local row = self:_row(36)
	make("TextLabel", { Size = UDim2.new(1, -60, 0, 17), BackgroundTransparency = 1, Text = options.Name or options.Title or "Slider", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left }, row)
	local number = make("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(56, 17), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = self.Window.Theme.Muted, TextXAlignment = Enum.TextXAlignment.Right }, row)
	local track = make("TextButton", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = self.Window.Theme.Field, BorderSizePixel = 0, Text = "", AutoButtonColor = false }, row)
	corner(track, 0)
	local fill = make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = self.Window.Theme.Accent, BorderSizePixel = 0 }, track)
	corner(fill, 0)
	local value, dragging = minimum, false
	local control: any = {}
	local function quantize(raw: number): number
		local stepped = minimum + math.floor((raw - minimum) / step + 0.5) * step
		return math.clamp(stepped, minimum, maximum)
	end
	function control:Set(newValue: number, silent: boolean?)
		value = quantize(tonumber(newValue) or minimum)
		local percent = maximum == minimum and 1 or (value - minimum) / (maximum - minimum)
		fill.Size = UDim2.new(percent, 0, 1, 0)
		number.Text = tostring(value)
		if not silent then safeCallback(options.Callback, value) end
	end
	function control:Get() return value end
	function control:Destroy() row:Destroy() end
	local function setFromPosition(position: Vector2)
		local percent = math.clamp((position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		control:Set(minimum + (maximum - minimum) * percent)
	end
	track.InputBegan:Connect(function(input) if isPrimaryInput(input) then dragging = true; setFromPosition(input.Position) end end)
	local move = UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setFromPosition(input.Position) end end)
	local finish = UserInputService.InputEnded:Connect(function(input) if isPrimaryInput(input) then dragging = false end end)
	function control:Destroy() move:Disconnect(); finish:Disconnect(); row:Destroy() end
	control:Set(options.CurrentValue or options.Default or minimum, true)
	return self:_register(options.Flag, control)
end
function Section:Slider(text: string, minimum: number, maximum: number, default: number, callback: (number) -> ()) return self:CreateSlider({ Name = text, Range = { minimum, maximum }, Default = default, Callback = callback }) end

function Section:CreateInput(options: {[string]: any})
	options = options or {}
	local input = make("TextBox", { Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = self.Window.Theme.Field, BorderSizePixel = 0, PlaceholderText = options.PlaceholderText or options.Placeholder or options.Name or "Enter text...", PlaceholderColor3 = self.Window.Theme.Muted, Text = options.Default or "", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left }, self.Body)
	corner(input, 1); stroke(input, self.Window.Theme.Line); padding(input, 6)
	local inputStroke = input:FindFirstChildOfClass("UIStroke")
	input.Focused:Connect(function() if inputStroke then tween(inputStroke, 0.12, { Color = self.Window.Theme.Accent }) end end)
	input.FocusLost:Connect(function() if inputStroke then tween(inputStroke, 0.12, { Color = self.Window.Theme.Line }) end end)
	local control: any = {}
	function control:Set(value: any, silent: boolean?) input.Text = tostring(value or ""); if not silent then safeCallback(options.Callback, input.Text) end end
	function control:Get() return input.Text end
	function control:Destroy() input:Destroy() end
	input.FocusLost:Connect(function(enterPressed) if options.RemoveTextAfterFocusLost then input.Text = "" end; safeCallback(options.Callback, input.Text, enterPressed) end)
	return self:_register(options.Flag, control)
end
function Section:Textbox(placeholder: string, callback: (string) -> ()) return self:CreateInput({ Placeholder = placeholder, Callback = callback }) end

function Section:CreateDropdown(options: {[string]: any})
	options = options or {}
	local values = options.Options or {}
	local multiple = options.MultipleOptions == true or options.Multi == true
	local holder = make("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, ClipsDescendants = false, ZIndex = 2 }, self.Body)
	local head = make("TextButton", { Size = UDim2.new(1, 0, 0, 23), BackgroundColor3 = self.Window.Theme.Field, BorderSizePixel = 0, Text = "", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 }, holder)
	corner(head, 1); stroke(head, self.Window.Theme.Line); padding(head, 6)
	addHover(head, self.Window.Theme.Field, self.Window.Theme.Field:Lerp(self.Window.Theme.Accent, 0.12))
	make("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(12, 16), BackgroundTransparency = 1, Text = "⌄", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = self.Window.Theme.Muted, ZIndex = 3 }, head)
	local list = make("Frame", { Position = UDim2.fromOffset(0, 25), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = self.Window.Theme.Panel, BorderSizePixel = 0, Visible = false, ZIndex = 10 }, holder)
	corner(list, 1); stroke(list, self.Window.Theme.Line)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)
	local selected: {[any]: boolean} = {}
	if multiple then for _, item in ipairs(options.CurrentOption or options.Default or {}) do selected[item] = true end end
	local single = multiple and nil or (options.CurrentOption or options.Default or values[1])
	local open = false
	local control: any = {}
	local function result()
		if not multiple then return single end
		local output = {}; for _, item in ipairs(values) do if selected[item] then table.insert(output, item) end end; return output
	end
	local function refreshTitle()
		local current = result()
		local text = multiple and (#current == 0 and "Select..." or table.concat(current, ", ")) or tostring(current or "Select...")
		head.Text = (options.Name or options.Title or "Dropdown") .. "  ·  " .. text
	end
	local function close()
		open = false; list.Visible = false
		tween(holder, 0.14, { Size = UDim2.new(1, 0, 0, 24) })
	end
	local function rebuild()
		for _, child in ipairs(list:GetChildren()) do if child:IsA("GuiButton") then child:Destroy() end end
		for _, item in ipairs(values) do
			local label = tostring(item)
			if multiple and selected[item] then label = "✓  " .. label end
			local choice = make("TextButton", { Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = self.Window.Theme.Panel, BorderSizePixel = 0, Text = label, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = self.Window.Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11 }, list)
			padding(choice, 6)
			choice.Activated:Connect(function()
				if multiple then selected[item] = not selected[item] else single = item; close() end
				refreshTitle(); rebuild(); safeCallback(options.Callback, result())
			end)
		end
	end
	function control:Get() return result() end
	function control:Set(value: any, silent: boolean?)
		if multiple then selected = {}; for _, item in ipairs(value or {}) do selected[item] = true end else single = value end
		refreshTitle(); rebuild(); if not silent then safeCallback(options.Callback, result()) end
	end
	function control:Refresh(newValues: {any}, keepSelection: boolean?)
		values = newValues or {}
		if not keepSelection then if multiple then selected = {} else single = values[1] end end
		refreshTitle(); rebuild()
	end
	function control:Destroy() holder:Destroy() end
	head.Activated:Connect(function()
		open = not open; list.Visible = open
		tween(holder, 0.14, { Size = UDim2.new(1, 0, 0, open and (27 + #values * 22) or 24) })
	end)
	refreshTitle(); rebuild()
	return self:_register(options.Flag, control)
end
function Section:Dropdown(text: string, options: {any}, default: any, callback: (any) -> ()) return self:CreateDropdown({ Name = text, Options = options, Default = default, Callback = callback }) end
function Section:MultiDropdown(text: string, options: {any}, defaults: {any}, callback: ({any}) -> ()) return self:CreateDropdown({ Name = text, Options = options, Default = defaults, MultipleOptions = true, Callback = callback }) end

function Section:CreateKeybind(options: {[string]: any})
	options = options or {}
	local row = self:_row(22)
	make("TextLabel", { Size = UDim2.new(1, -80, 1, 0), BackgroundTransparency = 1, Text = options.Name or options.Title or "Keybind", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left }, row)
	local button = make("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(54, 17), BackgroundColor3 = self.Window.Theme.Field, BorderSizePixel = 0, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = self.Window.Theme.Muted }, row)
	corner(button, 1); stroke(button, self.Window.Theme.Line)
	addHover(button, self.Window.Theme.Field, self.Window.Theme.Field:Lerp(self.Window.Theme.Accent, 0.12))
	local value = options.CurrentKeybind or options.Default or Enum.KeyCode.Unknown
	local listening = false
	local control: any = {}
	local function repaint() button.Text = listening and "Press a key" or value.Name end
	function control:Get() return value end
	function control:Set(newValue: Enum.KeyCode, silent: boolean?) value = newValue; repaint(); if not silent then safeCallback(options.ChangedCallback, value) end end
	local connection = UserInputService.InputBegan:Connect(function(input, processed)
		if listening and input.UserInputType == Enum.UserInputType.Keyboard then listening = false; control:Set(input.KeyCode); return end
		if not processed and not listening and input.KeyCode == value then safeCallback(options.Callback) end
	end)
	function control:Destroy() connection:Disconnect(); row:Destroy() end
	button.Activated:Connect(function() listening = true; repaint() end)
	repaint()
	return self:_register(options.Flag, control)
end
function Section:Keybind(text: string, defaultKey: Enum.KeyCode, callback: () -> ()) return self:CreateKeybind({ Name = text, Default = defaultKey, Callback = callback }) end
function Section:Bind(text: string, defaultKey: Enum.KeyCode, callback: () -> ()) return self:Keybind(text, defaultKey, callback) end

function Section:CreateColorPicker(options: {[string]: any})
	options = options or {}
	local color = options.Color or options.CurrentColor or options.Default or self.Window.Theme.Accent
	local r, g, b = math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5)
	local row = self:_row(25)
	row.ClipsDescendants = true
	make("TextLabel", { Size = UDim2.new(1, -48, 0, 25), BackgroundTransparency = 1, Text = options.Name or options.Title or "Color", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left }, row)
	local preview = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 3), Size = UDim2.fromOffset(38, 19), BackgroundColor3 = color, BorderSizePixel = 0, Text = "" }, row)
	corner(preview, 1); stroke(preview, self.Window.Theme.Line)
	local previewScale = make("UIScale", { Scale = 1 }, preview)
	preview.MouseEnter:Connect(function() tween(previewScale, 0.12, { Scale = 1.07 }) end)
	preview.MouseLeave:Connect(function() tween(previewScale, 0.12, { Scale = 1 }) end)
	local channels = {}
	local connections = {}
	local open = false
	local control: any = {}
	local function repaint()
		color = Color3.fromRGB(r, g, b)
		preview.BackgroundColor3 = color
		for _, channel in ipairs(channels) do
			local value = channel.getter()
			channel.fill.Size = UDim2.new(value / 255, 0, 1, 0)
			channel.value.Text = tostring(value)
		end
	end
	local function addChannel(letter: string, y: number, channelColor: Color3, getter: () -> number, setter: (number) -> ())
		make("TextLabel", { Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(16, 17), BackgroundTransparency = 1, Text = letter, Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = self.Window.Theme.Muted }, row)
		local track = make("TextButton", { Position = UDim2.new(0, 19, 0, y + 6), Size = UDim2.new(1, -57, 0, 4), BackgroundColor3 = self.Window.Theme.Field, BorderSizePixel = 0, Text = "", AutoButtonColor = false }, row)
		corner(track, 0)
		local fill = make("Frame", { Size = UDim2.new(getter() / 255, 0, 1, 0), BackgroundColor3 = channelColor, BorderSizePixel = 0 }, track)
		corner(fill, 0)
		local valueLabel = make("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, y), Size = UDim2.fromOffset(32, 17), BackgroundTransparency = 1, Text = tostring(getter()), Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = self.Window.Theme.Muted, TextXAlignment = Enum.TextXAlignment.Right }, row)
		table.insert(channels, { getter = getter, fill = fill, value = valueLabel })
		local dragging = false
		local function setFromPosition(position: Vector2)
			local percent = math.clamp((position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			setter(math.floor(percent * 255 + 0.5)); repaint(); safeCallback(options.Callback, color)
		end
		table.insert(connections, track.InputBegan:Connect(function(input) if isPrimaryInput(input) then dragging = true; setFromPosition(input.Position) end end))
		table.insert(connections, UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setFromPosition(input.Position) end end))
		table.insert(connections, UserInputService.InputEnded:Connect(function(input) if isPrimaryInput(input) then dragging = false end end))
	end
	addChannel("R", 32, Color3.fromRGB(255, 96, 105), function() return r end, function(value) r = value end)
	addChannel("G", 57, Color3.fromRGB(78, 214, 155), function() return g end, function(value) g = value end)
	addChannel("B", 82, Color3.fromRGB(93, 158, 255), function() return b end, function(value) b = value end)
	function control:Get() return color end
	function control:Set(newValue: Color3, silent: boolean?)
		color = newValue; r = math.floor(color.R * 255 + 0.5); g = math.floor(color.G * 255 + 0.5); b = math.floor(color.B * 255 + 0.5)
		repaint(); if not silent then safeCallback(options.Callback, color) end
	end
	function control:Destroy() disconnectAll(connections); row:Destroy() end
	preview.Activated:Connect(function()
		open = not open
		tween(row, 0.15, { Size = UDim2.new(1, 0, 0, open and 106 or 25) })
	end)
	return self:_register(options.Flag, control)
end

function Section:CreateTextArea(options: {[string]: any})
	options = options or {}
	local frame = make("Frame", { Size = UDim2.new(1, 0, 0, options.Height or 96), BackgroundTransparency = 1 }, self.Body)
	local title = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
		Text = options.Name or options.Title or "Text Area", Font = Enum.Font.GothamBold,
		TextSize = 11, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, frame)
	local input = make("TextBox", {
		Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, options.Height and options.Height - 22 or 74),
		BackgroundColor3 = self.Window.Theme.Field, BorderSizePixel = 0, Text = options.Default or "",
		ClearTextOnFocus = false, MultiLine = true, TextWrapped = true, Font = Enum.Font.Gotham,
		TextSize = 11, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, PlaceholderText = options.Placeholder or "Enter text...",
		PlaceholderColor3 = self.Window.Theme.Muted,
	}, frame)
	corner(input, 6); stroke(input, self.Window.Theme.Line); padding(input, 8)
	local control: any = {}
	function control:Set(value: string, silent: boolean?)
		input.Text = tostring(value or "")
		if not silent then safeCallback(options.Callback, input.Text) end
	end
	function control:Get() return input.Text end
	function control:Destroy() frame:Destroy() end
	input.FocusLost:Connect(function(enterPressed)
		safeCallback(options.Callback, input.Text, enterPressed)
	end)
	return self:_register(options.Flag, control)
end
function Section:TextArea(text: string, default: string, callback: (string) -> ())
	return self:CreateTextArea({ Name = text, Default = default, Callback = callback })
end

function Section:CreateProgressBar(options: {[string]: any})
	options = options or {}
	local frame = make("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 }, self.Body)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
		Text = options.Name or options.Title or "Progress", Font = Enum.Font.GothamBold,
		TextSize = 11, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, frame)
	local valueLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(60, 16),
		BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = self.Window.Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, frame)
	local barBg = make("Frame", { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = self.Window.Theme.Field, BorderSizePixel = 0 }, frame)
	corner(barBg, 5)
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = options.Color or self.Window.Theme.Accent, BorderSizePixel = 0 }, barBg)
	corner(fill, 5)
	local percentLabel = make("TextLabel", { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 10), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = self.Window.Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left }, frame)
	local current = tonumber(options.Current or options.Default or 0) or 0
	local maximum = tonumber(options.Max or options.Maximum or 100) or 100
	local control: any = {}
	local function refresh()
		local pct = maximum > 0 and math.clamp(current / maximum, 0, 1) or 0
		fill.Size = UDim2.fromScale(pct, 1)
		valueLabel.Text = string.format("%d/%d", current, maximum)
		percentLabel.Text = options.ShowPercent and string.format("%d%%", math.floor(pct * 100)) or ""
	end
	function control:Set(value: number, max: number?, silent: boolean?)
		current = tonumber(value) or 0
		maximum = tonumber(max or maximum) or maximum
		refresh()
		if not silent then safeCallback(options.Callback, current, maximum) end
	end
	function control:Get() return current, maximum end
	function control:Destroy() frame:Destroy() end
	refresh()
	return self:_register(options.Flag, control)
end
function Section:ProgressBar(text: string, current: number, maximum: number, callback: (number, number) -> ())
	return self:CreateProgressBar({ Name = text, Current = current, Max = maximum, Callback = callback })
end

function Section:CreateThemePresets(options: {[string]: any})
	options = options or {}
	local presets = options.Presets or {
		{ Name = "Default", Theme = DEFAULT_THEME },
		{ Name = "Cyber", Theme = {
			Background = Color3.fromRGB(18, 12, 28), Topbar = Color3.fromRGB(42, 11, 84), Sidebar = Color3.fromRGB(32, 16, 47), Panel = Color3.fromRGB(26, 13, 36), Field = Color3.fromRGB(32, 16, 45), Text = Color3.fromRGB(230, 230, 255), Muted = Color3.fromRGB(160, 150, 215), Accent = Color3.fromRGB(95, 255, 217), Line = Color3.fromRGB(79, 49, 121),
		} },
		{ Name = "Sunset", Theme = {
			Background = Color3.fromRGB(35, 16, 28), Topbar = Color3.fromRGB(92, 28, 54), Sidebar = Color3.fromRGB(68, 24, 44), Panel = Color3.fromRGB(50, 21, 37), Field = Color3.fromRGB(58, 24, 44), Text = Color3.fromRGB(246, 223, 201), Muted = Color3.fromRGB(200, 170, 155), Accent = Color3.fromRGB(255, 137, 91), Line = Color3.fromRGB(99, 53, 64),
		} },
	}
	local container = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, self.Body)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
		Text = options.Name or options.Title or "Theme Presets", Font = Enum.Font.GothamBold,
		TextSize = 11, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, container)
	local list = make("Frame", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, container)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	local selected = options.Current or options.Default or presets[1].Name
	local control: any = {}
	local function refresh()
		for _, child in ipairs(list:GetChildren()) do child:Destroy() end
		for _, item in ipairs(presets) do
			local button = make("TextButton", {
				Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = item.Name == selected and self.Window.Theme.Accent or self.Window.Theme.Panel,
				BorderSizePixel = 0, Text = item.Name, Font = Enum.Font.GothamBold, TextSize = 11,
				TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
			}, list)
			padding(button, 8)
			corner(button, 4); stroke(button, self.Window.Theme.Line)
			button.Activated:Connect(function()
				selected = item.Name
				safeCallback(options.Callback, item.Theme, item.Name)
				refresh()
			end)
		end
	end
	function control:Set(value: string, silent: boolean?)
		selected = tostring(value or selected)
		refresh()
		if not silent then safeCallback(options.Callback, value) end
	end
	function control:Get() return selected end
	function control:Destroy() container:Destroy() end
	refresh()
	return self:_register(options.Flag, control)
end
function Section:ThemePresets(text: string, callback: (table, string) -> ())
	return self:CreateThemePresets({ Name = text, Callback = callback })
end

function Section:CreateSearchBar(options: {[string]: any})
	options = options or {}
	local row = self:_row(28)
	make("TextLabel", {
		Size = UDim2.new(1, -120, 1, 0), BackgroundTransparency = 1,
		Text = options.Name or options.Title or "Search", Font = Enum.Font.Gotham,
		TextSize = 12, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local input = make("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -0, 0.5, 0), Size = UDim2.fromOffset(120, 22),
		BackgroundColor3 = self.Window.Theme.Field, BorderSizePixel = 0, Text = options.Default or "",
		ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = self.Window.Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left, PlaceholderText = options.Placeholder or "Search...",
		PlaceholderColor3 = self.Window.Theme.Muted,
	}, row)
	corner(input, 4); stroke(input, self.Window.Theme.Line); padding(input, 6)
	local control: any = {}
	function control:Set(value: string, silent: boolean?)
		input.Text = tostring(value or "")
		if not silent then safeCallback(options.Callback, input.Text) end
	end
	function control:Get() return input.Text end
	function control:Destroy() row:Destroy() end
	input:GetPropertyChangedSignal("Text"):Connect(function()
		safeCallback(options.Callback, input.Text)
	end)
	return self:_register(options.Flag, control)
end
function Section:SearchBar(text: string, callback: (string) -> ())
	return self:CreateSearchBar({ Name = text, Callback = callback })
end

function Section:CreateScriptLibrary(options: {[string]: any})
	options = options or {}
	local container = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, self.Body)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
		Text = options.Name or options.Title or "Script Library", Font = Enum.Font.GothamBold,
		TextSize = 11, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, container)
	local searchRow = nil
	local filterText = ""
	local favoritesOnly = false
	local function createSearchRow()
		searchRow = make("Frame", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 }, container)
		local searchBox = make("TextBox", {
			Size = UDim2.new(1, -90, 0, 22), Position = UDim2.fromOffset(0, 0), BackgroundColor3 = self.Window.Theme.Field,
			BorderSizePixel = 0, Text = "", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 11,
			TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
			PlaceholderText = options.SearchPlaceholder or "Search scripts...",
			PlaceholderColor3 = self.Window.Theme.Muted,
		}, searchRow)
		corner(searchBox, 4); stroke(searchBox, self.Window.Theme.Line); padding(searchBox, 8)
		local favToggle = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -0, 0, 0), Size = UDim2.fromOffset(82, 22),
			BackgroundColor3 = self.Window.Theme.Field, BorderSizePixel = 0, Text = "★ Favorites", Font = Enum.Font.GothamBold,
			TextSize = 10, TextColor3 = self.Window.Theme.Text, AutoButtonColor = false,
		}, searchRow)
		corner(favToggle, 4); stroke(favToggle, self.Window.Theme.Line)
		local function refreshFavLabel()
			favToggle.Text = favoritesOnly and "★ Favorites" or "☆ Favorites"
		end
		favToggle.Activated:Connect(function()
			favoritesOnly = not favoritesOnly
			refreshFavLabel()
			rebuild()
		end)
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			filterText = string.lower(tostring(searchBox.Text or ""))
			rebuild()
		end)
	end
	local list = make("Frame", { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, container)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	local control: any = {}
	local function shouldShow(entry)
		if favoritesOnly and not entry.Favorite then return false end
		if filterText == "" then return true end
		local name = string.lower(tostring(entry.Name or ""))
		local desc = string.lower(tostring(entry.Description or ""))
		return string.find(name, filterText, 1, true) or string.find(desc, filterText, 1, true)
	end
	local function rebuild()
		for _, child in ipairs(list:GetChildren()) do child:Destroy() end
		for _, entry in ipairs(options.Scripts or {}) do
			entry.Favorite = entry.Favorite == true
			if not shouldShow(entry) then continue end
			local height = entry.Description and 44 or 30
			local row = make("Frame", {
				Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = self.Window.Theme.Field,
				BorderSizePixel = 0,
			}, list)
			corner(row, 4); stroke(row, self.Window.Theme.Line)
			local btn = make("TextButton", {
				Size = UDim2.new(1, -28, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
				Text = "  " .. tostring(entry.Name or "Script"), Font = Enum.Font.GothamBold,
				TextSize = 11, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
			}, row)
			padding(btn, 8)
			if entry.Description then
				local desc = make("TextLabel", {
					Position = UDim2.new(0, 8, 0, 18), Size = UDim2.new(1, -36, 0, 20), BackgroundTransparency = 1,
					Text = tostring(entry.Description), Font = Enum.Font.Gotham, TextSize = 10,
					TextColor3 = self.Window.Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
				}, row)
			end
			local favoriteButton = make("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = self.Window.Theme.Panel, BorderSizePixel = 0, Text = entry.Favorite and "★" or "☆",
				Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = self.Window.Theme.Text,
				AutoButtonColor = false,
			}, row)
			corner(favoriteButton, 4); stroke(favoriteButton, self.Window.Theme.Line)
			favoriteButton.Activated:Connect(function()
				entry.Favorite = not entry.Favorite
				favoriteButton.Text = entry.Favorite and "★" or "☆"
				safeCallback(options.FavoritesChanged, entry, entry.Favorite)
			end)
			btn.Activated:Connect(function()
				safeCallback(entry.Callback, entry)
			end)
		end
	end
	function control:Refresh(items: {any})
		options.Scripts = items or options.Scripts
		rebuild()
	end
	function control:Get() return options.Scripts end
	function control:SetFilter(query: string, silent: boolean?)
		filterText = string.lower(tostring(query or ""))
		rebuild()
		if not silent then safeCallback(options.Callback, filterText) end
	end
	function control:SetFavoritesOnly(value: boolean, silent: boolean?)
		favoritesOnly = value == true
		rebuild()
		if not silent then safeCallback(options.FavoritesChanged, nil, favoritesOnly) end
	end
	function control:Destroy() container:Destroy() end
	createSearchRow()
	rebuild()
	return self:_register(options.Flag, control)
end
function Section:ScriptLibrary(text: string, scripts: {any}, callback: (any) -> ())
	return self:CreateScriptLibrary({ Name = text, Scripts = scripts, Callback = callback, Searchable = true, FavoritesEnabled = true })
end

function Section:CreatePlayerList(options: {[string]: any})
	options = options or {}
	local container = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, self.Body)
	local title = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
		Text = options.Name or options.Title or "Player List", Font = Enum.Font.GothamBold,
		TextSize = 11, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, container)
	local list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, options.Height or 140), BackgroundColor3 = self.Window.Theme.Panel,
		BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = self.Window.Theme.Line,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), BackgroundTransparency = 0,
	}, container)
	corner(list, 6); stroke(list, self.Window.Theme.Line)
	make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	local connections = {}
	local function refresh()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("Frame") and child.Name == "PlayerEntry" then child:Destroy() end
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local row = make("Frame", { Name = "PlayerEntry", Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = self.Window.Theme.Field, BorderSizePixel = 0 }, list)
			corner(row, 4)
			local nameLabel = make("TextLabel", {
				Size = UDim2.new(0.6, 0, 1, 0), BackgroundTransparency = 1,
				Text = player.DisplayName .. " (" .. player.Name .. ")", Font = Enum.Font.Gotham,
				TextSize = 11, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
			}, row)
			local info = make("TextLabel", {
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), Size = UDim2.new(0.4, -6, 1, 0),
				BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = self.Window.Theme.Muted,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = "ID: " .. tostring(player.UserId),
			}, row)
			if options.Callback then
				row.InputBegan:Connect(function(input, gameProcessed)
					if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
						safeCallback(options.Callback, player)
					end
				end)
			end
		end
	end
	function refreshPlayers()
		refresh()
	end
	table.insert(connections, Players.PlayerAdded:Connect(refreshPlayers))
	table.insert(connections, Players.PlayerRemoving:Connect(refreshPlayers))
	local control: any = {}
	function control:Refresh() refreshPlayers() end
	function control:Get() return Players:GetPlayers() end
	function control:Destroy()
		disconnectAll(connections)
		container:Destroy()
	end
	refreshPlayers()
	return self:_register(options.Flag, control)
end
function Section:PlayerList(text: string, callback: (Player) -> ())
	return self:CreatePlayerList({ Name = text, Callback = callback })
end

function Section:CreateServerInfo(options: {[string]: any})
	options = options or {}
	local startTime = os.time()
	local container = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, self.Body)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
		Text = options.Name or options.Title or "Server Info", Font = Enum.Font.GothamBold,
		TextSize = 11, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, container)
	local infoFrame = make("Frame", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, container)
	make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, infoFrame)
	local function line(labelText: string, initial: string)
		local row = make("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1 }, infoFrame)
		local left = make("TextLabel", {
			Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1, Text = labelText,
			Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = self.Window.Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		local right = make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.5, 0, 1, 0),
			BackgroundTransparency = 1, Text = initial or "", Font = Enum.Font.Gotham,
			TextSize = 10, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Right,
		}, row)
		return right
	end
	local placeLabel = line("Place ID", tostring(game.PlaceId))
	local jobLabel = line("Job ID", tostring(game.JobId))
	local playersLabel = line("Players", string.format("%d/%d", #Players:GetPlayers(), Players.MaxPlayers or 0))
	local uptimeLabel = line("Uptime", "0s")
	local serverLabel = line("Server Type", options.ServerType or "Roblox")
	local connection = game:GetService("RunService").Heartbeat:Connect(function(delta)
		local uptime = os.time() - startTime
		local minutes = math.floor(uptime / 60)
		local seconds = uptime % 60
		uptimeLabel.Text = string.format("%dm %ds", minutes, seconds)
		playersLabel.Text = string.format("%d/%d", #Players:GetPlayers(), Players.MaxPlayers or 0)
	end)
	local control: any = {}
	function control:Get()
		return {
			PlaceId = game.PlaceId,
			JobId = game.JobId,
			Players = #Players:GetPlayers(),
			MaxPlayers = Players.MaxPlayers,
			Uptime = os.time() - startTime,
		}
	end
	function control:Destroy()
		connection:Disconnect()
		container:Destroy()
	end
	return self:_register(options.Flag, control)
end
function Section:ServerInfo(text: string)
	return self:CreateServerInfo({ Name = text })
end

function Section:ColorPalette(text: string, default: Color3, callback: (Color3) -> ()) return self:CreateColorPicker({ Name = text, Default = default, Callback = callback }) end
function Section:ColorPicker(text: string, default: Color3, callback: (Color3) -> ()) return self:ColorPalette(text, default, callback) end

-- Portable state: save the returned table wherever your experience stores player settings.
function Window:ExportConfig(): {[string]: any}
	local data = {}
	for flag, control in pairs(self.Controls) do data[flag] = serializeValue(control:Get()) end
	return data
end

function Window:ImportConfig(data: {[string]: any}, silent: boolean?)
	for flag, value in pairs(data or {}) do
		local control = self.Controls[flag]
		if control then control:Set(deserializeValue(value), silent == true) end
	end
end

function Window:SaveConfig(): string
	local data = self:ExportConfig()
	return HttpService:JSONEncode(data)
end

function Window:LoadConfig(json: string, silent: boolean?)
	if type(json) ~= "string" or json == "" then return end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(data) ~= "table" then return end
	self:ImportConfig(data, silent)
end

function Window:ResetConfig(defaults: {[string]: any}?)
	local data = defaults or {}
	for flag, control in pairs(self.Controls) do
		local value = data[flag]
		if value ~= nil then
			control:Set(deserializeValue(value), true)
		elseif control.Set then
			control:Set(control:Get(), true)
		end
	end
end

function Window:GetControl(flag: string): Control? return self.Controls[flag] end

function Window:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	disconnectAll(self.Connections)
	if self.Gui then self.Gui:Destroy() end
	table.clear(self.Controls)
end

function XevorUI.Init(options: any)
	return XevorUI.CreateWindow(options)
end

return setmetatable(XevorUI, {
	__call = function(_, options: any)
		return XevorUI.CreateWindow(options)
	end,
})
