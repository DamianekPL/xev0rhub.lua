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
	Background = Color3.fromRGB(24, 24, 24), 
	Glow = Color3.fromRGB(0, 0, 0), 
	Accent = Color3.fromRGB(10, 10, 10), 
	LightContrast = Color3.fromRGB(20, 20, 20), 
	DarkContrast = Color3.fromRGB(14, 14, 14),  
	TextColor = Color3.fromRGB(255, 255, 255)
}

do
	function utilityCreate(instance, properties, children)
		local object = Instance.new(instance)
		
		for i, v in pairs(properties or {}) do
			object[i] = v
			
			if typeof(v) == "Color3" then -- save for theme changer later
				local theme = utilityFind(themes, v)
				
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
	
	function utilityTween(instance, properties, duration, ...)
		tween:Create(instance, tweeninfo(duration, ...), properties):Play()
	end
	
	function utilityWait()
		run.RenderStepped:Wait()
		return true
	end
	
	function utilityFind(table, value) -- table.find doesn't work for dictionaries
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
		
		spawn(function()
			wait(0.2)
		
			object.ImageTransparency = 0
			clone:Destroy()
		end)
		
		return clone
	end
	
	function utilityInitializeKeybind()
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
			if key.UserInputType == Enum.UserInputType.MouseButton1 then
				for i, callback in pairs(self.ended) do
					callback()
				end
			end
		end)
	end
	
	function utilityBindToKey(key, callback)
		 
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
	
	function utilityKeyPressed() -- yield until next key is pressed
		local key = input.InputBegan:Wait()
		
		while key.UserInputType ~= Enum.UserInputType.Keyboard do
			key = input.InputBegan:Wait()
		end
		
		wait() -- overlapping connection
		
		return key
	end
	
	function utilityDraggingEnabled(frame, parent)
		parent = parent or frame

		-- Works with both mouse and touch input.
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
	
	function utilityDraggingEnded(callback)
		table.insert(self.ended, callback)
	end
	
end

-- classes

