-- swrp/plugins/onboarding/derma/cl_character_menu.lua
-- Complete Republic/Battlefront-inspired replacement for the Helix join, creation and load screens.

SWRP = SWRP or {}
SWRP.JoinMenuVersion = "4.3.0"

local UI = {}
UI.blue = Color(76, 143, 224)
UI.blueSoft = Color(76, 143, 224, 110)
UI.white = Color(235, 242, 252)
UI.text = Color(190, 204, 222)
UI.muted = Color(116, 132, 153)
UI.panel = Color(8, 13, 22, 238)
UI.panelLight = Color(15, 23, 35, 242)
UI.line = Color(103, 148, 205, 62)
UI.error = Color(222, 83, 83)
UI.success = Color(92, 205, 176)
UI.sounds = {
	hover = "swrp/ui/ui_menumove.wav",
	select = "swrp/ui/ui_planetzoom.wav",
	back = "swrp/ui/ui_menuback.wav"
}

local function joinFontSize(base)
	return math.max(math.floor(base * math.Clamp(ScrH() / 1080, 0.78, 1.18) + 0.5), 9)
end

surface.CreateFont("SWRPJoinHero", {
	font = "Roboto",
	size = joinFontSize(31),
	weight = 300,
	extended = true
})

surface.CreateFont("SWRPJoinTitle", {
	font = "Roboto",
	size = joinFontSize(24),
	weight = 400,
	extended = true
})

surface.CreateFont("SWRPJoinHeading", {
	font = "Roboto Medium",
	size = joinFontSize(18),
	weight = 500,
	extended = true
})

surface.CreateFont("SWRPJoinBody", {
	font = "Roboto",
	size = joinFontSize(15),
	weight = 400,
	extended = true
})

surface.CreateFont("SWRPJoinSmall", {
	font = "Roboto",
	size = joinFontSize(12),
	weight = 500,
	extended = true
})

surface.CreateFont("SWRPJoinMicro", {
	font = "Roboto",
	size = joinFontSize(10),
	weight = 500,
	extended = true
})

local lastUISound = 0
local function playUISound(kind)
	if ((lastUISound or 0) > RealTime()) then
		return
	end

	local path = UI.sounds[kind]

	if (path) then
		surface.PlaySound(path)
		lastUISound = RealTime() + 0.035
	end
end

local function drawCorners(x, y, width, height, colour, length, thickness)
	length = length or 14
	thickness = thickness or 2
	surface.SetDrawColor(colour)

	surface.DrawRect(x, y, length, thickness)
	surface.DrawRect(x, y, thickness, length)
	surface.DrawRect(x + width - length, y, length, thickness)
	surface.DrawRect(x + width - thickness, y, thickness, length)
	surface.DrawRect(x, y + height - thickness, length, thickness)
	surface.DrawRect(x, y + height - length, thickness, length)
	surface.DrawRect(x + width - length, y + height - thickness, length, thickness)
	surface.DrawRect(x + width - thickness, y + height - length, thickness, length)
end

local function drawArc(cx, cy, radius, startAngle, endAngle, colour, segments, thickness)
	segments = math.max(segments or 40, 4)
	thickness = math.max(thickness or 1, 1)
	surface.SetDrawColor(colour)

	local previousX
	local previousY
	for index = 0, segments do
		local fraction = index / segments
		local angle = math.rad(Lerp(fraction, startAngle, endAngle))
		local cosine = math.cos(angle)
		local sine = math.sin(angle)

		for layer = 0, thickness - 1 do
			local layerRadius = radius + layer
			local x = cx + cosine * layerRadius
			local y = cy + sine * layerRadius
			if (previousX and layer == 0) then
				surface.DrawLine(previousX, previousY, x, y)
			end
		end

		previousX = cx + cosine * radius
		previousY = cy + sine * radius
	end
end

local function drawRadialTicks(cx, cy, innerRadius, outerRadius, count, rotation, colour)
	count = math.max(count or 24, 4)
	rotation = rotation or 0
	surface.SetDrawColor(colour)

	for index = 1, count do
		local angle = math.rad(rotation + (index - 1) * (360 / count))
		local cosine = math.cos(angle)
		local sine = math.sin(angle)
		surface.DrawLine(
			cx + cosine * innerRadius,
			cy + sine * innerRadius,
			cx + cosine * outerRadius,
			cy + sine * outerRadius
		)
	end
end

local function paintRepublicBackdrop(panel, width, height)
	surface.SetDrawColor(2, 5, 10, 242)
	surface.DrawRect(0, 0, width, height)

	for y = 0, height, 4 do
		surface.SetDrawColor(100, 150, 220, 4)
		surface.DrawRect(0, y, width, 1)
	end

	surface.SetDrawColor(UI.blue.r, UI.blue.g, UI.blue.b, 35)
	surface.DrawRect(0, 0, width, 2)
	surface.DrawRect(0, height - 2, width, 2)
end

local fitText

local function makeLabel(parent, text, font, colour, alignment)
	local label = parent:Add("DLabel")
	label:SetText(text or "")
	label:SetFont(font or "SWRPJoinBody")
	label:SetTextColor(colour or UI.white)
	label:SetContentAlignment(alignment or 4)
	label:SetWrap(false)
	return label
end

