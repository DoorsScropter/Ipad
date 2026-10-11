-- 3D iPad v3 | Delta compatible (client-side LocalScript)
-- Everything is a real Part in Workspace. The screen is a Part with a SurfaceGui,
-- so when the iPad tilts, the screen tilts with it.
--
-- Controls:
--   * Swipe up on the screen to unlock
--   * Swipe DOWN starting on the battery / wifi icons (top right) = Control Center
--   * Control Center: Wi-Fi, Bluetooth, Do Not Disturb, Eye Protection, Brightness, Volume
--   * Wi-Fi is OFF by default: open Control Center > tap Wi-Fi > turn it on > tap baseplate_5G
--   * Drag left/right on the silver frame (or just outside it) to tilt the iPad sideways
--   * Double-tap the frame to straighten it
--   * Tap the screen: the iPad gets pushed back a tiny bit and springs forward again
--   * Battery drains from 100% to 0%, at 0% the iPad turns off and can't be used

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- remove old copy if re-executed
local old = Workspace:FindFirstChild("IPad3D_Swipe")
if old then old:Destroy() end

-- ===== SETTINGS =====
local K = 0.75                 -- overall size (smaller so it covers less of the screen)
local DIST = 2.15               -- distance from camera
local PUSH = 0.08              -- tap push-back force (studs), lower = softer
local MAX_TILT = math.rad(35)  -- max sideways tilt
local TILT_SPEED = 0.3         -- degrees of tilt per pixel dragged
local TILT_MODE = "side"       -- "side" = turns left/right, "roll" = leans like a tilted picture
local DRAIN_MINUTES = 15       -- minutes from 100% to 0%
local WIFI_NAME = "baseplate_5G"

local BW, BH, BT, R = 2.5 * K, 3.3 * K, 0.14 * K, 0.2 * K
local SW, SH = 2.1 * K, 2.9 * K
local E = 0.02 * K
local CW, CH = 630, 870        -- screen canvas pixels
local TILT_MARGIN = 0.5 * K    -- extra grab area around the frame for tilting

local WHITE = Color3.new(1, 1, 1)
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

-- ===== SIDE BUTTONS =====
part("PowerButton", Vector3.new(0.4 * K, 0.04 * K, 0.06 * K), CFrame.new(BW / 2 - 0.6 * K, BH / 2 + 0.02 * K, 0), silver, metal)
part("VolUp", Vector3.new(0.04 * K, 0.3 * K, 0.06 * K), CFrame.new(BW / 2 + 0.02 * K, BH / 2 - 0.8 * K, 0), silver, metal)
part("VolDown", Vector3.new(0.04 * K, 0.3 * K, 0.06 * K), CFrame.new(BW / 2 + 0.02 * K, BH / 2 - 1.2 * K, 0), silver, metal)

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

-- shapes used to draw icons
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

-- ===== HOME SCREEN (revealed after unlock) =====
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

-- ===== APP STORE ICON =====
local APP = { x = 70, y = 110, s = 110 }

local icon = ui("Frame", {
	Name = "AppStoreIcon",
	Size = UDim2.fromOffset(APP.s, APP.s),
	Position = UDim2.fromOffset(APP.x, APP.y),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 3,
}, homeContent)
corner(icon, UDim.new(0, 26))
ui("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(80, 215, 255), Color3.fromRGB(10, 95, 250)),
	Rotation = 90,
}, icon)
ui("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.75 }, icon)
local iconScale = ui("UIScale", { Scale = 1 }, icon)

bar(icon, 11, 66, APP.s / 2 - 14, 52, 22, 4)
bar(icon, 11, 66, APP.s / 2 + 14, 52, -22, 4)
bar(icon, 40, 9, APP.s / 2, 64, 0, 4)

local spark = ui("Frame", {
	Size = UDim2.fromOffset(8, 8),
	Position = UDim2.fromOffset(78, 18),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
	ZIndex = 4,
}, icon)
corner(spark, UDim.new(1, 0))

local iconDim = ui("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 6,
}, icon)
corner(iconDim, UDim.new(0, 26))

local iconText = label(homeContent, "App Store", APP.x - 15, APP.y + APP.s + 8, APP.s + 30, 24, 20, WHITE, Enum.Font.GothamMedium, nil, 3)
iconText.TextStrokeTransparency = 0.85