local library = {} -- main
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
		if not key then
			return
		end

		self.toggleKeyConnection = input.InputBegan:Connect(function(userInput, gameProcessed)
			if gameProcessed or input:GetFocusedTextBox() then
				return
			end

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

	-- Updates only the supplied watermark values, so it is safe to call from
	-- sliders and color-picker callbacks while the hub is open.
	function library:SetWatermarkStyle(style)
		if type(style) ~= "table" or not self.watermark then
			return
		end

		local watermarkFrame = self.watermark:FindFirstChild("Watermark")
		if not watermarkFrame then
			return
		end

		local glow = watermarkFrame:FindFirstChild("Glow")
		local accentLine = watermarkFrame:FindFirstChild("AccentLine")
		local topBar = watermarkFrame:FindFirstChild("TopBar")
		local status = watermarkFrame:FindFirstChild("Status")
		local titleLabel = watermarkFrame:FindFirstChild("Title", true)
		local info = watermarkFrame:FindFirstChild("Info", true)

		if style.Enabled ~= nil then
			self.watermark.Enabled = style.Enabled == true
		end
		if typeof(style.Position) == "UDim2" then
			watermarkFrame.Position = style.Position
		end
		if typeof(style.AnchorPoint) == "Vector2" then
			watermarkFrame.AnchorPoint = style.AnchorPoint
		end
		if typeof(style.Size) == "UDim2" then
			watermarkFrame.Size = style.Size
		end
		if tonumber(style.DisplayOrder) then
			self.watermark.DisplayOrder = tonumber(style.DisplayOrder)
		end

		if typeof(style.BackgroundColor) == "Color3" then
			watermarkFrame.ImageColor3 = style.BackgroundColor
		end
		if topBar and typeof(style.TopBarColor) == "Color3" then
			topBar.ImageColor3 = style.TopBarColor
		end
		if status and typeof(style.StatusColor) == "Color3" then
			status.ImageColor3 = style.StatusColor
		end
		if glow then
			if style.Glow ~= nil then
				glow.Visible = style.Glow == true
			end
			if typeof(style.GlowColor) == "Color3" then
				glow.ImageColor3 = style.GlowColor
			end
		end
		if accentLine then
			if style.AccentLine ~= nil then
				accentLine.Visible = style.AccentLine == true
			end
			if typeof(style.AccentColor) == "Color3" then
				accentLine.ImageColor3 = style.AccentColor
			end
		end
		if titleLabel then
			if typeof(style.TextColor) == "Color3" then
				titleLabel.TextColor3 = style.TextColor
			end
			if typeof(style.TitleColor) == "Color3" then
				titleLabel.TextColor3 = style.TitleColor
			end
			if tonumber(style.TitleTextSize) then
				titleLabel.TextSize = math.clamp(tonumber(style.TitleTextSize), 8, 32)
			end
		end
		if info then
			if typeof(style.TextColor) == "Color3" then
				info.TextColor3 = style.TextColor
			end
			if tonumber(style.TextSize) then
				info.TextSize = math.clamp(tonumber(style.TextSize), 8, 32)
			end
		end
	end

	function library:Destroy()
		if self.toggleKeyConnection then
			self.toggleKeyConnection:Disconnect()
		end
		if self.watermarkConnection then
			self.watermarkConnection:Disconnect()
		end
		if self.watermark then
			self.watermark:Destroy()
		end
		self.container:Destroy()
	end
	
	-- new classes
	
	function library.new(title, options)
		options = options or {}
		-- Desktop-only layout. Mobiletouch scaling is intentionally disabled.
		local topbarHeight = 38
		local navigationWidth = 126
		local contentLeft = navigationWidth + 8
		local playerGui = player:WaitForChild("PlayerGui")
		local watermarkOptions = options.Watermark
		if type(watermarkOptions) ~= "table" then
			watermarkOptions = {}
		end

		-- Watermark styling is deliberately independent from the window options.
		-- All fields are optional; these values preserve the menu-themed default.
		local watermarkEnabled = watermarkOptions.Enabled ~= false
		local watermarkAnchor = typeof(watermarkOptions.AnchorPoint) == "Vector2" and watermarkOptions.AnchorPoint or Vector2.new(1, 0)
		local watermarkPosition = typeof(watermarkOptions.Position) == "UDim2" and watermarkOptions.Position or UDim2.new(1, -16, 0, 16)
		local watermarkSize = typeof(watermarkOptions.Size) == "UDim2" and watermarkOptions.Size or UDim2.new(0, 390, 0, 58)
		local watermarkBackground = typeof(watermarkOptions.BackgroundColor) == "Color3" and watermarkOptions.BackgroundColor or themes.Background
		local watermarkTopBar = typeof(watermarkOptions.TopBarColor) == "Color3" and watermarkOptions.TopBarColor or themes.Accent
		local watermarkStatus = typeof(watermarkOptions.StatusColor) == "Color3" and watermarkOptions.StatusColor or themes.DarkContrast
		local watermarkGlow = typeof(watermarkOptions.GlowColor) == "Color3" and watermarkOptions.GlowColor or themes.Glow
		local watermarkAccent = typeof(watermarkOptions.AccentColor) == "Color3" and watermarkOptions.AccentColor or themes.LightContrast
		local watermarkText = typeof(watermarkOptions.TextColor) == "Color3" and watermarkOptions.TextColor or themes.TextColor
		local watermarkTextSize = tonumber(watermarkOptions.TextSize) or 13
		local watermarkTopbarHeight = math.clamp(tonumber(watermarkOptions.TopBarHeight) or 27, 22, 40)
		local watermarkShowGlow = watermarkOptions.Glow ~= false
		local watermarkShowAccent = watermarkOptions.AccentLine ~= false
		local watermarkDisplayOrder = tonumber(watermarkOptions.DisplayOrder) or 100

		local container = utilityCreate("ScreenGui", {
			Name = title,
			Parent = playerGui,
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		}, {
			utilityCreate("ImageLabel", {
				Name = "Main",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.new(0, 511, 0, 428),
				Image = "rbxassetid://4641149554",
				ImageColor3 = themes.Background,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(4, 4, 296, 296)
			}, {
				utilityCreate("ImageLabel", {
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
				utilityCreate("ImageLabel", {
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
					utilityCreate("ScrollingFrame", {
						Name = "Pages_Container",
						Active = true,
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 0, 0, 10),
						Size = UDim2.new(1, 0, 1, -20),
						CanvasSize = UDim2.new(0, 0, 0, 314),
						ScrollBarThickness = 0
					}, {
						utilityCreate("UIListLayout", {
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 10)
						})
					})
				}),
				utilityCreate("ImageLabel", {
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
					utilityCreate("TextLabel", { -- title
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
				utilityCreate("TextButton", {
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
				utilityCreate("TextButton", {
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

		-- Kept in its own ScreenGui so it remains visible when the menu is hidden.
		local watermark = utilityCreate("ScreenGui", {
			Name = title .. "_Watermark",
			Parent = playerGui,
			Enabled = watermarkEnabled,
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			-- Separate, high-priority layer it stays above the menu and remains
			-- visible when library:SetVisible(false) hides the main ScreenGui.
			DisplayOrder = watermarkDisplayOrder,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		}, {
			utilityCreate("ImageLabel", {
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
				-- Same soft rounded glow used by the main menu.
				utilityCreate("ImageLabel", {
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
				-- Uses the exact top-bar and page colors from the primary window.
				utilityCreate("ImageLabel", {
					Name = "TopBar",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 0, 0, 0),
					Size = UDim2.new(1, 0, 0, watermarkTopbarHeight),
					ZIndex = 3,
					Image = "rbxassetid://4595286933",
					ImageColor3 = watermarkTopBar,
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(4, 4, 296, 296)
				}, {
					utilityCreate("TextLabel", {
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
					})
				}),
				utilityCreate("ImageLabel", {
					Name = "Status",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 6, 0, watermarkTopbarHeight + 4),
					Size = UDim2.new(1, -12, 1, -(watermarkTopbarHeight + 10)),
					ZIndex = 3,
					Image = "rbxassetid://5012534273",
					ImageColor3 = watermarkStatus,
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(4, 4, 296, 296)
				}, {
					utilityCreate("TextLabel", {
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
				utilityCreate("ImageLabel", {
					Name = "AccentLine",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 8, 0, watermarkTopbarHeight - 1),
					Size = UDim2.new(1, -16, 0, 1),
					ZIndex = 5,
					Visible = watermarkShowAccent,
					Image = "rbxassetid://4595286933",
					ImageColor3 = watermarkAccent,
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(4, 4, 296, 296)
				})
			})
		})
		
		utilityInitializeKeybind()
		utilityDraggingEnabled(container.Main.TopBar, container.Main)
		
		local window = setmetatable({
			container = container,
			pagesContainer = container.Main.Pages.Pages_Container,
			pages = {},
			watermark = watermark,
			topbarHeight = topbarHeight,
			navigationWidth = navigationWidth,
			contentLeft = contentLeft
		}, library)

		window:SetToggleKey(options.ToggleKey or Enum.KeyCode.RightShift)

		local frameCount = 0
		local lastSample = os.clock()
		window.watermarkConnection = run.RenderStepped:Connect(function()
			frameCount = frameCount + 1

			local now = os.clock()
			local elapsed = now - lastSample
			if elapsed < 1 then
				return
			end

			local ping = 0
			local success, value = pcall(function()
				return stats.Network.ServerStatsItem["Data Ping"]:GetValue()
			end)
			if success and tonumber(value) then
				ping = math.floor(tonumber(value) + 0.5)
			end

			local fps = math.floor((frameCount / elapsed) + 0.5)
			watermark.Watermark.Status.Info.Text = string.format("%s | %d FPS | %d ms", player.Name, fps, ping)
			frameCount = 0
			lastSample = now
		end)

		container.Main.TopBar.Minimize.MouseButton1Click:Connect(function()
			window:Toggle()
		end)
		container.Main.TopBar.Close.MouseButton1Click:Connect(function()
			window:Destroy()
		end)
		
		return window
	end
	
	function page.new(library, title, icon)
		local button = utilityCreate("TextButton", {
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
			utilityCreate("TextLabel", {
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
			}),
			icon and utilityCreate("ImageLabel", {
				Name = "Icon", 
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.new(0, 16, 0, 16),
				ZIndex = 3,
				Image = "rbxassetid://" .. tostring(icon),
				ImageColor3 = themes.TextColor,
				ImageTransparency = 0.64,
				ScaleType = Enum.ScaleType.Fit
			}) or {}
		})
		
		local container = utilityCreate("ScrollingFrame", {
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
			utilityCreate("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10)
			})
		})
		
		return setmetatable({
			library = library,
			container = container,
			button = button,
			sections = {}
		}, page)
	end
	
	function section.new(page, title)
		local container = utilityCreate("ImageLabel", {
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
			utilityCreate("Frame", {
				Name = "Container",
				Active = true,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 8, 0, 8),
				Size = UDim2.new(1, -16, 1, -16)
			}, {
				utilityCreate("TextLabel", {
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
				utilityCreate("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4)
				})
			})
		})
		
		return setmetatable({
			page = page,
			container = container.Container,
			colorpickers = {},
			modules = {},
			binds = {},
			lists = {},
		}, section) 
	end
	
	function library:AddPage(...)
	
		local page = page.new(self, ...)
		local button = page.button
		
		table.insert(self.pages, page)

		button.MouseButton1Click:Connect(function()
			self:SelectPage(page, true)
		end)
		
		return page
	end
	
	function page:AddSection(...)
		local section = section.new(self, ...)
		
		table.insert(self.sections, section)
		
		return section
	end
	
	-- functions
	
	function library:SetTheme(theme, color3)
		themes[theme] = color3
		
		for property, objects in pairs(objects[theme]) do
			for i, object in pairs(objects) do
				if not object.Parent or (object.Name == "Button" and object.Parent.Name == "ColorPicker") then
					objects[i] = nil -- i can do this because weak tables D
				else
					object[property] = color3
				end
			end
		end
	end
	
	function library:Toggle()
	
		if self.toggling then
			return
		end
		
		self.toggling = true
		
		local container = self.container.Main
		local topbar = container.TopBar
		
		if self.minimized then
			local expandedSize = self.expandedSize
			local yOffset = (expandedSize.Y.Offset - self.topbarHeight) / 2

			utilityTween(container, {
				Size = expandedSize,
				Position = container.Position - UDim2.fromOffset(0, yOffset)
			}, 0.2)
			wait(0.2)

			utilityTween(topbar, {Size = UDim2.new(1, 0, 0, self.topbarHeight)}, 0.15)
			container.ClipsDescendants = false
			self.minimized = false
		else
			self.expandedSize = container.Size
			local yOffset = (self.expandedSize.Y.Offset - self.topbarHeight) / 2

			container.ClipsDescendants = true
			utilityTween(topbar, {Size = UDim2.new(1, 0, 1, 0)}, 0.15)
			wait(0.15)

			utilityTween(container, {
				Size = UDim2.fromOffset(self.expandedSize.X.Offset, self.topbarHeight),
				Position = container.Position + UDim2.fromOffset(0, yOffset)
			}, 0.2)
			self.minimized = true
		end
		
		self.toggling = false
	end
	
	-- new modules
	
	function library:Notify(title, text, callback)
	
		-- overwrite last notification
		if self.activeNotification then
			self.activeNotification = self.activeNotification()
		end
		
		-- standard create
		local notification = utilityCreate("ImageLabel", {
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
			utilityCreate("ImageLabel", {
				Name = "Flash",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Image = "rbxassetid://4641149554",
				ImageColor3 = themes.TextColor,
				ZIndex = 5
			}),
			utilityCreate("ImageLabel", {
				Name = "Glow",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, -15, 0, -15),
				Size = UDim2.new(1, 30, 1, 30),
				ZIndex = 2,
				Image = "rbxassetid://5028857084",
				ImageColor3 = themes.Glow,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(24, 24, 276, 276)
			}),
			utilityCreate("TextLabel", {
				Name = "Title",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 10, 0, 8),
				Size = UDim2.new(1, -40, 0, 16),
				ZIndex = 4,
				Font = Enum.Font.GothamSemibold,
				TextColor3 = themes.TextColor,
				TextSize = 14.000,
				TextXAlignment = Enum.TextXAlignment.Left
			}),
			utilityCreate("TextLabel", {
				Name = "Text",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 10, 1, -24),
				Size = UDim2.new(1, -40, 0, 16),
				ZIndex = 4,
				Font = Enum.Font.Gotham,
				TextColor3 = themes.TextColor,
				TextSize = 12.000,
				TextXAlignment = Enum.TextXAlignment.Left
			}),
			utilityCreate("ImageButton", {
				Name = "Accept",
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -26, 0, 8),
				Size = UDim2.new(0, 16, 0, 16),
				Image = "rbxassetid://5012538259",
				ImageColor3 = themes.TextColor,
				ZIndex = 4
			}),
			utilityCreate("ImageButton", {
				Name = "Decline",
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -26, 1, -24),
				Size = UDim2.new(0, 16, 0, 16),
				Image = "rbxassetid://5012538583",
				ImageColor3 = themes.TextColor,
				ZIndex = 4
			})
		})
		
		-- dragging
		utilityDraggingEnabled(notification)
		
		-- position and size
		title = title or "Notification"
		text = text or ""
		
		notification.Title.Text = title
		notification.Text.Text = text
		
		local padding = 10
		local textSize = game:GetService("TextService"):GetTextSize(text, 12, Enum.Font.Gotham, Vector2.new(math.huge, 16))
		
		notification.Position = library.lastNotification or UDim2.new(0, padding, 1, -(notification.AbsoluteSize.Y + padding))
		notification.Size = UDim2.new(0, 0, 0, 60)
		
		utilityTween(notification, {Size = UDim2.new(0, textSize.X + 70, 0, 60)}, 0.2)
		wait(0.2)
		
		notification.ClipsDescendants = false
		utilityTween(notification.Flash, {
			Size = UDim2.new(0, 0, 0, 60),
			Position = UDim2.new(1, 0, 0, 0)
		}, 0.2)
		
		-- callbacks
		local active = true
		local close = function()
		
			if not active then
				return
			end
			
			active = false
			notification.ClipsDescendants = true
			
			library.lastNotification = notification.Position
			notification.Flash.Position = UDim2.new(0, 0, 0, 0)
			utilityTween(notification.Flash, {Size = UDim2.new(1, 0, 1, 0)}, 0.2)
			
			wait(0.2)
			utilityTween(notification, {
				Size = UDim2.new(0, 0, 0, 60),
				Position = notification.Position + UDim2.new(0, textSize.X + 70, 0, 0)
			}, 0.2)
			
			wait(0.2)
			notification:Destroy()
		end
		
		self.activeNotification = close
		
		notification.Accept.MouseButton1Click:Connect(function()
		
			if not active then 
				return
			end
			
			if callback then
				callback(true)
			end
			
			close()
		end)
		
		notification.Decline.MouseButton1Click:Connect(function()
		
			if not active then 
				return
			end
			
			if callback then
				callback(false)
			end
			
			close()
		end)
	end
	
	function section:AddButton(title, callback)
		local button = utilityCreate("ImageButton", {
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
			utilityCreate("TextLabel", {
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
		--self:Resize()
		
		local text = button.Title
		local debounce
		
		button.MouseButton1Click:Connect(function()
			
			if debounce then
				return
			end
			
			-- animation
			utilityPop(button, 10)
			
			debounce = true
			text.TextSize = 0
			utilityTween(button.Title, {TextSize = 14}, 0.2)
			
			wait(0.2)
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
		},{
			utilityCreate("TextLabel", {
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
			utilityCreate("ImageLabel", {
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
				utilityCreate("ImageLabel", {
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
		--self:Resize()
		
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
			utilityCreate("TextLabel", {
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
			utilityCreate("ImageLabel", {
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
				utilityCreate("TextBox", {
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
		--self:Resize()
		
		local button = textbox.Button
		local input = button.Textbox
		
		textbox.MouseButton1Click:Connect(function()
		
			if textbox.Button.Size ~= UDim2.new(0, 100, 0, 16) then
				return
			end
			
			utilityTween(textbox.Button, {
				Size = UDim2.new(0, 200, 0, 16),
				Position = UDim2.new(1, -210, 0.5, -8)
			}, 0.2)
			
			wait()

			input.TextXAlignment = Enum.TextXAlignment.Left
			input:CaptureFocus()
		end)
		
		input:GetPropertyChangedSignal("Text"):Connect(function()
			
			if button.ImageTransparency == 0 and (button.Size == UDim2.new(0, 200, 0, 16) or button.Size == UDim2.new(0, 100, 0, 16)) then -- i know, i dont like this either
				utilityPop(button, 10)
			end
			
			if callback then
				callback(input.Text, nil, function(...)
					self:UpdateTextbox(textbox, ...)
				end)
			end
		end)
		
		input.FocusLost:Connect(function()
			
			input.TextXAlignment = Enum.TextXAlignment.Center
			
			utilityTween(textbox.Button, {
				Size = UDim2.new(0, 100, 0, 16),
				Position = UDim2.new(1, -110, 0.5, -8)
			}, 0.2)
			
			if callback then
				callback(input.Text, true, function(...)
					self:UpdateTextbox(textbox, ...)
				end)
			end
		end)
		
		return textbox
	end
	
	function section:AddKeybind(title, default, callback, changedCallback)
		local keybind = utilityCreate("ImageButton", {
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
			utilityCreate("TextLabel", {
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
			utilityCreate("ImageLabel", {
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
				utilityCreate("TextLabel", {
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
		--self:Resize()
		
		local text = keybind.Button.Text
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
			
			if self.binds[keybind].connection then -- unbind
				return self:UpdateKeybind(keybind)
			end
			
			if text.Text == "None" then -- new bind
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
		},{
			utilityCreate("TextLabel", {
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
			utilityCreate("ImageButton", {
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
		
		local tab = utilityCreate("ImageLabel", {
			Name = "ColorPicker",
			Parent = self.page.library.container,
			BackgroundTransparency = 1,
			Position = UDim2.new(0.75, 0, 0.400000006, 0),
			Selectable = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 162, 0, 169),
			Image = "rbxassetid://5028857472",
			ImageColor3 = themes.Background,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(2, 2, 298, 298),
			Visible = false,
		}, {
			utilityCreate("ImageLabel", {
				Name = "Glow",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, -15, 0, -15),
				Size = UDim2.new(1, 30, 1, 30),
				ZIndex = 0,
				Image = "rbxassetid://5028857084",
				ImageColor3 = themes.Glow,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(22, 22, 278, 278)
			}),
			utilityCreate("TextLabel", {
				Name = "Title",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 10, 0, 8),
				Size = UDim2.new(1, -40, 0, 16),
				ZIndex = 2,
				Font = Enum.Font.GothamSemibold,
				Text = title,
				TextColor3 = themes.TextColor,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left
			}),
			utilityCreate("ImageButton", {
				Name = "Close",
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -26, 0, 8),
				Size = UDim2.new(0, 16, 0, 16),
				ZIndex = 2,
				Image = "rbxassetid://5012538583",
				ImageColor3 = themes.TextColor
			}), 
			utilityCreate("Frame", {
				Name = "Container",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 8, 0, 32),
				Size = UDim2.new(1, -18, 1, -40)
			}, {
				utilityCreate("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6)
				}),
				utilityCreate("ImageButton", {
					Name = "Canvas",
					BackgroundTransparency = 1,
					BorderColor3 = themes.LightContrast,
					Size = UDim2.new(1, 0, 0, 60),
					AutoButtonColor = false,
					Image = "rbxassetid://5108535320",
					ImageColor3 = Color3.fromRGB(255, 0, 0),
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(2, 2, 298, 298)
				}, {
					utilityCreate("ImageLabel", {
						Name = "White_Overlay",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 60),
						Image = "rbxassetid://5107152351",
						SliceCenter = Rect.new(2, 2, 298, 298)
					}),
					utilityCreate("ImageLabel", {
						Name = "Black_Overlay",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 60),
						Image = "rbxassetid://5107152095",
						SliceCenter = Rect.new(2, 2, 298, 298)
					}),
					utilityCreate("ImageLabel", {
						Name = "Cursor",
						BackgroundColor3 = themes.TextColor,
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1.000,
						Size = UDim2.new(0, 10, 0, 10),
						Position = UDim2.new(0, 0, 0, 0),
						Image = "rbxassetid://5100115962",
						SliceCenter = Rect.new(2, 2, 298, 298)
					})
				}),
				utilityCreate("ImageButton", {
					Name = "Color",
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.new(0, 0, 0, 4),
					Selectable = false,
					Size = UDim2.new(1, 0, 0, 16),
					ZIndex = 2,
					AutoButtonColor = false,
					Image = "rbxassetid://5028857472",
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(2, 2, 298, 298)
				}, {
					utilityCreate("Frame", {
						Name = "Select",
						BackgroundColor3 = themes.TextColor,
						BorderSizePixel = 1,
						Position = UDim2.new(1, 0, 0, 0),
						Size = UDim2.new(0, 2, 1, 0),
						ZIndex = 2
					}),
					utilityCreate("UIGradient", { -- rainbow canvas
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)), 
							ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)), 
							ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)), 
							ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)), 
							ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 0, 255)), 
							ColorSequenceKeypoint.new(0.82, Color3.fromRGB(255, 0, 255)), 
							ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0))
						})
					})
				}),
				utilityCreate("Frame", {
					Name = "Inputs",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 10, 0, 158),
					Size = UDim2.new(1, 0, 0, 16)
				}, {
					utilityCreate("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6)
					}),
					utilityCreate("ImageLabel", {
						Name = "R",
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Size = UDim2.new(0.305, 0, 1, 0),
						ZIndex = 2,
						Image = "rbxassetid://5028857472",
						ImageColor3 = themes.DarkContrast,
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(2, 2, 298, 298)
					}, {
						utilityCreate("TextLabel", {
							Name = "Text",
							BackgroundTransparency = 1,
							Size = UDim2.new(0.400000006, 0, 1, 0),
							ZIndex = 2,
							Font = Enum.Font.Gotham,
							Text = "R",
							TextColor3 = themes.TextColor,
							TextSize = 10.000
						}),
						utilityCreate("TextBox", {
							Name = "Textbox",
							BackgroundTransparency = 1,
							Position = UDim2.new(0.300000012, 0, 0, 0),
							Size = UDim2.new(0.600000024, 0, 1, 0),
							ZIndex = 2,
							Font = Enum.Font.Gotham,
							PlaceholderColor3 = themes.DarkContrast,
							Text = "255",
							TextColor3 = themes.TextColor,
							TextSize = 10.000
						})
					}),
					utilityCreate("ImageLabel", {
						Name = "G",
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Size = UDim2.new(0.305, 0, 1, 0),
						ZIndex = 2,
						Image = "rbxassetid://5028857472",
						ImageColor3 = themes.DarkContrast,
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(2, 2, 298, 298)
					}, {
						utilityCreate("TextLabel", {
							Name = "Text",
							BackgroundTransparency = 1,
							ZIndex = 2,
							Size = UDim2.new(0.400000006, 0, 1, 0),
							Font = Enum.Font.Gotham,
							Text = "G",
							TextColor3 = themes.TextColor,
							TextSize = 10.000
						}),
						utilityCreate("TextBox", {
							Name = "Textbox",
							BackgroundTransparency = 1,
							Position = UDim2.new(0.300000012, 0, 0, 0),
							Size = UDim2.new(0.600000024, 0, 1, 0),
							ZIndex = 2,
							Font = Enum.Font.Gotham,
							Text = "255",
							TextColor3 = themes.TextColor,
							TextSize = 10.000
						})
					}),
					utilityCreate("ImageLabel", {
						Name = "B",
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Size = UDim2.new(0.305, 0, 1, 0),
						ZIndex = 2,
						Image = "rbxassetid://5028857472",
						ImageColor3 = themes.DarkContrast,
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(2, 2, 298, 298)
					}, {
						utilityCreate("TextLabel", {
							Name = "Text",
							BackgroundTransparency = 1,
							Size = UDim2.new(0.400000006, 0, 1, 0),
							ZIndex = 2,
							Font = Enum.Font.Gotham,
							Text = "B",
							TextColor3 = themes.TextColor,
							TextSize = 10.000
						}),
						utilityCreate("TextBox", {
							Name = "Textbox",
							BackgroundTransparency = 1,
							Position = UDim2.new(0.300000012, 0, 0, 0),
							Size = UDim2.new(0.600000024, 0, 1, 0),
							ZIndex = 2,
							Font = Enum.Font.Gotham,
							Text = "255",
							TextColor3 = themes.TextColor,
							TextSize = 10.000
						})
					}),
				}),
				utilityCreate("ImageButton", {
					Name = "Button",
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 20),
					ZIndex = 2,
					Image = "rbxassetid://5028857472",
					ImageColor3 = themes.DarkContrast,
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(2, 2, 298, 298)
				}, {
					utilityCreate("TextLabel", {
						Name = "Text",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0),
						ZIndex = 3,
						Font = Enum.Font.Gotham,
						Text = "Submit",
						TextColor3 = themes.TextColor,
						TextSize = 11.000
					})
				})
			})
		})
		
		utilityDraggingEnabled(tab)
		table.insert(self.modules, colorpicker)
		--self:Resize()
		
		local allowed = {
			["."] = true
		}
		
		local canvas = tab.Container.Canvas
		local color = tab.Container.Color
		
		local canvasSize, canvasPosition = canvas.AbsoluteSize, canvas.AbsolutePosition
		local colorSize, colorPosition = color.AbsoluteSize, color.AbsolutePosition
		
		local draggingColor, draggingCanvas
		
		local color3 = default or Color3.fromRGB(255, 255, 255)
		local hue, sat, brightness = 0, 0, 1
		local rgb = {
			r = 255,
			g = 255,
			b = 255
		}
		
		self.colorpickers[colorpicker] = {
			tab = tab,
			callback = function(prop, value)
				rgb[prop] = value
				hue, sat, brightness = Color3.toHSV(Color3.fromRGB(rgb.r, rgb.g, rgb.b))
			end
		}
		
		local callback = function(value)
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
			
			for i, prop in pairs({"r", "g", "b"}) do
				rgb[prop] = default[prop:upper()] * 255
			end
		end
		
		for i, container in pairs(tab.Container.Inputs:GetChildren()) do -- i know what you are about to say, so shut up
			if container:IsA("ImageLabel") then
				local textbox = container.Textbox
				local focused
				
				textbox.Focused:Connect(function()
					focused = true
				end)
				
				textbox.FocusLost:Connect(function()
					focused = false
					
					if not tonumber(textbox.Text) then
						textbox.Text = math.floor(rgb[container.Name:lower()])
					end
				end)
				
				textbox:GetPropertyChangedSignal("Text"):Connect(function()
					local text = textbox.Text
					
					if not allowed[text] and not tonumber(text) then
						textbox.Text = text:sub(1, #text - 1)
					elseif focused and not allowed[text] then
						rgb[container.Name:lower()] = math.clamp(tonumber(textbox.Text), 0, 255)
						
						local color3 = Color3.fromRGB(rgb.r, rgb.g, rgb.b)
						hue, sat, brightness = Color3.toHSV(color3)
						
						self:UpdateColorPicker(colorpicker, nil, color3)
						callback(color3)
					end
				end)
			end
		end
		
		canvas.MouseButton1Down:Connect(function()
			draggingCanvas = true
			
			while draggingCanvas do
				
				local x, y = mouse.X, mouse.Y
				
				sat = math.clamp((x - canvasPosition.X) / canvasSize.X, 0, 1)
				brightness = 1 - math.clamp((y - canvasPosition.Y) / canvasSize.Y, 0, 1)
				
				color3 = Color3.fromHSV(hue, sat, brightness)
				
				for i, prop in pairs({"r", "g", "b"}) do
					rgb[prop] = color3[prop:upper()] * 255
				end
				
				self:UpdateColorPicker(colorpicker, nil, {hue, sat, brightness}) -- roblox is literally retarded
				utilityTween(canvas.Cursor, {Position = UDim2.new(sat, 0, 1 - brightness, 0)}, 0.1) -- overwrite
				
				callback(color3)
				utilityWait()
			end
		end)
		
		color.MouseButton1Down:Connect(function()
			draggingColor = true
			
			while draggingColor do
			
				hue = 1 - math.clamp(1 - ((mouse.X - colorPosition.X) / colorSize.X), 0, 1)
				color3 = Color3.fromHSV(hue, sat, brightness)
				
				for i, prop in pairs({"r", "g", "b"}) do
					rgb[prop] = color3[prop:upper()] * 255
				end
				
				local x = hue -- hue is updated
				self:UpdateColorPicker(colorpicker, nil, {hue, sat, brightness}) -- roblox is literally retarded
				utilityTween(tab.Container.Color.Select, {Position = UDim2.new(x, 0, 0, 0)}, 0.1) -- overwrite
				
				callback(color3)
				utilityWait()
			end
		end)
		
		-- click events
		local button = colorpicker.Button
		local toggle, debounce, animate
		
		lastColor = Color3.fromHSV(hue, sat, brightness)
		animate = function(visible, overwrite)
			
			if overwrite then
			
				if not toggle then
					return
				end
				
				if debounce then
					while debounce do
						utilityWait()
					end
				end
			elseif not overwrite then
				if debounce then 
					return 
				end
				
				if button.ImageTransparency == 0 then
					utilityPop(button, 10)
				end
			end
			
			toggle = visible
			debounce = true
			
			if visible then
			
				if self.page.library.activePicker and self.page.library.activePicker ~= animate then
					self.page.library.activePicker(nil, true)
				end
				
				self.page.library.activePicker = animate
				lastColor = Color3.fromHSV(hue, sat, brightness)
				
				local x1, x2 = button.AbsoluteSize.X / 2, 162--tab.AbsoluteSize.X
				local px, py = button.AbsolutePosition.X, button.AbsolutePosition.Y
				
				tab.ClipsDescendants = true
				tab.Visible = true
				tab.Size = UDim2.new(0, 0, 0, 0)
				
				tab.Position = UDim2.new(0, x1 + x2 + px, 0, py)
				utilityTween(tab, {Size = UDim2.new(0, 162, 0, 169)}, 0.2)
				
				-- update size and position
				wait(0.2)
				tab.ClipsDescendants = false
				
				canvasSize, canvasPosition = canvas.AbsoluteSize, canvas.AbsolutePosition
				colorSize, colorPosition = color.AbsoluteSize, color.AbsolutePosition
			else
				utilityTween(tab, {Size = UDim2.new(0, 0, 0, 0)}, 0.2)
				tab.ClipsDescendants = true
				
				wait(0.2)
				tab.Visible = false
			end
			
			debounce = false
		end
		
		local toggleTab = function()
			animate(not toggle)
		end
		
		button.MouseButton1Click:Connect(toggleTab)
		colorpicker.MouseButton1Click:Connect(toggleTab)
		
		tab.Container.Button.MouseButton1Click:Connect(function()
			animate()
		end)
		
		tab.Close.MouseButton1Click:Connect(function()
			self:UpdateColorPicker(colorpicker, nil, lastColor)
			animate()
		end)
		
		return colorpicker
	end
	
	function section:AddSlider(title, default, min, max, callback)
		local slider = utilityCreate("ImageButton", {
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
			utilityCreate("TextLabel", {
				Name = "Title",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 10, 0, 6),
				Size = UDim2.new(0.5, 0, 0, 16),
				ZIndex = 3,
				Font = Enum.Font.Gotham,
				Text = title,
				TextColor3 = themes.TextColor,
				TextSize = 12,
				TextTransparency = 0.10000000149012,
				TextXAlignment = Enum.TextXAlignment.Left
			}),
			utilityCreate("TextBox", {
				Name = "TextBox",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.new(1, -30, 0, 6),
				Size = UDim2.new(0, 20, 0, 16),
				ZIndex = 3,
				Font = Enum.Font.GothamSemibold,
				Text = default or min,
				TextColor3 = themes.TextColor,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right
			}),
			utilityCreate("TextLabel", {
				Name = "Slider",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 10, 0, 28),
				Size = UDim2.new(1, -20, 0, 16),
				ZIndex = 3,
				Text = "",
			}, {
				utilityCreate("ImageLabel", {
					Name = "Bar",
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.new(1, 0, 0, 4),
					ZIndex = 3,
					Image = "rbxassetid://5028857472",
					ImageColor3 = themes.LightContrast,
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(2, 2, 298, 298)
				}, {
					utilityCreate("ImageLabel", {
						Name = "Fill",
						BackgroundTransparency = 1,
						Size = UDim2.new(0.8, 0, 1, 0),
						ZIndex = 3,
						Image = "rbxassetid://5028857472",
						ImageColor3 = themes.TextColor,
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(2, 2, 298, 298)
					}, {
						utilityCreate("ImageLabel", {
							Name = "Circle",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							ImageTransparency = 1.000,
							ImageColor3 = themes.TextColor,
							Position = UDim2.new(1, 0, 0.5, 0),
							Size = UDim2.new(0, 10, 0, 10),
							ZIndex = 3,
							Image = "rbxassetid://4608020054"
						})
					})
				})
			})
		})
		
		table.insert(self.modules, slider)
		--self:Resize()
		
		local allowed = {
			["."] = true,
			["-"] = true
		}
		
		local textbox = slider.TextBox
		local circle = slider.Slider.Bar.Fill.Circle
		
		local value = default or min
		local dragging, last
		
		local callback = function(value)
			if callback then
				callback(value, function(...)
					self:UpdateSlider(slider, ...)
				end)
			end
		end
		
		self:UpdateSlider(slider, nil, value, min, max)
		
		utilityDraggingEnded(function()
			dragging = false
		end)

		slider.MouseButton1Down:Connect(function(input)
			dragging = true
			
			while dragging do
				utilityTween(circle, {ImageTransparency = 0}, 0.1)
				
				value = self:UpdateSlider(slider, nil, nil, min, max, value)
				callback(value)
				
				utilityWait()
			end
			
			wait(0.5)
			utilityTween(circle, {ImageTransparency = 1}, 0.2)
		end)
		
		textbox.FocusLost:Connect(function()
			if not tonumber(textbox.Text) then
				value = self:UpdateSlider(slider, nil, default or min, min, max)
				callback(value)
			end
		end)
		
		textbox:GetPropertyChangedSignal("Text"):Connect(function()
			local text = textbox.Text
			
			if not allowed[text] and not tonumber(text) then
				textbox.Text = text:sub(1, #text - 1)
			elseif not allowed[text] then	
				value = self:UpdateSlider(slider, nil, tonumber(text) or value, min, max)
				callback(value)
			end
		end)
		
		return slider
	end
	
	function section:AddDropdown(title, list, callback)
		local dropdown = utilityCreate("Frame", {
			Name = "Dropdown",
			Parent = self.container,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			ClipsDescendants = true
		}, {
			utilityCreate("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4)
			}),
			utilityCreate("ImageLabel", {
				Name = "Search",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 30),
				ZIndex = 2,
				Image = "rbxassetid://5028857472",
				ImageColor3 = themes.DarkContrast,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(2, 2, 298, 298)
			}, {
				utilityCreate("TextBox", {
					Name = "TextBox",
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Position = UDim2.new(0, 10, 0.5, 1),
					Size = UDim2.new(1, -42, 1, 0),
					ZIndex = 3,
					Font = Enum.Font.Gotham,
					Text = title,
					TextColor3 = themes.TextColor,
					TextSize = 12,
					TextTransparency = 0.10000000149012,
					TextXAlignment = Enum.TextXAlignment.Left
				}),
				utilityCreate("ImageButton", {
					Name = "Button",
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.new(1, -28, 0.5, -9),
					Size = UDim2.new(0, 18, 0, 18),
					ZIndex = 3,
					Image = "rbxassetid://5012539403",
					ImageColor3 = themes.TextColor,
					SliceCenter = Rect.new(2, 2, 298, 298)
				})
			}),
			utilityCreate("ImageLabel", {
				Name = "List",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 1, -34),
				ZIndex = 2,
				Image = "rbxassetid://5028857472",
				ImageColor3 = themes.Background,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(2, 2, 298, 298)
			}, {
				utilityCreate("ScrollingFrame", {
					Name = "Frame",
					Active = true,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.new(0, 4, 0, 4),
					Size = UDim2.new(1, -8, 1, -8),
					CanvasPosition = Vector2.new(0, 28),
					CanvasSize = UDim2.new(0, 0, 0, 120),
					ZIndex = 2,
					ScrollBarThickness = 3,
					ScrollBarImageColor3 = themes.DarkContrast
				}, {
					utilityCreate("UIListLayout", {
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4)
					})
				})
			})
		})
		
		table.insert(self.modules, dropdown)
		--self:Resize()
		
		local search = dropdown.Search
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
				local list = utilitySort(search.TextBox.Text, list)
				list = #list ~= 0 and list 
				
				self:UpdateDropdown(dropdown, nil, list, callback)
			end
		end)
		
		dropdown:GetPropertyChangedSignal("Size"):Connect(function()
			self:Resize()
		end)
		
		return dropdown
	end
	
	-- class functions
	
	function library:SelectPage(page, toggle)
		
		if toggle and self.focusedPage == page then -- already selected
			return
		end
		
		local button = page.button
		
		if toggle then
			-- page button
			button.Title.TextTransparency = 0
			button.Title.Font = Enum.Font.GothamSemibold
			
			if button:FindFirstChild("Icon") then
				button.Icon.ImageTransparency = 0
			end
			
			-- update selected page
			local focusedPage = self.focusedPage
			self.focusedPage = page
			
			if focusedPage then
				self:SelectPage(focusedPage)
			end
			
			-- sections
			local existingSections = focusedPage and #focusedPage.sections or 0
			local sectionsRequired = #page.sections - existingSections
			
			page:Resize()
			
			for i, section in pairs(page.sections) do
				section.container.Parent.ImageTransparency = 0
			end
			
			if sectionsRequired < 0 then -- hides some sections
				for i = existingSections, #page.sections + 1, -1 do
					local section = focusedPage.sections[i].container.Parent
					
					utilityTween(section, {ImageTransparency = 1}, 0.1)
				end
			end
			
			wait(0.1)
			page.container.Visible = true
			
			if focusedPage then
				focusedPage.container.Visible = false
			end
			
			if sectionsRequired > 0 then -- creates more section
				for i = existingSections + 1, #page.sections do
					local section = page.sections[i].container.Parent
					
					section.ImageTransparency = 1
					utilityTween(section, {ImageTransparency = 0}, 0.05)
				end
			end
			
			wait(0.05)
			
			for i, section in pairs(page.sections) do
			
				utilityTween(section.container.Title, {TextTransparency = 0}, 0.1)
				section:Resize(true)
				
				wait(0.05)
			end
			
			wait(0.05)
			page:Resize(true)
		else
			-- page button
			button.Title.Font = Enum.Font.Gotham
			button.Title.TextTransparency = 0.65
			
			if button:FindFirstChild("Icon") then
				button.Icon.ImageTransparency = 0.65
			end
			
			-- sections
			for i, section in pairs(page.sections) do	
				utilityTween(section.container.Parent, {Size = UDim2.new(1, -10, 0, 28)}, 0.1)
				utilityTween(section.container.Title, {TextTransparency = 1}, 0.1)
			end
			
			wait(0.1)
			
			page.lastPosition = page.container.CanvasPosition.Y
			page:Resize()
		end
	end
	
	function page:Resize(scroll)
		local padding = 10
		local size = 0
		
		for i, section in pairs(self.sections) do
			size = size + section.container.Parent.AbsoluteSize.Y + padding
		end
		
		self.container.CanvasSize = UDim2.new(0, 0, 0, size)
		self.container.ScrollBarImageTransparency = size > self.container.AbsoluteSize.Y and 0 or 1
		
		if scroll then
			utilityTween(self.container, {CanvasPosition = Vector2.new(0, self.lastPosition or 0)}, 0.2)
		end
	end
	
	function section:Resize(smooth)
	
		if self.page.library.focusedPage ~= self.page then
			return
		end
		
		local padding = 4
		local size = (4 + padding) + self.container.Title.AbsoluteSize.Y -- offset
		
		for i, module in pairs(self.modules) do
			size = size + module.AbsoluteSize.Y + padding
		end
		
		if smooth then
			utilityTween(self.container.Parent, {Size = UDim2.new(1, -10, 0, size)}, 0.05)
		else
			self.container.Parent.Size = UDim2.new(1, -10, 0, size)
			self.page:Resize()
		end
	end
	
	function section:GetModule(info)
	
		if table.find(self.modules, info) then
			return info
		end
		
		for i, module in pairs(self.modules) do
			if (module:FindFirstChild("Title") or module:FindFirstChild("TextBox", true)).Text == info then
				return module
			end
		end
		
		error("No module found under " .. tostring(info))
	end
	
	-- updates
	
	function section:UpdateButton(button, title)
		button = self:GetModule(button)
		
		button.Title.Text = title
	end
	
	function section:UpdateToggle(toggle, title, value)
		toggle = self:GetModule(toggle)
		
		local position = {
			In = UDim2.new(0, 2, 0.5, -6),
			Out = UDim2.new(0, 20, 0.5, -6)
		}
		
		local frame = toggle.Button.Frame
		value = value and "Out" or "In"
		
		if title then
			toggle.Title.Text = title
		end
		
		utilityTween(frame, {
			Size = UDim2.new(1, -22, 1, -9),
			Position = position[value] + UDim2.new(0, 0, 0, 2.5)
		}, 0.2)
		
		wait(0.1)
		utilityTween(frame, {
			Size = UDim2.new(1, -22, 1, -4),
			Position = position[value]
		}, 0.1)
	end
	
	function section:UpdateTextbox(textbox, title, value)
		textbox = self:GetModule(textbox)
		
		if title then
			textbox.Title.Text = title
		end
		
		if value then
			textbox.Button.Textbox.Text = value
		end
		
	end
	
	function section:UpdateKeybind(keybind, title, key)
		keybind = self:GetModule(keybind)
		
		local text = keybind.Button.Text
		local bind = self.binds[keybind]
		
		if title then
			keybind.Title.Text = title
		end
		
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
		
		local picker = self.colorpickers[colorpicker]
		local tab = picker.tab
		local callback = picker.callback
		
		if title then
			colorpicker.Title.Text = title
			tab.Title.Text = title
		end
		
		local color3
		local hue, sat, brightness
		
		if type(color) == "table" then -- roblox is literally retarded x2
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
		
		for i, container in pairs(tab.Container.Inputs:GetChildren()) do
			if container:IsA("ImageLabel") then
				local value = math.clamp(color3[container.Name], 0, 1) * 255
				
				container.Textbox.Text = math.floor(value)
				--callback(container.Name:lower(), value)
			end
		end
	end
	
	function section:UpdateSlider(slider, title, value, min, max, lvalue)
		slider = self:GetModule(slider)
		
		if title then
			slider.Title.Text = title
		end
		
		local bar = slider.Slider.Bar
		local percent = (mouse.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
		
		if value then -- support negative ranges
			percent = (value - min) / (max - min)
		end
		
		percent = math.clamp(percent, 0, 1)
		value = value or math.floor(min + (max - min) * percent)
		
		slider.TextBox.Text = value
		utilityTween(bar.Fill, {Size = UDim2.new(percent, 0, 1, 0)}, 0.1)
		
		if value ~= lvalue and slider.ImageTransparency == 0 then
			utilityPop(slider, 10)
		end
		
		return value
	end
	
	function section:UpdateDropdown(dropdown, title, list, callback)
		dropdown = self:GetModule(dropdown)
		
		if title then
			dropdown.Search.TextBox.Text = title
		end
		
		local entries = 0
		
		utilityPop(dropdown.Search, 10)
		
		for i, button in pairs(dropdown.List.Frame:GetChildren()) do
			if button:IsA("ImageButton") then
				button:Destroy()
			end
		end
			
		for i, value in pairs(list or {}) do
			local button = utilityCreate("ImageButton", {
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
				utilityCreate("TextLabel", {
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
		
		utilityTween(dropdown, {Size = UDim2.new(1, 0, 0, (entries == 0 and 30) or math.clamp(entries, 0, 3) * 34 + 38)}, 0.3)
		utilityTween(dropdown.Search.Button, {Rotation = list and 180 or 0}, 0.3)
		
		if entries > 3 then
		
			for i, button in pairs(dropdown.List.Frame:GetChildren()) do
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

-- Kept locally so the key system can create the window after verification.
local XevorLibrary = library


-- Loading screen and key system run before the main menu.

-- XEVOR cinematic loading screen
-- Inspired by the supplied showcase minimal black layout, cinematic title, and bottom loading readout.

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BLACK = Color3.fromRGB(3, 3, 5)
local SOFT_BLACK = Color3.fromRGB(10, 10, 14)
local PURPLE = Color3.fromRGB(143, 70, 235)
local PURPLE_LIGHT = Color3.fromRGB(211, 164, 255)
local WHITE = Color3.fromRGB(238, 236, 242)
local DIM = Color3.fromRGB(120, 116, 132)

local gui = Instance.new("ScreenGui")
gui.Name = "XevorLoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 9999
gui.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = BLACK
backdrop.BorderSizePixel = 0
backdrop.Parent = gui

local backgroundGradient = Instance.new("UIGradient")
backgroundGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 5, 13)),
	ColorSequenceKeypoint.new(0.48, BLACK),
	ColorSequenceKeypoint.new(1, SOFT_BLACK),
})
backgroundGradient.Rotation = 30
backgroundGradient.Parent = backdrop

-- Minimal corner marks give the screen a cinematic frame without clutter.
local function cornerMark(position, rotation)
	local mark = Instance.new("Frame")
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = position
	mark.Size = UDim2.fromOffset(150, 8)
	mark.Rotation = rotation
	mark.BackgroundColor3 = PURPLE
	mark.BackgroundTransparency = 0.78
	mark.BorderSizePixel = 0
	mark.Parent = backdrop

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = mark

	return mark
end

local topMark = cornerMark(UDim2.fromScale(0.94, 0.08), -48)
local bottomMark = cornerMark(UDim2.fromScale(0.06, 0.92), -48)

local versionLabel = Instance.new("TextLabel")
versionLabel.Name = "Version"
versionLabel.AnchorPoint = Vector2.new(1, 1)
versionLabel.Position = UDim2.new(1, -30, 1, -24)
versionLabel.Size = UDim2.fromOffset(160, 18)
versionLabel.BackgroundTransparency = 1
versionLabel.Font = Enum.Font.GothamBold
versionLabel.Text = "SCRIPTHUB • v1.0"
versionLabel.TextColor3 = DIM
versionLabel.TextSize = 11
versionLabel.TextXAlignment = Enum.TextXAlignment.Right
versionLabel.Parent = backdrop

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.53)
title.Size = UDim2.new(1, -120, 0, 80)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "X  E  V  O  R"
title.TextColor3 = WHITE
title.TextSize = 52
title.TextTransparency = 1
title.TextStrokeColor3 = PURPLE
title.TextStrokeTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = backdrop

local titleGlow = Instance.new("TextLabel")
titleGlow.Name = "TitleGlow"
titleGlow.AnchorPoint = Vector2.new(0.5, 0.5)
titleGlow.Position = UDim2.fromScale(0.5, 0.53)
titleGlow.Size = UDim2.new(1, -120, 0, 80)
titleGlow.BackgroundTransparency = 1
titleGlow.Font = Enum.Font.GothamBold
titleGlow.Text = "X  E  V  O  R"
titleGlow.TextColor3 = PURPLE
titleGlow.TextSize = 52
titleGlow.TextTransparency = 1
titleGlow.TextXAlignment = Enum.TextXAlignment.Center
titleGlow.ZIndex = 0
titleGlow.Parent = backdrop

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
subtitle.Position = UDim2.fromScale(0.5, 0.59)
subtitle.Size = UDim2.new(1, -120, 0, 20)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.GothamBold
subtitle.Text = "SCRIPTHUB"
subtitle.TextColor3 = PURPLE_LIGHT
subtitle.TextSize = 11
subtitle.TextTransparency = 1
subtitle.TextXAlignment = Enum.TextXAlignment.Center
subtitle.Parent = backdrop

local loader = Instance.new("Frame")
loader.Name = "Loader"
loader.AnchorPoint = Vector2.new(0.5, 1)
loader.Position = UDim2.new(0.5, 0, 1, -58)
loader.Size = UDim2.fromOffset(780, 72)
loader.BackgroundTransparency = 1
loader.Parent = backdrop

local blockHolder = Instance.new("Frame")
blockHolder.Name = "Blocks"
blockHolder.Position = UDim2.fromOffset(0, 0)
blockHolder.Size = UDim2.fromOffset(120, 16)
blockHolder.BackgroundTransparency = 1
blockHolder.Parent = loader

local blocks = {}
for index = 1, 6 do
	local block = Instance.new("Frame")
	block.Name = "Block" .. index
	block.Position = UDim2.fromOffset((index - 1) * 19, 0)
	block.Size = UDim2.fromOffset(13, 13)
	block.BackgroundColor3 = Color3.fromRGB(53, 48, 61)
	block.BorderSizePixel = 0
	block.Parent = blockHolder
	table.insert(blocks, block)
end

local stateText = Instance.new("TextLabel")
stateText.Name = "State"
stateText.Position = UDim2.fromOffset(0, 24)
stateText.Size = UDim2.fromOffset(320, 20)
stateText.BackgroundTransparency = 1
stateText.Font = Enum.Font.GothamBold
stateText.Text = "INITIALIZING..."
stateText.TextColor3 = WHITE
stateText.TextSize = 14
stateText.TextTransparency = 1
stateText.TextXAlignment = Enum.TextXAlignment.Left
stateText.Parent = loader

local percentage = Instance.new("TextLabel")
percentage.Name = "Percentage"
percentage.AnchorPoint = Vector2.new(1, 0)
percentage.Position = UDim2.new(1, 0, 0, 24)
percentage.Size = UDim2.fromOffset(110, 20)
percentage.BackgroundTransparency = 1
percentage.Font = Enum.Font.GothamBold
percentage.Text = "00%"
percentage.TextColor3 = PURPLE_LIGHT
percentage.TextSize = 14
percentage.TextTransparency = 1
percentage.TextXAlignment = Enum.TextXAlignment.Right
percentage.Parent = loader

local loadingLine = Instance.new("Frame")
loadingLine.Name = "LoadingLine"
loadingLine.Position = UDim2.fromOffset(0, 54)
loadingLine.Size = UDim2.new(1, 0, 0, 1)
loadingLine.BackgroundColor3 = Color3.fromRGB(44, 38, 53)
loadingLine.BorderSizePixel = 0
loadingLine.Parent = loader

local progressLine = Instance.new("Frame")
progressLine.Name = "ProgressLine"
progressLine.Size = UDim2.fromScale(0, 1)
progressLine.BackgroundColor3 = PURPLE
progressLine.BorderSizePixel = 0
progressLine.Parent = loadingLine

local progressGradient = Instance.new("UIGradient")
progressGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, PURPLE),
	ColorSequenceKeypoint.new(0.5, PURPLE_LIGHT),
	ColorSequenceKeypoint.new(1, PURPLE),
})
progressGradient.Offset = Vector2.new(-1, 0)
progressGradient.Parent = progressLine

local phases = {
	{value = 8, text = "INITIALIZING..."},
	{value = 24, text = "CONNECTING..."},
	{value = 43, text = "LOADING ASSETS..."},
	{value = 61, text = "SYNCHRONIZING..."},
	{value = 80, text = "PREPARING ACCESS..."},
	{value = 96, text = "FINALIZING..."},
	{value = 100, text = "READY"},
}

local function updateLoader(value, text)
	local filledBlocks = math.clamp(math.ceil(value / 100 * #blocks), 0, #blocks)
	stateText.Text = text
	percentage.Text = string.format("%02d%%", value)

	TweenService:Create(progressLine, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(value / 100, 1)
	}):Play()

	for index, block in ipairs(blocks) do
		TweenService:Create(block, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			BackgroundColor3 = index <= filledBlocks and PURPLE_LIGHT or Color3.fromRGB(53, 48, 61)
		}):Play()
	end
end

-- Show a short developer notice before the main loading animation.
local intro = Instance.new("Frame")
intro.Name = "DeveloperNotice"
intro.Size = UDim2.fromScale(1, 1)
intro.BackgroundColor3 = BLACK
intro.BorderSizePixel = 0
intro.ZIndex = 20
intro.Parent = gui

local introMessage = Instance.new("TextLabel")
introMessage.Name = "Message"
introMessage.AnchorPoint = Vector2.new(0.5, 0.5)
introMessage.Position = UDim2.fromScale(0.5, 0.5)
introMessage.Size = UDim2.new(1, -160, 0, 80)
introMessage.BackgroundTransparency = 1
introMessage.Font = Enum.Font.GothamBold
introMessage.Text = ""
introMessage.TextColor3 = WHITE
introMessage.TextSize = 15
introMessage.TextTransparency = 1
introMessage.TextWrapped = true
introMessage.TextXAlignment = Enum.TextXAlignment.Center
introMessage.TextYAlignment = Enum.TextYAlignment.Center
introMessage.ZIndex = 21
introMessage.Parent = intro

local introLine = Instance.new("Frame")
introLine.AnchorPoint = Vector2.new(0.5, 0.5)
introLine.Position = UDim2.fromScale(0.5, 0.59)
introLine.Size = UDim2.fromOffset(0, 2)
introLine.BackgroundColor3 = PURPLE
introLine.BorderSizePixel = 0
introLine.ZIndex = 21
introLine.Parent = intro

TweenService:Create(introMessage, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
	TextTransparency = 0.08,
}):Play()
TweenService:Create(introLine, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
	Size = UDim2.fromOffset(180, 2),
}):Play()

local introText = "THIS SCRIPT WAS DEVELOPED BY A SOLO DEVELOPER.\nIF YOU FIND ANY BUGS OR ERRORS, PLEASE REPORT THEM ON DISCORD <3"
for characterIndex = 1, #introText do
	introMessage.Text = introText:sub(1, characterIndex)
	task.wait(0.012)
end

-- Keep the complete message readable for three seconds before loading begins.
task.wait(3.0)

TweenService:Create(introMessage, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
	TextTransparency = 1,
}):Play()
TweenService:Create(introLine, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
	BackgroundTransparency = 1,
}):Play()
TweenService:Create(intro, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
	BackgroundTransparency = 1,
}):Play()

