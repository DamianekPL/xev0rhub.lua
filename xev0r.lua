--[[
    xev0r UI Library v1.0
    Dark Theme | Key System | Tabs | Color Pickers | Multi-Game | Mobile + PC
    Key: "xev0r"
    Load: loadstring(game:HttpGet("https://raw.githubusercontent.com/..."))()
    Usage:
        local Window = xev0r:CreateWindow("Title")
        local Tab = Window:CreateTab("Tab")
        Tab:CreateButton("Click Me", function() end)
        Tab:CreateToggle("Enabled", false, function(v) end)
        Tab:CreateSlider("Speed", 16, 1, 100, function(v) end)
        Tab:CreateDropdown("Mode", {"Easy","Hard"}, function(opt) end)
        Tab:CreateTextBox("Name", "Player", function(text) end)
        Tab:CreateLabel("Hello")
        Tab:CreateColorPicker(Color3.fromRGB(255,0,0), function(color) end)
        Tab:CreateKeybind("Toggle", Enum.KeyCode.E, function(key) end)
]]

local xev0r = {}
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

-- =============== KEY SYSTEM ===============
local KEY = "xev0r"
local keyVerified = false
local keyGui = nil
local keySystemShown = false

local function showKeySystem()
    if keySystemShown then return end
    keySystemShown = true
    
    keyGui = Instance.new("ScreenGui")
    keyGui.Name = "xev0r_KeySystem"
    keyGui.ResetOnSpawn = false
    keyGui.Parent = CoreGui
    
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1,0,1,0)
    overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
    overlay.BackgroundTransparency = 0.4
    overlay.Parent = keyGui
    
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0,300,0,200)
    main.Position = UDim2.new(0.5,-150,0.5,-100)
    main.BackgroundColor3 = Color3.fromRGB(30,30,30)
    main.BorderSizePixel = 0
    main.Parent = overlay
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,0,0,30)
    title.BackgroundColor3 = Color3.fromRGB(40,40,40)
    title.Text = "xev0r Key System"
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.Parent = main
    
    local textbox = Instance.new("TextBox")
    textbox.Size = UDim2.new(1,-20,0,30)
    textbox.Position = UDim2.new(0,10,0,50)
    textbox.BackgroundColor3 = Color3.fromRGB(50,50,50)
    textbox.TextColor3 = Color3.fromRGB(255,255,255)
    textbox.PlaceholderText = "Enter key..."
    textbox.Font = Enum.Font.Gotham
    textbox.TextSize = 14
    textbox.Parent = main
    
    local submit = Instance.new("TextButton")
    submit.Size = UDim2.new(1,-20,0,30)
    submit.Position = UDim2.new(0,10,0,95)
    submit.BackgroundColor3 = Color3.fromRGB(0,150,255)
    submit.TextColor3 = Color3.fromRGB(255,255,255)
    submit.Text = "Submit"
    submit.Font = Enum.Font.GothamBold
    submit.TextSize = 14
    submit.Parent = main
    
    local errorLabel = Instance.new("TextLabel")
    errorLabel.Size = UDim2.new(1,-20,0,20)
    errorLabel.Position = UDim2.new(0,10,0,140)
    errorLabel.BackgroundTransparency = 1
    errorLabel.TextColor3 = Color3.fromRGB(255,80,80)
    errorLabel.Text = ""
    errorLabel.Font = Enum.Font.Gotham
    errorLabel.TextSize = 12
    errorLabel.Parent = main
    
    submit.MouseButton1Click:Connect(function()
        if textbox.Text == KEY then
            keyVerified = true
            keyGui:Destroy()
            keyGui = nil
            processQueue()
        else
            errorLabel.Text = "Invalid key!"
            textbox.Text = ""
        end
    end)
end

local windowQueue = {}

function processQueue()
    for _, item in ipairs(windowQueue) do
        local win = createWindowInternal(item.title)
        item.event:Fire(win)
    end
    windowQueue = {}
end

-- =============== RESPONSIVE SCALING ===============
local function getScale()
    local screenSize = workspace.CurrentCamera.ViewportSize
    if screenSize.X < 500 then
        return 1.5
    else
        return 1
    end
end

