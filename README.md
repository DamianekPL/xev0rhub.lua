# XEVOR Library documentation

This guide documents the XEVOR menu library contained in `xevor_connected_loader_keysystem_mainmenu.lua`.

The combined script runs in this order:

```text
Loading screen -> key system -> XEVOR window -> watermark
```

The main window is created only after the key passes verification.

## Quick start

When using the **standalone library**, load it and then create a window:

```lua
local library = loadstring(game:HttpGet("YOUR_LIBRARY_URL"))()

local Window = library.new("XEVOR", {
    ToggleKey = Enum.KeyCode.RightControl,
})

local MainPage = Window:addPage("Main")
local MainSection = MainPage:addSection("Basic controls")
```

In the **combined loading/key-system script**, add your pages immediately after this existing block inside the successful key-check branch:

```lua
local Window = XevorLibrary.new("XEVOR", {
    ToggleKey = Enum.KeyCode.RightControl
})

-- Add pages and sections here.
```

The library uses a fixed desktop layout. Mobile/touch scaling is intentionally disabled.

## Creating the window

```lua
local Window = library.new(title, options)
```

| Argument | Type | Description |
| --- | --- | --- |
| `title` | string | The text shown in the window title bar and watermark header. |
| `options.ToggleKey` | `Enum.KeyCode` or `nil` | Key used to show/hide the window. Default: `Enum.KeyCode.RightShift`. |
| `options.Watermark` | table | Optional appearance settings for the independent watermark. |

Example:

```lua
local Window = library.new("XEVOR SCRIPTHUB", {
    ToggleKey = Enum.KeyCode.RightControl,
    Watermark = {
        Enabled = true,
        Position = UDim2.new(1, -16, 0, 16),
        AnchorPoint = Vector2.new(1, 0),
        Size = UDim2.fromOffset(390, 58),

        BackgroundColor = Color3.fromRGB(24, 24, 24),
        TopBarColor = Color3.fromRGB(10, 10, 10),
        StatusColor = Color3.fromRGB(14, 14, 14),
        TextColor = Color3.fromRGB(255, 255, 255),
        TextSize = 13,

        Glow = true,
        GlowColor = Color3.fromRGB(0, 0, 0),
        AccentLine = true,
        AccentColor = Color3.fromRGB(20, 20, 20),
        TopBarHeight = 27,
        DisplayOrder = 100,
    }
})
```

The watermark is a separate `ScreenGui`, so it remains visible when the main window is hidden. It displays the player name, FPS, and ping automatically.

## Pages and sections

Pages create the left navigation entries. Sections group controls inside a page.

```lua
local Main = Window:addPage("Main")
local Visuals = Window:addPage("Visuals", 6031091004) -- optional Roblox image asset id

local Basic = Main:addSection("Basic controls")
local Advanced = Main:addSection("Advanced")
```

| Method | Returns | Notes |
| --- | --- | --- |
| `Window:addPage(title, icon)` | page | `icon` is optional; pass only the numeric asset id, not `rbxassetid://`. |
| `Page:addSection(title)` | section | Use the returned section to add controls. |

## Controls

All control methods are called on a section, for example `Basic:addSlider(...)`. Each one returns its Roblox UI object, which can be passed to an update method later.

### Button

```lua
local Button = Basic:addButton("Print test", function(update)
    print("Button pressed")
    -- update("New button title")
end)
```

Signature: `Section:addButton(title, callback)`

The callback receives an optional `update(newTitle)` helper.

### Toggle

```lua
local Enabled = false

local Toggle = Basic:addToggle("Enable feature", false, function(value, update)
    Enabled = value
    print("Enabled:", value)
    -- update("Enable feature", true) -- changes the displayed toggle
end)
```

Signature: `Section:addToggle(title, default, callback)`

| Callback argument | Meaning |
| --- | --- |
| `value` | New boolean state. |
| `update` | Optional helper: `update(newTitle, displayedValue)`. |

### Textbox

```lua
local Textbox = Basic:addTextbox("Player name", "Guest", function(text, submitted, update)
    print("Current text:", text)

    if submitted then
        print("Player finished editing")
    end

    -- update("New label", "New text")
end)
```

Signature: `Section:addTextbox(title, default, callback)`

