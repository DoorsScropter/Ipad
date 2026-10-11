-- 3D iPad v4 | Delta compatible (client-side LocalScript)
-- Everything is a real Part in Workspace. The screen is a Part with a SurfaceGui,
-- so when the iPad tilts, the screen tilts with it.
--
-- iPad is an ITEM: it shows up in your inventory (hotbar) as "iPad".
--   * Tap the item = the iPad appears on your screen
--   * Tap the TOP button on the iPad (the part on the top edge) = closes the iPad (back to inventory)
--   * Tap the SIDE buttons (right edge) = volume up / down (hold to repeat)
--   * Swipe up on the screen to unlock
--   * Swipe DOWN starting on the battery / wifi icons = Control Center
--   * Wi-Fi is OFF by default: Control Center > Wi-Fi > turn on > tap baseplate_5G
--   * App Store: tap GET to download (only works while Wi-Fi is connected)
--   * Swipe up from the very bottom of the screen to leave an app
--   * Drag left/right on the silver frame to tilt, double-tap the frame to straighten
--   * Battery drains while the iPad is open. At 0% it turns off.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ===== SETTINGS =====
local K = 1.0                  -- overall iPad size (bigger = larger)
local DIST = 2.4               -- distance from camera
local PUSH = 0.08              -- tap push-back force (studs)
local MAX_TILT = math.rad(35)  -- max sideways tilt
local TILT_SPEED = 0.3         -- degrees of tilt per pixel dragged
local TILT_MODE = "side"       -- "side" = turns left/right, "roll" = leans like a tilted picture
local DRAIN_MINUTES = 15       -- minutes from 100% to 0% (only while the iPad is open)
local WIFI_NAME = "baseplate_5G"
local VOL_STEP = 0.0625        -- volume change per button press
local RELOCK_ON_CLOSE = true   -- closing the iPad locks it again

-- ===== CLEAN UP OLD COPY (if you run the script again) =====
local old = Workspace:FindFirstChild("IPad3D_Swipe")
if old then old:Destroy() end
for _, holder in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
	if holder then
		for _, c in ipairs(holder:GetChildren()) do
			if c:IsA("Tool") and c:GetAttribute("IPad3D_Tool") then
				c:Destroy()
			end
		end
	end
end

-- ===== SIZES =====
local BW, BH, BT, R = 2.5 * K, 3.3 * K, 0.14 * K, 0.2 * K
local SW, SH = 2.1 * K, 2.9 * K
local E = 0.02 * K
local CW, CH = 630, 870        -- screen canvas pixels
local TILT_MARGIN = 0.5 * K    -- extra grab area around the frame for tilting

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local BLUE = Color3.fromRGB(10, 132, 255)
local GREEN = Color3.fromRGB(52, 199, 89)
local PURPLE = Color3.fromRGB(94, 92, 230)
local ORANGE = Color3.fromRGB(255, 159, 10)
local RED = Color3.fromRGB(255, 69, 58)
local GRAY = Color3.fromRGB(140, 140, 155)
local TILE_OFF = Color3.fromRGB(66, 66, 80)
local ROW = Color3.fromRGB(54, 54, 66)

local model = Instance.new("Model")
model.Name = "IPad3D_Swipe"

local function part(name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- ===== BODY (rounded corners from cylinders) =====
local silver = Color3.fromRGB(205, 207, 214)
local metal = Enum.Material.Metal
local body = part("Body", Vector3.new(BW - 2 * R, BH, BT), CFrame.new(), silver, metal)
part("BodyWide", Vector3.new(BW, BH - 2 * R, BT), CFrame.new(), silver, metal)
for _, sx in ipairs({ -1, 1 }) do
	for _, sy in ipairs({ -1, 1 }) do
		part(
			"Corner",
			Vector3.new(BT, 2 * R, 2 * R),
			CFrame.new(sx * (BW / 2 - R), sy * (BH / 2 - R), 0) * CFrame.Angles(0, math.rad(90), 0),
			silver,
			metal,
			Enum.PartType.Cylinder
		)
	end
end

-- ===== BEZEL =====
local FZ = BT / 2
part("Bezel", Vector3.new(BW - 0.14 * K, BH - 0.14 * K, E), CFrame.new(0, 0, FZ + E / 2), Color3.fromRGB(8, 8, 10))

-- ===== FRONT CAMERA =====
part(
	"FrontCamera",
	Vector3.new(E, 0.07 * K, 0.07 * K),
	CFrame.new(0, BH / 2 - 0.1 * K, FZ + 1.5 * E) * CFrame.Angles(0, math.rad(90), 0),
	Color3.fromRGB(25, 35, 70),
	Enum.Material.Glass,
	Enum.PartType.Cylinder
)

-- ===== BUTTONS (top = close, side = volume) =====
local powerBtn = part("PowerButton", Vector3.new(0.5 * K, 0.06 * K, 0.1 * K), CFrame.new(BW / 2 - 0.6 * K, BH / 2 + 0.03 * K, 0), silver, metal)
local volUpBtn = part("VolUp", Vector3.new(0.06 * K, 0.34 * K, 0.1 * K), CFrame.new(BW / 2 + 0.03 * K, BH / 2 - 0.8 * K, 0), silver, metal)
local volDownBtn = part("VolDown", Vector3.new(0.06 * K, 0.34 * K, 0.1 * K), CFrame.new(BW / 2 + 0.03 * K, BH / 2 - 1.2 * K, 0), silver, metal)

-- ===== SCREEN PART =====
local screen = part("Screen", Vector3.new(SW, SH, E), CFrame.new(0, 0, FZ + 1.5 * E + E / 2), Color3.fromRGB(0, 0, 0))

local sg = Instance.new("SurfaceGui")
sg.Name = "ScreenGui"
sg.Face = Enum.NormalId.Back
sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
sg.CanvasSize = Vector2.new(CW, CH)
sg.LightInfluence = 0
sg.Brightness = 1
sg.ClipsDescendants = true
sg.Parent = screen

-- remember part transparency so the iPad can be hidden/shown
local origTr = {}
for _, d in ipairs(model:GetChildren()) do
	if d:IsA("BasePart") then
		origTr[d] = d.Transparency
	end
end

-- ===== UI HELPERS =====
local function ui(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function corner(parent, r)
	return ui("UICorner", { CornerRadius = r }, parent)
end

local blobScales = {}
local function blob(parent, x, y, s, color, tr)
	local f = ui("Frame", {
		Size = UDim2.fromOffset(s, s),
		Position = UDim2.fromOffset(x, y),
		BackgroundColor3 = color,
		BackgroundTransparency = tr,
		BorderSizePixel = 0,
	}, parent)
	corner(f, UDim.new(1, 0))
	table.insert(blobScales, ui("UIScale", { Scale = 1 }, f))
end

local function wallpaper(name, c1, c2, c3, rot, z)
	local w = ui("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = z,
	}, sg)
	ui("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c1),
			ColorSequenceKeypoint.new(0.5, c2),
			ColorSequenceKeypoint.new(1, c3),
		}),
		Rotation = rot,
	}, w)
	return w
end

local function group(parent, z)
	return ui("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		GroupTransparency = 0,
		ZIndex = z,
	}, parent)
end

local function label(parent, text, x, y, w, h, size, color, font, align, z)
	return ui("TextLabel", {
		Size = UDim2.fromOffset(w, h),
		Position = UDim2.fromOffset(x, y),
		BackgroundTransparency = 1,
		Font = font or Enum.Font.GothamMedium,
		TextSize = size,
		TextColor3 = color or WHITE,
		TextXAlignment = align or Enum.TextXAlignment.Center,
		Text = text,
		ZIndex = z or 3,
	}, parent)
end

local function bar(parent, w, h, x, y, rot, z)
	local f = ui("Frame", {
		Size = UDim2.fromOffset(w, h),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Rotation = rot,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = z,
	}, parent)
	corner(f, UDim.new(0, 5))
	return f
end

