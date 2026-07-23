-- ModuleScript library. Put in ReplicatedStorage, then require it from a LocalScript.
-- UI only: use callbacks for legitimate settings in an experience you own.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local XevorUI = {}
XevorUI.__index = XevorUI

local C = {bg=Color3.fromRGB(22,20,31), bar=Color3.fromRGB(29,26,40), side=Color3.fromRGB(34,30,48), panel=Color3.fromRGB(42,37,57), field=Color3.fromRGB(28,25,39), text=Color3.fromRGB(245,240,255), muted=Color3.fromRGB(180,166,203), accent=Color3.fromRGB(160,91,255), line=Color3.fromRGB(88,72,116)}

local function new(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end

local function rounded(object, radius)
	new("UICorner", {CornerRadius=UDim.new(0, radius or 6)}, object)
	return object
end

function XevorUI.new(title)
	local self = setmetatable({Tabs={}, Title=title or "XEVOR", ActiveTab=nil}, XevorUI)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("XevorLibrary") if old then old:Destroy() end
	self.Gui = new("ScreenGui", {Name="XevorLibrary", ResetOnSpawn=false, DisplayOrder=10}, playerGui)
	self.Notifications = new("Frame", {AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-16,0,57), Size=UDim2.fromOffset(265,350), BackgroundTransparency=1}, self.Gui)
	new("UIListLayout", {Padding=UDim.new(0,7), HorizontalAlignment=Enum.HorizontalAlignment.Right, SortOrder=Enum.SortOrder.LayoutOrder}, self.Notifications)

	local win = rounded(new("Frame", {AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(.5,.5), Size=UDim2.fromOffset(720,470), BackgroundColor3=C.bg, BorderSizePixel=0}, self.Gui), 7)
	new("UIStroke", {Color=Color3.fromRGB(9,7,13), Thickness=1}, win)
	self.Window = win
	local top = rounded(new("Frame", {Size=UDim2.new(1,0,0,30), BackgroundColor3=C.bar, BorderSizePixel=0}, win), 7)
	new("Frame", {Position=UDim2.new(0,0,1,-7), Size=UDim2.new(1,0,0,7), BackgroundColor3=C.bar, BorderSizePixel=0}, top)
	new("TextLabel", {Position=UDim2.fromOffset(11,0), Size=UDim2.fromOffset(500,30), BackgroundTransparency=1, Text=self.Title:upper().."  |  MAIN MENU", Font=Enum.Font.GothamBold, TextSize=12, TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Left}, top)
	local close = new("TextButton", {AnchorPoint=Vector2.new(1,.5), Position=UDim2.new(1,-8,.5), Size=UDim2.fromOffset(18,20), BackgroundTransparency=1, Text="×", Font=Enum.Font.Gotham, TextSize=22, TextColor3=C.muted}, top)
	close.Activated:Connect(function() win.Visible=false end)
	self.Sidebar = new("Frame", {Position=UDim2.fromOffset(0,30), Size=UDim2.new(0,178,1,-30), BackgroundColor3=C.side, BorderSizePixel=0}, win)
	self.Content = new("Frame", {Position=UDim2.fromOffset(178,30), Size=UDim2.new(1,-178,1,-30), BackgroundTransparency=1}, win)
	return self
end

function XevorUI:Notify(title, message)
	local card = rounded(new("Frame", {Size=UDim2.fromOffset(265,52), BackgroundColor3=C.panel, BorderSizePixel=0}, self.Notifications), 6)
	new("UIStroke", {Color=C.line}, card)
	new("Frame", {Size=UDim2.fromOffset(3,52), BackgroundColor3=C.accent, BorderSizePixel=0}, card)
	new("TextLabel", {Position=UDim2.fromOffset(12,7), Size=UDim2.fromOffset(240,16), BackgroundTransparency=1, Text=title, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Left}, card)
	new("TextLabel", {Position=UDim2.fromOffset(12,25), Size=UDim2.fromOffset(240,17), BackgroundTransparency=1, Text=message, Font=Enum.Font.Gotham, TextSize=10, TextColor3=C.muted, TextXAlignment=Enum.TextXAlignment.Left}, card)
	task.delay(3.5, function() if card.Parent then card:Destroy() end end)
