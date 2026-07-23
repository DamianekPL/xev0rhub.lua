-- XevorUI: client-side settings UI for experiences you own.
-- Place this ModuleScript in ReplicatedStorage and require it from a LocalScript.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local XevorUI = {}
XevorUI.__index = XevorUI

local activeUI
local C = {
	bg = Color3.fromRGB(22, 20, 31), bar = Color3.fromRGB(29, 26, 40),
	side = Color3.fromRGB(34, 30, 48), panel = Color3.fromRGB(42, 37, 57),
	field = Color3.fromRGB(28, 25, 39), text = Color3.fromRGB(245, 240, 255),
	muted = Color3.fromRGB(180, 166, 203), accent = Color3.fromRGB(160, 91, 255),
	line = Color3.fromRGB(88, 72, 116),
}

local function new(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end

local function rounded(object, radius)
	new("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, object)
	return object
end

local function stroke(object, color)
	return new("UIStroke", { Color = color or C.line, Thickness = 1 }, object)
end

function XevorUI:_connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(self._connections, connection)
	return connection
end

function XevorUI:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	table.clear(self._connections)
	if self.Gui then self.Gui:Destroy() end
	if activeUI == self then activeUI = nil end
end

function XevorUI.new(title)
	if activeUI then activeUI:Destroy() end
	local self = setmetatable({
		Tabs = {}, Title = title or "Xevor", ActiveTab = nil, _connections = {},
	}, XevorUI)
	activeUI = self

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.Gui = new("ScreenGui", {
		Name = "XevorLibrary", ResetOnSpawn = false, DisplayOrder = 10,
		IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	self.Notifications = new("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 57),
		Size = UDim2.fromOffset(265, 350), BackgroundTransparency = 1,
	}, self.Gui)
	new("UIListLayout", {
		Padding = UDim.new(0, 7), HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.Notifications)

	local win = rounded(new("Frame", {
		AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromOffset(720, 470), BackgroundColor3 = C.bg, BorderSizePixel = 0,
	}, self.Gui), 7)
	stroke(win, Color3.fromRGB(9, 7, 13))
	self.Window = win
	local top = rounded(new("Frame", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.bar, BorderSizePixel = 0,
	}, win), 7)
	new("Frame", { Position = UDim2.new(0, 0, 1, -7), Size = UDim2.new(1, 0, 0, 7), BackgroundColor3 = C.bar, BorderSizePixel = 0 }, top)
	new("TextLabel", {
		Position = UDim2.fromOffset(11, 0), Size = UDim2.fromOffset(500, 30), BackgroundTransparency = 1,
		Text = self.Title:upper() .. "  |  MAIN MENU", Font = Enum.Font.GothamBold, TextSize = 12,
		TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
	}, top)
	local close = new("TextButton", {
		AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -8, .5), Size = UDim2.fromOffset(18, 20),
		BackgroundTransparency = 1, Text = "×", Font = Enum.Font.Gotham, TextSize = 22, TextColor3 = C.muted,
	}, top)
	self:_connect(close.Activated, function() self:Destroy() end)
	self.Sidebar = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 30), Size = UDim2.new(0, 178, 1, -30), BackgroundColor3 = C.side,
		BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
	}, win)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, self.Sidebar)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, self.Sidebar)
	self.Content = new("Frame", { Position = UDim2.fromOffset(178, 30), Size = UDim2.new(1, -178, 1, -30), BackgroundTransparency = 1 }, win)
	self:_connect(self.Gui.AncestryChanged, function(_, parent)
		if not parent then self:Destroy() end
	end)
	return self
end

