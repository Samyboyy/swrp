-- swrp/plugins/navigator/derma/cl_navigator.lua
-- Republic NAVCOM-styled Navigator TAB page with rotating Venator hologram.

SWRP = SWRP or {}
SWRP.Navigator = SWRP.Navigator or {}

local MODEL_PATH = "models/swrp/venator_hologram.mdl"

local hologramMaterial = CreateMaterial("swrp_navigator_hologram_v2", "VertexLitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
	["$translucent"] = "1",
	["$additive"] = "1",
	["$nocull"] = "1",
	["$selfillum"] = "1",
	["$vertexcolor"] = "1",
	["$vertexalpha"] = "1"
})

local markerGlowMaterial = Material("sprites/light_glow02_add")

local function playDatapadSound(kind)
    if SWRP and SWRP.Datapad and isfunction(SWRP.Datapad.PlaySound) then
        SWRP.Datapad.PlaySound(kind)
    end
end

local function getAccent()
	return (ix and ix.config and ix.config.Get("color")) or Color(65, 155, 225)
end

local function formatDistanceTo(location)
	if (not location or not isvector(location.position) or not IsValid(LocalPlayer())) then
		return "UNKNOWN"
	end

	local units = LocalPlayer():GetPos():Distance(location.position)
	return string.format("%dm", math.max(0, math.Round(units / 39.37)))
end

-- DModelPanel renders its model in a separate 3D context, so its model does not
-- automatically inherit the alpha fade used by Helix's TAB menu. Walk up the parent
-- chain (and explicitly include ix.gui.menu) to obtain the active menu fade.
local function getInheritedMenuAlpha(panel)
	local alpha = 255
	local current = panel
	local safety = 0

	while (IsValid(current) and safety < 32) do
		alpha = math.min(alpha, current:GetAlpha() or 255)
		current = current:GetParent()
		safety = safety + 1
	end

	if (ix and ix.gui and IsValid(ix.gui.menu)) then
		alpha = math.min(alpha, ix.gui.menu:GetAlpha() or 255)
	end

	return math.Clamp(alpha / 255, 0, 1)
end


-- Projects a point from the DModelPanel's 3D camera into that panel's local 2D
-- coordinates. Vector:ToScreen() cannot be used here because the model panel renders
-- through its own camera rather than the player's world camera.
local function projectModelPoint(panel, worldPoint)
	if (
		not IsValid(panel)
		or not isvector(worldPoint)
		or not isvector(panel.swrpCameraPosition)
		or not isvector(panel.swrpCameraLookAt)
	) then
		return nil
	end

	local width, height = panel:GetSize()

	if (width <= 0 or height <= 0) then
		return nil
	end

	local cameraDirection = panel.swrpCameraLookAt - panel.swrpCameraPosition

	if (cameraDirection:LengthSqr() <= 0.0001) then
		return nil
	end

	local cameraAngle = cameraDirection:Angle()
	local relative = worldPoint - panel.swrpCameraPosition
	local depth = relative:Dot(cameraAngle:Forward())

	if (depth <= 0.01) then
		return nil
	end

	local fov = math.rad(math.Clamp(panel:GetFOV() or 36, 1, 179))
	-- cam.Start3D uses one projection and square pixels. Using independent X/Y
	-- focal lengths made the marker drift whenever the panel aspect ratio changed.
	local focalLength = (height * 0.5) / math.tan(fov * 0.5)
	local x = width * 0.5 + (relative:Dot(cameraAngle:Right()) / depth) * focalLength
	local y = height * 0.5 - (relative:Dot(cameraAngle:Up()) / depth) * focalLength

	return x, y, depth
end

local function drawCorners(x, y, width, height, colour)
	local length = 18
	surface.SetDrawColor(colour)

	surface.DrawRect(x, y, length, 2)
	surface.DrawRect(x, y, 2, length)
	surface.DrawRect(x + width - length, y, length, 2)
	surface.DrawRect(x + width - 2, y, 2, length)
	surface.DrawRect(x, y + height - 2, length, 2)
	surface.DrawRect(x, y + height - length, 2, length)
	surface.DrawRect(x + width - length, y + height - 2, length, 2)
	surface.DrawRect(x + width - 2, y + height - length, 2, length)
