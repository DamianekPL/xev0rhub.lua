--[[

    xev0r UI Library v2.1
    Purple Rounded Dark Theme
    Modern API, working window flow, cleaner visuals

]]

local xev0r = {}
xev0r.__index = xev0r

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local DEFAULT_THEME = {
    Main = Color3.fromRGB(18, 18, 18),
    Panel = Color3.fromRGB(30, 30, 30),
    Surface = Color3.fromRGB(45, 45, 45),
    Accent = Color3.fromRGB(130, 0, 255),
    AccentSoft = Color3.fromRGB(160, 75, 255),
    Success = Color3.fromRGB(85, 220, 120),
    Error = Color3.fromRGB(255, 100, 100),
    Text = Color3.fromRGB(255, 255, 255),
    Muted = Color3.fromRGB(190, 190, 190),
    Border = Color3.fromRGB(255, 255, 255),
}

local function create(className, parent, props)
    local inst = Instance.new(className)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    inst.Parent = parent
    return inst
end

local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = radius or UDim.new(0, 8)
    corner.Parent = parent
    return corner
end

local function addStroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(255, 255, 255)
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0
    stroke.Parent = parent
    return stroke
end

local function safeCall(fn)
    local ok, result = pcall(fn)
    if ok then
        return result
    end
    return nil
end

local function createBlurEffect(size)
    local blur = Instance.new("BlurEffect")
    blur.Size = size or 12
    blur.Enabled = true
    blur.Parent = Lighting
    return blur
end

local function getExecutor()
    local env = getgenv and getgenv() or {}
    local fenv = (getfenv and getfenv()) or {}

    local names = { "identifyexecutor", "getexecutorname" }
    for _, name in ipairs(names) do
        local fn = env[name] or fenv[name]
        if type(fn) == "function" then
            local result = safeCall(fn)
            if type(result) == "string" and result ~= "" then
                return result
            end
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

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function createShadow(parent, transparency)
    local shadow = create("ImageLabel", parent, {
        Name = "Shadow",
        BackgroundTransparency = 1,
        Image = "rbxassetid://1316045217",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = transparency or 0.55,
        Size = UDim2.new(1, 24, 1, 24),
        Position = UDim2.new(0, -12, 0, -12),
        ZIndex = 0,
    })
    return shadow
end