task.wait(0.55)
intro:Destroy()

-- Reveal the title with a cinematic fade, then run the six-second loader.
TweenService:Create(title, TweenInfo.new(1.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
	TextTransparency = 0.06,
	TextStrokeTransparency = 0.72,
	Position = UDim2.fromScale(0.5, 0.49),
}):Play()

TweenService:Create(titleGlow, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
	TextTransparency = 0.82,
	Position = UDim2.fromScale(0.5, 0.49),
}):Play()

TweenService:Create(subtitle, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
	TextTransparency = 0.18,
	Position = UDim2.fromScale(0.5, 0.55),
}):Play()

TweenService:Create(stateText, TweenInfo.new(0.7), {TextTransparency = 0.08}):Play()
TweenService:Create(percentage, TweenInfo.new(0.7), {TextTransparency = 0.08}):Play()
TweenService:Create(progressGradient, TweenInfo.new(1.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
	Offset = Vector2.new(1, 0),
}):Play()

for index, phase in ipairs(phases) do
	updateLoader(phase.value, phase.text)
	-- 5.15 seconds of loading plus the 0.85-second fade gives a six-second screen.
	task.wait(index == #phases and 0.95 or 0.7)
end

local fadeInfo = TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local fades = {}
for _, object in ipairs(backdrop:GetDescendants()) do
	if object:IsA("TextLabel") then
		table.insert(fades, TweenService:Create(object, fadeInfo, {TextTransparency = 1, TextStrokeTransparency = 1}))
	elseif object:IsA("Frame") then
		table.insert(fades, TweenService:Create(object, fadeInfo, {BackgroundTransparency = 1}))
	end
end

table.insert(fades, TweenService:Create(backdrop, fadeInfo, {BackgroundTransparency = 1}))
for _, fade in ipairs(fades) do
	fade:Play()
end

task.wait(0.85)
gui:Destroy()

-- XEVOR Key System (Standalone - Matches your library theme)
-- BlackGray dark theme with left changelog + right key panel

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

local input = game:GetService("UserInputService")
local run = game:GetService("RunService")
local tween = game:GetService("TweenService")
local tweeninfo = TweenInfo.new

local utility = {}

local themes = {
	Background = Color3.fromRGB(24, 24, 24),
	Glow = Color3.fromRGB(0, 0, 0),
	Accent = Color3.fromRGB(10, 10, 10),
	LightContrast = Color3.fromRGB(20, 20, 20),
	DarkContrast = Color3.fromRGB(14, 14, 14),
	TextColor = Color3.fromRGB(255, 255, 255),
	AccentPurple = Color3.fromRGB(180, 50, 255) -- subtle purple accent like your image
}

do
	function utilityCreate(instance, properties, children)
		local object = Instance.new(instance)
		for i, v in pairs(properties or {}) do
			object[i] = v
		end
		for _, child in pairs(children or {}) do
			child.Parent = object
		end
		return object
	end

	function utilityTween(instance, properties, duration)
		tween:Create(instance, tweeninfo(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties):Play()
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
		spawn(function()
			wait(0.2)
			object.ImageTransparency = 0
			clone:Destroy()
		end)
	end

	function utilityDraggingEnabled(frame, parent)
		parent = parent or frame
		local dragging = false
		local dragInput, mousePos, framePos

		frame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				mousePos = input.Position
				framePos = parent.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then dragging = false end
				end)
			end
		end)

		frame.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				dragInput = input
			end
		end)

		input.InputChanged:Connect(function(input)
			if input == dragInput and dragging then
				local delta = input.Position - mousePos
				parent.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
			end
		end)
	end