end

function XevorUI:Watermark()
	if self.WatermarkFrame then return end
	local frame = rounded(new("Frame", {AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-16,0,16), Size=UDim2.fromOffset(265,31), BackgroundColor3=C.panel, BorderSizePixel=0}, self.Gui), 6)
	new("UIStroke", {Color=C.line}, frame)
	new("Frame", {Position=UDim2.fromOffset(0,5), Size=UDim2.fromOffset(3,21), BackgroundColor3=C.accent, BorderSizePixel=0}, frame)
	local label = new("TextLabel", {Position=UDim2.fromOffset(11,0), Size=UDim2.fromOffset(244,31), BackgroundTransparency=1, Font=Enum.Font.GothamMedium, TextSize=11, TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Left}, frame)
	self.WatermarkFrame = frame
	local frames, elapsed, fps = 0, 0, 0
	RunService.RenderStepped:Connect(function(delta)
		frames += 1 elapsed += delta
		if elapsed >= 1 then fps=math.floor(frames/elapsed+.5) frames,elapsed=0,0 end
		local ping="-- ms" pcall(function() ping=game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString() end)
		label.Text=string.format("%s  |  %s  |  %d FPS  |  %s", self.Title:upper(), Players.LocalPlayer.Name, fps, ping)
	end)
end