local function applyDrag(titleBar, frame)
    local dragging = false
    local dragStart
    local startPos

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)

    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function createWatermark(theme)
    local gui = create("ScreenGui", CoreGui, {
        Name = "xev0r_Watermark",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    local panel = create("Frame", gui, {
        Size = UDim2.new(0, 210, 0, 24),
        Position = UDim2.new(1, -220, 0, 6),
        BackgroundColor3 = theme.Main,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
    })
    addCorner(panel, UDim.new(0, 6))
    addStroke(panel, theme.AccentSoft, 1, 0.2)
    createShadow(panel, 0.65)

    local label = create("TextLabel", panel, {
        Size = UDim2.new(1, -10, 1, -10),
        Position = UDim2.new(0, 5, 0, 5),
        BackgroundTransparency = 1,
        Text = "xev0r • 0 FPS • 0 ms",
        TextColor3 = theme.Muted,
        Font = Enum.Font.GothamSemibold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local fps = 0
    local ping = 0
    local frameCounter = 0

    RunService.RenderStepped:Connect(function(_, dt)
        frameCounter = frameCounter + 1
        if type(dt) == "number" and dt > 0 then
            fps = math.max(0, math.floor(1 / dt))
        end
    end)

    task.spawn(function()
        while gui and gui.Parent do
            local sampledFrames = frameCounter
            frameCounter = 0
            if sampledFrames > 0 then
                fps = math.max(0, math.floor(sampledFrames / 0.4))
            end

            ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
            label.Text = string.format("xev0r • %s • %d FPS • %d ms", getExecutor(), fps, ping)
            task.wait(0.4)
        end
    end)

    return gui
end

local function createKeySystem(self)
    if self.keySystemShown then
        return
    end

    self.keySystemShown = true

    local keyGui = create("ScreenGui", CoreGui, {
        Name = "xev0r_KeySystem",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    if self.keyBlur and self.keyBlur.Parent then
        self.keyBlur:Destroy()
    end

    self.keyBlur = createBlurEffect(12)

    local overlay = create("Frame", keyGui, {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
    })

    local panel = create("Frame", overlay, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.45, 0),
        Size = UDim2.new(0, 400, 0, 360),
        BackgroundColor3 = self.theme.Main,
        BorderSizePixel = 0,
    })
    addCorner(panel, UDim.new(0, 12))
    addStroke(panel, self.theme.AccentSoft, 1, 0.25)
    createShadow(panel, 0.7)

    local introTween = TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.5, 0),
    })
    introTween:Play()

    local top = create("Frame", panel, {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = self.theme.Accent,
        BorderSizePixel = 0,
    })
    addCorner(top, UDim.new(0, 12))

    local title = create("TextLabel", top, {
        Size = UDim2.new(1, -10, 1, 0),
        Position = UDim2.new(0, 5, 0, 0),
        BackgroundTransparency = 1,
        Text = "xev0r Key System",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local clock = create("TextLabel", panel, {
        Size = UDim2.new(1, -14, 0, 18),
        Position = UDim2.new(0, 7, 0, 54),
        BackgroundTransparency = 1,
        Text = "00:00:00",
        TextColor3 = self.theme.Muted,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    task.spawn(function()
        while keyGui and keyGui.Parent do
            local now = DateTime.now()
            clock.Text = now:FormatLocalTime("HH:mm:ss", "en-us")
            task.wait(1)
        end
    end)

    local infoFrame = create("Frame", panel, {
        Size = UDim2.new(1, -14, 0, 86),
        Position = UDim2.new(0, 7, 0, 78),
        BackgroundColor3 = self.theme.Panel,
        BorderSizePixel = 0,
    })
    addCorner(infoFrame, UDim.new(0, 10))
    addStroke(infoFrame, self.theme.Border, 1, 0.9)

    local avatar = create("ImageLabel", infoFrame, {
        Size = UDim2.new(0, 60, 0, 60),
        Position = UDim2.new(0, 6, 0.5, -30),
        BackgroundTransparency = 1,
        Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        BorderSizePixel = 0,
    })
    addCorner(avatar, UDim.new(0, 30))

    task.spawn(function()
        local content, _ = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
        avatar.Image = content
    end)

    local nameLabel = create("TextLabel", infoFrame, {
        Size = UDim2.new(1, -78, 0, 22),
        Position = UDim2.new(0, 74, 0, 8),
        BackgroundTransparency = 1,
        Text = LocalPlayer.Name,
        TextColor3 = self.theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local execLabel = create("TextLabel", infoFrame, {
        Size = UDim2.new(1, -78, 0, 18),
        Position = UDim2.new(0, 74, 0, 34),
        BackgroundTransparency = 1,
        Text = "Executor: " .. getExecutor(),
        TextColor3 = self.theme.Muted,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local keyStatus = create("TextLabel", panel, {
        Size = UDim2.new(1, -14, 0, 18),
        Position = UDim2.new(0, 7, 0, 176),
        BackgroundTransparency = 1,
        Text = "Key Status: Not verified",
        TextColor3 = self.theme.Error,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local scriptStatus = create("TextLabel", panel, {
        Size = UDim2.new(1, -14, 0, 18),
        Position = UDim2.new(0, 7, 0, 198),
        BackgroundTransparency = 1,
        Text = "Script Status: Waiting for key",
        TextColor3 = Color3.fromRGB(255, 200, 90),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local box = create("TextBox", panel, {
        Size = UDim2.new(1, -14, 0, 30),
        Position = UDim2.new(0, 7, 0, 224),
        BackgroundColor3 = self.theme.Panel,
        BorderSizePixel = 0,
        PlaceholderText = "Enter key...",
        Text = "",
        TextColor3 = self.theme.Text,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        ClearTextOnFocus = false,
    })
    addCorner(box, UDim.new(0, 8))
    addStroke(box, self.theme.AccentSoft, 1, 0.5)

    local errorLabel = create("TextLabel", panel, {
        Size = UDim2.new(1, -14, 0, 16),
        Position = UDim2.new(0, 7, 0, 262),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = self.theme.Error,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local submitBtn = create("TextButton", panel, {
        Size = UDim2.new(1, -14, 0, 36),
        Position = UDim2.new(0, 7, 0, 286),
        BackgroundColor3 = self.theme.Accent,
        Text = "Submit",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        BorderSizePixel = 0,
    })
    addCorner(submitBtn, UDim.new(0, 8))
    addStroke(submitBtn, self.theme.AccentSoft, 1, 0.25)

    local linkFrame = create("Frame", panel, {
        Size = UDim2.new(1, -14, 0, 34),
        Position = UDim2.new(0, 7, 0, 326),
        BackgroundTransparency = 1,
    })

    local getKeyBtn = create("TextButton", linkFrame, {
        Size = UDim2.new(0.5, -4, 1, 0),
        BackgroundColor3 = self.theme.Surface,
        Text = "Get Key",
        TextColor3 = self.theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        BorderSizePixel = 0,
    })
    addCorner(getKeyBtn, UDim.new(0, 8))

    local discordBtn = create("TextButton", linkFrame, {
        Size = UDim2.new(0.5, -4, 1, 0),
        Position = UDim2.new(0.5, 4, 0, 0),
        BackgroundColor3 = self.theme.Surface,
        Text = "Join Discord",
        TextColor3 = self.theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        BorderSizePixel = 0,
    })
    addCorner(discordBtn, UDim.new(0, 8))

    local function animateButton(btn, colorNormal, colorPressed)
        btn.MouseButton1Down:Connect(function()
            btn.BackgroundColor3 = colorPressed
        end)
        btn.MouseButton1Up:Connect(function()
            btn.BackgroundColor3 = colorNormal
        end)
    end

    animateButton(submitBtn, self.theme.Accent, self.theme.AccentSoft)
    animateButton(getKeyBtn, self.theme.Surface, Color3.fromRGB(65, 65, 65))
    animateButton(discordBtn, self.theme.Surface, Color3.fromRGB(65, 65, 65))

    getKeyBtn.MouseButton1Click:Connect(function()
        copyToClipboard("https://your-key-site.com")
        errorLabel.Text = "Get Key link copied!"
        task.delay(2, function()
            errorLabel.Text = ""
        end)
    end)

    discordBtn.MouseButton1Click:Connect(function()
        copyToClipboard("https://discord.gg/example")
        errorLabel.Text = "Discord link copied!"
        task.delay(2, function()
            errorLabel.Text = ""
        end)
    end)

    submitBtn.MouseButton1Click:Connect(function()
        if string.lower(box.Text or "") == string.lower(self.key) then
            self.keyVerified = true
            keyStatus.Text = "Key Status: Verified"
            keyStatus.TextColor3 = self.theme.Success
            scriptStatus.Text = "Script Status: Verified"
            scriptStatus.TextColor3 = self.theme.Success

            if not self.watermark or not self.watermark.Parent then
                self.watermark = createWatermark(self.theme)
            end

            task.delay(0.35, function()
                if self.keyBlur and self.keyBlur.Parent then
                    self.keyBlur:Destroy()
                end
                keyGui:Destroy()
                self.keySystemShown = false
                self:FlushQueuedWindows()
            end)
        else
            keyStatus.Text = "Key Status: Invalid"
            keyStatus.TextColor3 = self.theme.Error
            errorLabel.Text = "Invalid key!"
            box.Text = ""
        end
    end)

    self.keyGui = keyGui
end

function xev0r.new(options)
    options = options or {}

    local self = setmetatable({
        key = options.key or "xev0r",
        theme = options.theme or DEFAULT_THEME,
        keyVerified = false,
        keySystemShown = false,
        keyGui = nil,
        watermark = nil,
        pendingWindows = {},
    }, xev0r)

    return self
end

function xev0r:CreateWindow(title)
    if not self.keyVerified then
        local event = Instance.new("BindableEvent")
        table.insert(self.pendingWindows, { title = title, event = event })
        createKeySystem(self)
        local win = event.Event:Wait()
        event:Destroy()
        return win
    end

    return self:_CreateWindowInternal(title)
end

function xev0r:FlushQueuedWindows()
    for _, item in ipairs(self.pendingWindows) do
        local win = self:_CreateWindowInternal(item.title)
        item.event:Fire(win)
    end
    self.pendingWindows = {}
end

function xev0r:_CreateWindowInternal(title)
    local screen = create("ScreenGui", CoreGui, {
        Name = "xev0r_Library",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    local uiScale = create("UIScale", screen, {
        Scale = 1,
    })

    local window = create("Frame", screen, {
        Size = UDim2.new(0.42, 0, 0.55, 0),
        Position = UDim2.new(0.29, 0, 0.25, 0),
        BackgroundColor3 = self.theme.Main,
        BorderSizePixel = 0,
    })
    addCorner(window, UDim.new(0, 10))
    addStroke(window, self.theme.AccentSoft, 1, 0.3)
    createShadow(window, 0.7)

    local titleBar = create("TextButton", window, {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = self.theme.Accent,
        Text = title or "xev0r",
        TextColor3 = self.theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0,
    })
    addCorner(titleBar, UDim.new(0, 10))
    addStroke(titleBar, self.theme.Border, 1, 0.65)

    local padding = create("UIPadding", titleBar, {
        PaddingLeft = UDim.new(0, 10),
    })

    local closeBtn = create("TextButton", titleBar, {
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -34, 0, 3),
        BackgroundColor3 = Color3.fromRGB(255, 72, 72),
        Text = "✕",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        BorderSizePixel = 0,
    })
    addCorner(closeBtn, UDim.new(0, 8))

    closeBtn.MouseButton1Click:Connect(function()
        screen:Destroy()
    end)

    applyDrag(titleBar, window)

    local tabStrip = create("Frame", window, {
        Size = UDim2.new(1, 0, 0, 34),
        Position = UDim2.new(0, 0, 0, 36),
        BackgroundColor3 = self.theme.Panel,
        BorderSizePixel = 0,
    })

    local tabScrolling = create("ScrollingFrame", tabStrip, {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 0,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
    })

    local tabLayout = create("UIListLayout", tabScrolling, {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4),
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
    })

    local contentHolder = create("Frame", window, {
        Size = UDim2.new(1, 0, 1, -70),
        Position = UDim2.new(0, 0, 0, 70),
        BackgroundColor3 = self.theme.Main,
        BorderSizePixel = 0,
    })

    local tabs = {}
    local currentTab = nil

    local function switchTab(tab)
        if currentTab then
            currentTab.content.Visible = false
            currentTab.button.BackgroundColor3 = self.theme.Surface
        end

        currentTab = tab
        tab.content.Visible = true
        tab.button.BackgroundColor3 = self.theme.Accent
    end

    local function createTab(tabName)
        local tabButton = create("TextButton", tabScrolling, {
            Size = UDim2.new(0, 100, 1, 0),
            BackgroundColor3 = self.theme.Surface,
            Text = tabName,
            TextColor3 = self.theme.Text,
            Font = Enum.Font.GothamSemibold,
            TextSize = 13,
            BorderSizePixel = 0,
        })
        addCorner(tabButton, UDim.new(0, 8))
        addStroke(tabButton, self.theme.Border, 1, 0.7)

        local content = create("ScrollingFrame", contentHolder, {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = self.theme.Accent,
        })

        local contentLayout = create("UIListLayout", content, {
            Padding = UDim.new(0, 6),
        })

        local tab = {
            button = tabButton,
            content = content,
            layout = contentLayout,
            name = tabName,
        }

        table.insert(tabs, tab)

        tabButton.MouseButton1Click:Connect(function()
            switchTab(tab)
        end)

        if #tabs == 1 then
            switchTab(tab)
        end

        contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            content.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 12)
        end)

        local function createElement(className, props)
            return create(className, content, props)
        end

        local function defaultButton(text, callback)
            callback = callback or function() end
            local btn = createElement("TextButton", {
                Size = UDim2.new(1, -10, 0, 30),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundColor3 = self.theme.Surface,
                Text = text,
                TextColor3 = self.theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                BorderSizePixel = 0,
            })
            addCorner(btn, UDim.new(0, 8))
            addStroke(btn, self.theme.Border, 1, 0.6)
            btn.MouseButton1Click:Connect(callback)
            return btn
        end

        function tab:CreateButton(text, callback)
            return defaultButton(text, callback)
        end

        function tab:CreateToggle(text, defaultValue, callback)
            callback = callback or function() end

            local frame = createElement("Frame", {
                Size = UDim2.new(1, -10, 0, 34),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundColor3 = self.theme.Surface,
                BorderSizePixel = 0,
            })
            addCorner(frame, UDim.new(0, 8))

            local label = createElement("TextLabel", {
                Size = UDim2.new(1, -44, 1, 0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = self.theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            local toggle = createElement("TextButton", {
                Size = UDim2.new(0, 34, 0, 18),
                Position = UDim2.new(1, -40, 0.5, -9),
                BackgroundColor3 = defaultValue and self.theme.Accent or Color3.fromRGB(85, 85, 85),
                Text = "",
                BorderSizePixel = 0,
            })
            addCorner(toggle, UDim.new(0, 10))

            local enabled = defaultValue
            local function refresh()
                toggle.BackgroundColor3 = enabled and self.theme.Accent or Color3.fromRGB(85, 85, 85)
                callback(enabled)
            end

            toggle.MouseButton1Click:Connect(function()
                enabled = not enabled
                refresh()
            end)

            refresh()
            return frame
        end

        function tab:CreateSlider(text, defaultValue, minValue, maxValue, callback)
            callback = callback or function() end
            local frame = createElement("Frame", {
                Size = UDim2.new(1, -10, 0, 48),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundColor3 = self.theme.Surface,
                BorderSizePixel = 0,
            })
            addCorner(frame, UDim.new(0, 8))

            local label = createElement("TextLabel", {
                Size = UDim2.new(1, -10, 0, 18),
                Position = UDim2.new(0, 5, 0, 3),
                BackgroundTransparency = 1,
                Text = text .. ": " .. defaultValue,
                TextColor3 = self.theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            local line = createElement("Frame", {
                Size = UDim2.new(1, -10, 0, 8),
                Position = UDim2.new(0, 5, 0, 26),
                BackgroundColor3 = Color3.fromRGB(80, 80, 80),
                BorderSizePixel = 0,
            })
            addCorner(line, UDim.new(0, 4))

            local fill = createElement("Frame", line, {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = self.theme.Accent,
                BorderSizePixel = 0,
            })
            addCorner(fill, UDim.new(0, 4))

            local knob = createElement("Frame", line, {
                Size = UDim2.new(0, 12, 0, 12),
                Position = UDim2.new(0, -6, 0.5, -6),
                BackgroundColor3 = self.theme.Text,
                BorderSizePixel = 0,
            })
            addCorner(knob, UDim.new(0, 6))

            local dragging = false
            local function setFraction(frac)
                frac = clamp(frac, 0, 1)
                local value = math.floor(minValue + (maxValue - minValue) * frac)
                label.Text = text .. ": " .. value
                fill.Size = UDim2.new(frac, 0, 1, 0)
                knob.Position = UDim2.new(frac, -6, 0.5, -6)
                callback(value)
            end

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
                    local rel = (input.Position.X - line.AbsolutePosition.X) / line.AbsoluteSize.X
                    setFraction(rel)
                end
            end)

            setFraction((defaultValue - minValue) / (maxValue - minValue))
            return frame
        end

        function tab:CreateDropdown(text, options, callback)
            callback = callback or function() end
            options = options or {}

            local frame = createElement("Frame", {
                Size = UDim2.new(1, -10, 0, 34),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundColor3 = self.theme.Surface,
                BorderSizePixel = 0,
            })
            addCorner(frame, UDim.new(0, 8))

            local label = createElement("TextLabel", {
                Size = UDim2.new(0, 82, 1, 0),
                Position = UDim2.new(0, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = self.theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            local button = createElement("TextButton", {
                Size = UDim2.new(1, -92, 1, 0),
                Position = UDim2.new(0, 92, 0, 0),
                BackgroundColor3 = Color3.fromRGB(85, 85, 85),
                Text = options[1] or "",
                TextColor3 = self.theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                BorderSizePixel = 0,
            })
            addCorner(button, UDim.new(0, 8))

            local panel = createElement("Frame", {
                Size = UDim2.new(1, -10, 0, 0),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundColor3 = self.theme.Panel,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Visible = false,
                ZIndex = 25,
            })
            addCorner(panel, UDim.new(0, 8))
            addStroke(panel, self.theme.Border, 1, 0.8)

            local list = create("UIListLayout", panel, {
                Padding = UDim.new(0, 2),
            })

            local expanded = false

            local function collapse()
                expanded = false
                panel.Visible = false
                panel.Size = UDim2.new(1, -10, 0, 0)
            end

            button.MouseButton1Click:Connect(function()
                expanded = not expanded
                if expanded then
                    panel.Visible = true
                    panel.Size = UDim2.new(1, -10, 0, math.max(24, #options * 22))
                else
                    collapse()
                end
            end)

            for _, opt in ipairs(options) do
                local optBtn = create("TextButton", panel, {
                    Size = UDim2.new(1, -6, 0, 20),
                    BackgroundColor3 = self.theme.Surface,
                    Text = opt,
                    TextColor3 = self.theme.Text,
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    BorderSizePixel = 0,
                    ZIndex = 26,
                })
                addCorner(optBtn, UDim.new(0, 6))

                optBtn.MouseButton1Click:Connect(function()
                    button.Text = opt
                    callback(opt)
                    collapse()
                end)
            end

            return frame
        end

        function tab:CreateTextBox(text, placeholder, callback)
            callback = callback or function() end

            local frame = createElement("Frame", {
                Size = UDim2.new(1, -10, 0, 34),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundColor3 = self.theme.Surface,
                BorderSizePixel = 0,
            })
            addCorner(frame, UDim.new(0, 8))

            createElement("TextLabel", {
                Size = UDim2.new(0, 86, 1, 0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = self.theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            local box = createElement("TextBox", {
                Size = UDim2.new(1, -96, 1, 0),
                Position = UDim2.new(0, 96, 0, 0),
                BackgroundColor3 = Color3.fromRGB(85, 85, 85),
                TextColor3 = self.theme.Text,
                PlaceholderText = placeholder or "",
                Font = Enum.Font.Gotham,
                TextSize = 13,
                BorderSizePixel = 0,
            })
            addCorner(box, UDim.new(0, 8))

            box.FocusLost:Connect(function(enterPressed)
                callback(box.Text, enterPressed)
            end)

            return frame
        end

        function tab:CreateLabel(text)
            return createElement("TextLabel", {
                Size = UDim2.new(1, -10, 0, 20),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = self.theme.Muted,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
        end

        function tab:CreateColorPicker(defaultColor, callback)
            callback = callback or function() end
            local currentColor = defaultColor or Color3.fromRGB(255, 0, 0)

            local frame = createElement("Frame", {
                Size = UDim2.new(1, -10, 0, 34),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundColor3 = self.theme.Surface,
                BorderSizePixel = 0,
            })
            addCorner(frame, UDim.new(0, 8))

            local preview = createElement("Frame", {
                Size = UDim2.new(0, 26, 0, 26),
                Position = UDim2.new(0, 4, 0.5, -13),
                BackgroundColor3 = currentColor,
                BorderSizePixel = 0,
            })
            addCorner(preview, UDim.new(0, 5))

            local button = createElement("TextButton", {
                Size = UDim2.new(1, -40, 1, 0),
                Position = UDim2.new(0, 34, 0, 0),
                BackgroundColor3 = Color3.fromRGB(85, 85, 85),
                Text = "Pick Color",
                TextColor3 = self.theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                BorderSizePixel = 0,
            })
            addCorner(button, UDim.new(0, 8))

            local popup = create("Frame", screen, {
                Size = UDim2.new(0, 220, 0, 210),
                Position = UDim2.new(0.5, -110, 0.5, -105),
                BackgroundColor3 = self.theme.Main,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 40,
            })
            addCorner(popup, UDim.new(0, 10))
            addStroke(popup, self.theme.AccentSoft, 1, 0.3)

            local popupTitle = create("TextLabel", popup, {
                Size = UDim2.new(1, 0, 0, 22),
                BackgroundColor3 = self.theme.Accent,
                Text = "Color Picker",
                TextColor3 = self.theme.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                BorderSizePixel = 0,
                ZIndex = 41,
            })
            addCorner(popupTitle, UDim.new(0, 10))

            local rLabel = create("TextLabel", popup, { Size = UDim2.new(0, 20, 0, 15), Position = UDim2.new(0, 6, 0, 30), BackgroundTransparency = 1, Text = "R", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.Gotham, TextSize = 11, ZIndex = 41 })
            local gLabel = create("TextLabel", popup, { Size = UDim2.new(0, 20, 0, 15), Position = UDim2.new(0, 6, 0, 58), BackgroundTransparency = 1, Text = "G", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.Gotham, TextSize = 11, ZIndex = 41 })
            local bLabel = create("TextLabel", popup, { Size = UDim2.new(0, 20, 0, 15), Position = UDim2.new(0, 6, 0, 86), BackgroundTransparency = 1, Text = "B", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.Gotham, TextSize = 11, ZIndex = 41 })

            local rVal = create("TextLabel", popup, { Size = UDim2.new(0, 50, 0, 15), Position = UDim2.new(0, 150, 0, 30), BackgroundTransparency = 1, Text = "0", TextColor3 = self.theme.Muted, Font = Enum.Font.Gotham, TextSize = 11, ZIndex = 41 })
            local gVal = create("TextLabel", popup, { Size = UDim2.new(0, 50, 0, 15), Position = UDim2.new(0, 150, 0, 58), BackgroundTransparency = 1, Text = "0", TextColor3 = self.theme.Muted, Font = Enum.Font.Gotham, TextSize = 11, ZIndex = 41 })
            local bVal = create("TextLabel", popup, { Size = UDim2.new(0, 50, 0, 15), Position = UDim2.new(0, 150, 0, 86), BackgroundTransparency = 1, Text = "0", TextColor3 = self.theme.Muted, Font = Enum.Font.Gotham, TextSize = 11, ZIndex = 41 })

            local function makeBar(y)
                local bar = create("Frame", popup, {
                    Size = UDim2.new(1, -40, 0, 10),
                    Position = UDim2.new(0, 30, 0, y),
                    BackgroundColor3 = Color3.fromRGB(70, 70, 70),
                    BorderSizePixel = 0,
                    ZIndex = 41,
                })
                addCorner(bar, UDim.new(0, 4))
                local fill = create("Frame", bar, {
                    Size = UDim2.new(0.5, 0, 1, 0),
                    BackgroundColor3 = Color3.fromRGB(255, 0, 0),
                    BorderSizePixel = 0,
                    ZIndex = 42,
                })
                addCorner(fill, UDim.new(0, 4))
                return bar, fill
            end

            local barR, fillR = makeBar(28)
            local barG, fillG = makeBar(56)
            local barB, fillB = makeBar(84)

            local hexBox = create("TextBox", popup, {
                Size = UDim2.new(1, -10, 0, 22),
                Position = UDim2.new(0, 5, 0, 115),
                BackgroundColor3 = Color3.fromRGB(70, 70, 70),
                TextColor3 = self.theme.Text,
                PlaceholderText = "#FFFFFF",
                Font = Enum.Font.Gotham,
                TextSize = 12,
                BorderSizePixel = 0,
                ZIndex = 41,
            })
            addCorner(hexBox, UDim.new(0, 6))

            local previewLarge = create("Frame", popup, {
                Size = UDim2.new(0, 50, 0, 22),
                Position = UDim2.new(0.5, -25, 0, 145),
                BackgroundColor3 = currentColor,
                BorderSizePixel = 0,
                ZIndex = 41,
            })
            addCorner(previewLarge, UDim.new(0, 6))

            local okBtn = create("TextButton", popup, {
                Size = UDim2.new(0, 58, 0, 24),
                Position = UDim2.new(0.5, -29, 0, 176),
                BackgroundColor3 = self.theme.Accent,
                Text = "OK",
                TextColor3 = self.theme.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                BorderSizePixel = 0,
                ZIndex = 41,
            })
            addCorner(okBtn, UDim.new(0, 8))

            local function updatePreview()
                preview.BackgroundColor3 = currentColor
                previewLarge.BackgroundColor3 = currentColor
                callback(currentColor)
            end

            local function updateBars()
                local r = math.floor(currentColor.R * 255)
                local g = math.floor(currentColor.G * 255)
                local b = math.floor(currentColor.B * 255)
                rVal.Text = "R: " .. r
                gVal.Text = "G: " .. g
                bVal.Text = "B: " .. b
                hexBox.Text = string.format("#%02X%02X%02X", r, g, b)
                fillR.Size = UDim2.new(r / 255, 0, 1, 0)
                fillG.Size = UDim2.new(g / 255, 0, 1, 0)
                fillB.Size = UDim2.new(b / 255, 0, 1, 0)
            end

            local function setCurrentColor(c)
                currentColor = c
                updatePreview()
                updateBars()
            end

            local function dragBar(bar, fill, axis)
                local drag = false
                bar.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        drag = true
                    end
                end)

                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        drag = false
                    end
                end)

                UserInputService.InputChanged:Connect(function(input)
                    if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        local pct = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
                        pct = clamp(pct, 0, 1)

                        local r = fillR.Size.X.Scale
                        local g = fillG.Size.X.Scale
                        local b = fillB.Size.X.Scale

                        if axis == "r" then
                            r = pct
                            fillR.Size = UDim2.new(r, 0, 1, 0)
                        elseif axis == "g" then
                            g = pct
                            fillG.Size = UDim2.new(g, 0, 1, 0)
                        elseif axis == "b" then
                            b = pct
                            fillB.Size = UDim2.new(b, 0, 1, 0)
                        end

                        currentColor = Color3.new(
                            clamp(r, 0, 1),
                            clamp(g, 0, 1),
                            clamp(b, 0, 1)
                        )
                        updatePreview()
                        updateBars()
                    end
                end)
            end

            dragBar(barR, fillR, "r")
            dragBar(barG, fillG, "g")
            dragBar(barB, fillB, "b")

            hexBox.FocusLost:Connect(function()
                local hex = hexBox.Text:gsub("#", "")
                if #hex == 6 then
                    local r = tonumber(hex:sub(1, 2), 16) or 0
                    local g = tonumber(hex:sub(3, 4), 16) or 0
                    local b = tonumber(hex:sub(5, 6), 16) or 0
                    setCurrentColor(Color3.fromRGB(r, g, b))
                end
            end)

            okBtn.MouseButton1Click:Connect(function()
                popup.Visible = false
            end)

            button.MouseButton1Click:Connect(function()
                popup.Visible = not popup.Visible
                updateBars()
            end)

            updateBars()
            return frame
        end

        function tab:CreateKeybind(text, defaultKey, callback)
            callback = callback or function() end

            local frame = createElement("Frame", {
                Size = UDim2.new(1, -10, 0, 34),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundColor3 = self.theme.Surface,
                BorderSizePixel = 0,
            })
            addCorner(frame, UDim.new(0, 8))

            createElement("TextLabel", {
                Size = UDim2.new(0, 86, 1, 0),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = self.theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            local keyBtn = createElement("TextButton", {
                Size = UDim2.new(1, -96, 1, 0),
                Position = UDim2.new(0, 96, 0, 0),
                BackgroundColor3 = Color3.fromRGB(85, 85, 85),
                Text = defaultKey and defaultKey.Name or "[...]",
                TextColor3 = self.theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                BorderSizePixel = 0,
            })
            addCorner(keyBtn, UDim.new(0, 8))

            local binding = false
            local currentKey = defaultKey
            local connection

            keyBtn.MouseButton1Click:Connect(function()
                binding = true
                keyBtn.Text = "..."
                if connection then
                    connection:Disconnect()
                end

                connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                    if binding and not gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard then
                        currentKey = input.KeyCode
                        keyBtn.Text = currentKey.Name
                        callback(currentKey)
                        binding = false
                        connection:Disconnect()
                    end
                end)
            end)

            return frame
        end

        return tab
    end

    return {
        window = window,
        screen = screen,
        CreateTab = createTab,
    }
end

getgenv().xev0r = xev0r

return xev0r