end

local function drawScanlines(x, y, width, height)
	surface.SetDrawColor(75, 195, 255, 12)

	for lineY = y, y + height, 5 do
		surface.DrawRect(x, lineY, width, 1)
	end

	local sweep = y + ((RealTime() * 42) % math.max(height, 1))
	surface.SetDrawColor(115, 225, 255, 25)
	surface.DrawRect(x, sweep, width, 2)
end

local PANEL = {}

function PANEL:Init()
	self.selectedLocationID = nil
	self.searchText = ""
	self.nextRefresh = 0

	self:DockPadding(22, 18, 22, 20)

	self.header = self:Add("DPanel")
	self.header:Dock(TOP)
	self.header:SetTall(68)
	self.header.Paint = function(panel, width, height)
		local accent = getAccent()
		draw.RoundedBox(4, 0, 0, width, height, Color(4, 12, 20, 238))
		drawCorners(0, 0, width, height, Color(accent.r, accent.g, accent.b, 130))
		draw.SimpleText("REPUBLIC NAVCOM", "DermaLarge", 18, 10, color_white)
		draw.SimpleText("VENATOR-CLASS INTERNAL NAVIGATION SYSTEM", "DermaDefaultBold", 20, 43, accent)
		draw.SimpleText("VESSEL LINK  •  ACTIVE", "DermaDefaultBold", width - 18, 18, Color(105, 220, 175), TEXT_ALIGN_RIGHT)
		draw.SimpleText(string.upper(game.GetMap()), "DermaDefault", width - 18, 41, Color(120, 150, 170), TEXT_ALIGN_RIGHT)
	end

	self.body = self:Add("DPanel")
	self.body:Dock(FILL)
	self.body:DockMargin(0, 12, 0, 0)
	self.body.Paint = nil

	self.left = self.body:Add("DPanel")
	self.left:Dock(LEFT)
	self.left:SetWide(330)
	self.left:DockPadding(14, 14, 14, 14)
	self.left:DockMargin(0, 0, 12, 0)
	self.left.Paint = function(panel, width, height)
		local accent = getAccent()
		draw.RoundedBox(4, 0, 0, width, height, Color(5, 13, 22, 232))
		drawCorners(0, 0, width, height, Color(accent.r, accent.g, accent.b, 70))
	end

	self.searchLabel = self.left:Add("DLabel")
	self.searchLabel:Dock(TOP)
	self.searchLabel:SetTall(22)
	self.searchLabel:SetFont("DermaDefaultBold")
	self.searchLabel:SetText("DESTINATION SEARCH")
	self.searchLabel:SetTextColor(getAccent())

	self.search = self.left:Add("DTextEntry")
	self.search:Dock(TOP)
	self.search:SetTall(38)
	self.search:DockMargin(0, 2, 0, 12)
	self.search:SetPlaceholderText("Search ship locations...")
	self.search.OnValueChange = function(_, value)
		self.searchText = string.lower(string.Trim(value or ""))
		self:RebuildLocations()
	end

	self.activeStatus = self.left:Add("DPanel")
	self.activeStatus:Dock(BOTTOM)
	self.activeStatus:SetTall(58)
	self.activeStatus:DockMargin(0, 10, 0, 0)
	self.activeStatus.Paint = function(panel, width, height)
		local route = SWRP.Navigator.GetActiveRoute()
		local location = SWRP.Navigator.GetActiveLocation()
		local accent = getAccent()
		draw.RoundedBox(4, 0, 0, width, height, Color(10, 22, 34, 245))

		if (route and location) then
			draw.RoundedBox(4, 0, 0, 3, height, accent)
			draw.SimpleText("ACTIVE ROUTE", "DermaDefaultBold", 13, 9, accent)
			draw.SimpleText(location.name .. "  •  " .. formatDistanceTo(location), "DermaDefault", 13, 32, color_white)
		else
			draw.SimpleText("NO ACTIVE ROUTE", "DermaDefaultBold", 13, 11, Color(115, 145, 165))
			draw.SimpleText("Select a destination", "DermaDefault", 13, 33, Color(150, 165, 178))
		end
	end

	self.locationList = self.left:Add("DScrollPanel")
	self.locationList:Dock(FILL)

	self.right = self.body:Add("DPanel")
	self.right:Dock(FILL)
	self.right:DockPadding(14, 14, 14, 14)
	self.right.Paint = function(panel, width, height)
		local accent = getAccent()
		draw.RoundedBox(4, 0, 0, width, height, Color(3, 10, 18, 238))
		drawCorners(0, 0, width, height, Color(accent.r, accent.g, accent.b, 80))
	end

	self.details = self.right:Add("DPanel")
	self.details:Dock(BOTTOM)
	self.details:SetTall(156)
	self.details:DockPadding(16, 14, 16, 12)
	self.details.Paint = function(panel, width, height)
		local location = self:GetSelectedLocation()
		local accent = getAccent()
		draw.RoundedBox(3, 0, 0, width, height, Color(7, 17, 28, 248))

		if (not location) then
			draw.SimpleText("SELECT A DESTINATION", "DermaLarge", 16, 18, color_white)
			draw.SimpleText("Choose a location from the NAVCOM directory.", "DermaDefault", 16, 58, Color(150, 170, 185))
			return
		end

		draw.SimpleText(string.upper(location.name or self.selectedLocationID), "DermaLarge", 16, 13, color_white)
		draw.SimpleText(string.upper(location.deck or location.category or "SHIP LOCATION"), "DermaDefaultBold", 16, 51, accent)
		draw.SimpleText("DISTANCE", "DermaDefaultBold", width - 160, 18, Color(125, 155, 175))
		draw.SimpleText(formatDistanceTo(location), "DermaLarge", width - 160, 39, color_white)
		draw.DrawText(location.description or "", "DermaDefault", 16, 78, Color(185, 204, 216), TEXT_ALIGN_LEFT)
	end

	self.startButton = self.details:Add("DButton")
	self.startButton:Dock(BOTTOM)
	self.startButton:SetTall(40)
	self.startButton:SetText("BEGIN ROUTE")
	self.startButton:SetFont("DermaDefaultBold")
	self.startButton:SetTextColor(color_white)
	self.startButton.Paint = function(button, width, height)
		local accent = getAccent()
		local colour = accent

		if (button:IsHovered()) then
			colour = Color(math.min(accent.r + 18, 255), math.min(accent.g + 18, 255), math.min(accent.b + 18, 255))
		end

		draw.RoundedBox(3, 0, 0, width, height, colour)
	end
	self.startButton.OnCursorEntered = function()
		playDatapadSound("move")
	end
	self.startButton.DoClick = function()
		local locationID = self.selectedLocationID
		if (not locationID) then return end

		local route = SWRP.Navigator.GetActiveRoute()

		if (route and route.locationID == locationID and route.map == game.GetMap()) then
			playDatapadSound("back")
			SWRP.Navigator.StopNavigation(false)
			self:RefreshActionButton()
			return
		end

		playDatapadSound("zoom")
		if (SWRP.Navigator.StartNavigation(locationID) and IsValid(ix.gui.menu)) then
			ix.gui.menu:Remove()
		end
	end

	self.hologramFrame = self.right:Add("DPanel")
	self.hologramFrame:Dock(FILL)
	self.hologramFrame:DockMargin(0, 0, 0, 12)
	self.hologramFrame.Paint = function(panel, width, height)
		local accent = getAccent()
		draw.RoundedBox(3, 0, 0, width, height, Color(1, 8, 15, 245))

		surface.SetDrawColor(accent.r, accent.g, accent.b, 22)
		for gridX = 0, width, 34 do
			surface.DrawLine(width * 0.5, height * 0.72, gridX, height)
		end
		for gridY = math.floor(height * 0.72), height, 18 do
			surface.DrawLine(0, gridY, width, gridY)
		end

		draw.SimpleText("TACTICAL VESSEL PROJECTION", "DermaDefaultBold", 14, 12, Color(accent.r, accent.g, accent.b, 190))
		draw.SimpleText("VENATOR-CLASS STAR DESTROYER", "DermaDefault", 14, 31, Color(125, 165, 188))
	end
	self.hologramFrame.PaintOver = function(panel, width, height)
		drawScanlines(0, 0, width, height)

		local accent = getAccent()
		local pulse = 60 + math.floor((math.sin(RealTime() * 2.1) + 1) * 24)

		surface.SetDrawColor(accent.r, accent.g, accent.b, pulse)
		surface.DrawOutlinedRect(5, 5, width - 10, height - 10)

		self:DrawHologramDestinationMarker(panel, width, height)
	end

	self.modelPanel = self.hologramFrame:Add("DModelPanel")
	self.modelPanel:Dock(FILL)
	self.modelPanel:DockMargin(4, 44, 4, 4)
	self.modelPanel:SetMouseInputEnabled(false)
	self.modelPanel:SetPaintBackground(false)
	self.modelPanel:SetFOV((SWRP.Navigator.hologram and SWRP.Navigator.hologram.fov) or 36)
	self.modelPanel:SetAmbientLight(Color(50, 175, 225))
	self.modelPanel:SetDirectionalLight(BOX_TOP, Color(0, 0, 0))
	self.modelPanel:SetDirectionalLight(BOX_FRONT, Color(0, 0, 0))
	self.modelPanel:SetDirectionalLight(BOX_RIGHT, Color(0, 0, 0))

	self.modelPanel.LayoutEntity = function(panel, entity)
		if (not IsValid(entity) or not panel.hologramCentre or not panel.hologramDistance) then return end

		-- The model stays fixed; the camera orbits its calculated visual centre. This avoids
		-- an off-centre Blender/model origin making the ship orbit around empty space.
		entity:SetAngles(angle_zero)

		local config = SWRP.Navigator.hologram or {}
		local orbitDegrees
		if config.staticCamera ~= false then
			orbitDegrees = tonumber(config.fixedOrbitDegrees) or 90
		else
			orbitDegrees = (RealTime() * (config.orbitSpeed or 7)) % 360
		end
		local orbit = math.rad(orbitDegrees)
		local centre = panel.hologramCentre
		local distance = panel.hologramDistance
		local height = panel.hologramRadius * (config.cameraHeightMultiplier or 0.30)

		local cameraPosition = centre + Vector(
			math.cos(orbit) * distance,
			math.sin(orbit) * distance,
			height
		)

		panel.swrpCameraPosition = cameraPosition
		panel.swrpCameraLookAt = centre

		panel:SetCamPos(cameraPosition)
		panel:SetLookAt(centre)
	end

	self.modelPanel.PreDrawModel = function(panel, entity)
		local menuAlpha = getInheritedMenuAlpha(panel)

		-- When Helix has faded the TAB menu away, stop drawing the model altogether.
		-- This also prevents a one-frame cyan ship flash after the menu disappears.
		if (menuAlpha <= 0.002) then
			return false
		end

		panel.swrpMenuAlpha = menuAlpha

		render.SuppressEngineLighting(true)
		render.MaterialOverride(hologramMaterial)

		local hologramAlpha = 0.58 + math.sin(RealTime() * 9) * 0.035
		render.SetBlend(hologramAlpha * menuAlpha)
		render.SetColorModulation(0.18, 0.78, 1)
	end

	self.modelPanel.PostDrawModel = function(panel, entity)
		local selectedLocation = self:GetSelectedLocation()
		local useScreenMarker = selectedLocation and isvector(selectedLocation.hologramScreenAnchor)

		-- Future locations may still opt into model-space tracking. The Training Room
		-- uses a calibrated screen-space marker with a fixed camera for deterministic
		-- placement across resolutions.
		local worldPoint = useScreenMarker and nil or self:CaptureHologramDestinationMarker(panel, entity)

		render.SetColorModulation(1, 1, 1)
		render.SetBlend(1)
		render.MaterialOverride()
		render.SuppressEngineLighting(false)

		if worldPoint and markerGlowMaterial then
			local menuAlpha = panel.swrpMenuAlpha or 1
			local pulse = (math.sin(RealTime() * 4.2) + 1) * 0.5
			local size = math.max((panel.hologramRadius or 1) * (0.026 + pulse * 0.006), 2)
			cam.IgnoreZ(true)
			render.SetMaterial(markerGlowMaterial)
			render.DrawSprite(worldPoint, size * 2.2, size * 2.2, Color(75, 205, 255, math.floor(85 * menuAlpha)))
			render.DrawSprite(worldPoint, size, size, Color(235, 253, 255, math.floor(255 * menuAlpha)))
			cam.IgnoreZ(false)
		end
	end

	self.modelFallback = self.hologramFrame:Add("DLabel")
	self.modelFallback:SetFont("DermaDefaultBold")
	self.modelFallback:SetText("HOLOGRAM DATA UNAVAILABLE\nModel not mounted: " .. MODEL_PATH)
	self.modelFallback:SetTextColor(Color(110, 170, 195))
	self.modelFallback:SetContentAlignment(5)
	self.modelFallback:SetWrap(true)
	self.modelFallback:SetVisible(false)

	self:LoadHologramModel()
	self:RebuildLocations()