-- =============== UI CREATION HELPERS ===============
local function applyDrag(gui, frame)
    local dragging, dragStart, startPos
    local inputObject
    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            inputObject = input
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == inputObject then
            update(input)
        end
    end)
end

local function createElement(parent, class, props)
    local el = Instance.new(class)
    for k,v in pairs(props) do
        el[k] = v
    end
    el.Parent = parent
    return el
end

-- =============== WINDOW CREATION ===============
function createWindowInternal(title)
    local screen = Instance.new("ScreenGui")
    screen.Name = "xev0r_Library"
    screen.ResetOnSpawn = false
    screen.Parent = CoreGui
    
    local uiscale = Instance.new("UIScale")
    uiscale.Scale = getScale()
    uiscale.Parent = screen
    
    -- main window frame
    local window = Instance.new("Frame")
    window.Size = UDim2.new(0.4,0,0.5,0)
    window.Position = UDim2.new(0.3,0,0.25,0)
    window.BackgroundColor3 = Color3.fromRGB(35,35,35)
    window.BorderSizePixel = 0
    window.ClipsDescendants = true
    window.Parent = screen
    
    -- title bar
    local titleBar = Instance.new("TextButton")
    titleBar.Size = UDim2.new(1,0,0,30)
    titleBar.BackgroundColor3 = Color3.fromRGB(45,45,45)
    titleBar.Text = title
    titleBar.Font = Enum.Font.GothamBold
    titleBar.TextSize = 14
    titleBar.TextColor3 = Color3.fromRGB(255,255,255)
    titleBar.TextXAlignment = Enum.TextXAlignment.Left
    titleBar.Parent = window
    applyDrag(window, window) -- dragging
    
    -- close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0,30,0,30)
    closeBtn.Position = UDim2.new(1,-30,0,0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(45,45,45)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        screen:Destroy()
    end)
    
    -- tab container (horizontal)
    local tabContainer = Instance.new("Frame")
    tabContainer.Size = UDim2.new(1,0,0,25)
    tabContainer.Position = UDim2.new(0,0,0,30)
    tabContainer.BackgroundColor3 = Color3.fromRGB(50,50,50)
    tabContainer.BorderSizePixel = 0
    tabContainer.Parent = window
    
    local tabList = Instance.new("UIListLayout")
    tabList.FillDirection = Enum.FillDirection.Horizontal
    tabList.Parent = tabContainer
    
    local tabScrolling = Instance.new("ScrollingFrame")
    tabScrolling.Size = UDim2.new(1,0,1,0)
    tabScrolling.BackgroundTransparency = 1
    tabScrolling.CanvasSize = UDim2.new(0,0,0,0)
    tabScrolling.ScrollBarThickness = 0
    tabScrolling.Parent = tabContainer
    
    local tabContent = Instance.new("Frame")
    tabContent.Size = UDim2.new(1,0,1,-5)
    tabContent.Position = UDim2.new(0,0,0,55)
    tabContent.BackgroundColor3 = Color3.fromRGB(40,40,40)
    tabContent.BorderSizePixel = 0
    tabContent.Parent = window
    
    -- tab management
    local tabs = {}
    local currentTab = nil
    
    local function switchTab(tab)
        if currentTab then
            currentTab.content.Visible = false
            currentTab.button.BackgroundColor3 = Color3.fromRGB(50,50,50)
        end
        currentTab = tab
        tab.content.Visible = true
        tab.button.BackgroundColor3 = Color3.fromRGB(0,150,255)
    end
    
    -- tab creation function
    local function createTab(tabName)
        local tabButton = Instance.new("TextButton")
        tabButton.Size = UDim2.new(0,100,1,0)
        tabButton.BackgroundColor3 = Color3.fromRGB(50,50,50)
        tabButton.Text = tabName
        tabButton.TextColor3 = Color3.fromRGB(255,255,255)
        tabButton.Font = Enum.Font.Gotham
        tabButton.TextSize = 13
        tabButton.Parent = tabScrolling
        
        local content = Instance.new("ScrollingFrame")
        content.Size = UDim2.new(1,0,1,0)
        content.BackgroundTransparency = 1
        content.CanvasSize = UDim2.new(0,0,0,0)
        content.ScrollBarThickness = 2
        content.ScrollBarImageColor3 = Color3.fromRGB(0,150,255)
        content.Visible = false
        content.Parent = tabContent
        
        local contentLayout = Instance.new("UIListLayout")
        contentLayout.Padding = UDim.new(0,4)
        contentLayout.Parent = content
        
        local tab = {button = tabButton, content = content, layout = contentLayout, window = screen, name = tabName}
        table.insert(tabs, tab)
        
        tabButton.MouseButton1Click:Connect(function()
            switchTab(tab)
        end)
        
        -- if first tab, auto select
        if #tabs == 1 then
            switchTab(tab)
        end
        
        -- Auto-resize canvas
        contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            content.CanvasSize = UDim2.new(0,0,0,contentLayout.AbsoluteContentSize.Y + 10)
        end)
        
        -- ================= ELEMENT CREATORS =================
        function tab:CreateButton(text, callback)
            local btn = createElement(content, "TextButton", {
                Size = UDim2.new(1,-10,0,30),
                Position = UDim2.new(0,5,0,0),
                BackgroundColor3 = Color3.fromRGB(60,60,60),
                Text = text,
                TextColor3 = Color3.fromRGB(255,255,255),
                Font = Enum.Font.Gotham,
                TextSize = 13
            })
            btn.MouseButton1Click:Connect(callback)
            return btn
        end
        
        function tab:CreateToggle(text, default, callback)
            local frame = createElement(content, "Frame", {
                Size = UDim2.new(1,-10,0,30),
                Position = UDim2.new(0,5,0,0),
                BackgroundColor3 = Color3.fromRGB(60,60,60)
            })
            local label = createElement(frame, "TextLabel", {
                Size = UDim2.new(1,-40,1,0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Color3.fromRGB(255,255,255),
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left
            })
            local toggleBtn = createElement(frame, "TextButton", {
                Size = UDim2.new(0,30,0,20),
                Position = UDim2.new(1,-35,0.5,-10),
                BackgroundColor3 = default and Color3.fromRGB(0,150,255) or Color3.fromRGB(80,80,80),
                Text = "",
                BorderSizePixel = 0
            })
            local toggled = default
            local function update()
                toggleBtn.BackgroundColor3 = toggled and Color3.fromRGB(0,150,255) or Color3.fromRGB(80,80,80)
                callback(toggled)
            end
            toggleBtn.MouseButton1Click:Connect(function()
                toggled = not toggled
                update()
            end)
            update()
            return frame
        end
        
        function tab:CreateSlider(text, default, min, max, callback)
            local frame = createElement(content, "Frame", {
                Size = UDim2.new(1,-10,0,45),
                Position = UDim2.new(0,5,0,0),
                BackgroundColor3 = Color3.fromRGB(60,60,60)
            })
            local label = createElement(frame, "TextLabel", {
                Size = UDim2.new(1,0,0,18),
                BackgroundTransparency = 1,
                Text = text .. ": " .. default,
                TextColor3 = Color3.fromRGB(255,255,255),
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left
            })
            local sliderFrame = createElement(frame, "Frame", {
                Size = UDim2.new(1,-10,0,8),
                Position = UDim2.new(0,5,0,22),
                BackgroundColor3 = Color3.fromRGB(80,80,80),
                BorderSizePixel = 0
            })
            local fill = createElement(sliderFrame, "Frame", {
                Size = UDim2.new((default-min)/(max-min),0,1,0),
                BackgroundColor3 = Color3.fromRGB(0,150,255),
                BorderSizePixel = 0
            })
            local knob = createElement(sliderFrame, "TextButton", {
                Size = UDim2.new(0,12,0,12),
                Position = UDim2.new((default-min)/(max-min), -6, 0.5, -6),
                BackgroundColor3 = Color3.fromRGB(255,255,255),
                Text = "",
                BorderSizePixel = 0
            })
            local val = default
            local function setVal(frac)
                val = math.floor(min + (max-min)*math.clamp(frac,0,1))
                fill.Size = UDim2.new(frac,0,1,0)
                knob.Position = UDim2.new(frac, -6, 0.5, -6)
                label.Text = text .. ": " .. val
                callback(val)
            end
            local dragging = false
            knob.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local rel = (input.Position.X - sliderFrame.AbsolutePosition.X) / sliderFrame.AbsoluteSize.X
                    setVal(rel)
                end
            end)
            setVal((default-min)/(max-min))
            return frame
        end
        
        function tab:CreateDropdown(text, options, callback)
            local frame = createElement(content, "Frame", {
                Size = UDim2.new(1,-10,0,30),
                Position = UDim2.new(0,5,0,0),
                BackgroundColor3 = Color3.fromRGB(60,60,60)
            })
            local label = createElement(frame, "TextLabel", {
                Size = UDim2.new(0,80,1,0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Color3.fromRGB(255,255,255),
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left
            })
            local btn = createElement(frame, "TextButton", {
                Size = UDim2.new(1,-85,1,0),
                Position = UDim2.new(0,85,0,0),
                BackgroundColor3 = Color3.fromRGB(80,80,80),
                Text = options[1],
                TextColor3 = Color3.fromRGB(255,255,255),
                Font = Enum.Font.Gotham,
                TextSize = 13
            })
            local dropFrame = createElement(content, "Frame", {
                Size = UDim2.new(1,-10,0,0),
                Position = UDim2.new(0,5,0,0),
                BackgroundColor3 = Color3.fromRGB(70,70,70),
                ClipsDescendants = true,
                Visible = false,
                ZIndex = 5
            })
            local dropLayout = createElement(dropFrame, "UIListLayout", {})
            local expanded = false
            local function collapse()
                expanded = false
                dropFrame.Visible = false
                dropFrame.Size = UDim2.new(1,-10,0,0)
            end
            btn.MouseButton1Click:Connect(function()
                expanded = not expanded
                if expanded then
                    dropFrame.Visible = true
                    dropFrame.Size = UDim2.new(1,-10,0, 20 * #options)
                    dropFrame.ZIndex = 10
                else
                    collapse()
                end
            end)
            for _, opt in ipairs(options) do
                local optBtn = createElement(dropFrame, "TextButton", {
                    Size = UDim2.new(1,0,0,20),
                    BackgroundColor3 = Color3.fromRGB(70,70,70),
                    Text = opt,
                    TextColor3 = Color3.fromRGB(255,255,255),
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    ZIndex = 10
                })
                optBtn.MouseButton1Click:Connect(function()
                    btn.Text = opt
                    callback(opt)
                    collapse()
                end)
            end
            return frame
        end
        
        function tab:CreateTextBox(text, placeholder, callback)
            local frame = createElement(content, "Frame", {
                Size = UDim2.new(1,-10,0,30),
                Position = UDim2.new(0,5,0,0),
                BackgroundColor3 = Color3.fromRGB(60,60,60)
            })
            createElement(frame, "TextLabel", {
                Size = UDim2.new(0,80,1,0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Color3.fromRGB(255,255,255),
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left
            })
            local box = createElement(frame, "TextBox", {
                Size = UDim2.new(1,-85,1,0),
                Position = UDim2.new(0,85,0,0),
                BackgroundColor3 = Color3.fromRGB(80,80,80),
                TextColor3 = Color3.fromRGB(255,255,255),
                PlaceholderText = placeholder or "",
                Font = Enum.Font.Gotham,
                TextSize = 13
            })
            box.FocusLost:Connect(function(enterPressed)
                callback(box.Text)
            end)
            return frame
        end
        
        function tab:CreateLabel(text)
            return createElement(content, "TextLabel", {
                Size = UDim2.new(1,-10,0,20),
                Position = UDim2.new(0,5,0,0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Color3.fromRGB(200,200,200),
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left
            })
        end
        
        function tab:CreateColorPicker(defaultColor, callback)
            local currentColor = defaultColor or Color3.fromRGB(255,0,0)
            local frame = createElement(content, "Frame", {
                Size = UDim2.new(1,-10,0,30),
                Position = UDim2.new(0,5,0,0),
                BackgroundColor3 = Color3.fromRGB(60,60,60)
            })
            local preview = createElement(frame, "Frame", {
                Size = UDim2.new(0,25,0,25),
                Position = UDim2.new(0,3,0.5,-12),
                BackgroundColor3 = currentColor,
                BorderSizePixel = 0
            })
            local openBtn = createElement(frame, "TextButton", {
                Size = UDim2.new(1,-35,1,0),
                Position = UDim2.new(0,30,0,0),
                BackgroundColor3 = Color3.fromRGB(80,80,80),
                Text = "Pick Color",
                TextColor3 = Color3.fromRGB(255,255,255),
                Font = Enum.Font.Gotham,
                TextSize = 13
            })
            
            -- Color picker popup
            local popup = Instance.new("Frame")
            popup.Size = UDim2.new(0,220,0,200)
            popup.Position = UDim2.new(0.5,-110,0.5,-100)
            popup.BackgroundColor3 = Color3.fromRGB(35,35,35)
            popup.BorderSizePixel = 0
            popup.Visible = false
            popup.ZIndex = 20
            popup.Parent = screen
            
            local popTitle = createElement(popup, "TextLabel", {
                Size = UDim2.new(1,0,0,20),
                BackgroundColor3 = Color3.fromRGB(45,45,45),
                Text = "Color Picker",
                TextColor3 = Color3.fromRGB(255,255,255),
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                ZIndex = 20
            })
            
            local rSlider, rValLabel, gSlider, gValLabel, bSlider, bValLabel
            local hexBox
            local colorPreview
            
            local function updateSlidersFromColor(col)
                local r = math.floor(col.R*255)
                local g = math.floor(col.G*255)
                local b = math.floor(col.B*255)
                rSlider.Size = UDim2.new(r/255,0,1,0)
                gSlider.Size = UDim2.new(g/255,0,1,0)
                bSlider.Size = UDim2.new(b/255,0,1,0)
                rValLabel.Text = "R: "..r
                gValLabel.Text = "G: "..g
                bValLabel.Text = "B: "..b
                colorPreview.BackgroundColor3 = col
                hexBox.Text = string.format("#%02X%02X%02X", r, g, b)
            end
            
            local function readSliders()
                local r = math.clamp(tonumber(rValLabel.Text:match("%d+")) or 0,0,255)/255
                local g = math.clamp(tonumber(gValLabel.Text:match("%d+")) or 0,0,255)/255
                local b = math.clamp(tonumber(bValLabel.Text:match("%d+")) or 0,0,255)/255
                return Color3.new(r,g,b)
            end
            
            local function makeSlider(name, y)
                local label = createElement(popup, "TextLabel", {
                    Size = UDim2.new(0,30,0,15),
                    Position = UDim2.new(0,5,0,y),
                    BackgroundTransparency = 1,
                    Text = name,
                    TextColor3 = Color3.fromRGB(255,255,255),
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    ZIndex = 20
                })
                local valLabel = createElement(popup, "TextLabel", {
                    Size = UDim2.new(0,60,0,15),
                    Position = UDim2.new(0,150,0,y),
                    BackgroundTransparency = 1,
                    Text = "0",
                    TextColor3 = Color3.fromRGB(200,200,200),
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    ZIndex = 20
                })
                local bg = createElement(popup, "Frame", {
                    Size = UDim2.new(1,-40,0,10),
                    Position = UDim2.new(0,35,0,y+2),
                    BackgroundColor3 = Color3.fromRGB(60,60,60),
                    BorderSizePixel = 0,
                    ZIndex = 20
                })
                local fill = createElement(bg, "Frame", {
                    Size = UDim2.new(0.5,0,1,0),
                    BackgroundColor3 = name == "R" and Color3.fromRGB(255,0,0) or name == "G" and Color3.fromRGB(0,255,0) or Color3.fromRGB(0,0,255),
                    BorderSizePixel = 0
                })
                return bg, fill, valLabel
            end
            
            rSlider, rFill, rValLabel = makeSlider("R", 25)
            gSlider, gFill, gValLabel = makeSlider("G", 55)
            bSlider, bFill, bValLabel = makeSlider("B", 85)
            
            hexBox = createElement(popup, "TextBox", {
                Size = UDim2.new(1,-10,0,20),
                Position = UDim2.new(0,5,0,115),
                BackgroundColor3 = Color3.fromRGB(50,50,50),
                TextColor3 = Color3.fromRGB(255,255,255),
                Font = Enum.Font.Gotham,
                TextSize = 12,
                PlaceholderText = "#FFFFFF",
                ZIndex = 20
            })
            hexBox.FocusLost:Connect(function()
                local hex = hexBox.Text:gsub("#","")
                if #hex == 6 then
                    local r = tonumber(hex:sub(1,2),16) or 0
                    local g = tonumber(hex:sub(3,4),16) or 0
                    local b = tonumber(hex:sub(5,6),16) or 0
                    currentColor = Color3.fromRGB(r,g,b)
                    updateSlidersFromColor(currentColor)
                end
            end)
            
            colorPreview = createElement(popup, "Frame", {
                Size = UDim2.new(0,50,0,20),
                Position = UDim2.new(0.5,-25,0,145),
                BackgroundColor3 = currentColor,
                BorderSizePixel = 0,
                ZIndex = 20
            })
            
            local confirmBtn = createElement(popup, "TextButton", {
                Size = UDim2.new(0,60,0,20),
                Position = UDim2.new(0.5,-30,0,170),
                BackgroundColor3 = Color3.fromRGB(0,150,255),
                Text = "OK",
                TextColor3 = Color3.fromRGB(255,255,255),
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                ZIndex = 20
            })
            confirmBtn.MouseButton1Click:Connect(function()
                currentColor = readSliders()
                preview.BackgroundColor3 = currentColor
                callback(currentColor)
                popup.Visible = false
            end)
            
            -- drag for sliders
            local function setupSliderDrag(sliderFrame, fill)
                local dragging = false
                sliderFrame.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                    end
                end)
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                        currentColor = readSliders()
                        callback(currentColor)
                        preview.BackgroundColor3 = currentColor
                    end
                end)
                UserInputService.InputChanged:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        local rel = (input.Position.X - sliderFrame.AbsolutePosition.X) / sliderFrame.AbsoluteSize.X
                        rel = math.clamp(rel,0,1)
                        fill.Size = UDim2.new(rel,0,1,0)
                        updateSlidersFromColor(readSliders())
                    end
                end)
            end
            setupSliderDrag(rSlider, rFill)
            setupSliderDrag(gSlider, gFill)
            setupSliderDrag(bSlider, bFill)
            
            openBtn.MouseButton1Click:Connect(function()
                popup.Visible = not popup.Visible
                if popup.Visible then
                    updateSlidersFromColor(currentColor)
                end
            end)
            updateSlidersFromColor(currentColor)
            return frame
        end
        
        function tab:CreateKeybind(text, defaultKey, callback)
            local frame = createElement(content, "Frame", {
                Size = UDim2.new(1,-10,0,30),
                Position = UDim2.new(0,5,0,0),
                BackgroundColor3 = Color3.fromRGB(60,60,60)
            })
            local label = createElement(frame, "TextLabel", {
                Size = UDim2.new(0,80,1,0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Color3.fromRGB(255,255,255),
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left
            })
            local keyBtn = createElement(frame, "TextButton", {
                Size = UDim2.new(1,-85,1,0),
                Position = UDim2.new(0,85,0,0),
                BackgroundColor3 = Color3.fromRGB(80,80,80),
                Text = defaultKey and defaultKey.Name or "[...]",
                TextColor3 = Color3.fromRGB(255,255,255),
                Font = Enum.Font.Gotham,
                TextSize = 13
            })
            local binding = false
            local boundKey = defaultKey
            local connection
            keyBtn.MouseButton1Click:Connect(function()
                binding = true
                keyBtn.Text = "..."
                if connection then connection:Disconnect() end
                connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                    if not gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard then
                        if binding then
                            boundKey = input.KeyCode
                            keyBtn.Text = boundKey.Name
                            callback(boundKey)
                            binding = false
                            connection:Disconnect()
                        end
                    end
                end)
            end)
            return frame
        end
        
        return tab
    end
    
    local windowObj = {
        window = window,
        screen = screen,
        CreateTab = createTab
    }
    return windowObj
end

-- =============== PUBLIC API ===============
function xev0r:CreateWindow(title)
    if not keyVerified then
        local event = Instance.new("BindableEvent")
        table.insert(windowQueue, {title = title, event = event})
        showKeySystem()
        local win = event.Event:Wait()
        event:Destroy()
        return win
    else
        return createWindowInternal(title)
    end
end

-- Expose library globally
getgenv().xev0r = xev0r
return xev0r