end

-- Key System GUI
local keySystem = utilityCreate("ScreenGui", {
	Name = "XEVOR_KeySystem",
	Parent = game.CoreGui,
	ResetOnSpawn = false
}, {
	utilityCreate("ImageLabel", { -- Main Frame
		Name = "Main",
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, -280, 0.5, -200),
		Size = UDim2.new(0, 560, 0, 400),
		Image = "rbxassetid://4641149554",
		ImageColor3 = themes.Background,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(4, 4, 296, 296),
		ZIndex = 2
	}, {
		utilityCreate("ImageLabel", {
			Name = "Glow",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, -15, 0, -15),
			Size = UDim2.new(1, 30, 1, 30),
			ZIndex = 1,
			Image = "rbxassetid://5028857084",
			ImageColor3 = themes.Glow,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(24, 24, 276, 276)
		}),
		utilityCreate("ImageLabel", { -- Top Bar
			Name = "TopBar",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 50),
			ZIndex = 5,
			Image = "rbxassetid://4595286933",
			ImageColor3 = themes.Accent,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(4, 4, 296, 296)
		}, {
			utilityCreate("TextLabel", {
				Name = "Title",
				-- Centre the label vertically within the 50px top bar. Without this
				-- anchor, the label starts halfway down the bar and overflows below it.
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 20, 0.5, 0),
				Size = UDim2.new(1, -40, 0, 50),
				ZIndex = 6,
				Font = Enum.Font.GothamBold,
				Text = "XEVOR",
				TextColor3 = themes.AccentPurple,
				TextSize = 22,
				TextXAlignment = Enum.TextXAlignment.Left
			})
		}),

		-- LEFT Changelog
		utilityCreate("ImageLabel", {
			Name = "LeftPanel",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 15, 0, 65),
			Size = UDim2.new(0.48, 0, 1, -90),
			ZIndex = 3,
			Image = "rbxassetid://5028857472",
			ImageColor3 = themes.DarkContrast,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(4, 4, 296, 296)
		}, {
			utilityCreate("TextLabel", {
				Name = "Header",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 8),
				Size = UDim2.new(1, -24, 0, 20),
				ZIndex = 4,
				Font = Enum.Font.GothamSemibold,
				Text = "Changelog",
				TextColor3 = themes.TextColor,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left
			}),
			utilityCreate("ScrollingFrame", {
				Name = "ChangelogContainer",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 10, 0, 35),
				Size = UDim2.new(1, -20, 1, -50),
				ZIndex = 4,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = themes.LightContrast,
				CanvasSize = UDim2.new(0, 0, 0, 800)
			}, {
				utilityCreate("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8)
				})
			})
		}),

		-- RIGHT Key System
		utilityCreate("ImageLabel", {
			Name = "RightPanel",
			BackgroundTransparency = 1,
			Position = UDim2.new(0.52, 0, 0, 65),
			Size = UDim2.new(0.46, 0, 1, -90),
			ZIndex = 3,
			Image = "rbxassetid://5028857472",
			ImageColor3 = themes.DarkContrast,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(4, 4, 296, 296)
		}, {
			utilityCreate("TextLabel", {
				Name = "Status",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 12),
				Size = UDim2.new(1, -24, 0, 20),
				ZIndex = 4,
				Font = Enum.Font.Gotham,
				Text = "Enter Key",
				TextColor3 = themes.TextColor,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Center
			}),
			utilityCreate("ImageLabel", { -- Key Input
				Name = "KeyInput",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 45),
				Size = UDim2.new(1, -24, 0, 36),
				ZIndex = 4,
				Image = "rbxassetid://5028857472",
				ImageColor3 = themes.LightContrast,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(2, 2, 298, 298)
			}, {
				utilityCreate("TextBox", {
					Name = "Input",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 10, 0, 0),
					Size = UDim2.new(1, -20, 1, 0),
					ZIndex = 5,
					Font = Enum.Font.GothamSemibold,
					PlaceholderText = "Paste key here...",
					Text = "",
					TextColor3 = themes.TextColor,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left
				})
			}),
			utilityCreate("ImageButton", { -- VERIFY
				Name = "VerifyBtn",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 95),
				Size = UDim2.new(1, -24, 0, 36),
				ZIndex = 4,
				Image = "rbxassetid://5028857472",
				ImageColor3 = themes.AccentPurple,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(2, 2, 298, 298)
			}, {
				utilityCreate("TextLabel", {
					Name = "Label",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					ZIndex = 5,
					Font = Enum.Font.GothamBold,
					Text = "VERIFY KEY",
					TextColor3 = themes.TextColor,
					TextSize = 14
				})
			}),
			utilityCreate("ImageButton", { -- GET KEY
				Name = "GetKeyBtn",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 145),
				Size = UDim2.new(1, -24, 0, 36),
				ZIndex = 4,
				Image = "rbxassetid://5028857472",
				ImageColor3 = themes.DarkContrast,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(2, 2, 298, 298)
			}, {
				utilityCreate("TextLabel", {
					Name = "Label",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					ZIndex = 5,
					Font = Enum.Font.GothamSemibold,
					Text = "GET KEY",
					TextColor3 = themes.TextColor,
					TextSize = 13
				})
			}),
			utilityCreate("ImageButton", { -- JOIN DISCORD
				Name = "DiscordBtn",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 195),
				Size = UDim2.new(1, -24, 0, 36),
				ZIndex = 4,
				Image = "rbxassetid://5028857472",
				ImageColor3 = themes.DarkContrast,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(2, 2, 298, 298)
			}, {
				utilityCreate("TextLabel", {
					Name = "Label",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					ZIndex = 5,
					Font = Enum.Font.GothamSemibold,
					Text = "JOIN DISCORD",
					TextColor3 = themes.TextColor,
					TextSize = 13
				})
			})
		})
	})
})