end

function PANEL:LoadHologramModel()
	local modelPath = (SWRP.Navigator.hologram and SWRP.Navigator.hologram.model) or MODEL_PATH

	if (not file.Exists(modelPath, "GAME")) then
		self.modelPanel:SetVisible(false)
		self.modelFallback:SetVisible(true)
		return
	end

	self.modelPanel:SetModel(modelPath)
	local entity = self.modelPanel:GetEntity()

	if (not IsValid(entity)) then
		self.modelPanel:SetVisible(false)
		self.modelFallback:SetVisible(true)
		return
	end

	local minimum, maximum = entity:GetModelRenderBounds()
	if (not isvector(minimum) or not isvector(maximum)) then
		minimum, maximum = entity:GetRenderBounds()
	end

	local config = SWRP.Navigator.hologram or {}
	local centre = (minimum + maximum) * 0.5 + (config.centreOffset or vector_origin)
	local size = maximum - minimum
	local radius = math.max(size:Length() * 0.5, 1)
	local fov = math.rad(self.modelPanel:GetFOV())
	local distance = (radius / math.tan(fov * 0.5)) * (config.distanceMultiplier or 1.12)

	self.modelPanel.hologramCentre = centre
	self.modelPanel.hologramRadius = radius
	self.modelPanel.hologramDistance = distance
	self.modelPanel.hologramBoundsMinimum = minimum
	self.modelPanel.hologramBoundsMaximum = maximum
	self.modelPanel:SetLookAt(centre)
	self.modelPanel:SetCamPos(centre + Vector(distance, 0, radius * 0.30))

	entity:SetRenderMode(RENDERMODE_TRANSCOLOR)
	entity:SetColor(Color(60, 205, 255, 180))
