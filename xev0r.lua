--[[
    xev0r UI Library v2.0 – Purple Rounded Dark Theme
    Key System | Watermark (FPS/Ping) | Avatar, Username, Executor Detection
    Time Display | Get Key & Discord Links
    Load: loadstring(game:HttpGet("https://raw.githubusercontent.com/..."))()
]]

local xev0r = {}
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui") or Players.LocalPlayer:WaitForChild("PlayerGui")

-- =============== CONSTANTS & STYLE ===============
local KEY = "xev0r"
local PURPLE = Color3.fromRGB(130, 0, 255)
local DARK_BG = Color3.fromRGB(18, 18, 18)
local MEDIUM_BG = Color3.fromRGB(30, 30, 30)
local LIGHT_BG = Color3.fromRGB(45, 45, 45)
local CORNER_RADIUS = UDim.new(0, 6)

-- =============== UTILITY FUNCTIONS ===============
local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = radius or CORNER_RADIUS
    corner.Parent = parent
    return corner
end

local function getExecutor()
    local funcs = {"identifyexecutor", "getexecutorname"}
    for _, name in ipairs(funcs) do
        local success, result = pcall(function()
            return getfenv()[name]() or getgenv()[name]()
        end)
        if success and type(result) == "string" then
            return result
        end
    end
    return "Unknown"
end

local function copyToClipboard(text)
    pcall(function()
        if setclipboard then
            setclipboard(text)
        end
    end)
end

-- =============== WATERMARK (FPS & PING) ===============
local function createWatermark()
    local gui = Instance.new("ScreenGui")
    gui.Name = "xev0r_Watermark"
    gui.ResetOnSpawn = false
    gui.Parent = CoreGui

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 200, 0, 20)
    label.Position = UDim2.new(1, -210, 0, 5)
    label.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    label.BackgroundTransparency = 0.3
    label.TextColor3 = Color3.fromRGB(180, 180, 255)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = gui
    addCorner(label, UDim.new(0, 4))

    local fps = 0
    local ping = 0

    -- FPS counter
    RunService.Stepped:Connect(function(_, dt)
        fps = math.floor(1 / dt)
    end)

    -- Update display
    spawn(function()
        while gui and gui.Parent do
            ping = math.floor(Players.LocalPlayer:GetNetworkPing() * 1000)
            label.Text = string.format("xev0r | FPS: %d | Ping: %d ms", fps, ping)
            wait(0.5)
        end
    end)

    return gui
end

-- =============== KEY SYSTEM (ENHANCED) ===============
local keyVerified = false
local keyGui = nil
local keySystemShown = false