function XevorUI:Notify(title, message)
	if self._destroyed then return end
	local card = rounded(new("Frame", { Size = UDim2.fromOffset(265, 52), BackgroundColor3 = C.panel, BorderSizePixel = 0 }, self.Notifications), 6)
	stroke(card)
	new("Frame", { Size = UDim2.fromOffset(3, 52), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, card)
	new("TextLabel", { Position = UDim2.fromOffset(12, 7), Size = UDim2.fromOffset(240, 16), BackgroundTransparency = 1, Text = tostring(title), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, card)
	new("TextLabel", { Position = UDim2.fromOffset(12, 25), Size = UDim2.fromOffset(240, 17), BackgroundTransparency = 1, Text = tostring(message), Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left }, card)
	task.delay(3.5, function() if card.Parent then card:Destroy() end end)
end

function XevorUI:Watermark()
	if self.WatermarkFrame or self._destroyed then return end
	local frame = rounded(new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.fromOffset(265, 31), BackgroundColor3 = C.panel, BorderSizePixel = 0 }, self.Gui), 6)
	stroke(frame)
	new("Frame", { Position = UDim2.fromOffset(0, 5), Size = UDim2.fromOffset(3, 21), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, frame)
	local label = new("TextLabel", { Position = UDim2.fromOffset(11, 0), Size = UDim2.fromOffset(244, 31), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, frame)
	self.WatermarkFrame = frame
	local frames, elapsed, fps = 0, 0, 0
	self:_connect(RunService.RenderStepped, function(delta)
		frames, elapsed = frames + 1, elapsed + delta
		if elapsed >= 1 then fps = math.floor(frames / elapsed + .5); frames, elapsed = 0, 0 end
		local ping = "-- ms"
		pcall(function() ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString() end)
		label.Text = string.format("%s  |  %s  |  %d FPS  |  %s", self.Title:upper(), Players.LocalPlayer.Name, fps, ping)
	end)
end

function XevorUI:Tab(name)
	local tab = setmetatable({ Library = self, Name = tostring(name), Order = #self.Tabs + 1 }, XevorUI)
	tab.Page = new("Frame", { Name = tab.Name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, self.Content)
	tab.Button = new("TextButton", { Size = UDim2.new(1, 0, 0, 31), LayoutOrder = tab.Order, BackgroundColor3 = C.side, BorderSizePixel = 0, Text = "     " .. tab.Name, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, self.Sidebar)
	tab.Bar = new("Frame", { Position = UDim2.fromOffset(0, 3), Size = UDim2.fromOffset(4, 25), BackgroundColor3 = C.accent, BorderSizePixel = 0, Visible = false }, tab.Button)
	self:_connect(tab.Button.Activated, function() self:SelectTab(tab) end)
	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then self:SelectTab(tab, true) end
	return tab
end

function XevorUI:SelectTab(tab, silent)
	if self._destroyed then return end
	for _, item in ipairs(self.Tabs) do
		local isActive = item == tab
		item.Page.Visible, item.Bar.Visible = isActive, isActive
		item.Button.BackgroundColor3 = isActive and Color3.fromRGB(57, 48, 75) or C.side
	end
	self.ActiveTab = tab
	if not silent then self:Notify(self.Title, tab.Name .. " tab opened.") end
end

function XevorUI:Section(title, position)
	local parent = self.Page or self.Content
	local frame = rounded(new("Frame", { Position = position or UDim2.fromOffset(18, 50), Size = UDim2.fromOffset(248, 225), BackgroundColor3 = C.panel, BorderSizePixel = 0 }, parent), 5)
	new("TextLabel", { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(228, 17), BackgroundTransparency = 1, Text = tostring(title):upper(), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, frame)
	new("Frame", { Position = UDim2.fromOffset(8, 31), Size = UDim2.fromOffset(232, 2), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, frame)
	local content = new("ScrollingFrame", { Position = UDim2.fromOffset(8, 39), Size = UDim2.new(1, -16, 1, -47), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent }, frame)
	new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	return setmetatable({ Frame = frame, Content = content, Library = self.Library or self }, XevorUI)
end

function XevorUI:_row(height)
	return new("Frame", { Size = UDim2.new(1, -5, 0, height), BackgroundTransparency = 1 }, self.Content)
end

function XevorUI:Button(text, callback)
	local button = rounded(new("TextButton", { Size = UDim2.new(1, -5, 0, 27), BackgroundColor3 = C.field, BorderSizePixel = 0, Text = tostring(text), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.text }, self.Content), 4)
	stroke(button)
	self.Library:_connect(button.Activated, function() self.Library:Notify(self.Library.Title, tostring(text) .. " selected."); if callback then callback() end end)
	return button
end

function XevorUI:Toggle(text, default, callback)
	local row = self:_row(23)
	local on = default == true
	new("TextLabel", { Size = UDim2.new(1, -33, 1, 0), BackgroundTransparency = 1, Text = tostring(text), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, row)
	local box = rounded(new("TextButton", { AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, 0, .5, 0), Size = UDim2.fromOffset(25, 15), BackgroundColor3 = on and C.accent or C.field, BorderSizePixel = 0, Text = "" }, row), 4)
	stroke(box)
	self.Library:_connect(box.Activated, function() on = not on; box.BackgroundColor3 = on and C.accent or C.field; self.Library:Notify(self.Library.Title, tostring(text) .. (on and " enabled." or " disabled.")); if callback then callback(on) end end)
	return { Get = function() return on end, Set = function(_, value) on = value == true; box.BackgroundColor3 = on and C.accent or C.field; if callback then callback(on) end end }
end

function XevorUI:Textbox(placeholder, callback)
	local input = new("TextBox", { Size = UDim2.new(1, -5, 0, 25), BackgroundColor3 = C.field, BorderSizePixel = 0, PlaceholderText = tostring(placeholder), PlaceholderColor3 = C.muted, Text = "", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, self.Content)
	stroke(input); new("UIPadding", { PaddingLeft = UDim.new(0, 7) }, input)
	if callback then self.Library:_connect(input.FocusLost, function() callback(input.Text) end) end
	return input
end

function XevorUI:Label(text)
	return new("TextLabel", { Size = UDim2.new(1, -5, 0, 20), BackgroundTransparency = 1, Text = tostring(text), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left }, self.Content)
end

function XevorUI:Divider()
	local row = self:_row(8)
	return new("Frame", { Position = UDim2.new(0, 0, .5, 0), Size = UDim2.new(1, -5, 0, 1), BackgroundColor3 = C.line, BorderSizePixel = 0 }, row)
end

function XevorUI:Paragraph(title, content)
	local holder = self:_row(50)
	new("TextLabel", { Size = UDim2.new(1, -5, 0, 17), BackgroundTransparency = 1, Text = tostring(title), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, holder)
	new("TextLabel", { Position = UDim2.fromOffset(0, 17), Size = UDim2.new(1, -5, 0, 33), BackgroundTransparency = 1, Text = tostring(content), TextWrapped = true, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, holder)
	return holder
end

function XevorUI:Slider(text, minimum, maximum, default, callback)
	minimum, maximum = tonumber(minimum) or 0, tonumber(maximum) or 100
	if maximum < minimum then minimum, maximum = maximum, minimum end
	local range = maximum - minimum
	local value = math.clamp(tonumber(default) or minimum, minimum, maximum)
	local row = self:_row(39)
	new("TextLabel", { Size = UDim2.new(1, -52, 0, 17), BackgroundTransparency = 1, Text = tostring(text), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, row)
	local label = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(46, 17), BackgroundTransparency = 1, Text = tostring(value), Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Right }, row)
	local track = rounded(new("TextButton", { Position = UDim2.fromOffset(0, 25), Size = UDim2.new(1, -5, 0, 5), BackgroundColor3 = C.field, BorderSizePixel = 0, Text = "", AutoButtonColor = false }, row), 3)
	local fill = rounded(new("Frame", { BackgroundColor3 = C.accent, BorderSizePixel = 0 }, track), 3)
	local function render(emit)
		local pct = range == 0 and 0 or (value - minimum) / range
		fill.Size, label.Text = UDim2.new(pct, 0, 1, 0), tostring(value)
		if emit and callback then callback(value) end
	end
	local dragging = false
	local function set(position) if range == 0 then return end; local pct = math.clamp((position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1); value = math.floor(minimum + range * pct + .5); render(true) end
	self.Library:_connect(track.InputBegan, function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; set(input.Position) end end)
	self.Library:_connect(UserInputService.InputChanged, function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then set(input.Position) end end)
	self.Library:_connect(UserInputService.InputEnded, function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
	render(false)
	return { Get = function() return value end, Set = function(_, newValue) value = math.clamp(tonumber(newValue) or minimum, minimum, maximum); render(true) end }
end

function XevorUI:Keybind(text, defaultKey, callback)
	local boundKey = typeof(defaultKey) == "EnumItem" and defaultKey or Enum.KeyCode.Unknown
	local row = self:_row(23)
	new("TextLabel", { Size = UDim2.new(1, -60, 1, 0), BackgroundTransparency = 1, Text = tostring(text), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, row)
	local button = rounded(new("TextButton", { AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, 0, .5, 0), Size = UDim2.fromOffset(52, 18), BackgroundColor3 = C.field, BorderSizePixel = 0, Text = boundKey.Name, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.muted }, row), 3)
	stroke(button)
	local listening = false
	self.Library:_connect(button.Activated, function() listening = true; button.Text = "..." end)
	self.Library:_connect(UserInputService.InputBegan, function(input, processed)
		if listening and input.UserInputType == Enum.UserInputType.Keyboard then boundKey = input.KeyCode; button.Text = boundKey.Name; listening = false; self.Library:Notify(self.Library.Title, tostring(text) .. " set to " .. boundKey.Name .. "."); return end
		if not processed and not listening and input.KeyCode == boundKey and callback then callback() end
	end)
	return { Get = function() return boundKey end, Set = function(_, key) if typeof(key) == "EnumItem" then boundKey = key; button.Text = key.Name end end }
end

function XevorUI:Dropdown(text, options, default, callback)
	options = options or {}
	local value = default or options[1] or "Select..."
	local holder = new("Frame", { Size = UDim2.new(1, -5, 0, 25), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2 }, self.Content)
	local head = rounded(new("TextButton", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = C.field, BorderSizePixel = 0, Text = tostring(text) .. "  ·  " .. tostring(value), Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, holder), 3)
	new("UIPadding", { PaddingLeft = UDim.new(0, 7) }, head); stroke(head)
	local opened = false
	self.Library:_connect(head.Activated, function() opened = not opened; holder.Size = UDim2.new(1, -5, 0, opened and (25 + #options * 24) or 25) end)
	for index, option in ipairs(options) do
		local choice = new("TextButton", { Position = UDim2.fromOffset(0, 25 + (index - 1) * 24), Size = UDim2.new(1, 0, 0, 23), BackgroundColor3 = C.panel, BorderSizePixel = 0, Text = "  " .. tostring(option), Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left }, holder)
		self.Library:_connect(choice.Activated, function() value = option; head.Text = tostring(text) .. "  ·  " .. tostring(value); opened = false; holder.Size = UDim2.new(1, -5, 0, 25); if callback then callback(value) end end)
	end
	return { Get = function() return value end, Set = function(_, newValue) value = newValue; head.Text = tostring(text) .. "  ·  " .. tostring(value); if callback then callback(value) end end }
end

function XevorUI:MultiDropdown(text, options, defaults, callback)
	options = options or {}; local selected = {}; for _, item in ipairs(defaults or {}) do selected[item] = true end
	local holder = new("Frame", { Size = UDim2.new(1, -5, 0, 25), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2 }, self.Content)
	local function selectedItems() local out = {}; for _, item in ipairs(options) do if selected[item] then table.insert(out, item) end end; return out end
	local head = rounded(new("TextButton", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = C.field, BorderSizePixel = 0, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, holder), 3)
	new("UIPadding", { PaddingLeft = UDim.new(0, 7) }, head); stroke(head)
	local choiceRenders = {}
	local function refresh()
		local names = selectedItems()
		head.Text = tostring(text) .. "  ·  " .. (#names > 0 and table.concat(names, ", ") or "Select...")
		for _, renderChoice in ipairs(choiceRenders) do renderChoice() end
	end
	refresh(); local opened = false
	self.Library:_connect(head.Activated, function() opened = not opened; holder.Size = UDim2.new(1, -5, 0, opened and (25 + #options * 24) or 25) end)
	for index, option in ipairs(options) do
		local choice = new("TextButton", { Position = UDim2.fromOffset(0, 25 + (index - 1) * 24), Size = UDim2.new(1, 0, 0, 23), BackgroundColor3 = C.panel, BorderSizePixel = 0, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left }, holder)
		local function renderChoice() choice.Text = (selected[option] and "  ✓  " or "     ") .. tostring(option) end
		table.insert(choiceRenders, renderChoice)
		renderChoice(); self.Library:_connect(choice.Activated, function() selected[option] = not selected[option]; refresh(); if callback then callback(selectedItems()) end end)
	end
	return { Get = selectedItems, Set = function(_, values) table.clear(selected); for _, item in ipairs(values or {}) do selected[item] = true end; refresh(); if callback then callback(selectedItems()) end end }
end

function XevorUI:ColorPalette(text, default, callback)
	local palette = { Color3.fromRGB(160, 91, 255), Color3.fromRGB(93, 158, 255), Color3.fromRGB(78, 214, 155), Color3.fromRGB(255, 115, 148), Color3.fromRGB(255, 191, 87) }
	local color, index = default or C.accent, 1
	local row = self:_row(23); new("TextLabel", { Size = UDim2.new(1, -44, 1, 0), BackgroundTransparency = 1, Text = tostring(text), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, row)
	local preview = rounded(new("TextButton", { AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, 0, .5, 0), Size = UDim2.fromOffset(36, 18), BackgroundColor3 = color, BorderSizePixel = 0, Text = "" }, row), 4); stroke(preview)
	self.Library:_connect(preview.Activated, function() index = index % #palette + 1; color = palette[index]; preview.BackgroundColor3 = color; if callback then callback(color) end end)
	return { Get = function() return color end, Set = function(_, newColor) color = newColor; preview.BackgroundColor3 = color; if callback then callback(color) end end }
end

function XevorUI:ColorPicker(text, default, callback)
	local color = default or C.accent
	local channels = {
		math.floor(color.R * 255 + .5), math.floor(color.G * 255 + .5), math.floor(color.B * 255 + .5),
	}
	local colors = { Color3.fromRGB(255, 95, 105), Color3.fromRGB(78, 214, 155), Color3.fromRGB(93, 158, 255) }
	local names = { "R", "G", "B" }
	local holder = new("Frame", { Size = UDim2.new(1, -5, 0, 23), BackgroundTransparency = 1, ClipsDescendants = true }, self.Content)
	new("TextLabel", { Size = UDim2.new(1, -45, 0, 23), BackgroundTransparency = 1, Text = tostring(text), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, holder)
	local preview = rounded(new("TextButton", { AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, 0, .5, 0), Size = UDim2.fromOffset(36, 18), BackgroundColor3 = color, BorderSizePixel = 0, Text = "", AutoButtonColor = false }, holder), 4)
	stroke(preview)
	local opened, rows = false, {}
	local function apply(emit)
		color = Color3.fromRGB(channels[1], channels[2], channels[3])
		preview.BackgroundColor3 = color
		for index, row in ipairs(rows) do
			row.Fill.Size = UDim2.new(channels[index] / 255, 0, 1, 0)
			row.Value.Text = tostring(channels[index])
		end
		if emit and callback then callback(color) end
	end
	for index = 1, 3 do
		local y = 26 + (index - 1) * 27
		new("TextLabel", { Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(15, 16), BackgroundTransparency = 1, Text = names[index], Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = C.muted }, holder)
		local track = rounded(new("TextButton", { Position = UDim2.fromOffset(19, y + 6), Size = UDim2.new(1, -58, 0, 4), BackgroundColor3 = C.field, BorderSizePixel = 0, Text = "", AutoButtonColor = false }, holder), 3)
		local fill = rounded(new("Frame", { Size = UDim2.new(channels[index] / 255, 0, 1, 0), BackgroundColor3 = colors[index], BorderSizePixel = 0 }, track), 3)
		local value = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, y), Size = UDim2.fromOffset(34, 16), BackgroundTransparency = 1, Text = tostring(channels[index]), Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Right }, holder)
		rows[index] = { Fill = fill, Value = value }
		local dragging = false
		local function set(position)
			local pct = math.clamp((position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			channels[index] = math.floor(pct * 255 + .5)
			apply(true)
		end
		self.Library:_connect(track.InputBegan, function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; set(input.Position) end end)
		self.Library:_connect(UserInputService.InputChanged, function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then set(input.Position) end end)
		self.Library:_connect(UserInputService.InputEnded, function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
	end
	self.Library:_connect(preview.Activated, function() opened = not opened; holder.Size = UDim2.new(1, -5, 0, opened and 106 or 23) end)
	return {
		Get = function() return color end,
		Set = function(_, newColor)
			if typeof(newColor) ~= "Color3" then return end
			channels = { math.floor(newColor.R * 255 + .5), math.floor(newColor.G * 255 + .5), math.floor(newColor.B * 255 + .5) }
			apply(true)
		end,
	}
end

function XevorUI:Bind(text, defaultKey, callback) return self:Keybind(text, defaultKey, callback) end
function XevorUI:CreateTab(options) return self:Tab(type(options) == "table" and (options.Name or options.Title) or options or "Tab") end
function XevorUI:CreateSection(options) return self:Section(type(options) == "table" and (options.Name or options.Title or "Section") or options or "Section", type(options) == "table" and options.Position or nil) end
function XevorUI:CreateButton(options) options = options or {}; return self:Button(options.Name or options.Title or "Button", options.Callback) end
function XevorUI:CreateToggle(options) options = options or {}; return self:Toggle(options.Name or options.Title or "Toggle", options.CurrentValue == true or options.Default == true, options.Callback) end
function XevorUI:CreateSlider(options) options = options or {}; local r = options.Range or { 0, 100 }; return self:Slider(options.Name or options.Title or "Slider", r[1], r[2], options.CurrentValue or options.Default or r[1], options.Callback) end
function XevorUI:CreateDropdown(options) options = options or {}; if options.MultipleOptions or options.Multi then return self:MultiDropdown(options.Name or options.Title or "Dropdown", options.Options, options.CurrentOption or options.Default, options.Callback) end; local d = options.CurrentOption or options.Default; if type(d) == "table" then d = d[1] end; return self:Dropdown(options.Name or options.Title or "Dropdown", options.Options, d, options.Callback) end
function XevorUI:CreateInput(options) options = options or {}; return self:Textbox(options.PlaceholderText or options.Placeholder or options.Name or "Enter text...", options.Callback) end
function XevorUI:CreateKeybind(options) options = options or {}; return self:Keybind(options.Name or options.Title or "Keybind", options.CurrentKeybind or options.Default, options.Callback) end
function XevorUI:CreateColorPicker(options) options = options or {}; return self:ColorPicker(options.Name or options.Title or "Color", options.Color or options.CurrentColor, options.Callback) end
function XevorUI:CreateLabel(options) return self:Label(type(options) == "table" and (options.Content or options.Name or "Label") or options) end
function XevorUI:CreateParagraph(options) options = options or {}; return self:Paragraph(options.Title or options.Name or "Paragraph", options.Content or "") end
function XevorUI.CreateWindow(first, second) local options = second or first; return XevorUI.new(type(options) == "table" and (options.Name or options.Title) or options or "Xevor") end

return XevorUI