-- invisible hit area for the icon (not scaled, not faded)
local iconHit = ui("Frame", {
	Size = UDim2.fromOffset(APP.s + 20, APP.s + 50),
	Position = UDim2.fromOffset(APP.x - 10, APP.y - 10),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 2,
}, home)


-- ===== APP STORE + TOP EXIT CONTROL =====
-- All apps below are simulated inside this virtual tablet. A LocalScript cannot
-- install native apps on the device or grant server-side Roblox inventory items.
local storeRoot = ui("Frame", {
	Name = "AppStoreWindow",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(245, 246, 250),
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 40,
}, sg)

local storeTop = ui("Frame", {
	Size = UDim2.new(1, 0, 0, 90),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BorderSizePixel = 0,
	ZIndex = 41,
}, storeRoot)
label(storeTop, "App Store", 24, 18, 300, 52, 34, Color3.fromRGB(25, 25, 30), Enum.Font.GothamBold, Enum.TextXAlignment.Left, 42)
local storeClose = ui("TextButton", {
	Size = UDim2.fromOffset(54, 54),
	Position = UDim2.new(1, -70, 0, 16),
	BackgroundColor3 = Color3.fromRGB(242, 243, 247),
	BorderSizePixel = 0,
	Text = "Done",
	TextSize = 18,
	TextColor3 = Color3.fromRGB(0, 122, 255),
	Font = Enum.Font.GothamMedium,
	AutoButtonColor = false,
	ZIndex = 43,
}, storeTop)
corner(storeClose, UDim.new(1, 0))

local storeSearch = ui("TextBox", {
	Name = "StoreSearch",
	Size = UDim2.new(1, -48, 0, 42),
	Position = UDim2.fromOffset(24, 96),
	BackgroundColor3 = Color3.fromRGB(230, 232, 238),
	BorderSizePixel = 0,
	PlaceholderText = "Search",
	PlaceholderColor3 = Color3.fromRGB(115, 118, 130),
	Text = "",
	TextColor3 = Color3.fromRGB(30, 30, 35),
	TextSize = 18,
	Font = Enum.Font.Gotham,
	ClearTextOnFocus = false,
	ZIndex = 43,
}, storeRoot)
corner(storeSearch, UDim.new(0, 13))
local storeHint = label(storeRoot, "Connect to Wi-Fi to download apps.", 24, 142, CW - 48, 30, 15, Color3.fromRGB(90, 92, 105), Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 42)
local installedLabel = label(storeRoot, "Installed: none", 24, CH - 56, CW - 48, 30, 17, Color3.fromRGB(80, 82, 95), Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 42)

local installedApps = {}
local appButtons = {}
local function makeStoreApp(name, description, y, iconText, color)
	local card = ui("Frame", {
		Size = UDim2.new(1, -40, 0, 142),
		Position = UDim2.fromOffset(20, y),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		ZIndex = 41,
	}, storeRoot)
	corner(card, UDim.new(0, 22))
	local appIcon = ui("Frame", {
		Size = UDim2.fromOffset(86, 86),
		Position = UDim2.fromOffset(18, 26),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 42,
	}, card)
	corner(appIcon, UDim.new(0, 20))
	label(appIcon, iconText, 0, 0, 86, 86, 28, WHITE, Enum.Font.GothamBold, nil, 43)
	label(card, name, 122, 20, 240, 34, 22, Color3.fromRGB(25, 25, 30), Enum.Font.GothamBold, Enum.TextXAlignment.Left, 43)
	label(card, description, 122, 55, 245, 48, 15, Color3.fromRGB(90, 92, 105), Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 43)
	local action = ui("TextButton", {
		Size = UDim2.fromOffset(112, 42),
		Position = UDim2.new(1, -130, 0.5, -21),
		BackgroundColor3 = BLUE,
		BorderSizePixel = 0,
		Text = "GET",
		TextColor3 = WHITE,
		TextSize = 17,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = false,
		ZIndex = 43,
	}, card)
	corner(action, UDim.new(1, 0))
	appButtons[name] = {button = action, card = card}
	return action
end

local robloxButton = makeStoreApp("Roblox", "Explore experiences (simulated app)", 184, "R", Color3.fromRGB(25, 25, 30))
local flappyButton = makeStoreApp("Flappy Bird", "A tiny arcade game (simulated app)", 342, "FB", Color3.fromRGB(65, 190, 95))

