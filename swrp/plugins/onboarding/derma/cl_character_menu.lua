-- swrp/plugins/onboarding/derma/cl_character_menu.lua
-- Complete Republic/Battlefront-inspired replacement for the Helix join, creation and load screens.

SWRP = SWRP or {}
SWRP.JoinMenuVersion = "3.0.1"

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

surface.CreateFont("SWRPJoinHero", {
	font = "Roboto",
	size = math.max(ScreenScale(22), 34),
	weight = 300,
	extended = true
})

surface.CreateFont("SWRPJoinTitle", {
	font = "Roboto",
	size = math.max(ScreenScale(15), 25),
	weight = 400,
	extended = true
})

surface.CreateFont("SWRPJoinHeading", {
	font = "Roboto Medium",
	size = math.max(ScreenScale(10), 18),
	weight = 500,
	extended = true
})

surface.CreateFont("SWRPJoinBody", {
	font = "Roboto",
	size = math.max(ScreenScale(8), 15),
	weight = 400,
	extended = true
})

surface.CreateFont("SWRPJoinSmall", {
	font = "Roboto",
	size = math.max(ScreenScale(6), 12),
	weight = 500,
	extended = true
})

surface.CreateFont("SWRPJoinMicro", {
	font = "Roboto",
	size = math.max(ScreenScale(5), 10),
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

		draw.SimpleText(this.title, "SWRPJoinHeading", 20, this.subtitle ~= "" and 14 or height * 0.5, Color(UI.white.r, UI.white.g, UI.white.b, alpha), TEXT_ALIGN_LEFT, this.subtitle ~= "" and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)

		if (this.subtitle ~= "") then
			draw.SimpleText(this.subtitle, "SWRPJoinSmall", 20, height - 15, Color(UI.text.r, UI.text.g, UI.text.b, alpha * 0.75), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
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

local function fitText(text, font, maxWidth)
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

local function applyCharacterModel(panel, character)
	if (!IsValid(panel) or !character) then
		return
	end

	panel:SetModel(character:GetModel())
	panel:SetSkin(character:GetData("skin", 0))

	local entity = panel.Entity

	if (!IsValid(entity)) then
		return
	end

	for i = 0, entity:GetNumBodyGroups() - 1 do
		entity:SetBodygroup(i, 0)
	end

	for group, value in pairs(character:GetData("groups", {}) or {}) do
		entity:SetBodygroup(tonumber(group) or 0, tonumber(value) or 0)
	end
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

	self.menu = self:Add("Panel")
	self.menu:SetZPos(-10)
	self.menu.Paint = function(panel, width, height)
		surface.SetDrawColor(Color(4, 9, 16, 220))
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawRect(width - 1, 0, 1, height)
	end

	self.createButton = makeButton(self.menu, "CREATE PERSONNEL RECORD", "Register a new clone identity and choose a career target.", function()
		local maximum = hook.Run("GetMaxPlayerCharacter", LocalPlayer()) or ix.config.Get("maxCharacters", 5)

		if (#ix.characters >= maximum) then
			self:GetParent():ShowNotice(3, L("maxCharacters"))
			return
		end

		self:Dim()
		self:GetParent().newCharacterPanel:SlideUp()
	end)

	self.loadButton = makeButton(self.menu, "ACCESS SERVICE RECORD", "Review a character, current role and tracked progression.", function()
		self:Dim()
		self:GetParent().loadCharacterPanel:SlideUp()
	end)
	self.loadButton:SetEnabled(#ix.characters > 0)

	local communityURL = ix.config.Get("communityURL", "")
	self.communityButton = makeButton(self.menu, "COMMUNITY UPLINK", "Open the server community and operational channels.", function()
		if (communityURL ~= "") then
			gui.OpenURL(communityURL)
		end
	end)
	self.communityButton:SetEnabled(communityURL ~= "")

	self.returnButton = makeButton(self.menu, "DISCONNECT", "Terminate the current Republic network session.", function()
		if (self.bUsingCharacter) then
			self:GetParent():Close()
		else
			RunConsoleCommand("disconnect")
		end
	end, "back")

	self.buttons = {self.createButton, self.loadButton, self.communityButton, self.returnButton}

	self.operation = self:Add("Panel")
	self.operation.Paint = function(panel, width, height)
		surface.SetDrawColor(UI.panel)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		drawCorners(0, 0, width, height, UI.blueSoft, 18, 2)

		local personnelWidth = 142
		local dividerX = width - personnelWidth - 18
		local deploymentWidth = dividerX - 44

		draw.SimpleText("CURRENT DEPLOYMENT", "SWRPJoinSmall", 22, 20, UI.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(fitText(getDeploymentName(), "SWRPJoinHeading", deploymentWidth), "SWRPJoinHeading", 22, 50, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("Personnel awaiting assignment", "SWRPJoinSmall", 22, 86, UI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		surface.SetDrawColor(UI.line)
		surface.DrawRect(dividerX, 18, 1, height - 36)

		local online = #player.GetAll()
		draw.SimpleText(string.format("%02d", online), "SWRPJoinHero", width - 24, 22, UI.white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		draw.SimpleText("PERSONNEL ONLINE", "SWRPJoinMicro", width - 24, 84, UI.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end
end

function MAIN:UpdateReturnButton(value)
	if (value ~= nil) then
		self.bUsingCharacter = value
	end

	if (!IsValid(self.returnButton)) then
		return
	end

	if (self.bUsingCharacter) then
		self.returnButton.title = "RETURN TO DEPLOYMENT"
		self.returnButton.subtitle = "Close the personnel network and resume active duty."
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
	local margin = math.max(ScreenScale(18), 34)
	local menuWidth = math.Clamp(width * 0.34, 430, 610)
	local top = math.Clamp(height * 0.13, 82, 130)

	self.brand:SetPos(margin, top)
	self.brand:SizeToContents()
	self.brandSub:SetPos(margin + 2, top + self.brand:GetTall() + 4)
	self.brandSub:SizeToContents()
	self.connection:SetPos(width - margin - 280, top + 7)
	self.connection:SetSize(280, 24)

	self.menu:SetPos(0, 0)
	self.menu:SetSize(menuWidth, height)

	local buttonX = margin
	local buttonY = top + self.brand:GetTall() + self.brandSub:GetTall() + 64
	local buttonWidth = menuWidth - margin * 1.35
	local buttonHeight = math.Clamp(height * 0.105, 76, 96)
	local gap = 10

	for index, button in ipairs(self.buttons) do
		button:SetPos(buttonX, buttonY + (index - 1) * (buttonHeight + gap))
		button:SetSize(buttonWidth, buttonHeight)
	end

	self.operation:SetSize(math.Clamp(width * 0.34, 450, 610), 128)
	self.operation:SetPos(width - self.operation:GetWide() - margin, height - self.operation:GetTall() - margin)
end

function MAIN:Paint(width, height)
	paintRepublicBackdrop(self, width, height)

	local beamX = width * 0.61
	surface.SetDrawColor(UI.blue.r, UI.blue.g, UI.blue.b, 9)
	draw.NoTexture()
	surface.DrawPoly({
		{x = beamX - 180, y = 0},
		{x = beamX + 40, y = 0},
		{x = beamX + 330, y = height},
		{x = beamX + 40, y = height}
	})

	BaseClass.Paint(self, width, height)
end

vgui.Register("swrpCharMenuMain", MAIN, "ixCharMenuPanel")

-- =====================================================================================
-- Character creator
-- =====================================================================================

local CREATOR = {}

function CREATOR:Init()
	local parent = self:GetParent()
	self.awaitingResponse = false
	self.currentStep = 1
	self.selectedTarget = ""
	self.selectedPath = ""
	self.digitEntries = {}
	self.branchButtons = {}

	self.header = makeLabel(self, "CREATE PERSONNEL RECORD", "SWRPJoinTitle", UI.white)
	self.headerSub = makeLabel(self, "REPUBLIC PERSONNEL DATABASE // NEW ENTRY", "SWRPJoinSmall", UI.blue)
	self.stepLabel = makeLabel(self, "01  IDENTIFICATION", "SWRPJoinSmall", UI.white, 6)

	self.identity = self:Add("Panel")
	self.identity.Paint = function(panel, width, height)
		surface.SetDrawColor(Color(4, 8, 15, 120))
		surface.DrawRect(0, 0, width, height)
	end

	self.identityModelFrame = self.identity:Add("Panel")
	self.identityModelFrame.Paint = function(panel, width, height)
		surface.SetDrawColor(UI.panel)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		drawCorners(0, 0, width, height, UI.blueSoft, 20, 2)
		draw.SimpleText("LIVE PERSONNEL PREVIEW", "SWRPJoinMicro", 16, 14, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	self.identityModel = self.identityModelFrame:Add("ixModelPanel")
	self.identityModel:SetModel("models/error.mdl")
	self.identityModel:SetFOV((ScrW() > ScrH() * 1.8) and 78 or 68)
	self.identityModel.PaintModel = self.identityModel.Paint

	self.identityForm = self.identity:Add("Panel")
	self.identityForm.Paint = function(panel, width, height)
		surface.SetDrawColor(UI.panelLight)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		drawCorners(0, 0, width, height, UI.blueSoft, 20, 2)
	end

	self.designationTitle = makeLabel(self.identityForm, "CLONE DESIGNATION", "SWRPJoinSmall", UI.blue)
	self.designationHelp = makeLabel(self.identityForm, "Choose the four digits that will identify this character.", "SWRPJoinSmall", UI.muted)

	for i = 1, 4 do
		local entry = makeTextEntry(self.identityForm, "0")
		entry:SetFont("SWRPJoinHero")
		entry:SetContentAlignment(5)
		entry:SetNumeric(true)
		entry.digitIndex = i
		entry.bUpdating = false

		entry.OnGetFocus = function(this)
			this:SelectAllText()
		end

		entry.OnTextChanged = function(this)
			if (this.bUpdating) then
				return
			end

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

			if (#clean > 0 and this.digitIndex < 4) then
				self.digitEntries[this.digitIndex + 1]:RequestFocus()
			end

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

			if (oldKeyTyped) then
				oldKeyTyped(this, code)
			end
		end

		self.digitEntries[i] = entry
	end

	self.randomise = makeButton(self.identityForm, "RANDOMISE", "", function()
		self:SetDesignation(string.format("%04d", math.random(1, 9999)))
	end)

	self.callsignTitle = makeLabel(self.identityForm, "NAME / CALLSIGN", "SWRPJoinSmall", UI.blue)
	self.callsignHelp = makeLabel(self.identityForm, "This is the name other players will know your clone by.", "SWRPJoinSmall", UI.muted)
	self.callsign = makeTextEntry(self.identityForm, "Example: Sam, Sparrow, Atlas")
	self.callsign:SetMaximumCharCount(24)
	self.callsign.OnValueChange = function()
		self:UpdateIdentityPreview()
	end

	self.previewCard = self.identityForm:Add("Panel")
	self.previewCard.Paint = function(panel, width, height)
		surface.SetDrawColor(Color(6, 12, 21, 230))
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		draw.SimpleText("RECORD PREVIEW", "SWRPJoinMicro", 15, 12, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(self:GetDisplayName():upper(), "SWRPJoinTitle", 15, height * 0.56, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	self.identityBack = makeButton(self, "RETURN", "", function()
		self:SlideDown()
		parent.mainPanel:Undim()
	end, "back")

	self.identityContinue = makeButton(self, "CONTINUE", "Choose a career target for this character.", function()
		if (self:ValidateIdentity()) then
			self:SetStep(2)
		end
	end)

	-- career step
	self.career = self:Add("Panel")
	self.career:SetVisible(false)

	self.branchBar = self.career:Add("Panel")
	self.branchBar.Paint = function(panel, width, height)
		surface.SetDrawColor(Color(5, 10, 18, 235))
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(UI.line)
		surface.DrawRect(0, height - 1, width, 1)
	end

	for _, pathID in ipairs(SWRP.CareerPathOrder or {}) do
		local path = SWRP.GetCareerPath(pathID)
		local button = makeButton(self.branchBar, path and path.title or pathID:upper(), "", function(this)
			self:SelectBranch(this.pathID)
		end)
		button.pathID = pathID
		self.branchButtons[#self.branchButtons + 1] = button
	end

	self.tree = self.career:Add("swrpCareerTree")
	self.tree.OnTargetSelected = function(panel, node)
		self.selectedTarget = node.id
		self.selectedPath = node.branch
		self:UpdateTargetCard(node)
	end

	self.targetCard = self.career:Add("Panel")
	self.targetCard.Paint = function(panel, width, height)
		local node = SWRP.GetCareerTarget(self.selectedTarget)
		local path = node and SWRP.GetCareerPath(node.branch)
		local colour = path and path.colour or UI.blue

		surface.SetDrawColor(UI.panelLight)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(colour.r, colour.g, colour.b, node and 150 or 60)
		surface.DrawOutlinedRect(0, 0, width, height, node and 2 or 1)
		drawCorners(0, 0, width, height, Color(colour.r, colour.g, colour.b, 140), 18, 2)

		draw.SimpleText("TRACKED CAREER TARGET", "SWRPJoinMicro", 18, 18, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		if (!node) then
			draw.SimpleText("SELECT A NODE", "SWRPJoinHeading", 18, 52, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			drawWrappedText("Choose the qualification or role your clone wants to work towards.", "SWRPJoinBody", 18, 86, UI.text, width - 36, 20)
			return
		end

		draw.SimpleText(string.upper(getCareerNodeTitle(node)), "SWRPJoinHeading", 18, 50, colour, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		drawWrappedText(node.description or "", "SWRPJoinBody", 18, 84, UI.text, width - 36, 20)
		draw.SimpleText(node.effect or "", "SWRPJoinSmall", 18, height - 58, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		draw.SimpleText("GOAL ONLY — THIS DOES NOT UNLOCK THE QUALIFICATION", "SWRPJoinMicro", 18, height - 24, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	end

	self.careerBack = makeButton(self, "BACK", "Return to identification.", function()
		self:SetStep(1)
	end, "back")

	self.createRecord = makeButton(self, "CREATE RECORD", "Register this clone and deploy.", function()
		self:SendPayload()
	end)

	net.Receive("ixCharacterAuthed", function()
		timer.Remove("ixCharacterCreateTimeout")

		if (!IsValid(self)) then
			return
		end

		self.awaitingResponse = false
		local id = net.ReadUInt(32)
		local indices = net.ReadUInt(6)
		local charList = {}

		for _ = 1, indices do
			charList[#charList + 1] = net.ReadUInt(32)
		end

		ix.characters = charList
		self:SlideDown()

		if (!IsValid(parent)) then
			return
		end

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

		if (!IsValid(self)) then
			return
		end

		self.awaitingResponse = false
		local fault = net.ReadString()
		local args = net.ReadTable()
		if (IsValid(parent)) then
			parent:ShowNotice(3, L(fault, unpack(args)))
		end
	end)
end

function CREATOR:GetDesignation()
	local value = ""

	for i = 1, 4 do
		value = value .. tostring(self.digitEntries[i]:GetValue() or ""):gsub("%D", ""):sub(1, 1)
	end

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

	if (#number ~= 4) then
		number = "----"
	end

	if (callsign == "") then
		callsign = "UNASSIGNED"
	end

	return string.format("CT %s %s", number, callsign)
end

function CREATOR:UpdateIdentityPreview()
	if (IsValid(self.previewCard)) then
		self.previewCard:InvalidateLayout(false)
	end
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

function CREATOR:SelectBranch(pathID)
	local branch = SWRP.GetCareerBranch(pathID)

	if (!branch) then
		self:GetParent():ShowNotice(3, "The progression tree has not loaded yet.")
		return
	end

	if (self.selectedPath ~= "" and self.selectedPath ~= pathID) then
		self.selectedTarget = ""
		self.selectedPath = ""
		self:UpdateTargetCard(nil)
	end

	self.activeBranch = pathID
	self.tree:SetBranch(branch)
	self.tree:SetSelectedTarget(self.selectedTarget)

	for _, button in ipairs(self.branchButtons) do
		button.active = button.pathID == pathID
	end
end

function CREATOR:UpdateTargetCard(node)
	self.tree:SetSelectedTarget(node and node.id or "")
	self.targetCard:InvalidateLayout(false)
end

function CREATOR:SetStep(step)
	self.currentStep = step
	local identity = step == 1
	self.identity:SetVisible(identity)
	self.identityBack:SetVisible(identity)
	self.identityContinue:SetVisible(identity)
	self.career:SetVisible(!identity)
	self.careerBack:SetVisible(!identity)
	self.createRecord:SetVisible(!identity)
	self.stepLabel:SetText(identity and "01  IDENTIFICATION" or "02  CAREER TARGET")
	self.stepLabel:InvalidateLayout(true)

	if (!identity and !self.activeBranch) then
		self:SelectBranch("conditioning")
	end
end

function CREATOR:ResetForm()
	self.awaitingResponse = false
	self.selectedTarget = ""
	self.selectedPath = ""
	self.activeBranch = nil
	self.callsign:SetText("")
	self:SetDesignation(string.format("%04d", math.random(1, 9999)))
	self.tree:SetSelectedTarget("")
	self:UpdateTargetCard(nil)
	self:SetStep(1)

	local faction = getCloneFaction()
	local model = getFactionModel(faction)
	self.identityModel:SetModel(model)
end

function CREATOR:OnSlideUp()
	self:ResetForm()
end

function CREATOR:OnSlideDown()
end

function CREATOR:SendPayload()
	if (self.awaitingResponse) then
		return
	end

	if (!self:ValidateIdentity()) then
		self:SetStep(1)
		return
	end

	local node = SWRP.GetCareerTarget(self.selectedTarget)

	if (!node) then
		self:GetParent():ShowNotice(3, L("chooseCareerTarget"))
		return
	end

	local faction = getCloneFaction()

	if (!faction) then
		self:GetParent():ShowNotice(3, "No clone faction is available for character creation.")
		return
	end

	local number = self:GetDesignation()
	local callsign = self:GetCallsign()
	local payload = {
		faction = faction.index,
		model = 1,
		name = string.format("CT %s %s", number, callsign),
		description = "Grand Army clone personnel record.",
		cloneNumber = number,
		callsign = callsign,
		careerPath = node.branch,
		careerTarget = node.id
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
	local margin = math.max(ScreenScale(16), 28)
	local headerHeight = math.Clamp(height * 0.12, 76, 102)
	local footerHeight = math.Clamp(height * 0.11, 72, 96)

	self.header:SetPos(margin, 22)
	self.header:SizeToContents()
	self.headerSub:SetPos(margin + 2, 22 + self.header:GetTall() + 3)
	self.headerSub:SizeToContents()
	self.stepLabel:SetPos(width - margin - 260, 30)
	self.stepLabel:SetSize(260, 28)

	local contentY = headerHeight
	local contentHeight = height - headerHeight - footerHeight

	self.identity:SetPos(margin, contentY)
	self.identity:SetSize(width - margin * 2, contentHeight)

	local gap = math.max(ScreenScale(8), 16)
	local modelWidth = math.Clamp(self.identity:GetWide() * 0.36, 390, 560)
	self.identityModelFrame:SetPos(0, 0)
	self.identityModelFrame:SetSize(modelWidth, contentHeight)
	self.identityModel:SetPos(8, 34)
	self.identityModel:SetSize(modelWidth - 16, contentHeight - 42)
	self.identityForm:SetPos(modelWidth + gap, 0)
	self.identityForm:SetSize(self.identity:GetWide() - modelWidth - gap, contentHeight)

	local formPad = 28
	local formWidth = self.identityForm:GetWide() - formPad * 2
	self.designationTitle:SetPos(formPad, 28)
	self.designationTitle:SizeToContents()
	self.designationHelp:SetPos(formPad, 52)
	self.designationHelp:SizeToContents()

	local digitY = 86
	local digitSize = math.Clamp(contentHeight * 0.105, 58, 76)
	local digitGap = 10
	for i, entry in ipairs(self.digitEntries) do
		entry:SetPos(formPad + (i - 1) * (digitSize + digitGap), digitY)
		entry:SetSize(digitSize, digitSize)
	end

	self.randomise:SetPos(formPad + 4 * (digitSize + digitGap) + 8, digitY)
	self.randomise:SetSize(math.Clamp(formWidth * 0.25, 150, 210), digitSize)

	local callsignY = digitY + digitSize + 42
	self.callsignTitle:SetPos(formPad, callsignY)
	self.callsignTitle:SizeToContents()
	self.callsignHelp:SetPos(formPad, callsignY + 24)
	self.callsignHelp:SizeToContents()
	self.callsign:SetPos(formPad, callsignY + 58)
	self.callsign:SetSize(formWidth, 58)

	self.previewCard:SetPos(formPad, callsignY + 136)
	self.previewCard:SetSize(formWidth, math.Clamp(contentHeight * 0.2, 104, 140))

	self.identityBack:SetPos(margin, height - footerHeight + 10)
	self.identityBack:SetSize(190, footerHeight - 20)
	self.identityContinue:SetPos(width - margin - 350, height - footerHeight + 10)
	self.identityContinue:SetSize(350, footerHeight - 20)

	self.career:SetPos(margin, contentY)
	self.career:SetSize(width - margin * 2, contentHeight)
	self.branchBar:SetPos(0, 0)
	self.branchBar:SetSize(self.career:GetWide(), 72)

	local branchGap = 8
	local branchWidth = (self.branchBar:GetWide() - branchGap * (#self.branchButtons - 1)) / math.max(#self.branchButtons, 1)
	for i, button in ipairs(self.branchButtons) do
		button:SetPos((i - 1) * (branchWidth + branchGap), 0)
		button:SetSize(branchWidth, 64)
	end

	local careerGap = 14
	local targetWidth = math.Clamp(self.career:GetWide() * 0.27, 330, 430)
	self.tree:SetPos(0, 82)
	self.tree:SetSize(self.career:GetWide() - targetWidth - careerGap, contentHeight - 82)
	self.targetCard:SetPos(self.career:GetWide() - targetWidth, 82)
	self.targetCard:SetSize(targetWidth, contentHeight - 82)

	self.careerBack:SetPos(margin, height - footerHeight + 10)
	self.careerBack:SetSize(250, footerHeight - 20)
	self.createRecord:SetPos(width - margin - 350, height - footerHeight + 10)
	self.createRecord:SetSize(350, footerHeight - 20)
end

function CREATOR:Paint(width, height)
	paintRepublicBackdrop(self, width, height)
	surface.SetDrawColor(UI.line)
	surface.DrawRect(0, math.Clamp(height * 0.12, 76, 102) - 1, width, 1)

	-- ixSubpanelParent marks direct children as manually painted. Without calling the
	-- base paint method the backdrop appears, but every field/button/model remains invisible.
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

	self.header = makeLabel(self, "SERVICE RECORDS", "SWRPJoinTitle", UI.white)
	self.headerSub = makeLabel(self, "SELECT ACTIVE PERSONNEL FILE", "SWRPJoinSmall", UI.blue)

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

	self.model = self.modelFrame:Add("ixModelPanel")
	self.model:SetModel("models/error.mdl")
	self.model:SetFOV((ScrW() > ScrH() * 1.8) and 82 or 72)
	self.model.PaintModel = self.model.Paint

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
		local target = SWRP.GetCareerTarget(safeValue(character, "GetCareerTarget", ""))
		local path = SWRP.GetCareerPath(safeValue(character, "GetCareerPath", ""))
		local unlocked, total = getCareerProgress(character)
		local level = math.max(tonumber(safeValue(character, "GetLevel", 1)) or 1, 1)
		local xp = math.max(tonumber(safeValue(character, "GetXp", 0)) or 0, 0)
		local requirement = SWRP.Datapad and SWRP.Datapad.GetXPRequirement and SWRP.Datapad.GetXPRequirement(character, level) or 1000
		local progress = requirement > 0 and math.Clamp(xp / requirement, 0, 1) or 0
		local training = safeValue(character, "GetTrainingCompleted", false) and "TRAINED" or "UNTRAINED"
		local y = 24

		draw.SimpleText("ACTIVE PERSONNEL FILE", "SWRPJoinMicro", 24, y, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 28
		draw.SimpleText(character:GetName():upper(), "SWRPJoinTitle", 24, y, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 48
		draw.SimpleText(getCharacterRole(character):upper(), "SWRPJoinHeading", 24, y, path and path.colour or UI.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 42

		local rank = safeValue(character, "GetRank", "CT")
		local regiment = safeValue(character, "GetRegiment", "Unassigned")
		draw.SimpleText("RANK", "SWRPJoinMicro", 24, y, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(tostring(rank):upper(), "SWRPJoinBody", width * 0.5, y, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 30
		draw.SimpleText("REGIMENT", "SWRPJoinMicro", 24, y, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(tostring(regiment):upper(), "SWRPJoinBody", width * 0.5, y, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 30
		draw.SimpleText("TRAINING", "SWRPJoinMicro", 24, y, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(training, "SWRPJoinBody", width * 0.5, y, training == "TRAINED" and UI.success or UI.error, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 48

		surface.SetDrawColor(UI.line)
		surface.DrawRect(24, y, width - 48, 1)
		y = y + 22
		draw.SimpleText("TRACKED CAREER TARGET", "SWRPJoinMicro", 24, y, UI.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 24
		draw.SimpleText(target and getCareerNodeTitle(target):upper() or (path and path.fullTitle or "UNASSIGNED"), "SWRPJoinHeading", 24, y, path and path.colour or UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 38
		draw.SimpleText(string.format("%d / %d QUALIFICATIONS COMPLETE", unlocked, total), "SWRPJoinSmall", 24, y, UI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 44

		draw.SimpleText(string.format("LEVEL %d", level), "SWRPJoinSmall", 24, y, UI.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(string.format("%d / %d XP", xp, requirement), "SWRPJoinMicro", width - 24, y + 2, UI.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		y = y + 24
		surface.SetDrawColor(Color(255, 255, 255, 18))
		surface.DrawRect(24, y, width - 48, 8)
		surface.SetDrawColor(UI.blue)
		surface.DrawRect(24, y, (width - 48) * progress, 8)
	end

	self.backButton = makeButton(self, "RETURN", "Return to the Republic personnel network.", function()
		self:SlideDown()
		parent.mainPanel:Undim()
	end, "back")

	self.deleteButton = makeButton(self, "DELETE RECORD", "Permanently remove the selected character.", function()
		if (self.character) then
			self.deleteOverlay:SetVisible(true)
			self.deleteOverlay:MoveToFront()
		end
	end, "back")

	self.deployButton = makeButton(self, "DEPLOY", "Load the selected character and enter the server.", function()
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
	local margin = math.max(ScreenScale(16), 28)
	local headerHeight = math.Clamp(height * 0.12, 76, 102)
	local footerHeight = math.Clamp(height * 0.11, 72, 96)
	local contentY = headerHeight
	local contentHeight = height - headerHeight - footerHeight
	local gap = 14
	local listWidth = math.Clamp(width * 0.25, 330, 430)
	local recordWidth = math.Clamp(width * 0.27, 350, 455)
	local modelWidth = width - margin * 2 - listWidth - recordWidth - gap * 2

	self.header:SetPos(margin, 22)
	self.header:SizeToContents()
	self.headerSub:SetPos(margin + 2, 22 + self.header:GetTall() + 3)
	self.headerSub:SizeToContents()

	self.listFrame:SetPos(margin, contentY)
	self.listFrame:SetSize(listWidth, contentHeight)
	self.characterList:SetPos(14, 54)
	self.characterList:SetSize(listWidth - 28, contentHeight - 68)

	self.modelFrame:SetPos(margin + listWidth + gap, contentY)
	self.modelFrame:SetSize(modelWidth, contentHeight)
	self.model:SetPos(8, 8)
	self.model:SetSize(modelWidth - 16, contentHeight - 16)

	self.record:SetPos(width - margin - recordWidth, contentY)
	self.record:SetSize(recordWidth, contentHeight)

	self.backButton:SetPos(margin, height - footerHeight + 10)
	self.backButton:SetSize(260, footerHeight - 20)
	self.deleteButton:SetPos(width - margin - 640, height - footerHeight + 10)
	self.deleteButton:SetSize(270, footerHeight - 20)
	self.deployButton:SetPos(width - margin - 350, height - footerHeight + 10)
	self.deployButton:SetSize(350, footerHeight - 20)

	self.deleteOverlay:SetPos(0, 0)
	self.deleteOverlay:SetSize(width, height)
	local boxWidth = math.Clamp(width * 0.42, 520, 700)
	local boxHeight = 260
	local boxX = width * 0.5 - boxWidth * 0.5
	local boxY = height * 0.5 - boxHeight * 0.5
	self.cancelDelete:SetPos(boxX + 28, boxY + boxHeight - 76)
	self.cancelDelete:SetSize(190, 48)
	self.confirmDelete:SetPos(boxX + boxWidth - 278, boxY + boxHeight - 76)
	self.confirmDelete:SetSize(250, 48)
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