local function showKeySystem()
    if keySystemShown then return end
    keySystemShown = true

    -- Watermark appears only after key? We'll show it anyway, remove after
    local watermark = createWatermark()

    keyGui = Instance.new("ScreenGui")
    keyGui.Name = "xev0r_KeySystem"
    keyGui.ResetOnSpawn = false
    keyGui.Parent = CoreGui

    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.Parent = keyGui

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 360, 0, 300)
    main.Position = UDim2.new(0.5, -180, 0.5, -150)
    main.BackgroundColor3 = DARK_BG
    main.BorderSizePixel = 0
    main.Parent = overlay
    addCorner(main, UDim.new(0, 8))

    -- Title bar
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = PURPLE
    title.Text = "xev0r Key System"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.Parent = main
    addCorner(title, UDim.new(0, 8))
    title.ClipsDescendants = true

    -- Live time label
    local timeLabel = Instance.new("TextLabel")
    timeLabel.Size = UDim2.new(1, -10, 0, 18)
    timeLabel.Position = UDim2.new(0, 5, 0, 35)
    timeLabel.BackgroundTransparency = 1
    timeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    timeLabel.Font = Enum.Font.Gotham
    timeLabel.TextSize = 12
    timeLabel.Text = "00:00:00"
    timeLabel.Parent = main
    spawn(function()
        while keyGui and keyGui.Parent do
            local now = DateTime.now()
            timeLabel.Text = now:FormatLocalTime("HH:mm:ss", "en-us")
            wait(1)
        end
    end)

    -- Avatar + Username + Executor info
    local infoFrame = Instance.new("Frame")
    infoFrame.Size = UDim2.new(1, -10, 0, 70)
    infoFrame.Position = UDim2.new(0, 5, 0, 55)
    infoFrame.BackgroundColor3 = MEDIUM_BG
    infoFrame.BorderSizePixel = 0
    infoFrame.Parent = main
    addCorner(infoFrame)

    -- Avatar
    local avatarImage = Instance.new("ImageLabel")
    avatarImage.Size = UDim2.new(0, 60, 0, 60)
    avatarImage.Position = UDim2.new(0, 5, 0.5, -30)
    avatarImage.BackgroundTransparency = 1
    avatarImage.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    avatarImage.Parent = infoFrame
    addCorner(avatarImage, UDim.new(0, 30)) -- circular

    local player = Players.LocalPlayer
    spawn(function()
        local userId = player.UserId
        local thumbnailType = Enum.ThumbnailType.HeadShot
        local thumbnailSize = Enum.ThumbnailSize.Size420x420
        local content, isReady = Players:GetUserThumbnailAsync(userId, thumbnailType, thumbnailSize)
        avatarImage.Image = content
    end)

    -- Username & Executor labels
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -70, 0, 20)
    nameLabel.Position = UDim2.new(0, 70, 0, 8)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = infoFrame

    local execLabel = Instance.new("TextLabel")
    execLabel.Size = UDim2.new(1, -70, 0, 16)
    execLabel.Position = UDim2.new(0, 70, 0, 32)
    execLabel.BackgroundTransparency = 1
    execLabel.Text = "Executor: " .. getExecutor()
    execLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    execLabel.Font = Enum.Font.Gotham
    execLabel.TextSize = 12
    execLabel.TextXAlignment = Enum.TextXAlignment.Left
    execLabel.Parent = infoFrame

    -- Key status
    local keyStatusLabel = Instance.new("TextLabel")
    keyStatusLabel.Size = UDim2.new(1, -10, 0, 18)
    keyStatusLabel.Position = UDim2.new(0, 5, 0, 130)
    keyStatusLabel.BackgroundTransparency = 1
    keyStatusLabel.Text = "Key Status: Not verified"
    keyStatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
    keyStatusLabel.Font = Enum.Font.Gotham
    keyStatusLabel.TextSize = 12
    keyStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    keyStatusLabel.Parent = main

    -- Script status
    local scriptStatusLabel = Instance.new("TextLabel")
    scriptStatusLabel.Size = UDim2.new(1, -10, 0, 18)
    scriptStatusLabel.Position = UDim2.new(0, 5, 0, 148)
    scriptStatusLabel.BackgroundTransparency = 1
    scriptStatusLabel.Text = "Script Status: Waiting for key"
    scriptStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    scriptStatusLabel.Font = Enum.Font.Gotham
    scriptStatusLabel.TextSize = 12
    scriptStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    scriptStatusLabel.Parent = main

    -- Key input field
    local textbox = Instance.new("TextBox")
    textbox.Size = UDim2.new(1, -10, 0, 28)
    textbox.Position = UDim2.new(0, 5, 0, 175)
    textbox.BackgroundColor3 = MEDIUM_BG
    textbox.TextColor3 = Color3.fromRGB(255, 255, 255)
    textbox.PlaceholderText = "Enter key..."
    textbox.Font = Enum.Font.Gotham
    textbox.TextSize = 14
    textbox.Parent = main
    addCorner(textbox)

    local errorLabel = Instance.new("TextLabel")
    errorLabel.Size = UDim2.new(1, -10, 0, 16)
    errorLabel.Position = UDim2.new(0, 5, 0, 205)
    errorLabel.BackgroundTransparency = 1
    errorLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    errorLabel.Text = ""
    errorLabel.Font = Enum.Font.Gotham
    errorLabel.TextSize = 11
    errorLabel.Parent = main

    -- Buttons row
    local buttonRow = Instance.new("Frame")
    buttonRow.Size = UDim2.new(1, -10, 0, 28)
    buttonRow.Position = UDim2.new(0, 5, 0, 225)
    buttonRow.BackgroundTransparency = 1
    buttonRow.Parent = main

    local submitBtn = Instance.new("TextButton")
    submitBtn.Size = UDim2.new(1, 0, 1, 0)
    submitBtn.BackgroundColor3 = PURPLE
    submitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    submitBtn.Text = "Submit"
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.TextSize = 14
    submitBtn.Parent = buttonRow
    addCorner(submitBtn)

    local linkBtnFrame = Instance.new("Frame")
    linkBtnFrame.Size = UDim2.new(1, -10, 0, 28)
    linkBtnFrame.Position = UDim2.new(0, 5, 0, 258)
    linkBtnFrame.BackgroundTransparency = 1
    linkBtnFrame.Parent = main

    local getKeyBtn = Instance.new("TextButton")
    getKeyBtn.Size = UDim2.new(0.5, -5, 1, 0)
    getKeyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    getKeyBtn.Text = "Get Key"
    getKeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    getKeyBtn.Font = Enum.Font.Gotham
    getKeyBtn.TextSize = 13
    getKeyBtn.Parent = linkBtnFrame
    addCorner(getKeyBtn)

    local discordBtn = Instance.new("TextButton")
    discordBtn.Size = UDim2.new(0.5, -5, 1, 0)
    discordBtn.Position = UDim2.new(0.5, 5, 0, 0)
    discordBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    discordBtn.Text = "Join Discord"
    discordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    discordBtn.Font = Enum.Font.Gotham
    discordBtn.TextSize = 13
    discordBtn.Parent = linkBtnFrame
    addCorner(discordBtn)

    -- Link button actions (copy to clipboard)
    getKeyBtn.MouseButton1Click:Connect(function()
        copyToClipboard("https://your-key-site.com")  -- change to real link
        errorLabel.Text = "Get Key link copied!"
        wait(2)
        errorLabel.Text = ""
    end)
    discordBtn.MouseButton1Click:Connect(function()
        copyToClipboard("https://discord.gg/example") -- change to real invite
        errorLabel.Text = "Discord link copied!"
        wait(2)
        errorLabel.Text = ""
    end)

    -- Submit action
    submitBtn.MouseButton1Click:Connect(function()
        if textbox.Text == KEY then
            keyVerified = true
            scriptStatusLabel.Text = "Script Status: Verified"
            scriptStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            keyStatusLabel.Text = "Key Status: Verified"
            keyStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            wait(0.5)
            keyGui:Destroy()
            keyGui = nil
            -- Keep watermark, but it will continue working
            processQueue()
        else
            keyStatusLabel.Text = "Key Status: Invalid"
            keyStatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
            errorLabel.Text = "Invalid key!"
            textbox.Text = ""
        end
    end)