end


local function getHologramAnchorWorldPoint(modelPanel, entity, location)
	if (
		not location
		or not isvector(location.hologramAnchor)
		or not IsValid(modelPanel)
		or not IsValid(entity)
		or not isvector(modelPanel.hologramBoundsMinimum)
		or not isvector(modelPanel.hologramBoundsMaximum)
	) then
		return nil
	end

	local minimum = modelPanel.hologramBoundsMinimum
	local maximum = modelPanel.hologramBoundsMaximum
	local boundsSize = maximum - minimum
	local anchor = location.hologramAnchor
	local modelLocalPoint = Vector(
		minimum.x + boundsSize.x * math.Clamp(anchor.x, 0, 1),
		minimum.y + boundsSize.y * math.Clamp(anchor.y, 0, 1),
		minimum.z + boundsSize.z * math.Clamp(anchor.z, 0, 1)
	)

	return entity:LocalToWorld(modelLocalPoint)
end

function PANEL:CaptureHologramDestinationMarker(modelPanel, entity)
	local location = self:GetSelectedLocation()
	local worldPoint = getHologramAnchorWorldPoint(modelPanel, entity, location)

	if not worldPoint then
		modelPanel.swrpProjectedMarkerAt = nil
		return nil
	end

	-- This function runs inside DModelPanel:PostDrawModel while that panel's
	-- cam.Start3D viewport is still active. ToScreen therefore uses the exact
	-- engine projection, including the current panel size and aspect ratio.
	local projected = worldPoint:ToScreen()
	local screenX, screenY = modelPanel:LocalToScreen(0, 0)
	local localX = projected and projected.visible ~= false and (projected.x - screenX) or nil
	local localY = projected and projected.visible ~= false and (projected.y - screenY) or nil

	-- Some render branches do not report the custom viewport through ToScreen.
	-- Retain the camera-space calculation as a guarded fallback only.
	if not localX or not localY
	or localX < -modelPanel:GetWide() or localX > modelPanel:GetWide() * 2
	or localY < -modelPanel:GetTall() or localY > modelPanel:GetTall() * 2 then
		localX, localY = projectModelPoint(modelPanel, worldPoint)
	end

	if localX and localY then
		modelPanel.swrpProjectedMarkerX = localX
		modelPanel.swrpProjectedMarkerY = localY
		modelPanel.swrpProjectedMarkerAt = RealTime()
	else
		modelPanel.swrpProjectedMarkerAt = nil
	end

	return worldPoint
