# XEVOR Script Hub

Modern Roblox UI library with a cinematic loading screen, key system, expandable watermark, and a full widget set for building script hubs.

![Roblox](https://img.shields.io/badge/Roblox-UI%20Library-00A2FF?style=flat-square)
![Lua](https://img.shields.io/badge/Lua-5.1-blue?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)

---

## Features

- **Cinematic loading screen** — intro notice, animated progress, purple theme
- **Key system** — changelog panel, key input, verify / get key / Discord buttons
- **Main menu** — pages, sections, minimize / close, drag, toggle key
- **Watermark**
  - Player name, FPS, ping
  - Expandable dropdown: current game, session time, active keybinds
  - Rounded corners (`CanvasGroup` + `UICorner`)
  - Draggable from the title bar
- **Widgets** — Button, Toggle, Textbox, Keybind, ColorPicker, Slider, Dropdown
- **Theming** — live theme colors via `SetTheme`
- **Notifications** — accept / decline style popups

---

## Quick Start

### Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/DamianekPL/xev0rhub.lua/refs/heads/main/test.lua"))()
```

With error handling:

```lua
local ok, err = pcall(function()
	loadstring(game:HttpGet("https://raw.githubusercontent.com/DamianekPL/xev0rhub.lua/refs/heads/main/test.lua"))()
end)

if not ok then
	warn("[XEVOR] Load failed:", err)
end
```

### Test keys

| Key | Result |
|-----|--------|
| `XEVOR-TEST-KEY-1234` | Accepted |
| `VALIDKEY` | Accepted |

Replace the key check in the script with your own validation before release.

### Toggle menu

Default toggle key: **Right Ctrl**

---

## Usage Example

Add this **after** the window is created (inside the key-verify success block):

```lua
local Window = XevorLibrary.new("XEVOR", {
	ToggleKey = Enum.KeyCode.RightControl,
	Watermark = {
		Enabled = true,
		-- optional style overrides:
		-- Position = UDim2.new(1, -16, 0, 16),
		-- AccentPurple = Color3.fromRGB(180, 50, 255),
	}
})

-- Pages
local Main = Window:AddPage("Main")
local Visuals = Window:AddPage("Visuals")
local Settings = Window:AddPage("Settings")

-- Sections
local Combat = Main:AddSection("Combat")
local Movement = Main:AddSection("Movement")

-- Toggle
Combat:AddToggle("Kill Aura", false, function(state)
	print("Kill Aura:", state)
end)

-- Keybind (shows up in watermark when bound)
Combat:AddKeybind("Fly", Enum.KeyCode.F, function()
	print("Fly pressed")
end)

-- Slider
Movement:AddSlider("WalkSpeed", 16, 16, 200, function(value)
	local char = game.Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = value
	end
end)

-- Button
Combat:AddButton("Reset Character", function()
	local char = game.Players.LocalPlayer.Character
	if char then
		char:BreakJoints()
	end
end)

-- Textbox
Settings:AddTextbox("Webhook URL", "", function(text, enter)
	if enter then
		print("Saved:", text)
	end
end)

-- Dropdown
Visuals:AddDropdown("ESP Mode", { "Box", "Highlight", "Name" }, function(option)
	print("ESP Mode:", option)
end)

-- Color picker
Visuals:AddColorPicker("ESP Color", Color3.fromRGB(180, 50, 255), function(color)
	print("Color:", color)
end)

-- Open first page
Window:SelectPage(Main, true)
```

---

## API Reference

### Library

| Method | Description |
|--------|-------------|
| `library.new(title, options?)` | Create the main window |
| `Window:AddPage(title, icon?)` | Add a sidebar page (`icon` = asset id number) |
| `Window:SelectPage(page, true)` | Focus a page |
| `Window:SetToggleKey(KeyCode)` | Change menu toggle key |
| `Window:SetVisible(bool)` | Show / hide menu |
| `Window:SetWatermarkVisible(bool)` | Show / hide watermark |
| `Window:SetWatermarkStyle(table)` | Update watermark colors / position / size |
| `Window:SetTheme(name, Color3)` | Live theme update |
| `Window:Notify(title, text, callback?)` | Notification (`callback(accepted)`) |
| `Window:Toggle()` | Minimize / expand window |
| `Window:Destroy()` | Destroy menu + watermark |

### Options (`library.new`)

```lua
{
	ToggleKey = Enum.KeyCode.RightControl,
	Watermark = {
		Enabled = true,
		Position = UDim2.new(1, -16, 0, 16),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0, 268, 0, 56), -- height is layout-locked
		BackgroundColor = Color3.fromRGB(24, 24, 24),
		TopBarColor = Color3.fromRGB(10, 10, 10),
		StatusColor = Color3.fromRGB(14, 14, 14),
		AccentPurple = Color3.fromRGB(180, 50, 255),
		TextColor = Color3.fromRGB(255, 255, 255),
		Glow = true,
		AccentLine = true,
		DisplayOrder = 100,
	}
}
```

### Section widgets

| Method | Signature |
|--------|-----------|
| **Button** | `section:AddButton(title, callback)` |
| **Toggle** | `section:AddToggle(title, default, callback)` → `callback(state)` |
| **Textbox** | `section:AddTextbox(title, default, callback)` → `callback(text, enter)` |
| **Keybind** | `section:AddKeybind(title, defaultKey?, callback, changedCallback?)` |
| **Slider** | `section:AddSlider(title, default, min, max, callback)` → `callback(value)` |
| **Dropdown** | `section:AddDropdown(title, list, callback)` → `callback(option)` |
| **ColorPicker** | `section:AddColorPicker(title, defaultColor, callback)` → `callback(color)` |

### Themes

```lua
Window:SetTheme("Background", Color3.fromRGB(24, 24, 24))
Window:SetTheme("Accent", Color3.fromRGB(10, 10, 10))
Window:SetTheme("DarkContrast", Color3.fromRGB(14, 14, 14))
Window:SetTheme("LightContrast", Color3.fromRGB(20, 20, 20))
Window:SetTheme("TextColor", Color3.fromRGB(255, 255, 255))
Window:SetTheme("Glow", Color3.fromRGB(0, 0, 0))
```

---

## Watermark

| Element | Behavior |
|---------|----------|
| Title bar | Hub name + expand (`v` / `^`) — **drag handle** |
| Purple line | Accent under title |
| Status | `Player \| FPS \| Ping` |
| Dropdown | **GAME** (place name), **TIME** (session), **KEYBINDS** (bound features) |

Click the title or `v` to expand. Bound keybinds from `AddKeybind` appear automatically.

---

## Project structure

```
xev0rhub.lua /
├── test.lua          -- full hub (library + loading + key system)
└── README.md         -- this file
```

Script flow:

1. **Library** defines UI classes  
2. **Loading screen** plays (~6s + intro)  
3. **Key system** waits for a valid key  
4. **Main window + watermark** open after verification  

---

## Customization

### Key check

```lua
-- in VerifyBtn click handler
if key == "YOUR-KEY-HERE" then
	-- accept
end
```

### Get Key / Discord links

```lua
setclipboard("https://yourkeysite.com")
setclipboard("https://discord.gg/yourserver")
```

### Changelog entries

```lua
local logs = {
	"• v1.2.3 - New UI overhaul",
	"• Added watermark dropdown",
	"• Rounded corners + drag",
}
```

---

## Requirements

- Roblox executor / LocalScript (client)
- `game:HttpGet` for remote load
- Optional: `setclipboard` for Get Key / Discord buttons

---

## Credits

- **XEVOR** — solo developer  
- Report bugs on Discord  

---

## License

MIT — free to use and modify. Credit appreciated but not required.
