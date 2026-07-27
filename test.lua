-- XEVOR Library — Fixed + Watermark Keybind Dropdown
-- Bugs fixed:
--   • utilityInitializeKeybind / utilityBindToKey / utilityDraggingEnded: self → keybindState table (no longer nil)
--   • lastColor in AddColorPicker: implicit global → local per picker
--   • spawn() → task.spawn() throughout
--   • wait() → task.wait() in Toggle() to prevent tween desync
--   • Key system: CoreGui parent wrapped in pcall with playerGui fallback
--   • Watermark: keybind dropdown panel added (library.keybindLabels table)

-- init
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

-- services
local inputService = game:GetService("UserInputService")
local run = game:GetService("RunService")
local tweenService = game:GetService("TweenService")
local stats = game:GetService("Stats")
local tweeninfo = TweenInfo.new

-- FIX: keybind state lives in a plain table, not on global `self`
local keybindState = {
	keybinds = {},
	ended = {}
}

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

-- utility block
local utility = {}

do
	function utilityCreate(instance, properties, children)
		local object = Instance.new(instance)

		for i, v in pairs(properties or {}) do
			object[i] = v

			if typeof(v) == "Color3" then
				local theme = utilityFind(themes, v)

				if theme then
					objects[theme] = objects[theme] or {}
					objects[theme][i] = objects[theme][i] or setmetatable({}, {__mode = "k"})
					table.insert(objects[theme][i], object)
				end
			end
		end

		for _, module in pairs(children or {}) do
			module.Parent = object
		end

		return object
	end

	function utilityTween(instance, properties, duration, ...)
		tweenService:Create(instance, tweeninfo(duration, ...), properties):Play()
	end

	function utilityWait()
		run.RenderStepped:Wait()
		return true
	end

	function utilityFind(table, value)
		for i, v in pairs(table) do
			if v == value then
				return i
			end
		end
	end

	function utilitySort(pattern, values)
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

	function utilityPop(object, shrink)
		local clone = object:Clone()

		clone.AnchorPoint = Vector2.new(0.5, 0.5)
		clone.Size = clone.Size - UDim2.new(0, shrink, 0, shrink)
		clone.Position = UDim2.new(0.5, 0, 0.5, 0)

		clone.Parent = object
		clone:ClearAllChildren()

		object.ImageTransparency = 1
		utilityTween(clone, {Size = object.Size}, 0.2)

		-- FIX: spawn → task.spawn
		task.spawn(function()
			task.wait(0.2)
			object.ImageTransparency = 0
			clone:Destroy()
		end)

		return clone
	end

	-- FIX: all keybind functions now use keybindState table instead of global self
	function utilityInitializeKeybind()
		keybindState.keybinds = {}
		keybindState.ended = {}

		inputService.InputBegan:Connect(function(key)
			if keybindState.keybinds[key.KeyCode] then
				for _, bind in pairs(keybindState.keybinds[key.KeyCode]) do
					bind()
				end
			end
		end)

		inputService.InputEnded:Connect(function(key)
			if key.UserInputType == Enum.UserInputType.MouseButton1 then
				for _, callback in pairs(keybindState.ended) do
					callback()
				end
			end
		end)
	end

	function utilityBindToKey(key, callback)
		keybindState.keybinds[key] = keybindState.keybinds[key] or {}

		table.insert(keybindState.keybinds[key], callback)

		return {
			UnBind = function()
				for i, bind in pairs(keybindState.keybinds[key]) do
					if bind == callback then
						table.remove(keybindState.keybinds[key], i)
					end
				end
			end
		}
	end

	function utilityKeyPressed()
		local key = inputService.InputBegan:Wait()

		while key.UserInputType ~= Enum.UserInputType.Keyboard do
			key = inputService.InputBegan:Wait()
		end

		task.wait() -- overlapping connection
		return key
	end

	function utilityDraggingEnabled(frame, parent)
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

		inputService.InputChanged:Connect(function(userInput)
			if userInput == dragInput and dragging then
				local delta = userInput.Position - startPosition
				parent.Position = UDim2.new(
					parentPosition.X.Scale, parentPosition.X.Offset + delta.X,
					parentPosition.Y.Scale, parentPosition.Y.Offset + delta.Y
				)
			end
		end)
	end

	function utilityDraggingEnded(callback)
		table.insert(keybindState.ended, callback)
	end
end

-- classes