local appScreen = ui("Frame", {
	Name = "SimulatedAppScreen",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(20, 24, 35),
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 60,
}, sg)
local appScreenTitle = label(appScreen, "", 20, 90, CW - 40, 64, 34, WHITE, Enum.Font.GothamBold, nil, 61)
local appScreenMessage = label(appScreen, "", 36, 190, CW - 72, 300, 24, WHITE, Enum.Font.GothamMedium, nil, 61)
local appScreenBack = ui("TextButton", {
	Size = UDim2.fromOffset(130, 52),
	Position = UDim2.fromOffset(20, 20),
	BackgroundColor3 = Color3.fromRGB(60, 65, 80),
	BorderSizePixel = 0,
	Text = "‹ Store",
	TextColor3 = WHITE,
	TextSize = 20,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
	ZIndex = 62,
}, appScreen)
corner(appScreenBack, UDim.new(0, 18))

-- iPad-style home indicator. When an app is open, tapping this bottom area
-- exits the app to the home screen. The hit target is intentionally larger
-- than the visible white bar for easier mobile tapping.
local homeIndicator = ui("Frame", {
	Name = "AppHomeIndicator",
	Size = UDim2.fromOffset(176, 7),
	Position = UDim2.fromOffset(CW / 2 - 88, CH - 30),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 120,
}, sg)
corner(homeIndicator, UDim.new(1, 0))

local homeIndicatorHit = ui("Frame", {
	Name = "AppHomeIndicatorHit",
	Size = UDim2.fromOffset(300, 84),
	Position = UDim2.fromOffset(CW / 2 - 150, CH - 82),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 121,
}, sg)

local function pressIcon(on)
	TweenService:Create(
		iconScale,
		TweenInfo.new(on and 0.08 or 0.25, on and Enum.EasingStyle.Quad or Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = on and 0.88 or 1 }
	):Play()
	TweenService:Create(iconDim, TweenInfo.new(0.1), { BackgroundTransparency = on and 0.75 or 1 }):Play()
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
	while model.Parent do
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

local statusWifi = drawWifi(status, CW - 174, 37, 0.48, WHITE, 21)
for _, p in ipairs(statusWifi) do
	p.BackgroundTransparency = 0.7 -- dim until connected
end

local pctLabel = label(status, "100%", CW - 145, 14, 58, 28, 22, WHITE, Enum.Font.GothamMedium, Enum.TextXAlignment.Right, 21)

local battOutline = ui("Frame", {
	Size = UDim2.fromOffset(52, 26),
	Position = UDim2.fromOffset(CW - 76, 15),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 21,
}, status)
corner(battOutline, UDim.new(0, 8))
ui("UIStroke", { Color = WHITE, Thickness = 2.5, Transparency = 0.2 }, battOutline)

local battFill = ui("Frame", {
	Size = UDim2.fromOffset(44, 18),
	Position = UDim2.fromOffset(CW - 76 + 4, 15 + 4),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 22,
}, status)
corner(battFill, UDim.new(0, 5))

local battNub = ui("Frame", {
	Size = UDim2.fromOffset(4, 11),
	Position = UDim2.fromOffset(CW - 23, 22),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	ZIndex = 21,
}, status)
corner(battNub, UDim.new(0, 2))