function XevorUI:Tab(name)
	local tab = {Library=self, Name=name}
	tab.Page = new("Frame", {Name=name, Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Visible=false}, self.Content)
	tab.Button = new("TextButton", {Position=UDim2.fromOffset(5,11+(#self.Tabs*37)), Size=UDim2.fromOffset(168,31), BackgroundColor3=C.side, BorderSizePixel=0, Text="     "..name, Font=Enum.Font.GothamMedium, TextSize=13, TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Left}, self.Sidebar)
	tab.Bar = new("Frame", {Position=UDim2.fromOffset(0,3), Size=UDim2.fromOffset(4,25), BackgroundColor3=C.accent, BorderSizePixel=0, Visible=false}, tab.Button)
	tab.Button.Activated:Connect(function() self:SelectTab(tab) end)
	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then self:SelectTab(tab) end
	return setmetatable(tab, {__index=XevorUI})
end

function XevorUI:SelectTab(tab)
	for _, item in ipairs(self.Tabs) do item.Page.Visible=item==tab item.Bar.Visible=item==tab item.Button.BackgroundColor3=item==tab and Color3.fromRGB(57,48,75) or C.side end
	self.ActiveTab=tab self:Notify(self.Title, tab.Name.." tab opened.")
end

function XevorUI:Section(title, position)
	local parent = self.Page or self.Content
	local section = rounded(new("Frame", {Position=position or UDim2.fromOffset(18,50), Size=UDim2.fromOffset(248,225), BackgroundColor3=C.panel, BorderSizePixel=0}, parent), 5)
	new("TextLabel", {Position=UDim2.fromOffset(10,8), Size=UDim2.fromOffset(228,17), BackgroundTransparency=1, Text=title:upper(), Font=Enum.Font.GothamBold, TextSize=11, TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Left}, section)
	new("Frame", {Position=UDim2.fromOffset(8,31), Size=UDim2.fromOffset(232,2), BackgroundColor3=C.accent, BorderSizePixel=0}, section)
	return setmetatable({Frame=section, Offset=43, Library=self}, {__index=XevorUI})
end

function XevorUI:Button(text, callback)
	local b = rounded(new("TextButton", {Position=UDim2.fromOffset(9,self.Offset), Size=UDim2.fromOffset(230,27), BackgroundColor3=C.field, BorderSizePixel=0, Text=text, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=C.text}, self.Frame), 4)
	new("UIStroke", {Color=C.line}, b) self.Offset += 35
	b.Activated:Connect(function() self.Library:Notify(self.Library.Title, text.." selected.") if callback then callback() end end)
	return b
end

function XevorUI:Toggle(text, default, callback)
	local row = new("TextButton", {Position=UDim2.fromOffset(9,self.Offset), Size=UDim2.fromOffset(230,23), BackgroundTransparency=1, Text=text, Font=Enum.Font.Gotham, TextSize=12, TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Left}, self.Frame)
	local on=default==true
	local box=rounded(new("Frame", {AnchorPoint=Vector2.new(1,.5), Position=UDim2.new(1,0,.5,0), Size=UDim2.fromOffset(25,15), BackgroundColor3=on and C.accent or C.field, BorderSizePixel=0}, row), 4)
	new("UIStroke", {Color=C.line}, box) self.Offset += 29
	row.Activated:Connect(function() on=not on box.BackgroundColor3=on and C.accent or C.field self.Library:Notify(self.Library.Title, text..(on and " enabled." or " disabled.")) if callback then callback(on) end end)
	return row
end

function XevorUI:Textbox(placeholder, callback)
	local input = new("TextBox", {Position=UDim2.fromOffset(9,self.Offset), Size=UDim2.fromOffset(230,24), BackgroundColor3=C.field, BorderSizePixel=0, PlaceholderText=placeholder, PlaceholderColor3=C.muted, Text="", ClearTextOnFocus=false, Font=Enum.Font.Gotham, TextSize=12, TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Left}, self.Frame)
	new("UIStroke", {Color=C.line}, input) new("UIPadding", {PaddingLeft=UDim.new(0,7)}, input) self.Offset += 32
	if callback then input.FocusLost:Connect(function() callback(input.Text) end) end
	return input
end

function XevorUI:Label(text)
	local label = new("TextLabel", {Position=UDim2.fromOffset(9,self.Offset), Size=UDim2.fromOffset(230,20), BackgroundTransparency=1, Text=text, Font=Enum.Font.Gotham, TextSize=12, TextColor3=C.muted, TextXAlignment=Enum.TextXAlignment.Left}, self.Frame)
	self.Offset += 24
	return label
end

function XevorUI:Divider()
	local line = new("Frame", {Position=UDim2.fromOffset(9,self.Offset), Size=UDim2.fromOffset(230,1), BackgroundColor3=C.line, BorderSizePixel=0}, self.Frame)
	self.Offset += 12
	return line
end

function XevorUI:Paragraph(title, content)
	local holder = new("Frame", {Position=UDim2.fromOffset(9,self.Offset), Size=UDim2.fromOffset(230,50), BackgroundTransparency=1}, self.Frame)
	new("TextLabel", {Size=UDim2.fromOffset(230,17), BackgroundTransparency=1, Text=title, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Left}, holder)
	new("TextLabel", {Position=UDim2.fromOffset(0,17), Size=UDim2.fromOffset(230,33), BackgroundTransparency=1, Text=content, TextWrapped=true, Font=Enum.Font.Gotham, TextSize=10, TextColor3=C.muted, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top}, holder)
	self.Offset += 55
	return holder
end

function XevorUI:Slider(text, minimum, maximum, default, callback)
	minimum, maximum = minimum or 0, maximum or 100
	local value = math.clamp(default or minimum, minimum, maximum)
	local row = new("Frame", {Position=UDim2.fromOffset(9,self.Offset), Size=UDim2.fromOffset(230,39), BackgroundTransparency=1}, self.Frame)
	new("TextLabel", {Size=UDim2.fromOffset(178,17), BackgroundTransparency=1, Text=text, Font=Enum.Font.Gotham, TextSize=12, TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Left}, row)
	local valueLabel = new("TextLabel", {AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), Size=UDim2.fromOffset(46,17), BackgroundTransparency=1, Text=tostring(value), Font=Enum.Font.Gotham, TextSize=11, TextColor3=C.muted, TextXAlignment=Enum.TextXAlignment.Right}, row)
	local track = rounded(new("TextButton", {Position=UDim2.fromOffset(0,25), Size=UDim2.fromOffset(230,4), BackgroundColor3=C.field, BorderSizePixel=0, Text=""}, row), 3)
	local fill = rounded(new("Frame", {Size=UDim2.new((value-minimum)/(maximum-minimum),0,1,0), BackgroundColor3=C.accent, BorderSizePixel=0}, track), 3)
	local dragging = false
	local function setValue(inputPosition)
		local pct = math.clamp((inputPosition.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
		value = math.floor((minimum+(maximum-minimum)*pct)+.5)
		fill.Size = UDim2.new(pct,0,1,0) valueLabel.Text=tostring(value)
		if callback then callback(value) end
	end
	track.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true setValue(input.Position) end end)
	track.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
	game:GetService("UserInputService").InputChanged:Connect(function(input) if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then setValue(input.Position) end end)
	self.Offset += 45
	return {Get=function() return value end, Set=function(_,newValue) value=math.clamp(newValue,minimum,maximum) local pct=(value-minimum)/(maximum-minimum) fill.Size=UDim2.new(pct,0,1,0) valueLabel.Text=tostring(value) if callback then callback(value) end end}
end

function XevorUI:Keybind(text, defaultKey, callback)
	local boundKey = defaultKey or Enum.KeyCode.Unknown
	local row = new("Frame", {Position=UDim2.fromOffset(9,self.Offset), Size=UDim2.fromOffset(230,23), BackgroundTransparency=1}, self.Frame)
	new("TextLabel", {Size=UDim2.fromOffset(170,23), BackgroundTransparency=1, Text=text, Font=Enum.Font.Gotham, TextSize=12, TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Left}, row)
	local button = rounded(new("TextButton", {AnchorPoint=Vector2.new(1,.5), Position=UDim2.new(1,0,.5,0), Size=UDim2.fromOffset(52,18), BackgroundColor3=C.field, BorderSizePixel=0, Text=boundKey.Name, Font=Enum.Font.Gotham, TextSize=10, TextColor3=C.muted}, row), 3)
	new("UIStroke", {Color=C.line}, button)
	local listening = false
	button.Activated:Connect(function() listening=true button.Text="..." end)
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if listening and input.UserInputType==Enum.UserInputType.Keyboard then boundKey=input.KeyCode button.Text=boundKey.Name listening=false self.Library:Notify(self.Library.Title,text.." set to "..boundKey.Name..".") return end
		if not processed and not listening and input.KeyCode==boundKey and callback then callback() end
	end)
	self.Offset += 29
	return {Get=function() return boundKey end, Set=function(_,key) boundKey=key button.Text=key.Name end}
end

function XevorUI:Dropdown(text, options, default, callback)
	options = options or {}
	local value = default or options[1] or "Select..."
	local holder = new("Frame", {Position=UDim2.fromOffset(9,self.Offset), Size=UDim2.fromOffset(230,25), BackgroundTransparency=1, ClipsDescendants=true}, self.Frame)
	local head = rounded(new("TextButton", {Size=UDim2.fromOffset(230,24), BackgroundColor3=C.field, BorderSizePixel=0, Text=text.."  ·  "..value, Font=Enum.Font.Gotham, TextSize=11, TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Left}, holder), 3)
	new("UIPadding", {PaddingLeft=UDim.new(0,7)}, head) new("UIStroke", {Color=C.line}, head)
	local opened=false
	head.Activated:Connect(function()
		opened=not opened holder.Size=UDim2.fromOffset(230,opened and (25+#options*24) or 25)
	end)
	for index, option in ipairs(options) do
		local optionButton = new("TextButton", {Position=UDim2.fromOffset(0,25+(index-1)*24), Size=UDim2.fromOffset(230,23), BackgroundColor3=C.panel, BorderSizePixel=0, Text="  "..tostring(option), Font=Enum.Font.Gotham, TextSize=11, TextColor3=C.muted, TextXAlignment=Enum.TextXAlignment.Left}, holder)
		optionButton.Activated:Connect(function() value=option head.Text=text.."  ·  "..value opened=false holder.Size=UDim2.fromOffset(230,25) if callback then callback(value) end end)
	end
	self.Offset += 31
	return {Get=function() return value end, Set=function(_,newValue) value=newValue head.Text=text.."  ·  "..value if callback then callback(value) end end}
end

function XevorUI:ColorPalette(text, default, callback)
	local color = default or C.accent
	local row = new("Frame", {Position=UDim2.fromOffset(9,self.Offset), Size=UDim2.fromOffset(230,23), BackgroundTransparency=1}, self.Frame)
	new("TextLabel", {Size=UDim2.fromOffset(170,23), BackgroundTransparency=1, Text=text, Font=Enum.Font.Gotham, TextSize=12, TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Left}, row)
	local preview = rounded(new("TextButton", {AnchorPoint=Vector2.new(1,.5), Position=UDim2.new(1,0,.5,0), Size=UDim2.fromOffset(36,18), BackgroundColor3=color, BorderSizePixel=0, Text=""}, row), 4)
	new("UIStroke", {Color=C.line}, preview)
	local palette={Color3.fromRGB(160,91,255),Color3.fromRGB(93,158,255),Color3.fromRGB(78,214,155),Color3.fromRGB(255,115,148),Color3.fromRGB(255,191,87)}
	local index=1
	preview.Activated:Connect(function() index=index%#palette+1 color=palette[index] preview.BackgroundColor3=color self.Library:Notify(self.Library.Title,text.." color updated.") if callback then callback(color) end end)
	self.Offset += 29
	return {Get=function() return color end, Set=function(_,newColor) color=newColor preview.BackgroundColor3=color if callback then callback(color) end end}
end

-- ColorPicker provides a compact RGB picker. Click a swatch to select it;
-- pass a custom palette as the fourth argument if you want your own colors.
function XevorUI:ColorPicker(text, default, callback, palette)
	local color = default or C.accent
	palette = palette or {
		Color3.fromRGB(160,91,255), Color3.fromRGB(93,158,255), Color3.fromRGB(78,214,155),
		Color3.fromRGB(255,115,148), Color3.fromRGB(255,191,87), Color3.fromRGB(245,240,255),
	}
	local holder = new("Frame", {Position=UDim2.fromOffset(9,self.Offset), Size=UDim2.fromOffset(230,23), BackgroundTransparency=1, ClipsDescendants=true}, self.Frame)
	new("TextLabel", {Size=UDim2.fromOffset(170,23), BackgroundTransparency=1, Text=text, Font=Enum.Font.Gotham, TextSize=12, TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Left}, holder)
	local preview = rounded(new("TextButton", {AnchorPoint=Vector2.new(1,.5), Position=UDim2.new(1,0,.5,0), Size=UDim2.fromOffset(36,18), BackgroundColor3=color, BorderSizePixel=0, Text="", AutoButtonColor=false}, holder), 4)
	new("UIStroke", {Color=C.line}, preview)
	local opened = false
	preview.Activated:Connect(function()
		opened = not opened
		holder.Size = UDim2.fromOffset(230, opened and 53 or 23)
	end)
	for index, swatchColor in ipairs(palette) do
		local swatch = rounded(new("TextButton", {Position=UDim2.fromOffset((index-1)*36,29), Size=UDim2.fromOffset(30,18), BackgroundColor3=swatchColor, BorderSizePixel=0, Text="", AutoButtonColor=false}, holder), 4)
		swatch.Activated:Connect(function()
			color = swatchColor
			preview.BackgroundColor3 = color
			opened = false
			holder.Size = UDim2.fromOffset(230,23)
			if callback then callback(color) end
		end)
	end
	self.Offset += 29
	return {Get=function() return color end, Set=function(_,newColor) color=newColor preview.BackgroundColor3=color if callback then callback(color) end end}
end

function XevorUI:Bind(text, defaultKey, callback)
	return self:Keybind(text, defaultKey, callback)
end

function XevorUI:MultiDropdown(text, options, defaults, callback)
	local selected = {}
	for _, value in ipairs(defaults or {}) do selected[value] = true end
	local dropdown = self:Dropdown(text, options, nil, function(value)
		selected[value] = not selected[value]
		if callback then
			local output = {}
			for _, item in ipairs(options or {}) do if selected[item] then table.insert(output,item) end end
			callback(output)
		end
	end)
	return {Get=function()
		local output = {}
		for _, item in ipairs(options or {}) do if selected[item] then table.insert(output,item) end end
		return output
	end, Dropdown=dropdown}
end

-- Rayfield-style convenience API. These are original compatibility helpers
-- for XevorUI's purple interface; they do not use Rayfield code or assets.
function XevorUI:CreateTab(options)
	local name = type(options) == "table" and (options.Name or options.Title) or options
	return self:Tab(name or "Tab")
end

function XevorUI:CreateSection(options)
	if type(options) == "table" then
		return self:Section(options.Name or options.Title or "Section", options.Position)
	end
	return self:Section(options or "Section")
end

function XevorUI:CreateButton(options)
	options = options or {}
	return self:Button(options.Name or options.Title or "Button", options.Callback)
end

function XevorUI:CreateToggle(options)
	options = options or {}
	return self:Toggle(options.Name or options.Title or "Toggle", options.CurrentValue == true or options.Default == true, options.Callback)
end

function XevorUI:CreateSlider(options)
	options = options or {}
	local range = options.Range or {0, 100}
	return self:Slider(options.Name or options.Title or "Slider", range[1] or 0, range[2] or 100, options.CurrentValue or options.Default or range[1] or 0, options.Callback)
end

function XevorUI:CreateDropdown(options)
	options = options or {}
	if options.MultipleOptions or options.Multi then
		return self:MultiDropdown(options.Name or options.Title or "Dropdown", options.Options or {}, options.CurrentOption or options.Default or {}, options.Callback)
	end
	local default = options.CurrentOption or options.Default
	if type(default) == "table" then default = default[1] end
	return self:Dropdown(options.Name or options.Title or "Dropdown", options.Options or {}, default, options.Callback)
end

function XevorUI:CreateInput(options)
	options = options or {}
	return self:Textbox(options.PlaceholderText or options.Placeholder or options.Name or "Enter text...", options.Callback)
end

function XevorUI:CreateKeybind(options)
	options = options or {}
	return self:Keybind(options.Name or options.Title or "Keybind", options.CurrentKeybind or options.Default or Enum.KeyCode.Unknown, options.Callback)
end

function XevorUI:CreateColorPicker(options)
	options = options or {}
	return self:ColorPicker(options.Name or options.Title or "Color", options.Color or options.CurrentColor or C.accent, options.Callback, options.Palette)
end

function XevorUI:CreateLabel(options)
	return self:Label(type(options) == "table" and (options.Content or options.Name or "Label") or options)
end

function XevorUI:CreateParagraph(options)
	options = options or {}
	return self:Paragraph(options.Title or options.Name or "Paragraph", options.Content or "")
end

function XevorUI.CreateWindow(first, second)
	local options = second or first -- supports both XevorUI.CreateWindow() and XevorUI:CreateWindow()
	local title = type(options) == "table" and (options.Name or options.Title) or options
	return XevorUI.new(title or "Xevor")
end

return XevorUI
