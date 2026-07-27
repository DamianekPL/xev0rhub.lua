-- init
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

-- services
local input = game:GetService("UserInputService")
local run = game:GetService("RunService")
local tween = game:GetService("TweenService")
local stats = game:GetService("Stats")
local tweeninfo = TweenInfo.new

-- additional
local utility = {}

-- themes
local objects = {}
local themes = {
	Background    = Color3.fromRGB(24, 24, 24),
	Glow          = Color3.fromRGB(0, 0, 0),
	Accent        = Color3.fromRGB(10, 10, 10),
	LightContrast = Color3.fromRGB(20, 20, 20),
	DarkContrast  = Color3.fromRGB(14, 14, 14),
	TextColor     = Color3.fromRGB(255, 255, 255)
}

do
	function utility:Create(instance, properties, children)
		local object = Instance.new(instance)

		for i, v in pairs(properties or {}) do
			object[i] = v

			if typeof(v) == "Color3" then
				local theme = utility:Find(themes, v)

				if theme then
					objects[theme] = objects[theme] or {}
					objects[theme][i] = objects[theme][i] or setmetatable({}, {__mode = "k"})
					table.insert(objects[theme][i], object)
				end
			end
		end

		for i, module in pairs(children or {}) do
			module.Parent = object
		end

		return object
	end

	function utility:Tween(instance, properties, duration, ...)
		tween:Create(instance, tweeninfo(duration, ...), properties):Play()
	end

	function utility:Wait()
		run.RenderStepped:Wait()
		return true
	end

	function utility:Find(table, value)
		for i, v in pairs(table) do
			if v == value then
				return i
			end
		end
	end

	function utility:Sort(pattern, values)
		local new = {}
		pattern = pattern:lower()

		if pattern == "" then
			return values
		end

		for i, value in pairs(values) do
			if tostring(value):lower():find(pattern) then
				table.insert(new, value)
			end
		end

		return new
	end

	function utility:Pop(object, shrink)
		local clone = object:Clone()

		clone.AnchorPoint = Vector2.new(0.5, 0.5)
		clone.Size = clone.Size - UDim2.new(0, shrink, 0, shrink)
		clone.Position = UDim2.new(0.5, 0, 0.5, 0)

		clone.Parent = object
		clone:ClearAllChildren()

		object.ImageTransparency = 1
		utility:Tween(clone, {Size = object.Size}, 0.2)

		spawn(function()
			wait(0.2)
			object.ImageTransparency = 0
			clone:Destroy()
		end)

		return clone
	end

	function utility:InitializeKeybind()
		self.keybinds = {}
		self.ended = {}

		input.InputBegan:Connect(function(key)
			if self.keybinds[key.KeyCode] then
				for i, bind in pairs(self.keybinds[key.KeyCode]) do
					bind()
				end
			end
		end)

		input.InputEnded:Connect(function(key)
			if key.UserInputType == Enum.UserInputType.MouseButton1
				or key.UserInputType == Enum.UserInputType.Touch then
				for i, callback in pairs(self.ended) do
					callback()
				end
			end
		end)
	end

	function utility:BindToKey(key, callback)
		self.keybinds[key] = self.keybinds[key] or {}
		table.insert(self.keybinds[key], callback)

		return {
			UnBind = function()
				for i, bind in pairs(self.keybinds[key]) do
					if bind == callback then
						table.remove(self.keybinds[key], i)
					end
				end
			end
		}
	end

	function utility:KeyPressed()
		local key = input.InputBegan:Wait()

		while key.UserInputType ~= Enum.UserInputType.Keyboard do
			key = input.InputBegan:Wait()
		end

		wait()
		return key
	end

	function utility:DraggingEnabled(frame, parent)
		parent = parent or frame

		local dragging = false
		local dragInput, startPosition, parentPosition

		frame.InputBegan:Connect(function(userInput)
			if userInput.UserInputType == Enum.UserInputType.MouseButton1
				or userInput.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				startPosition = userInput.Position
				parentPosition = parent.Position

				userInput.Changed:Connect(function()
					if userInput.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)

		frame.InputChanged:Connect(function(userInput)
			if userInput.UserInputType == Enum.UserInputType.MouseMovement
				or userInput.UserInputType == Enum.UserInputType.Touch then
				dragInput = userInput
			end
		end)

		input.InputChanged:Connect(function(userInput)
			if userInput == dragInput and dragging then
				local delta = userInput.Position - startPosition
				parent.Position = UDim2.new(
					parentPosition.X.Scale, parentPosition.X.Offset + delta.X,
					parentPosition.Y.Scale, parentPosition.Y.Offset + delta.Y
				)
			end
		end)
	end

	function utility:DraggingEnded(callback)
		table.insert(self.ended, callback)
	end
end

-- ============================================================
-- SAFE FILE HELPERS
-- Sanitises path so dots/slashes can't escape working dir.
-- ============================================================

local function sanitizeName(name)
	-- Strip anything that isn't alphanumeric, dash, or underscore.
	return tostring(name or "default"):gsub("[^%w%-_]", "_")
end

local function safeWrite(path, data)
	local ok = pcall(writefile, path, data)
	return ok
end

local function safeRead(path)
	local ok, data = pcall(readfile, path)
	if ok then return data end
	return nil
end

-- ============================================================
-- CONFIG SYSTEM
-- Proper recursive JSON-like serialiser / deserialiser.
-- Fixes: trailing-entry regex drop, nested object parse,
--        path sanitisation.
-- ============================================================

local configRegistry = {}  -- { id = { getter, setter } }

local function encodeValue(v)
	local t = type(v)
	if t == "boolean" then
		return v and "true" or "false"
	elseif t == "number" then
		return tostring(v)
	elseif t == "string" then
		return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
	elseif t == "table" then
		if v.r ~= nil and v.g ~= nil and v.b ~= nil then
			return string.format('{"__type":"Color3","r":%s,"g":%s,"b":%s}', v.r, v.g, v.b)
		end
		local items = {}
		for _, item in ipairs(v) do
			table.insert(items, encodeValue(item))
		end
		return "[" .. table.concat(items, ",") .. "]"
	end
	return "null"
end

local function serializeConfig()
	local parts = {}
	for id, entry in pairs(configRegistry) do
		local key = '"' .. id:gsub('"', '\\"') .. '"'
		table.insert(parts, key .. ":" .. encodeValue(entry.getter()))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

-- State-machine JSON value parser — handles bool, number, string,
-- Color3 object, and string arrays reliably without regex fragility.
local function parseJsonValue(s)
	s = s:match("^%s*(.-)%s*$")
	if s == "true"  then return true  end
	if s == "false" then return false end
	if s == "null"  then return nil   end

	-- Quoted string
	if s:sub(1, 1) == '"' then
		return s:sub(2, -2):gsub('\\"', '"'):gsub('\\\\', '\\')
	end

	-- Object (Color3)
	if s:sub(1, 1) == "{" then
		local r = tonumber(s:match('"r"%s*:%s*([%d%.]+)'))
		local g = tonumber(s:match('"g"%s*:%s*([%d%.]+)'))
		local b = tonumber(s:match('"b"%s*:%s*([%d%.]+)'))
		if r and g and b then
			return {r = r, g = g, b = b}
		end
		return nil
	end

	-- Array of quoted strings
	if s:sub(1, 1) == "[" then
		local arr = {}
		local inner = s:sub(2, -2)
		for item in inner:gmatch('"(.-[^\\])"') do
			table.insert(arr, item)
		end
		-- Fallback for empty or single-entry arrays
		if #arr == 0 then
			local single = inner:match('^%s*"(.-)"%s*$')
			if single then arr = {single} end
		end
		return arr
	end

	-- Number
	return tonumber(s)
end

-- Walk the JSON string token by token — immune to trailing-entry
-- loss and handles Color3 nested objects correctly.
local function deserializeConfig(raw)
	local result = {}
	raw = raw:match("^%s*(.-)%s*$")

	-- Strip outer braces
	if raw:sub(1,1) == "{" then
		raw = raw:sub(2, -2)
	end

	local pos = 1
	local len = #raw

	local function skipWS()
		while pos <= len and raw:sub(pos,pos):match("%s") do
			pos = pos + 1
		end
	end

	local function readString()
		-- pos is currently on the opening quote
		pos = pos + 1  -- skip "
		local buf = {}
		while pos <= len do
			local ch = raw:sub(pos, pos)
			if ch == '\\' then
				pos = pos + 1
				local esc = raw:sub(pos, pos)
				if esc == '"' then table.insert(buf, '"')
				elseif esc == '\\' then table.insert(buf, '\\')
				else table.insert(buf, esc) end
			elseif ch == '"' then
				pos = pos + 1  -- skip closing "
				break
			else
				table.insert(buf, ch)
			end
			pos = pos + 1
		end
		return table.concat(buf)
	end

	local function readValue()
		skipWS()
		local ch = raw:sub(pos, pos)

		if ch == '"' then
			return readString()

		elseif ch == '{' then
			-- Nested object — collect until matching }
			local depth = 0
			local start = pos
			repeat
				local c = raw:sub(pos, pos)
				if c == '{' then depth = depth + 1
				elseif c == '}' then depth = depth - 1 end
				pos = pos + 1
			until depth == 0 or pos > len
			return parseJsonValue(raw:sub(start, pos - 1))

		elseif ch == '[' then
			-- Array — collect until matching ]
			local depth = 0
			local start = pos
			repeat
				local c = raw:sub(pos, pos)
				if c == '[' then depth = depth + 1
				elseif c == ']' then depth = depth - 1 end
				pos = pos + 1
			until depth == 0 or pos > len
			return parseJsonValue(raw:sub(start, pos - 1))

		else
			-- Primitive: bool / number / null
			local start = pos
			while pos <= len do
				local c = raw:sub(pos, pos)
				if c == ',' or c == '}' or c == ']' or c:match("%s") then break end
				pos = pos + 1
			end
			return parseJsonValue(raw:sub(start, pos - 1))
		end
	end

	while pos <= len do
		skipWS()
		if pos > len then break end
		if raw:sub(pos, pos) ~= '"' then pos = pos + 1 ; continue end

		local key = readString()
		skipWS()
		if raw:sub(pos, pos) == ':' then pos = pos + 1 end
		local value = readValue()
		result[key] = value
		skipWS()
		if raw:sub(pos, pos) == ',' then pos = pos + 1 end
	end

	return result
end

-- ============================================================
-- KEY SYSTEM
-- Saves key to file after validation. Loads on next session
-- so the user doesn't re-enter it. Supports optional expiry
-- (Unix timestamp) embedded in the key via a simple format:
--   KEY:EXPIRY_TIMESTAMP
-- If EXPIRY_TIMESTAMP is absent, the key never expires.
-- ============================================================

local KEY_FILE = "xevor_key.dat"
local SALT     = "xev0r_s4lt_2024"  -- change per-project

local function hashString(s)
	-- Simple non-crypto checksum — sufficient for executor env.
	local h = 5381
	for i = 1, #s do
		h = ((h * 33) + string.byte(s, i)) % 0x100000000
	end
	return string.format("%08x", h)
end

local function buildKeyRecord(rawKey)
	local fingerprint = hashString(rawKey .. SALT)
	return rawKey .. "|" .. fingerprint
end

local function validateKeyRecord(record)
	if not record then return false, nil end
	local rawKey, storedHash = record:match("^(.+)|([0-9a-f]+)$")
	if not rawKey or not storedHash then return false, nil end

	local expected = hashString(rawKey .. SALT)
	if expected ~= storedHash then return false, nil end  -- tampered

	-- Check optional expiry embedded in key: "MYKEY:1700000000"
	local baseKey, expiry = rawKey:match("^(.+):(%d+)$")
	if expiry then
		local expiryNum = tonumber(expiry)
		-- os.time() available in most executors
		local ok, now = pcall(os.time)
		if ok and now and expiryNum and now > expiryNum then
			return false, nil  -- expired
		end
		return true, baseKey
	end

	return true, rawKey
end

-- Public key API — attach to library after construction.
-- library:SaveKey(rawKey)  → bool
-- library:LoadKey()        → rawKey or nil
-- library:ClearKey()       → void
-- library:ValidateKey(fn)  → calls fn(rawKey) if saved key is valid

local keySystem = {}

function keySystem:SaveKey(rawKey)
	rawKey = tostring(rawKey or "")
	if rawKey == "" then return false end
	local record = buildKeyRecord(rawKey)
	return safeWrite(KEY_FILE, record)
