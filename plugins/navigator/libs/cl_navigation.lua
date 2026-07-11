-- swrp/plugins/navigator/libs/cl_navigation.lua
-- Clientside route state and HUD guidance.
--
-- Version 0.1 provides direct destination guidance. Proper corridor-by-corridor
-- instructions will be layered on later using route nodes.

SWRP = SWRP or {}
SWRP.Navigator = SWRP.Navigator or {}

local nextArrivalCheck = 0

local function notify(message)
	if (ix and ix.util and ix.util.Notify) then
		ix.util.Notify(message)
	else
		notification.AddLegacy(message, NOTIFY_GENERIC, 4)
	end
end

local function formatDistance(units)
	-- Source units are approximately inches. Keep this intentionally approximate.
	return math.max(0, math.Round((tonumber(units) or 0) / 39.37))
end

local function rotatePoint(x, y, radians)
	local cosine = math.cos(radians)
	local sine = math.sin(radians)

	return x * cosine - y * sine, x * sine + y * cosine
end

--- Returns the currently active navigation route, if any.
-- @realm client
function SWRP.Navigator.GetActiveRoute()
	return SWRP.Navigator.activeRoute
end

--- Begins navigating to a configured destination on the current map.
-- @realm client
-- @string locationID
-- @treturn bool
function SWRP.Navigator.StartNavigation(locationID)
	local location = SWRP.Navigator.GetLocation(locationID)

	if (not location or not isvector(location.position)) then
		notify("That navigator destination is unavailable on this map.")
		return false
	end

	SWRP.Navigator.activeRoute = {
		locationID = locationID,
		map = game.GetMap(),
		startedAt = CurTime()
	}

	notify("Navigation started: " .. tostring(location.name or locationID))

	return true
end

--- Cancels the active route.
-- @realm client
-- @bool[opt] silent Suppress the notification.
function SWRP.Navigator.StopNavigation(silent)
	local route = SWRP.Navigator.activeRoute

	if (not route) then
		return
	end

	local location = SWRP.Navigator.GetLocation(route.locationID, route.map)
	SWRP.Navigator.activeRoute = nil

	if (not silent) then
		notify("Navigation cancelled" .. (location and (": " .. location.name) or "") .. ".")
	end
end

--- Returns the active destination table, or nil if the route is no longer valid.
-- @realm client
function SWRP.Navigator.GetActiveLocation()
	local route = SWRP.Navigator.GetActiveRoute()

	if (not route or route.map ~= game.GetMap()) then
		return nil
	end

	return SWRP.Navigator.GetLocation(route.locationID, route.map)
end

hook.Add("Think", "SWRP.NavigatorArrivalCheck", function()
	if (CurTime() < nextArrivalCheck) then
		return
	end

	nextArrivalCheck = CurTime() + 0.2

	local route = SWRP.Navigator.GetActiveRoute()
	if (not route) then
		return
	end

	if (route.map ~= game.GetMap()) then
		SWRP.Navigator.StopNavigation(true)
		return
	end

	local location = SWRP.Navigator.GetActiveLocation()
	local client = LocalPlayer()

	if (not location or not IsValid(client)) then
		SWRP.Navigator.StopNavigation(true)
		return
	end

	if (client:GetPos():DistToSqr(location.position) <= (SWRP.Navigator.arrivalDistance ^ 2)) then
		local name = location.name or "destination"
		SWRP.Navigator.activeRoute = nil
		notify("Destination reached: " .. name .. ".")
		surface.PlaySound("buttons/button15.wav")
	end
end)

hook.Add("HUDPaint", "SWRP.NavigatorHUD", function()
	local route = SWRP.Navigator.GetActiveRoute()
	local location = SWRP.Navigator.GetActiveLocation()
	local client = LocalPlayer()

	if (not route or not location or not IsValid(client)) then
		return
	end

	local screenWidth = ScrW()
	local panelWidth = math.Clamp(screenWidth * 0.30, 340, 520)
	local panelHeight = 102
	local panelX = (screenWidth - panelWidth) * 0.5
	local panelY = 26
	local accent = (ix and ix.config and ix.config.Get("color")) or Color(75, 119, 190)
	local distanceUnits = client:GetPos():Distance(location.position)
	local distanceMetres = formatDistance(distanceUnits)

	draw.RoundedBox(8, panelX, panelY, panelWidth, panelHeight, Color(12, 16, 24, 225))
	draw.RoundedBox(8, panelX, panelY, 5, panelHeight, accent)

	draw.SimpleText(
		string.upper(location.name or route.locationID),
		"DermaDefaultBold",
		panelX + 20,
		panelY + 17,
		color_white,
		TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP
	)

	draw.SimpleText(
		location.instruction or "Proceed toward the selected destination.",
		"DermaDefault",
		panelX + 20,
		panelY + 43,
		Color(210, 218, 230),
		TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP
	)

	draw.SimpleText(
		string.format("%dm away", distanceMetres),
		"DermaDefaultBold",
		panelX + 20,
		panelY + 69,
		accent,
		TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP
	)

	draw.SimpleText(
		"TAB > Navigator to cancel",
		"DermaDefault",
		panelX + panelWidth - 18,
		panelY + 71,
		Color(160, 168, 180),
		TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_TOP
	)

	-- Directional arrow. Up means straight ahead; it rotates left/right toward the
	-- destination using the player's current view yaw.
	local targetYaw = (location.position - EyePos()):Angle().y
	local yawDifference = math.AngleDifference(targetYaw, EyeAngles().y)
	local radians = math.rad(yawDifference)
	local centreX = panelX + panelWidth - 50
	local centreY = panelY + 35
	local arrowTemplate = {
		{x = 0, y = -12},
		{x = 9, y = 10},
		{x = 0, y = 6},
		{x = -9, y = 10}
	}
	local arrow = {}

	for index, point in ipairs(arrowTemplate) do
		local rotatedX, rotatedY = rotatePoint(point.x, point.y, radians)
		arrow[index] = {
			x = centreX + rotatedX,
			y = centreY + rotatedY
		}
	end

	surface.SetDrawColor(accent)
	draw.NoTexture()
	surface.DrawPoly(arrow)

	-- A small world marker appears when the target coordinate is actually visible.
	local projected = location.position:ToScreen()

	if (projected.visible) then
		draw.RoundedBox(4, projected.x - 5, projected.y - 5, 10, 10, accent)
		draw.SimpleText(
			location.name or route.locationID,
			"DermaDefaultBold",
			projected.x,
			projected.y - 12,
			color_white,
			TEXT_ALIGN_CENTER,
			TEXT_ALIGN_BOTTOM
		)
	end
end)