-- ===== OVERLAYS: brightness, eye protection, dead screen =====
local dim = ui("Frame", {
	Name = "BrightnessDim",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
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
	BackgroundColor3 = Color3.new(0, 0, 0),
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

-- frosted layer = the "blur" behind the menu
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
	BackgroundTransparency = 0.15,
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

-- targets = things that react to touches
local targets = {}
local function addTarget(obj, kind, active, fn, press, set)
	table.insert(targets, { obj = obj, kind = kind, active = active, fn = fn, press = press, set = set })
end

-- state shared by the logic below
local wifiOn, wifiState, wifiView = false, "off", false
local btOn, dndOn, eyeOn = false, false, false
local locked = true
local dead = false
local ccP, ccTarget, ccDragging = 0, 0, false
local mode, dragType, curTarget = nil, nil, nil
local savedCamType = nil

local function ccReady()
	return ccTarget == 1 and ccP > 0.85
end

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

-- tile 1: Wi-Fi
local wifiTile, wifiSc, wifiLab = makeTile(1, "Wi-Fi")
drawWifi(wifiTile, TILE / 2, 70, 1, WHITE, 5)

-- tile 2: Bluetooth
local btTile, btSc = makeTile(2, "Bluetooth")
drawBluetooth(btTile, TILE / 2, TILE / 2, 1, WHITE, 5)

-- tile 3: Do Not Disturb (moon)
local dndTile, dndSc = makeTile(3, "Do Not Disturb")
dot(dndTile, TILE / 2, TILE / 2, 44, WHITE, 5)
local dndCarve = dot(dndTile, TILE / 2 + 12, TILE / 2 - 8, 38, TILE_OFF, 6)

-- tile 4: Eye Protection
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

-- sliders
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

local brightV, volV = 0.85, 0.5
local brightTrack, brightFill = makeSlider(215, "Brightness", drawSun, brightV)
local volTrack, volFill = makeSlider(325, "Volume", drawSpeaker, volV)

local function setBrightness(v)
	brightV = math.clamp(v, 0, 1)
	brightFill.Size = UDim2.new(brightV, 0, 1, 0)
	dim.BackgroundTransparency = 1 - (1 - brightV) * 0.85
end
local function setVolume(v)
	volV = math.clamp(v, 0, 1) -- stored here, nothing plays audio yet
	volFill.Size = UDim2.new(volV, 0, 1, 0)
end
setBrightness(brightV)

-- ===== WI-FI VIEW (inside the control center) =====
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

-- ===== BATTERY =====
local batt = 100
local DRAIN_SECONDS = DRAIN_MINUTES * 60

local function updateBattery()
	pctLabel.Text = math.ceil(batt) .. "%"
	battFill.Size = UDim2.fromOffset(math.floor(44 * batt / 100), 18)
	battFill.BackgroundColor3 = batt <= 20 and RED or WHITE
end

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
	while model.Parent and not dead do
		task.wait(1)
		batt = math.max(0, batt - 100 / DRAIN_SECONDS)
		updateBattery()
		if batt <= 0 then
			powerOff()
		end
	end
end)

-- ===== WI-FI LOGIC =====
local function refreshWifi()
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
	if storeRoot then
		storeHint.Text = wifiState == "connected" and ("Connected to " .. WIFI_NAME .. " — downloads available.") or "Connect to Wi-Fi to download apps."
	end
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

local function showWifiView(v)
	wifiView = v
	ccMain.Visible = not v
	ccWifi.Visible = v
end
refreshWifi()

-- ===== CONTROL CENTER LOGIC =====
local function setCC(p)
	ccRoot.Visible = p > 0.002
	frost.BackgroundTransparency = 1 - 0.5 * p
	local closedY = -PANEL_H - 30
	panel.Position = UDim2.fromOffset(30, closedY + (PANEL_Y - closedY) * p)
	homeContent.GroupTransparency = 0.85 * p
	lockContent.GroupTransparency = 0.85 * p
	for _, sc in ipairs(blobScales) do
		sc.Scale = 1 + 0.4 * p -- blobs swell and soften = blur
	end
end

local ccActiveMain = function()
	return ccReady() and not wifiView and not dead
end
local ccActiveWifi = function()
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

local function updateHomeIndicator()
	local appOpen = storeRoot.Visible or appScreen.Visible
	homeIndicator.Visible = appOpen
	homeIndicatorHit.Visible = appOpen
end

local function returnToHome()
	storeRoot.Visible = false
	appScreen.Visible = false
	ccTarget, ccP, ccDragging = 0, 0, false
	updateHomeIndicator()
end

addTarget(iconHit, "tap", function()
	return not locked and ccTarget == 0 and ccP < 0.05 and not dead and not storeRoot.Visible and not appScreen.Visible
end, function()
	storeRoot.Visible = true
	appScreen.Visible = false
	storeHint.Text = wifiState == "connected" and "Connected to " .. WIFI_NAME or "Connect to Wi-Fi to download apps."
	updateHomeIndicator()
end, pressIcon)

local function refreshStore()
	installedLabel.Text = "Installed: " .. (#(function()
		local names = {}
		for name in pairs(installedApps) do table.insert(names, name) end
		table.sort(names)
		return names
	end)() > 0 and table.concat((function()
		local names = {}
		for name in pairs(installedApps) do table.insert(names, name) end
		table.sort(names)
		return names
	end)(), ", ") or "none")
	storeHint.Text = wifiState == "connected" and ("Connected to " .. WIFI_NAME .. " — downloads available.") or "Connect to Wi-Fi to download apps."
	for name, item in pairs(appButtons) do
		item.button.Text = installedApps[name] and "OPEN" or "GET"
		item.button.BackgroundColor3 = installedApps[name] and GREEN or BLUE
	end