end

function PANEL:DrawHologramDestinationMarker(frame, frameWidth, frameHeight)
	local location = self:GetSelectedLocation()
	local modelPanel = self.modelPanel

	if (
		not location
		or not isvector(location.hologramAnchor)
		or not IsValid(modelPanel)
		or not modelPanel:IsVisible()
		or not isvector(modelPanel.hologramBoundsMinimum)
		or not isvector(modelPanel.hologramBoundsMaximum)
	) then
		return
	end

	local entity = modelPanel:GetEntity()
	if not IsValid(entity) then
		return
	end

	local modelX, modelY = modelPanel:GetPos()
	local markerX, markerY

	if isvector(location.hologramScreenAnchor) then
		local viewportHeight = modelPanel:GetTall()
		markerX = modelX + modelPanel:GetWide() * 0.5 + viewportHeight * location.hologramScreenAnchor.x
		markerY = modelY + viewportHeight * math.Clamp(location.hologramScreenAnchor.y, 0, 1)
	else
		local capturedRecently = modelPanel.swrpProjectedMarkerAt and (RealTime() - modelPanel.swrpProjectedMarkerAt) <= 0.25
		if capturedRecently then
			markerX = modelPanel.swrpProjectedMarkerX
			markerY = modelPanel.swrpProjectedMarkerY
		else
			local worldPoint = getHologramAnchorWorldPoint(modelPanel, entity, location)
			markerX, markerY = projectModelPoint(modelPanel, worldPoint)
		end

		if not markerX or not markerY then
			return
		end

		local screenOffset = location.hologramScreenOffset
		if isvector(screenOffset) then
			markerX = markerX + modelPanel:GetWide() * screenOffset.x
			markerY = markerY + modelPanel:GetTall() * screenOffset.y
		end

		markerX = markerX + modelX
		markerY = markerY + modelY
	end

	if markerX < modelX - 20
	or markerX > modelX + modelPanel:GetWide() + 20
	or markerY < modelY - 20
	or markerY > modelY + modelPanel:GetTall() + 20 then
		return
	end

	local accent = getAccent()
	local menuAlpha = getInheritedMenuAlpha(frame)
	local alpha = math.floor(255 * menuAlpha)
	if alpha <= 1 then
		return
	end

	-- Match the approved NAVCOM reference: a fixed left-hand label, horizontal
	-- terminal line and diagonal segment down to the ship-bound anchor. All
	-- distances are percentages of the model viewport rather than pixels.
	local viewportWidth = modelPanel:GetWide()
	local viewportHeight = modelPanel:GetTall()
	local direction = -1
	local endX
	local elbowY

	if isvector(location.hologramCalloutAnchor) then
		endX = modelX + viewportWidth * math.Clamp(location.hologramCalloutAnchor.x, 0, 1)
		elbowY = modelY + viewportHeight * math.Clamp(location.hologramCalloutAnchor.y, 0, 1)
		direction = endX < markerX and -1 or 1
	else
		endX = markerX - viewportWidth * 0.24
		if endX < modelX + 34 then
			direction = 1
			endX = markerX + viewportWidth * 0.24
		end
		elbowY = markerY - viewportHeight * 0.22
	end

	elbowY = math.Clamp(elbowY, modelY + 62, modelY + viewportHeight - 70)
	endX = math.Clamp(endX, modelX + 34, modelX + viewportWidth - 34)
	local elbowX = markerX + direction * viewportWidth * 0.10

	if direction < 0 then
		elbowX = math.max(endX + viewportWidth * 0.08, markerX - viewportWidth * 0.14)
	else
		elbowX = math.min(endX - viewportWidth * 0.08, markerX + viewportWidth * 0.14)
	end

	local pulse = (math.sin(RealTime() * 3.6) + 1) * 0.5
	local ringRadius = 6 + pulse * 2

	-- White target dot with a restrained cyan scan ring.
	surface.SetDrawColor(accent.r, accent.g, accent.b, math.floor(115 * menuAlpha))
	surface.DrawCircle(markerX, markerY, ringRadius, accent.r, accent.g, accent.b, math.floor(150 * menuAlpha))
	draw.RoundedBox(4, markerX - 3, markerY - 3, 6, 6, Color(240, 253, 255, alpha))

	-- Shadow and main two-segment leader line.
	surface.SetDrawColor(accent.r, accent.g, accent.b, math.floor(75 * menuAlpha))
	surface.DrawLine(markerX + 1, markerY + 1, elbowX + 1, elbowY + 1)
	surface.DrawLine(elbowX + 1, elbowY + 1, endX + 1, elbowY + 1)

	surface.SetDrawColor(235, 250, 255, alpha)
	surface.DrawLine(markerX, markerY, elbowX, elbowY)
	surface.DrawLine(elbowX, elbowY, endX, elbowY)
	surface.DrawLine(endX, elbowY - 4, endX, elbowY + 4)

	local label = string.upper(location.hologramLabel or location.name or "DESTINATION")
	local code = string.upper(location.hologramCode or "NAV-LOC")
	local textAlign = direction < 0 and TEXT_ALIGN_RIGHT or TEXT_ALIGN_LEFT
	local textX = endX + (direction < 0 and -10 or 10)

	draw.SimpleText(label, "DermaDefaultBold", textX, elbowY - 27, Color(238, 252, 255, alpha), textAlign, TEXT_ALIGN_TOP)
	draw.SimpleText(code .. "  •  SELECTED DESTINATION", "DermaDefault", textX, elbowY - 11, Color(accent.r, accent.g, accent.b, math.floor(205 * menuAlpha)), textAlign, TEXT_ALIGN_TOP)