local library = {}
local page = {}
local section = {}

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

		self.toggleKeyConnection = inputService.InputBegan:Connect(function(userInput, gameProcessed)
			if gameProcessed or inputService:GetFocusedTextBox() then return end

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

		local glow        = watermarkFrame:FindFirstChild("Glow")
		local accentLine  = watermarkFrame:FindFirstChild("AccentLine")
		local topBar      = watermarkFrame:FindFirstChild("TopBar")
		local status      = watermarkFrame:FindFirstChild("Status")
		local titleLabel  = watermarkFrame:FindFirstChild("Title", true)
		local info        = watermarkFrame:FindFirstChild("Info", true)

		if style.Enabled ~= nil then self.watermark.Enabled = style.Enabled == true end
		if typeof(style.Position)     == "UDim2"    then watermarkFrame.Position    = style.Position    end
		if typeof(style.AnchorPoint)  == "Vector2"  then watermarkFrame.AnchorPoint = style.AnchorPoint end
		if typeof(style.Size)         == "UDim2"    then watermarkFrame.Size        = style.Size        end
		if tonumber(style.DisplayOrder)              then self.watermark.DisplayOrder = tonumber(style.DisplayOrder) end

		if typeof(style.BackgroundColor) == "Color3" then watermarkFrame.ImageColor3 = style.BackgroundColor end
		if topBar   and typeof(style.TopBarColor)  == "Color3" then topBar.ImageColor3  = style.TopBarColor  end
		if status   and typeof(style.StatusColor)  == "Color3" then status.ImageColor3  = style.StatusColor  end

		if glow then
			if style.Glow ~= nil then glow.Visible = style.Glow == true end
			if typeof(style.GlowColor) == "Color3"  then glow.ImageColor3 = style.GlowColor end
		end

		if accentLine then
			if style.AccentLine ~= nil then accentLine.Visible = style.AccentLine == true end
			if typeof(style.AccentColor) == "Color3" then accentLine.ImageColor3 = style.AccentColor end
		end

		if titleLabel then
			if typeof(style.TextColor)  == "Color3" then titleLabel.TextColor3 = style.TextColor  end
			if typeof(style.TitleColor) == "Color3" then titleLabel.TextColor3 = style.TitleColor end
			if tonumber(style.TitleTextSize) then
				titleLabel.TextSize = math.clamp(tonumber(style.TitleTextSize), 8, 32)
			end
		end

		if info then
			if typeof(style.TextColor) == "Color3" then info.TextColor3 = style.TextColor end
			if tonumber(style.TextSize) then
				info.TextSize = math.clamp(tonumber(style.TextSize), 8, 32)
			end
		end
	end

	function library:Destroy()
		if self.toggleKeyConnection  then self.toggleKeyConnection:Disconnect()  end
		if self.watermarkConnection  then self.watermarkConnection:Disconnect()   end
		if self.watermark            then self.watermark:Destroy()               end
		self.container:Destroy()
	end

	-- ─── library.new ─────────────────────────────────────────────────────────

	function library.new(title, options)
		options = options or {}

		local topbarHeight    = 38
		local navigationWidth = 126
		local contentLeft     = navigationWidth + 8
		local playerGui       = player:WaitForChild("PlayerGui")

		local watermarkOptions = type(options.Watermark) == "table" and options.Watermark or {}

		local watermarkEnabled      = watermarkOptions.Enabled ~= false
		local watermarkAnchor       = typeof(watermarkOptions.AnchorPoint)    == "Vector2" and watermarkOptions.AnchorPoint    or Vector2.new(1, 0)
		local watermarkPosition     = typeof(watermarkOptions.Position)       == "UDim2"   and watermarkOptions.Position       or UDim2.new(1, -16, 0, 16)
		local watermarkSize         = typeof(watermarkOptions.Size)           == "UDim2"   and watermarkOptions.Size           or UDim2.new(0, 390, 0, 58)
		local watermarkBackground   = typeof(watermarkOptions.BackgroundColor)== "Color3"  and watermarkOptions.BackgroundColor or themes.Background
		local watermarkTopBar       = typeof(watermarkOptions.TopBarColor)    == "Color3"  and watermarkOptions.TopBarColor    or themes.Accent
		local watermarkStatus       = typeof(watermarkOptions.StatusColor)    == "Color3"  and watermarkOptions.StatusColor    or themes.DarkContrast
		local watermarkGlow         = typeof(watermarkOptions.GlowColor)      == "Color3"  and watermarkOptions.GlowColor      or themes.Glow
		local watermarkAccent       = typeof(watermarkOptions.AccentColor)    == "Color3"  and watermarkOptions.AccentColor    or themes.LightContrast
		local watermarkText         = typeof(watermarkOptions.TextColor)      == "Color3"  and watermarkOptions.TextColor      or themes.TextColor
		local watermarkTextSize     = tonumber(watermarkOptions.TextSize)     or 13
		local watermarkTopbarHeight = math.clamp(tonumber(watermarkOptions.TopBarHeight) or 27, 22, 40)
		local watermarkShowGlow     = watermarkOptions.Glow ~= false
		local watermarkShowAccent   = watermarkOptions.AccentLine ~= false
		local watermarkDisplayOrder = tonumber(watermarkOptions.DisplayOrder) or 100

		local container = utilityCreate("ScreenGui", {
			Name             = title,
			Parent           = playerGui,
			IgnoreGuiInset   = true,
			ResetOnSpawn     = false,
			ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
		}, {
			utilityCreate("ImageLabel", {
				Name              = "Main",
				AnchorPoint       = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position          = UDim2.new(0.5, 0, 0.5, 0),
				Size              = UDim2.new(0, 511, 0, 428),
				Image             = "rbxassetid://4641149554",
				ImageColor3       = themes.Background,
				ScaleType         = Enum.ScaleType.Slice,
				SliceCenter       = Rect.new(4, 4, 296, 296)
			}, {
				utilityCreate("ImageLabel", {
					Name              = "Glow",
					BackgroundTransparency = 1,
					Position          = UDim2.new(0, -15, 0, -15),
					Size              = UDim2.new(1, 30, 1, 30),
					ZIndex            = 0,
					Image             = "rbxassetid://5028857084",
					ImageColor3       = themes.Glow,
					ScaleType         = Enum.ScaleType.Slice,
					SliceCenter       = Rect.new(24, 24, 276, 276)
				}),
				utilityCreate("ImageLabel", {
					Name              = "Pages",
					BackgroundTransparency = 1,
					ClipsDescendants  = true,
					Position          = UDim2.new(0, 0, 0, topbarHeight),
					Size              = UDim2.new(0, navigationWidth, 1, -topbarHeight),
					ZIndex            = 3,
					Image             = "rbxassetid://5012534273",
					ImageColor3       = themes.DarkContrast,
					ScaleType         = Enum.ScaleType.Slice,
					SliceCenter       = Rect.new(4, 4, 296, 296)
				}, {
					utilityCreate("ScrollingFrame", {
						Name                = "Pages_Container",
						Active              = true,
						BackgroundTransparency = 1,
						Position            = UDim2.new(0, 0, 0, 10),
						Size                = UDim2.new(1, 0, 1, -20),
						CanvasSize          = UDim2.new(0, 0, 0, 314),
						ScrollBarThickness  = 0
					}, {
						utilityCreate("UIListLayout", {
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding   = UDim.new(0, 10)
						})
					})
				}),
				utilityCreate("ImageLabel", {
					Name              = "TopBar",
					BackgroundTransparency = 1,
					ClipsDescendants  = true,
					Size              = UDim2.new(1, 0, 0, topbarHeight),
					ZIndex            = 5,
					Image             = "rbxassetid://4595286933",
					ImageColor3       = themes.Accent,
					ScaleType         = Enum.ScaleType.Slice,
					SliceCenter       = Rect.new(4, 4, 296, 296)
				}, {
					utilityCreate("TextLabel", {
						Name              = "Title",
						AnchorPoint       = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						Position          = UDim2.new(0, 12, 0.5, 0),
						Size              = UDim2.new(1, -94, 0, 16),
						ZIndex            = 5,
						Font              = Enum.Font.GothamBold,
						Text              = title,
						TextColor3        = themes.TextColor,
						TextSize          = 14,
						TextXAlignment    = Enum.TextXAlignment.Left
					}),
					utilityCreate("TextButton", {
						Name              = "Minimize",
						BackgroundTransparency = 1,
						Position          = UDim2.new(1, -62, 0, 0),
						Size              = UDim2.new(0, 30, 1, 0),
						ZIndex            = 6,
						Font              = Enum.Font.GothamBold,
						Text              = "-",
						TextColor3        = themes.TextColor,
						TextSize          = 20
					}),
					utilityCreate("TextButton", {
						Name              = "Close",
						BackgroundTransparency = 1,
						Position          = UDim2.new(1, -32, 0, 0),
						Size              = UDim2.new(0, 30, 1, 0),
						ZIndex            = 6,
						Font              = Enum.Font.GothamBold,
						Text              = "X",
						TextColor3        = themes.TextColor,
						TextSize          = 16
					})
				})
			})
		})

		-- ─── Watermark ScreenGui ─────────────────────────────────────────────
		local watermark = utilityCreate("ScreenGui", {
			Name           = title .. "_Watermark",
			Parent         = playerGui,
			Enabled        = watermarkEnabled,
			IgnoreGuiInset = true,
			ResetOnSpawn   = false,
			DisplayOrder   = watermarkDisplayOrder,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		}, {
			utilityCreate("ImageLabel", {
				Name              = "Watermark",
				AnchorPoint       = watermarkAnchor,
				BackgroundTransparency = 1,
				Position          = watermarkPosition,
				Size              = watermarkSize,
				ZIndex            = 2,
				Image             = "rbxassetid://4641149554",
				ImageColor3       = watermarkBackground,
				ScaleType         = Enum.ScaleType.Slice,
				SliceCenter       = Rect.new(4, 4, 296, 296)
			}, {
				utilityCreate("ImageLabel", {
					Name              = "Glow",
					BackgroundTransparency = 1,
					Position          = UDim2.new(0, -7, 0, -7),
					Size              = UDim2.new(1, 14, 1, 14),
					ZIndex            = 1,
					Visible           = watermarkShowGlow,
					Image             = "rbxassetid://5028857084",
					ImageColor3       = watermarkGlow,
					ScaleType         = Enum.ScaleType.Slice,
					SliceCenter       = Rect.new(24, 24, 276, 276)
				}),
				utilityCreate("ImageLabel", {
					Name              = "TopBar",
					BackgroundTransparency = 1,
					Position          = UDim2.new(0, 0, 0, 0),
					Size              = UDim2.new(1, 0, 0, watermarkTopbarHeight),
					ZIndex            = 3,
					Image             = "rbxassetid://4595286933",
					ImageColor3       = watermarkTopBar,
					ScaleType         = Enum.ScaleType.Slice,
					SliceCenter       = Rect.new(4, 4, 296, 296)
				}, {
					utilityCreate("TextLabel", {
						Name              = "Title",
						BackgroundTransparency = 1,
						Position          = UDim2.new(0, 14, 0, 0),
						Size              = UDim2.new(1, -28, 1, 0),
						ZIndex            = 4,
						Font              = Enum.Font.GothamBold,
						Text              = title,
						TextColor3        = watermarkText,
						TextSize          = watermarkTextSize + 1,
						TextTruncate      = Enum.TextTruncate.AtEnd,
						TextXAlignment    = Enum.TextXAlignment.Left
					})
				}),
				utilityCreate("ImageLabel", {
					Name              = "Status",
					BackgroundTransparency = 1,
					Position          = UDim2.new(0, 6, 0, watermarkTopbarHeight + 4),
					Size              = UDim2.new(1, -12, 1, -(watermarkTopbarHeight + 10)),
					ZIndex            = 3,
					Image             = "rbxassetid://5012534273",
					ImageColor3       = watermarkStatus,
					ScaleType         = Enum.ScaleType.Slice,
					SliceCenter       = Rect.new(4, 4, 296, 296)
				}, {
					utilityCreate("TextLabel", {
						Name              = "Info",
						BackgroundTransparency = 1,
						Position          = UDim2.new(0, 10, 0, 0),
						Size              = UDim2.new(1, -20, 1, 0),
						ZIndex            = 4,
						Font              = Enum.Font.GothamSemibold,
						Text              = player.Name .. " | -- FPS | -- ms",
						TextColor3        = watermarkText,
						TextSize          = watermarkTextSize,
						TextTruncate      = Enum.TextTruncate.AtEnd,
						TextXAlignment    = Enum.TextXAlignment.Left
					})
				}),
				utilityCreate("ImageLabel", {
					Name              = "AccentLine",
					BackgroundTransparency = 1,
					Position          = UDim2.new(0, 8, 0, watermarkTopbarHeight - 1),
					Size              = UDim2.new(1, -16, 0, 1),
					ZIndex            = 5,
					Visible           = watermarkShowAccent,
					Image             = "rbxassetid://4595286933",
					ImageColor3       = watermarkAccent,
					ScaleType         = Enum.ScaleType.Slice,
					SliceCenter       = Rect.new(4, 4, 296, 296)
				}),

				-- ─── Keybind Dropdown Panel ───────────────────────────────
				-- Sits below the watermark card, hidden by default.
				-- Populated dynamically from library.keybindLabels.
				-- Toggle by clicking the Status area.
				utilityCreate("ImageLabel", {
					Name              = "KeybindDropdown",
					BackgroundTransparency = 1,
					-- Anchored below the watermark card; grows downward.
					Position          = UDim2.new(0, 0, 1, 6),
					Size              = UDim2.new(1, 0, 0, 0), -- height set at runtime
					ZIndex            = 6,
					Visible           = false,
					Image             = "rbxassetid://5028857472",
					ImageColor3       = themes.DarkContrast,
					ScaleType         = Enum.ScaleType.Slice,
					SliceCenter       = Rect.new(4, 4, 296, 296),
					ClipsDescendants  = true
				}, {
					utilityCreate("TextLabel", {
						Name              = "Header",
						BackgroundTransparency = 1,
						Position          = UDim2.new(0, 10, 0, 6),
						Size              = UDim2.new(1, -20, 0, 14),
						ZIndex            = 7,
						Font              = Enum.Font.GothamBold,
						Text              = "KEYBINDS",
						TextColor3        = themes.TextColor,
						TextSize          = 10,
						TextXAlignment    = Enum.TextXAlignment.Left,
						TextTransparency  = 0.4
					}),
					utilityCreate("Frame", {
						Name              = "List",
						BackgroundTransparency = 1,
						Position          = UDim2.new(0, 0, 0, 26),
						Size              = UDim2.new(1, 0, 1, -26)
					}, {
						utilityCreate("UIListLayout", {
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding   = UDim.new(0, 2)
						}),
						utilityCreate("UIPadding", {
							PaddingLeft   = UDim.new(0, 10),
							PaddingRight  = UDim.new(0, 10),
							PaddingBottom = UDim.new(0, 6)
						})
					})
				})
			})
		})

		utilityInitializeKeybind()
		utilityDraggingEnabled(container.Main.TopBar, container.Main)

		local window = setmetatable({
			container       = container,
			pagesContainer  = container.Main.Pages.Pages_Container,
			pages           = {},
			watermark       = watermark,
			topbarHeight    = topbarHeight,
			navigationWidth = navigationWidth,
			contentLeft     = contentLeft,
			-- keybindLabels: array of {label = "Feature Name", key = Enum.KeyCode.X}
			-- Populate this from your main script when adding features.
			-- e.g. table.insert(Window.keybindLabels, {label = "Aimbot", key = Enum.KeyCode.E})
			keybindLabels   = {}
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
			watermark.Watermark.Status.Info.Text = string.format(
				"%s | %d FPS | %d ms", player.Name, fps, ping
			)
			frameCount = 0
			lastSample = now
		end)

		-- ─── Keybind dropdown toggle (click Status area) ──────────────────
		local keybindDropdownOpen = false

		local function refreshKeybindDropdown()
			local dropdown    = watermark.Watermark.KeybindDropdown
			local list        = dropdown.List
			local rowHeight   = 22
			local headerH     = 26

			-- Clear old rows
			for _, child in pairs(list:GetChildren()) do
				if child:IsA("Frame") then child:Destroy() end
			end

			local labels = window.keybindLabels
			local count  = #labels

			if count == 0 then
				-- "No bound keys" row
				local row = Instance.new("Frame")
				row.BackgroundTransparency = 1
				row.Size = UDim2.new(1, 0, 0, rowHeight)
				row.ZIndex = 7

				local lbl = Instance.new("TextLabel")
				lbl.BackgroundTransparency = 1
				lbl.Size = UDim2.fromScale(1, 1)
				lbl.ZIndex = 8
				lbl.Font = Enum.Font.Gotham
				lbl.Text = "No bound keys"
				lbl.TextColor3 = themes.TextColor
				lbl.TextTransparency = 0.55
				lbl.TextSize = 11
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Parent = row
				row.Parent = list
			else
				for _, entry in ipairs(labels) do
					local keyName = (entry.key and entry.key.Name) or "—"
					local featureName = entry.label or "Unknown"

					local row = Instance.new("Frame")
					row.BackgroundTransparency = 1
					row.Size = UDim2.new(1, 0, 0, rowHeight)
					row.ZIndex = 7

					local featureLbl = Instance.new("TextLabel")
					featureLbl.BackgroundTransparency = 1
					featureLbl.Position = UDim2.fromOffset(0, 0)
					featureLbl.Size = UDim2.new(0.65, 0, 1, 0)
					featureLbl.ZIndex = 8
					featureLbl.Font = Enum.Font.Gotham
					featureLbl.Text = featureName
					featureLbl.TextColor3 = themes.TextColor
					featureLbl.TextTransparency = 0.15
					featureLbl.TextSize = 11
					featureLbl.TextXAlignment = Enum.TextXAlignment.Left
					featureLbl.Parent = row

					local keyLbl = Instance.new("TextLabel")
					keyLbl.BackgroundTransparency = 1
					keyLbl.Position = UDim2.new(0.65, 0, 0, 0)
					keyLbl.Size = UDim2.new(0.35, 0, 1, 0)
					keyLbl.ZIndex = 8
					keyLbl.Font = Enum.Font.GothamSemibold
					keyLbl.Text = "[" .. keyName .. "]"
					keyLbl.TextColor3 = themes.TextColor
					keyLbl.TextTransparency = 0.4
					keyLbl.TextSize = 11
					keyLbl.TextXAlignment = Enum.TextXAlignment.Right
					keyLbl.Parent = row

					row.Parent = list
				end
			end

			-- Resize dropdown height to fit content
			local totalH = headerH + (math.max(count, 1) * (rowHeight + 2)) + 8
			dropdown.Size = UDim2.new(1, 0, 0, totalH)
		end

		watermark.Watermark.Status.InputBegan:Connect(function(userInput)
			if userInput.UserInputType == Enum.UserInputType.MouseButton1 then
				keybindDropdownOpen = not keybindDropdownOpen
				local dropdown = watermark.Watermark.KeybindDropdown

				if keybindDropdownOpen then
					refreshKeybindDropdown()
					dropdown.Visible = true
					dropdown.Size = UDim2.new(1, 0, 0, 0)
					-- animate open
					local targetH = dropdown.Size.Y.Offset
					refreshKeybindDropdown() -- sets real height
					local realH = dropdown.Size.Y.Offset
					dropdown.Size = UDim2.new(1, 0, 0, 0)
					utilityTween(dropdown, {Size = UDim2.new(1, 0, 0, realH)}, 0.18)
				else
					utilityTween(dropdown, {Size = UDim2.new(1, 0, 0, 0)}, 0.15)
					task.delay(0.15, function()
						dropdown.Visible = false
					end)
				end
			end
		end)

		-- Window chrome
		container.Main.TopBar.Minimize.MouseButton1Click:Connect(function()
			window:Toggle()
		end)
		container.Main.TopBar.Close.MouseButton1Click:Connect(function()
			window:Destroy()
		end)

		return window
	end

	-- ─── page.new ────────────────────────────────────────────────────────────

	function page.new(library, title, icon)
		local button = utilityCreate("TextButton", {
			Name              = title,
			Parent            = library.pagesContainer,
			BackgroundTransparency = 1,
			BorderSizePixel   = 0,
			Size              = UDim2.new(1, 0, 0, 26),
			ZIndex            = 3,
			AutoButtonColor   = false,
			Font              = Enum.Font.Gotham,
			Text              = "",
			TextSize          = 14
		}, {
			utilityCreate("TextLabel", {
				Name              = "Title",
				AnchorPoint       = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position          = UDim2.new(0, 40, 0.5, 0),
				Size              = UDim2.new(0, 76, 1, 0),
				ZIndex            = 3,
				Font              = Enum.Font.Gotham,
				Text              = title,
				TextColor3        = themes.TextColor,
				TextSize          = 12,
				TextTransparency  = 0.65,
				TextXAlignment    = Enum.TextXAlignment.Left
			}),
			icon and utilityCreate("ImageLabel", {
				Name              = "Icon",
				AnchorPoint       = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position          = UDim2.new(0, 12, 0.5, 0),
				Size              = UDim2.new(0, 16, 0, 16),
				ZIndex            = 3,
				Image             = "rbxassetid://" .. tostring(icon),
				ImageColor3       = themes.TextColor,
				ImageTransparency = 0.64,
				ScaleType         = Enum.ScaleType.Fit
			}) or {}
		})

		local container = utilityCreate("ScrollingFrame", {
			Name              = title,
			Parent            = library.container.Main,
			Active            = true,
			BackgroundTransparency = 1,
			BorderSizePixel   = 0,
			Position          = UDim2.new(0, library.contentLeft, 0, library.topbarHeight + 8),
			Size              = UDim2.new(1, -(library.contentLeft + 8), 1, -(library.topbarHeight + 18)),
			CanvasSize        = UDim2.new(0, 0, 0, 466),
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = themes.DarkContrast,
			Visible           = false
		}, {
			utilityCreate("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding   = UDim.new(0, 10)
			})
		})

		return setmetatable({
			library   = library,
			container = container,
			button    = button,
			sections  = {}
		}, page)
	end

	-- ─── section.new ─────────────────────────────────────────────────────────

	function section.new(page, title)
		local container = utilityCreate("ImageLabel", {
			Name              = title,
			Parent            = page.container,
			BackgroundTransparency = 1,
			Size              = UDim2.new(1, -10, 0, 28),
			ZIndex            = 2,
			Image             = "rbxassetid://5028857472",
			ImageColor3       = themes.LightContrast,
			ScaleType         = Enum.ScaleType.Slice,
			SliceCenter       = Rect.new(4, 4, 296, 296),
			ClipsDescendants  = true
		}, {
			utilityCreate("Frame", {
				Name              = "Container",
				Active            = true,
				BackgroundTransparency = 1,
				BorderSizePixel   = 0,
				Position          = UDim2.new(0, 8, 0, 8),
				Size              = UDim2.new(1, -16, 1, -16)
			}, {
				utilityCreate("TextLabel", {
					Name              = "Title",
					BackgroundTransparency = 1,
					Size              = UDim2.new(1, 0, 0, 20),
					ZIndex            = 2,
					Font              = Enum.Font.GothamSemibold,
					Text              = title,
					TextColor3        = themes.TextColor,
					TextSize          = 12,
					TextXAlignment    = Enum.TextXAlignment.Left,
					TextTransparency  = 1
				}),
				utilityCreate("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding   = UDim.new(0, 4)
				})
			})
		})

		return setmetatable({
			page         = page,
			container    = container.Container,
			colorpickers = {},
			modules      = {},
			binds        = {},
			lists        = {}
		}, section)
	end

	-- ─── AddPage / AddSection ────────────────────────────────────────────────

	function library:AddPage(...)
		local newPage = page.new(self, ...)
		local button  = newPage.button

		table.insert(self.pages, newPage)

		button.MouseButton1Click:Connect(function()
			self:SelectPage(newPage, true)
		end)

		return newPage
	end

	function page:AddSection(...)
		local newSection = section.new(self, ...)
		table.insert(self.sections, newSection)
		return newSection
	end

	-- ─── SetTheme ────────────────────────────────────────────────────────────

	function library:SetTheme(theme, color3)
		themes[theme] = color3

		for property, objectList in pairs(objects[theme] or {}) do
			for i, object in pairs(objectList) do
				if not object.Parent or (object.Name == "Button" and object.Parent.Name == "ColorPicker") then
					objectList[i] = nil
				else
					object[property] = color3
				end
			end
		end
	end

	-- ─── Toggle (minimize/expand) ─────────────────────────────────────────
	-- FIX: wait() → task.wait() to avoid deprecated scheduler and tween desync

	function library:Toggle()
		if self.toggling then return end

		self.toggling = true

		local cont   = self.container.Main
		local topbar = cont.TopBar

		if self.minimized then
			local expandedSize = self.expandedSize
			local yOffset = (expandedSize.Y.Offset - self.topbarHeight) / 2

			utilityTween(cont, {
				Size     = expandedSize,
				Position = cont.Position - UDim2.fromOffset(0, yOffset)
			}, 0.2)
			task.wait(0.2)

			utilityTween(topbar, {Size = UDim2.new(1, 0, 0, self.topbarHeight)}, 0.15)
			cont.ClipsDescendants = false
			self.minimized = false
		else
			self.expandedSize = cont.Size
			local yOffset = (self.expandedSize.Y.Offset - self.topbarHeight) / 2

			cont.ClipsDescendants = true
			utilityTween(topbar, {Size = UDim2.new(1, 0, 1, 0)}, 0.15)
			task.wait(0.15)

			utilityTween(cont, {
				Size     = UDim2.fromOffset(self.expandedSize.X.Offset, self.topbarHeight),
				Position = cont.Position + UDim2.fromOffset(0, yOffset)
			}, 0.2)
			self.minimized = true
		end

		self.toggling = false
	end

	-- ─── Notify ──────────────────────────────────────────────────────────────

	function library:Notify(title, text, callback)
		if self.activeNotification then
			self.activeNotification = self.activeNotification()
		end

		local notification = utilityCreate("ImageLabel", {
			Name              = "Notification",
			Parent            = self.container,
			BackgroundTransparency = 1,
			Size              = UDim2.new(0, 200, 0, 60),
			Image             = "rbxassetid://5028857472",
			ImageColor3       = themes.Background,
			ScaleType         = Enum.ScaleType.Slice,
			SliceCenter       = Rect.new(4, 4, 296, 296),
			ZIndex            = 3,
			ClipsDescendants  = true
		}, {
			utilityCreate("ImageLabel", {
				Name              = "Flash",
				Size              = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Image             = "rbxassetid://4641149554",
				ImageColor3       = themes.TextColor,
				ZIndex            = 5
			}),
			utilityCreate("ImageLabel", {
				Name              = "Glow",
				BackgroundTransparency = 1,
				Position          = UDim2.new(0, -15, 0, -15),
				Size              = UDim2.new(1, 30, 1, 30),
				ZIndex            = 2,
				Image             = "rbxassetid://5028857084",
				ImageColor3       = themes.Glow,
				ScaleType         = Enum.ScaleType.Slice,
				SliceCenter       = Rect.new(24, 24, 276, 276)
			}),
			utilityCreate("TextLabel", {
				Name              = "Title",
				BackgroundTransparency = 1,
				Position          = UDim2.new(0, 10, 0, 8),
				Size              = UDim2.new(1, -40, 0, 16),
				ZIndex            = 4,
				Font              = Enum.Font.GothamSemibold,
				TextColor3        = themes.TextColor,
				TextSize          = 14,
				TextXAlignment    = Enum.TextXAlignment.Left
			}),
			utilityCreate("TextLabel", {
				Name              = "Text",
				BackgroundTransparency = 1,
				Position          = UDim2.new(0, 10, 1, -24),
				Size              = UDim2.new(1, -40, 0, 16),
				ZIndex            = 4,
				Font              = Enum.Font.Gotham,
				TextColor3        = themes.TextColor,
				TextSize          = 12,
				TextXAlignment    = Enum.TextXAlignment.Left
			}),
			utilityCreate("ImageButton", {
				Name              = "Accept",
				BackgroundTransparency = 1,
				Position          = UDim2.new(1, -26, 0, 8),
				Size              = UDim2.new(0, 16, 0, 16),
				Image             = "rbxassetid://5012538259",
				ImageColor3       = themes.TextColor,
				ZIndex            = 4
			}),
			utilityCreate("ImageButton", {
				Name              = "Decline",
				BackgroundTransparency = 1,
				Position          = UDim2.new(1, -26, 1, -24),
				Size              = UDim2.new(0, 16, 0, 16),
				Image             = "rbxassetid://5012538583",
				ImageColor3       = themes.TextColor,
				ZIndex            = 4
			})
		})

		utilityDraggingEnabled(notification)

		title = title or "Notification"
		text  = text  or ""

		notification.Title.Text = title
		notification.Text.Text  = text

		local padding  = 10
		local textSize = game:GetService("TextService"):GetTextSize(
			text, 12, Enum.Font.Gotham, Vector2.new(math.huge, 16)
		)

		notification.Position = self.lastNotification or UDim2.new(0, padding, 1, -(notification.AbsoluteSize.Y + padding))
		notification.Size = UDim2.new(0, 0, 0, 60)

		utilityTween(notification, {Size = UDim2.new(0, textSize.X + 70, 0, 60)}, 0.2)
		task.wait(0.2)

		notification.ClipsDescendants = false
		utilityTween(notification.Flash, {
			Size     = UDim2.new(0, 0, 0, 60),
			Position = UDim2.new(1, 0, 0, 0)
		}, 0.2)

		local active = true
		local close = function()
			if not active then return end

			active = false
			notification.ClipsDescendants = true

			self.lastNotification = notification.Position
			notification.Flash.Position = UDim2.new(0, 0, 0, 0)
			utilityTween(notification.Flash, {Size = UDim2.new(1, 0, 1, 0)}, 0.2)

			task.wait(0.2)
			utilityTween(notification, {
				Size     = UDim2.new(0, 0, 0, 60),
				Position = notification.Position + UDim2.new(0, textSize.X + 70, 0, 0)
			}, 0.2)

			task.wait(0.2)
			notification:Destroy()
		end

		self.activeNotification = close

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

	-- ─── Section modules ──────────────────────────────────────────────────────

	function section:AddButton(title, callback)
		local button = utilityCreate("ImageButton", {
			Name              = "Button",
			Parent            = self.container,
			BackgroundTransparency = 1,
			BorderSizePixel   = 0,
			Size              = UDim2.new(1, 0, 0, 30),
			ZIndex            = 2,
			Image             = "rbxassetid://5028857472",
			ImageColor3       = themes.DarkContrast,
			ScaleType         = Enum.ScaleType.Slice,
			SliceCenter       = Rect.new(2, 2, 298, 298)
		}, {
			utilityCreate("TextLabel", {
				Name              = "Title",
				BackgroundTransparency = 1,
				Size              = UDim2.new(1, 0, 1, 0),
				ZIndex            = 3,
				Font              = Enum.Font.Gotham,
				Text              = title,
				TextColor3        = themes.TextColor,
				TextSize          = 12,
				TextTransparency  = 0.10000000149012
			})
		})

		table.insert(self.modules, button)

		local text     = button.Title
		local debounce

		button.MouseButton1Click:Connect(function()
			if debounce then return end

			utilityPop(button, 10)

			debounce = true
			text.TextSize = 0
			utilityTween(button.Title, {TextSize = 14}, 0.2)

			task.wait(0.2)
			utilityTween(button.Title, {TextSize = 12}, 0.2)

			if callback then
				callback(function(...)
					self:UpdateButton(button, ...)
				end)
			end

			debounce = false
		end)

		return button
	end

	function section:AddToggle(title, default, callback)
		local toggle = utilityCreate("ImageButton", {
			Name              = "Toggle",
			Parent            = self.container,
			BackgroundTransparency = 1,
			BorderSizePixel   = 0,
			Size              = UDim2.new(1, 0, 0, 30),
			ZIndex            = 2,
			Image             = "rbxassetid://5028857472",
			ImageColor3       = themes.DarkContrast,
			ScaleType         = Enum.ScaleType.Slice,
			SliceCenter       = Rect.new(2, 2, 298, 298)
		}, {
			utilityCreate("TextLabel", {
				Name              = "Title",
				AnchorPoint       = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position          = UDim2.new(0, 10, 0.5, 1),
				Size              = UDim2.new(0.5, 0, 1, 0),
				ZIndex            = 3,
				Font              = Enum.Font.Gotham,
				Text              = title,
				TextColor3        = themes.TextColor,
				TextSize          = 12,
				TextTransparency  = 0.10000000149012,
				TextXAlignment    = Enum.TextXAlignment.Left
			}),
			utilityCreate("ImageLabel", {
				Name              = "Button",
				BackgroundTransparency = 1,
				BorderSizePixel   = 0,
				Position          = UDim2.new(1, -50, 0.5, -8),
				Size              = UDim2.new(0, 40, 0, 16),
				ZIndex            = 2,
				Image             = "rbxassetid://5028857472",
				ImageColor3       = themes.LightContrast,
				ScaleType         = Enum.ScaleType.Slice,
				SliceCenter       = Rect.new(2, 2, 298, 298)
			}, {
				utilityCreate("ImageLabel", {
					Name              = "Frame",
					BackgroundTransparency = 1,
					Position          = UDim2.new(0, 2, 0.5, -6),
					Size              = UDim2.new(1, -22, 1, -4),
					ZIndex            = 2,
					Image             = "rbxassetid://5028857472",
					ImageColor3       = themes.TextColor,
					ScaleType         = Enum.ScaleType.Slice,
					SliceCenter       = Rect.new(2, 2, 298, 298)
				})
			})
		})

		table.insert(self.modules, toggle)

		local active = default
		self:UpdateToggle(toggle, nil, active)

		toggle.MouseButton1Click:Connect(function()
			active = not active
			self:UpdateToggle(toggle, nil, active)

			if callback then
				callback(active, function(...)
					self:UpdateToggle(toggle, ...)
				end)
			end
		end)

		return toggle
	end

	function section:AddTextbox(title, default, callback)
		local textbox = utilityCreate("ImageButton", {
			Name              = "Textbox",
			Parent            = self.container,
			BackgroundTransparency = 1,
			BorderSizePixel   = 0,
			Size              = UDim2.new(1, 0, 0, 30),
			ZIndex            = 2,
			Image             = "rbxassetid://5028857472",
			ImageColor3       = themes.DarkContrast,
			ScaleType         = Enum.ScaleType.Slice,
			SliceCenter       = Rect.new(2, 2, 298, 298)
		}, {
			utilityCreate("TextLabel", {
				Name              = "Title",
				AnchorPoint       = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position          = UDim2.new(0, 10, 0.5, 1),
				Size              = UDim2.new(0.5, 0, 1, 0),
				ZIndex            = 3,
				Font              = Enum.Font.Gotham,
				Text              = title,
				TextColor3        = themes.TextColor,
				TextSize          = 12,
				TextTransparency  = 0.10000000149012,
				TextXAlignment    = Enum.TextXAlignment.Left
			}),
			utilityCreate("ImageLabel", {
				Name              = "Button",
				BackgroundTransparency = 1,
				Position          = UDim2.new(1, -110, 0.5, -8),
				Size              = UDim2.new(0, 100, 0, 16),
				ZIndex            = 2,
				Image             = "rbxassetid://5028857472",
				ImageColor3       = themes.LightContrast,
				ScaleType         = Enum.ScaleType.Slice,
				SliceCenter       = Rect.new(2, 2, 298, 298)
			}, {
				utilityCreate("TextBox", {
					Name              = "Textbox",
					BackgroundTransparency = 1,
					TextTruncate      = Enum.TextTruncate.AtEnd,
					Position          = UDim2.new(0, 5, 0, 0),
					Size              = UDim2.new(1, -10, 1, 0),
					ZIndex            = 3,
					Font              = Enum.Font.GothamSemibold,
					Text              = default or "",
					TextColor3        = themes.TextColor,
					TextSize          = 11
				})
			})
		})

		table.insert(self.modules, textbox)

		local inputBox = textbox.Button.Textbox

		textbox.MouseButton1Click:Connect(function()
			if textbox.Button.Size ~= UDim2.new(0, 100, 0, 16) then return end

			utilityTween(textbox.Button, {
				Size     = UDim2.new(0, 200, 0, 16),
				Position = UDim2.new(1, -210, 0.5, -8)
			}, 0.2)

			task.wait()
			inputBox.TextXAlignment = Enum.TextXAlignment.Left
			inputBox:CaptureFocus()
		end)

		inputBox:GetPropertyChangedSignal("Text"):Connect(function()
			if textbox.Button.ImageTransparency == 0
				and (textbox.Button.Size == UDim2.new(0, 200, 0, 16)
				  or textbox.Button.Size == UDim2.new(0, 100, 0, 16)) then
				utilityPop(textbox.Button, 10)
			end

			if callback then
				callback(inputBox.Text, nil, function(...)
					self:UpdateTextbox(textbox, ...)
				end)
			end
		end)

		inputBox.FocusLost:Connect(function()
			inputBox.TextXAlignment = Enum.TextXAlignment.Center

			utilityTween(textbox.Button, {
				Size     = UDim2.new(0, 100, 0, 16),
				Position = UDim2.new(1, -110, 0.5, -8)
			}, 0.2)

			if callback then
				callback(inputBox.Text, true, function(...)
					self:UpdateTextbox(textbox, ...)
				end)
			end
		end)

		return textbox
	end

	function section:AddKeybind(title, default, callback, changedCallback)
		local keybind = utilityCreate("ImageButton", {
			Name              = "Keybind",
			Parent            = self.container,
			BackgroundTransparency = 1,
			BorderSizePixel   = 0,
			Size              = UDim2.new(1, 0, 0, 30),
			ZIndex            = 2,
			Image             = "rbxassetid://5028857472",
			ImageColor3       = themes.DarkContrast,
			ScaleType         = Enum.ScaleType.Slice,
			SliceCenter       = Rect.new(2, 2, 298, 298)
		}, {
			utilityCreate("TextLabel", {
				Name              = "Title",
				AnchorPoint       = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position          = UDim2.new(0, 10, 0.5, 1),
				Size              = UDim2.new(1, 0, 1, 0),
				ZIndex            = 3,
				Font              = Enum.Font.Gotham,
				Text              = title,
				TextColor3        = themes.TextColor,
				TextSize          = 12,
				TextTransparency  = 0.10000000149012,
				TextXAlignment    = Enum.TextXAlignment.Left
			}),
			utilityCreate("ImageLabel", {
				Name              = "Button",
				BackgroundTransparency = 1,
				Position          = UDim2.new(1, -110, 0.5, -8),
				Size              = UDim2.new(0, 100, 0, 16),
				ZIndex            = 2,
				Image             = "rbxassetid://5028857472",
				ImageColor3       = themes.LightContrast,
				ScaleType         = Enum.ScaleType.Slice,
				SliceCenter       = Rect.new(2, 2, 298, 298)
			}, {
				utilityCreate("TextLabel", {
					Name              = "Text",
					BackgroundTransparency = 1,
					ClipsDescendants  = true,
					Size              = UDim2.new(1, 0, 1, 0),
					ZIndex            = 3,
					Font              = Enum.Font.GothamSemibold,
					Text              = default and default.Name or "None",
					TextColor3        = themes.TextColor,
					TextSize          = 11
				})
			})
		})

		table.insert(self.modules, keybind)

		local text   = keybind.Button.Text
		local button = keybind.Button

		local animate = function()
			if button.ImageTransparency == 0 then
				utilityPop(button, 10)
			end
		end

		self.binds[keybind] = {callback = function()
			animate()
			if callback then
				callback(function(...)
					self:UpdateKeybind(keybind, ...)
				end)
			end
		end}

		if default and callback then
			self:UpdateKeybind(keybind, nil, default)
		end

		keybind.MouseButton1Click:Connect(function()
			animate()

			if self.binds[keybind].connection then
				return self:UpdateKeybind(keybind)
			end

			if text.Text == "None" then
				text.Text = "..."

				local key = utilityKeyPressed()

				self:UpdateKeybind(keybind, nil, key.KeyCode)
				animate()

				if changedCallback then
					changedCallback(key, function(...)
						self:UpdateKeybind(keybind, ...)
					end)
				end
			end
		end)

		return keybind
	end

	function section:AddColorPicker(title, default, callback)
		local colorpicker = utilityCreate("ImageButton", {
			Name              = "ColorPicker",
			Parent            = self.container,
			BackgroundTransparency = 1,
			BorderSizePixel   = 0,
			Size              = UDim2.new(1, 0, 0, 30),
			ZIndex            = 2,
			Image             = "rbxassetid://5028857472",
			ImageColor3       = themes.DarkContrast,
			ScaleType         = Enum.ScaleType.Slice,
			SliceCenter       = Rect.new(2, 2, 298, 298)
		}, {
			utilityCreate("TextLabel", {
				Name              = "Title",
				AnchorPoint       = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position          = UDim2.new(0, 10, 0.5, 1),
				Size              = UDim2.new(0.5, 0, 1, 0),
				ZIndex            = 3,
				Font              = Enum.Font.Gotham,
				Text              = title,
				TextColor3        = themes.TextColor,
				TextSize          = 12,
				TextTransparency  = 0.10000000149012,
				TextXAlignment    = Enum.TextXAlignment.Left
			}),
			utilityCreate("ImageButton", {
				Name              = "Button",
				BackgroundTransparency = 1,
				BorderSizePixel   = 0,
				Position          = UDim2.new(1, -50, 0.5, -7),
				Size              = UDim2.new(0, 40, 0, 14),
				ZIndex            = 2,
				Image             = "rbxassetid://5028857472",
				ImageColor3       = Color3.fromRGB(255, 255, 255),
				ScaleType         = Enum.ScaleType.Slice,
				SliceCenter       = Rect.new(2, 2, 298, 298)
			})
		})

		local tab = utilityCreate("ImageLabel", {
			Name              = "ColorPicker",
			Parent            = self.page.library.container,
			BackgroundTransparency = 1,
			Position          = UDim2.new(0.75, 0, 0.4, 0),
			Selectable        = true,
			AnchorPoint       = Vector2.new(0.5, 0.5),
			Size              = UDim2.new(0, 162, 0, 169),
			Image             = "rbxassetid://5028857472",
			ImageColor3       = themes.Background,
			ScaleType         = Enum.ScaleType.Slice,
			SliceCenter       = Rect.new(2, 2, 298, 298),
			Visible           = false
		}, {
			utilityCreate("ImageLabel", {
				Name              = "Glow",
				BackgroundTransparency = 1,
				Position          = UDim2.new(0, -15, 0, -15),
				Size              = UDim2.new(1, 30, 1, 30),
				ZIndex            = 0,
				Image             = "rbxassetid://5028857084",
				ImageColor3       = themes.Glow,
				ScaleType         = Enum.ScaleType.Slice,
				SliceCenter       = Rect.new(22, 22, 278, 278)
			}),
			utilityCreate("TextLabel", {
				Name              = "Title",
				BackgroundTransparency = 1,
				Position          = UDim2.new(0, 10, 0, 8),
				Size              = UDim2.new(1, -40, 0, 16),
				ZIndex            = 2,
				Font              = Enum.Font.GothamSemibold,
				Text              = title,
				TextColor3        = themes.TextColor,
				TextSize          = 14,
				TextXAlignment    = Enum.TextXAlignment.Left
			}),
			utilityCreate("ImageButton", {
				Name              = "Close",
				BackgroundTransparency = 1,
				Position          = UDim2.new(1, -26, 0, 8),
				Size              = UDim2.new(0, 16, 0, 16),
				ZIndex            = 2,
				Image             = "rbxassetid://5012538583",
				ImageColor3       = themes.TextColor
			}),
			utilityCreate("Frame", {
				Name              = "Container",
				BackgroundTransparency = 1,
				Position          = UDim2.new(0, 8, 0, 32),
				Size              = UDim2.new(1, -18, 1, -40)
			}, {
				utilityCreate("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding   = UDim.new(0, 6)
				}),
				utilityCreate("ImageButton", {
					Name              = "Canvas",
					BackgroundTransparency = 1,
					BorderColor3      = themes.LightContrast,
					Size              = UDim2.new(1, 0, 0, 60),
					AutoButtonColor   = false,
					Image             = "rbxassetid://5108535320",
					ImageColor3       = Color3.fromRGB(255, 0, 0),
					ScaleType         = Enum.ScaleType.Slice,
					SliceCenter       = Rect.new(2, 2, 298, 298)
				}, {
					utilityCreate("ImageLabel", {
						Name              = "White_Overlay",
						BackgroundTransparency = 1,
						Size              = UDim2.new(1, 0, 0, 60),
						Image             = "rbxassetid://5107152351",
						SliceCenter       = Rect.new(2, 2, 298, 298)
					}),
					utilityCreate("ImageLabel", {
						Name              = "Black_Overlay",
						BackgroundTransparency = 1,
						Size              = UDim2.new(1, 0, 0, 60),
						Image             = "rbxassetid://5107152095",
						SliceCenter       = Rect.new(2, 2, 298, 298)
					}),
					utilityCreate("ImageLabel", {
						Name              = "Cursor",
						BackgroundColor3  = themes.TextColor,
						AnchorPoint       = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Size              = UDim2.new(0, 10, 0, 10),
						Position          = UDim2.new(0, 0, 0, 0),
						Image             = "rbxassetid://5100115962",
						SliceCenter       = Rect.new(2, 2, 298, 298)
					})
				}),
				utilityCreate("ImageButton", {
					Name              = "Color",
					BackgroundTransparency = 1,
					BorderSizePixel   = 0,
					Position          = UDim2.new(0, 0, 0, 4),
					Selectable        = false,
					Size              = UDim2.new(1, 0, 0, 16),
					ZIndex            = 2,
					AutoButtonColor   = false,
					Image             = "rbxassetid://5028857472",
					ScaleType         = Enum.ScaleType.Slice,
					SliceCenter       = Rect.new(2, 2, 298, 298)
				}, {
					utilityCreate("Frame", {
						Name              = "Select",
						BackgroundColor3  = themes.TextColor,
						BorderSizePixel   = 1,
						Position          = UDim2.new(1, 0, 0, 0),
						Size              = UDim2.new(0, 2, 1, 0),
						ZIndex            = 2
					}),
					utilityCreate("UIGradient", {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0,   0)),
							ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
							ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,   255, 0)),
							ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0,   255, 255)),
							ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0,   0,   255)),
							ColorSequenceKeypoint.new(0.82, Color3.fromRGB(255, 0,   255)),
							ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0,   0))
						})
					})
				}),
				utilityCreate("Frame", {
					Name              = "Inputs",
					BackgroundTransparency = 1,
					Position          = UDim2.new(0, 10, 0, 158),
					Size              = UDim2.new(1, 0, 0, 16)
				}, {
					utilityCreate("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder     = Enum.SortOrder.LayoutOrder,
						Padding       = UDim.new(0, 6)
					}),
					-- R / G / B inputs (identical pattern, one each)
					utilityCreate("ImageLabel", {Name = "R", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(0.305, 0, 1, 0), ZIndex = 2, Image = "rbxassetid://5028857472", ImageColor3 = themes.DarkContrast, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(2,2,298,298)}, {
						utilityCreate("TextLabel", {Name="Text", BackgroundTransparency=1, Size=UDim2.new(0.4,0,1,0), ZIndex=2, Font=Enum.Font.Gotham, Text="R", TextColor3=themes.TextColor, TextSize=10}),
						utilityCreate("TextBox",  {Name="Textbox", BackgroundTransparency=1, Position=UDim2.new(0.3,0,0,0), Size=UDim2.new(0.6,0,1,0), ZIndex=2, Font=Enum.Font.Gotham, PlaceholderColor3=themes.DarkContrast, Text="255", TextColor3=themes.TextColor, TextSize=10})
					}),
					utilityCreate("ImageLabel", {Name = "G", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(0.305, 0, 1, 0), ZIndex = 2, Image = "rbxassetid://5028857472", ImageColor3 = themes.DarkContrast, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(2,2,298,298)}, {
						utilityCreate("TextLabel", {Name="Text", BackgroundTransparency=1, ZIndex=2, Size=UDim2.new(0.4,0,1,0), Font=Enum.Font.Gotham, Text="G", TextColor3=themes.TextColor, TextSize=10}),
						utilityCreate("TextBox",  {Name="Textbox", BackgroundTransparency=1, Position=UDim2.new(0.3,0,0,0), Size=UDim2.new(0.6,0,1,0), ZIndex=2, Font=Enum.Font.Gotham, Text="255", TextColor3=themes.TextColor, TextSize=10})
					}),
					utilityCreate("ImageLabel", {Name = "B", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(0.305, 0, 1, 0), ZIndex = 2, Image = "rbxassetid://5028857472", ImageColor3 = themes.DarkContrast, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(2,2,298,298)}, {
						utilityCreate("TextLabel", {Name="Text", BackgroundTransparency=1, Size=UDim2.new(0.4,0,1,0), ZIndex=2, Font=Enum.Font.Gotham, Text="B", TextColor3=themes.TextColor, TextSize=10}),
						utilityCreate("TextBox",  {Name="Textbox", BackgroundTransparency=1, Position=UDim2.new(0.3,0,0,0), Size=UDim2.new(0.6,0,1,0), ZIndex=2, Font=Enum.Font.Gotham, Text="255", TextColor3=themes.TextColor, TextSize=10})
					})
				}),
				utilityCreate("ImageButton", {
					Name              = "Button",
					BackgroundTransparency = 1,
					BorderSizePixel   = 0,
					Size              = UDim2.new(1, 0, 0, 20),
					ZIndex            = 2,
					Image             = "rbxassetid://5028857472",
					ImageColor3       = themes.DarkContrast,
					ScaleType         = Enum.ScaleType.Slice,
					SliceCenter       = Rect.new(2, 2, 298, 298)
				}, {
					utilityCreate("TextLabel", {
						Name              = "Text",
						BackgroundTransparency = 1,
						Size              = UDim2.new(1, 0, 1, 0),
						ZIndex            = 3,
						Font              = Enum.Font.Gotham,
						Text              = "Submit",
						TextColor3        = themes.TextColor,
						TextSize          = 11
					})
				})
			})
		})

		utilityDraggingEnabled(tab)
		table.insert(self.modules, colorpicker)

		local allowed = {["."] = true}

		local canvas = tab.Container.Canvas
		local color  = tab.Container.Color

		local canvasSize, canvasPosition = canvas.AbsoluteSize, canvas.AbsolutePosition
		local colorSize,  colorPosition  = color.AbsoluteSize,  color.AbsolutePosition

		local draggingColor, draggingCanvas

		-- FIX: lastColor is now local per picker, not an implicit global
		local lastColor = Color3.fromRGB(255, 255, 255)
		local color3    = default or Color3.fromRGB(255, 255, 255)
		local hue, sat, brightness = 0, 0, 1
		local rgb = {r = 255, g = 255, b = 255}

		self.colorpickers[colorpicker] = {
			tab = tab,
			callback = function(prop, value)
				rgb[prop] = value
				hue, sat, brightness = Color3.toHSV(Color3.fromRGB(rgb.r, rgb.g, rgb.b))
			end
		}

		local fireCallback = function(value)
			if callback then
				callback(value, function(...)
					self:UpdateColorPicker(colorpicker, ...)
				end)
			end
		end

		utilityDraggingEnded(function()
			draggingColor, draggingCanvas = false, false
		end)

		if default then
			self:UpdateColorPicker(colorpicker, nil, default)
			hue, sat, brightness = Color3.toHSV(default)
			default = Color3.fromHSV(hue, sat, brightness)
			for _, prop in pairs({"r", "g", "b"}) do
				rgb[prop] = default[prop:upper()] * 255
			end
		end

		for _, cont in pairs(tab.Container.Inputs:GetChildren()) do
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
					local t = textbox.Text
					if not allowed[t] and not tonumber(t) then
						textbox.Text = t:sub(1, #t - 1)
					elseif focused and not allowed[t] then
						rgb[cont.Name:lower()] = math.clamp(tonumber(textbox.Text), 0, 255)
						local c3 = Color3.fromRGB(rgb.r, rgb.g, rgb.b)
						hue, sat, brightness = Color3.toHSV(c3)
						self:UpdateColorPicker(colorpicker, nil, c3)
						fireCallback(c3)
					end
				end)
			end
		end

		canvas.MouseButton1Down:Connect(function()
			draggingCanvas = true

			while draggingCanvas do
				local x, y = mouse.X, mouse.Y
				sat        = math.clamp((x - canvasPosition.X) / canvasSize.X, 0, 1)
				brightness = 1 - math.clamp((y - canvasPosition.Y) / canvasSize.Y, 0, 1)
				color3     = Color3.fromHSV(hue, sat, brightness)

				for _, prop in pairs({"r", "g", "b"}) do
					rgb[prop] = color3[prop:upper()] * 255
				end

				self:UpdateColorPicker(colorpicker, nil, {hue, sat, brightness})
				utilityTween(canvas.Cursor, {Position = UDim2.new(sat, 0, 1 - brightness, 0)}, 0.1)
				fireCallback(color3)
				utilityWait()
			end
		end)

		color.MouseButton1Down:Connect(function()
			draggingColor = true

			while draggingColor do
				hue    = 1 - math.clamp(1 - ((mouse.X - colorPosition.X) / colorSize.X), 0, 1)
				color3 = Color3.fromHSV(hue, sat, brightness)

				for _, prop in pairs({"r", "g", "b"}) do
					rgb[prop] = color3[prop:upper()] * 255
				end

				self:UpdateColorPicker(colorpicker, nil, {hue, sat, brightness})
				utilityTween(tab.Container.Color.Select, {Position = UDim2.new(hue, 0, 0, 0)}, 0.1)
				fireCallback(color3)
				utilityWait()
			end
		end)

		local button = colorpicker.Button
		local toggle, debounce, animate

		animate = function(visible, overwrite)
			if overwrite then
				if not toggle then return end
				if debounce then
					while debounce do utilityWait() end
				end
			else
				if debounce then return end
				if button.ImageTransparency == 0 then
					utilityPop(button, 10)
				end
			end

			toggle  = visible
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
				utilityTween(tab, {Size = UDim2.new(0, 162, 0, 169)}, 0.2)

				task.wait(0.2)
				tab.ClipsDescendants = false
				canvasSize, canvasPosition = canvas.AbsoluteSize, canvas.AbsolutePosition
				colorSize,  colorPosition  = color.AbsoluteSize,  color.AbsolutePosition
			else
				utilityTween(tab, {Size = UDim2.new(0, 0, 0, 0)}, 0.2)
				tab.ClipsDescendants = true
				task.wait(0.2)
				tab.Visible = false
			end

			debounce = false
		end

		local toggleTab = function() animate(not toggle) end

		button.MouseButton1Click:Connect(toggleTab)
		colorpicker.MouseButton1Click:Connect(toggleTab)

		tab.Container.Button.MouseButton1Click:Connect(function() animate() end)

		tab.Close.MouseButton1Click:Connect(function()
			self:UpdateColorPicker(colorpicker, nil, lastColor)
			animate()
		end)

		return colorpicker
	end

	function section:AddSlider(title, default, min, max, callback)
		local slider = utilityCreate("ImageButton", {
			Name              = "Slider",
			Parent            = self.container,
			BackgroundTransparency = 1,
			BorderSizePixel   = 0,
			Position          = UDim2.new(0.292817682, 0, 0.299145311, 0),
			Size              = UDim2.new(1, 0, 0, 50),
			ZIndex            = 2,
			Image             = "rbxassetid://5028857472",
			ImageColor3       = themes.DarkContrast,
			ScaleType         = Enum.ScaleType.Slice,
			SliceCenter       = Rect.new(2, 2, 298, 298)
		}, {
			utilityCreate("TextLabel", {
				Name              = "Title",
				BackgroundTransparency = 1,
				Position          = UDim2.new(0, 10, 0, 6),
				Size              = UDim2.new(0.5, 0, 0, 16),
				ZIndex            = 3,
				Font              = Enum.Font.Gotham,
				Text              = title,
				TextColor3        = themes.TextColor,
				TextSize          = 12,
				TextTransparency  = 0.10000000149012,
				TextXAlignment    = Enum.TextXAlignment.Left
			}),
			utilityCreate("TextBox", {
				Name              = "TextBox",
				BackgroundTransparency = 1,
				BorderSizePixel   = 0,
				Position          = UDim2.new(1, -30, 0, 6),
				Size              = UDim2.new(0, 20, 0, 16),
				ZIndex            = 3,
				Font              = Enum.Font.GothamSemibold,
				Text              = default or min,
				TextColor3        = themes.TextColor,
				TextSize          = 12,
				TextXAlignment    = Enum.TextXAlignment.Right
			}),
			utilityCreate("TextLabel", {
				Name              = "Slider",
				BackgroundTransparency = 1,
				Position          = UDim2.new(0, 10, 0, 28),
				Size              = UDim2.new(1, -20, 0, 16),
				ZIndex            = 3,
				Text              = ""
			}, {
				utilityCreate("ImageLabel", {
					Name              = "Bar",
					AnchorPoint       = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Position          = UDim2.new(0, 0, 0.5, 0),
					Size              = UDim2.new(1, 0, 0, 4),
					ZIndex            = 3,
					Image             = "rbxassetid://5028857472",
					ImageColor3       = themes.LightContrast,
					ScaleType         = Enum.ScaleType.Slice,
					SliceCenter       = Rect.new(2, 2, 298, 298)
				}, {
					utilityCreate("ImageLabel", {
						Name              = "Fill",
						BackgroundTransparency = 1,
						Size              = UDim2.new(0.8, 0, 1, 0),
						ZIndex            = 3,
						Image             = "rbxassetid://5028857472",
						ImageColor3       = themes.TextColor,
						ScaleType         = Enum.ScaleType.Slice,
						SliceCenter       = Rect.new(2, 2, 298, 298)
					}, {
						utilityCreate("ImageLabel", {
							Name              = "Circle",
							AnchorPoint       = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							ImageTransparency = 1,
							ImageColor3       = themes.TextColor,
							Position          = UDim2.new(1, 0, 0.5, 0),
							Size              = UDim2.new(0, 10, 0, 10),
							ZIndex            = 3,
							Image             = "rbxassetid://4608020054"
						})
					})
				})
			})
		})

		table.insert(self.modules, slider)

		local allowed = {["."] = true, ["-"] = true}

		local textbox = slider.TextBox
		local circle  = slider.Slider.Bar.Fill.Circle

		local value    = default or min
		local dragging

		local fireCallback = function(v)
			if callback then
				callback(v, function(...)
					self:UpdateSlider(slider, ...)
				end)
			end
		end

		self:UpdateSlider(slider, nil, value, min, max)

		utilityDraggingEnded(function()
			dragging = false
		end)

		slider.MouseButton1Down:Connect(function()
			dragging = true

			while dragging do
				utilityTween(circle, {ImageTransparency = 0}, 0.1)
				value = self:UpdateSlider(slider, nil, nil, min, max, value)
				fireCallback(value)
				utilityWait()
			end

			task.wait(0.5)
			utilityTween(circle, {ImageTransparency = 1}, 0.2)
		end)

		textbox.FocusLost:Connect(function()
			if not tonumber(textbox.Text) then
				value = self:UpdateSlider(slider, nil, default or min, min, max)
				fireCallback(value)
			end
		end)

		textbox:GetPropertyChangedSignal("Text"):Connect(function()
			local t = textbox.Text
			if not allowed[t] and not tonumber(t) then
				textbox.Text = t:sub(1, #t - 1)
			elseif not allowed[t] then
				value = self:UpdateSlider(slider, nil, tonumber(t) or value, min, max)
				fireCallback(value)
			end
		end)

		return slider
	end

	function section:AddDropdown(title, list, callback)
		local dropdown = utilityCreate("Frame", {
			Name              = "Dropdown",
			Parent            = self.container,
			BackgroundTransparency = 1,
			Size              = UDim2.new(1, 0, 0, 30),
			ClipsDescendants  = true
		}, {
			utilityCreate("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding   = UDim.new(0, 4)
			}),
			utilityCreate("ImageLabel", {
				Name              = "Search",
				BackgroundTransparency = 1,
				BorderSizePixel   = 0,
				Size              = UDim2.new(1, 0, 0, 30),
				ZIndex            = 2,
				Image             = "rbxassetid://5028857472",
				ImageColor3       = themes.DarkContrast,
				ScaleType         = Enum.ScaleType.Slice,
				SliceCenter       = Rect.new(2, 2, 298, 298)
			}, {
				utilityCreate("TextBox", {
					Name              = "TextBox",
					AnchorPoint       = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					TextTruncate      = Enum.TextTruncate.AtEnd,
					Position          = UDim2.new(0, 10, 0.5, 1),
					Size              = UDim2.new(1, -42, 1, 0),
					ZIndex            = 3,
					Font              = Enum.Font.Gotham,
					Text              = title,
					TextColor3        = themes.TextColor,
					TextSize          = 12,
					TextTransparency  = 0.10000000149012,
					TextXAlignment    = Enum.TextXAlignment.Left
				}),
				utilityCreate("ImageButton", {
					Name              = "Button",
					BackgroundTransparency = 1,
					BorderSizePixel   = 0,
					Position          = UDim2.new(1, -28, 0.5, -9),
					Size              = UDim2.new(0, 18, 0, 18),
					ZIndex            = 3,
					Image             = "rbxassetid://5012539403",
					ImageColor3       = themes.TextColor,
					SliceCenter       = Rect.new(2, 2, 298, 298)
				})
			}),
			utilityCreate("ImageLabel", {
				Name              = "List",
				BackgroundTransparency = 1,
				BorderSizePixel   = 0,
				Size              = UDim2.new(1, 0, 1, -34),
				ZIndex            = 2,
				Image             = "rbxassetid://5028857472",
				ImageColor3       = themes.Background,
				ScaleType         = Enum.ScaleType.Slice,
				SliceCenter       = Rect.new(2, 2, 298, 298)
			}, {
				utilityCreate("ScrollingFrame", {
					Name                = "Frame",
					Active              = true,
					BackgroundTransparency = 1,
					BorderSizePixel     = 0,
					Position            = UDim2.new(0, 4, 0, 4),
					Size                = UDim2.new(1, -8, 1, -8),
					CanvasPosition      = Vector2.new(0, 28),
					CanvasSize          = UDim2.new(0, 0, 0, 120),
					ZIndex              = 2,
					ScrollBarThickness  = 3,
					ScrollBarImageColor3 = themes.DarkContrast
				}, {
					utilityCreate("UIListLayout", {
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding   = UDim.new(0, 4)
					})
				})
			})
		})

		table.insert(self.modules, dropdown)

		local search  = dropdown.Search
		local focused
		list = list or {}

		search.Button.MouseButton1Click:Connect(function()
			if search.Button.Rotation == 0 then
				self:UpdateDropdown(dropdown, nil, list, callback)
			else
				self:UpdateDropdown(dropdown, nil, nil, callback)
			end
		end)

		search.TextBox.Focused:Connect(function()
			if search.Button.Rotation == 0 then
				self:UpdateDropdown(dropdown, nil, list, callback)
			end
			focused = true
		end)

		search.TextBox.FocusLost:Connect(function()
			focused = false
		end)

		search.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
			if focused then
				local filtered = utilitySort(search.TextBox.Text, list)
				filtered = #filtered ~= 0 and filtered or nil
				self:UpdateDropdown(dropdown, nil, filtered, callback)
			end
		end)

		dropdown:GetPropertyChangedSignal("Size"):Connect(function()
			self:Resize()
		end)

		return dropdown
	end

	-- ─── SelectPage ──────────────────────────────────────────────────────────

	function library:SelectPage(p, toggle)
		if toggle and self.focusedPage == p then return end

		local button = p.button

		if toggle then
			button.Title.TextTransparency = 0
			button.Title.Font = Enum.Font.GothamSemibold

			if button:FindFirstChild("Icon") then
				button.Icon.ImageTransparency = 0
			end

			local focusedPage = self.focusedPage
			self.focusedPage = p

			if focusedPage then self:SelectPage(focusedPage) end

			local existingSections = focusedPage and #focusedPage.sections or 0
			local sectionsRequired = #p.sections - existingSections

			p:Resize()

			for _, sec in pairs(p.sections) do
				sec.container.Parent.ImageTransparency = 0
			end

			if sectionsRequired < 0 then
				for i = existingSections, #p.sections + 1, -1 do
					local sec = focusedPage.sections[i].container.Parent
					utilityTween(sec, {ImageTransparency = 1}, 0.1)
				end
			end

			task.wait(0.1)
			p.container.Visible = true

			if focusedPage then focusedPage.container.Visible = false end

			if sectionsRequired > 0 then
				for i = existingSections + 1, #p.sections do
					local sec = p.sections[i].container.Parent
					sec.ImageTransparency = 1
					utilityTween(sec, {ImageTransparency = 0}, 0.05)
				end
			end

			task.wait(0.05)

			for _, sec in pairs(p.sections) do
				utilityTween(sec.container.Title, {TextTransparency = 0}, 0.1)
				sec:Resize(true)
				task.wait(0.05)
			end

			task.wait(0.05)
			p:Resize(true)
		else
			button.Title.Font = Enum.Font.Gotham
			button.Title.TextTransparency = 0.65

			if button:FindFirstChild("Icon") then
				button.Icon.ImageTransparency = 0.65
			end

			for _, sec in pairs(p.sections) do
				utilityTween(sec.container.Parent, {Size = UDim2.new(1, -10, 0, 28)}, 0.1)
				utilityTween(sec.container.Title, {TextTransparency = 1}, 0.1)
			end

			task.wait(0.1)
			p.lastPosition = p.container.CanvasPosition.Y
			p:Resize()
		end
	end

	-- ─── Resize ──────────────────────────────────────────────────────────────

	function page:Resize(scroll)
		local padding = 10
		local size    = 0

		for _, sec in pairs(self.sections) do
			size = size + sec.container.Parent.AbsoluteSize.Y + padding
		end

		self.container.CanvasSize = UDim2.new(0, 0, 0, size)
		self.container.ScrollBarImageTransparency = size > self.container.AbsoluteSize.Y and 0 or 1

		if scroll then
			utilityTween(self.container, {CanvasPosition = Vector2.new(0, self.lastPosition or 0)}, 0.2)
		end
	end

	function section:Resize(smooth)
		if self.page.library.focusedPage ~= self.page then return end

		local padding = 4
		local size    = (4 + padding) + self.container.Title.AbsoluteSize.Y

		for _, module in pairs(self.modules) do
			size = size + module.AbsoluteSize.Y + padding
		end

		if smooth then
			utilityTween(self.container.Parent, {Size = UDim2.new(1, -10, 0, size)}, 0.05)
		else
			self.container.Parent.Size = UDim2.new(1, -10, 0, size)
			self.page:Resize()
		end
	end

	-- ─── GetModule ───────────────────────────────────────────────────────────

	function section:GetModule(info)
		if table.find(self.modules, info) then return info end

		for _, module in pairs(self.modules) do
			local label = module:FindFirstChild("Title") or module:FindFirstChild("TextBox", true)
			if label and label.Text == info then return module end
		end

		error("No module found under " .. tostring(info))
	end

	-- ─── Update functions ─────────────────────────────────────────────────────

	function section:UpdateButton(button, title)
		button = self:GetModule(button)
		button.Title.Text = title
	end

	function section:UpdateToggle(toggle, title, value)
		toggle = self:GetModule(toggle)

		local position = {
			In  = UDim2.new(0, 2,  0.5, -6),
			Out = UDim2.new(0, 20, 0.5, -6)
		}

		local frame = toggle.Button.Frame
		value = value and "Out" or "In"

		if title then toggle.Title.Text = title end

		utilityTween(frame, {
			Size     = UDim2.new(1, -22, 1, -9),
			Position = position[value] + UDim2.new(0, 0, 0, 2.5)
		}, 0.2)

		task.wait(0.1)
		utilityTween(frame, {
			Size     = UDim2.new(1, -22, 1, -4),
			Position = position[value]
		}, 0.1)
	end

	function section:UpdateTextbox(textbox, title, value)
		textbox = self:GetModule(textbox)
		if title then textbox.Title.Text           = title end
		if value then textbox.Button.Textbox.Text  = value end
	end

	function section:UpdateKeybind(keybind, title, key)
		keybind = self:GetModule(keybind)

		local text = keybind.Button.Text
		local bind = self.binds[keybind]

		if title then keybind.Title.Text = title end

		if bind.connection then
			bind.connection = bind.connection:UnBind()
		end

		if key then
			self.binds[keybind].connection = utilityBindToKey(key, bind.callback)
			text.Text = key.Name
		else
			text.Text = "None"
		end
	end

	function section:UpdateColorPicker(colorpicker, title, color)
		colorpicker = self:GetModule(colorpicker)

		local picker   = self.colorpickers[colorpicker]
		local tab      = picker.tab

		if title then
			colorpicker.Title.Text = title
			tab.Title.Text         = title
		end

		local color3, hue, sat, brightness

		if type(color) == "table" then
			hue, sat, brightness = unpack(color)
			color3 = Color3.fromHSV(hue, sat, brightness)
		else
			color3 = color
			hue, sat, brightness = Color3.toHSV(color3)
		end

		utilityTween(colorpicker.Button, {ImageColor3 = color3}, 0.5)
		utilityTween(tab.Container.Color.Select, {Position = UDim2.new(hue, 0, 0, 0)}, 0.1)
		utilityTween(tab.Container.Canvas, {ImageColor3 = Color3.fromHSV(hue, 1, 1)}, 0.5)
		utilityTween(tab.Container.Canvas.Cursor, {Position = UDim2.new(sat, 0, 1 - brightness)}, 0.5)

		for _, cont in pairs(tab.Container.Inputs:GetChildren()) do
			if cont:IsA("ImageLabel") then
				local value = math.clamp(color3[cont.Name], 0, 1) * 255
				cont.Textbox.Text = math.floor(value)
			end
		end
	end

	function section:UpdateSlider(slider, title, value, min, max, lvalue)
		slider = self:GetModule(slider)

		if title then slider.Title.Text = title end

		local bar     = slider.Slider.Bar
		local percent = (mouse.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X

		if value then
			percent = (value - min) / (max - min)
		end

		percent = math.clamp(percent, 0, 1)
		value   = value or math.floor(min + (max - min) * percent)

		slider.TextBox.Text = value
		utilityTween(bar.Fill, {Size = UDim2.new(percent, 0, 1, 0)}, 0.1)

		if value ~= lvalue and slider.ImageTransparency == 0 then
			utilityPop(slider, 10)
		end

		return value
	end

	function section:UpdateDropdown(dropdown, title, list, callback)
		dropdown = self:GetModule(dropdown)

		if title then dropdown.Search.TextBox.Text = title end

		local entries = 0

		utilityPop(dropdown.Search, 10)

		for _, button in pairs(dropdown.List.Frame:GetChildren()) do
			if button:IsA("ImageButton") then button:Destroy() end
		end

		for _, value in pairs(list or {}) do
			local button = utilityCreate("ImageButton", {
				Parent            = dropdown.List.Frame,
				BackgroundTransparency = 1,
				BorderSizePixel   = 0,
				Size              = UDim2.new(1, 0, 0, 30),
				ZIndex            = 2,
				Image             = "rbxassetid://5028857472",
				ImageColor3       = themes.DarkContrast,
				ScaleType         = Enum.ScaleType.Slice,
				SliceCenter       = Rect.new(2, 2, 298, 298)
			}, {
				utilityCreate("TextLabel", {
					BackgroundTransparency = 1,
					Position          = UDim2.new(0, 10, 0, 0),
					Size              = UDim2.new(1, -10, 1, 0),
					ZIndex            = 3,
					Font              = Enum.Font.Gotham,
					Text              = value,
					TextColor3        = themes.TextColor,
					TextSize          = 12,
					TextXAlignment    = Enum.TextXAlignment.Left,
					TextTransparency  = 0.10000000149012
				})
			})

			button.MouseButton1Click:Connect(function()
				if callback then
					callback(value, function(...)
						self:UpdateDropdown(dropdown, ...)
					end)
				end
				self:UpdateDropdown(dropdown, value, nil, callback)
			end)

			entries = entries + 1
		end

		local frame = dropdown.List.Frame

		utilityTween(dropdown, {
			Size = UDim2.new(1, 0, 0, (entries == 0 and 30) or math.clamp(entries, 0, 3) * 34 + 38)
		}, 0.3)
		utilityTween(dropdown.Search.Button, {Rotation = list and 180 or 0}, 0.3)

		if entries > 3 then
			for _, button in pairs(frame:GetChildren()) do
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

print("xev0r was here ))")

-- Expose for the key system and main script
return library