local function line(parent, x1, y1, x2, y2, th, color, z)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	local f = ui("Frame", {
		Size = UDim2.fromOffset(len + th * 0.6, th),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
		Rotation = math.deg(math.atan2(dy, dx)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
	}, parent)
	corner(f, UDim.new(0.5, 0))
	return f
end

local function dot(parent, cx, cy, d, color, z)
	local f = ui("Frame", {
		Size = UDim2.fromOffset(d, d),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(cx, cy),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
	}, parent)
	corner(f, UDim.new(1, 0))
	return f
end

local function drawWifi(parent, cx, cy, s, color, z)
	local parts = {}
	local th = math.max(2.5, 4 * s)
	for _, r in ipairs({ 12, 21, 30 }) do
		local prev = nil
		for a = -45, 45, 15 do
			local rad = math.rad(a)
			local px, py = cx + math.sin(rad) * r * s, cy - math.cos(rad) * r * s
			if prev then
				table.insert(parts, line(parent, prev[1], prev[2], px, py, th, color, z))
			end
			prev = { px, py }
		end
	end
	table.insert(parts, dot(parent, cx, cy, math.max(4, 8 * s), color, z))
	return parts
end

local function drawBluetooth(parent, cx, cy, s, color, z)
	local segs = {
		{ 0, -24, 0, 24 },
		{ 0, -24, 14, -10 },
		{ 14, -10, -13, 12 },
		{ 0, 24, 14, 10 },
		{ 14, 10, -13, -12 },
	}
	for _, g in ipairs(segs) do
		line(parent, cx + g[1] * s, cy + g[2] * s, cx + g[3] * s, cy + g[4] * s, 4 * s, color, z)
	end
end

local function drawSun(parent, cx, cy, s, color, z)
	dot(parent, cx, cy, 20 * s, color, z)
	for i = 0, 7 do
		local rad = math.rad(i * 45)
		line(
			parent,
			cx + math.cos(rad) * 16 * s, cy + math.sin(rad) * 16 * s,
			cx + math.cos(rad) * 23 * s, cy + math.sin(rad) * 23 * s,
			3.5 * s, color, z
		)
	end
end

local function drawSpeaker(parent, cx, cy, s, color, z)
	local pts = { { -13, -6 }, { -5, -6 }, { 4, -13 }, { 4, 13 }, { -5, 6 }, { -13, 6 }, { -13, -6 } }
	for i = 1, #pts - 1 do
		line(parent, cx + pts[i][1] * s, cy + pts[i][2] * s, cx + pts[i + 1][1] * s, cy + pts[i + 1][2] * s, 3 * s, color, z)
	end
	for _, r in ipairs({ 9, 17 }) do
		local prev = nil
		for a = -35, 35, 17.5 do
			local rad = math.rad(a)
			local px, py = cx + (4 + math.cos(rad) * r) * s, cy + math.sin(rad) * r * s
			if prev then
				line(parent, prev[1], prev[2], px, py, 3 * s, color, z)
			end
			prev = { px, py }
		end
	end
end

-- ===== SHARED STATE =====
local alive = true
local isOpen, shown = false, false
local locked, dead = true, false
local wifiOn, wifiState, wifiView = false, "off", false
local btOn, dndOn, eyeOn = false, false, false
local ccP, ccTarget, ccDragging = 0, 0, false
local appOpen = nil
local alertOn = false
local mode, dragType, curTarget = nil, nil, nil
local savedCamType = nil
local slideTween = nil
local brightV, volV = 0.85, 0.5
local tool = nil
local conns = {}
local targets = {}

local function addTarget(obj, kind, active, fn, press, set)
	table.insert(targets, { obj = obj, kind = kind, active = active, fn = fn, press = press, set = set })
end

local function ccReady()
	return ccTarget == 1 and ccP > 0.85
end

-- forward declarations (assigned further down)
local openApp, closeApp, startDownload, showAlert, hideAlert
local refreshStoreStatus, flappyReset, flappyTap
local setBrightness, setVolume, showVolHud
local refreshWifi, showWifiView
local showIPad, hideIPad, closeIPad

-- ===== APP ICON GLYPHS =====
local glyphs = {}

glyphs.store = function(f, s, u)
	bar(f, 11 * u, 66 * u, s / 2 - 14 * u, 52 * u, 22, 4)
	bar(f, 11 * u, 66 * u, s / 2 + 14 * u, 52 * u, -22, 4)
	bar(f, 40 * u, 9 * u, s / 2, 64 * u, 0, 4)
	dot(f, 78 * u, 22 * u, 8 * u, WHITE, 4)
end

glyphs.roblox = function(f, s, u)
	local sq = ui("Frame", {
		Size = UDim2.fromOffset(60 * u, 60 * u),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(s / 2, s / 2),
		Rotation = -15,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, f)
	corner(sq, UDim.new(0, 8 * u))
	local hole = ui("Frame", {
		Size = UDim2.fromOffset(20 * u, 20 * u),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(35, 36, 42),
		BorderSizePixel = 0,
		ZIndex = 5,
	}, sq)
	corner(hole, UDim.new(0, 3 * u))
end

glyphs.flappy = function(f, s, u)
	-- little pipe stub
	local pipe = ui("Frame", {
		Size = UDim2.fromOffset(26 * u, 30 * u),
		Position = UDim2.fromOffset(s - 46 * u, s - 44 * u),
		BackgroundColor3 = Color3.fromRGB(115, 190, 46),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, f)
	ui("UIStroke", { Color = Color3.fromRGB(70, 120, 30), Thickness = 2 }, pipe)
	-- bird
	dot(f, s / 2 - 4 * u, s / 2 - 6 * u, 54 * u, Color3.fromRGB(255, 214, 48), 4)
	dot(f, s / 2 - 16 * u, s / 2 + 2 * u, 24 * u, Color3.fromRGB(240, 170, 30), 5)
	dot(f, s / 2 + 10 * u, s / 2 - 16 * u, 20 * u, WHITE, 5)
	dot(f, s / 2 + 14 * u, s / 2 - 16 * u, 9 * u, BLACK, 6)
	local beak = ui("Frame", {
		Size = UDim2.fromOffset(26 * u, 15 * u),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(s / 2 + 28 * u, s / 2),
		BackgroundColor3 = Color3.fromRGB(255, 128, 40),
		BorderSizePixel = 0,
		ZIndex = 5,
	}, f)
	corner(beak, UDim.new(0.5, 0))
end

glyphs.minecraft = function(f, s, u)
	local g1, g2 = Color3.fromRGB(96, 170, 60), Color3.fromRGB(78, 148, 48)
	local d1, d2 = Color3.fromRGB(134, 96, 58), Color3.fromRGB(112, 78, 46)
	local cols = {
		{ g1, g2, g1 },
		{ d1, g1, d1 },
		{ d2, d1, d2 },
	}
	local px = 30 * u
	local x0, y0 = (s - 3 * px) / 2, (s - 3 * px) / 2
	for r = 1, 3 do
		for c = 1, 3 do
			ui("Frame", {
				Size = UDim2.fromOffset(px, px),
				Position = UDim2.fromOffset(x0 + (c - 1) * px, y0 + (r - 1) * px),
				BackgroundColor3 = cols[r][c],
				BorderSizePixel = 0,
				ZIndex = 4,
			}, f)
		end
	end
end

glyphs.amongus = function(f, s, u)
	local red = Color3.fromRGB(197, 17, 17)
	local function rr(w, h, x, y, color, rad, z)
		local o = ui("Frame", {
			Size = UDim2.fromOffset(w, h),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
		}, f)
		corner(o, UDim.new(0, rad))
		return o
	end
	rr(18 * u, 34 * u, s / 2 - 30 * u, s / 2 + 4 * u, red, 8 * u, 4)
	rr(50 * u, 62 * u, s / 2, s / 2 - 2 * u, red, 22 * u, 5)
	rr(22 * u, 22 * u, s / 2 - 12 * u, s / 2 + 30 * u, red, 6 * u, 4)
	rr(22 * u, 22 * u, s / 2 + 12 * u, s / 2 + 30 * u, red, 6 * u, 4)
	rr(32 * u, 20 * u, s / 2 + 8 * u, s / 2 - 14 * u, Color3.fromRGB(150, 225, 245), 10 * u, 6)
end

glyphs.spotify = function(f, s, u)
	dot(f, s / 2, s / 2, 76 * u, Color3.fromRGB(30, 215, 96), 3)
	local dark = Color3.fromRGB(18, 18, 20)
	local arcs = { { 46, -14, 8 }, { 38, 0, 7 }, { 28, 13, 5.5 } }
	for _, a in ipairs(arcs) do
		local w, yo, d = a[1] * u, a[2] * u, a[3] * u
		local prev = nil
		for i = 0, 6 do
			local t = (i / 6) * 2 - 1
			local px = s / 2 + t * w / 2
			local py = s / 2 + yo + t * t * d
			if prev then
				line(f, prev[1], prev[2], px, py, 5 * u, dark, 4)
			end
			prev = { px, py }
		end
	end
end

glyphs.youtube = function(f, s, u)
	local r = ui("Frame", {
		Size = UDim2.fromOffset(80 * u, 56 * u),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(s / 2, s / 2),
		BackgroundColor3 = Color3.fromRGB(255, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, f)
	corner(r, UDim.new(0, 16 * u))
	local pts = { { -8, -14 }, { -8, 14 }, { 16, 0 } }
	for i = 1, 3 do
		local a, b = pts[i], pts[i % 3 + 1]
		line(f, s / 2 + a[1] * u, s / 2 + a[2] * u, s / 2 + b[1] * u, s / 2 + b[2] * u, 7 * u, WHITE, 4)
	end
end

-- ===== APP CATALOG =====
local APPS = {
	{ id = "store", name = "App Store", sub = "", c1 = Color3.fromRGB(80, 215, 255), c2 = Color3.fromRGB(10, 95, 250), glyph = glyphs.store, time = 0 },
	{ id = "roblox", name = "Roblox", sub = "Play millions of games", c1 = Color3.fromRGB(78, 78, 88), c2 = Color3.fromRGB(22, 22, 28), glyph = glyphs.roblox, time = 14 },
	{ id = "flappy", name = "Flappy Bird", sub = "Tap to flap, dodge the pipes", c1 = Color3.fromRGB(112, 205, 255), c2 = Color3.fromRGB(60, 165, 235), glyph = glyphs.flappy, time = 6 },
	{ id = "minecraft", name = "Minecraft", sub = "Build and explore", c1 = Color3.fromRGB(134, 96, 58), c2 = Color3.fromRGB(90, 60, 36), glyph = glyphs.minecraft, time = 18 },
	{ id = "amongus", name = "Among Us", sub = "Find the impostor", c1 = Color3.fromRGB(40, 48, 86), c2 = Color3.fromRGB(14, 18, 40), glyph = glyphs.amongus, time = 12 },
	{ id = "spotify", name = "Spotify", sub = "Music for everyone", c1 = Color3.fromRGB(34, 34, 38), c2 = Color3.fromRGB(12, 12, 14), glyph = glyphs.spotify, time = 9 },
	{ id = "youtube", name = "YouTube", sub = "Watch videos", c1 = Color3.fromRGB(255, 255, 255), c2 = Color3.fromRGB(232, 232, 240), glyph = glyphs.youtube, time = 8 },
}
local APPSById = {}
for _, a in ipairs(APPS) do
	APPSById[a.id] = a
end

local function makeAppIcon(parent, app, s, x, y, z)
	local f = ui("Frame", {
		Size = UDim2.fromOffset(s, s),
		Position = UDim2.fromOffset(x, y),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = z,
	}, parent)
	corner(f, UDim.new(0, s * 0.235))
	ui("UIGradient", { Color = ColorSequence.new(app.c1, app.c2), Rotation = 90 }, f)
	ui("UIStroke", { Color = WHITE, Thickness = 1.2, Transparency = 0.8 }, f)
	app.glyph(f, s, s / 110)
	return f
end

-- ===== HOME SCREEN =====
local home = wallpaper("Home", Color3.fromRGB(14, 120, 170), Color3.fromRGB(52, 84, 210), Color3.fromRGB(150, 72, 215), 70, 1)
blob(home, -120, 80, 420, Color3.fromRGB(120, 255, 235), 0.82)
blob(home, 330, 330, 460, Color3.fromRGB(255, 170, 255), 0.84)
blob(home, 40, 640, 360, Color3.fromRGB(110, 190, 255), 0.8)

local homeBar = ui("Frame", {
	Size = UDim2.fromOffset(200, 7),
	Position = UDim2.fromOffset(CW / 2 - 100, CH - 26),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	ZIndex = 2,
}, home)
corner(homeBar, UDim.new(1, 0))

local homeContent = group(home, 3)

local homeEntries = {}
local slotCount = 0

local function slotPos(slot)
	local col, row = (slot - 1) % 4, math.floor((slot - 1) / 4)
	return 38 + col * 148, 130 + row * 190
end

local function homeActive()
	return not locked and ccTarget == 0 and ccP < 0.05 and not dead and appOpen == nil
end

local function addHomeIcon(app, installed)
	slotCount = slotCount + 1
	local x, y = slotPos(slotCount)
	local frame = makeAppIcon(homeContent, app, 110, x, y, 3)
	local sc = ui("UIScale", { Scale = 1 }, frame)
	local rad = UDim.new(0, 110 * 0.235)
	local dimF = ui("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, frame)
	corner(dimF, rad)
	local dl = ui("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = installed and 1 or 0.45,
		BorderSizePixel = 0,
		ZIndex = 9,
	}, frame)
	corner(dl, rad)
	local track = ui("Frame", {
		Size = UDim2.fromOffset(86, 8),
		Position = UDim2.fromOffset(12, 88),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Visible = not installed,
		ZIndex = 10,
	}, frame)
	corner(track, UDim.new(1, 0))
	local fill = ui("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, track)
	corner(fill, UDim.new(1, 0))

	local lab = label(homeContent, app.name, x - 15, y + 118, 140, 24, 20, WHITE, Enum.Font.GothamMedium, nil, 3)
	lab.TextStrokeTransparency = 0.85

	-- invisible hit area (not faded, not scaled)
	local hit = ui("Frame", {
		Size = UDim2.fromOffset(130, 160),
		Position = UDim2.fromOffset(x - 10, y - 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, home)

	local entry = { app = app, installed = installed, frame = frame, scale = sc, dl = dl, track = track, fill = fill }
	homeEntries[app.id] = entry

	addTarget(hit, "tap", homeActive, function()
		if entry.installed then
			openApp(app.id)
		end
	end, function(on)
		TweenService:Create(
			sc,
			TweenInfo.new(on and 0.08 or 0.25, on and Enum.EasingStyle.Quad or Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = on and 0.88 or 1 }
		):Play()
		TweenService:Create(dimF, TweenInfo.new(0.1), { BackgroundTransparency = on and 0.75 or 1 }):Play()
	end)
	return entry
end

addHomeIcon(APPSById.store, true)

-- ===== APP LAYER (store, flappy bird, generic apps) =====
local appLayer = ui("Frame", {
	Name = "AppLayer",
	Size = UDim2.fromScale(1, 1),
	Position = UDim2.fromOffset(0, CH),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 4,
}, sg)

local appBar = ui("Frame", {
	Size = UDim2.fromOffset(200, 7),
	Position = UDim2.fromOffset(CW / 2 - 100, CH - 26),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	ZIndex = 20,
}, appLayer)
corner(appBar, UDim.new(1, 0))

-- ---------- APP STORE ----------
local storeFrame = ui("Frame", {
	Name = "Store",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(20, 20, 28),
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 1,
}, appLayer)

label(storeFrame, "App Store", 34, 58, 420, 56, 44, WHITE, Enum.Font.GothamBold, Enum.TextXAlignment.Left, 2)
local storeStatus = label(storeFrame, "", 34, 116, 560, 28, 20, GRAY, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 2)

local installState = {}
local storeRows = {}

local function storeActive()
	return appOpen == "store" and ccTarget == 0 and ccP < 0.05 and not dead and not alertOn
end

local function refreshRow(app)
	local r, st = storeRows[app.id], installState[app.id]
	if not r then return end
	if st.state == "none" then
		r.btn.BackgroundColor3 = BLUE
		r.fill.Visible = false
		r.txt.Text = "GET"
		r.txt.TextSize = 22
		r.txt.TextColor3 = WHITE
	elseif st.state == "downloading" then
		r.btn.BackgroundColor3 = Color3.fromRGB(60, 60, 76)
		r.fill.Visible = true
		r.fill.Size = UDim2.fromScale(st.p, 1)
		if wifiState == "connected" then
			r.txt.Text = math.floor(st.p * 100) .. "%"
			r.txt.TextSize = 22
		else
			r.txt.Text = "Waiting..."
			r.txt.TextSize = 17
		end
		r.txt.TextColor3 = WHITE
	else
		r.btn.BackgroundColor3 = Color3.fromRGB(60, 60, 76)
		r.fill.Visible = false
		r.txt.Text = "OPEN"
		r.txt.TextSize = 22
		r.txt.TextColor3 = BLUE
	end
end

local function onStoreButton(app)
	local st = installState[app.id]
	if st.state == "installed" then
		openApp(app.id)
	elseif st.state == "none" then
		if wifiState ~= "connected" then
			showAlert() -- no downloads without Wi-Fi
		else
			startDownload(app)
		end
	end
end

local rowCount = 0
for _, app in ipairs(APPS) do
	if app.id ~= "store" then
		local ry = 170 + rowCount * 100
		rowCount = rowCount + 1
		makeAppIcon(storeFrame, app, 80, 34, ry, 2)
		label(storeFrame, app.name, 134, ry + 6, 330, 34, 28, WHITE, Enum.Font.GothamBold, Enum.TextXAlignment.Left, 2)
		label(storeFrame, app.sub, 134, ry + 44, 330, 26, 18, GRAY, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 2)
		local btn = ui("Frame", {
			Size = UDim2.fromOffset(120, 46),
			Position = UDim2.fromOffset(476, ry + 17),
			BackgroundColor3 = BLUE,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 2,
		}, storeFrame)
		corner(btn, UDim.new(1, 0))
		local fill = ui("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = BLUE,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 3,
		}, btn)
		corner(fill, UDim.new(1, 0))
		local txt = label(btn, "GET", 0, 0, 120, 46, 22, WHITE, Enum.Font.GothamBold, nil, 4)
		ui("Frame", {
			Size = UDim2.fromOffset(562, 1),
			Position = UDim2.fromOffset(34, ry + 90),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, storeFrame)

		storeRows[app.id] = { btn = btn, fill = fill, txt = txt }
		installState[app.id] = { state = "none", p = 0 }
		addTarget(btn, "tap", storeActive, function()
			onStoreButton(app)
		end, function(on)
			btn.BackgroundTransparency = on and 0.3 or 0
		end)
	end
end

-- "Wi-Fi required" alert
local alertFrame = ui("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = BLACK,
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 30,
}, storeFrame)
local alertBox = ui("Frame", {
	Size = UDim2.fromOffset(470, 250),
	Position = UDim2.fromOffset((CW - 470) / 2, 300),
	BackgroundColor3 = Color3.fromRGB(46, 46, 60),
	BorderSizePixel = 0,
	ZIndex = 31,
}, alertFrame)
corner(alertBox, UDim.new(0, 30))
label(alertBox, "Wi-Fi Required", 0, 26, 470, 40, 30, WHITE, Enum.Font.GothamBold, nil, 32)
local alertMsg = label(alertBox, "Connect to Wi-Fi to download apps.", 40, 74, 390, 80, 22, GRAY, Enum.Font.GothamMedium, nil, 32)
alertMsg.TextWrapped = true
ui("Frame", {
	Size = UDim2.fromOffset(470, 1),
	Position = UDim2.fromOffset(0, 170),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.85,
	BorderSizePixel = 0,
	ZIndex = 32,
}, alertBox)
local alertOk = ui("Frame", {
	Size = UDim2.fromOffset(470, 79),
	Position = UDim2.fromOffset(0, 171),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 32,
}, alertBox)
label(alertOk, "OK", 0, 0, 470, 79, 30, BLUE, Enum.Font.GothamBold, nil, 33)

showAlert = function()
	alertOn = true
	alertFrame.Visible = true
end
hideAlert = function()
	alertOn = false
	alertFrame.Visible = false
end
addTarget(alertOk, "tap", function()
	return appOpen == "store" and alertOn and ccTarget == 0 and ccP < 0.05 and not dead
end, function()
	hideAlert()
end)

refreshStoreStatus = function()
	if wifiState == "connected" then
		storeStatus.Text = "Connected to " .. WIFI_NAME
		storeStatus.TextColor3 = GREEN
	else
		storeStatus.Text = "No Wi-Fi connection. Connect to download apps."
		storeStatus.TextColor3 = ORANGE
	end
end
refreshStoreStatus()

startDownload = function(app)
	local st = installState[app.id]
	if st.state ~= "none" then return end
	st.state = "downloading"
	st.p = 0
	addHomeIcon(app, false) -- icon shows up on the home screen while it downloads
	refreshRow(app)
end

local function finishInstall(app)
	local st = installState[app.id]
	st.state = "installed"
	st.p = 1
	local e = homeEntries[app.id]
	if e then
		e.installed = true
		TweenService:Create(e.dl, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		e.track.Visible = false
		TweenService:Create(e.scale, TweenInfo.new(0.15), { Scale = 1.12 }):Play()
		task.delay(0.15, function()
			TweenService:Create(e.scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
	end
	refreshRow(app)
end

-- ---------- FLAPPY BIRD ----------
local GROUND_Y, PIPE_W, GAP, SPACING = 740, 100, 230, 310
local SPEED, GRAV, FLAP = 190, 1500, -500
local BIRD_X = 170

local flappyFrame = ui("Frame", {
	Name = "Flappy",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(112, 197, 206),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Visible = false,
	ZIndex = 1,
}, appLayer)

-- clouds
for _, c in ipairs({ { 60, 330, 150 }, { 380, 260, 190 }, { 240, 600, 140 } }) do
	local cl = ui("Frame", {
		Size = UDim2.fromOffset(c[3], c[3] * 0.35),
		Position = UDim2.fromOffset(c[1], c[2]),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, flappyFrame)
	corner(cl, UDim.new(1, 0))
end

local pipes = {}
for i = 1, 3 do
	local top = ui("Frame", { BackgroundColor3 = Color3.fromRGB(115, 190, 46), BorderSizePixel = 0, ZIndex = 2 }, flappyFrame)
	ui("UIStroke", { Color = Color3.fromRGB(70, 120, 30), Thickness = 4 }, top)
	local bot = ui("Frame", { BackgroundColor3 = Color3.fromRGB(115, 190, 46), BorderSizePixel = 0, ZIndex = 2 }, flappyFrame)
	ui("UIStroke", { Color = Color3.fromRGB(70, 120, 30), Thickness = 4 }, bot)
	pipes[i] = { x = 0, gap = 400, top = top, bot = bot, scored = false }
end

local ground = ui("Frame", {
	Size = UDim2.fromOffset(CW, CH - GROUND_Y),
	Position = UDim2.fromOffset(0, GROUND_Y),
	BackgroundColor3 = Color3.fromRGB(222, 216, 150),
	BorderSizePixel = 0,
	ZIndex = 3,
}, flappyFrame)
ui("Frame", {
	Size = UDim2.fromOffset(CW, 18),
	BackgroundColor3 = Color3.fromRGB(100, 200, 60),
	BorderSizePixel = 0,
	ZIndex = 4,
}, ground)

local bird = ui("Frame", {
	Size = UDim2.fromOffset(50, 38),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(BIRD_X, 380),
	BackgroundColor3 = Color3.fromRGB(255, 214, 48),
	BorderSizePixel = 0,
	ZIndex = 5,
}, flappyFrame)
corner(bird, UDim.new(1, 0))
dot(bird, 16, 24, 18, Color3.fromRGB(240, 170, 30), 6)
dot(bird, 36, 12, 15, WHITE, 6)
dot(bird, 39, 12, 7, BLACK, 7)
local beak = ui("Frame", {
	Size = UDim2.fromOffset(18, 11),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(48, 24),
	BackgroundColor3 = Color3.fromRGB(255, 128, 40),
	BorderSizePixel = 0,
	ZIndex = 6,
}, bird)
corner(beak, UDim.new(0.5, 0))

local fScoreLabel = label(flappyFrame, "0", 0, 110, CW, 100, 84, WHITE, Enum.Font.GothamBold, nil, 6)
fScoreLabel.TextStrokeColor3 = BLACK
fScoreLabel.TextStrokeTransparency = 0.3
local fHint = label(flappyFrame, "Tap to flap", 0, 520, CW, 50, 34, WHITE, Enum.Font.GothamBold, nil, 6)
fHint.TextStrokeColor3 = BLACK
fHint.TextStrokeTransparency = 0.3

local BROWN = Color3.fromRGB(84, 56, 71)
local fOver = ui("Frame", {
	Size = UDim2.fromOffset(440, 300),
	Position = UDim2.fromOffset((CW - 440) / 2, 250),
	BackgroundColor3 = Color3.fromRGB(222, 216, 150),
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 7,
}, flappyFrame)
corner(fOver, UDim.new(0, 24))
ui("UIStroke", { Color = BROWN, Thickness = 5 }, fOver)
label(fOver, "GAME OVER", 0, 24, 440, 50, 40, Color3.fromRGB(230, 110, 30), Enum.Font.GothamBold, nil, 8)
local fOverScore = label(fOver, "Score: 0", 0, 100, 440, 40, 32, BROWN, Enum.Font.GothamBold, nil, 8)
local fOverBest = label(fOver, "Best: 0", 0, 150, 440, 40, 32, BROWN, Enum.Font.GothamBold, nil, 8)
label(fOver, "Tap to retry", 0, 225, 440, 36, 26, BROWN, Enum.Font.GothamMedium, nil, 8)

local fState, by, bv, fScore, fBest, deadAt = "ready", 380, 0, 0, 0, 0

local function flappyApply()
	bird.Position = UDim2.fromOffset(BIRD_X, by)
	bird.Rotation = math.clamp(bv * 0.08, -25, 80)
	for _, p in ipairs(pipes) do
		local topH = p.gap - GAP / 2
		p.top.Position = UDim2.fromOffset(p.x, 0)
		p.top.Size = UDim2.fromOffset(PIPE_W, topH)
		p.bot.Position = UDim2.fromOffset(p.x, p.gap + GAP / 2)
		p.bot.Size = UDim2.fromOffset(PIPE_W, GROUND_Y - (p.gap + GAP / 2))
	end
end

flappyReset = function()
	fState = "ready"
	by, bv, fScore = 380, 0, 0
	for i, p in ipairs(pipes) do
		p.x = CW + 120 + (i - 1) * SPACING
		p.gap = math.random(260, 520)
		p.scored = false
	end
	fScoreLabel.Text = "0"
	fHint.Visible = true
	fOver.Visible = false
	flappyApply()
end

local function flappyDie()
	fState = "dead"
	deadAt = os.clock()
	if fScore > fBest then fBest = fScore end
	fOverScore.Text = "Score: " .. fScore
	fOverBest.Text = "Best: " .. fBest
	fOver.Visible = true
end

flappyTap = function()
	if fState == "ready" then
		fState = "playing"
		fHint.Visible = false
		bv = FLAP
	elseif fState == "playing" then
		bv = FLAP
	elseif fState == "dead" and os.clock() - deadAt > 0.5 then
		flappyReset()
	end
end

local function flappyUpdate(dt)
	if fState == "ready" then
		by = 380 + math.sin(os.clock() * 5) * 10
		bv = 0
	elseif fState == "playing" then
		bv = bv + GRAV * dt
		by = by + bv * dt
		if by < 12 then
			by = 12
			bv = 0
		end
		-- move pipes
		local maxX = -1000
		for _, p in ipairs(pipes) do
			p.x = p.x - SPEED * dt
			if p.x > maxX then maxX = p.x end
		end
		for _, p in ipairs(pipes) do
			if p.x < -PIPE_W then
				p.x = maxX + SPACING
				maxX = p.x
				p.gap = math.random(260, 520)
				p.scored = false
			end
		end
		-- score + collisions
		local left, right, top, bottom = BIRD_X - 17, BIRD_X + 17, by - 15, by + 15
		for _, p in ipairs(pipes) do
			if not p.scored and p.x + PIPE_W < left then
				p.scored = true
				fScore = fScore + 1
				fScoreLabel.Text = tostring(fScore)
			end
			if right > p.x and left < p.x + PIPE_W then
				if top < p.gap - GAP / 2 or bottom > p.gap + GAP / 2 then
					flappyDie()
				end
			end
		end
		if bottom >= GROUND_Y then
			by = GROUND_Y - 15
			flappyDie()
		end
	elseif fState == "dead" then
		if by < GROUND_Y - 15 then
			bv = bv + GRAV * dt
			by = math.min(by + bv * dt, GROUND_Y - 15)
		end
	end
	flappyApply()
end
flappyReset()

-- ---------- GENERIC APP SCREEN (Roblox, Minecraft, ...) ----------
local genericFrame = ui("Frame", {
	Name = "Generic",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(18, 18, 26),
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 1,
}, appLayer)
local bigIcons = {}
for _, app in ipairs(APPS) do
	if app.id ~= "store" and app.id ~= "flappy" then
		local ic = makeAppIcon(genericFrame, app, 190, (CW - 190) / 2, 230, 2)
		ic.Visible = false
		bigIcons[app.id] = ic
	end
end
local genName = label(genericFrame, "", 0, 450, CW, 60, 46, WHITE, Enum.Font.GothamBold, nil, 2)
local genSub = label(genericFrame, "", 0, 515, CW, 34, 24, GRAY, Enum.Font.GothamMedium, nil, 2)
label(genericFrame, "This app has no content yet", 0, 610, CW, 30, 20, Color3.fromRGB(100, 100, 115), Enum.Font.GothamMedium, nil, 2)

-- open / close apps
local appToken = 0

openApp = function(id)
	local app = APPSById[id]
	if not app then return end
	local generic = id ~= "store" and id ~= "flappy"
	storeFrame.Visible = id == "store"
	flappyFrame.Visible = id == "flappy"
	genericFrame.Visible = generic
	if generic then
		for k, ic in pairs(bigIcons) do
			ic.Visible = (k == id)
		end
		genName.Text = app.name
		genSub.Text = app.sub
	end
	if id == "flappy" then flappyReset() end
	if id == "store" then
		hideAlert()
		refreshStoreStatus()
	end
	local already = appOpen ~= nil
	appOpen = id
	appToken = appToken + 1
	if not already then
		appLayer.Position = UDim2.fromOffset(0, CH)
		appLayer.Visible = true
		TweenService:Create(appLayer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0) }):Play()
	end
end

closeApp = function(instant)
	if not appOpen then return end
	appOpen = nil
	appToken = appToken + 1
	local my = appToken
	hideAlert()
	flappyReset()
	if instant then
		appLayer.Visible = false
		appLayer.Position = UDim2.fromOffset(0, CH)
		return
	end
	local tw = TweenService:Create(appLayer, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(0, -CH) })
	tw.Completed:Connect(function()
		if appToken == my then
			appLayer.Visible = false
			appLayer.Position = UDim2.fromOffset(0, CH)
		end
	end)
	tw:Play()
end

-- ===== LOCK SCREEN (slides up) =====
local lock = wallpaper("Lock", Color3.fromRGB(24, 20, 84), Color3.fromRGB(132, 52, 172), Color3.fromRGB(255, 128, 118), 70, 5)
blob(lock, -100, 60, 400, Color3.fromRGB(120, 140, 255), 0.82)
blob(lock, 340, 300, 440, Color3.fromRGB(255, 190, 120), 0.85)
blob(lock, 30, 620, 380, Color3.fromRGB(255, 110, 190), 0.82)

local lockContent = group(lock, 6)

local shackle = ui("Frame", {
	Size = UDim2.fromOffset(24, 24),
	Position = UDim2.fromOffset(CW / 2 - 12, 72),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 6,
}, lockContent)
corner(shackle, UDim.new(1, 0))
ui("UIStroke", { Color = WHITE, Thickness = 4, Transparency = 0.1 }, shackle)
local lockBody = ui("Frame", {
	Size = UDim2.fromOffset(38, 28),
	Position = UDim2.fromOffset(CW / 2 - 19, 90),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	ZIndex = 7,
}, lockContent)
corner(lockBody, UDim.new(0, 7))

local dateLabel = label(lockContent, "", 0, 140, CW, 40, 32, WHITE, Enum.Font.GothamMedium, nil, 6)
dateLabel.TextTransparency = 0.1
local timeLabel = label(lockContent, "", 0, 175, CW, 150, 140, WHITE, Enum.Font.GothamBold, nil, 6)

local hint = label(lockContent, "Swipe up to unlock", 0, CH - 90, CW, 36, 26, WHITE, Enum.Font.GothamMedium, nil, 6)
hint.TextTransparency = 0.15
TweenService:Create(
	hint,
	TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ TextTransparency = 0.7 }
):Play()

local lockBar = ui("Frame", {
	Size = UDim2.fromOffset(200, 7),
	Position = UDim2.fromOffset(CW / 2 - 100, CH - 26),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	ZIndex = 6,
}, lockContent)
corner(lockBar, UDim.new(1, 0))

task.spawn(function()
	while alive do
		timeLabel.Text = os.date("%H:%M")
		dateLabel.Text = os.date("%A, %B %d")
		task.wait(1)
	end
end)

-- ===== STATUS BAR (wifi + battery) =====
local status = ui("Frame", {
	Name = "StatusBar",
	Size = UDim2.fromOffset(CW, 56),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 20,
}, sg)

local dndLabel = label(status, "Do Not Disturb", 30, 14, 260, 28, 20, WHITE, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 21)
dndLabel.Visible = false

local statusWifi = drawWifi(status, CW - 192, 37, 0.55, WHITE, 21)
for _, p in ipairs(statusWifi) do
	p.BackgroundTransparency = 0.7
end

local pctLabel = label(status, "100%", CW - 160, 14, 70, 28, 22, WHITE, Enum.Font.GothamMedium, Enum.TextXAlignment.Right, 21)

local battOutline = ui("Frame", {
	Size = UDim2.fromOffset(52, 26),
	Position = UDim2.fromOffset(CW - 80, 15),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 21,
}, status)
corner(battOutline, UDim.new(0, 8))
ui("UIStroke", { Color = WHITE, Thickness = 2.5, Transparency = 0.2 }, battOutline)

local battFill = ui("Frame", {
	Size = UDim2.fromOffset(44, 18),
	Position = UDim2.fromOffset(CW - 80 + 4, 15 + 4),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 22,
}, status)
corner(battFill, UDim.new(0, 5))

local battNub = ui("Frame", {
	Size = UDim2.fromOffset(4, 11),
	Position = UDim2.fromOffset(CW - 27, 22),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	ZIndex = 21,
}, status)
corner(battNub, UDim.new(0, 2))

-- ===== OVERLAYS: volume HUD, brightness, eye protection, dead screen =====
local volHud = ui("Frame", {
	Name = "VolumeHud",
	Size = UDim2.fromOffset(300, 64),
	Position = UDim2.fromOffset((CW - 300) / 2, 66),
	BackgroundColor3 = Color3.fromRGB(34, 34, 44),
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 30,
}, sg)
corner(volHud, UDim.new(1, 0))
ui("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.85 }, volHud)
drawSpeaker(volHud, 44, 32, 0.9, WHITE, 31)
local hudTrack = ui("Frame", {
	Size = UDim2.fromOffset(180, 12),
	Position = UDim2.fromOffset(84, 26),
	BackgroundColor3 = Color3.fromRGB(90, 90, 104),
	BorderSizePixel = 0,
	ZIndex = 31,
}, volHud)
corner(hudTrack, UDim.new(1, 0))
local hudFill = ui("Frame", {
	Size = UDim2.fromScale(0.5, 1),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 32,
}, hudTrack)
corner(hudFill, UDim.new(1, 0))

local hudToken = 0
showVolHud = function()
	hudFill.Size = UDim2.fromScale(volV, 1)
	volHud.Visible = true
	hudToken = hudToken + 1
	local my = hudToken
	task.delay(1.4, function()
		if hudToken == my then
			volHud.Visible = false
		end
	end)
end

local dim = ui("Frame", {
	Name = "BrightnessDim",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = BLACK,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 90,
}, sg)

local warm = ui("Frame", {
	Name = "EyeProtection",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 160, 40),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 91,
}, sg)

local deadFrame = ui("Frame", {
	Name = "Dead",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = BLACK,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 200,
}, sg)
local deadIcon = ui("Frame", {
	Size = UDim2.fromOffset(160, 70),
	Position = UDim2.fromOffset(CW / 2 - 80, CH / 2 - 35),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 201,
}, deadFrame)
local deadBody = ui("Frame", {
	Size = UDim2.fromOffset(140, 70),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 201,
}, deadIcon)
corner(deadBody, UDim.new(0, 18))
ui("UIStroke", { Color = RED, Thickness = 5 }, deadBody)
local deadNub = ui("Frame", {
	Size = UDim2.fromOffset(8, 24),
	Position = UDim2.fromOffset(146, 23),
	BackgroundColor3 = RED,
	BorderSizePixel = 0,
	ZIndex = 201,
}, deadIcon)
corner(deadNub, UDim.new(0, 4))
local deadSliver = ui("Frame", {
	Size = UDim2.fromOffset(18, 50),
	Position = UDim2.fromOffset(10, 10),
	BackgroundColor3 = RED,
	BorderSizePixel = 0,
	ZIndex = 202,
}, deadIcon)
corner(deadSliver, UDim.new(0, 8))

-- ===== CONTROL CENTER =====
local PANEL_W, PANEL_H, PANEL_Y = 570, 450, 78

local ccRoot = ui("Frame", {
	Name = "ControlCenter",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 12,
}, sg)

local frost = ui("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(110, 115, 145),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 1,
}, ccRoot)

local panel = ui("Frame", {
	Name = "Panel",
	Size = UDim2.fromOffset(PANEL_W, PANEL_H),
	Position = UDim2.fromOffset(30, -PANEL_H - 30),
	BackgroundColor3 = Color3.fromRGB(32, 32, 42),
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	ZIndex = 2,
}, ccRoot)
corner(panel, UDim.new(0, 40))
ui("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.85 }, panel)

local ccMain = ui("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 3,
}, panel)
local ccWifi = ui("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 3,
}, panel)

local function setToggle(tile, carve, on, onColor)
	local c = on and onColor or TILE_OFF
	TweenService:Create(tile, TweenInfo.new(0.15), { BackgroundColor3 = c }):Play()
	if carve then
		TweenService:Create(carve, TweenInfo.new(0.15), { BackgroundColor3 = c }):Play()
	end
end

local function tilePress(sc)
	return function(on)
		TweenService:Create(sc, TweenInfo.new(0.1), { Scale = on and 0.92 or 1 }):Play()
	end
end

local TILE = 112
local function makeTile(i, text)
	local x = 30 + (i - 1) * (TILE + 20.67)
	local t = ui("Frame", {
		Size = UDim2.fromOffset(TILE, TILE),
		Position = UDim2.fromOffset(x, 30),
		BackgroundColor3 = TILE_OFF,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, ccMain)
	corner(t, UDim.new(0, 30))
	local sc = ui("UIScale", { Scale = 1 }, t)
	local lab = label(ccMain, text, x - 10, 30 + TILE + 8, TILE + 20, 22, 15, WHITE, Enum.Font.GothamMedium, nil, 3)
	lab.TextTransparency = 0.1
	return t, sc, lab
end

local wifiTile, wifiSc, wifiLab = makeTile(1, "Wi-Fi")
drawWifi(wifiTile, TILE / 2, 70, 1, WHITE, 5)

local btTile, btSc = makeTile(2, "Bluetooth")
drawBluetooth(btTile, TILE / 2, TILE / 2, 1, WHITE, 5)

local dndTile, dndSc = makeTile(3, "Do Not Disturb")
dot(dndTile, TILE / 2, TILE / 2, 44, WHITE, 5)
local dndCarve = dot(dndTile, TILE / 2 + 12, TILE / 2 - 8, 38, TILE_OFF, 6)

local eyeTile, eyeSc = makeTile(4, "Eye Protection")
local eyeOutline = ui("Frame", {
	Size = UDim2.fromOffset(58, 34),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(TILE / 2, TILE / 2),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 5,
}, eyeTile)
corner(eyeOutline, UDim.new(1, 0))
ui("UIStroke", { Color = WHITE, Thickness = 4 }, eyeOutline)
dot(eyeTile, TILE / 2, TILE / 2, 16, WHITE, 5)

local function makeSlider(y, text, drawIcon, init)
	local track = ui("Frame", {
		Size = UDim2.fromOffset(510, 84),
		Position = UDim2.fromOffset(30, y),
		BackgroundColor3 = Color3.fromRGB(78, 78, 92),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 3,
	}, ccMain)
	corner(track, UDim.new(0, 30))
	local fill = ui("Frame", {
		Size = UDim2.new(init, 0, 1, 0),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, track)
	corner(fill, UDim.new(0, 30))
	drawIcon(track, 48, 42, 1, Color3.fromRGB(120, 120, 135), 6)
	label(track, text, 96, 0, 300, 84, 24, Color3.fromRGB(125, 125, 140), Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 6)
	return track, fill
end

local brightTrack, brightFill = makeSlider(215, "Brightness", drawSun, brightV)
local volTrack, volFill = makeSlider(325, "Volume", drawSpeaker, volV)

setBrightness = function(v)
	brightV = math.clamp(v, 0, 1)
	brightFill.Size = UDim2.new(brightV, 0, 1, 0)
	dim.BackgroundTransparency = 1 - (1 - brightV) * 0.85
end
setVolume = function(v)
	volV = math.clamp(v, 0, 1) -- stored here, nothing plays audio yet
	volFill.Size = UDim2.new(volV, 0, 1, 0)
end
setBrightness(brightV)

-- Wi-Fi view
local wBack = ui("Frame", {
	Size = UDim2.fromOffset(200, 64),
	Position = UDim2.fromOffset(14, 16),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 3,
}, ccWifi)
label(wBack, "< Back", 10, 7, 180, 50, 26, BLUE, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 4)
label(ccWifi, "Wi-Fi", 0, 24, PANEL_W, 50, 30, WHITE, Enum.Font.GothamBold, nil, 3)

local swRow = ui("Frame", {
	Size = UDim2.fromOffset(510, 84),
	Position = UDim2.fromOffset(30, 96),
	BackgroundColor3 = ROW,
	BorderSizePixel = 0,
	ZIndex = 3,
}, ccWifi)
corner(swRow, UDim.new(0, 26))
label(swRow, "Wi-Fi", 28, 0, 200, 84, 28, WHITE, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 4)
local swTrack = ui("Frame", {
	Size = UDim2.fromOffset(94, 54),
	Position = UDim2.fromOffset(510 - 94 - 24, 15),
	BackgroundColor3 = Color3.fromRGB(86, 86, 100),
	BorderSizePixel = 0,
	ZIndex = 4,
}, swRow)
corner(swTrack, UDim.new(1, 0))
local swKnob = ui("Frame", {
	Size = UDim2.fromOffset(46, 46),
	Position = UDim2.fromOffset(4, 4),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 5,
}, swTrack)
corner(swKnob, UDim.new(1, 0))

local netHeader = label(ccWifi, "NETWORKS", 44, 204, 300, 24, 16, GRAY, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 3)

local netRow = ui("Frame", {
	Size = UDim2.fromOffset(510, 84),
	Position = UDim2.fromOffset(30, 235),
	BackgroundColor3 = ROW,
	BorderSizePixel = 0,
	ZIndex = 3,
}, ccWifi)
corner(netRow, UDim.new(0, 26))
drawWifi(netRow, 50, 58, 0.6, WHITE, 5)
label(netRow, WIFI_NAME, 88, 0, 260, 84, 28, WHITE, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 4)
local netStatus = label(netRow, "", 300, 0, 190, 84, 22, GRAY, Enum.Font.GothamMedium, Enum.TextXAlignment.Right, 4)

local netInfo = label(ccWifi, "Turn on Wi-Fi to see networks", 30, 235, 510, 84, 24, GRAY, Enum.Font.GothamMedium, nil, 3)

-- ===== CAMERA HELPERS =====
local function restoreCamera()
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = savedCamType or Enum.CameraType.Custom
	end
end

local function freezeCamera()
	local cam = Workspace.CurrentCamera
	if cam then
		savedCamType = cam.CameraType
		cam.CameraType = Enum.CameraType.Scriptable
	end
end

-- ===== BATTERY =====
local batt = 100
local DRAIN_SECONDS = DRAIN_MINUTES * 60

local function updateBattery()
	pctLabel.Text = math.ceil(batt) .. "%"
	battFill.Size = UDim2.fromOffset(math.floor(44 * batt / 100), 18)
	battFill.BackgroundColor3 = batt <= 20 and RED or WHITE
end

local function powerOff()
	dead = true
	ccTarget = 0
	ccDragging = false
	if mode then
		mode = nil
		restoreCamera()
	end
	deadIcon.Visible = false
	deadFrame.Visible = true
	TweenService:Create(deadFrame, TweenInfo.new(0.8), { BackgroundTransparency = 0 }):Play()
	task.delay(0.9, function()
		deadIcon.Visible = true
	end)
end

task.spawn(function()
	while alive and not dead do
		task.wait(1)
		if isOpen then
			batt = math.max(0, batt - 100 / DRAIN_SECONDS)
			updateBattery()
			if batt <= 0 then
				powerOff()
			end
		end
	end
end)

-- ===== WI-FI LOGIC =====
refreshWifi = function()
	TweenService:Create(swTrack, TweenInfo.new(0.2), { BackgroundColor3 = wifiOn and GREEN or Color3.fromRGB(86, 86, 100) }):Play()
	TweenService:Create(swKnob, TweenInfo.new(0.2), { Position = wifiOn and UDim2.fromOffset(94 - 50, 4) or UDim2.fromOffset(4, 4) }):Play()

	local showList = wifiOn and wifiState ~= "scanning"
	netHeader.Visible = showList
	netRow.Visible = showList
	netInfo.Visible = not showList
	netInfo.Text = wifiOn and "Searching..." or "Turn on Wi-Fi to see networks"

	if wifiState == "connecting" then
		netStatus.Text = "Connecting..."
		netStatus.TextColor3 = GRAY
	elseif wifiState == "connected" then
		netStatus.Text = "Connected"
		netStatus.TextColor3 = BLUE
	else
		netStatus.Text = ""
	end

	setToggle(wifiTile, nil, wifiOn, BLUE)
	if wifiState == "connected" then
		wifiLab.Text = WIFI_NAME
	elseif wifiOn then
		wifiLab.Text = "Not Connected"
	else
		wifiLab.Text = "Wi-Fi"
	end

	for _, p in ipairs(statusWifi) do
		p.BackgroundTransparency = wifiState == "connected" and 0 or 0.7
	end

	refreshStoreStatus()
end

local wifiToken = 0
local function setWifi(on)
	wifiToken = wifiToken + 1
	local my = wifiToken
	wifiOn = on
	if on then
		wifiState = "scanning"
		refreshWifi()
		task.delay(1.2, function()
			if wifiToken == my and wifiOn then
				wifiState = "idle"
				refreshWifi()
			end
		end)
	else
		wifiState = "off"
		refreshWifi()
	end
end

local function tapNetwork()
	if wifiState == "idle" then
		wifiToken = wifiToken + 1
		local my = wifiToken
		wifiState = "connecting"
		refreshWifi()
		task.delay(1.6, function()
			if wifiToken == my and wifiOn then
				wifiState = "connected"
				refreshWifi()
			end
		end)
	elseif wifiState == "connected" then
		wifiToken = wifiToken + 1
		wifiState = "idle" -- tap again to disconnect
		refreshWifi()
	end
end

showWifiView = function(v)
	wifiView = v
	ccMain.Visible = not v
	ccWifi.Visible = v
end
refreshWifi()

-- ===== CONTROL CENTER LOGIC =====
local function setCC(p)
	ccRoot.Visible = p > 0.002
	frost.BackgroundTransparency = 1 - (appOpen and 0.8 or 0.5) * p
	local closedY = -PANEL_H - 30
	panel.Position = UDim2.fromOffset(30, closedY + (PANEL_Y - closedY) * p)
	-- home/lock content fades out completely behind the menu (no overlapping icons)
	homeContent.GroupTransparency = p
	lockContent.GroupTransparency = p
	for _, sc in ipairs(blobScales) do
		sc.Scale = 1 + 0.4 * p -- blobs swell and soften = blur
	end
end

local function ccActiveMain()
	return ccReady() and not wifiView and not dead
end
local function ccActiveWifi()
	return ccReady() and wifiView and not dead
end

addTarget(wifiTile, "tap", ccActiveMain, function() showWifiView(true) end, tilePress(wifiSc))
addTarget(btTile, "tap", ccActiveMain, function()
	btOn = not btOn
	setToggle(btTile, nil, btOn, BLUE)
end, tilePress(btSc))
addTarget(dndTile, "tap", ccActiveMain, function()
	dndOn = not dndOn
	setToggle(dndTile, dndCarve, dndOn, PURPLE)
	dndLabel.Visible = dndOn
end, tilePress(dndSc))
addTarget(eyeTile, "tap", ccActiveMain, function()
	eyeOn = not eyeOn
	setToggle(eyeTile, nil, eyeOn, ORANGE)
	TweenService:Create(warm, TweenInfo.new(0.3), { BackgroundTransparency = eyeOn and 0.86 or 1 }):Play()
end, tilePress(eyeSc))
addTarget(brightTrack, "slider", ccActiveMain, nil, nil, setBrightness)
addTarget(volTrack, "slider", ccActiveMain, nil, nil, setVolume)

addTarget(wBack, "tap", ccActiveWifi, function() showWifiView(false) end)
addTarget(swRow, "tap", ccActiveWifi, function() setWifi(not wifiOn) end)
addTarget(netRow, "tap", function()
	return ccActiveWifi() and wifiOn and wifiState ~= "scanning"
end, tapNetwork)

-- ===== SPRINGS =====
local sPush = { p = 0, v = 0, t = 0 }
local sOpen = { p = 0, v = 0, t = 0 }
local function stepSpring(s, dt, k, d)
	local a = (s.t - s.p) * k - s.v * d
	s.v = s.v + a * dt
	s.p = s.p + s.v * dt
end

local function pulse()
	sPush.t = PUSH
	task.delay(0.09, function()
		sPush.t = 0
	end)
end

-- ===== SHOW / HIDE THE IPAD (inventory item) =====
local function setShown(v)
	shown = v
	for p, tr in pairs(origTr) do
		p.Transparency = v and tr or 1
	end
	sg.Enabled = v
end
setShown(false)

showIPad = function()
	if isOpen then return end
	isOpen = true
	setShown(true)
	sOpen.t = 1
end

hideIPad = function()
	if not isOpen then return end
	isOpen = false
	sOpen.t = 0
	if mode then
		mode = nil
		restoreCamera()
	end
	ccDragging = false
	ccTarget = 0
	ccP = 0
	showWifiView(false)
	closeApp(true)
	if RELOCK_ON_CLOSE then
		locked = true
		if slideTween then slideTween:Cancel() end
		lock.Visible = true
		lock.Position = UDim2.fromOffset(0, 0)
	end
end

closeIPad = function()
	local bp = player:FindFirstChildOfClass("Backpack")
	if tool and bp and tool.Parent ~= bp then
		tool.Parent = bp
	end
	hideIPad()
end

-- ===== PLACE IN FRONT OF CAMERA (with sideways tilt) =====
model.PrimaryPart = body
model.Parent = Workspace

local tgtTilt, curTilt = 0, 0
local ccDrawn = -1

conns[#conns + 1] = RunService.RenderStepped:Connect(function(dt)
	if not alive then return end
	local cam = Workspace.CurrentCamera
	if not cam then return end
	dt = math.min(dt, 1 / 30)

	stepSpring(sOpen, dt, 120, 15)
	if not isOpen and shown and sOpen.p < 0.03 then
		setShown(false)
	end
	if not shown then return end

	curTilt = curTilt + (tgtTilt - curTilt) * math.min(1, dt * 12)
	stepSpring(sPush, dt, 260, 16)

	local tiltCF
	if TILT_MODE == "roll" then
		tiltCF = CFrame.Angles(0, 0, -curTilt)
	else
		tiltCF = CFrame.Angles(0, curTilt, 0)
	end

	-- the whole model (frame + screen + buttons) moves/tilts together
	model:PivotTo(
		cam.CFrame
			* CFrame.new(0, -(1 - sOpen.p) * 3.8, -DIST)
			* tiltCF
			* CFrame.new(0, 0, -sPush.p)
	)

	-- control center animation
	if not ccDragging then
		ccP = ccP + (ccTarget - ccP) * math.min(1, dt * 14)
		if math.abs(ccTarget - ccP) < 0.003 then
			ccP = ccTarget
		end
	end
	if ccP ~= ccDrawn then
		ccDrawn = ccP
		setCC(ccP)
	end
	if ccP == 0 and wifiView then
		showWifiView(false)
	end

	-- flappy bird (pauses while the control center is open)
	if appOpen == "flappy" and ccP < 0.01 and not dead then
		flappyUpdate(dt)
	end
end)

-- ===== DOWNLOADS (only while Wi-Fi is connected) =====
conns[#conns + 1] = RunService.Heartbeat:Connect(function(dt)
	if not alive or dead then return end
	for _, app in ipairs(APPS) do
		local st = installState[app.id]
		if st and st.state == "downloading" then
			if wifiState == "connected" then
				st.p = math.min(1, st.p + dt / app.time)
			end
			local e = homeEntries[app.id]
			if e then
				e.fill.Size = UDim2.fromScale(st.p, 1)
			end
			if st.p >= 1 then
				finishInstall(app)
			else
				refreshRow(app)
			end
		end
	end
end)

-- ===== INPUT (finger ray -> screen plane, works while tilted) =====
local startY, startT, lastDy = 0, 0, 0
local cy0, lastCx, lastCy = 0, 0, 0
local startedOutside = false
local tiltStartX, tiltStart0, tiltMoved = 0, 0, 0
local lastTiltTap = 0
local btnName = nil
local repeatToken = 0

local function toLocal(pos)
	local cam = Workspace.CurrentCamera
	if not cam then return nil end
	local ray = cam:ScreenPointToRay(pos.X, pos.Y)
	local n = screen.CFrame.ZVector
	local denom = ray.Direction:Dot(n)
	if math.abs(denom) < 1e-4 then return nil end
	local t = (screen.Position - ray.Origin):Dot(n) / denom
	if t < 0 then return nil end
	return screen.CFrame:PointToObjectSpace(ray.Origin + ray.Direction * t)
end

local function canvasXY(lp)
	return (lp.X + SW / 2) / SW * CW, (SH / 2 - lp.Y) / SH * CH
end

local function inside(obj, cx, cy)
	local p, s = obj.AbsolutePosition, obj.AbsoluteSize
	return cx >= p.X and cx <= p.X + s.X and cy >= p.Y and cy <= p.Y + s.Y
end

local function findTarget(cx, cy)
	for _, t in ipairs(targets) do
		if t.active() and inside(t.obj, cx, cy) then
			return t
		end
	end
	return nil
end

local function sliderValue(t, cx)
	local p, s = t.obj.AbsolutePosition, t.obj.AbsoluteSize
	return math.clamp((cx - p.X) / s.X, 0, 1)
end

-- which physical button (if any) is under the finger? (screen-local coordinates)
local function hitButton(lp)
	local x, y = lp.X, lp.Y
	-- top button = close
	if math.abs(x - (BW / 2 - 0.6 * K)) <= 0.4 * K and y >= BH / 2 - 0.12 * K and y <= BH / 2 + 0.5 * K then
		return "power"
	end
	-- side buttons = volume
	if x >= BW / 2 - 0.1 * K and x <= BW / 2 + 0.5 * K then
		if math.abs(y - (BH / 2 - 0.8 * K)) <= 0.19 * K then return "volup" end
		if math.abs(y - (BH / 2 - 1.2 * K)) <= 0.19 * K then return "voldown" end
	end
	return nil
end

-- little "button pressed" animation
local function nudge(p, v)
	p.CFrame = p.CFrame * CFrame.new(v)
	task.delay(0.12, function()
		if p.Parent then
			p.CFrame = p.CFrame * CFrame.new(-v)
		end
	end)
end

local function doVolume(name)
	if name == "volup" then
		setVolume(volV + VOL_STEP)
		nudge(volUpBtn, Vector3.new(-0.04 * K, 0, 0))
	else
		setVolume(volV - VOL_STEP)
		nudge(volDownBtn, Vector3.new(-0.04 * K, 0, 0))
	end
	showVolHud()
end

local function unlock()
	locked = false
	if slideTween then slideTween:Cancel() end
	slideTween = TweenService:Create(
		lock,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(0, -CH - 20) }
	)
	slideTween.Completed:Connect(function()
		if not locked then
			lock.Visible = false
		end
	end)
	slideTween:Play()
end

local function snapBack()
	if slideTween then slideTween:Cancel() end
	slideTween = TweenService:Create(
		lock,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(0, 0) }
	)
	slideTween:Play()
end

conns[#conns + 1] = UIS.InputBegan:Connect(function(input)
	if not alive or not isOpen or mode then return end
	local ut = input.UserInputType
	if ut ~= Enum.UserInputType.Touch and ut ~= Enum.UserInputType.MouseButton1 then return end

	local lp = toLocal(input.Position)
	if not lp then return end

	local onScreen = math.abs(lp.X) <= SW / 2 and math.abs(lp.Y) <= SH / 2
	local inFrame = math.abs(lp.X) <= BW / 2 + TILT_MARGIN and math.abs(lp.Y) <= BH / 2 + TILT_MARGIN
	if not inFrame then return end
	if dead and onScreen then return end -- iPad is off

	dragType = ut
	freezeCamera()

	if not onScreen then
		local b = hitButton(lp)
		if b then
			mode = "button"
			btnName = b
			if b == "volup" or b == "voldown" then
				doVolume(b)
				repeatToken = repeatToken + 1
				local my = repeatToken
				task.spawn(function()
					task.wait(0.4)
					while mode == "button" and repeatToken == my do
						doVolume(b)
						task.wait(0.12)
					end
				end)
			end
			return
		end
		-- sideways tilt (frame / just outside it)
		mode = "tilt"
		tiltStartX = input.Position.X
		tiltStart0 = tgtTilt
		tiltMoved = 0
		return
	end

	local cx, cy = canvasXY(lp)
	lastCx, lastCy = cx, cy
	pulse() -- push-back "force" on every tap

	if ccTarget == 1 then
		-- control center is open
		local tgt = nil
		if ccP > 0.85 then
			tgt = findTarget(cx, cy)
		end
		if tgt then
			curTarget = tgt
			if tgt.kind == "slider" then
				mode = "slider"
				tgt.set(sliderValue(tgt, cx))
			else
				mode = "cctap"
				if tgt.press then tgt.press(true) end
			end
		else
			mode = "ccclose"
			cy0 = cy
			ccDragging = true
			startedOutside = not inside(panel, cx, cy)
		end
	elseif cx >= CW - 300 and cy <= 80 then
		-- pressed on the battery / wifi area: pull down for control center
		mode = "ccpull"
		cy0 = cy
		startT = os.clock()
		ccDragging = true
	elseif appOpen and cy >= CH - 110 then
		-- swipe up from the bottom = leave the app
		mode = "appclose"
		cy0 = cy
		startT = os.clock()
	elseif locked then
		mode = "swipe"
		startY = lp.Y
		startT = os.clock()
		lastDy = 0
		if slideTween then slideTween:Cancel() end
	else
		local tgt = findTarget(cx, cy)
		if tgt then
			curTarget = tgt
			mode = "cctap"
			if tgt.press then tgt.press(true) end
		else
			mode = "tap"
			if appOpen == "flappy" then
				flappyTap()
			end
		end
	end
end)

conns[#conns + 1] = UIS.InputChanged:Connect(function(input)
	if not mode then return end
	local ut = input.UserInputType
	local ok = (dragType == Enum.UserInputType.Touch and ut == Enum.UserInputType.Touch)
		or (dragType == Enum.UserInputType.MouseButton1 and ut == Enum.UserInputType.MouseMovement)
	if not ok then return end

	if mode == "tilt" then
		local dx = input.Position.X - tiltStartX
		tiltMoved = math.max(tiltMoved, math.abs(dx))
		tgtTilt = math.clamp(tiltStart0 + math.rad(dx * TILT_SPEED), -MAX_TILT, MAX_TILT)
		return
	end
	if mode == "button" then return end

	local lp = toLocal(input.Position)
	if not lp then return end
	local cx, cy = canvasXY(lp)
	lastCx, lastCy = cx, cy

	if mode == "swipe" then
		local dy = math.max(0, lp.Y - startY)
		lastDy = dy
		lock.Position = UDim2.fromOffset(0, -(dy / SH) * CH)
	elseif mode == "ccpull" then
		ccP = math.clamp((cy - cy0) / 330, 0, 1)
	elseif mode == "ccclose" then
		ccP = math.clamp(1 + (cy - cy0) / 330, 0, 1)
	elseif mode == "appclose" then
		local dy = math.max(0, cy0 - cy)
		appLayer.Position = UDim2.fromOffset(0, -dy)
	elseif mode == "slider" and curTarget then
		curTarget.set(sliderValue(curTarget, cx))
	end
end)

conns[#conns + 1] = UIS.InputEnded:Connect(function(input)
	if not mode then return end
	if input.UserInputType ~= dragType then return end

	local m = mode
	mode = nil
	restoreCamera()

	if m == "button" then
		repeatToken = repeatToken + 1
		if btnName == "power" then
			nudge(powerBtn, Vector3.new(0, -0.04 * K, 0))
			closeIPad() -- top button closes the iPad
		end
	elseif m == "swipe" then
		local dt = math.max(os.clock() - startT, 0.05)
		local speed = lastDy / dt
		if lastDy > SH * 0.3 or (lastDy > SH * 0.08 and speed > SH * 1.4) then
			unlock()
		else
			snapBack()
		end
	elseif m == "ccpull" then
		ccDragging = false
		local dt = math.max(os.clock() - startT, 0.05)
		local speed = (lastCy - cy0) / dt
		if ccP > 0.4 or (speed > 900 and ccP > 0.08) then
			ccTarget = 1
		else
			ccTarget = 0
		end
	elseif m == "ccclose" then
		ccDragging = false
		if (startedOutside and math.abs(lastCy - cy0) < 14) or ccP < 0.6 then
			ccTarget = 0
		else
			ccTarget = 1
		end
	elseif m == "appclose" then
		local dy = cy0 - lastCy
		local dt = math.max(os.clock() - startT, 0.05)
		if dy > 150 or (dy > 40 and dy / dt > 900) then
			closeApp(false)
		else
			TweenService:Create(
				appLayer,
				TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Position = UDim2.fromOffset(0, 0) }
			):Play()
		end
	elseif m == "cctap" then
		local t = curTarget
		curTarget = nil
		if t then
			if t.press then t.press(false) end
			if t.fn and inside(t.obj, lastCx, lastCy) then
				t.fn()
			end
		end
	elseif m == "slider" then
		curTarget = nil
	elseif m == "tilt" then
		if tiltMoved < 12 then
			local now = os.clock()
			if now - lastTiltTap < 0.4 then
				tgtTilt = 0 -- double-tap the frame to straighten
			end
			lastTiltTap = now
		end
	end
end)

-- ===== THE IPAD ITEM (inventory / hotbar) =====
local function onToolParent()
	if not alive or not tool then return end
	local char = player.Character
	if char and tool.Parent == char then
		showIPad()
	else
		hideIPad()
	end
end

local function makeTool()
	if tool then
		local oldTool = tool
		tool = nil
		pcall(function()
			oldTool:Destroy()
		end)
	end
	local t = Instance.new("Tool")
	t.Name = "iPad"
	t.ToolTip = "iPad"
	t.RequiresHandle = false
	t.CanBeDropped = false
	t:SetAttribute("IPad3D_Tool", true)
	tool = t
	t:GetPropertyChangedSignal("Parent"):Connect(onToolParent)
	t.Parent = player:WaitForChild("Backpack")
end

-- after respawn the backpack is reset, so give the item again
conns[#conns + 1] = player.CharacterAdded:Connect(function()
	hideIPad()
	task.wait(1)
	if alive then
		makeTool()
	end
end)

task.spawn(makeTool)

-- cleanup if the model is destroyed (re-execute)
model.Destroying:Connect(function()
	alive = false
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	if mode then
		restoreCamera()
	end
	if tool then
		pcall(function()
			tool:Destroy()
		end)
	end
end)