end

local function downloadApp(name)
	if installedApps[name] then
		storeRoot.Visible = false
		appScreen.Visible = true
		updateHomeIndicator()
		appScreenTitle.Text = name
		appScreenMessage.Text = name == "Flappy Bird"
			and "Flappy Bird demo\\n\\nTap the screen to flap. This is a local UI demo, not the original game."
			or "Roblox demo\\n\\nThis simulated app cannot sign in, join experiences, or install the real Roblox app."
		return
	end
	if wifiState ~= "connected" then
		storeHint.Text = "Download blocked — turn Wi-Fi on and connect to " .. WIFI_NAME .. "."
		return
	end
	local item = appButtons[name]
	if not item then return end
	item.button.Text = "..."
	item.button.Active = false
	task.delay(1.5, function()
		if not model.Parent then return end
		installedApps[name] = true
		item.button.Active = true
		refreshStore()
	end)
end

robloxButton.Activated:Connect(function() downloadApp("Roblox") end)
flappyButton.Activated:Connect(function() downloadApp("Flappy Bird") end)

-- Explicit ray-hit targets for controls inside the 3D SurfaceGui.
-- SurfaceGui TextButton.Activated alone can be unreliable for some mobile executor setups.
addTarget(storeClose, "tap", function()
	return storeRoot.Visible and not appScreen.Visible and not dead
end, function()
	returnToHome()
end)

addTarget(homeIndicatorHit, "tap", function()
	return (storeRoot.Visible or appScreen.Visible) and not dead
end, function()
	returnToHome()
end)

addTarget(appScreenBack, "tap", function()
	return appScreen.Visible and not dead
end, function()
	appScreen.Visible = false
	storeRoot.Visible = true
	refreshStore()
	updateHomeIndicator()
end)

addTarget(robloxButton, "tap", function()
	return storeRoot.Visible and not appScreen.Visible and not dead
end, function()
	downloadApp("Roblox")
end)

addTarget(flappyButton, "tap", function()
	return storeRoot.Visible and not appScreen.Visible and not dead
end, function()
	downloadApp("Flappy Bird")
end)

storeClose.Activated:Connect(function() returnToHome() end)
appScreenBack.Activated:Connect(function()
	appScreen.Visible = false
	storeRoot.Visible = true
	refreshStore()
	updateHomeIndicator()
end)

-- ===== SPRING (tap push-back) =====
local sPush = { p = 0, v = 0, t = 0 }
local function stepSpring(s, dt)
	local a = (s.t - s.p) * 260 - s.v * 16
	s.v = s.v + a * dt
	s.p = s.p + s.v * dt
end

local function pulse()
	sPush.t = PUSH
	task.delay(0.09, function()
		sPush.t = 0
	end)
end

-- ===== PLACE IN FRONT OF CAMERA (with sideways tilt) =====
model.PrimaryPart = body
model.Parent = Workspace

local reopenGui = Instance.new("ScreenGui")
reopenGui.Name = "VirtualIPadReopen"
reopenGui.ResetOnSpawn = false
reopenGui.IgnoreGuiInset = true
local reopenButton = Instance.new("TextButton")
reopenButton.Name = "OpenIPad"
reopenButton.Size = UDim2.fromOffset(132, 48)
reopenButton.Position = UDim2.new(1, -146, 1, -68)
reopenButton.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
reopenButton.TextColor3 = WHITE
reopenButton.Text = "Open iPad"
reopenButton.TextSize = 17
reopenButton.Font = Enum.Font.GothamBold
reopenButton.Visible = false
reopenButton.Parent = reopenGui
local reopenCorner = Instance.new("UICorner")
reopenCorner.CornerRadius = UDim.new(0, 14)
reopenCorner.Parent = reopenButton
reopenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
reopenButton.Activated:Connect(function()
	model.Parent = Workspace
	reopenButton.Visible = false
end)
-- Update visibility without another perpetual loop.