end

-- =============== LIBRARY INITIALISATION ===============
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
        return 1.5  -- mobile scale
    else
        return 1
    end
end

-- =============== UI ELEMENTS CREATION ===============
local function createElement(parent, class, props)
    local el = Instance.new(class)
    for k, v in pairs(props) do
        el[k] = v
    end
    el.Parent = parent
    return el
end

-- Apply dragging functionality
local function applyDrag(gui, frame)
    local dragging, dragStart, startPos
    local inputObject
    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
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

-- =============== WINDOW CREATION ===============
function createWindowInternal(title)
    local screen = Instance.new("ScreenGui")
    screen.Name = "xev0r_Library"
    screen.ResetOnSpawn = false
    screen.Parent = CoreGui

    local uiscale = Instance.new("UIScale")
    uiscale.Scale = getScale()
    uiscale.Parent = screen

    -- Main window
    local window = Instance.new("Frame")
    window.Size = UDim2.new(0.42, 0, 0.55, 0)
    window.Position = UDim2.new(0.29, 0, 0.25, 0)
    window.BackgroundColor3 = DARK_BG
    window.BorderSizePixel = 0
    window.ClipsDescendants = false
    window.Parent = screen
    addCorner(window, UDim.new(0, 8))

    -- Title bar (drag area)
    local titleBar = Instance.new("TextButton")
    titleBar.Size = UDim2.new(1, 0, 0, 32)
    titleBar.BackgroundColor3 = PURPLE
    titleBar.Text = title
    titleBar.Font = Enum.Font.GothamBold
    titleBar.TextSize = 15
    titleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleBar.TextXAlignment = Enum.TextXAlignment.Left
    titleBar.Parent = window
    addCorner(titleBar, UDim.new(0, 8))
    applyDrag(window, window)  -- drag the whole window from title bar

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -30, 0, 1)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Parent = titleBar
    addCorner(closeBtn, UDim.new(0, 6))
    closeBtn.MouseButton1Click:Connect(function()
        screen:Destroy()
    end)

    -- Tab container
    local tabContainer = Instance.new("Frame")
    tabContainer.Size = UDim2.new(1, 0, 0, 28)
    tabContainer.Position = UDim2.new(0, 0, 0, 33)
    tabContainer.BackgroundColor3 = MEDIUM_BG
    tabContainer.BorderSizePixel = 0
    tabContainer.Parent = window

    local tabScrolling = Instance.new("ScrollingFrame")
    tabScrolling.Size = UDim2.new(1, 0, 1, 0)
    tabScrolling.BackgroundTransparency = 1
    tabScrolling.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabScrolling.ScrollBarThickness = 0
    tabScrolling.Parent = tabContainer

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Parent = tabScrolling

    -- Tab content area
    local tabContent = Instance.new("Frame")
    tabContent.Size = UDim2.new(1, 0, 1, -61)
    tabContent.Position = UDim2.new(0, 0, 0, 61)
    tabContent.BackgroundColor3 = DARK_BG
    tabContent.BorderSizePixel = 0
    tabContent.Parent = window

    -- Tab management
    local tabs = {}
    local currentTab = nil

    local function switchTab(tab)
        if currentTab then
            currentTab.content.Visible = false
            currentTab.button.BackgroundColor3 = MEDIUM_BG
        end
        currentTab = tab
        tab.content.Visible = true
        tab.button.BackgroundColor3 = PURPLE
    end

    -- Tab creation function
    local function createTab(tabName)
        local tabButton = Instance.new("TextButton")
        tabButton.Size = UDim2.new(0, 100, 1, 0)
        tabButton.BackgroundColor3 = MEDIUM_BG
        tabButton.Text = tabName
        tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        tabButton.Font = Enum.Font.GothamSemibold
        tabButton.TextSize = 13
        tabButton.Parent = tabScrolling
        addCorner(tabButton)

        local content = Instance.new("ScrollingFrame")
        content.Size = UDim2.new(1, 0, 1, 0)
        content.BackgroundTransparency = 1
        content.CanvasSize = UDim2.new(0, 0, 0, 0)
        content.ScrollBarThickness = 3
        content.ScrollBarImageColor3 = PURPLE
        content.Visible = false
        content.Parent = tabContent

        local contentLayout = Instance.new("UIListLayout")
        contentLayout.Padding = UDim.new(0, 5)
        contentLayout.Parent = content

        local tab = {button = tabButton, content = content, layout = contentLayout, window = screen, name = tabName}
        table.insert(tabs, tab)

        tabButton.MouseButton1Click:Connect(function()
            switchTab(tab)
        end)

        -- Auto-select first tab
        if #tabs == 1 then
            switchTab(tab)
        end

        -- Auto-resize canvas
        contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            content.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 10)
        end)

        -- ================= ELEMENT CREATORS =================
        local function defaultBtn(parent, text, callback)
            local btn = createElement(parent, "TextButton", {
                Size = UDim2.new(1, -10, 0, 30),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundColor3 = LIGHT_BG,
                Text = text,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.Gotham,
                TextSize = 13
            })
            addCorner(btn)
            btn.MouseButton1Click:Connect(callback)
            return btn
        end

        function tab:CreateButton(text, callback)
            return defaultBtn(content, text, callback)
        end

        function tab:CreateToggle(text, default, callback)
            local frame = createElement(content, "Frame", {
                Size = UDim2.new(1, -10, 0, 30),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundColor3 = LIGHT_BG,
            })
            addCorner(frame)
            local label = createElement(frame, "TextLabel", {
                Size = UDim2.new(1, -40, 1, 0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left
            })
            local toggleBtn = createElement(frame, "TextButton", {
                Size = UDim2.new(0, 30, 0, 20),
                Position = UDim2.new(1, -35, 0.5, -10),
                BackgroundColor3 = default and PURPLE or Color3.fromRGB(80, 80, 80),
                Text = "",
                BorderSizePixel = 0
            })
            addCorner(toggleBtn, UDim.new(0, 10))
            local toggled = default
            local function update()
                toggleBtn.BackgroundColor3 = toggled and PURPLE or Color3.fromRGB(80, 80, 80)
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
                Size = UDim2.new(1, -10, 0, 45),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundColor3 = LIGHT_BG,
            })
            addCorner(frame)
            local label = createElement(frame, "TextLabel", {
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                Text = text .. ": " .. default,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left
            })
            local sliderFrame = createElement(frame, "Frame", {
                Size = UDim2.new(1, -10, 0, 8),
                Position = UDim2.new(0, 5, 0, 22),
                BackgroundColor3 = Color3.fromRGB(80, 80, 80),
                BorderSizePixel = 0
            })
            addCorner(sliderFrame, UDim.new(0, 4))
            local fill = createElement(sliderFrame, "Frame", {
                Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
                BackgroundColor3 = PURPLE,
                BorderSizePixel = 0
            })
            addCorner(fill, UDim.new(0, 4))
            local knob = createElement(sliderFrame, "TextButton", {
                Size = UDim2.new(0, 12, 0, 12),
                Position = UDim2.new((default - min) / (max - min), -6, 0.5, -6),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                Text = "",
                BorderSizePixel = 0
            })
            addCorner(knob, UDim.new(0, 6))
            local val = default
            local function setVal(frac)
                val = math.floor(min + (max - min) * math.clamp(frac, 0, 1))
                fill.Size = UDim2.new(frac, 0, 1, 0)
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
            setVal((default - min) / (max - min))
            return frame
        end

        function tab:CreateDropdown(text, options, callback)
            local frame = createElement(content, "Frame", {
                Size = UDim2.new(1, -10, 0, 30),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundColor3 = LIGHT_BG,
            })
            addCorner(frame)
            local label = createElement(frame, "TextLabel", {
                Size = UDim2.new(0, 80, 1, 0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left
            })
            local btn = createElement(frame, "TextButton", {
                Size = UDim2.new(1, -85, 1, 0),
                Position = UDim2.new(0, 85, 0, 0),
                BackgroundColor3 = Color3.fromRGB(80, 80, 80),
                Text = options[1],
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.Gotham,
                TextSize = 13
            })
            addCorner(btn)
            local dropFrame = createElement(content, "Frame", {
                Size = UDim2.new(1, -10, 0, 0),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundColor3 = MEDIUM_BG,
                ClipsDescendants = true,
                Visible = false,
                ZIndex = 5
            })
            addCorner(dropFrame)
            local dropLayout = createElement(dropFrame, "UIListLayout", {})
            local expanded = false
            local function collapse()
                expanded = false
                dropFrame.Visible = false
                dropFrame.Size = UDim2.new(1, -10, 0, 0)
            end
            btn.MouseButton1Click:Connect(function()
                expanded = not expanded
                if expanded then
                    dropFrame.Visible = true
                    dropFrame.Size = UDim2.new(1, -10, 0, 20 * #options)
                    dropFrame.ZIndex = 10
                else
                    collapse()
                end
            end)
            for _, opt in ipairs(options) do
                local optBtn = createElement(dropFrame, "TextButton", {
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundColor3 = MEDIUM_BG,
                    Text = opt,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    ZIndex = 10
                })
                addCorner(optBtn)
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
                Size = UDim2.new(1, -10, 0, 30),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundColor3 = LIGHT_BG,
            })
            addCorner(frame)
            createElement(frame, "TextLabel", {
                Size = UDim2.new(0, 80, 1, 0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left
            })
            local box = createElement(frame, "TextBox", {
                Size = UDim2.new(1, -85, 1, 0),
                Position = UDim2.new(0, 85, 0, 0),
                BackgroundColor3 = Color3.fromRGB(80, 80, 80),
                TextColor3 = Color3.fromRGB(255, 255, 255),
                PlaceholderText = placeholder or "",
                Font = Enum.Font.Gotham,
                TextSize = 13
            })
            addCorner(box)
            box.FocusLost:Connect(function(enterPressed)
                callback(box.Text)
            end)
            return frame
        end

        function tab:CreateLabel(text)
            return createElement(content, "TextLabel", {
                Size = UDim2.new(1, -10, 0, 20),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Color3.fromRGB(200, 200, 200),
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left
            })
        end

        function tab:CreateColorPicker(defaultColor, callback)
            local currentColor = defaultColor or Color3.fromRGB(255, 0, 0)
            local frame = createElement(content, "Frame", {
                Size = UDim2.new(1, -10, 0, 30),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundColor3 = LIGHT_BG,
            })
            addCorner(frame)
            local preview = createElement(frame, "Frame", {
                Size = UDim2.new(0, 25, 0, 25),
                Position = UDim2.new(0, 3, 0.5, -12),
                BackgroundColor3 = currentColor,
                BorderSizePixel = 0
            })
            addCorner(preview, UDim.new(0, 4))
            local openBtn = createElement(frame, "TextButton", {
                Size = UDim2.new(1, -35, 1, 0),
                Position = UDim2.new(0, 30, 0, 0),
                BackgroundColor3 = Color3.fromRGB(80, 80, 80),
                Text = "Pick Color",
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.Gotham,
                TextSize = 13
            })
            addCorner(openBtn)

            -- Color picker popup
            local popup = Instance.new("Frame")
            popup.Size = UDim2.new(0, 220, 0, 200)
            popup.Position = UDim2.new(0.5, -110, 0.5, -100)
            popup.BackgroundColor3 = DARK_BG
            popup.BorderSizePixel = 0
            popup.Visible = false
            popup.ZIndex = 20
            popup.Parent = screen
            addCorner(popup, UDim.new(0, 8))

            local popTitle = createElement(popup, "TextLabel", {
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundColor3 = PURPLE,
                Text = "Color Picker",
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                ZIndex = 20
            })
            addCorner(popTitle, UDim.new(0, 8))

            local rSlider, rValLabel, gSlider, gValLabel, bSlider, bValLabel
            local hexBox
            local colorPreview

            local function updateSlidersFromColor(col)
                local r = math.floor(col.R * 255)
                local g = math.floor(col.G * 255)
                local b = math.floor(col.B * 255)
                rValLabel.Text = "R: " .. r
                gValLabel.Text = "G: " .. g
                bValLabel.Text = "B: " .. b
                colorPreview.BackgroundColor3 = col
                hexBox.Text = string.format("#%02X%02X%02X", r, g, b)
            end

            local function readSliders()
                local r = math.clamp(tonumber(rValLabel.Text:match("%d+")) or 0, 0, 255) / 255
                local g = math.clamp(tonumber(gValLabel.Text:match("%d+")) or 0, 0, 255) / 255
                local b = math.clamp(tonumber(bValLabel.Text:match("%d+")) or 0, 0, 255) / 255
                return Color3.new(r, g, b)
            end

            local function makeSlider(name, y)
                local label = createElement(popup, "TextLabel", {
                    Size = UDim2.new(0, 30, 0, 15),
                    Position = UDim2.new(0, 5, 0, y),
                    BackgroundTransparency = 1,
                    Text = name,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    ZIndex = 20
                })
                local valLabel = createElement(popup, "TextLabel", {
                    Size = UDim2.new(0, 60, 0, 15),
                    Position = UDim2.new(0, 150, 0, y),
                    BackgroundTransparency = 1,
                    Text = "0",
                    TextColor3 = Color3.fromRGB(200, 200, 200),
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    ZIndex = 20
                })
                local bg = createElement(popup, "Frame", {
                    Size = UDim2.new(1, -40, 0, 10),
                    Position = UDim2.new(0, 35, 0, y + 2),
                    BackgroundColor3 = MEDIUM_BG,
                    BorderSizePixel = 0,
                    ZIndex = 20
                })
                addCorner(bg, UDim.new(0, 4))
                local fill = createElement(bg, "Frame", {
                    Size = UDim2.new(0.5, 0, 1, 0),
                    BackgroundColor3 = name == "R" and Color3.fromRGB(255, 0, 0) or name == "G" and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(0, 0, 255),
                    BorderSizePixel = 0
                })
                addCorner(fill, UDim.new(0, 4))
                return bg, fill, valLabel
            end

            rSlider, _, rValLabel = makeSlider("R", 25)
            gSlider, _, gValLabel = makeSlider("G", 55)
            bSlider, _, bValLabel = makeSlider("B", 85)

            hexBox = createElement(popup, "TextBox", {
                Size = UDim2.new(1, -10, 0, 20),
                Position = UDim2.new(0, 5, 0, 115),
                BackgroundColor3 = MEDIUM_BG,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.Gotham,
                TextSize = 12,
                PlaceholderText = "#FFFFFF",
                ZIndex = 20
            })
            addCorner(hexBox)
            hexBox.FocusLost:Connect(function()
                local hex = hexBox.Text:gsub("#", "")
                if #hex == 6 then
                    local r = tonumber(hex:sub(1, 2), 16) or 0
                    local g = tonumber(hex:sub(3, 4), 16) or 0
                    local b = tonumber(hex:sub(5, 6), 16) or 0
                    currentColor = Color3.fromRGB(r, g, b)
                    updateSlidersFromColor(currentColor)
                end
            end)

            colorPreview = createElement(popup, "Frame", {
                Size = UDim2.new(0, 50, 0, 20),
                Position = UDim2.new(0.5, -25, 0, 145),
                BackgroundColor3 = currentColor,
                BorderSizePixel = 0,
                ZIndex = 20
            })
            addCorner(colorPreview, UDim.new(0, 4))

            local confirmBtn = createElement(popup, "TextButton", {
                Size = UDim2.new(0, 60, 0, 20),
                Position = UDim2.new(0.5, -30, 0, 170),
                BackgroundColor3 = PURPLE,
                Text = "OK",
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                ZIndex = 20
            })
            addCorner(confirmBtn)
            confirmBtn.MouseButton1Click:Connect(function()
                currentColor = readSliders()
                preview.BackgroundColor3 = currentColor
                callback(currentColor)
                popup.Visible = false
            end)

            -- Slider drag logic
            local function setupSliderDrag(sliderFrame, fill, valLabel)
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
                        rel = math.clamp(rel, 0, 1)
                        fill.Size = UDim2.new(rel, 0, 1, 0)
                        updateSlidersFromColor(readSliders())
                    end
                end)
            end
            setupSliderDrag(rSlider, _, rValLabel)
            setupSliderDrag(gSlider, _, gValLabel)
            setupSliderDrag(bSlider, _, bValLabel)

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
                Size = UDim2.new(1, -10, 0, 30),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundColor3 = LIGHT_BG,
            })
            addCorner(frame)
            local label = createElement(frame, "TextLabel", {
                Size = UDim2.new(0, 80, 1, 0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left
            })
            local keyBtn = createElement(frame, "TextButton", {
                Size = UDim2.new(1, -85, 1, 0),
                Position = UDim2.new(0, 85, 0, 0),
                BackgroundColor3 = Color3.fromRGB(80, 80, 80),
                Text = defaultKey and defaultKey.Name or "[...]",
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.Gotham,
                TextSize = 13
            })
            addCorner(keyBtn)
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

getgenv().xev0r = xev0r
return xev0r