end

function PANEL:GetSelectedLocation()
	if (not self.selectedLocationID) then return nil end
	return SWRP.Navigator.GetLocation(self.selectedLocationID)
end

function PANEL:SelectLocation(locationID)
	if self.selectedLocationID ~= locationID then
		playDatapadSound("zoom")
	end
	self.selectedLocationID = locationID
	self:RefreshActionButton()
	self:RebuildLocations()
end

function PANEL:RefreshActionButton()
	local location = self:GetSelectedLocation()
	self.startButton:SetEnabled(location ~= nil)

	if (not location) then
		self.startButton:SetText("SELECT A DESTINATION")
		return
	end

	local route = SWRP.Navigator.GetActiveRoute()
	if (route and route.locationID == self.selectedLocationID and route.map == game.GetMap()) then
		self.startButton:SetText("CANCEL ROUTE")
	elseif (route) then
		self.startButton:SetText("CHANGE DESTINATION")
	else
		self.startButton:SetText("BEGIN ROUTE")
	end
end

function PANEL:RebuildLocations()
	if (not IsValid(self.locationList)) then return end
	self.locationList:Clear()

	local filtered = {}
	for _, location in ipairs(SWRP.Navigator.GetSortedLocations()) do
		local haystack = string.lower(table.concat({
			tostring(location.name or ""),
			tostring(location.category or ""),
			tostring(location.deck or ""),
			tostring(location.description or "")
		}, " "))

		if (self.searchText == "" or string.find(haystack, self.searchText, 1, true)) then
			filtered[#filtered + 1] = location
		end
	end

	if (#filtered == 0) then
		local empty = self.locationList:Add("DLabel")
		empty:Dock(TOP)
		empty:SetTall(50)
		empty:SetText("No matching locations are available on this map.")
		empty:SetTextColor(Color(145, 165, 180))
		empty:SetWrap(true)
		return
	end

	local lastCategory = nil
	for _, location in ipairs(filtered) do
		if (location.category ~= lastCategory) then
			lastCategory = location.category
			local category = self.locationList:Add("DLabel")
			category:Dock(TOP)
			category:SetTall(28)
			category:DockMargin(4, 5, 4, 2)
			category:SetFont("DermaDefaultBold")
			category:SetText(string.upper(location.category or "Locations"))
			category:SetTextColor(getAccent())
		end

		local button = self.locationList:Add("DButton")
		button:Dock(TOP)
		button:SetTall(62)
		button:DockMargin(0, 0, 4, 7)
		button:SetText("")
		button.locationID = location.id
		button.Paint = function(currentButton, width, height)
			local selected = self.selectedLocationID == currentButton.locationID
			local route = SWRP.Navigator.GetActiveRoute()
			local active = route and route.locationID == currentButton.locationID and route.map == game.GetMap()
			local background = Color(8, 19, 30, 238)

			if (selected) then
				background = Color(20, 43, 61, 248)
			elseif (currentButton:IsHovered()) then
				background = Color(14, 31, 46, 248)
			end

			draw.RoundedBox(3, 0, 0, width, height, background)
			if (selected or active) then draw.RoundedBox(3, 0, 0, 3, height, getAccent()) end
			draw.SimpleText(location.name or location.id, "DermaDefaultBold", 13, 12, color_white)
			draw.SimpleText(string.upper(location.deck or location.category or "SHIP LOCATION"), "DermaDefault", 13, 35, Color(130, 165, 186))
			if (active) then draw.SimpleText("ACTIVE", "DermaDefaultBold", width - 12, height * 0.5, getAccent(), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) end
		end
		button.DoClick = function() self:SelectLocation(location.id) end
	end

	if (not self.selectedLocationID and filtered[1]) then self.selectedLocationID = filtered[1].id end
	self:RefreshActionButton()
end

function PANEL:PerformLayout(width, height)
	if (IsValid(self.modelFallback) and IsValid(self.hologramFrame)) then
		self.modelFallback:SetPos(24, 70)
		self.modelFallback:SetSize(math.max(self.hologramFrame:GetWide() - 48, 1), math.max(self.hologramFrame:GetTall() - 100, 1))
	end
end

function PANEL:Think()
	if (CurTime() < self.nextRefresh) then return end
	self.nextRefresh = CurTime() + 0.25
	self:RefreshActionButton()
end

vgui.Register("swrpNavigator", PANEL, "DPanel")
