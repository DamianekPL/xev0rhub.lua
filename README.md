# xev0rhub.lua

-- Load the library
local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/DamianekPL/xev0rhub.lua/refs/heads/main/test.lua"))()

-- Create main window (Watermark is automatically created!)
local Window = library.new("My Awesome Hub", {
    ToggleKey = Enum.KeyCode.RightControl  -- Press Right Ctrl to open/close
})

-- ==================== TABS & SECTIONS ====================

local Tab1 = Window:addPage("Main")

local Sec1 = Tab1:addSection("Basic Controls")

Sec1:addButton("Test Button", function()
    Window:Notify("Button Clicked!", "This is a test notification!")
end)

Sec1:addToggle("Enable Feature", true, function(state)
    print("Toggle state changed to:", state)
end)

Sec1:addTextbox("Input Text", "Hello World", function(text)
    print("User typed:", text)
end)

Sec1:addSlider("Speed", 50, 0, 100, function(value)
    print("Slider value:", value)
end)

local Sec2 = Tab1:addSection("Advanced")

Sec2:addKeybind("Toggle Fly", Enum.KeyCode.F, function()
    print("Fly keybind pressed!")
end)

Sec2:addColorPicker("ESP Color", Color3.fromRGB(255, 0, 255), function(color)
    print("Selected color:", color)
end)

Sec2:addDropdown("Game Mode", {"Survival", "Creative", "Hardcore", "Peaceful"}, function(selected)
    print("Selected mode:", selected)
end)

-- ==================== NOTIFICATIONS TEST ====================

local Tab2 = Window:addPage("Notifications")

local NotifSec = Tab2:addSection("Notification Examples")

NotifSec:addButton("Success Notification", function()
    Window:Notify("Success!", "Everything worked perfectly.", function() end)
end)

NotifSec:addButton("Warning Notification", function()
    Window:Notify("Warning", "Be careful with this action!", function() end)
end)

NotifSec:addButton("Error Notification", function()
    Window:Notify("Error", "Failed to connect to server.", function() end)
end)

-- ==================== MISC ====================

local Tab3 = Window:addPage("Misc")

local MiscSec = Tab3:addSection("Window Controls")

MiscSec:addButton("Minimize Window", function()
    Window:toggle()
end)

MiscSec:addButton("Destroy UI", function()
    Window:Destroy()
end)

print("✅ Full XevorUI Test Loaded with Watermark!")
print("Press RightControl to open the menu")