utilityDraggingEnabled(keySystem.Main.TopBar, keySystem.Main)

-- Populate Changelog (example - edit as needed)
local changelogFrame = keySystem.Main.LeftPanel.ChangelogContainer
local logs = {
	"• v1.2.3 - New UI overhaul",
	"• Added 5 new scripts",
	"• Fixed anti-cheat bypass",
	"• Performance improvements",
	"• More games supported",
	"• UI now fully customizable"
}

for _, log in ipairs(logs) do
	utilityCreate("TextLabel", {
		Parent = changelogFrame,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 5,
		Font = Enum.Font.Gotham,
		Text = log,
		TextColor3 = themes.TextColor,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true
	})
end
changelogFrame.CanvasSize = UDim2.new(0, 0, 0, #logs * 26)

-- Button logic
local keyInput = keySystem.Main.RightPanel.KeyInput.Input
local statusLabel = keySystem.Main.RightPanel.Status

keySystem.Main.RightPanel.VerifyBtn.MouseButton1Click:Connect(function()
	utilityPop(keySystem.Main.RightPanel.VerifyBtn, 8)
	local key = keyInput.Text:upper()

	-- === YOUR KEY CHECK HERE ===
	if key == "XEVOR-TEST-KEY-1234" or key == "VALIDKEY" then
		statusLabel.Text = "Key Verified ✓"
		statusLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
		wait(1.2)
		keySystem:Destroy()
		-- Open the main menu only after the key is accepted.
		local Window = XevorLibrary.new("XEVOR", {
			ToggleKey = Enum.KeyCode.RightControl
		})
		print("Key accepted! Main UI loaded. Press Right Ctrl to toggle it.")
	else
		statusLabel.Text = "Invalid Key ✕"
		statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		wait(2)
		statusLabel.Text = "Enter Key"
		statusLabel.TextColor3 = themes.TextColor
	end
end)

keySystem.Main.RightPanel.GetKeyBtn.MouseButton1Click:Connect(function()
	utilityPop(keySystem.Main.RightPanel.GetKeyBtn, 8)
	-- Open link
	setclipboard("https://yourkeysite.com")
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = "XEVOR",
		Text = "Link copied to clipboard!",
		Duration = 4
	})
end)

keySystem.Main.RightPanel.DiscordBtn.MouseButton1Click:Connect(function()
	utilityPop(keySystem.Main.RightPanel.DiscordBtn, 8)
	setclipboard("https://discord.gg/yourserver")
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = "XEVOR",
		Text = "Discord link copied!",
		Duration = 4
	})
end)

print("XEVOR Key System Loaded - BlackGray themed with changelogs")