end

function keySystem:LoadKey()
	local record = safeRead(KEY_FILE)
	local valid, rawKey = validateKeyRecord(record)
	if valid then return rawKey end
	return nil
end

function keySystem:ClearKey()
	pcall(writefile, KEY_FILE, "")
end

function keySystem:ValidateKey(callback)
	local rawKey = self:LoadKey()
	if rawKey and callback then
		callback(rawKey)
		return true
	end
	return false
end

-- ============================================================
-- WATERMARK KEYBIND DRAWER
-- Clicking the watermark card toggles an animated keybind list
-- that expands below the status bar. Same visual language as
-- the card — no new ScreenGui, just extra rows inside the
-- existing watermark ImageLabel.
-- ============================================================

local wmKeybindData    = {}   -- { label, key }
local wmDrawerOpen     = false
local wmDrawerFrame    = nil  -- ScrollingFrame injected into watermark
local wmCardRef        = nil  -- watermark ImageLabel ref
local wmBaseHeight     = nil  -- collapsed card height
local WM_ROW_H         = 22
local WM_DRAWER_PAD    = 6
local WM_MAX_ROWS      = 5    -- rows visible before scroll

local function buildWatermarkDrawer(watermarkCard, collapsedHeight)
	wmCardRef    = watermarkCard
	wmBaseHeight = collapsedHeight

	-- Separator line above drawer
	utility:Create("ImageLabel", {
		Name             = "DrawerSep",
		Parent           = watermarkCard,
		BackgroundTransparency = 1,
		Position         = UDim2.new(0, 8, 0, collapsedHeight - 1),
		Size             = UDim2.new(1, -16, 0, 1),
		ZIndex           = 5,
		Visible          = false,
		Image            = "rbxassetid://4595286933",
		ImageColor3      = themes.LightContrast,
		ScaleType        = Enum.ScaleType.Slice,
		SliceCenter      = Rect.new(4, 4, 296, 296)
	})

	-- Drawer scroll frame
	wmDrawerFrame = utility:Create("ScrollingFrame", {
		Name                    = "KeybindDrawer",
		Parent                  = watermarkCard,
		BackgroundTransparency  = 1,
		Position                = UDim2.new(0, 0, 0, collapsedHeight + 2),
		Size                    = UDim2.new(1, 0, 0, 0),
		CanvasSize              = UDim2.new(0, 0, 0, 0),
		ZIndex                  = 4,
		ScrollBarThickness      = 2,
		ScrollBarImageColor3    = themes.LightContrast,
		Visible                 = false,
		ClipsDescendants        = true
	})

	utility:Create("UIListLayout", {
		Name      = "Layout",
		Parent    = wmDrawerFrame,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding   = UDim.new(0, 0)
	})
end

local function rebuildWatermarkDrawerRows()
	if not wmDrawerFrame then return end

	for _, ch in ipairs(wmDrawerFrame:GetChildren()) do
		if ch:IsA("Frame") then ch:Destroy() end
	end

	local count = #wmKeybindData
	for i, entry in ipairs(wmKeybindData) do
		local row = utility:Create("Frame", {
			Name              = "KBRow_" .. i,
			Parent            = wmDrawerFrame,
			BackgroundTransparency = 1,
			Size              = UDim2.new(1, 0, 0, WM_ROW_H),
			ZIndex            = 5
		})

		if i > 1 then
			utility:Create("Frame", {
				Name              = "Sep",
				Parent            = row,
				BackgroundColor3  = themes.LightContrast,
				BackgroundTransparency = 0.6,
				BorderSizePixel   = 0,
				Position          = UDim2.new(0, WM_DRAWER_PAD, 0, 0),
				Size              = UDim2.new(1, -(WM_DRAWER_PAD * 2), 0, 1),
				ZIndex            = 5
			})
		end

		utility:Create("TextLabel", {
			Name              = "Label",
			Parent            = row,
			BackgroundTransparency = 1,
			Position          = UDim2.new(0, WM_DRAWER_PAD + 4, 0, 0),
			Size              = UDim2.new(0.65, 0, 1, 0),
			ZIndex            = 6,
			Font              = Enum.Font.Gotham,
			Text              = entry.label,
			TextColor3        = themes.TextColor,
			TextSize          = 10,
			TextTransparency  = 0.2,
			TextXAlignment    = Enum.TextXAlignment.Left,
			TextTruncate      = Enum.TextTruncate.AtEnd
		})

		utility:Create("TextLabel", {
			Name              = "Key",
			Parent            = row,
			AnchorPoint       = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Position          = UDim2.new(1, -WM_DRAWER_PAD, 0.5, 0),
			Size              = UDim2.new(0.32, 0, 0, 14),
			ZIndex            = 6,
			Font              = Enum.Font.GothamSemibold,
			Text              = entry.key,
			TextColor3        = themes.TextColor,
			TextSize          = 10,
			TextTransparency  = 0.1,
			TextXAlignment    = Enum.TextXAlignment.Right
		})
	end

	local totalH = count * WM_ROW_H
	wmDrawerFrame.CanvasSize = UDim2.new(0, 0, 0, totalH)
	wmDrawerFrame.ScrollBarImageTransparency = (count > WM_MAX_ROWS) and 0 or 1
end

local function refreshWatermarkDrawer()
	if not wmCardRef or not wmDrawerFrame then return end

	rebuildWatermarkDrawerRows()

	local count = #wmKeybindData
	local sep   = wmCardRef:FindFirstChild("DrawerSep")

	if wmDrawerOpen and count > 0 then
		local drawerH = math.min(count, WM_MAX_ROWS) * WM_ROW_H + WM_DRAWER_PAD
		wmDrawerFrame.Visible = true
		if sep then sep.Visible = true end

		utility:Tween(wmDrawerFrame, {Size = UDim2.new(1, 0, 0, drawerH)}, 0.2)
		utility:Tween(wmCardRef, {
			Size = UDim2.new(wmCardRef.Size.X.Scale, wmCardRef.Size.X.Offset,
			                  0, wmBaseHeight + drawerH + 4)
		}, 0.2)
	else
		wmDrawerOpen = false
		if sep then sep.Visible = false end
		utility:Tween(wmDrawerFrame, {Size = UDim2.new(1, 0, 0, 0)}, 0.15)
		utility:Tween(wmCardRef, {
			Size = UDim2.new(wmCardRef.Size.X.Scale, wmCardRef.Size.X.Offset,
			                  0, wmBaseHeight)
		}, 0.15)
		task.delay(0.15, function()
			if not wmDrawerOpen then
				wmDrawerFrame.Visible = false
			end
		end)
	end
end

local function registerWmKeybind(label, keyName)
	for _, entry in ipairs(wmKeybindData) do
		if entry.label == label then
			entry.key = keyName or "None"
			if wmDrawerOpen then refreshWatermarkDrawer() end
			return
		end
	end
	table.insert(wmKeybindData, {label = label, key = keyName or "None"})
	if wmDrawerOpen then refreshWatermarkDrawer() end
end

local function unregisterWmKeybind(label)
	for i, entry in ipairs(wmKeybindData) do
		if entry.label == label then
			table.remove(wmKeybindData, i)
			break
		end
	end
	if wmDrawerOpen then refreshWatermarkDrawer() end
end

-- classes

local library = {}
local page = {}
local section = {}

library.Icons = {
	icon1  = 78448098168568,
	icon2  = 134778074060560,
	icon3  = 126402342060943,
	icon4  = 126810039551277,
	icon5  = 93378016140831,
	icon6  = 87811184442788,
	icon7  = 72796864087159,
	icon8  = 78102496134558,
	icon9  = 81115759913656,
	icon10 = 96500516193754,
	icon11 = 74415409437219,
	icon12 = 114521010215596,
	icon13 = 131241633461243,
	icon14 = 99002376488764,
	icon15 = 120338532250111,
	icon16 = 109963815197771,
	icon17 = 137880747463789,
	icon18 = 140530833013409,
	main      = 78448098168568,
	home      = 78448098168568,
	combat    = 134778074060560,
	visuals   = 126402342060943,
	player    = 126810039551277,
	misc      = 93378016140831,
	teleport  = 87811184442788,
	esp       = 72796864087159,
	aimbot    = 78102496134558,
	settings  = 81115759913656,
	credits   = 96500516193754,
	key       = 74415409437219,
	lock      = 114521010215596,
	shield    = 131241633461243,
	info      = 99002376488764,
	folder    = 120338532250111,
	menu      = 109963815197771,
	user      = 137880747463789,
	tip       = 140530833013409,
	walka       = 134778074060560,
	rozne       = 93378016140831,
	ustawienia  = 81115759913656,
	kredyty     = 96500516193754,
}

local function getPageIcon(title, icon)
	if icon then return icon end
	local iconName = tostring(title):lower():gsub("[^%w]", "")
	return library.Icons[iconName]
end

