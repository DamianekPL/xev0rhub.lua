--!strict
-- XevorUI v2
-- Place this ModuleScript in ReplicatedStorage and require it from a LocalScript.
-- The callbacks below are intended for settings and UI in experiences you own.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

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
	button.MouseEnter:Connect(function() tween(button, 0.12, { BackgroundColor3 = hovered }) end)
	button.MouseLeave:Connect(function() tween(button, 0.12, { BackgroundColor3 = normal }) end)
end

local function safeCallback(callback: ((...any) -> ())?, ...: any)
	if not callback then return end
	local ok, err = pcall(callback, ...)
	if not ok then warn("[XevorUI] Callback error:", err) end
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

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("XevorUI")
	if old then old:Destroy() end

	self.Gui = make("ScreenGui", {
		Name = "XevorUI", ResetOnSpawn = false, DisplayOrder = options.DisplayOrder or 10,
		IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)

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

function Window:SetVisible(visible: boolean)
	if not self.Destroyed then self.Gui.Enabled = visible end
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
	local section = setmetatable({ Tab = self, Window = self.Window, Controls = {} }, Section)
	-- Cards deliberately have a compact fixed width like the reference UI.
	-- Override it per section with Width = 300 when a wider control is needed.
	section.Frame = make("Frame", { Name = options.Name or options.Title or "Section", Size = UDim2.fromOffset(options.Width or 262, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = self.Window.Theme.Panel, BorderSizePixel = 0 }, self.Page)
	corner(section.Frame, 2); stroke(section.Frame, self.Window.Theme.Line)
	local sectionScale = make("UIScale", { Scale = 0.97 }, section.Frame)
	tween(sectionScale, 0.16, { Scale = 1 })
	make("TextLabel", { Size = UDim2.new(1, -16, 0, 29), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1, Text = string.upper(options.Name or options.Title or "SECTION"), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = self.Window.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left }, section.Frame)
	make("Frame", { Position = UDim2.fromOffset(8, 28), Size = UDim2.new(1, -16, 0, 1), BackgroundColor3 = self.Window.Theme.Accent, BorderSizePixel = 0 }, section.Frame)
	section.Body = make("Frame", { Position = UDim2.fromOffset(8, 36), Size = UDim2.new(1, -16, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, section.Frame)
	make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, section.Body)
	make("UIPadding", { PaddingBottom = UDim.new(0, 8) }, section.Body)
	make("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 999999 }, section.Frame)
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
	local button = make("TextButton", { Size = UDim2.new(1, 0, 0, 23), BackgroundColor3 = options.Color or self.Window.Theme.Field, BorderSizePixel = 0, Text = options.Name or options.Title or "Button", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = self.Window.Theme.Text }, self.Body)
	corner(button, 1); stroke(button, self.Window.Theme.Line)
	local normalColor = options.Color or self.Window.Theme.Field
	addHover(button, normalColor, normalColor:Lerp(self.Window.Theme.Accent, 0.16))
	button.Activated:Connect(function() safeCallback(options.Callback) end)
	return { Destroy = function() button:Destroy() end }
end
function Section:Button(text: string, callback: () -> ()) return self:CreateButton({ Name = text, Callback = callback }) end

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
function Section:ColorPalette(text: string, default: Color3, callback: (Color3) -> ()) return self:CreateColorPicker({ Name = text, Default = default, Callback = callback }) end
function Section:ColorPicker(text: string, default: Color3, callback: (Color3) -> ()) return self:ColorPalette(text, default, callback) end

-- Portable state: save the returned table wherever your experience stores player settings.
function Window:ExportConfig(): {[string]: any}
	local data = {}
	for flag, control in pairs(self.Controls) do data[flag] = control:Get() end
	return data
end

function Window:ImportConfig(data: {[string]: any}, silent: boolean?)
	for flag, value in pairs(data or {}) do
		local control = self.Controls[flag]
		if control then control:Set(value, silent == true) end
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

return XevorUI