The callback runs while the user types. `submitted` is `true` when the textbox loses focus; otherwise it is `nil`.

### Keybind

```lua
local FlyBind = Basic:addKeybind(
    "Toggle fly",
    Enum.KeyCode.F,
    function(update)
        print("F was pressed")
        -- update("Toggle fly", Enum.KeyCode.G)
    end,
    function(input, update)
        print("New key:", input.KeyCode.Name)
    end
)
```

Signature: `Section:addKeybind(title, defaultKey, pressedCallback, changedCallback)`

- Click the keybind control and press a key to change it.
- `pressedCallback(update)` runs when the assigned key is pressed.
- `changedCallback(input, update)` runs after the user selects a new key.
- Click an already assigned keybind to clear it.

### Color picker

```lua
local EspColor = Basic:addColorPicker("ESP color", Color3.fromRGB(255, 0, 255), function(color, update)
    print("R:", color.R, "G:", color.G, "B:", color.B)
    -- update("ESP color", Color3.fromRGB(255, 255, 255))
end)
```

Signature: `Section:addColorPicker(title, defaultColor, callback)`

The callback receives a `Color3` whenever the user changes the hue, saturation, brightness, or RGB fields.

### Slider

```lua
local Speed = Basic:addSlider("Speed", 16, 0, 100, function(value, update)
    print("Speed:", value)
    -- update("Speed", 50, 0, 200)
end)
```

Signature: `Section:addSlider(title, default, minimum, maximum, callback)`

The callback runs while dragging the bar and when a valid number is entered into its text field.

### Dropdown

```lua
local Mode = Basic:addDropdown("Game mode", {"Legit", "Rage", "Visuals"}, function(value, update)
    print("Selected:", value)

    -- Change the displayed label and replace the entries:
    -- update("Game mode", {"One", "Two"})
end)
```

Signature: `Section:addDropdown(title, list, callback)`

The callback receives the selected value and an optional `update(newTitle, newList)` helper. The list must be an array of strings.

## Full example

```lua
local library = loadstring(game:HttpGet("YOUR_LIBRARY_URL"))()

local Window = library.new("XEVOR", {
    ToggleKey = Enum.KeyCode.RightControl,
    Watermark = {
        Enabled = true,
        Glow = true,
    }
})

local Main = Window:addPage("Main")
local Settings = Main:addSection("Settings")

local fly = false
Settings:addToggle("Fly", false, function(value)
    fly = value
    print("Fly is", fly)
end)

Settings:addSlider("Walk speed", 16, 0, 100, function(value)
    print("Selected speed:", value)
end)

Settings:addColorPicker("Watermark color", Color3.fromRGB(24, 24, 24), function(color)
    Window:SetWatermarkStyle({
        BackgroundColor = color
    })
end)

Settings:addDropdown("Mode", {"Normal", "Fast", "Safe"}, function(value)
    print("Mode:", value)
end)

Settings:addButton("Notify", function()
    Window:Notify("XEVOR", "Everything is working.")
end)
```

## Window functions

### Show, hide, minimize, and destroy

```lua
Window:SetVisible(true)     -- show the full window
Window:SetVisible(false)    -- hide only the full window; watermark stays visible
Window:toggle()             -- minimize/restore the window
Window:SetToggleKey(Enum.KeyCode.RightControl)
Window:Destroy()            -- destroys the window, watermark, and its connections
```

### Notifications

```lua
Window:Notify("Confirm", "Do you want to continue?", function(accepted)
    if accepted then
        print("Accepted")
    else
        print("Declined")
    end
end)
```

Signature: `Window:Notify(title, text, callback)`

The callback receives `true` when the check icon is pressed and `false` when the close icon is pressed. Calling a new notification replaces the previous one.

### Theme colors

```lua
Window:setTheme("Background", Color3.fromRGB(24, 24, 24))
Window:setTheme("Accent", Color3.fromRGB(10, 10, 10))
Window:setTheme("TextColor", Color3.fromRGB(255, 255, 255))
```

Supported keys in the main library are:

```lua
"Background"
"Glow"
"Accent"
"LightContrast"
"DarkContrast"
"TextColor"
```

Changing a theme changes all UI objects tied to that theme. Use `Window:SetWatermarkStyle()` for watermark-specific colors.

## Watermark functions

### Visibility