local function makeButton(parent, title, subtitle, callback, soundKind)
	local button = parent:Add("DButton")
	button:SetText("")
	button:SetCursor("hand")
	button.title = title or ""
	button.subtitle = subtitle or ""
	button.soundKind = soundKind or "select"

	button.OnCursorEntered = function(this)
		if (!this:IsEnabled()) then
			return
		end

		playUISound("hover")
	end

	button.DoClick = function(this)
		if (!this:IsEnabled()) then
			return
		end

		playUISound(this.soundKind)

		if (callback) then
			callback(this)
		end
	end

	button.Paint = function(this, width, height)
		local enabled = this:IsEnabled()
		local hovered = enabled and this:IsHovered()
		local active = this.active
		local alpha = enabled and 255 or 70

		surface.SetDrawColor(hovered and Color(23, 39, 61, 245) or Color(10, 18, 29, 235))
		surface.DrawRect(0, 0, width, height)

		local lineColour = active and UI.blue or (hovered and Color(125, 178, 241) or Color(75, 104, 140, 95))
		surface.SetDrawColor(lineColour.r, lineColour.g, lineColour.b, alpha)
		surface.DrawRect(0, 0, active and 5 or 2, height)
		surface.DrawOutlinedRect(0, 0, width, height, active and 2 or 1)

		local textWidth = math.max(width - 64, 20)
		local titleY = this.subtitle ~= "" and height * 0.34 or height * 0.5
		local fittedTitle = fitText and fitText(this.title, "SWRPJoinHeading", textWidth) or this.title
		draw.SimpleText(fittedTitle, "SWRPJoinHeading", 20, titleY, Color(UI.white.r, UI.white.g, UI.white.b, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (this.subtitle ~= "") then
			local fittedSubtitle = fitText and fitText(this.subtitle, "SWRPJoinSmall", textWidth) or this.subtitle
			draw.SimpleText(fittedSubtitle, "SWRPJoinSmall", 20, height * 0.70, Color(UI.text.r, UI.text.g, UI.text.b, alpha * 0.75), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		if (enabled) then
			draw.SimpleText("›", "SWRPJoinTitle", width - 22, height * 0.5, hovered and UI.white or UI.blue, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	return button
end

local function makeTextEntry(parent, placeholder)
	local entry = parent:Add("DTextEntry")
	entry:SetFont("SWRPJoinHeading")
	entry:SetTextColor(UI.white)
	entry:SetCursorColor(UI.blue)
	entry:SetHighlightColor(Color(UI.blue.r, UI.blue.g, UI.blue.b, 100))
	entry:SetPlaceholderText(placeholder or "")
	entry:SetDrawLanguageID(false)
	entry:SetUpdateOnType(true)

	entry.Paint = function(this, width, height)
		surface.SetDrawColor(this:HasFocus() and Color(17, 31, 49, 245) or Color(10, 17, 27, 235))
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(this:HasFocus() and UI.blue or Color(90, 115, 145, 100))
		surface.DrawOutlinedRect(0, 0, width, height, this:HasFocus() and 2 or 1)
		this:DrawTextEntryText(UI.white, UI.blue, UI.white)
	end

	entry.OnCursorEntered = function()
		playUISound("hover")
	end

	return entry
end

local function drawWrappedText(text, font, x, y, colour, maxWidth, lineHeight)
	text = tostring(text or "")
	lineHeight = lineHeight or 18
	surface.SetFont(font)

	local line = ""
	local drawY = y

	for _, word in ipairs(string.Explode(" ", text, false)) do
		local candidate = line == "" and word or (line .. " " .. word)
		local textWidth = surface.GetTextSize(candidate)

		if (textWidth > maxWidth and line ~= "") then
			draw.SimpleText(line, font, x, drawY, colour, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			drawY = drawY + lineHeight
			line = word
		else
			line = candidate
		end
	end

	if (line ~= "") then
		draw.SimpleText(line, font, x, drawY, colour, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		drawY = drawY + lineHeight
	end

	return drawY
end

fitText = function(text, font, maxWidth)
	text = tostring(text or "")
	maxWidth = math.max(tonumber(maxWidth) or 0, 0)
	surface.SetFont(font)

	if (surface.GetTextSize(text) <= maxWidth) then
		return text
	end

	local suffix = "..."
	local low = 0
	local high = #text

	while (low < high) do
		local middle = math.ceil((low + high) * 0.5)
		local candidate = string.TrimRight(text:sub(1, middle)) .. suffix

		if (surface.GetTextSize(candidate) <= maxWidth) then
			low = middle
		else
			high = middle - 1
		end
	end

	return string.TrimRight(text:sub(1, low)) .. suffix
end

-- A static, fullbright model panel used only by the join flow. It deliberately avoids
-- the directional Helix lighting that can turn some Workshop clone materials into a
-- black silhouette in DModelPanel, and it disables projected entity shadows entirely.
DEFINE_BASECLASS("ixModelPanel")
local JOIN_MODEL = {}

function JOIN_MODEL:Init()
	BaseClass.Init(self)
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
	self.modelAngle = Angle(0, 35, 0)
end

function JOIN_MODEL:SetModel(model, skin, bodygroups)
	BaseClass.SetModel(self, model, skin, bodygroups)

	if (IsValid(self.Entity)) then
		self.Entity:DrawShadow(false)
		self.Entity:SetNoDraw(true)
		self.Entity:SetIK(false)
		self.Entity:SetRenderMode(RENDERMODE_NORMAL)
		self.Entity:SetColor(color_white)
	end
end

function JOIN_MODEL:LayoutEntity(entity)
	if (!IsValid(entity)) then return end
	entity:SetAngles(self.modelAngle or angle_zero)
	entity:SetIK(false)
	entity:SetPoseParameter("head_pitch", 0)
	entity:SetPoseParameter("head_yaw", 0)
	self:RunAnimation()
end

function JOIN_MODEL:DrawModel()
	if (!IsValid(self.Entity)) then return end

	render.SetStencilEnable(false)
	render.MaterialOverride(nil)
	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
	render.SuppressEngineLighting(true)
	self.Entity:DrawModel()
	render.SuppressEngineLighting(false)
	render.SetColorModulation(1, 1, 1)
	render.SetBlend(1)
end

vgui.Register("swrpJoinModelPanel", JOIN_MODEL, "ixModelPanel")

local function getDeploymentName()
	local map = tostring(game.GetMap() or "UNKNOWN SECTOR")
	map = map:gsub("^[Rr][Pp]_", "")
	map = map:gsub("_", " ")
	map = string.Trim(map)

	if (map == "") then
		return "UNKNOWN SECTOR"
	end

	return string.upper(map)
end

local function safeValue(character, getter, fallback)
	if (!character or !isfunction(character[getter])) then
		return fallback
	end

	local value = character[getter](character)

	if (value == nil or value == "") then
		return fallback
	end

	return value
end

local function getCloneFaction()
	if (FACTION_CLONE and ix.faction.indices[FACTION_CLONE]) then
		return ix.faction.indices[FACTION_CLONE]
	end

	for _, faction in pairs(ix.faction.indices) do
		if (faction.uniqueID == "clone_trooper") then
			return faction
		end
	end

	for _, faction in pairs(ix.faction.teams) do
		if (faction.isDefault) then
			return faction
		end
	end
end

local function getFactionModel(faction)
	if (!faction) then
		return "models/error.mdl", 1
	end

	local models = faction:GetModels(LocalPlayer()) or {}
	local selection = models[1]

	if (istable(selection)) then
		return selection[1] or "models/error.mdl", 1, selection[2], selection[3]
	end

	return selection or "models/error.mdl", 1
end

local function frameModelPanel(panel, padding)
	if (!IsValid(panel) or !IsValid(panel.Entity)) then
		return
	end

	padding = tonumber(padding) or 1.18
	local mins, maxs = panel.Entity:GetRenderBounds()
	local size = maxs - mins
	local centre = (mins + maxs) * 0.5
	local modelHeight = math.max(size.z, 1)
	local modelWidth = math.max(size.x, size.y, 1)
	local fov = 34
	local verticalFOV = math.rad(fov)
	local aspect = math.max(panel:GetWide() / math.max(panel:GetTall(), 1), 0.2)
	local horizontalFOV = 2 * math.atan(math.tan(verticalFOV * 0.5) * aspect)
	local verticalDistance = (modelHeight * 0.5) / math.tan(verticalFOV * 0.5)
	local horizontalDistance = (modelWidth * 0.72) / math.tan(horizontalFOV * 0.5)
	local distance = math.max(verticalDistance, horizontalDistance, 92) * padding
	local lookAt = centre + Vector(0, 0, modelHeight * 0.015)

	panel:SetFOV(fov)
	panel:SetLookAt(lookAt)
	panel:SetCamPos(lookAt + Vector(distance, 0, modelHeight * 0.025))
end

local function applyCharacterModel(panel, character)
	if (!IsValid(panel) or !character) then
		return
	end

	local model = character:GetModel()
	if (istable(model)) then model = model[1] end
	panel:SetModel(model)
	panel:SetSkin(math.max(tonumber(character:GetData("skin", 0)) or 0, 0))

	local entity = panel.Entity
	if (!IsValid(entity)) then return end

	entity:DrawShadow(false)
	entity:SetNoDraw(true)
	entity:SetIK(false)
	entity:SetRenderMode(RENDERMODE_NORMAL)
	entity:SetColor(color_white)

	-- Old records can retain bodygroup indices from a previous placeholder model.
	-- Applying those indices to the clone model removes armour sections and looks like
	-- a second black model. The service-record preview therefore uses the model's safe
	-- default bodygroups; the player's real in-world bodygroups are not changed.
	for i = 0, entity:GetNumBodyGroups() - 1 do
		entity:SetBodygroup(i, 0)
	end

	timer.Simple(0, function()
		if (IsValid(panel)) then
			frameModelPanel(panel, 1.34)
		end
	end)
end

local function getCareerNodeTitle(node)
	if (!node) then
		return "UNASSIGNED"
	end

	if (node.capability == "weapons_specialist") then
		return "Heavy Specialist"
	end

	return node.title or "Unknown"
end

local roleCapabilities = {
	{"combat_medic", "Combat Medic"},
	{"medic", "Field Medic"},
	{"advanced_pilot", "Advanced Pilot"},
	{"pilot", "Republic Pilot"},
	{"weapons_specialist", "Heavy Specialist"},
	{"launcher_weapons", "Launcher Specialist"},
	{"heavy_weapons", "Heavy Trooper"},
	{"marksman", "Marksman"}
}

local function getCharacterRole(character)
	local datapad = SWRP.Datapad

	if (datapad and isfunction(datapad.HasCapability)) then
		for _, definition in ipairs(roleCapabilities) do
			if (datapad.HasCapability(character, definition[1])) then
				return definition[2]
			end
		end
	end

	return "Clone Trooper"
end

local function getCareerProgress(character)
	local tree = SWRP.GetUpgradeTree()
	local pathID = safeValue(character, "GetCareerPath", "")
	local branch = SWRP.GetCareerBranch(pathID)

	if (!tree or !branch or !isfunction(tree.GetMask)) then
		return 0, 0
	end

	local mask = tree.GetMask(character)

	if (isfunction(tree.GetBranchProgress)) then
		return tree.GetBranchProgress(mask, branch)
	end

	local unlocked = 0

	for _, node in ipairs(branch.nodes or {}) do
		if (tree.IsUnlocked(mask, node)) then
			unlocked = unlocked + 1
		end
	end

	return unlocked, #(branch.nodes or {})
end

-- =====================================================================================
-- Career tree selector
-- =====================================================================================

local TREE_PANEL = {}

function TREE_PANEL:Init()
	self.nodeButtons = {}
	self.positions = {}
	self.branch = nil
	self.selectedTarget = ""
end

function TREE_PANEL:ClearNodes()
	for _, button in pairs(self.nodeButtons) do
		if (IsValid(button)) then
			button:Remove()
		end
	end

	self.nodeButtons = {}
	self.positions = {}
end

function TREE_PANEL:SetSelectedTarget(targetID)
	self.selectedTarget = tostring(targetID or "")
end

function TREE_PANEL:SetBranch(branch)
	self.branch = branch
	self:ClearNodes()

	if (!branch) then
		return
	end

	for _, node in ipairs(branch.nodes or {}) do
		local button = self:Add("DButton")
		button:SetText("")
		button:SetCursor("hand")
		button.node = node

		button.OnCursorEntered = function()
			playUISound("hover")
		end

		button.DoClick = function(this)
			playUISound("select")
			self.selectedTarget = this.node.id

			if (self.OnTargetSelected) then
				self:OnTargetSelected(this.node)
			end
		end

		button.Paint = function(this, width, height)
			local selected = self.selectedTarget == this.node.id
			local hovered = this:IsHovered()
			local path = SWRP.GetCareerPath(this.node.branch)
			local colour = path and path.colour or UI.blue

			surface.SetDrawColor(selected and Color(colour.r, colour.g, colour.b, 42) or (hovered and Color(24, 38, 57, 245) or Color(10, 17, 27, 242)))
			surface.DrawRect(0, 0, width, height)
			surface.SetDrawColor(colour.r, colour.g, colour.b, selected and 255 or (hovered and 180 or 80))
			surface.DrawOutlinedRect(0, 0, width, height, selected and 2 or 1)
			surface.DrawRect(0, 0, selected and 4 or 2, height)

			draw.SimpleText(string.upper(getCareerNodeTitle(this.node)), "SWRPJoinSmall", 10, 9, selected and colour or UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(this.node.effect or "CAREER TARGET", "SWRPJoinMicro", 10, height - 8, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		end

		self.nodeButtons[node.id] = button
	end

	self:InvalidateLayout(true)
end

function TREE_PANEL:PerformLayout(width, height)
	if (!self.branch) then
		return
	end

	local nodes = self.branch.nodes or {}
	local minX, maxX, minY, maxY

	for _, node in ipairs(nodes) do
		minX = minX and math.min(minX, node.x or 0) or (node.x or 0)
		maxX = maxX and math.max(maxX, node.x or 0) or (node.x or 0)
		minY = minY and math.min(minY, node.y or 0) or (node.y or 0)
		maxY = maxY and math.max(maxY, node.y or 0) or (node.y or 0)
	end

	minX = minX or 0
	maxX = maxX or 1
	minY = minY or 0
	maxY = maxY or 1

	local nodeWidth = math.Clamp(width * 0.12, 105, 180)
	local nodeHeight = math.Clamp(height * 0.105, 54, 72)
	local left = 105
	local right = width - nodeWidth - 24
	local top = 54
	local bottom = height - nodeHeight - 30
	local xRange = math.max(maxX - minX, 1)
	local yRange = math.max(maxY - minY, 1)

	self.rootX = 36
	self.rootY = height * 0.5

	for _, node in ipairs(nodes) do
		local nx = left + ((node.x or 0) - minX) / xRange * math.max(right - left, 1)
		local ny = top + ((node.y or 0) - minY) / yRange * math.max(bottom - top, 1)
		local button = self.nodeButtons[node.id]

		if (IsValid(button)) then
			button:SetSize(nodeWidth, nodeHeight)
			button:SetPos(nx, ny)
			self.positions[node.id] = {x = nx + nodeWidth * 0.5, y = ny + nodeHeight * 0.5}
		end
	end
end

function TREE_PANEL:Paint(width, height)
	surface.SetDrawColor(UI.panel)
	surface.DrawRect(0, 0, width, height)
	surface.SetDrawColor(UI.line)
	surface.DrawOutlinedRect(0, 0, width, height, 1)
	drawCorners(0, 0, width, height, UI.blueSoft, 18, 2)

	if (!self.branch) then
		draw.SimpleText("CAREER NETWORK UNAVAILABLE", "SWRPJoinHeading", width * 0.5, height * 0.5, UI.error, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		return
	end

	local path = SWRP.GetCareerPath(self.branch.id)
	local colour = path and path.colour or UI.blue

	draw.SimpleText(path and path.fullTitle or self.branch.title, "SWRPJoinHeading", 18, 15, colour, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText("SELECT THE ROLE YOUR CHARACTER WANTS TO WORK TOWARDS", "SWRPJoinMicro", width - 18, 20, UI.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

	surface.SetDrawColor(colour.r, colour.g, colour.b, 70)

	for _, node in ipairs(self.branch.nodes or {}) do
		local destination = self.positions[node.id]

		if (!destination) then
			continue
		end

		for _, requirementID in ipairs(node.requires or {}) do
			local source = requirementID == "root" and {x = self.rootX, y = self.rootY} or self.positions[requirementID]

			if (source) then
				surface.DrawLine(source.x, source.y, destination.x, destination.y)
			end
		end
	end

	surface.SetDrawColor(colour.r, colour.g, colour.b, 42)
	surface.DrawCircle(self.rootX, self.rootY, 18, colour.r, colour.g, colour.b, 110)
	surface.DrawCircle(self.rootX, self.rootY, 12, colour.r, colour.g, colour.b, 200)
	draw.SimpleText("START", "SWRPJoinMicro", self.rootX, self.rootY + 27, UI.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

vgui.Register("swrpCareerTree", TREE_PANEL, "Panel")

-- =====================================================================================
-- Main join screen
-- =====================================================================================

DEFINE_BASECLASS("ixCharMenuPanel")

local MAIN = {}
AccessorFunc(MAIN, "bUsingCharacter", "UsingCharacter", FORCE_BOOL)

function MAIN:Init()
	self.bUsingCharacter = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()
	self.buttons = {}

	self.brand = makeLabel(self, "GALACTIC ROLEPLAY", "SWRPJoinHero", UI.white)
	self.brandSub = makeLabel(self, "REPUBLIC PERSONNEL & DEPLOYMENT NETWORK", "SWRPJoinSmall", UI.blue)
	self.connection = makeLabel(self, "SECURE CONNECTION // ONLINE", "SWRPJoinMicro", UI.success, 6)

	self.menuFrame = self:Add("Panel")
	self.menuFrame.Paint = function(panel, width, height)
		surface.SetDrawColor(Color(5, 10, 18, 226))
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		drawCorners(0, 0, width, height, UI.blueSoft, 22, 2)
		draw.SimpleText("PERSONNEL NETWORK", "SWRPJoinMicro", 22, 18, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	self.createButton = makeButton(self.menuFrame, "CREATE PERSONNEL RECORD", "Register a clone identity, doctrine and starting aptitude.", function()
		local maximum = hook.Run("GetMaxPlayerCharacter", LocalPlayer()) or ix.config.Get("maxCharacters", 5)
		if (#ix.characters >= maximum) then
			self:GetParent():ShowNotice(3, L("maxCharacters"))
			return
		end
		self:Dim()
		self:GetParent().newCharacterPanel:SlideUp()
	end)

	self.loadButton = makeButton(self.menuFrame, "ACCESS SERVICE RECORD", "Review your role, doctrine, level and progression.", function()
		self:Dim()
		self:GetParent().loadCharacterPanel:SlideUp()
	end)
	self.loadButton:SetEnabled(#ix.characters > 0)

	local communityURL = ix.config.Get("communityURL", "")
	self.communityButton = makeButton(self.menuFrame, "COMMUNITY UPLINK", "Open the community and operational channels.", function()
		if (communityURL ~= "") then gui.OpenURL(communityURL) end
	end)
	self.communityButton:SetEnabled(communityURL ~= "")

	self.returnButton = makeButton(self.menuFrame, "DISCONNECT", "Terminate the current Republic network session.", function()
		if (self.bUsingCharacter) then
			self:GetParent():Close()
		else
			RunConsoleCommand("disconnect")
		end
	end, "back")

	self.buttons = {self.createButton, self.loadButton, self.communityButton, self.returnButton}

	self.heroFrame = self:Add("Panel")
	self.heroFrame.Paint = function(panel, width, height)
		local now = RealTime()
		local pulse = (math.sin(now * 2.1) + 1) * 0.5
		local pad = math.Clamp(width * 0.052, 28, 46)
		local lowerBandHeight = math.Clamp(height * 0.24, 116, 146)
		local lowerBandY = height - lowerBandHeight - 24

		surface.SetDrawColor(Color(5, 11, 20, 184))
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		drawCorners(0, 0, width, height, UI.blueSoft, 28, 2)

		-- Subtle moving scan across the central command display.
		local scanX = ((now * 72) % (width + 180)) - 180
		surface.SetDrawColor(UI.blue.r, UI.blue.g, UI.blue.b, 10)
		surface.DrawRect(scanX, 1, 120, math.max(lowerBandY - 2, 0))

		draw.SimpleText("GRAND ARMY PERSONNEL COMMAND", "SWRPJoinMicro", pad, 24, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("YOUR SERVICE", "SWRPJoinHero", pad, 67, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("STARTS HERE", "SWRPJoinHero", pad, 108, UI.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		drawWrappedText(
			"Create your clone, choose how they will develop and earn a place in the Grand Army through service.",
			"SWRPJoinBody",
			pad,
			164,
			UI.text,
			math.max(width * 0.49, 280),
			22
		)

		local statusY = math.min(242, lowerBandY - 64)
		surface.SetDrawColor(Color(UI.success.r, UI.success.g, UI.success.b, 18 + pulse * 12))
		surface.DrawRect(pad, statusY, 250, 34)
		surface.SetDrawColor(UI.success.r, UI.success.g, UI.success.b, 150)
		surface.DrawOutlinedRect(pad, statusY, 250, 34, 1)
		surface.DrawRect(pad + 12, statusY + 15, 5, 5)
		draw.SimpleText("NEW PERSONNEL INTAKE // ACTIVE", "SWRPJoinMicro", pad + 28, statusY + 17, UI.success, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		-- Animated holographic personnel seal. This gives the home screen a focal point
		-- without introducing another character model or Workshop dependency.
		local sealX = width * 0.73
		local sealY = math.min(height * 0.39, lowerBandY * 0.50)
		local sealRadius = math.Clamp(math.min(width * 0.16, height * 0.22), 74, 138)
		local ringColour = Color(UI.blue.r, UI.blue.g, UI.blue.b, 45)
		local brightRing = Color(UI.blue.r, UI.blue.g, UI.blue.b, 105 + pulse * 35)
		local greenRing = Color(UI.success.r, UI.success.g, UI.success.b, 75)

		for radiusStep = 0, 3 do
			surface.DrawCircle(sealX, sealY, sealRadius - radiusStep * 20, ringColour.r, ringColour.g, ringColour.b, ringColour.a)
		end
		drawRadialTicks(sealX, sealY, sealRadius + 5, sealRadius + 15, 28, now * 4, brightRing)
		drawArc(sealX, sealY, sealRadius + 2, now * 22, now * 22 + 92, brightRing, 34, 2)
		drawArc(sealX, sealY, sealRadius - 25, 205 - now * 17, 308 - now * 17, greenRing, 30, 1)
		drawArc(sealX, sealY, sealRadius - 48, now * 28, now * 28 + 74, Color(255, 255, 255, 65), 24, 1)

		surface.SetDrawColor(UI.blue.r, UI.blue.g, UI.blue.b, 40)
		surface.DrawLine(sealX - sealRadius - 42, sealY, sealX + sealRadius + 42, sealY)
		surface.DrawLine(sealX, sealY - sealRadius - 30, sealX, sealY + sealRadius + 30)
		draw.SimpleText("GAR", "SWRPJoinHero", sealX, sealY - 18, UI.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("PERSONNEL COMMAND", "SWRPJoinMicro", sealX, sealY + 20, UI.blue, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("ENLISTMENT PROTOCOL 01", "SWRPJoinMicro", sealX, sealY + sealRadius + 27, UI.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

		-- Three-stage service path.
		local cardGap = 12
		local cardWidth = (width - pad * 2 - cardGap * 2) / 3
		local cardHeight = lowerBandHeight - 28
		local cardY = lowerBandY + 14
		local stages = {
			{"01", "IDENTITY", "Designation and callsign", UI.blue},
			{"02", "DOCTRINE", "Choose your XP advantage", UI.success},
			{"03", "SERVICE", "Earn roles and qualifications", UI.blue}
		}

		surface.SetDrawColor(UI.line)
		surface.DrawRect(pad, lowerBandY, width - pad * 2, 1)

		for index, stage in ipairs(stages) do
			local x = pad + (index - 1) * (cardWidth + cardGap)
			local colour = stage[4]
			surface.SetDrawColor(Color(7, 14, 24, 238))
			surface.DrawRect(x, cardY, cardWidth, cardHeight)
			surface.SetDrawColor(colour.r, colour.g, colour.b, index == 1 and 190 or 100)
			surface.DrawOutlinedRect(x, cardY, cardWidth, cardHeight, 1)
			surface.DrawRect(x, cardY, 3, cardHeight)
			draw.SimpleText(stage[1], "SWRPJoinMicro", x + 16, cardY + 13, colour, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(stage[2], "SWRPJoinHeading", x + 16, cardY + 36, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(fitText(stage[3], "SWRPJoinSmall", cardWidth - 32), "SWRPJoinSmall", x + 16, cardY + cardHeight - 18, UI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		end
	end

	self.intel = self:Add("Panel")
	self.intel.Paint = function(panel, width, height)
		surface.SetDrawColor(UI.panel)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		drawCorners(0, 0, width, height, UI.blueSoft, 18, 2)

		draw.SimpleText("REPUBLIC SERVICE", "SWRPJoinMicro", 20, 18, UI.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("BUILD A CAREER", "SWRPJoinTitle", 20, 48, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		local y = drawWrappedText("Choose a doctrine when your clone is created. It guides progression, but roles such as Medic, Heavy and Pilot must still be earned through level requirements and training.", "SWRPJoinBody", 20, 96, UI.text, width - 40, 22)
		y = y + 24
		surface.SetDrawColor(UI.line)
		surface.DrawRect(20, y, width - 40, 1)
		y = y + 24
		draw.SimpleText("DOCTRINE BENEFIT", "SWRPJoinMicro", 20, y, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 25
		draw.SimpleText("25% LOWER TREE COST", "SWRPJoinHeading", 20, y, UI.success, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 45
		draw.SimpleText("ROLE ACCESS", "SWRPJoinMicro", 20, y, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 25
		draw.SimpleText("LEVEL + CERTIFICATION", "SWRPJoinHeading", 20, y, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	self.operation = self:Add("Panel")
	self.operation.Paint = function(panel, width, height)
		surface.SetDrawColor(UI.panelLight)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		drawCorners(0, 0, width, height, UI.blueSoft, 18, 2)

		local personnelWidth = math.Clamp(width * 0.22, 130, 180)
		local dividerX = width - personnelWidth
		draw.SimpleText("CURRENT DEPLOYMENT", "SWRPJoinMicro", 20, 16, UI.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(fitText(getDeploymentName(), "SWRPJoinHeading", dividerX - 40), "SWRPJoinHeading", 20, 43, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("Personnel awaiting assignment", "SWRPJoinSmall", 20, height - 18, UI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

		surface.SetDrawColor(UI.line)
		surface.DrawRect(dividerX, 14, 1, height - 28)
		local online = #player.GetAll()
		draw.SimpleText(string.format("%02d", online), "SWRPJoinHero", width - 18, 12, UI.white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		draw.SimpleText("PERSONNEL ONLINE", "SWRPJoinMicro", width - 18, height - 18, UI.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	end

end

function MAIN:UpdateReturnButton(value)
	if (value ~= nil) then self.bUsingCharacter = value end
	if (!IsValid(self.returnButton)) then return end
	if (self.bUsingCharacter) then
		self.returnButton.title = "RETURN TO DEPLOYMENT"
		self.returnButton.subtitle = "Close the network and resume active duty."
	else
		self.returnButton.title = "DISCONNECT"
		self.returnButton.subtitle = "Terminate the current Republic network session."
	end
end

function MAIN:OnDim()
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
end

function MAIN:OnUndim()
	self:SetMouseInputEnabled(true)
	self:SetKeyboardInputEnabled(true)
	self.bUsingCharacter = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()
	self:UpdateReturnButton()
	self.loadButton:SetEnabled(#ix.characters > 0)
end

function MAIN:PerformLayout(width, height)
	local margin = math.Clamp(width * 0.03, 32, 58)
	local top = math.Clamp(height * 0.065, 40, 72)
	local bottomHeight = math.Clamp(height * 0.13, 108, 132)
	local contentBottom = height - margin - bottomHeight - 14
	local leftWidth = math.Clamp(width * 0.29, 410, 500)
	local intelWidth = math.Clamp(width * 0.21, 300, 360)
	local gap = math.Clamp(width * 0.012, 14, 22)
	local heroX = margin + leftWidth + gap
	local heroWidth = width - heroX - intelWidth - gap - margin

	self.brand:SetPos(margin, top)
	self.brand:SizeToContents()
	self.brandSub:SetPos(margin + 2, top + self.brand:GetTall() + 3)
	self.brandSub:SizeToContents()
	self.connection:SetPos(width - margin - 280, top + 6)
	self.connection:SetSize(280, 24)

	local menuY = top + self.brand:GetTall() + self.brandSub:GetTall() + 45
	self.menuFrame:SetPos(margin, menuY)
	self.menuFrame:SetSize(leftWidth, contentBottom - menuY)

	local pad = 18
	local buttonGap = 10
	local available = self.menuFrame:GetTall() - 54 - pad
	local buttonHeight = math.Clamp((available - buttonGap * 3) / 4, 74, 92)
	for index, button in ipairs(self.buttons) do
		button:SetPos(pad, 48 + (index - 1) * (buttonHeight + buttonGap))
		button:SetSize(leftWidth - pad * 2, buttonHeight)
	end

	self.heroFrame:SetPos(heroX, menuY)
	self.heroFrame:SetSize(heroWidth, contentBottom - menuY)

	self.intel:SetPos(width - margin - intelWidth, menuY)
	self.intel:SetSize(intelWidth, math.min(contentBottom - menuY, 430))

	self.operation:SetPos(heroX, height - margin - bottomHeight)
	self.operation:SetSize(width - heroX - margin, bottomHeight)
end

function MAIN:Paint(width, height)
	paintRepublicBackdrop(self, width, height)
	local centre = width * 0.58
	surface.SetDrawColor(UI.blue.r, UI.blue.g, UI.blue.b, 9)
	draw.NoTexture()
	surface.DrawPoly({
		{x = centre - 180, y = 0},
		{x = centre + 30, y = 0},
		{x = centre + 300, y = height},
		{x = centre + 40, y = height}
	})
	BaseClass.Paint(self, width, height)
end

vgui.Register("swrpCharMenuMain", MAIN, "ixCharMenuPanel")

-- =====================================================================================
-- Character creator
-- =====================================================================================

local CREATOR = {}

local function makeDoctrineCard(parent, path, onSelect)
	local button = parent:Add("DButton")
	button:SetText("")
	button:SetCursor("hand")
	button.path = path
	button.selected = false

	button.OnCursorEntered = function()
		playUISound("hover")
	end

	button.DoClick = function(this)
		playUISound("select")
		onSelect(this.path.id)
	end

	button.Paint = function(this, width, height)
		local selected = this.selected
		local hovered = this:IsHovered()
		local colour = this.path.colour or UI.blue
		local fill = selected and Color(colour.r, colour.g, colour.b, 34)
			or (hovered and Color(17, 30, 47, 248) or Color(7, 13, 22, 240))

		surface.SetDrawColor(fill)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(colour.r, colour.g, colour.b, selected and 245 or (hovered and 160 or 70))
		surface.DrawRect(0, 0, selected and 6 or 2, height)
		surface.DrawOutlinedRect(0, 0, width, height, selected and 2 or 1)
		if (selected) then drawCorners(0, 0, width, height, Color(colour.r, colour.g, colour.b, 180), 18, 2) end

		draw.SimpleText(this.path.title, "SWRPJoinTitle", 22, 18, selected and colour or UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("DEVELOPMENT DOCTRINE", "SWRPJoinMicro", width - 20, 22, UI.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		local y = drawWrappedText(this.path.description, "SWRPJoinBody", 22, 66, UI.text, width - 44, 21)
		y = math.max(y + 18, height - 105)
		draw.SimpleText("25% LOWER TREE COST", "SWRPJoinHeading", 22, y, colour, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(this.path.access, "SWRPJoinSmall", 22, height - 24, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

		if (selected) then
			draw.SimpleText("✓ SELECTED", "SWRPJoinSmall", width - 20, height - 24, colour, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		else
			draw.SimpleText("SELECT", "SWRPJoinMicro", width - 20, height - 24, UI.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end
	end

	return button
end

local function makeAptitudeCard(parent, aptitude, onSelect)
	local button = parent:Add("DButton")
	button:SetText("")
	button:SetCursor("hand")
	button.aptitude = aptitude
	button.selected = false

	button.OnCursorEntered = function()
		playUISound("hover")
	end

	button.DoClick = function(this)
		playUISound("select")
		onSelect(this.aptitude.id)
	end

	button.Paint = function(this, width, height)
		local selected = this.selected
		local hovered = this:IsHovered()
		local colour = this.aptitude.colour or UI.blue
		surface.SetDrawColor(selected and Color(colour.r, colour.g, colour.b, 36) or (hovered and Color(18, 31, 48, 248) or Color(7, 13, 22, 240)))
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(colour.r, colour.g, colour.b, selected and 245 or (hovered and 155 or 70))
		surface.DrawRect(0, 0, selected and 6 or 2, height)
		surface.DrawOutlinedRect(0, 0, width, height, selected and 2 or 1)
		if (selected) then drawCorners(0, 0, width, height, Color(colour.r, colour.g, colour.b, 180), 18, 2) end

		draw.SimpleText(this.aptitude.title, "SWRPJoinTitle", 22, 20, selected and colour or UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(this.aptitude.effect, "SWRPJoinHeading", 22, 68, colour, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		drawWrappedText(this.aptitude.description, "SWRPJoinBody", 22, 112, UI.text, width - 44, 21)
		if (selected) then
			draw.SimpleText("✓ SELECTED", "SWRPJoinSmall", width - 20, height - 20, colour, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		else
			draw.SimpleText("SELECT", "SWRPJoinMicro", width - 20, height - 20, UI.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end
	end

	return button
end

function CREATOR:Init()
	local parent = self:GetParent()
	self.awaitingResponse = false
	self.currentStep = 1
	self.selectedPath = ""
	self.selectedAptitude = ""
	self.digitEntries = {}
	self.doctrineCards = {}
	self.aptitudeCards = {}

	self.header = makeLabel(self, "CREATE PERSONNEL RECORD", "SWRPJoinTitle", UI.white)
	self.headerSub = makeLabel(self, "REPUBLIC PERSONNEL DATABASE // NEW ENTRY", "SWRPJoinSmall", UI.blue)
	self.stepLabel = makeLabel(self, "01 / 03   IDENTIFICATION", "SWRPJoinSmall", UI.white, 6)
	self.progress = self:Add("Panel")
	self.progress.Paint = function(panel, width, height)
		local segmentWidth = width / 3
		for index = 1, 3 do
			local active = index <= self.currentStep
			surface.SetDrawColor(active and UI.blue or Color(70, 90, 115, 55))
			surface.DrawRect((index - 1) * segmentWidth + (index > 1 and 5 or 0), 0, segmentWidth - 5, 3)
		end
	end

	-- Step 1: identity.
	self.identity = self:Add("Panel")
	self.identityModelFrame = self.identity:Add("Panel")
	self.identityModelFrame.Paint = function(panel, width, height)
		surface.SetDrawColor(Color(5, 10, 18, 225))
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		drawCorners(0, 0, width, height, UI.blueSoft, 22, 2)
		draw.SimpleText("LIVE PERSONNEL PREVIEW", "SWRPJoinMicro", 18, 16, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(self:GetDisplayName():upper(), "SWRPJoinHeading", 20, height - 52, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	self.identityModel = self.identityModelFrame:Add("swrpJoinModelPanel")
	self.identityModel:SetModel("models/error.mdl")
	self.identityModel:SetFOV(48)
	self.identityModel:SetMouseInputEnabled(false)

	self.identityForm = self.identity:Add("Panel")
	self.identityForm.Paint = function(panel, width, height)
		surface.SetDrawColor(UI.panelLight)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		drawCorners(0, 0, width, height, UI.blueSoft, 22, 2)
		draw.SimpleText("IDENTITY ASSIGNMENT", "SWRPJoinMicro", 26, 20, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("WHO IS THIS CLONE?", "SWRPJoinTitle", 26, 48, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	self.designationTitle = makeLabel(self.identityForm, "CLONE DESIGNATION", "SWRPJoinSmall", UI.blue)
	self.designationHelp = makeLabel(self.identityForm, "Four digits form the permanent Republic service number.", "SWRPJoinSmall", UI.muted)

	for i = 1, 4 do
		local entry = makeTextEntry(self.identityForm, "0")
		entry:SetFont("SWRPJoinHero")
		entry:SetContentAlignment(5)
		entry:SetNumeric(true)
		entry.digitIndex = i
		entry.bUpdating = false
		entry.OnGetFocus = function(this) this:SelectAllText() end
		entry.OnTextChanged = function(this)
			if (this.bUpdating) then return end
			local clean = tostring(this:GetValue() or ""):gsub("%D", "")
			if (#clean > 1) then
				for offset = 0, math.min(#clean - 1, 4 - this.digitIndex) do
					local target = self.digitEntries[this.digitIndex + offset]
					target.bUpdating = true
					target:SetText(clean:sub(offset + 1, offset + 1))
					target.bUpdating = false
				end
			elseif (this:GetValue() ~= clean) then
				this.bUpdating = true
				this:SetText(clean:sub(1, 1))
				this.bUpdating = false
			end
			if (#clean > 0 and this.digitIndex < 4) then self.digitEntries[this.digitIndex + 1]:RequestFocus() end
			self:UpdateIdentityPreview()
		end
		local oldKeyTyped = entry.OnKeyCodeTyped
		entry.OnKeyCodeTyped = function(this, code)
			if (code == KEY_BACKSPACE and this:GetValue() == "" and this.digitIndex > 1) then
				local previous = self.digitEntries[this.digitIndex - 1]
				previous:RequestFocus()
				previous:SelectAllText()
				return
			end
			if (oldKeyTyped) then oldKeyTyped(this, code) end
		end
		self.digitEntries[i] = entry
	end

	self.randomise = makeButton(self.identityForm, "RANDOMISE", "Generate an available-looking designation.", function()
		self:SetDesignation(string.format("%04d", math.random(1, 9999)))
	end)

	self.callsignTitle = makeLabel(self.identityForm, "NAME / CALLSIGN", "SWRPJoinSmall", UI.blue)
	self.callsignHelp = makeLabel(self.identityForm, "The name other players will use for this character.", "SWRPJoinSmall", UI.muted)
	self.callsign = makeTextEntry(self.identityForm, "Example: Sam, Sparrow, Atlas")
	self.callsign:SetMaximumCharCount(24)
	self.callsign.OnValueChange = function() self:UpdateIdentityPreview() end

	self.previewCard = self.identityForm:Add("Panel")
	self.previewCard.Paint = function(panel, width, height)
		surface.SetDrawColor(Color(5, 11, 20, 238))
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		draw.SimpleText("PERSONNEL RECORD PREVIEW", "SWRPJoinMicro", 18, 14, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(self:GetDisplayName():upper(), "SWRPJoinTitle", 18, 48, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("RANK  CT    //    REGIMENT  UNASSIGNED", "SWRPJoinSmall", 18, height - 18, UI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	end

	-- Step 2: doctrine.
	self.doctrine = self:Add("Panel")
	self.doctrine:SetVisible(false)
	self.doctrineBrief = self.doctrine:Add("Panel")
	self.doctrineBrief.Paint = function(panel, width, height)
		surface.SetDrawColor(UI.panelLight)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		drawCorners(0, 0, width, height, UI.blueSoft, 22, 2)
		draw.SimpleText("DEVELOPMENT DOCTRINE", "SWRPJoinMicro", 24, 22, UI.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("REQUIRED", "SWRPJoinMicro", width - 24, 22, UI.error, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		draw.SimpleText("CHOOSE A DIRECTION", "SWRPJoinTitle", 24, 55, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		local y = drawWrappedText("Every clone commits to one doctrine. Nodes in that tree cost 3 development credits instead of 4 — exactly 25% less.", "SWRPJoinBody", 24, 105, UI.text, width - 48, 22)
		y = y + 24
		surface.SetDrawColor(UI.line)
		surface.DrawRect(24, y, width - 48, 1)
		y = y + 24
		draw.SimpleText("THIS DOES NOT GRANT A ROLE", "SWRPJoinHeading", 24, y, UI.error, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = drawWrappedText("Medical, Heavy and Aviation remain locked behind their minimum service level, progression path and server training or certification.", "SWRPJoinBody", 24, y + 40, UI.text, width - 48, 22)
		y = y + 26
		draw.SimpleText("CROSS-TRAINING", "SWRPJoinSmall", 24, y, UI.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		drawWrappedText("Basic nodes in other trees remain available at their normal cost. Defining roles and capstones require the matching doctrine.", "SWRPJoinBody", 24, y + 28, UI.text, width - 48, 22)
	end
	self.doctrineGrid = self.doctrine:Add("Panel")
	for _, pathID in ipairs(SWRP.CareerPathOrder or {}) do
		local path = SWRP.GetCareerPath(pathID)
		if (path) then
			self.doctrineCards[#self.doctrineCards + 1] = makeDoctrineCard(self.doctrineGrid, path, function(id) self:SelectDoctrine(id) end)
		end
	end

	-- Step 3: small starting aptitude.
	self.aptitude = self:Add("Panel")
	self.aptitude:SetVisible(false)
	self.aptitudeIntro = self.aptitude:Add("Panel")
	self.aptitudeIntro.Paint = function(panel, width, height)
		surface.SetDrawColor(UI.panelLight)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		drawCorners(0, 0, width, height, UI.blueSoft, 22, 2)
		draw.SimpleText("INITIAL CONDITIONING", "SWRPJoinMicro", 22, 18, UI.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("REQUIRED", "SWRPJoinMicro", width - 22, 18, UI.error, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		draw.SimpleText("CHOOSE ONE BASELINE STRENGTH", "SWRPJoinTitle", 22, 47, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		drawWrappedText("This is a small immediate bonus, not a class. It gives the new character a distinct physical starting point while the full career tree remains in the datapad.", "SWRPJoinBody", 22, 94, UI.text, width - 44, 21)
	end
	self.aptitudeGrid = self.aptitude:Add("Panel")
	for _, aptitudeID in ipairs(SWRP.StartingAptitudeOrder or {}) do
		local aptitude = SWRP.GetStartingAptitude(aptitudeID)
		if (aptitude) then
			self.aptitudeCards[#self.aptitudeCards + 1] = makeAptitudeCard(self.aptitudeGrid, aptitude, function(id) self:SelectAptitude(id) end)
		end
	end
	self.attributePreview = self.aptitude:Add("Panel")
	self.attributePreview.values = {
		stamina = 0,
		endurance = 0,
		strength = 0
	}
	self.attributePreview.Paint = function(panel, width, height)
		local aptitude = SWRP.GetStartingAptitude(self.selectedAptitude)
		local selectedAttribute = aptitude and aptitude.attribute or ""
		local rows = {
			{"stamina", "STAMINA", Color(87, 190, 224)},
			{"endurance", "ENDURANCE", Color(92, 205, 176)},
			{"strength", "STRENGTH", Color(218, 162, 91)}
		}

		surface.SetDrawColor(Color(5, 11, 20, 238))
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		drawCorners(0, 0, width, height, UI.blueSoft, 16, 2)
		draw.SimpleText("STARTING ATTRIBUTE PREVIEW", "SWRPJoinMicro", 18, 13, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("The selected aptitude adds 10 points when this record is created.", "SWRPJoinSmall", width - 18, 13, UI.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

		local labelWidth = 112
		local valueWidth = 70
		local barX = 18 + labelWidth
		local barWidth = math.max(width - barX - valueWidth - 22, 80)
		local rowY = 42
		local rowGap = 29
		local lerpAmount = math.Clamp(FrameTime() * 10, 0, 1)

		for index, row in ipairs(rows) do
			local id, title, colour = row[1], row[2], row[3]
			local definition = ix.attributes and ix.attributes.list and ix.attributes.list[id]
			local configuredMaximum = tonumber(ix.config.Get("maxAttributes", 100)) or 100
			local maximum = math.max(tonumber(definition and definition.maxValue) or configuredMaximum, 10)
			local target = selectedAttribute == id and math.min(10, maximum) or 0
			panel.values[id] = Lerp(lerpAmount, panel.values[id] or 0, target)
			local value = panel.values[id]
			local y = rowY + (index - 1) * rowGap

			draw.SimpleText(title, "SWRPJoinSmall", 18, y, selectedAttribute == id and colour or UI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			surface.SetDrawColor(Color(255, 255, 255, 16))
			surface.DrawRect(barX, y - 5, barWidth, 10)
			surface.SetDrawColor(colour.r, colour.g, colour.b, selectedAttribute == id and 235 or 105)
			surface.DrawRect(barX, y - 5, barWidth * math.Clamp(value / maximum, 0, 1), 10)
			surface.SetDrawColor(colour.r, colour.g, colour.b, 80)
			surface.DrawOutlinedRect(barX, y - 5, barWidth, 10, 1)
			draw.SimpleText(string.format("%d / %d", math.Round(value), maximum), "SWRPJoinSmall", width - 18, y, selectedAttribute == id and colour or UI.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	self.confirmation = self.aptitude:Add("Panel")
	self.confirmation.Paint = function(panel, width, height)
		local path = SWRP.GetCareerPath(self.selectedPath)
		local aptitude = SWRP.GetStartingAptitude(self.selectedAptitude)
		local colour = path and path.colour or UI.blue
		surface.SetDrawColor(Color(5, 11, 20, 238))
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(colour.r, colour.g, colour.b, 105)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		drawCorners(0, 0, width, height, Color(colour.r, colour.g, colour.b, 130), 18, 2)
		draw.SimpleText("RECORD SUMMARY", "SWRPJoinMicro", 20, 16, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(self:GetDisplayName():upper(), "SWRPJoinHeading", 20, 45, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("DOCTRINE", "SWRPJoinMicro", width * 0.44, 18, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(path and path.title or "UNSELECTED", "SWRPJoinHeading", width * 0.44, 43, colour, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("STARTING APTITUDE", "SWRPJoinMicro", width * 0.72, 18, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(aptitude and aptitude.title or "UNSELECTED", "SWRPJoinHeading", width * 0.72, 43, aptitude and aptitude.colour or UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("All specialist roles must still be earned in service.", "SWRPJoinSmall", 20, height - 18, UI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	end

	self.backButton = makeButton(self, "RETURN", "", function()
		self:PreviousStep()
	end, "back")
	self.nextButton = makeButton(self, "CONTINUE", "Choose a development doctrine.", function()
		self:NextStep()
	end)

	net.Receive("ixCharacterAuthed", function()
		timer.Remove("ixCharacterCreateTimeout")
		if (!IsValid(self)) then return end
		self.awaitingResponse = false
		local id = net.ReadUInt(32)
		local indices = net.ReadUInt(6)
		local charList = {}
		for _ = 1, indices do charList[#charList + 1] = net.ReadUInt(32) end
		ix.characters = charList
		self:SlideDown()
		if (!IsValid(parent)) then return end
		if (LocalPlayer():GetCharacter()) then
			parent.mainPanel:Undim()
			parent:ShowNotice(2, L("charCreated"))
		elseif (id) then
			self.bMenuShouldClose = true
			net.Start("ixCharacterChoose")
				net.WriteUInt(id, 32)
			net.SendToServer()
		end
	end)

	net.Receive("ixCharacterAuthFailed", function()
		timer.Remove("ixCharacterCreateTimeout")
		if (!IsValid(self)) then return end
		self.awaitingResponse = false
		local fault = net.ReadString()
		local args = net.ReadTable()
		if (IsValid(parent)) then parent:ShowNotice(3, L(fault, unpack(args))) end
	end)
end

function CREATOR:GetDesignation()
	local value = ""
	for i = 1, 4 do value = value .. tostring(self.digitEntries[i]:GetValue() or ""):gsub("%D", ""):sub(1, 1) end
	return value
end

function CREATOR:SetDesignation(value)
	value = tostring(value or ""):gsub("%D", ""):sub(1, 4)
	for i = 1, 4 do
		local entry = self.digitEntries[i]
		entry.bUpdating = true
		entry:SetText(value:sub(i, i))
		entry.bUpdating = false
	end
	self:UpdateIdentityPreview()
end

function CREATOR:GetCallsign()
	local value = tostring(self.callsign:GetValue() or "")
	value = value:gsub("[^%w%s%-']", "")
	value = value:gsub("%s+", " ")
	return string.Trim(value):sub(1, 24)
end

function CREATOR:GetDisplayName()
	local number = self:GetDesignation()
	local callsign = self:GetCallsign()
	if (#number ~= 4) then number = "----" end
	if (callsign == "") then callsign = "UNASSIGNED" end
	return string.format("CT %s %s", number, callsign)
end

function CREATOR:UpdateIdentityPreview()
	if (IsValid(self.previewCard)) then self.previewCard:InvalidateLayout(false) end
	if (IsValid(self.identityModelFrame)) then self.identityModelFrame:InvalidateLayout(false) end
	if (IsValid(self.confirmation)) then self.confirmation:InvalidateLayout(false) end
end

function CREATOR:ValidateIdentity()
	local number = self:GetDesignation()
	local callsign = self:GetCallsign()
	if (#number ~= 4 or number == "0000") then
		self:GetParent():ShowNotice(3, L("cloneNumberInvalid"))
		return false
	end
	if (#callsign < 2 or #callsign > 24) then
		self:GetParent():ShowNotice(3, L("cloneCallsignInvalid"))
		return false
	end
	return true
end

function CREATOR:SelectDoctrine(pathID)
	if (!SWRP.IsCareerPath(pathID)) then return end
	self.selectedPath = pathID
	for _, card in ipairs(self.doctrineCards) do card.selected = card.path.id == pathID end
	if (IsValid(self.confirmation)) then self.confirmation:InvalidateLayout(false) end
	self:UpdateNavigationState()
end

function CREATOR:SelectAptitude(aptitudeID)
	if (!SWRP.IsStartingAptitude(aptitudeID)) then return end
	self.selectedAptitude = aptitudeID
	for _, card in ipairs(self.aptitudeCards) do card.selected = card.aptitude.id == aptitudeID end
	if (IsValid(self.confirmation)) then self.confirmation:InvalidateLayout(false) end
	self:UpdateNavigationState()
end

function CREATOR:UpdateNavigationState()
	if (!IsValid(self.nextButton)) then
		return
	end

	local enabled = true
	if (self.currentStep == 2) then
		enabled = SWRP.IsCareerPath(self.selectedPath)
	elseif (self.currentStep == 3) then
		enabled = SWRP.IsStartingAptitude(self.selectedAptitude)
	end

	self.nextButton:SetEnabled(enabled)
end

function CREATOR:SetStep(step)
	self.currentStep = math.Clamp(math.floor(tonumber(step) or 1), 1, 3)
	self.identity:SetVisible(self.currentStep == 1)
	self.doctrine:SetVisible(self.currentStep == 2)
	self.aptitude:SetVisible(self.currentStep == 3)
	local labels = {
		"01 / 03   IDENTIFICATION",
		"02 / 03   DEVELOPMENT DOCTRINE",
		"03 / 03   INITIAL CONDITIONING"
	}
	self.stepLabel:SetText(labels[self.currentStep])
	if (self.currentStep == 1) then
		self.backButton.title = "RETURN"
		self.backButton.subtitle = ""
		self.nextButton.title = "CONTINUE"
		self.nextButton.subtitle = "Choose a development doctrine."
	elseif (self.currentStep == 2) then
		self.backButton.title = "BACK"
		self.backButton.subtitle = ""
		self.nextButton.title = "CONTINUE"
		self.nextButton.subtitle = "Choose a starting physical aptitude."
	else
		self.backButton.title = "BACK"
		self.backButton.subtitle = ""
		self.nextButton.title = "CREATE RECORD"
		self.nextButton.subtitle = "Register this clone and deploy."
	end
	self.progress:InvalidateLayout(false)
	self:UpdateNavigationState()
end

function CREATOR:PreviousStep()
	if (self.currentStep <= 1) then
		self:SlideDown()
		self:GetParent().mainPanel:Undim()
	else
		self:SetStep(self.currentStep - 1)
	end
end

function CREATOR:NextStep()
	if (self.currentStep == 1) then
		if (self:ValidateIdentity()) then self:SetStep(2) end
	elseif (self.currentStep == 2) then
		if (self.selectedPath == "") then
			self:GetParent():ShowNotice(3, L("chooseDoctrine"))
			return
		end
		self:SetStep(3)
	else
		self:SendPayload()
	end
end

function CREATOR:ResetForm()
	self.awaitingResponse = false
	self.selectedPath = ""
	self.selectedAptitude = ""
	self.callsign:SetText("")
	self:SetDesignation(string.format("%04d", math.random(1, 9999)))
	for _, card in ipairs(self.doctrineCards) do card.selected = false end
	for _, card in ipairs(self.aptitudeCards) do card.selected = false end
	self:SetStep(1)
	self:UpdateNavigationState()
	local faction = getCloneFaction()
	local model = getFactionModel(faction)
	self.identityModel:SetModel(model)
	timer.Simple(0, function()
		if (IsValid(self) and IsValid(self.identityModel)) then
			frameModelPanel(self.identityModel, 1.05)
		end
	end)
end

function CREATOR:OnSlideUp()
	self:ResetForm()
end

function CREATOR:OnSlideDown()
end

function CREATOR:SendPayload()
	if (self.awaitingResponse) then return end
	if (!self:ValidateIdentity()) then self:SetStep(1) return end
	if (!SWRP.IsCareerPath(self.selectedPath)) then self:GetParent():ShowNotice(3, L("chooseDoctrine")) self:SetStep(2) return end
	if (!SWRP.IsStartingAptitude(self.selectedAptitude)) then self:GetParent():ShowNotice(3, L("chooseStartingAptitude")) return end

	local faction = getCloneFaction()
	if (!faction) then self:GetParent():ShowNotice(3, "No clone faction is available for character creation.") return end
	local number = self:GetDesignation()
	local callsign = self:GetCallsign()
	local payload = {
		faction = faction.index,
		model = 1,
		name = string.format("CT %s %s", number, callsign),
		description = "Grand Army clone personnel record.",
		cloneNumber = number,
		callsign = callsign,
		careerPath = self.selectedPath,
		careerTarget = "",
		startingAptitude = self.selectedAptitude,
		progressionCreditVersion = 1,
		upgradeTreeVersion = (SWRP.GetUpgradeTree() and SWRP.GetUpgradeTree().version) or 6
	}

	self.awaitingResponse = true
	playUISound("select")
	timer.Create("ixCharacterCreateTimeout", 10, 1, function()
		if (IsValid(self) and self.awaitingResponse) then
			self.awaitingResponse = false
			self:GetParent():ShowNotice(3, L("unknownError"))
		end
	end)

	net.Start("ixCharacterCreate")
		net.WriteUInt(table.Count(payload), 8)
		for key, value in pairs(payload) do
			net.WriteString(key)
			net.WriteType(value)
		end
	net.SendToServer()
end

function CREATOR:PerformLayout(width, height)
	local outerMargin = math.Clamp(width * 0.024, 28, 46)
	local pageWidth = math.min(width - outerMargin * 2, 1500)
	local pageX = math.floor((width - pageWidth) * 0.5)
	local headerHeight = math.Clamp(height * 0.078, 70, 84)
	local footerHeight = math.Clamp(height * 0.082, 72, 88)
	local contentY = headerHeight
	local availableHeight = height - headerHeight - footerHeight

	self.header:SetPos(pageX, 13)
	self.header:SizeToContents()
	self.headerSub:SetPos(pageX + 1, 13 + self.header:GetTall())
	self.headerSub:SizeToContents()
	self.stepLabel:SetPos(pageX + pageWidth - 330, 17)
	self.stepLabel:SetSize(330, 24)
	self.progress:SetPos(pageX, headerHeight - 7)
	self.progress:SetSize(pageWidth, 3)

	-- Identity is deliberately compact: the model is a preview, not the entire page.
	local identityHeight = math.min(availableHeight - 18, 700)
	local identityY = contentY + math.max((availableHeight - identityHeight) * 0.5, 0)
	self.identity:SetPos(pageX, identityY)
	self.identity:SetSize(pageWidth, identityHeight)
	local gap = 16
	local modelWidth = math.Clamp(pageWidth * 0.285, 360, 430)
	self.identityModelFrame:SetPos(0, 0)
	self.identityModelFrame:SetSize(modelWidth, identityHeight)
	self.identityModel:SetPos(16, 38)
	self.identityModel:SetSize(modelWidth - 32, identityHeight - 104)
	self.identityForm:SetPos(modelWidth + gap, 0)
	self.identityForm:SetSize(pageWidth - modelWidth - gap, identityHeight)

	local pad = 30
	local formWidth = self.identityForm:GetWide() - pad * 2
	self.designationTitle:SetPos(pad, 90)
	self.designationTitle:SizeToContents()
	self.designationHelp:SetPos(pad, 112)
	self.designationHelp:SizeToContents()
	local digitY = 144
	local digitSize = math.Clamp(identityHeight * 0.105, 58, 70)
	local digitGap = 9
	for i, entry in ipairs(self.digitEntries) do
		entry:SetPos(pad + (i - 1) * (digitSize + digitGap), digitY)
		entry:SetSize(digitSize, digitSize)
	end
	local randomX = pad + 4 * (digitSize + digitGap) + 10
	self.randomise:SetPos(randomX, digitY)
	self.randomise:SetSize(math.Clamp(formWidth - (randomX - pad), 185, 270), digitSize)

	local callsignY = digitY + digitSize + 30
	self.callsignTitle:SetPos(pad, callsignY)
	self.callsignTitle:SizeToContents()
	self.callsignHelp:SetPos(pad, callsignY + 22)
	self.callsignHelp:SizeToContents()
	self.callsign:SetPos(pad, callsignY + 49)
	self.callsign:SetSize(formWidth, 48)
	self.previewCard:SetPos(pad, callsignY + 112)
	self.previewCard:SetSize(formWidth, math.Clamp(identityHeight - callsignY - 142, 112, 150))

	-- Doctrine is a centred decision board, not a wall-to-wall dashboard.
	local doctrineHeight = math.min(availableHeight - 24, 690)
	local doctrineY = contentY + math.max((availableHeight - doctrineHeight) * 0.5, 0)
	self.doctrine:SetPos(pageX, doctrineY)
	self.doctrine:SetSize(pageWidth, doctrineHeight)
	local briefWidth = math.Clamp(pageWidth * 0.22, 280, 325)
	self.doctrineBrief:SetPos(0, 0)
	self.doctrineBrief:SetSize(briefWidth, doctrineHeight)
	self.doctrineGrid:SetPos(briefWidth + gap, 0)
	self.doctrineGrid:SetSize(pageWidth - briefWidth - gap, doctrineHeight)
	local gridGap = 12
	local cardWidth = (self.doctrineGrid:GetWide() - gridGap) * 0.5
	local cardHeight = (doctrineHeight - gridGap) * 0.5
	for index, card in ipairs(self.doctrineCards) do
		local col = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		card:SetPos(col * (cardWidth + gridGap), row * (cardHeight + gridGap))
		card:SetSize(cardWidth, cardHeight)
	end

	-- Conditioning uses only the space it needs; the old version left half the screen empty.
	local aptitudeHeight = math.min(availableHeight - 24, 650)
	local aptitudeY = contentY + math.max((availableHeight - aptitudeHeight) * 0.5, 0)
	self.aptitude:SetPos(pageX, aptitudeY)
	self.aptitude:SetSize(pageWidth, aptitudeHeight)
	local introHeight = 120
	self.aptitudeIntro:SetPos(0, 0)
	self.aptitudeIntro:SetSize(pageWidth, introHeight)
	self.aptitudeGrid:SetPos(0, introHeight + 12)
	local gridHeight = math.Clamp(aptitudeHeight * 0.31, 180, 205)
	self.aptitudeGrid:SetSize(pageWidth, gridHeight)
	local aptitudeGap = 12
	local aptitudeWidth = (pageWidth - aptitudeGap * 2) / 3
	for index, card in ipairs(self.aptitudeCards) do
		card:SetPos((index - 1) * (aptitudeWidth + aptitudeGap), 0)
		card:SetSize(aptitudeWidth, gridHeight)
	end
	local attributeY = introHeight + 12 + gridHeight + 12
	local attributeHeight = 132
	self.attributePreview:SetPos(0, attributeY)
	self.attributePreview:SetSize(pageWidth, attributeHeight)
	local confirmY = attributeY + attributeHeight + 12
	self.confirmation:SetPos(0, confirmY)
	self.confirmation:SetSize(pageWidth, aptitudeHeight - confirmY)

	self.backButton:SetPos(pageX, height - footerHeight + 9)
	self.backButton:SetSize(220, footerHeight - 18)
	self.nextButton:SetSize(290, footerHeight - 18)
	self.nextButton:SetPos(pageX + pageWidth - self.nextButton:GetWide(), height - footerHeight + 9)

	if (IsValid(self.identityModel.Entity)) then
		frameModelPanel(self.identityModel, 1.05)
	end
end
function CREATOR:Paint(width, height)
	paintRepublicBackdrop(self, width, height)
	surface.SetDrawColor(UI.line)
	surface.DrawRect(0, math.Clamp(height * 0.105, 82, 102) - 1, width, 1)
	BaseClass.Paint(self, width, height)
end

vgui.Register("swrpCharMenuNew", CREATOR, "ixCharMenuPanel")

-- =====================================================================================
-- Character load / service record
-- =====================================================================================

local LOAD = {}

function LOAD:Init()
	local parent = self:GetParent()
	self.character = nil
	self.characterButtons = {}

	self.header = makeLabel(self, "ACCESS SERVICE RECORD", "SWRPJoinTitle", UI.white)
	self.headerSub = makeLabel(self, "REPUBLIC PERSONNEL DATABASE // RETURNING PERSONNEL", "SWRPJoinSmall", UI.blue)

	self.listFrame = self:Add("Panel")
	self.listFrame.Paint = function(panel, width, height)
		surface.SetDrawColor(UI.panel)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		drawCorners(0, 0, width, height, UI.blueSoft, 18, 2)
		draw.SimpleText("PERSONNEL FILES", "SWRPJoinSmall", 18, 17, UI.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	self.characterList = self.listFrame:Add("DScrollPanel")
	self.characterList:GetVBar():SetWide(4)

	self.modelFrame = self:Add("Panel")
	self.modelFrame.Paint = function(panel, width, height)
		surface.SetDrawColor(Color(5, 9, 16, 225))
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		drawCorners(0, 0, width, height, UI.blueSoft, 18, 2)
	end

	self.model = self.modelFrame:Add("swrpJoinModelPanel")
	self.model:SetModel("models/error.mdl")
	self.model:SetFOV(50)

	self.record = self:Add("Panel")
	self.record.Paint = function(panel, width, height)
		surface.SetDrawColor(UI.panelLight)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		drawCorners(0, 0, width, height, UI.blueSoft, 18, 2)

		if (!self.character) then
			draw.SimpleText("NO PERSONNEL FILE SELECTED", "SWRPJoinHeading", width * 0.5, height * 0.5, UI.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return
		end

		local character = self.character
		local path = SWRP.GetCareerPath(safeValue(character, "GetCareerPath", ""))
		local aptitude = SWRP.GetStartingAptitude and SWRP.GetStartingAptitude(safeValue(character, "GetStartingAptitude", "")) or nil
		local unlocked, total = getCareerProgress(character)
		local level = math.max(tonumber(safeValue(character, "GetLevel", 1)) or 1, 1)
		local xp = math.max(tonumber(safeValue(character, "GetXp", 0)) or 0, 0)
		local credits = math.max(tonumber(safeValue(character, "GetSkillPoints", 0)) or 0, 0)
		local requirement = SWRP.Datapad and SWRP.Datapad.GetXPRequirement and SWRP.Datapad.GetXPRequirement(character, level) or 1000
		local progress = requirement > 0 and math.Clamp(xp / requirement, 0, 1) or 0
		local training = safeValue(character, "GetTrainingCompleted", false) and "TRAINED" or "UNTRAINED"
		local colour = path and path.colour or UI.blue
		local y = 22

		draw.SimpleText("ACTIVE PERSONNEL FILE", "SWRPJoinMicro", 22, y, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 27
		draw.SimpleText(fitText(character:GetName():upper(), "SWRPJoinTitle", width - 44), "SWRPJoinTitle", 22, y, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 45
		draw.SimpleText(getCharacterRole(character):upper(), "SWRPJoinHeading", 22, y, colour, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 40

		surface.SetDrawColor(UI.line)
		surface.DrawRect(22, y, width - 44, 1)
		y = y + 20
		draw.SimpleText("DEVELOPMENT DOCTRINE", "SWRPJoinMicro", 22, y, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 24
		draw.SimpleText(path and path.fullTitle or "UNASSIGNED", "SWRPJoinHeading", 22, y, colour, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 34
		draw.SimpleText("3 CREDITS IN DOCTRINE  //  4 OUTSIDE", "SWRPJoinSmall", 22, y, UI.success, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 30
		local accessText = path and (level >= (path.minimumLevel or 1) and "TREE ACCESS ACTIVE" or ("TREE OPENS AT LEVEL " .. tostring(path.minimumLevel or 1))) or "NO DOCTRINE ASSIGNED"
		draw.SimpleText(accessText, "SWRPJoinSmall", 22, y, level >= (path and path.minimumLevel or 1) and UI.white or UI.error, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 42

		local rank = safeValue(character, "GetRank", "CT")
		local regiment = safeValue(character, "GetRegiment", "Unassigned")
		local rows = {
			{"RANK", tostring(rank):upper(), UI.white},
			{"REGIMENT", tostring(regiment):upper(), UI.white},
			{"TRAINING", training, training == "TRAINED" and UI.success or UI.error},
			{"STARTING APTITUDE", aptitude and aptitude.title or "LEGACY RECORD", aptitude and aptitude.colour or UI.muted}
		}
		for _, row in ipairs(rows) do
			draw.SimpleText(row[1], "SWRPJoinMicro", 22, y, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(row[2], "SWRPJoinBody", width * 0.48, y, row[3], TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			y = y + 29
		end
		y = y + 10

		surface.SetDrawColor(UI.line)
		surface.DrawRect(22, y, width - 44, 1)
		y = y + 20
		draw.SimpleText("DOCTRINE PROGRESS", "SWRPJoinMicro", 22, y, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(string.format("%d / %d NODES", unlocked, total), "SWRPJoinSmall", width - 22, y, UI.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		y = y + 30
		draw.SimpleText(string.format("LEVEL %d", level), "SWRPJoinHeading", 22, y, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(string.format("%d DEVELOPMENT CREDITS", credits), "SWRPJoinSmall", width - 22, y + 5, colour, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		y = y + 38
		draw.SimpleText(string.format("%d / %d XP", xp, requirement), "SWRPJoinMicro", width - 22, y, UI.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		surface.SetDrawColor(Color(255, 255, 255, 18))
		surface.DrawRect(22, y + 19, width - 44, 9)
		surface.SetDrawColor(colour)
		surface.DrawRect(22, y + 19, (width - 44) * progress, 9)
	end
	self.backButton = makeButton(self, "RETURN", "", function()
		self:SlideDown()
		parent.mainPanel:Undim()
	end, "back")

	self.deleteButton = makeButton(self, "DELETE RECORD", "Permanently delete this record.", function()
		if (self.character) then
			self.deleteOverlay:SetVisible(true)
			self.deleteOverlay:MoveToFront()
		end
	end, "back")

	self.deployButton = makeButton(self, "DEPLOY", "Enter the server as this character.", function()
		if (!self.character) then
			return
		end

		self:SlideDown(0.5, function()
			net.Start("ixCharacterChoose")
				net.WriteUInt(self.character:GetID(), 32)
			net.SendToServer()
		end, true)
	end)

	self.deleteOverlay = self:Add("Panel")
	self.deleteOverlay:SetVisible(false)
	self.deleteOverlay.Paint = function(panel, width, height)
		surface.SetDrawColor(0, 0, 0, 235)
		surface.DrawRect(0, 0, width, height)

		local boxWidth = math.Clamp(width * 0.42, 520, 700)
		local boxHeight = 260
		local x = width * 0.5 - boxWidth * 0.5
		local y = height * 0.5 - boxHeight * 0.5
		surface.SetDrawColor(UI.panelLight)
		surface.DrawRect(x, y, boxWidth, boxHeight)
		surface.SetDrawColor(UI.error)
		surface.DrawOutlinedRect(x, y, boxWidth, boxHeight, 2)
		drawCorners(x, y, boxWidth, boxHeight, UI.error, 22, 2)
		draw.SimpleText("DELETE PERSONNEL RECORD?", "SWRPJoinTitle", x + 28, y + 28, UI.error, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		drawWrappedText("This action is permanent. Rank, qualifications and progression attached to this character will be lost.", "SWRPJoinBody", x + 28, y + 85, UI.text, boxWidth - 56, 22)
	end

	self.cancelDelete = makeButton(self.deleteOverlay, "CANCEL", "", function()
		self.deleteOverlay:SetVisible(false)
	end, "back")

	self.confirmDelete = makeButton(self.deleteOverlay, "DELETE PERMANENTLY", "", function()
		if (!self.character) then
			return
		end

		local id = self.character:GetID()
		parent:ShowNotice(1, L("deleteComplete", self.character:GetName()))
		self.deleteOverlay:SetVisible(false)
		self:Populate(id)

		net.Start("ixCharacterDelete")
			net.WriteUInt(id, 32)
		net.SendToServer()
	end, "back")
end

function LOAD:SetCharacter(character)
	self.character = character

	if (character) then
		applyCharacterModel(self.model, character)
	end

	for _, button in ipairs(self.characterButtons) do
		button.selected = button.character == character
	end
end

function LOAD:Populate(ignoreID)
	self.characterList:Clear()
	self.characterButtons = {}
	local selected

	for _, id in ipairs(ix.characters or {}) do
		local character = ix.char.loaded[id]

		if (!character or character:GetID() == ignoreID) then
			continue
		end

		local button = self.characterList:Add("DButton")
		button:Dock(TOP)
		button:DockMargin(0, 0, 0, 8)
		button:SetTall(82)
		button:SetText("")
		button:SetCursor("hand")
		button.character = character

		button.OnCursorEntered = function()
			playUISound("hover")
		end

		button.DoClick = function(this)
			playUISound("select")
			self:SetCharacter(this.character)
		end

		button.Paint = function(this, width, height)
			local active = this.selected
			local hovered = this:IsHovered()
			local path = SWRP.GetCareerPath(safeValue(this.character, "GetCareerPath", ""))
			local colour = path and path.colour or UI.blue

			surface.SetDrawColor(active and Color(colour.r, colour.g, colour.b, 35) or (hovered and Color(20, 33, 50, 245) or Color(8, 14, 23, 230)))
			surface.DrawRect(0, 0, width, height)
			surface.SetDrawColor(colour.r, colour.g, colour.b, active and 255 or (hovered and 160 or 70))
			surface.DrawRect(0, 0, active and 5 or 2, height)
			surface.DrawOutlinedRect(0, 0, width, height, active and 2 or 1)

			draw.SimpleText(this.character:GetName():upper(), "SWRPJoinHeading", 16, 14, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(getCharacterRole(this.character):upper(), "SWRPJoinSmall", 16, height - 16, colour, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		end

		self.characterButtons[#self.characterButtons + 1] = button

		local localCharacter = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()
		if (localCharacter and localCharacter:GetID() == character:GetID()) then
			selected = character
		end
	end

	selected = selected or (self.characterButtons[1] and self.characterButtons[1].character)
	self:SetCharacter(selected)

	if (!selected and self.bActive) then
		self:SlideDown()
		self:GetParent().mainPanel:Undim()
	end
end

function LOAD:OnCharacterDeleted()
	if (self.bActive and #ix.characters == 0) then
		self:SlideDown()
	end
end

function LOAD:OnSlideUp()
	self.bActive = true
	self.deleteOverlay:SetVisible(false)
	self:Populate()
end

function LOAD:OnSlideDown()
	self.bActive = false
end

function LOAD:PerformLayout(width, height)
	local outerMargin = math.Clamp(width * 0.024, 28, 46)
	local pageWidth = math.min(width - outerMargin * 2, 1420)
	local pageX = math.floor((width - pageWidth) * 0.5)
	local headerHeight = math.Clamp(height * 0.078, 70, 84)
	local footerHeight = math.Clamp(height * 0.082, 72, 88)
	local availableHeight = height - headerHeight - footerHeight
	local contentHeight = math.min(availableHeight - 18, 760)
	local contentY = headerHeight + math.max((availableHeight - contentHeight) * 0.5, 0)
	local gap = 14
	local listWidth = math.Clamp(pageWidth * 0.215, 285, 320)
	local recordWidth = math.Clamp(pageWidth * 0.295, 390, 430)
	local modelWidth = pageWidth - listWidth - recordWidth - gap * 2

	self.header:SetPos(pageX, 13)
	self.header:SizeToContents()
	self.headerSub:SetPos(pageX + 1, 13 + self.header:GetTall())
	self.headerSub:SizeToContents()

	self.listFrame:SetPos(pageX, contentY)
	self.listFrame:SetSize(listWidth, contentHeight)
	self.characterList:SetPos(12, 48)
	self.characterList:SetSize(listWidth - 24, contentHeight - 60)

	self.modelFrame:SetPos(pageX + listWidth + gap, contentY)
	self.modelFrame:SetSize(modelWidth, contentHeight)
	self.model:SetPos(18, 18)
	self.model:SetSize(modelWidth - 36, contentHeight - 36)

	self.record:SetPos(pageX + pageWidth - recordWidth, contentY)
	self.record:SetSize(recordWidth, contentHeight)

	self.backButton:SetPos(pageX, height - footerHeight + 9)
	self.backButton:SetSize(210, footerHeight - 18)
	self.deployButton:SetSize(260, footerHeight - 18)
	self.deployButton:SetPos(pageX + pageWidth - 260, height - footerHeight + 9)
	self.deleteButton:SetSize(230, footerHeight - 18)
	self.deleteButton:SetPos(self.deployButton:GetX() - 230 - 10, height - footerHeight + 9)

	self.deleteOverlay:SetPos(0, 0)
	self.deleteOverlay:SetSize(width, height)
	local boxWidth = math.Clamp(width * 0.38, 500, 650)
	local boxHeight = 240
	local boxX = width * 0.5 - boxWidth * 0.5
	local boxY = height * 0.5 - boxHeight * 0.5
	self.cancelDelete:SetPos(boxX + 26, boxY + boxHeight - 70)
	self.cancelDelete:SetSize(180, 44)
	self.confirmDelete:SetPos(boxX + boxWidth - 256, boxY + boxHeight - 70)
	self.confirmDelete:SetSize(230, 44)

	if (IsValid(self.model.Entity)) then
		frameModelPanel(self.model, 1.34)
	end
end
function LOAD:Paint(width, height)
	paintRepublicBackdrop(self, width, height)
	surface.SetDrawColor(UI.line)
	surface.DrawRect(0, math.Clamp(height * 0.12, 76, 102) - 1, width, 1)

	-- See CREATOR:Paint above: these children are manually painted by Helix's
	-- ixSubpanelParent implementation.
	BaseClass.Paint(self, width, height)
end

vgui.Register("swrpCharMenuLoad", LOAD, "ixCharMenuPanel")

-- =====================================================================================
-- Swap the stock Helix panels after the container has been created.
-- =====================================================================================

function PLUGIN:OnCharacterMenuCreated(menu)
	if (!IsValid(menu)) then
		return
	end

	if (IsValid(menu.mainPanel)) then
		menu.mainPanel:Remove()
	end

	if (IsValid(menu.newCharacterPanel)) then
		menu.newCharacterPanel:Remove()
	end

	if (IsValid(menu.loadCharacterPanel)) then
		menu.loadCharacterPanel:Remove()
	end

	menu.mainPanel = menu:Add("swrpCharMenuMain")
	menu.newCharacterPanel = menu:Add("swrpCharMenuNew")
	menu.loadCharacterPanel = menu:Add("swrpCharMenuLoad")

	for _, panel in ipairs({menu.mainPanel, menu.newCharacterPanel, menu.loadCharacterPanel}) do
		panel:SetSize(menu:GetSize())
		panel:SetPos(0, 0)
		panel:InvalidateLayout(true)
	end

	menu.newCharacterPanel:SlideDown(0)
	menu.loadCharacterPanel:SlideDown(0)

	menu.mainPanel:SetZPos(0)
	menu.newCharacterPanel:SetZPos(5)
	menu.loadCharacterPanel:SetZPos(5)

	if (IsValid(menu.notice)) then
		menu.notice:SetZPos(20)
		menu.notice:MoveToFront()
	end
end