local conns = {}
local tgtTilt, curTilt = 0, 0
local ccDrawn = -1

conns[#conns + 1] = RunService.RenderStepped:Connect(function(dt)
	local cam = Workspace.CurrentCamera
	if not cam or not model.Parent then return end
	dt = math.min(dt, 1 / 30)

	curTilt = curTilt + (tgtTilt - curTilt) * math.min(1, dt * 12)
	stepSpring(sPush, dt)

	local tiltCF
	if TILT_MODE == "roll" then
		tiltCF = CFrame.Angles(0, 0, -curTilt)
	else
		tiltCF = CFrame.Angles(0, curTilt, 0)
	end

	-- the whole model (frame + screen) moves/tilts together
	model:PivotTo(cam.CFrame * CFrame.new(0, 0, -DIST) * tiltCF * CFrame.new(0, 0, -sPush.p))

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
end)

-- ===== INPUT (finger ray -> screen plane, works while tilted) =====
local startY, startT, lastDy = 0, 0, 0
local cy0, lastCx, lastCy = 0, 0, 0
local startedOutside = false
local tiltStartX, tiltStart0, tiltMoved = 0, 0, 0
local lastTiltTap = 0
local slideTween = nil

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

local function unlock()
	locked = false
	if slideTween then slideTween:Cancel() end
	slideTween = TweenService:Create(
		lock,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(0, -CH - 20) }
	)
	slideTween.Completed:Connect(function()
		lock.Visible = false
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

local function handleInputBegan(input)
	if mode then return end
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
		-- Physical top/power button: hide the whole iPad, then use Open iPad to restore it.
		local nearTopPowerButton =
			lp.Y > SH / 2 and lp.Y < BH / 2 + TILT_MARGIN
			and lp.X > (BW / 2 - 1.0 * K) and lp.X < (BW / 2 - 0.2 * K)
		if nearTopPowerButton then
			model.Parent = nil
			reopenButton.Visible = true
			returnToHome()
			mode = nil
			restoreCamera()
			return
		end

		-- Touching the right edge near the physical volume buttons changes volume.
		local nearRightEdge = lp.X > SW / 2 and lp.X < BW / 2 + TILT_MARGIN
		if nearRightEdge and math.abs(lp.Y) < BH / 2 then
			local yFromTop = BH / 2 - lp.Y
			if yFromTop > 0.55 * K and yFromTop < 1.05 * K then
				setVolume(volV + 0.1)
				return
			elseif yFromTop >= 1.05 * K and yFromTop < 1.55 * K then
				setVolume(volV - 0.1)
				return
			end
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
	elseif locked then
		mode = "swipe"
		startY = lp.Y
		startT = os.clock()
		lastDy = 0
		if slideTween then slideTween:Cancel() end
	else
		-- A broad bottom swipe/tap region acts like the iPad home indicator while
		-- the App Store or a simulated app is open.
		if (storeRoot.Visible or appScreen.Visible) and cy >= CH - 82 and math.abs(cx - CW / 2) <= 150 then
			curTarget = nil
			mode = "cctap"
			curTarget = {
				obj = homeIndicatorHit,
				kind = "tap",
				fn = returnToHome,
				active = function() return (storeRoot.Visible or appScreen.Visible) and not dead end,
			}
			return
		end

		local tgt = findTarget(cx, cy)
		if tgt then
			curTarget = tgt
			mode = "cctap"
			if tgt.press then tgt.press(true) end
		else
			mode = "tap"
		end
	end
end
conns[#conns + 1] = UIS.TouchStarted:Connect(function(input)
	handleInputBegan(input)
end)
conns[#conns + 1] = UIS.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		handleInputBegan(input)
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
	elseif mode == "slider" and curTarget then
		curTarget.set(sliderValue(curTarget, cx))
	end
end)

local function handleInputEnded(input)
	if not mode then return end
	if input.UserInputType ~= dragType then return end

	local m = mode
	mode = nil
	restoreCamera()

	if m == "swipe" then
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
end
conns[#conns + 1] = UIS.TouchEnded:Connect(function(input)
	handleInputEnded(input)
end)
conns[#conns + 1] = UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		handleInputEnded(input)
	end
end)

-- cleanup if the model is destroyed (re-execute)
model.Destroying:Connect(function()
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	if mode then
		restoreCamera()
	end
end)
