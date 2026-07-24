local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local XevorUI = {}
XevorUI.__index = XevorUI

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

local function make(className, properties, parent)
    local instance = Instance.new(className)
    if properties then
        for property, value in pairs(properties) do
            instance[property] = value
        end
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end

local function corner(parent, radius)
    return make("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end

local function stroke(parent, color, thickness)
    return make("UIStroke", { Color = color, Thickness = thickness or 1 }, parent)
end

local function tween(instance, duration, properties, style, direction)
    local animation = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), properties)
    animation:Play()
    return animation
end

local function safeCallback(callback, ...)
    if not callback then
        return
    end
    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[XevorUI] Callback error:", err)
    end
end

local function getGuiRoot(silent)
    local player = Players.LocalPlayer
    if player and player:FindFirstChild("PlayerGui") then
        return player.PlayerGui
    end

    local root = nil
    if gethui then
        root = gethui()
    end
    if not root then
        root = CoreGui
    end
    if not root then
        if not silent then
            warn("[XevorUI] No GUI parent was available.")
        end
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

local Window = {}
Window.__index = Window

function XevorUI.CreateWindow(first, second)
    local options = first == XevorUI and second or first
    options = options or {}

    local theme = DEFAULT_THEME
    local self = setmetatable({
        Title = options.Title or options.Name or "Xevor",
        Theme = theme,
        Tabs = {},
        Controls = {},
        Connections = {},
        ToggleKey = options.ToggleKey or Enum.KeyCode.RightControl,
        Destroyed = false,
    }, Window)

    local parentGui = getGuiRoot(false)
    if not parentGui then
        warn("[XevorUI] Window creation skipped because no GUI parent was available.")
        return nil
    end

    local old = parentGui:FindFirstChild("XevorUI")
    if old then
        old:Destroy()
    end

    self.Gui = make("ScreenGui", {
        Name = "XevorUI",
        ResetOnSpawn = false,
        DisplayOrder = options.DisplayOrder or 10,
        IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, parentGui)

    self.Frame = make("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = options.Position or UDim2.fromScale(0.5, 0.5),
        Size = options.Size or UDim2.fromOffset(700, 450),
        BackgroundColor3 = theme.Background,
        BorderSizePixel = 0,
    }, self.Gui)
    corner(self.Frame, 8)
    stroke(self.Frame, Color3.fromRGB(8, 7, 12))

    local topbar = make("Frame", {
        Name = "Topbar",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = theme.Topbar,
        BorderSizePixel = 0,
    }, self.Frame)
    corner(topbar, 8)
    make("TextLabel", {
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -100, 1, 0),
        BackgroundTransparency = 1,
        Text = string.upper(self.Title),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, topbar)

    self.Sidebar = make("Frame", {
        Position = UDim2.fromOffset(0, 36),
        Size = UDim2.new(0, 180, 1, -36),
        BackgroundColor3 = theme.Sidebar,
        BorderSizePixel = 0,
    }, self.Frame)

    self.Content = make("Frame", {
        Position = UDim2.fromOffset(180, 36),
        Size = UDim2.new(1, -180, 1, -36),
        BackgroundTransparency = 1,
    }, self.Frame)

    self.Notifications = make("Frame", {
        Position = UDim2.new(1, -16, 0, 16),
        Size = UDim2.fromOffset(280, 260),
        BackgroundTransparency = 1,
    }, self.Gui)

    return self
end

function XevorUI.new(title)
    return XevorUI.CreateWindow({ Title = title })
end

function XevorUI.LoadingScreen(options)
    options = options or {}
    local parentGui = getGuiRoot(true)
    if not parentGui then
        return nil
    end
    local gui = make("ScreenGui", {
        Name = options.Name or "XevorUI_LoadingScreen",
        ResetOnSpawn = false,
    }, parentGui)
    return gui
end

function XevorUI.ShowKeySystem(options)
    options = options or {}
    local parentGui = getGuiRoot(true)
    if not parentGui then
        return nil
    end
    local gui = make("ScreenGui", {
        Name = "XevorUI_KeySystem",
        ResetOnSpawn = false,
    }, parentGui)
    return gui
end

function XevorUI.StartWithKeySystem(options)
    options = options or {}
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
        OnComplete = function()
            XevorUI.ShowKeySystem({
                Key = options.Key or "XEVOR-ACCESS-KEY",
                OnSuccess = openMainMenu,
            })
        end,
    })
end

function Window:SetVisible(visible)
    if self.Destroyed then return end
    if self.Gui then
        self.Gui.Enabled = visible
    end
end

function Window:Notify(options, message, duration)
    if self.Destroyed then return end
    if type(options) == "string" then
        options = { Title = options, Content = message, Duration = duration }
    end
    options = options or {}
    return options.Title or self.Title
end

function Window:CreateTab(options)
    if type(options) ~= "table" then
        options = { Name = options }
    end
    local name = options.Name or options.Title or "Tab"
    local tab = setmetatable({ Name = name, Window = self }, { __index = function(_, key) return Window[key] end })
    table.insert(self.Tabs, tab)
    return tab
end

function Window:Tab(name)
    return self:CreateTab(name)
end

function Window:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    if self.Gui then
        self.Gui:Destroy()
    end
end

function XevorUI.Init(options)
    return XevorUI.CreateWindow(options)
end

return setmetatable(XevorUI, {
    __call = function(_, options)
        return XevorUI.CreateWindow(options)
    end,
})