```lua
Window:SetWatermarkVisible(false)
Window:SetWatermarkVisible(true)
```

### Live styling

```lua
Window:SetWatermarkStyle({
    Size = UDim2.fromOffset(440, 58),
    Position = UDim2.new(1, -16, 0, 16),
    BackgroundColor = Color3.fromRGB(24, 24, 24),
    TopBarColor = Color3.fromRGB(10, 10, 10),
    StatusColor = Color3.fromRGB(14, 14, 14),
    TextColor = Color3.fromRGB(255, 255, 255),
    Glow = true,
    GlowColor = Color3.fromRGB(0, 0, 0),
    AccentLine = true,
    AccentColor = Color3.fromRGB(80, 45, 120),
    TextSize = 13,
    TitleColor = Color3.fromRGB(255, 255, 255),
    TitleTextSize = 14,
    DisplayOrder = 100,
})
```

`SetWatermarkStyle` changes only the supplied fields. This makes it safe to call from sliders, toggles, and color-picker callbacks.

| Field | Type | Effect |
| --- | --- | --- |
| `Enabled` | boolean | Shows or hides the watermark. |
| `Position` | `UDim2` | Screen position. |
| `AnchorPoint` | `Vector2` | Anchor used by `Position`. |
| `Size` | `UDim2` | Full watermark size. |
| `DisplayOrder` | number | UI draw priority. |
| `BackgroundColor` | `Color3` | Outer panel color. |
| `TopBarColor` | `Color3` | Header color. |
| `StatusColor` | `Color3` | Player/FPS/ping panel color. |
| `TextColor` | `Color3` | Status text and title color. |
| `TitleColor` | `Color3` | Header title color only. |
| `TextSize` | number | Status text size, clamped to 8–32. |
| `TitleTextSize` | number | Header text size, clamped to 8–32. |
| `Glow` | boolean | Enables/disables the shadow glow. |
| `GlowColor` | `Color3` | Glow color. |
| `AccentLine` | boolean | Enables/disables the line below the header. |
| `AccentColor` | `Color3` | Accent line color. |

Example: connect a picker and slider to the watermark:

```lua
local Appearance = Main:addSection("Watermark")

Appearance:addColorPicker("Watermark background", Color3.fromRGB(24, 24, 24), function(color)
    Window:SetWatermarkStyle({BackgroundColor = color})
end)

Appearance:addSlider("Watermark width", 390, 250, 600, function(value)
    Window:SetWatermarkStyle({
        Size = UDim2.fromOffset(value, 58)
    })
end)

Appearance:addToggle("Watermark glow", true, function(enabled)
    Window:SetWatermarkStyle({Glow = enabled})
end)
```

## Updating existing controls

The section object also has these update methods:

```lua
Section:updateButton(buttonOrTitle, newTitle)
Section:updateToggle(toggleOrTitle, newTitle, displayedValue)
Section:updateTextbox(textboxOrTitle, newTitle, newText)
Section:updateKeybind(keybindOrTitle, newTitle, newKey)
Section:updateColorPicker(pickerOrTitle, newTitle, newColor)
Section:updateSlider(sliderOrTitle, newTitle, value, minimum, maximum)
Section:updateDropdown(dropdownOrTitle, newTitle, newList, callback)
```

Pass either the object returned by `add...` or its original title. For predictable application logic, keep your own variables (for example `fly = true`) instead of reading visual UI state.

## Combined-script key system

The current combined script checks the key here:

```lua
if key == "XEVOR-TEST-KEY-1234" or key == "VALIDKEY" then
    -- The loading screen has already completed.
    -- The key system is destroyed.
    -- The XEVOR window is created here.
end
```

Replace this condition with your own key verification when ready. The XEVOR main window should be created only inside the successful branch.

## Troubleshooting

- **Window does not appear:** make sure code that creates `Window`, pages, and sections runs after the library has loaded (or inside the successful key branch in the combined script).
- **Right Ctrl does nothing:** ensure `ToggleKey = Enum.KeyCode.RightControl` was passed to `library.new`, and no textbox has focus.
- **Watermark remains visible when menu hides:** this is expected; use `Window:SetWatermarkVisible(false)` if you want to hide it too.
- **`Animation failed to load` in the Roblox console:** that comes from the game's animation asset, not this menu/watermark library.