do
	library.__index = library
	page.__index = page
	section.__index = section

	function library:SetToggleKey(key)
		if self.toggleKeyConnection then
			self.toggleKeyConnection:Disconnect()
			self.toggleKeyConnection = nil
		end

		self.toggleKey = key
		if not key then return end

		self.toggleKeyConnection = input.InputBegan:Connect(function(userInput, gameProcessed)
			if gameProcessed or input:GetFocusedTextBox() then return end
			if userInput.KeyCode == self.toggleKey then
				self:SetVisible(not self.container.Enabled)
			end
		end)
	end

	function library:SetVisible(visible)
		self.container.Enabled = visible
	end

	function library:SetWatermarkVisible(visible)
		if self.watermark then
			self.watermark.Enabled = visible == true
		end
	end

	function library:SetWatermarkStyle(style)
		if type(style) ~= "table" or not self.watermark then return end

		local watermarkFrame = self.watermark:FindFirstChild("Watermark")
		if not watermarkFrame then return end

		local glow       = watermarkFrame:FindFirstChild("Glow")
		local accentLine = watermarkFrame:FindFirstChild("AccentLine")
		local topBar     = watermarkFrame:FindFirstChild("TopBar")
		local status     = watermarkFrame:FindFirstChild("Status")
		local titleLabel = watermarkFrame:FindFirstChild("Title", true)
		local info       = watermarkFrame:FindFirstChild("Info", true)

		if style.Enabled ~= nil then self.watermark.Enabled = style.Enabled == true end
		if typeof(style.Position) == "UDim2" then watermarkFrame.Position = style.Position end
		if typeof(style.AnchorPoint) == "Vector2" then watermarkFrame.AnchorPoint = style.AnchorPoint end
		if typeof(style.Size) == "UDim2" then watermarkFrame.Size = style.Size end
		if tonumber(style.DisplayOrder) then self.watermark.DisplayOrder = tonumber(style.DisplayOrder) end
		if typeof(style.BackgroundColor) == "Color3" then watermarkFrame.ImageColor3 = style.BackgroundColor end
		if topBar and typeof(style.TopBarColor) == "Color3" then topBar.ImageColor3 = style.TopBarColor end
		if status and typeof(style.StatusColor) == "Color3" then status.ImageColor3 = style.StatusColor end
		if glow then
			if style.Glow ~= nil then glow.Visible = style.Glow == true end
			if typeof(style.GlowColor) == "Color3" then glow.ImageColor3 = style.GlowColor end
		end
		if accentLine then
			if style.AccentLine ~= nil then accentLine.Visible = style.AccentLine == true end
			if typeof(style.AccentColor) == "Color3" then accentLine.ImageColor3 = style.AccentColor end
		end
		if titleLabel then
			if typeof(style.TextColor) == "Color3" then titleLabel.TextColor3 = style.TextColor end
			if typeof(style.TitleColor) == "Color3" then titleLabel.TextColor3 = style.TitleColor end
			if tonumber(style.TitleTextSize) then titleLabel.TextSize = math.clamp(tonumber(style.TitleTextSize), 8, 32) end
		end
		if info then
			if typeof(style.TextColor) == "Color3" then info.TextColor3 = style.TextColor end
			if tonumber(style.TextSize) then info.TextSize = math.clamp(tonumber(style.TextSize), 8, 32) end
		end
	end

	-- ============================================================
	-- CONFIG API
	-- library:SaveConfig(name)   writes <name>.json
	-- library:LoadConfig(name)   reads and applies saved values
	-- library:ListConfigs()      returns array of saved config names
	-- ============================================================

	function library:SaveConfig(name)
		name = sanitizeName(name)
		local data = serializeConfig()
		local path = name .. ".json"
		if safeWrite(path, data) then
			return true, path
		end
		return false, nil
	end

	function library:LoadConfig(name)
		name = sanitizeName(name)
		local path = name .. ".json"
		local raw = safeRead(path)
		if not raw then return false end

		local data = deserializeConfig(raw)

		for id, value in pairs(data) do
			local entry = configRegistry[id]
			if entry and entry.setter then
				pcall(entry.setter, value)
			end
		end

		return true
	end

	function library:ListConfigs()
		local list = {}
		pcall(function()
			for _, file in ipairs(listfiles(".")) do
				if file:match("%.json$") then
					local name = file:match("^(.+)%.json$")
					if name then
						table.insert(list, name)
					end
				end
			end
		end)
		return list
	end

	-- ============================================================
	-- KEY API — forwarded from keySystem
	-- library:SaveKey(rawKey)
	-- library:LoadKey()   → rawKey | nil
	-- library:ClearKey()
	-- library:ValidateKey(fn)
	-- ============================================================

	function library:SaveKey(rawKey)
		return keySystem:SaveKey(rawKey)
	end

	function library:LoadKey()
		return keySystem:LoadKey()
	end

	function library:ClearKey()
		keySystem:ClearKey()
	end

	function library:ValidateKey(callback)
		return keySystem:ValidateKey(callback)
	end

	function library:Destroy()
		if self.toggleKeyConnection then self.toggleKeyConnection:Disconnect() end
		if self.watermarkConnection  then self.watermarkConnection:Disconnect() end
		if self.watermark            then self.watermark:Destroy() end
		-- Reset watermark drawer state so next library.new() starts clean.
		wmKeybindData  = {}
		wmDrawerOpen   = false
		wmDrawerFrame  = nil
		wmCardRef      = nil
		wmBaseHeight   = nil
		self.container:Destroy()
	end

	-- ============================================================
	-- library.new
	-- ============================================================

	function library.new(title, options)
		options = options or {}

		local designWidth, designHeight = 511, 428
		local topbarHeight    = 38
		local navigationWidth = 126
		local contentLeft     = navigationWidth + 8
		local playerGui       = player:WaitForChild("PlayerGui")

		local watermarkOptions = type(options.Watermark) == "table" and options.Watermark or {}

		local watermarkEnabled     = watermarkOptions.Enabled ~= false
		local watermarkAnchor      = typeof(watermarkOptions.AnchorPoint) == "Vector2" and watermarkOptions.AnchorPoint or Vector2.new(1, 0)
		local watermarkPosition    = typeof(watermarkOptions.Position)    == "UDim2"   and watermarkOptions.Position    or UDim2.new(1, -16, 0, 16)
		local watermarkSize        = typeof(watermarkOptions.Size)        == "UDim2"   and watermarkOptions.Size        or UDim2.new(0, 390, 0, 58)
		local watermarkBackground  = typeof(watermarkOptions.BackgroundColor) == "Color3" and watermarkOptions.BackgroundColor or themes.Background
		local watermarkTopBar      = typeof(watermarkOptions.TopBarColor)     == "Color3" and watermarkOptions.TopBarColor     or themes.Accent
		local watermarkStatus      = typeof(watermarkOptions.StatusColor)     == "Color3" and watermarkOptions.StatusColor     or themes.DarkContrast
		local watermarkGlow        = typeof(watermarkOptions.GlowColor)       == "Color3" and watermarkOptions.GlowColor       or themes.Glow
		local watermarkAccent      = typeof(watermarkOptions.AccentColor)     == "Color3" and watermarkOptions.AccentColor     or themes.LightContrast
		local watermarkText        = typeof(watermarkOptions.TextColor)       == "Color3" and watermarkOptions.TextColor       or themes.TextColor
		local watermarkTextSize    = tonumber(watermarkOptions.TextSize)    or 13
		local watermarkTopbarH     = math.clamp(tonumber(watermarkOptions.TopBarHeight) or 27, 22, 40)
		local watermarkShowGlow    = watermarkOptions.Glow ~= false
		local watermarkShowAccent  = watermarkOptions.AccentLine ~= false
		local watermarkDisplayOrder= tonumber(watermarkOptions.DisplayOrder) or 9999
		local menuDisplayOrder     = tonumber(options.DisplayOrder) or 9998

		local guiParent = playerGui
		pcall(function() guiParent = game:GetService("CoreGui") end)

		local container = utility:Create("ScreenGui", {
			Name = title,
			Parent = guiParent,
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			DisplayOrder = menuDisplayOrder,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		}, {
			utility:Create("ImageLabel", {
				Name = "Main",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.new(0, designWidth, 0, designHeight),
				Image = "rbxassetid://4641149554",
				ImageColor3 = themes.Background,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(4, 4, 296, 296)
			}, {
				utility:Create("ImageLabel", {
					Name = "Glow",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, -15, 0, -15),
					Size = UDim2.new(1, 30, 1, 30),
					ZIndex = 0,
					Image = "rbxassetid://5028857084",
					ImageColor3 = themes.Glow,
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(24, 24, 276, 276)
				}),
				utility:Create("ImageLabel", {
					Name = "Pages",
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					Position = UDim2.new(0, 0, 0, topbarHeight),
					Size = UDim2.new(0, navigationWidth, 1, -topbarHeight),
					ZIndex = 3,
					Image = "rbxassetid://5012534273",
					ImageColor3 = themes.DarkContrast,
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(4, 4, 296, 296)
				}, {
					utility:Create("ScrollingFrame", {
						Name = "Pages_Container",
						Active = true,
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 0, 0, 10),
						Size = UDim2.new(1, 0, 1, -20),
						CanvasSize = UDim2.new(0, 0, 0, 314),
						ScrollBarThickness = 0
					}, {
						utility:Create("UIListLayout", {
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 10)
						})
					})
				}),
				utility:Create("ImageLabel", {
					Name = "TopBar",
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					Size = UDim2.new(1, 0, 0, topbarHeight),
					ZIndex = 5,
					Image = "rbxassetid://4595286933",
					ImageColor3 = themes.Accent,
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(4, 4, 296, 296)
				}, {
					utility:Create("TextLabel", {
						Name = "Title",
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 12, 0.5, 0),
						Size = UDim2.new(1, -94, 0, 16),
						ZIndex = 5,
						Font = Enum.Font.GothamBold,
						Text = title,
						TextColor3 = themes.TextColor,
						TextSize = 14,
						TextXAlignment = Enum.TextXAlignment.Left
					}),
					utility:Create("TextButton", {
						Name = "Minimize",
						BackgroundTransparency = 1,
						Position = UDim2.new(1, -62, 0, 0),
						Size = UDim2.new(0, 30, 1, 0),
						ZIndex = 6,
						Font = Enum.Font.GothamBold,
						Text = "-",
						TextColor3 = themes.TextColor,
						TextSize = 20
					}),
					utility:Create("TextButton", {
						Name = "Close",
						BackgroundTransparency = 1,
						Position = UDim2.new(1, -32, 0, 0),
						Size = UDim2.new(0, 30, 1, 0),
						ZIndex = 6,
						Font = Enum.Font.GothamBold,
						Text = "X",
						TextColor3 = themes.TextColor,
						TextSize = 16
					})
				})
			})
		})

		-- Watermark card height = topbar + status area
		local wmCollapsedH = watermarkSize.Y.Offset  -- e.g. 58

		local watermarkCard = utility:Create("ImageLabel", {
			Name = "Watermark",
			AnchorPoint = watermarkAnchor,
			BackgroundTransparency = 1,
			Position = watermarkPosition,
			Size = watermarkSize,
			ZIndex = 2,
			Image = "rbxassetid://4641149554",
			ImageColor3 = watermarkBackground,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(4, 4, 296, 296)
		}, {
			utility:Create("ImageLabel", {
				Name = "Glow",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, -7, 0, -7),
				Size = UDim2.new(1, 14, 1, 14),
				ZIndex = 1,
				Visible = watermarkShowGlow,
				Image = "rbxassetid://5028857084",
				ImageColor3 = watermarkGlow,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(24, 24, 276, 276)
			}),
			utility:Create("ImageLabel", {
				Name = "TopBar",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 0, watermarkTopbarH),
				ZIndex = 3,
				Image = "rbxassetid://4595286933",
				ImageColor3 = watermarkTopBar,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(4, 4, 296, 296)
			}, {
				utility:Create("TextLabel", {
					Name = "Title",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 14, 0, 0),
					Size = UDim2.new(1, -28, 1, 0),
					ZIndex = 4,
					Font = Enum.Font.GothamBold,
					Text = title,
					TextColor3 = watermarkText,
					TextSize = watermarkTextSize + 1,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left
				}),
				-- Click indicator chevron in top-right of watermark topbar
				utility:Create("TextLabel", {
					Name = "DrawerArrow",
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.new(0, 14, 0, 14),
					ZIndex = 4,
					Font = Enum.Font.GothamBold,
					Text = "▲",
					TextColor3 = watermarkText,
					TextTransparency = 0.5,
					TextSize = 8
				})
			}),
			utility:Create("ImageLabel", {
				Name = "Status",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 6, 0, watermarkTopbarH + 4),
				Size = UDim2.new(1, -12, 1, -(watermarkTopbarH + 10)),
				ZIndex = 3,
				Image = "rbxassetid://5012534273",
				ImageColor3 = watermarkStatus,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(4, 4, 296, 296)
			}, {
				utility:Create("TextLabel", {
					Name = "Info",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 10, 0, 0),
					Size = UDim2.new(1, -20, 1, 0),
					ZIndex = 4,
					Font = Enum.Font.GothamSemibold,
					Text = player.Name .. " | -- FPS | -- ms",
					TextColor3 = watermarkText,
					TextSize = watermarkTextSize,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left
				})
			}),
			utility:Create("ImageLabel", {
				Name = "AccentLine",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 8, 0, watermarkTopbarH - 1),
				Size = UDim2.new(1, -16, 0, 1),
				ZIndex = 5,
				Visible = watermarkShowAccent,
				Image = "rbxassetid://4595286933",
				ImageColor3 = watermarkAccent,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(4, 4, 296, 296)
			})
		})

		local watermark = utility:Create("ScreenGui", {
			Name = title .. "_Watermark",
			Parent = guiParent,
			Enabled = watermarkEnabled,
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			DisplayOrder = watermarkDisplayOrder,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		})

		watermarkCard.Parent = watermark

		-- Build the keybind drawer attached to the watermark card.
		buildWatermarkDrawer(watermarkCard, wmCollapsedH)

		-- Wire the click-toggle on the watermark card's topbar.
		-- Use InputBegan on the ImageLabel (not a button) — reliable across all input types.
		local wmTopBar = watermarkCard:FindFirstChild("TopBar")
		if wmTopBar then
			local wmDragging = false
			local wmDragStart

			wmTopBar.InputBegan:Connect(function(inp)
				if inp.UserInputType == Enum.UserInputType.MouseButton1
					or inp.UserInputType == Enum.UserInputType.Touch then
					wmDragging = false
					wmDragStart = inp.Position
				end
			end)

			wmTopBar.InputChanged:Connect(function(inp)
				if inp.UserInputType == Enum.UserInputType.MouseMovement
					or inp.UserInputType == Enum.UserInputType.Touch then
					if wmDragStart then
						local delta = (inp.Position - wmDragStart).Magnitude
						if delta > 4 then wmDragging = true end
					end
				end
			end)

			wmTopBar.InputEnded:Connect(function(inp)
				if (inp.UserInputType == Enum.UserInputType.MouseButton1
					or inp.UserInputType == Enum.UserInputType.Touch)
					and not wmDragging then

					wmDrawerOpen = not wmDrawerOpen
					local arrow = wmTopBar:FindFirstChild("DrawerArrow")
					if arrow then
						arrow.Text = wmDrawerOpen and "▼" or "▲"
					end
					refreshWatermarkDrawer()
				end
				if inp.UserInputType == Enum.UserInputType.MouseButton1
					or inp.UserInputType == Enum.UserInputType.Touch then
					wmDragStart = nil
				end
			end)

			utility:DraggingEnabled(wmTopBar, watermarkCard)
		end

		pcall(function()
			if syn and syn.protect_gui then
				syn.protect_gui(container)
				syn.protect_gui(watermark)
			elseif protectgui then
				protectgui(container)
				protectgui(watermark)
			end
		end)

		utility:InitializeKeybind()
		utility:DraggingEnabled(container.Main.TopBar, container.Main)

		local window = setmetatable({
			container       = container,
			pagesContainer  = container.Main.Pages.Pages_Container,
			pages           = {},
			watermark       = watermark,
			topbarHeight    = topbarHeight,
			navigationWidth = navigationWidth,
			contentLeft     = contentLeft
		}, library)

		window:SetToggleKey(options.ToggleKey or Enum.KeyCode.RightShift)

		-- FPS / ping ticker
		local frameCount = 0
		local lastSample = os.clock()

		window.watermarkConnection = run.RenderStepped:Connect(function()
			frameCount = frameCount + 1
			local now     = os.clock()
			local elapsed = now - lastSample
			if elapsed < 1 then return end

			local ping = 0
			local ok, value = pcall(function()
				return stats.Network.ServerStatsItem["Data Ping"]:GetValue()
			end)
			if ok and tonumber(value) then
				ping = math.floor(tonumber(value) + 0.5)
			end

			local fps = math.floor((frameCount / elapsed) + 0.5)
			watermarkCard.Status.Info.Text = string.format(
				"%s | %d FPS | %d ms", player.Name, fps, ping)
			frameCount = 0
			lastSample = now
		end)

		container.Main.TopBar.Minimize.MouseButton1Click:Connect(function()
			window:toggle()
		end)
		container.Main.TopBar.Close.MouseButton1Click:Connect(function()
			window:Destroy()
		end)

		return window
	end

	-- ============================================================
	-- page.new  /  section.new
	-- ============================================================

	function page.new(library, title, icon)
		icon = getPageIcon(title, icon)

		local button = utility:Create("TextButton", {
			Name = title,
			Parent = library.pagesContainer,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 26),
			ZIndex = 3,
			AutoButtonColor = false,
			Font = Enum.Font.Gotham,
			Text = "",
			TextSize = 14
		}, {
			utility:Create("TextLabel", {
				Name = "Title",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 40, 0.5, 0),
				Size = UDim2.new(0, 76, 1, 0),
				ZIndex = 3,
				Font = Enum.Font.Gotham,
				Text = title,
				TextColor3 = themes.TextColor,
				TextSize = 12,
				TextTransparency = 0.65,
				TextXAlignment = Enum.TextXAlignment.Left
			})
		})

		if icon then
			local iconId = tostring(icon):gsub("%D", "")
			utility:Create("ImageLabel", {
				Name = "Icon",
				Parent = button,
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 10, 0.5, 0),
				Size = UDim2.new(0, 18, 0, 18),
				ZIndex = 4,
				Image = "rbxassetid://" .. iconId,
				ImageColor3 = Color3.fromRGB(255, 255, 255),
				ImageTransparency = 0.35,
				ScaleType = Enum.ScaleType.Fit
			})
		end

		local container = utility:Create("ScrollingFrame", {
			Name = title,
			Parent = library.container.Main,
			Active = true,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, library.contentLeft, 0, library.topbarHeight + 8),
			Size = UDim2.new(1, -(library.contentLeft + 8), 1, -(library.topbarHeight + 18)),
			CanvasSize = UDim2.new(0, 0, 0, 466),
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = themes.DarkContrast,
			Visible = false
		}, {
			utility:Create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10)
			})
		})

		return setmetatable({
			library   = library,
			container = container,
			button    = button,
			sections  = {}
		}, page)
	end

	function section.new(page, title)
		local container = utility:Create("ImageLabel", {
			Name = title,
			Parent = page.container,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -10, 0, 28),
			ZIndex = 2,
			Image = "rbxassetid://5028857472",
			ImageColor3 = themes.LightContrast,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(4, 4, 296, 296),
			ClipsDescendants = true
		}, {
			utility:Create("Frame", {
				Name = "Container",
				Active = true,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 8, 0, 8),
				Size = UDim2.new(1, -16, 1, -16)
			}, {
				utility:Create("TextLabel", {
					Name = "Title",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 20),
					ZIndex = 2,
					Font = Enum.Font.GothamSemibold,
					Text = title,
					TextColor3 = themes.TextColor,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTransparency = 1
				}),
				utility:Create("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4)
				})
			})
		})

		return setmetatable({
			page         = page,
			container    = container.Container,
			colorpickers = {},
			modules      = {},
			binds        = {},
			lists        = {},
		}, section)
	end

	function library:addPage(...)
		local p = page.new(self, ...)
		local button = p.button

		table.insert(self.pages, p)

		button.MouseButton1Click:Connect(function()
			self:SelectPage(p, true)
		end)

		return p
	end

	function page:addSection(...)
		local s = section.new(self, ...)
		table.insert(self.sections, s)
		return s
	end

	-- ============================================================
	-- Theme
	-- ============================================================

	function library:setTheme(theme, color3)
		themes[theme] = color3

		for property, objectSet in pairs(objects[theme] or {}) do
			for i, object in pairs(objectSet) do
				if not object.Parent or (object.Name == "Button" and object.Parent.Name == "ColorPicker") then
					objectSet[i] = nil
				else
					object[property] = color3
				end
			end
		end
	end

	-- ============================================================
	-- Minimize / toggle
	-- ============================================================

	function library:toggle()
		if self.toggling then return end
		self.toggling = true

		local cont   = self.container.Main
		local topbar = cont.TopBar

		if self.minimized then
			local expandedSize = self.expandedSize
			local yOffset = (expandedSize.Y.Offset - self.topbarHeight) / 2

			utility:Tween(cont, {
				Size = expandedSize,
				Position = cont.Position - UDim2.fromOffset(0, yOffset)
			}, 0.2)
			wait(0.2)

			utility:Tween(topbar, {Size = UDim2.new(1, 0, 0, self.topbarHeight)}, 0.15)
			cont.ClipsDescendants = false
			self.minimized = false
		else
			self.expandedSize = cont.Size
			local yOffset = (self.expandedSize.Y.Offset - self.topbarHeight) / 2

			cont.ClipsDescendants = true
			utility:Tween(topbar, {Size = UDim2.new(1, 0, 1, 0)}, 0.15)
			wait(0.15)

			utility:Tween(cont, {
				Size = UDim2.fromOffset(self.expandedSize.X.Offset, self.topbarHeight),
				Position = cont.Position + UDim2.fromOffset(0, yOffset)
			}, 0.2)
			self.minimized = true
		end

		self.toggling = false
	end

	-- ============================================================
	-- Notify
	-- ============================================================

	function library:Notify(title, text, callback, duration)
		if type(callback) == "number" and duration == nil then
			duration = callback
			callback = nil
		end
		duration = math.max(tonumber(duration) or 4, 0.5)

		if self.activeNotification then
			self.activeNotification = self.activeNotification()
		end

		local notification = utility:Create("ImageLabel", {
			Name = "Notification",
			Parent = self.container,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 200, 0, 60),
			Image = "rbxassetid://5028857472",
			ImageColor3 = themes.Background,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(4, 4, 296, 296),
			ZIndex = 3,
			ClipsDescendants = true
		}, {
			utility:Create("ImageLabel", {Name="Flash",   Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Image="rbxassetid://4641149554", ImageColor3=themes.TextColor, ZIndex=5}),
			utility:Create("ImageLabel", {Name="Glow",    BackgroundTransparency=1, Position=UDim2.new(0,-15,0,-15), Size=UDim2.new(1,30,1,30), ZIndex=2, Image="rbxassetid://5028857084", ImageColor3=themes.Glow, ScaleType=Enum.ScaleType.Slice, SliceCenter=Rect.new(24,24,276,276)}),
			utility:Create("TextLabel",  {Name="Title",   BackgroundTransparency=1, Position=UDim2.new(0,10,0,8), Size=UDim2.new(1,-40,0,16), ZIndex=4, Font=Enum.Font.GothamSemibold, TextColor3=themes.TextColor, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left}),
			utility:Create("TextLabel",  {Name="Text",    BackgroundTransparency=1, Position=UDim2.new(0,10,1,-24), Size=UDim2.new(1,-40,0,16), ZIndex=4, Font=Enum.Font.Gotham, TextColor3=themes.TextColor, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left}),
			utility:Create("ImageButton",{Name="Accept",  BackgroundTransparency=1, Position=UDim2.new(1,-26,0,8),   Size=UDim2.new(0,16,0,16), Image="rbxassetid://5012538259", ImageColor3=themes.TextColor, ZIndex=4}),
			utility:Create("ImageButton",{Name="Decline", BackgroundTransparency=1, Position=UDim2.new(1,-26,1,-24), Size=UDim2.new(0,16,0,16), Image="rbxassetid://5012538583", ImageColor3=themes.TextColor, ZIndex=4})
		})

		title = title or "Notification"
		text  = text  or ""

		notification.Title.Text = title
		notification.Text.Text  = text
		notification.Accept.Visible  = callback ~= nil
		notification.Decline.Visible = callback ~= nil

		local padding = 16
		local height  = 60
		local textSize = game:GetService("TextService"):GetTextSize(text, 12, Enum.Font.Gotham, Vector2.new(math.huge, 16))
		local width   = math.clamp(textSize.X + 70, 200, 360)
		local visiblePosition = UDim2.new(1, -(width + padding), 1, -(height + padding))
		local hiddenPosition  = UDim2.new(1, padding, 1, -(height + padding))

		notification.Position = hiddenPosition
		notification.Size = UDim2.new(0, 0, 0, height)
		utility:Tween(notification, {Size = UDim2.new(0, width, 0, height), Position = visiblePosition}, 0.2)
		wait(0.2)

		notification.ClipsDescendants = false
		utility:Tween(notification.Flash, {Size = UDim2.new(0,0,0,60), Position = UDim2.new(1,0,0,0)}, 0.2)

		local active = true
		local close = function()
			if not active then return end
			active = false
			notification.ClipsDescendants = true
			notification.Flash.Position = UDim2.new(0,0,0,0)
			utility:Tween(notification.Flash, {Size = UDim2.new(1,0,1,0)}, 0.2)
			wait(0.2)
			utility:Tween(notification, {Size = UDim2.new(0,0,0,60), Position = hiddenPosition}, 0.2)
			wait(0.2)
			notification:Destroy()
		end

		self.activeNotification = close
		task.delay(duration, close)

		notification.Accept.MouseButton1Click:Connect(function()
			if not active then return end
			if callback then callback(true) end
			close()
		end)

		notification.Decline.MouseButton1Click:Connect(function()
			if not active then return end
			if callback then callback(false) end
			close()
		end)
	end

	-- ============================================================
	-- addButton
	-- ============================================================

	function section:addButton(title, callback)
		local button = utility:Create("ImageButton", {
			Name = "Button",
			Parent = self.container,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 30),
			ZIndex = 2,
			Image = "rbxassetid://5028857472",
			ImageColor3 = themes.DarkContrast,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(2, 2, 298, 298)
		}, {
			utility:Create("TextLabel", {
				Name = "Title",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 3,
				Font = Enum.Font.Gotham,
				Text = title,
				TextColor3 = themes.TextColor,
				TextSize = 12,
				TextTransparency = 0.10000000149012
			})
		})

		table.insert(self.modules, button)
		self:Resize()

		local text = button.Title
		local debounce

		button.MouseButton1Click:Connect(function()
			if debounce then return end

			utility:Pop(button, 10)
			debounce = true
			text.TextSize = 0
			utility:Tween(button.Title, {TextSize = 14}, 0.2)
			wait(0.2)
			utility:Tween(button.Title, {TextSize = 12}, 0.2)

			if callback then
				callback(function(...) self:updateButton(button, ...) end)
			end

			debounce = false
		end)

		return button
	end

	-- ============================================================
	-- addLabel
	-- ============================================================

	function section:addLabel(text, options)
		options = type(options) == "table" and options or {}

		local align     = ({Left=true,Center=true,Right=true})[options.Align] and options.Align or "Left"
		local textSize  = math.clamp(tonumber(options.Size) or 12, 8, 24)
		local textAlpha = math.clamp(tonumber(options.Alpha) or 0.35, 0, 1)

		local frame = utility:Create("Frame", {
			Name = "Label_" .. tostring(text):sub(1, 24),
			Parent = self.container,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 22),
			ZIndex = 2
		})

		utility:Create("TextLabel", {
			Name = "Text",
			Parent = frame,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 8, 0, 0),
			Size = UDim2.new(1, -16, 1, 0),
			ZIndex = 3,
			Font = Enum.Font.GothamSemibold,
			Text = text,
			TextColor3 = themes.TextColor,
			TextSize = textSize,
			TextTransparency = textAlpha,
			TextXAlignment = Enum.TextXAlignment[align],
			TextTruncate = Enum.TextTruncate.AtEnd
		})

		table.insert(self.modules, frame)
		self:Resize()

		return frame
	end

	-- ============================================================
	-- addToggle
	-- ============================================================

	function section:addToggle(title, default, callback, configId)
		local toggle = utility:Create("ImageButton", {
			Name = "Toggle",
			Parent = self.container,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 30),
			ZIndex = 2,
			Image = "rbxassetid://5028857472",
			ImageColor3 = themes.DarkContrast,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(2, 2, 298, 298)
		}, {
			utility:Create("TextLabel", {
				Name = "Title",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 10, 0.5, 1),
				Size = UDim2.new(0.5, 0, 1, 0),
				ZIndex = 3,
				Font = Enum.Font.Gotham,
				Text = title,
				TextColor3 = themes.TextColor,
				TextSize = 12,
				TextTransparency = 0.10000000149012,
				TextXAlignment = Enum.TextXAlignment.Left
			}),
			utility:Create("ImageLabel", {
				Name = "Button",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.new(1, -50, 0.5, -8),
				Size = UDim2.new(0, 40, 0, 16),
				ZIndex = 2,
				Image = "rbxassetid://5028857472",
				ImageColor3 = themes.LightContrast,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(2, 2, 298, 298)
			}, {
				utility:Create("ImageLabel", {
					Name = "Frame",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 2, 0.5, -6),
					Size = UDim2.new(1, -22, 1, -4),
					ZIndex = 2,
					Image = "rbxassetid://5028857472",
					ImageColor3 = themes.TextColor,
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(2, 2, 298, 298)
				})
			})
		})

		table.insert(self.modules, toggle)
		self:Resize()

		local active = default
		self:updateToggle(toggle, nil, active)

		if configId then
			configRegistry[configId] = {
				getter = function() return active end,
				setter = function(v)
					active = v == true or v == "true"
					self:updateToggle(toggle, nil, active)
					if callback then callback(active, function(...) self:updateToggle(toggle, ...) end) end
				end
			}
		end

		toggle.MouseButton1Click:Connect(function()
			active = not active
			self:updateToggle(toggle, nil, active)
			if callback then
				callback(active, function(...) self:updateToggle(toggle, ...) end)
			end
		end)

		return toggle
	end

	-- ============================================================
	-- addTextbox
	-- ============================================================

	function section:addTextbox(title, default, callback, configId)
		local textbox = utility:Create("ImageButton", {
			Name = "Textbox",
			Parent = self.container,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 30),
			ZIndex = 2,
			Image = "rbxassetid://5028857472",
			ImageColor3 = themes.DarkContrast,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(2, 2, 298, 298)
		}, {
			utility:Create("TextLabel", {
				Name = "Title",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 10, 0.5, 1),
				Size = UDim2.new(0.5, 0, 1, 0),
				ZIndex = 3,
				Font = Enum.Font.Gotham,
				Text = title,
				TextColor3 = themes.TextColor,
				TextSize = 12,
				TextTransparency = 0.10000000149012,
				TextXAlignment = Enum.TextXAlignment.Left
			}),
			utility:Create("ImageLabel", {
				Name = "Button",
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -110, 0.5, -8),
				Size = UDim2.new(0, 100, 0, 16),
				ZIndex = 2,
				Image = "rbxassetid://5028857472",
				ImageColor3 = themes.LightContrast,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(2, 2, 298, 298)
			}, {
				utility:Create("TextBox", {
					Name = "Textbox",
					BackgroundTransparency = 1,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Position = UDim2.new(0, 5, 0, 0),
					Size = UDim2.new(1, -10, 1, 0),
					ZIndex = 3,
					Font = Enum.Font.GothamSemibold,
					Text = default or "",
					TextColor3 = themes.TextColor,
					TextSize = 11
				})
			})
		})

		table.insert(self.modules, textbox)
		self:Resize()

		local button = textbox.Button
		local inp    = button.Textbox

		if configId then
			configRegistry[configId] = {
				getter = function() return inp.Text end,
				setter = function(v) inp.Text = tostring(v or "") end
			}
		end

		textbox.MouseButton1Click:Connect(function()
			if textbox.Button.Size ~= UDim2.new(0, 100, 0, 16) then return end
			utility:Tween(textbox.Button, {Size = UDim2.new(0, 200, 0, 16), Position = UDim2.new(1, -210, 0.5, -8)}, 0.2)
			wait()
			inp.TextXAlignment = Enum.TextXAlignment.Left
			inp:CaptureFocus()
		end)

		inp:GetPropertyChangedSignal("Text"):Connect(function()
			if button.ImageTransparency == 0 and (button.Size == UDim2.new(0, 200, 0, 16) or button.Size == UDim2.new(0, 100, 0, 16)) then
				utility:Pop(button, 10)
			end
			if callback then callback(inp.Text, nil, function(...) self:updateTextbox(textbox, ...) end) end
		end)

		inp.FocusLost:Connect(function()
			inp.TextXAlignment = Enum.TextXAlignment.Center
			utility:Tween(textbox.Button, {Size = UDim2.new(0, 100, 0, 16), Position = UDim2.new(1, -110, 0.5, -8)}, 0.2)
			if callback then callback(inp.Text, true, function(...) self:updateTextbox(textbox, ...) end) end
		end)

		return textbox
	end

	-- ============================================================
	-- addKeybind
	-- ============================================================

	function section:addKeybind(title, default, callback, changedCallback, configId)
		local keybind = utility:Create("ImageButton", {
			Name = "Keybind",
			Parent = self.container,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 30),
			ZIndex = 2,
			Image = "rbxassetid://5028857472",
			ImageColor3 = themes.DarkContrast,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(2, 2, 298, 298)
		}, {
			utility:Create("TextLabel", {
				Name = "Title",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 10, 0.5, 1),
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 3,
				Font = Enum.Font.Gotham,
				Text = title,
				TextColor3 = themes.TextColor,
				TextSize = 12,
				TextTransparency = 0.10000000149012,
				TextXAlignment = Enum.TextXAlignment.Left
			}),
			utility:Create("ImageLabel", {
				Name = "Button",
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -110, 0.5, -8),
				Size = UDim2.new(0, 100, 0, 16),
				ZIndex = 2,
				Image = "rbxassetid://5028857472",
				ImageColor3 = themes.LightContrast,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(2, 2, 298, 298)
			}, {
				utility:Create("TextLabel", {
					Name = "Text",
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					Size = UDim2.new(1, 0, 1, 0),
					ZIndex = 3,
					Font = Enum.Font.GothamSemibold,
					Text = default and default.Name or "None",
					TextColor3 = themes.TextColor,
					TextSize = 11
				})
			})
		})

		table.insert(self.modules, keybind)
		self:Resize()

		local text   = keybind.Button.Text
		local button = keybind.Button

		local animate = function()
			if button.ImageTransparency == 0 then utility:Pop(button, 10) end
		end

		self.binds[keybind] = {callback = function()
			animate()
			if callback then callback(function(...) self:updateKeybind(keybind, ...) end) end
		end}

		if default and callback then
			self:updateKeybind(keybind, nil, default)
		end

		-- Register in watermark drawer on creation
		registerWmKeybind(title, default and default.Name or "None")

		if configId then
			configRegistry[configId] = {
				getter = function()
					return text.Text ~= "..." and text.Text or "None"
				end,
				setter = function(v)
					if v and v ~= "None" then
						local keyCode = Enum.KeyCode[v]
						if keyCode then
							self:updateKeybind(keybind, nil, keyCode)
						end
					end
				end
			}
		end

		keybind.MouseButton1Click:Connect(function()
			animate()

			if self.binds[keybind].connection then
				self:updateKeybind(keybind)
				return
			end

			if text.Text == "None" then
				text.Text = "..."

				local key = utility:KeyPressed()
				self:updateKeybind(keybind, nil, key.KeyCode)
				animate()

				-- Sync watermark drawer
				registerWmKeybind(title, key.KeyCode.Name)

				if changedCallback then
					changedCallback(key, function(...) self:updateKeybind(keybind, ...) end)
				end
			end
		end)

		return keybind
	end

	-- ============================================================
	-- addColorPicker
	-- ============================================================

	function section:addColorPicker(title, default, callback, configId)
		local colorpicker = utility:Create("ImageButton", {
			Name = "ColorPicker",
			Parent = self.container,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 30),
			ZIndex = 2,
			Image = "rbxassetid://5028857472",
			ImageColor3 = themes.DarkContrast,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(2, 2, 298, 298)
		}, {
			utility:Create("TextLabel", {
				Name = "Title",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 10, 0.5, 1),
				Size = UDim2.new(0.5, 0, 1, 0),
				ZIndex = 3,
				Font = Enum.Font.Gotham,
				Text = title,
				TextColor3 = themes.TextColor,
				TextSize = 12,
				TextTransparency = 0.10000000149012,
				TextXAlignment = Enum.TextXAlignment.Left
			}),
			utility:Create("ImageButton", {
				Name = "Button",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.new(1, -50, 0.5, -7),
				Size = UDim2.new(0, 40, 0, 14),
				ZIndex = 2,
				Image = "rbxassetid://5028857472",
				ImageColor3 = Color3.fromRGB(255, 255, 255),
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(2, 2, 298, 298)
			})
		})

		local tab = utility:Create("ImageLabel", {
			Name = "ColorPicker",
			Parent = self.page.library.container,
			BackgroundTransparency = 1,
			Position = UDim2.new(0.75, 0, 0.4, 0),
			Selectable = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 162, 0, 169),
			Image = "rbxassetid://5028857472",
			ImageColor3 = themes.Background,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(2, 2, 298, 298),
			Visible = false
		}, {
			utility:Create("ImageLabel", {Name="Glow", BackgroundTransparency=1, Position=UDim2.new(0,-15,0,-15), Size=UDim2.new(1,30,1,30), ZIndex=0, Image="rbxassetid://5028857084", ImageColor3=themes.Glow, ScaleType=Enum.ScaleType.Slice, SliceCenter=Rect.new(22,22,278,278)}),
			utility:Create("TextLabel", {Name="Title", BackgroundTransparency=1, Position=UDim2.new(0,10,0,8), Size=UDim2.new(1,-40,0,16), ZIndex=2, Font=Enum.Font.GothamSemibold, Text=title, TextColor3=themes.TextColor, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left}),
			utility:Create("ImageButton", {Name="Close", BackgroundTransparency=1, Position=UDim2.new(1,-26,0,8), Size=UDim2.new(0,16,0,16), ZIndex=2, Image="rbxassetid://5012538583", ImageColor3=themes.TextColor}),
			utility:Create("Frame", {
				Name = "Container",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 8, 0, 32),
				Size = UDim2.new(1, -18, 1, -40)
			}, {
				utility:Create("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6)}),
				utility:Create("ImageButton", {
					Name="Canvas", BackgroundTransparency=1, Size=UDim2.new(1,0,0,60), AutoButtonColor=false,
					Image="rbxassetid://5108535320", ImageColor3=Color3.fromRGB(255,0,0), ScaleType=Enum.ScaleType.Slice, SliceCenter=Rect.new(2,2,298,298)
				}, {
					utility:Create("ImageLabel", {Name="White_Overlay", BackgroundTransparency=1, Size=UDim2.new(1,0,0,60), Image="rbxassetid://5107152351", SliceCenter=Rect.new(2,2,298,298)}),
					utility:Create("ImageLabel", {Name="Black_Overlay", BackgroundTransparency=1, Size=UDim2.new(1,0,0,60), Image="rbxassetid://5107152095", SliceCenter=Rect.new(2,2,298,298)}),
					utility:Create("ImageLabel", {Name="Cursor", BackgroundColor3=themes.TextColor, AnchorPoint=Vector2.new(0.5,0.5), BackgroundTransparency=1, Size=UDim2.new(0,10,0,10), Position=UDim2.new(0,0,0,0), Image="rbxassetid://5100115962", SliceCenter=Rect.new(2,2,298,298)})
				}),
				utility:Create("ImageButton", {
					Name="Color", BackgroundTransparency=1, BorderSizePixel=0, Position=UDim2.new(0,0,0,4), Selectable=false,
					Size=UDim2.new(1,0,0,16), ZIndex=2, AutoButtonColor=false, Image="rbxassetid://5028857472", ScaleType=Enum.ScaleType.Slice, SliceCenter=Rect.new(2,2,298,298)
				}, {
					utility:Create("Frame", {Name="Select", BackgroundColor3=themes.TextColor, BorderSizePixel=1, Position=UDim2.new(1,0,0,0), Size=UDim2.new(0,2,1,0), ZIndex=2}),
					utility:Create("UIGradient", {Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,0,0)),ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,255,0)),ColorSequenceKeypoint.new(0.33,Color3.fromRGB(0,255,0)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(0,255,255)),ColorSequenceKeypoint.new(0.66,Color3.fromRGB(0,0,255)),ColorSequenceKeypoint.new(0.82,Color3.fromRGB(255,0,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,0,0))})})
				}),
				utility:Create("Frame", {Name="Inputs", BackgroundTransparency=1, Position=UDim2.new(0,10,0,158), Size=UDim2.new(1,0,0,16)}, {
					utility:Create("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6)}),
					utility:Create("ImageLabel", {Name="R", BackgroundTransparency=1, BorderSizePixel=0, Size=UDim2.new(0.305,0,1,0), ZIndex=2, Image="rbxassetid://5028857472", ImageColor3=themes.DarkContrast, ScaleType=Enum.ScaleType.Slice, SliceCenter=Rect.new(2,2,298,298)}, {utility:Create("TextLabel", {Name="Text", BackgroundTransparency=1, Size=UDim2.new(0.4,0,1,0), ZIndex=2, Font=Enum.Font.Gotham, Text="R:", TextColor3=themes.TextColor, TextSize=10}), utility:Create("TextBox", {Name="Textbox", BackgroundTransparency=1, Position=UDim2.new(0.3,0,0,0), Size=UDim2.new(0.6,0,1,0), ZIndex=2, Font=Enum.Font.Gotham, Text="255", TextColor3=themes.TextColor, TextSize=10})}),
					utility:Create("ImageLabel", {Name="G", BackgroundTransparency=1, BorderSizePixel=0, Size=UDim2.new(0.305,0,1,0), ZIndex=2, Image="rbxassetid://5028857472", ImageColor3=themes.DarkContrast, ScaleType=Enum.ScaleType.Slice, SliceCenter=Rect.new(2,2,298,298)}, {utility:Create("TextLabel", {Name="Text", BackgroundTransparency=1, ZIndex=2, Size=UDim2.new(0.4,0,1,0), Font=Enum.Font.Gotham, Text="G:", TextColor3=themes.TextColor, TextSize=10}), utility:Create("TextBox", {Name="Textbox", BackgroundTransparency=1, Position=UDim2.new(0.3,0,0,0), Size=UDim2.new(0.6,0,1,0), ZIndex=2, Font=Enum.Font.Gotham, Text="255", TextColor3=themes.TextColor, TextSize=10})}),
					utility:Create("ImageLabel", {Name="B", BackgroundTransparency=1, BorderSizePixel=0, Size=UDim2.new(0.305,0,1,0), ZIndex=2, Image="rbxassetid://5028857472", ImageColor3=themes.DarkContrast, ScaleType=Enum.ScaleType.Slice, SliceCenter=Rect.new(2,2,298,298)}, {utility:Create("TextLabel", {Name="Text", BackgroundTransparency=1, Size=UDim2.new(0.4,0,1,0), ZIndex=2, Font=Enum.Font.Gotham, Text="B:", TextColor3=themes.TextColor, TextSize=10}), utility:Create("TextBox", {Name="Textbox", BackgroundTransparency=1, Position=UDim2.new(0.3,0,0,0), Size=UDim2.new(0.6,0,1,0), ZIndex=2, Font=Enum.Font.Gotham, Text="255", TextColor3=themes.TextColor, TextSize=10})})
				}),
				utility:Create("ImageButton", {Name="Button", BackgroundTransparency=1, BorderSizePixel=0, Size=UDim2.new(1,0,0,20), ZIndex=2, Image="rbxassetid://5028857472", ImageColor3=themes.DarkContrast, ScaleType=Enum.ScaleType.Slice, SliceCenter=Rect.new(2,2,298,298)}, {utility:Create("TextLabel", {Name="Text", BackgroundTransparency=1, Size=UDim2.new(1,0,1,0), ZIndex=3, Font=Enum.Font.Gotham, Text="Submit", TextColor3=themes.TextColor, TextSize=11})})
			})
		})

		utility:DraggingEnabled(tab)
		table.insert(self.modules, colorpicker)
		self:Resize()

		local allowed = {[""] = true}
		local canvas  = tab.Container.Canvas
		local color   = tab.Container.Color
		local canvasSize, canvasPosition = canvas.AbsoluteSize, canvas.AbsolutePosition
		local colorSize, colorPosition   = color.AbsoluteSize, color.AbsolutePosition
		local draggingColor, draggingCanvas

		local color3 = default or Color3.fromRGB(255, 255, 255)
		local hue, sat, brightness = 0, 0, 1
		local rgb = {r = 255, g = 255, b = 255}

		self.colorpickers[colorpicker] = {
			tab = tab,
			callback = function(prop, value)
				rgb[prop] = value
				hue, sat, brightness = Color3.toHSV(Color3.fromRGB(rgb.r, rgb.g, rgb.b))
			end
		}

		if configId then
			configRegistry[configId] = {
				getter = function()
					return {r = math.floor(rgb.r), g = math.floor(rgb.g), b = math.floor(rgb.b)}
				end,
				setter = function(v)
					if type(v) == "table" and v.r then
						local c = Color3.fromRGB(v.r, v.g, v.b)
						self:updateColorPicker(colorpicker, nil, c)
						if callback then callback(c, function(...) self:updateColorPicker(colorpicker, ...) end) end
					end
				end
			}
		end

		local userCallback = callback
		local callback = function(value)
			if userCallback then userCallback(value, function(...) self:updateColorPicker(colorpicker, ...) end) end
		end

		utility:DraggingEnded(function()
			draggingColor, draggingCanvas = false, false
		end)

		if default then
			self:updateColorPicker(colorpicker, nil, default)
			hue, sat, brightness = Color3.toHSV(default)
			default = Color3.fromHSV(hue, sat, brightness)
			for i, prop in pairs({"r", "g", "b"}) do
				rgb[prop] = default[prop:upper()] * 255
			end
		end

		for i, cont in pairs(tab.Container.Inputs:GetChildren()) do
			if cont:IsA("ImageLabel") then
				local textbox = cont.Textbox
				local focused

				textbox.Focused:Connect(function() focused = true end)
				textbox.FocusLost:Connect(function()
					focused = false
					if not tonumber(textbox.Text) then
						textbox.Text = math.floor(rgb[cont.Name:lower()])
					end
				end)

				textbox:GetPropertyChangedSignal("Text"):Connect(function()
					local text = textbox.Text
					if not allowed[text] and not tonumber(text) then
						textbox.Text = text:sub(1, #text - 1)
					elseif focused and not allowed[text] then
						rgb[cont.Name:lower()] = math.clamp(tonumber(textbox.Text), 0, 255)
						local c3 = Color3.fromRGB(rgb.r, rgb.g, rgb.b)
						hue, sat, brightness = Color3.toHSV(c3)
						self:updateColorPicker(colorpicker, nil, c3)
						callback(c3)
					end
				end)
			end
		end

		canvas.MouseButton1Down:Connect(function()
			draggingCanvas = true
			while draggingCanvas do
				sat = math.clamp((mouse.X - canvasPosition.X) / canvasSize.X, 0, 1)
				brightness = 1 - math.clamp((mouse.Y - canvasPosition.Y) / canvasSize.Y, 0, 1)
				color3 = Color3.fromHSV(hue, sat, brightness)
				for i, prop in pairs({"r", "g", "b"}) do rgb[prop] = color3[prop:upper()] * 255 end
				self:updateColorPicker(colorpicker, nil, {hue, sat, brightness})
				utility:Tween(canvas.Cursor, {Position = UDim2.new(sat, 0, 1 - brightness, 0)}, 0.1)
				callback(color3)
				utility:Wait()
			end
		end)

		color.MouseButton1Down:Connect(function()
			draggingColor = true
			while draggingColor do
				hue = 1 - math.clamp(1 - ((mouse.X - colorPosition.X) / colorSize.X), 0, 1)
				color3 = Color3.fromHSV(hue, sat, brightness)
				for i, prop in pairs({"r", "g", "b"}) do rgb[prop] = color3[prop:upper()] * 255 end
				local x = hue
				self:updateColorPicker(colorpicker, nil, {hue, sat, brightness})
				utility:Tween(tab.Container.Color.Select, {Position = UDim2.new(x, 0, 0, 0)}, 0.1)
				callback(color3)
				utility:Wait()
			end
		end)

		local button = colorpicker.Button
		local toggle, debounce, animate
		local lastColor = Color3.fromHSV(hue, sat, brightness)

		animate = function(visible, overwrite)
			if overwrite then
				if not toggle then return end
				if debounce then while debounce do utility:Wait() end end
			else
				if debounce then return end
				if button.ImageTransparency == 0 then utility:Pop(button, 10) end
			end

			toggle = visible
			debounce = true

			if visible then
				if self.page.library.activePicker and self.page.library.activePicker ~= animate then
					self.page.library.activePicker(nil, true)
				end
				self.page.library.activePicker = animate
				lastColor = Color3.fromHSV(hue, sat, brightness)

				local x1 = button.AbsoluteSize.X / 2
				local px, py = button.AbsolutePosition.X, button.AbsolutePosition.Y

				tab.ClipsDescendants = true
				tab.Visible = true
				tab.Size = UDim2.new(0, 0, 0, 0)
				tab.Position = UDim2.new(0, x1 + 162 + px, 0, py)
				utility:Tween(tab, {Size = UDim2.new(0, 162, 0, 169)}, 0.2)
				wait(0.2)

				tab.ClipsDescendants = false
				canvasSize, canvasPosition = canvas.AbsoluteSize, canvas.AbsolutePosition
				colorSize, colorPosition   = color.AbsoluteSize, color.AbsolutePosition
			else
				utility:Tween(tab, {Size = UDim2.new(0, 0, 0, 0)}, 0.2)
				tab.ClipsDescendants = true
				wait(0.2)
				tab.Visible = false
			end

			debounce = false
		end

		local toggleTab = function() animate(not toggle) end
		button.MouseButton1Click:Connect(toggleTab)
		colorpicker.MouseButton1Click:Connect(toggleTab)
		tab.Container.Button.MouseButton1Click:Connect(function() animate() end)
		tab.Close.MouseButton1Click:Connect(function()
			self:updateColorPicker(colorpicker, nil, lastColor)
			animate()
		end)

		return colorpicker
	end

	-- ============================================================
	-- addSlider
	-- ============================================================

	function section:addSlider(title, default, min, max, callback, configId)
		local slider = utility:Create("ImageButton", {
			Name = "Slider",
			Parent = self.container,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0.292817682, 0, 0.299145311, 0),
			Size = UDim2.new(1, 0, 0, 50),
			ZIndex = 2,
			Image = "rbxassetid://5028857472",
			ImageColor3 = themes.DarkContrast,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(2, 2, 298, 298)
		}, {
			utility:Create("TextLabel", {Name="Title", BackgroundTransparency=1, Position=UDim2.new(0,10,0,6), Size=UDim2.new(0.5,0,0,16), ZIndex=3, Font=Enum.Font.Gotham, Text=title, TextColor3=themes.TextColor, TextSize=12, TextTransparency=0.10000000149012, TextXAlignment=Enum.TextXAlignment.Left}),
			utility:Create("TextBox", {Name="TextBox", BackgroundTransparency=1, BorderSizePixel=0, Position=UDim2.new(1,-30,0,6), Size=UDim2.new(0,20,0,16), ZIndex=3, Font=Enum.Font.GothamSemibold, Text=default or min, TextColor3=themes.TextColor, TextSize=12, TextXAlignment=Enum.TextXAlignment.Right}),
			utility:Create("TextLabel", {Name="Slider", BackgroundTransparency=1, Position=UDim2.new(0,10,0,28), Size=UDim2.new(1,-20,0,16), ZIndex=3, Text=""}, {
				utility:Create("ImageLabel", {Name="Bar", AnchorPoint=Vector2.new(0,0.5), BackgroundTransparency=1, Position=UDim2.new(0,0,0.5,0), Size=UDim2.new(1,0,0,4), ZIndex=3, Image="rbxassetid://5028857472", ImageColor3=themes.LightContrast, ScaleType=Enum.ScaleType.Slice, SliceCenter=Rect.new(2,2,298,298)}, {
					utility:Create("ImageLabel", {Name="Fill", BackgroundTransparency=1, Size=UDim2.new(0.8,0,1,0), ZIndex=3, Image="rbxassetid://5028857472", ImageColor3=themes.TextColor, ScaleType=Enum.ScaleType.Slice, SliceCenter=Rect.new(2,2,298,298)}, {
						utility:Create("ImageLabel", {Name="Circle", AnchorPoint=Vector2.new(0.5,0.5), BackgroundTransparency=1, ImageTransparency=1, ImageColor3=themes.TextColor, Position=UDim2.new(1,0,0.5,0), Size=UDim2.new(0,10,0,10), ZIndex=3, Image="rbxassetid://4608020054"})
					})
				})
			})
		})

		table.insert(self.modules, slider)
		self:Resize()

		local allowed = {[""] = true, ["-"] = true}
		local textbox = slider.TextBox
		local circle  = slider.Slider.Bar.Fill.Circle

		local value = default or min
		local dragging = false
		local activeInput = nil

		local userCallback = callback
		local callback = function(v)
			if userCallback then userCallback(v, function(...) self:updateSlider(slider, ...) end) end
		end

		if configId then
			configRegistry[configId] = {
				getter = function() return value end,
				setter = function(v)
					value = self:updateSlider(slider, nil, tonumber(v) or min, min, max)
					if userCallback then userCallback(value, function(...) self:updateSlider(slider, ...) end) end
				end
			}
		end

		self:updateSlider(slider, nil, value, min, max)

		local function stopDrag()
			if not dragging then return end
			dragging = false
			activeInput = nil
			utility:Tween(circle, {ImageTransparency = 1}, 0.2)
		end

		slider.InputBegan:Connect(function(userInput)
			if userInput.UserInputType ~= Enum.UserInputType.MouseButton1
				and userInput.UserInputType ~= Enum.UserInputType.Touch then return end

			dragging = true
			activeInput = userInput
			utility:Tween(circle, {ImageTransparency = 0}, 0.1)

			userInput.Changed:Connect(function()
				if userInput.UserInputState == Enum.UserInputState.End then stopDrag() end
			end)

			while dragging do
				local posX = mouse.X
				if activeInput and activeInput.UserInputType == Enum.UserInputType.Touch then
					posX = activeInput.Position.X
				end
				value = self:updateSlider(slider, nil, nil, min, max, value, posX)
				callback(value)
				utility:Wait()
			end
		end)

		utility:DraggingEnded(stopDrag)

		textbox.FocusLost:Connect(function()
			if not tonumber(textbox.Text) then
				value = self:updateSlider(slider, nil, default or min, min, max)
				callback(value)
			end
		end)

		textbox:GetPropertyChangedSignal("Text"):Connect(function()
			local text = textbox.Text
			if not allowed[text] and not tonumber(text) then
				textbox.Text = text:sub(1, #text - 1)
			elseif not allowed[text] then
				value = self:updateSlider(slider, nil, tonumber(text) or value, min, max)
				callback(value)
			end
		end)

		return slider
	end

	-- ============================================================
	-- addDropdown  (single-select)
	-- ============================================================

	function section:addDropdown(title, list, callback, configId)
		local dropdown = utility:Create("Frame", {
			Name = "Dropdown",
			Parent = self.container,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			ClipsDescendants = true
		}, {
			utility:Create("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4)}),
			utility:Create("ImageLabel", {
				Name="Search", BackgroundTransparency=1, BorderSizePixel=0, Size=UDim2.new(1,0,0,30), ZIndex=2,
				Image="rbxassetid://5028857472", ImageColor3=themes.DarkContrast, ScaleType=Enum.ScaleType.Slice, SliceCenter=Rect.new(2,2,298,298)
			}, {
				utility:Create("TextBox", {Name="TextBox", AnchorPoint=Vector2.new(0,0.5), BackgroundTransparency=1, TextTruncate=Enum.TextTruncate.AtEnd, Position=UDim2.new(0,10,0.5,1), Size=UDim2.new(1,-42,1,0), ZIndex=3, Font=Enum.Font.Gotham, Text=title, TextColor3=themes.TextColor, TextSize=12, TextTransparency=0.10000000149012, TextXAlignment=Enum.TextXAlignment.Left}),
				utility:Create("ImageButton", {Name="Button", BackgroundTransparency=1, BorderSizePixel=0, Position=UDim2.new(1,-28,0.5,-9), Size=UDim2.new(0,18,0,18), ZIndex=3, Image="rbxassetid://5012539403", ImageColor3=themes.TextColor, SliceCenter=Rect.new(2,2,298,298)})
			}),
			utility:Create("ImageLabel", {
				Name="List", BackgroundTransparency=1, BorderSizePixel=0, Size=UDim2.new(1,0,1,-34), ZIndex=2,
				Image="rbxassetid://5028857472", ImageColor3=themes.Background, ScaleType=Enum.ScaleType.Slice, SliceCenter=Rect.new(2,2,298,298)
			}, {
				utility:Create("ScrollingFrame", {Name="Frame", Active=true, BackgroundTransparency=1, BorderSizePixel=0, Position=UDim2.new(0,4,0,4), Size=UDim2.new(1,-8,1,-8), CanvasPosition=Vector2.new(0,28), CanvasSize=UDim2.new(0,0,0,120), ZIndex=2, ScrollBarThickness=3, ScrollBarImageColor3=themes.DarkContrast}, {
					utility:Create("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4)})
				})
			})
		})

		table.insert(self.modules, dropdown)
		self:Resize()

		local search = dropdown.Search
		local focused
		list = list or {}

		if configId then
			local selectedValue = ""
			configRegistry[configId] = {
				getter = function() return selectedValue end,
				setter = function(v)
					selectedValue = tostring(v or "")
					search.TextBox.Text = selectedValue
					if callback then callback(selectedValue, function(...) self:updateDropdown(dropdown, ...) end) end
				end
			}
			local origCallback = callback
			callback = function(value, updater)
				selectedValue = value
				if origCallback then origCallback(value, updater) end
			end
		end

		search.Button.MouseButton1Click:Connect(function()
			if search.Button.Rotation == 0 then
				self:updateDropdown(dropdown, nil, list, callback)
			else
				self:updateDropdown(dropdown, nil, nil, callback)
			end
		end)

		search.TextBox.Focused:Connect(function()
			if search.Button.Rotation == 0 then
				self:updateDropdown(dropdown, nil, list, callback)
			end
			focused = true
		end)

		search.TextBox.FocusLost:Connect(function() focused = false end)

		search.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
			if focused then
				local sorted = utility:Sort(search.TextBox.Text, list)
				sorted = #sorted ~= 0 and sorted
				self:updateDropdown(dropdown, nil, sorted, callback)
			end
		end)

		dropdown:GetPropertyChangedSignal("Size"):Connect(function()
			self:Resize()
		end)

		return dropdown
	end

	-- ============================================================
	-- addMultiDropdown
	-- Fixed: header click now uses InputBegan guard (ImageLabel
	-- doesn't fire MouseButton1Click reliably).
	-- ============================================================

	function section:addMultiDropdown(title, list, defaults, callback, configId)
		list     = list     or {}
		defaults = defaults or {}

		local selected = {}
		for _, v in ipairs(defaults) do
			selected[v] = true
		end

		local function displayText()
			local parts = {}
			for _, v in ipairs(list) do
				if selected[v] then table.insert(parts, v) end
			end
			if #parts == 0 then return title end
			if #parts <= 2 then return table.concat(parts, ", ") end
			return parts[1] .. ", +" .. (#parts - 1)
		end

		local dropdown = utility:Create("Frame", {
			Name = "MultiDropdown",
			Parent = self.container,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			ClipsDescendants = true
		}, {
			utility:Create("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4)}),
			utility:Create("ImageLabel", {
				Name="Search", BackgroundTransparency=1, BorderSizePixel=0, Size=UDim2.new(1,0,0,30), ZIndex=2,
				Image="rbxassetid://5028857472", ImageColor3=themes.DarkContrast, ScaleType=Enum.ScaleType.Slice, SliceCenter=Rect.new(2,2,298,298)
			}, {
				utility:Create("TextLabel", {
					Name="TextBox",
					AnchorPoint=Vector2.new(0,0.5), BackgroundTransparency=1,
					Position=UDim2.new(0,10,0.5,1), Size=UDim2.new(1,-42,1,0),
					ZIndex=3, Font=Enum.Font.Gotham, Text=displayText(),
					TextColor3=themes.TextColor, TextSize=12,
					TextTransparency=0.10000000149012, TextXAlignment=Enum.TextXAlignment.Left,
					TextTruncate=Enum.TextTruncate.AtEnd
				}),
				utility:Create("ImageButton", {
					Name="Button", BackgroundTransparency=1, BorderSizePixel=0,
					Position=UDim2.new(1,-28,0.5,-9), Size=UDim2.new(0,18,0,18),
					ZIndex=3, Image="rbxassetid://5012539403", ImageColor3=themes.TextColor,
					SliceCenter=Rect.new(2,2,298,298)
				})
			}),
			utility:Create("ImageLabel", {
				Name="List", BackgroundTransparency=1, BorderSizePixel=0, Size=UDim2.new(1,0,1,-34), ZIndex=2,
				Image="rbxassetid://5028857472", ImageColor3=themes.Background, ScaleType=Enum.ScaleType.Slice, SliceCenter=Rect.new(2,2,298,298)
			}, {
				utility:Create("ScrollingFrame", {
					Name="Frame", Active=true, BackgroundTransparency=1, BorderSizePixel=0,
					Position=UDim2.new(0,4,0,4), Size=UDim2.new(1,-8,1,-8),
					CanvasSize=UDim2.new(0,0,0,0), ZIndex=2, ScrollBarThickness=3,
					ScrollBarImageColor3=themes.DarkContrast
				}, {
					utility:Create("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4)})
				})
			})
		})

		table.insert(self.modules, dropdown)
		self:Resize()

		local search   = dropdown.Search
		local label    = search.TextBox
		local listOpen = false

		if configId then
			configRegistry[configId] = {
				getter = function()
					local arr = {}
					for v, on in pairs(selected) do
						if on then table.insert(arr, v) end
					end
					return arr
				end,
				setter = function(arr)
					selected = {}
					if type(arr) == "table" then
						for _, v in ipairs(arr) do selected[v] = true end
					end
					label.Text = displayText()
					if callback then callback(selected) end
					if listOpen then buildRows() end
				end
			}
		end

		local buildRows  -- forward declare so toggle can call it

		buildRows = function()
			local frame = dropdown.List.Frame

			for _, child in ipairs(frame:GetChildren()) do
				if child:IsA("ImageButton") then child:Destroy() end
			end

			for _, value in ipairs(list) do
				local checked = selected[value] == true

				local row = utility:Create("ImageButton", {
					Parent = frame,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 30),
					ZIndex = 2,
					Image = "rbxassetid://5028857472",
					ImageColor3 = themes.DarkContrast,
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(2, 2, 298, 298)
				})

				utility:Create("ImageLabel", {
					Name = "Check",
					Parent = row,
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 8, 0.5, 0),
					Size = UDim2.new(0, 12, 0, 12),
					ZIndex = 3,
					Image = "rbxassetid://5028857472",
					ImageColor3 = checked and themes.TextColor or themes.LightContrast,
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(2, 2, 298, 298)
				})

				utility:Create("TextLabel", {
					Parent = row,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 28, 0, 0),
					Size = UDim2.new(1, -36, 1, 0),
					ZIndex = 3,
					Font = Enum.Font.Gotham,
					Text = value,
					TextColor3 = themes.TextColor,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTransparency = checked and 0.05 or 0.4
				})

				row.MouseButton1Click:Connect(function()
					selected[value] = not selected[value]
					utility:Pop(row, 8)
					label.Text = displayText()
					if callback then callback(selected) end
					buildRows()
				end)
			end

			local count = #list
			local rowH  = math.min(count, 4) * 34 + 8
			frame.CanvasSize = UDim2.new(0, 0, 0, count * 34)
			frame.ScrollBarImageTransparency = count > 4 and 0 or 1
			utility:Tween(dropdown, {Size = UDim2.new(1, 0, 0, rowH + 38)}, 0.25)
		end

		local function toggle()
			listOpen = not listOpen
			utility:Tween(search.Button, {Rotation = listOpen and 180 or 0}, 0.25)

			if listOpen then
				buildRows()
			else
				for _, child in ipairs(dropdown.List.Frame:GetChildren()) do
					if child:IsA("ImageButton") then child:Destroy() end
				end
				utility:Tween(dropdown, {Size = UDim2.new(1, 0, 0, 30)}, 0.25)
			end
		end

		-- Arrow button — always a real GuiButton, fine to use MouseButton1Click.
		search.Button.MouseButton1Click:Connect(toggle)

		-- Header bar is an ImageLabel — use InputBegan/InputEnded with drag guard.
		local mdDragging = false
		local mdDragStart

		search.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1
				or inp.UserInputType == Enum.UserInputType.Touch then
				mdDragging = false
				mdDragStart = inp.Position
			end
		end)

		search.InputChanged:Connect(function(inp)
			if (inp.UserInputType == Enum.UserInputType.MouseMovement
				or inp.UserInputType == Enum.UserInputType.Touch)
				and mdDragStart then
				if (inp.Position - mdDragStart).Magnitude > 4 then
					mdDragging = true
				end
			end
		end)

		search.InputEnded:Connect(function(inp)
			if (inp.UserInputType == Enum.UserInputType.MouseButton1
				or inp.UserInputType == Enum.UserInputType.Touch)
				and not mdDragging then
				-- Only fire if the arrow button itself wasn't clicked
				-- (it sits inside search so events bubble — check position).
				local btn = search:FindFirstChild("Button")
				if btn then
					local bPos = btn.AbsolutePosition
					local bSz  = btn.AbsoluteSize
					local mPos = inp.Position
					if mPos.X >= bPos.X and mPos.X <= bPos.X + bSz.X
						and mPos.Y >= bPos.Y and mPos.Y <= bPos.Y + bSz.Y then
						-- Click landed on the arrow — arrow handler covers it.
						mdDragStart = nil
						return
					end
				end
				toggle()
			end
			if inp.UserInputType == Enum.UserInputType.MouseButton1
				or inp.UserInputType == Enum.UserInputType.Touch then
				mdDragStart = nil
			end
		end)

		dropdown:GetPropertyChangedSignal("Size"):Connect(function()
			self:Resize()
		end)

		function dropdown:getSelected()
			local arr = {}
			for v, on in pairs(selected) do
				if on then table.insert(arr, v) end
			end
			return arr
		end

		return dropdown
	end

	-- ============================================================
	-- SelectPage
	-- ============================================================

	function library:SelectPage(p, toggle)
		if toggle and self.focusedPage == p then return end

		local button = p.button

		if toggle then
			button.Title.TextTransparency = 0
			button.Title.Font = Enum.Font.GothamSemibold

			if button:FindFirstChild("Icon") then
				button.Icon.ImageTransparency = 0
				button.Icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
			end

			local focusedPage = self.focusedPage
			self.focusedPage = p

			if focusedPage then self:SelectPage(focusedPage) end

			local existingSections = focusedPage and #focusedPage.sections or 0
			local sectionsRequired = #p.sections - existingSections

			p:Resize()

			for i, sec in pairs(p.sections) do
				sec.container.Parent.ImageTransparency = 0
			end

			if sectionsRequired < 0 then
				for i = existingSections, #p.sections + 1, -1 do
					local sec = focusedPage.sections[i].container.Parent
					utility:Tween(sec, {ImageTransparency = 1}, 0.1)
				end
			end

			wait(0.1)
			p.container.Visible = true
			if focusedPage then focusedPage.container.Visible = false end

			if sectionsRequired > 0 then
				for i = existingSections + 1, #p.sections do
					local sec = p.sections[i].container.Parent
					sec.ImageTransparency = 1
					utility:Tween(sec, {ImageTransparency = 0}, 0.05)
				end
			end

			wait(0.05)

			for i, sec in pairs(p.sections) do
				sec.container.Title.TextTransparency = 0
				sec:Resize(false)
				wait(0.05)
			end

			wait(0.05)
			p:Resize(true)
		else
			button.Title.Font = Enum.Font.Gotham
			button.Title.TextTransparency = 0.65

			if button:FindFirstChild("Icon") then
				button.Icon.ImageTransparency = 0.35
			end

			for i, sec in pairs(p.sections) do
				utility:Tween(sec.container.Parent, {Size = UDim2.new(1, -10, 0, 28)}, 0.1)
				utility:Tween(sec.container.Title, {TextTransparency = 1}, 0.1)
			end

			wait(0.1)
			p.lastPosition = p.container.CanvasPosition.Y
			p:Resize()
		end
	end

	function page:Resize(scroll)
		local padding = 10
		local size    = 0

		for i, sec in pairs(self.sections) do
			size = size + sec.container.Parent.AbsoluteSize.Y + padding
		end

		self.container.CanvasSize = UDim2.new(0, 0, 0, size)
		self.container.ScrollBarImageTransparency = (size > self.container.AbsoluteSize.Y) and 0 or 1

		if scroll then
			utility:Tween(self.container, {CanvasPosition = Vector2.new(0, self.lastPosition or 0)}, 0.2)
		end
	end

	function section:Resize(smooth)
		local padding = 4
		local titleY  = self.container.Title.AbsoluteSize.Y
		if titleY < 1 then titleY = 20 end
		local size = (4 * padding) + titleY

		for _, module in pairs(self.modules) do
			local moduleY = module.AbsoluteSize.Y
			if moduleY < 1 then moduleY = 30 end
			size = size + moduleY + padding
		end

		if self.page.library.focusedPage ~= self.page then
			self.container.Parent.Size = UDim2.new(1, -10, 0, size)
			return
		end

		if smooth then
			utility:Tween(self.container.Parent, {Size = UDim2.new(1, -10, 0, size)}, 0.05)
		else
			self.container.Parent.Size = UDim2.new(1, -10, 0, size)
			self.page:Resize()
		end
	end

	function section:getModule(info)
		if table.find(self.modules, info) then return info end

		for i, module in pairs(self.modules) do
			local t = module:FindFirstChild("Title") or module:FindFirstChild("TextBox", true)
			if t and t.Text == info then return module end
		end

		error("No module found under " .. tostring(info))
	end

	-- ============================================================
	-- Update helpers
	-- ============================================================

	function section:updateButton(button, title)
		button = self:getModule(button)
		button.Title.Text = title
	end

	function section:updateLabel(frame, text)
		if frame and frame:FindFirstChild("Text") then
			frame.Text.Text = text
		end
	end

	function section:updateToggle(toggle, title, value)
		toggle = self:getModule(toggle)

		local position = {
			In  = UDim2.new(0, 2,  0.5, -6),
			Out = UDim2.new(0, 20, 0.5, -6)
		}

		local frame = toggle.Button.Frame
		value = value and "Out" or "In"

		if title then toggle.Title.Text = title end

		utility:Tween(frame, {Size = UDim2.new(1,-22,1,-9), Position = position[value] + UDim2.new(0,0,0,2.5)}, 0.2)
		wait(0.1)
		utility:Tween(frame, {Size = UDim2.new(1,-22,1,-4), Position = position[value]}, 0.1)
	end

	function section:updateTextbox(textbox, title, value)
		textbox = self:getModule(textbox)
		if title then textbox.Title.Text = title end
		if value then textbox.Button.Textbox.Text = value end
	end

	function section:updateKeybind(keybind, title, key)
		keybind = self:getModule(keybind)

		local text = keybind.Button.Text
		local bind = self.binds[keybind]

		if title then keybind.Title.Text = title end

		if bind.connection then
			bind.connection = bind.connection:UnBind()
		end

		if key then
			self.binds[keybind].connection = utility:BindToKey(key, bind.callback)
			text.Text = key.Name
			registerWmKeybind(keybind.Title.Text, key.Name)
		else
			text.Text = "None"
			registerWmKeybind(keybind.Title.Text, "None")
		end
	end

	function section:updateColorPicker(colorpicker, title, color)
		colorpicker = self:getModule(colorpicker)

		local picker = self.colorpickers[colorpicker]
		local tab    = picker.tab

		if title then
			colorpicker.Title.Text = title
			tab.Title.Text = title
		end

		local color3, hue, sat, brightness

		if type(color) == "table" then
			hue, sat, brightness = unpack(color)
			color3 = Color3.fromHSV(hue, sat, brightness)
		else
			color3 = color
			hue, sat, brightness = Color3.toHSV(color3)
		end

		utility:Tween(colorpicker.Button, {ImageColor3 = color3}, 0.5)
		utility:Tween(tab.Container.Color.Select, {Position = UDim2.new(hue, 0, 0, 0)}, 0.1)
		utility:Tween(tab.Container.Canvas, {ImageColor3 = Color3.fromHSV(hue, 1, 1)}, 0.5)
		utility:Tween(tab.Container.Canvas.Cursor, {Position = UDim2.new(sat, 0, 1 - brightness)}, 0.5)

		for i, cont in pairs(tab.Container.Inputs:GetChildren()) do
			if cont:IsA("ImageLabel") then
				local value = math.clamp(color3[cont.Name], 0, 1) * 255
				cont.Textbox.Text = math.floor(value)
			end
		end
	end

	function section:updateSlider(slider, title, value, min, max, lvalue, posX)
		slider = self:getModule(slider)

		if title then slider.Title.Text = title end

		local bar      = slider.Slider.Bar
		local pointerX = posX or mouse.X
		local percent  = (pointerX - bar.AbsolutePosition.X) / bar.AbsoluteSize.X

		if value then percent = (value - min) / (max - min) end

		percent = math.clamp(percent, 0, 1)
		value   = value or math.floor(min + (max - min) * percent)

		slider.TextBox.Text = value
		utility:Tween(bar.Fill, {Size = UDim2.new(percent, 0, 1, 0)}, 0.1)

		if value ~= lvalue and slider.ImageTransparency == 0 then
			utility:Pop(slider, 10)
		end

		return value
	end

	function section:updateDropdown(dropdown, title, list, callback)
		dropdown = self:getModule(dropdown)

		if title then dropdown.Search.TextBox.Text = title end

		local entries = 0
		utility:Pop(dropdown.Search, 10)

		for i, button in pairs(dropdown.List.Frame:GetChildren()) do
			if button:IsA("ImageButton") then button:Destroy() end
		end

		for i, value in pairs(list or {}) do
			local button = utility:Create("ImageButton", {
				Parent = dropdown.List.Frame,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 30),
				ZIndex = 2,
				Image = "rbxassetid://5028857472",
				ImageColor3 = themes.DarkContrast,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(2, 2, 298, 298)
			}, {
				utility:Create("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 10, 0, 0),
					Size = UDim2.new(1, -10, 1, 0),
					ZIndex = 3,
					Font = Enum.Font.Gotham,
					Text = value,
					TextColor3 = themes.TextColor,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTransparency = 0.10000000149012
				})
			})

			button.MouseButton1Click:Connect(function()
				if callback then callback(value, function(...) self:updateDropdown(dropdown, ...) end) end
				self:updateDropdown(dropdown, value, nil, callback)
			end)

			entries = entries + 1
		end

		local frame = dropdown.List.Frame

		utility:Tween(dropdown, {Size = UDim2.new(1, 0, 0, (entries == 0 and 30) or math.clamp(entries, 0, 3) * 34 + 38)}, 0.3)
		utility:Tween(dropdown.Search.Button, {Rotation = list and 180 or 0}, 0.3)

		if entries > 3 then
			for i, button in pairs(frame:GetChildren()) do
				if button:IsA("ImageButton") then
					button.Size = UDim2.new(1, -6, 0, 30)
				end
			end
			frame.CanvasSize = UDim2.new(0, 0, 0, (entries * 34) - 4)
			frame.ScrollBarImageTransparency = 0
		else
			frame.CanvasSize = UDim2.new(0, 0, 0, 0)
			frame.ScrollBarImageTransparency = 1
		end
	end
end

print("xev0r was here :)")

return library
