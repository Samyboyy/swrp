-- swrp/plugins/regiments/derma/cl_directory.lua
-- GAR regiment hierarchy, personnel directory and public service record viewer.

SWRP = SWRP or {}
SWRP.Regiments = SWRP.Regiments or {}

local REG = SWRP.Regiments
REG.snapshot = REG.snapshot or {
	personnel = {},
	recruitment = {},
	modelAssignments = {}
}
REG.panels = REG.panels or {}

local BACKGROUND = Color(2, 9, 16, 242)
local PANEL_DARK = Color(5, 14, 23, 238)
local PANEL_LIGHT = Color(9, 22, 34, 245)
local TEXT_MUTED = Color(151, 173, 189)
local TEXT_FAINT = Color(102, 129, 147)
local ONLINE = Color(91, 220, 157)
local OFFLINE = Color(111, 128, 140)
local DANGER = Color(224, 91, 91)

local function playDatapadSound(kind)
	if (SWRP.Datapad and isfunction(SWRP.Datapad.PlaySound)) then
		SWRP.Datapad.PlaySound(kind)
	end
end

local function drawCorners(x, y, width, height, colour, length)
	length = length or 17
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
	surface.SetDrawColor(83, 190, 235, 8)

	for lineY = y, y + height, 6 do
		surface.DrawRect(x, lineY, width, 1)
	end
end

local function nodeColour(node)
	return node and node.colour or (ix.config.Get("color", Color(65, 155, 225)))
end

local function colourWithAlpha(colour, alpha)
	return Color(colour.r, colour.g, colour.b, alpha)
end

local function formatDate(timestamp, fallback)
	timestamp = tonumber(timestamp) or 0

	if (timestamp <= 0) then
		return fallback or "NOT RECORDED"
	end

	return os.date("%d/%m/%Y", timestamp)
end

local function prettyID(value)
	value = tostring(value or "")

	if (value == "") then
		return "UNASSIGNED"
	end

	return string.upper(value:gsub("_", " "))
end

local function getOptionalNode(id)
	id = string.Trim(tostring(id or ""))

	if (id == "") then
		return nil
	end

	return REG.Get(id)
end

local function getNodeName(id, fallback)
	local node = getOptionalNode(id)
	return node and node.name or (fallback or prettyID(id))
end

local function drawFittedText(text, fonts, x, y, maximumWidth, colour, horizontalAlignment, verticalAlignment)
	text = tostring(text or "")
	fonts = istable(fonts) and fonts or {fonts or "DermaDefault"}
	horizontalAlignment = horizontalAlignment or TEXT_ALIGN_LEFT
	verticalAlignment = verticalAlignment or TEXT_ALIGN_TOP

	local selectedFont = fonts[#fonts] or "DermaDefault"

	for _, font in ipairs(fonts) do
		surface.SetFont(font)
		local width = surface.GetTextSize(text)

		if (width <= maximumWidth) then
			selectedFont = font
			break
		end
	end

	draw.SimpleText(text, selectedFont, x, y, colour, horizontalAlignment, verticalAlignment)
	return selectedFont
end


local function cleanModelPath(value)
	local model = string.Trim(tostring(value or "")):gsub("\\", "/")

	if (model == "" or not string.EndsWith(string.lower(model), ".mdl")) then
		return ""
	end

	return model
end

local function cleanBodygroups(value)
	local bodygroups = {}

	if (istable(value)) then
		for rawIndex, rawValue in pairs(value) do
			local index = math.floor(tonumber(rawIndex) or -1)
			local bodygroup = math.floor(tonumber(rawValue) or -1)

			if (index >= 0 and index <= 63 and bodygroup >= 0 and bodygroup <= 63) then
				bodygroups[index] = bodygroup
			end
		end
	else
		for token in string.gmatch(tostring(value or ""), "[^,;%s]+") do
			local rawIndex, rawValue = string.match(token, "^(%d+)%s*[:=]%s*(%d+)$")
			local index = math.floor(tonumber(rawIndex) or -1)
			local bodygroup = math.floor(tonumber(rawValue) or -1)

			if (index >= 0 and index <= 63 and bodygroup >= 0 and bodygroup <= 63) then
				bodygroups[index] = bodygroup
			end
		end
	end

	return bodygroups
end

local function bodygroupsToText(bodygroups)
	local entries = {}

	for rawIndex, rawValue in pairs(cleanBodygroups(bodygroups)) do
		entries[#entries + 1] = {
			index = tonumber(rawIndex) or 0,
			value = tonumber(rawValue) or 0
		}
	end

	table.sort(entries, function(a, b)
		return a.index < b.index
	end)

	local output = {}
	for _, entry in ipairs(entries) do
		output[#output + 1] = tostring(entry.index) .. "=" .. tostring(entry.value)
	end

	return table.concat(output, ", ")
end

local function resolveUnitTypeModelAssignment(snapshot, regimentID, unitTypeID)
	local assignments = snapshot and snapshot.modelAssignments or {}
	regimentID = REG.GetPrimaryRegiment(regimentID)
	unitTypeID = REG.ResolveUnitType(regimentID, unitTypeID)
	local bucket = istable(assignments) and assignments[regimentID] or nil

	if (not istable(bucket)) then
		return nil
	end

	local assignment = bucket[unitTypeID]

	if (istable(assignment) and cleanModelPath(assignment.model) ~= "") then
		return assignment
	end

	return nil
end

local function collectAvailableModels()
	local models = {}
	local seen = {}

	local function add(label, path)
		path = cleanModelPath(path)
		if (path == "" or seen[string.lower(path)]) then return end
		seen[string.lower(path)] = true
		models[#models + 1] = {
			label = tostring(label or path),
			path = path
		}
	end

	if (player_manager and player_manager.AllValidModels) then
		for label, path in pairs(player_manager.AllValidModels() or {}) do
			add(label, path)
		end
	end

	local function addFactionModels(value, label)
		if (isstring(value)) then
			add(label, value)
		elseif (istable(value)) then
			for _, nested in pairs(value) do
				addFactionModels(nested, label)
			end
		end
	end

	if (ix.faction and ix.faction.indices) then
		for _, faction in pairs(ix.faction.indices) do
			addFactionModels(faction.models, faction.name or faction.uniqueID or "Faction model")
		end
	end

	if (IsValid(LocalPlayer())) then
		add("Current player model", LocalPlayer():GetModel())
	end

	table.sort(models, function(a, b)
		return string.lower(a.label .. a.path) < string.lower(b.label .. b.path)
	end)

	return models
end

local function applyModelPreview(panel, modelPath, skin, bodygroups, framing)
	if (not IsValid(panel)) then return false end
	modelPath = cleanModelPath(modelPath)
	framing = framing or "full"

	if (modelPath == "" or not util.IsValidModel(modelPath)) then
		return false
	end

	panel:SetModel(modelPath)
	panel:SetFOV(framing == "portrait" and 30 or 34)
	panel:SetAmbientLight(Color(85, 112, 132))
	panel:SetDirectionalLight(BOX_FRONT, Color(205, 226, 238))
	panel:SetDirectionalLight(BOX_TOP, Color(105, 139, 162))

	local function configure()
		if (not IsValid(panel)) then return end
		local entity = panel:GetEntity()
		if (not IsValid(entity)) then return end

		entity:DrawShadow(false)
		local maximumSkin = math.max((entity:SkinCount() or 1) - 1, 0)
		entity:SetSkin(math.Clamp(math.floor(tonumber(skin) or 0), 0, maximumSkin))

		for index = 0, math.max(entity:GetNumBodyGroups() - 1, 0) do
			entity:SetBodygroup(index, 0)
		end

		for rawIndex, rawValue in pairs(cleanBodygroups(bodygroups)) do
			local index = math.floor(tonumber(rawIndex) or -1)
			if (index >= 0 and index < entity:GetNumBodyGroups()) then
				entity:SetBodygroup(index, math.max(math.floor(tonumber(rawValue) or 0), 0))
			end
		end

		local minimum, maximum = entity:GetRenderBounds()
		local height = math.max(maximum.z - minimum.z, 1)

		if (framing == "portrait") then
			-- Keep the helmet and face comfortably inside the personnel-record
			-- viewport. A slightly higher focal point moves the model down in-frame,
			-- while the extra camera distance adds a small amount of headroom.
			local targetZ = minimum.z + height * 0.84
			panel:SetLookAt(Vector(0, 0, targetZ))
			panel:SetCamPos(Vector(height * 0.76, height * 0.035, targetZ + height * 0.02))
		else
			panel:SetLookAt(Vector(0, 0, minimum.z + height * 0.51))
			panel:SetCamPos(Vector(height * 1.02, height * 0.04, minimum.z + height * 0.52))
		end
	end

	configure()
	timer.Simple(0, configure)
	panel.LayoutEntity = function(_, entity)
		if (IsValid(entity)) then
			entity:SetAngles(Angle(0, 18, 0))
		end
	end
	return true
end

local function getRecruitmentState(snapshot, node)
	local stateID = snapshot.recruitment and snapshot.recruitment[node.id]

	if (not REG.recruitmentStates[stateID]) then
		stateID = node.defaultRecruitment or "closed"
	end

	return stateID, REG.recruitmentStates[stateID] or REG.recruitmentStates.closed
end

local function recordBelongsToNode(record, nodeID)
	local node = REG.Get(nodeID)

	if (not node or not istable(record)) then
		return false
	end

	if (node.id == "gar") then
		return true
	end

	if (node.kind == "unit") then
		if (node.filterByUnitType and node.unitType) then
			return REG.GetPrimaryRegiment(record.regiment) == REG.GetPrimaryRegiment(node.id)
				and REG.ResolveUnitType(record.regiment, record.unitType) == node.unitType
		end

		return REG.ResolveID(record.unit) == node.id
	end

	return REG.ResolveID(record.regiment) == node.id
end

local function recordMatchesSearch(record, searchText)
	searchText = string.lower(string.Trim(searchText or ""))

	if (searchText == "") then
		return true
	end

	local haystack = table.concat({
		tostring(record.displayName or ""),
		tostring(record.name or ""),
		tostring(record.callsign or ""),
		tostring(record.cloneNumber or ""),
		tostring(record.rank or ""),
		tostring(record.billet or ""),
		getNodeName(record.regiment, ""),
		getNodeName(record.unit, ""),
		REG.GetUnitTypeName(record.regiment, record.unitType)
	}, " ")

	return string.find(string.lower(haystack), searchText, 1, true) ~= nil
end

local function addSectionHeading(parent, title, subtitle, accent)
	local panel = parent:Add("DPanel")
	panel:Dock(TOP)
	panel:SetTall(subtitle and 48 or 31)
	panel:DockMargin(0, 0, 0, 8)
	panel.Paint = function(_, width, height)
		surface.SetDrawColor(accent.r, accent.g, accent.b, 160)
		surface.DrawRect(0, height - 2, width, 2)
		draw.SimpleText(string.upper(title), "DermaDefaultBold", 0, 3, color_white)

		if (subtitle) then
			draw.SimpleText(subtitle, "DermaDefault", 0, 23, TEXT_MUTED)
		end
	end

	return panel
end

local function addInformationCard(parent, title, body, accent, height)
	local card = parent:Add("DPanel")
	card:Dock(TOP)
	card:SetTall(height or 94)
	card:DockMargin(0, 0, 0, 9)
	card:DockPadding(15, 13, 15, 11)
	card.Paint = function(_, width, panelHeight)
		draw.RoundedBox(3, 0, 0, width, panelHeight, PANEL_LIGHT)
		surface.SetDrawColor(accent.r, accent.g, accent.b, 180)
		surface.DrawRect(0, 0, 3, panelHeight)
	end

	local heading = card:Add("DLabel")
	heading:Dock(TOP)
	heading:SetTall(22)
	heading:SetFont("DermaDefaultBold")
	heading:SetText(string.upper(title))
	heading:SetTextColor(accent)

	local description = card:Add("DLabel")
	description:Dock(FILL)
	description:SetFont("DermaDefault")
	description:SetText(body or "")
	description:SetTextColor(Color(196, 211, 222))
	description:SetWrap(true)
	description:SetContentAlignment(7)

	return card
end

local function createServiceRecord(record)
	if (not istable(record)) then
		return
	end

	playDatapadSound("zoom")

	local node = REG.Get(record.regiment)
	local unit = getOptionalNode(record.unit)
	local accent = nodeColour(unit or node)
	local frame = vgui.Create("DFrame")
	frame:SetSize(math.min(ScrW() - 100, 980), math.min(ScrH() - 90, 680))
	frame:Center()
	frame:MakePopup()
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:SetDraggable(true)
	frame:DockPadding(18, 76, 18, 18)
	frame.Paint = function(_, width, height)
		draw.RoundedBox(4, 0, 0, width, height, Color(2, 8, 14, 252))
		draw.RoundedBoxEx(4, 0, 0, width, 64, Color(5, 16, 27, 252), true, true, false, false)
		drawCorners(0, 0, width, height, colourWithAlpha(accent, 160), 22)
		draw.SimpleText("REPUBLIC PERSONNEL RECORD", "DermaLarge", 20, 10, color_white)
		draw.SimpleText("PUBLIC SERVICE FILE • GAR PERSONNEL COMMAND", "DermaDefaultBold", 22, 42, accent)
		drawScanlines(0, 64, width, height - 64)
	end

	local close = frame:Add("DButton")
	close:SetSize(42, 34)
	close:SetPos(frame:GetWide() - 58, 15)
	close:SetText("×")
	close:SetFont("DermaLarge")
	close:SetTextColor(color_white)
	close.Paint = function(button, width, height)
		draw.RoundedBox(3, 0, 0, width, height, button:IsHovered() and Color(173, 66, 66) or Color(75, 34, 38))
	end
	close.DoClick = function()
		playDatapadSound("back")
		frame:Remove()
	end

	local left = frame:Add("DPanel")
	left:Dock(LEFT)
	left:SetWide(310)
	left:DockMargin(0, 0, 14, 0)
	left:DockPadding(12, 12, 12, 12)
	left.Paint = function(_, width, height)
		draw.RoundedBox(3, 0, 0, width, height, PANEL_DARK)
		drawCorners(0, 0, width, height, colourWithAlpha(accent, 95), 14)
	end

	local model = left:Add("DModelPanel")
	model:Dock(TOP)
	model:SetTall(330)
	model:SetPaintBackground(false)
	model:SetFOV(34)
	model:SetCamPos(Vector(64, 0, 62))
	model:SetLookAt(Vector(0, 0, 59))
	model:SetMouseInputEnabled(false)

	if (isstring(record.model) and record.model ~= "" and util.IsValidModel(record.model)) then
		applyModelPreview(model, record.model, record.modelSkin or 0, record.modelBodygroups or {}, "portrait")
	end

	model.LayoutEntity = function(_, entity)
		if (IsValid(entity)) then
			entity:SetAngles(Angle(0, 18, 0))
		end
	end

	local identity = left:Add("DPanel")
	identity:Dock(FILL)
	identity:DockMargin(0, 10, 0, 0)
	identity.Paint = function(_, width, height)
		draw.RoundedBox(3, 0, 0, width, height, Color(8, 21, 33, 245))
		surface.SetDrawColor(accent.r, accent.g, accent.b, 170)
		surface.DrawRect(0, 0, width, 3)
		local publicName = string.Trim(tostring(record.callsign or ""))
		if (publicName == "") then
			publicName = record.displayName or record.name or "UNKNOWN"
		end

		local designation = table.concat({
			REG.GetRegimentPrefix(record.regiment),
			string.upper(record.rank or "RCT"),
			tostring(record.cloneNumber or "")
		}, " "):gsub("%s+$", "")

		drawFittedText(
			string.upper(publicName),
			{"DermaLarge", "Trebuchet24", "DermaDefaultBold"},
			13,
			15,
			width - 26,
			color_white
		)
		drawFittedText(
			designation .. " • " .. getNodeName(record.regiment),
			{"DermaDefaultBold", "DermaDefault"},
			14,
			54,
			width - 28,
			accent
		)
		drawFittedText(
			unit and unit.name or "NO SUBUNIT ASSIGNMENT",
			{"DermaDefaultBold", "DermaDefault"},
			14,
			78,
			width - 28,
			TEXT_MUTED
		)
		draw.SimpleText(
			"UNIT TYPE  •  " .. string.upper(REG.GetUnitTypeName(record.regiment, record.unitType)),
			"DermaDefault",
			14,
			101,
			TEXT_MUTED
		)
		draw.SimpleText(record.online and "● CURRENTLY ONLINE" or "● CURRENTLY OFFLINE", "DermaDefaultBold", 14, height - 37, record.online and ONLINE or OFFLINE)
	end

	local scroll = frame:Add("DScrollPanel")
	scroll:Dock(FILL)

	addSectionHeading(scroll, "Assignment", "Current public posting and service state", accent)
	addInformationCard(scroll, "Regiment", getNodeName(record.regiment), accent, 76)
	addInformationCard(scroll, "Unit", unit and unit.name or "No subunit assignment", accent, 76)
	addInformationCard(scroll, "Unit Type", REG.GetUnitTypeName(record.regiment, record.unitType), accent, 76)
	addInformationCard(scroll, "Billet", record.billet ~= "" and prettyID(record.billet) or "No command billet", accent, 76)
	addInformationCard(scroll, "Service Status", string.upper(record.serviceStatus or "active"), accent, 76)

	addSectionHeading(scroll, "Service Information", "Public dates and identification", accent)
	addInformationCard(scroll, "Service Number", record.cloneNumber ~= "" and (REG.GetRegimentPrefix(record.regiment) .. "-" .. record.cloneNumber) or (record.name or "Not recorded"), accent, 76)
	addInformationCard(scroll, "Enlisted", formatDate(record.enlistedAt), accent, 76)
	addInformationCard(scroll, "Last Promotion", formatDate(record.lastPromotionAt, "NO PROMOTION RECORDED"), accent, 76)

	local function addListSection(title, list, emptyText)
		addSectionHeading(scroll, title, nil, accent)

		if (not istable(list) or #list == 0) then
			addInformationCard(scroll, "No entries", emptyText, accent, 74)
			return
		end

		for index, value in ipairs(list) do
			addInformationCard(scroll, string.format("%02d", index), tostring(value), accent, 74)
		end
	end

	addListSection("Specialisations", record.specialisations, "No specialist assignment is listed.")
	addListSection("Training Certifications", record.certifications, "No public certifications are listed.")
	addListSection("Commendations", record.commendations, "No public commendations are listed.")
end

local function mergeNodeData(snapshot, node)
	local data = table.Copy(node or {})
	local override = snapshot and snapshot.nodeOverrides and snapshot.nodeOverrides[data.id]

	if (istable(override)) then
		if (isstring(override.description) and override.description ~= "") then
			data.description = override.description
		end

		if (istable(override.specialisations)) then
			data.specialisations = override.specialisations
		end

		if (istable(override.requirements)) then
			data.requirements = override.requirements
		end

		data.recruitmentNotice = tostring(override.recruitmentNotice or "")
	else
		data.recruitmentNotice = ""
	end

	return data
end

local function getNodeTraining(snapshot, nodeID)
	if (snapshot and snapshot.training and istable(snapshot.training[nodeID])) then
		return snapshot.training[nodeID]
	end

	local node = REG.Get(nodeID)
	return node and node.trainingSessions or {}
end

local function sendManagement(action, nodeID, payload)
	net.Start("swrpRegimentsManage")
	net.WriteString(action)
	net.WriteString(nodeID)
	net.WriteTable(payload or {})
	net.SendToServer()
end

local function applyEntryStyle(entry, accent)
	entry:SetTextColor(color_white)
	entry:SetCursorColor(color_white)
	entry:SetPaintBackground(false)
	entry.Paint = function(this, width, height)
		draw.RoundedBox(3, 0, 0, width, height, Color(7, 19, 30, 250))
		surface.SetDrawColor(this:HasFocus() and accent or Color(69, 98, 119))
		surface.DrawOutlinedRect(0, 0, width, height, this:HasFocus() and 2 or 1)
		this:DrawTextEntryText(color_white, accent, color_white)
	end
end

local function addFieldLabel(parent, text)
	local label = parent:Add("DLabel")
	label:Dock(TOP)
	label:SetTall(24)
	label:DockMargin(0, 5, 0, 3)
	label:SetFont("DermaDefaultBold")
	label:SetText(string.upper(text))
	label:SetTextColor(TEXT_MUTED)
	return label
end

local function addTextField(parent, value, accent, tall, multiline)
	local entry = parent:Add("DTextEntry")
	entry:Dock(TOP)
	entry:SetTall(tall or 36)
	entry:SetText(value or "")
	entry:SetMultiline(multiline == true)
	entry:SetUpdateOnType(true)
	applyEntryStyle(entry, accent)
	return entry
end

local function addActionButton(parent, label, accent, callback, danger)
	local button = parent:Add("DButton")
	button:Dock(TOP)
	button:SetTall(38)
	button:DockMargin(0, 8, 0, 0)
	button:SetText(label)
	button:SetFont("DermaDefaultBold")
	button:SetTextColor(color_white)
	button.Paint = function(this, width, height)
		local colour = danger and DANGER or accent
		draw.RoundedBox(3, 0, 0, width, height, colourWithAlpha(colour, this:IsHovered() and 210 or 145))
	end
	button.DoClick = callback
	return button
end

local function openPersonnelEditor(owner, node, record, permission)
	if (not istable(record) or not record.online) then
		return
	end

	local accent = nodeColour(node)
	local frame = vgui.Create("DFrame")
	frame:SetSize(610, math.min(ScrH() - 100, 720))
	frame:Center()
	frame:MakePopup()
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:DockPadding(18, 66, 18, 18)
	frame.Paint = function(_, width, height)
		draw.RoundedBox(4, 0, 0, width, height, Color(2, 8, 14, 253))
		draw.RoundedBoxEx(4, 0, 0, width, 56, Color(6, 17, 27, 253), true, true, false, false)
		drawCorners(0, 0, width, height, colourWithAlpha(accent, 160), 18)
		draw.SimpleText("MANAGE PERSONNEL", "DermaLarge", 17, 9, color_white)
		draw.SimpleText(record.displayName or record.name or "UNKNOWN", "DermaDefaultBold", 19, 37, accent)
	end

	local close = frame:Add("DButton")
	close:SetSize(38, 30)
	close:SetPos(frame:GetWide() - 52, 13)
	close:SetText("×")
	close:SetFont("DermaLarge")
	close:SetTextColor(color_white)
	close.Paint = function(this, width, height)
		draw.RoundedBox(3, 0, 0, width, height, this:IsHovered() and Color(171, 61, 67) or Color(67, 31, 35))
	end
	close.DoClick = function() frame:Remove() end

	local scroll = frame:Add("DScrollPanel")
	scroll:Dock(FILL)

	addSectionHeading(scroll, "Assignment", "Personnel changes apply immediately", accent)
	addFieldLabel(scroll, "Rank")
	local selectedRank = REG.NormalizeRank(record.rank) or "RCT"
	local rank = scroll:Add("DComboBox")
	rank:Dock(TOP)
	rank:SetTall(36)
	rank:SetValue(selectedRank .. " — " .. REG.GetRankName(selectedRank))

	for _, abbreviation in ipairs(REG.rankOrder or {}) do
		rank:AddChoice(abbreviation .. " — " .. REG.GetRankName(abbreviation), abbreviation)
	end

	rank.OnSelect = function(_, _, _, data)
		selectedRank = data or selectedRank
	end

	addFieldLabel(scroll, "Callsign")
	local callsign = addTextField(scroll, record.callsign or "", accent, 36, false)
	callsign:SetPlaceholderText("Optional, e.g. Rex or Fives")

	addFieldLabel(scroll, "Unit")
	local selectedUnit = record.unit ~= "" and record.unit or "none"
	local unit = scroll:Add("DComboBox")
	unit:Dock(TOP)
	unit:SetTall(36)
	unit:SetValue(record.unit ~= "" and getNodeName(record.unit) or "No subunit")
	unit:AddChoice("No subunit", "none")
	unit.OnSelect = function(_, _, _, data)
		selectedUnit = data or "none"
	end

	for _, child in ipairs(REG.GetChildren(REG.GetPrimaryRegiment(record.regiment))) do
		if (child.kind == "unit") then
			unit:AddChoice(child.name, child.id)
		end
	end

	addFieldLabel(scroll, "Unit type")
	local regimentID = REG.GetPrimaryRegiment(record.regiment)
	local selectedUnitType = REG.ResolveUnitType(regimentID, record.unitType)
	local unitType = scroll:Add("DComboBox")
	unitType:Dock(TOP)
	unitType:SetTall(36)
	unitType:SetValue(REG.GetUnitTypeName(regimentID, selectedUnitType))
	unitType.OnSelect = function(_, _, _, data)
		selectedUnitType = data or selectedUnitType
	end

	for _, option in ipairs(REG.GetUnitTypes(regimentID)) do
		unitType:AddChoice(option.name, option.id)
	end

	addFieldLabel(scroll, "Command billet ID")
	local billet = addTextField(scroll, record.billet or "", accent, 36, false)
	billet:SetPlaceholderText("none, commanding_officer, senior_nco...")

	addFieldLabel(scroll, "Service status")
	local selectedStatus = record.serviceStatus or "active"
	local status = scroll:Add("DComboBox")
	status:Dock(TOP)
	status:SetTall(36)
	status:SetValue(string.upper(selectedStatus))
	status:AddChoice("ACTIVE", "active")
	status:AddChoice("RESERVE", "reserve")
	status:AddChoice("DISCHARGED", "discharged")
	status.OnSelect = function(_, _, _, data)
		selectedStatus = data or "active"
	end

	if (permission >= 3) then
		addActionButton(scroll, "SAVE PERSONNEL RECORD", accent, function()
			sendManagement("update_personnel", node.id, {
				characterID = record.characterID,
				rank = selectedRank,
				callsign = callsign:GetValue(),
				unit = selectedUnit,
				unitType = selectedUnitType,
				billet = billet:GetValue(),
				serviceStatus = selectedStatus
			})
			timer.Simple(0.4, function()
				if (IsValid(owner)) then owner:RequestSnapshot() end
			end)
		end)

		local primaryNodeID = REG.GetPrimaryRegiment(node.id)
		if (node.id == primaryNodeID and node.id ~= "unassigned") then
			addActionButton(scroll, "REMOVE FROM REGIMENT", DANGER, function()
				Derma_Query(
					"Remove " .. (record.displayName or record.name or "this player") .. " from " .. (node.name or "the regiment") .. "?\n\nTheir clone number, callsign and rank will stay the same, but their prefix will return to CT.",
					"Confirm Regiment Removal",
					"REMOVE",
					function()
						sendManagement("remove_personnel", node.id, {
							characterID = record.characterID
						})
						frame:Remove()
						timer.Simple(0.4, function()
							if (IsValid(owner)) then owner:RequestSnapshot() end
						end)
					end,
					"CANCEL"
				)
			end, true)
		end
	end

	addSectionHeading(scroll, "Service Record", "Certifications and commendations", accent)
	addFieldLabel(scroll, "New certification")
	local certification = addTextField(scroll, "", accent, 36, false)
	certification:SetPlaceholderText("e.g. Advanced Breaching")
	addActionButton(scroll, "ADD CERTIFICATION", accent, function()
		sendManagement("record_entry", node.id, {
			characterID = record.characterID,
			entryType = "certification",
			value = certification:GetValue(),
			remove = false
		})
		certification:SetText("")
	end)

	addFieldLabel(scroll, "New commendation")
	local commendation = addTextField(scroll, "", accent, 36, false)
	commendation:SetPlaceholderText("e.g. Republic Medal of Valor")
	addActionButton(scroll, "ADD COMMENDATION", accent, function()
		sendManagement("record_entry", node.id, {
			characterID = record.characterID,
			entryType = "commendation",
			value = commendation:GetValue(),
			remove = false
		})
		commendation:SetText("")
	end)
end

net.Receive("swrpRegimentsSnapshot", function()
	REG.snapshot = net.ReadTable() or {
		personnel = {},
		recruitment = {},
		nodeOverrides = {},
		training = {},
		permissions = {},
		modelAssignments = {}
	}

	for panel in pairs(REG.panels) do
		if (IsValid(panel)) then
			panel:ApplySnapshot(REG.snapshot)
		else
			REG.panels[panel] = nil
		end
	end
end)

net.Receive("swrpRegimentsRecord", function()
	createServiceRecord(net.ReadTable())
end)

local PANEL = {}

function PANEL:Init()
	REG.panels[self] = true
	self.snapshot = REG.snapshot or {}
	self.selectedNodeID = nil
	self.activeView = "overview"
	self.manageView = "regiment"
	self.searchText = ""
	self.bInitialSelectionMade = false
	self:DockPadding(20, 16, 20, 18)

	self.header = self:Add("DPanel")
	self.header:Dock(TOP)
	self.header:SetTall(58)
	self.header.Paint = function(_, width, height)
		local node = self.selectedNodeID and REG.Get(self.selectedNodeID) or REG.Get("gar")
		local accent = nodeColour(node)
		draw.RoundedBox(4, 0, 0, width, height, Color(4, 13, 22, 244))
		drawCorners(0, 0, width, height, colourWithAlpha(accent, 105), 16)
		draw.SimpleText("REGIMENTS", "DermaLarge", 17, 8, color_white)
		draw.SimpleText("Browse formations, personnel and training", "DermaDefault", 19, 36, TEXT_MUTED)
	end

	self.body = self:Add("DPanel")
	self.body:Dock(FILL)
	self.body:DockMargin(0, 10, 0, 0)
	self.body.Paint = nil

	self.sidebar = self.body:Add("DPanel")
	self.sidebar:Dock(LEFT)
	self.sidebar:SetWide(244)
	self.sidebar:DockMargin(0, 0, 12, 0)
	self.sidebar:DockPadding(11, 11, 11, 11)
	self.sidebar.Paint = function(_, width, height)
		draw.RoundedBox(4, 0, 0, width, height, PANEL_DARK)
		drawCorners(0, 0, width, height, Color(59, 126, 164, 70), 14)
	end

	self.navigation = self.sidebar:Add("DScrollPanel")
	self.navigation:Dock(FILL)

	self.refreshButton = self.sidebar:Add("DButton")
	self.refreshButton:Dock(BOTTOM)
	self.refreshButton:SetTall(36)
	self.refreshButton:DockMargin(0, 9, 0, 0)
	self.refreshButton:SetText("REFRESH")
	self.refreshButton:SetFont("DermaDefaultBold")
	self.refreshButton:SetTextColor(color_white)
	self.refreshButton.Paint = function(this, width, height)
		draw.RoundedBox(3, 0, 0, width, height, this:IsHovered() and Color(49, 127, 174) or Color(27, 75, 104))
	end
	self.refreshButton.DoClick = function()
		playDatapadSound("zoom")
		self:RequestSnapshot()
	end

	self.main = self.body:Add("DPanel")
	self.main:Dock(FILL)
	self.main:DockPadding(14, 14, 14, 14)
	self.main.Paint = function(_, width, height)
		local node = self.selectedNodeID and REG.Get(self.selectedNodeID) or REG.Get("gar")
		local accent = nodeColour(node)
		draw.RoundedBox(4, 0, 0, width, height, BACKGROUND)
		drawCorners(0, 0, width, height, colourWithAlpha(accent, 75), 15)
	end

	self.hero = self.main:Add("DPanel")
	self.hero:Dock(TOP)
	self.hero:SetTall(0)
	self.hero.Paint = nil

	self.tabs = self.main:Add("DPanel")
	self.tabs:Dock(TOP)
	self.tabs:SetTall(0)
	self.tabs.Paint = nil

	self.content = self.main:Add("DScrollPanel")
	self.content:Dock(FILL)

	self:RebuildNavigation()
	self:RefreshView()
	self:RequestSnapshot()
end

function PANEL:OnRemove()
	REG.panels[self] = nil
end

function PANEL:RequestSnapshot()
	net.Start("swrpRegimentsRequest")
	net.SendToServer()
end

function PANEL:ApplySnapshot(snapshot)
	self.snapshot = snapshot or {}

	if (not self.bInitialSelectionMade) then
		local viewer = self.snapshot.viewer

		if (istable(viewer) and viewer.regiment and viewer.regiment ~= "unassigned" and REG.Get(viewer.regiment)) then
			self.selectedNodeID = REG.ResolveID(viewer.regiment)
		else
			self.selectedNodeID = nil
		end

		self.bInitialSelectionMade = true
	end

	self:RebuildNavigation()
	self:RefreshView()
end

function PANEL:GetPermission(nodeID)
	return tonumber(self.snapshot.permissions and self.snapshot.permissions[nodeID]) or 0
end

function PANEL:GetPersonnel(nodeID, includeSearch)
	local results = {}
	local node = REG.Get(nodeID)

	if (not node) then
		return results
	end

	for _, record in ipairs(self.snapshot.personnel or {}) do
		local belongs = false

		if (node.id == "gar") then
			belongs = true
		elseif (node.kind == "unit") then
			if (node.filterByUnitType and node.unitType) then
				belongs = REG.GetPrimaryRegiment(record.regiment) == REG.GetPrimaryRegiment(node.id)
					and REG.ResolveUnitType(record.regiment, record.unitType) == node.unitType
			else
				belongs = REG.ResolveID(record.unit) == node.id
			end
		else
			belongs = REG.ResolveID(record.regiment) == node.id
		end

		if (belongs and (includeSearch == false or recordMatchesSearch(record, self.searchText))) then
			results[#results + 1] = record
		end
	end

	return results
end

function PANEL:GetNodeCount(nodeID)
	local personnel = self:GetPersonnel(nodeID, false)
	local online = 0

	for _, record in ipairs(personnel) do
		if (record.online) then online = online + 1 end
	end

	return online, #personnel
end

function PANEL:GetCommandHolder(node, positionID)
	for _, record in ipairs(self:GetPersonnel(node.id, false)) do
		if (string.lower(record.billet or "") == string.lower(positionID or "")) then
			return record
		end
	end

	return nil
end

function PANEL:SelectNode(nodeID)
	if (nodeID ~= nil and not REG.Get(nodeID)) then
		return
	end

	playDatapadSound("zoom")
	self.selectedNodeID = nodeID
	self.activeView = "overview"
	self.manageView = "regiment"
	self.searchText = ""
	self:RebuildNavigation()
	self:RefreshView()
end

function PANEL:AddNavigationButton(label, nodeID, subtitle, accent)
	local button = self.navigation:Add("DButton")
	button:Dock(TOP)
	button:SetTall(subtitle and 58 or 42)
	button:DockMargin(0, 0, 0, 5)
	button:SetText("")
	button.Paint = function(this, width, height)
		local selected = self.selectedNodeID == nodeID
		local colour = accent or Color(72, 164, 220)
		draw.RoundedBox(3, 0, 0, width, height, selected and colourWithAlpha(colour, 45) or Color(8, 20, 31, this:IsHovered() and 245 or 220))
		surface.SetDrawColor(colour.r, colour.g, colour.b, selected and 220 or 75)
		surface.DrawRect(0, 0, selected and 4 or 2, height)
		draw.SimpleText(label, "DermaDefaultBold", 12, subtitle and 10 or 13, selected and color_white or Color(199, 213, 222))
		if (subtitle) then
			draw.SimpleText(subtitle, "DermaDefault", 12, 32, TEXT_FAINT)
		end
	end
	button.OnCursorEntered = function() playDatapadSound("move") end
	button.DoClick = function() self:SelectNode(nodeID) end
	return button
end

function PANEL:RebuildNavigation()
	if (not IsValid(self.navigation)) then return end
	self.navigation:Clear()

	local viewer = self.snapshot.viewer
	local myPanel = self.navigation:Add("DPanel")
	myPanel:Dock(TOP)
	myPanel:SetTall(82)
	myPanel:DockMargin(0, 0, 0, 11)
	myPanel.Paint = function(_, width, height)
		draw.RoundedBox(3, 0, 0, width, height, Color(8, 21, 33, 245))
		draw.SimpleText("MY ASSIGNMENT", "DermaDefaultBold", 12, 10, TEXT_FAINT)

		if (istable(viewer)) then
			draw.SimpleText(viewer.displayName or viewer.name or "PERSONNEL", "DermaDefaultBold", 12, 31, color_white)
			draw.SimpleText(getNodeName(viewer.regiment, "Unassigned Personnel"), "DermaDefault", 12, 55, nodeColour(REG.Get(viewer.regiment)))
		else
			draw.SimpleText("NO ACTIVE RECORD", "DermaDefaultBold", 12, 35, TEXT_MUTED)
		end
	end

	local browseLabel = self.navigation:Add("DLabel")
	browseLabel:Dock(TOP)
	browseLabel:SetTall(25)
	browseLabel:SetText("BROWSE")
	browseLabel:SetFont("DermaDefaultBold")
	browseLabel:SetTextColor(TEXT_MUTED)

	self:AddNavigationButton("All Regiments", nil, "Simple overview", Color(85, 169, 214))

	for _, id in ipairs(REG.browseOrder or {}) do
		local nodeID = id
		local node = REG.Get(nodeID)
		if (node) then
			local online, total = self:GetNodeCount(nodeID)
			self:AddNavigationButton(node.name, nodeID, string.format("%d online • %d roster", online, total), nodeColour(node))
		end
	end

	if (self.snapshot.isStaff or self:GetPermission("high_command") > 0) then
		local staffLabel = self.navigation:Add("DLabel")
		staffLabel:Dock(TOP)
		staffLabel:SetTall(29)
		staffLabel:DockMargin(0, 8, 0, 0)
		staffLabel:SetText("COMMAND")
		staffLabel:SetFont("DermaDefaultBold")
		staffLabel:SetTextColor(TEXT_MUTED)
		self:AddNavigationButton("High Command", "high_command", nil, nodeColour(REG.Get("high_command")))
		self:AddNavigationButton("Unassigned Personnel", "unassigned", nil, nodeColour(REG.Get("unassigned")))
	end
end

function PANEL:RefreshView()
	if (not IsValid(self.content)) then return end
	self.content:Clear()
	self.hero:Clear()
	self.tabs:Clear()

	if (not self.selectedNodeID) then
		self.hero:SetTall(0)
		self.tabs:SetTall(0)
		self:BuildHomeView()
		return
	end

	local node = REG.Get(self.selectedNodeID)
	if (not node) then return end
	self:BuildHero(node)
	self:BuildTabs(node)

	if (self.activeView == "personnel") then
		self:BuildPersonnelView(node)
	elseif (self.activeView == "training") then
		self:BuildTrainingView(node)
	elseif (self.activeView == "manage") then
		self:BuildManageView(node)
	elseif (self.activeView == "models") then
		self:BuildModelsView(node)
	else
		self:BuildOverviewView(node)
	end
end

function PANEL:BuildHomeView()
	local accent = nodeColour(REG.Get("gar"))
	local intro = self.content:Add("DPanel")
	intro:Dock(TOP)
	intro:SetTall(118)
	intro:DockMargin(0, 0, 0, 12)
	intro.Paint = function(_, width, height)
		draw.RoundedBox(4, 0, 0, width, height, PANEL_LIGHT)
		surface.SetDrawColor(accent.r, accent.g, accent.b, 190)
		surface.DrawRect(0, 0, 4, height)
		draw.SimpleText("REPUBLIC REGIMENTS", "DermaLarge", 18, 14, color_white)
		draw.SimpleText("Choose a formation to see what it does, who leads it and how to join.", "DermaDefault", 19, 51, Color(198, 213, 223))
		draw.SimpleText("You do not need to understand the whole command structure to get started.", "DermaDefault", 19, 77, TEXT_MUTED)
	end

	for _, id in ipairs(REG.browseOrder or {}) do
		local nodeID = id
		local node = REG.Get(nodeID)
		if (node) then
			local data = mergeNodeData(self.snapshot, node)
			local stateID, state = getRecruitmentState(self.snapshot, node)
			local online, total = self:GetNodeCount(nodeID)
			local card = self.content:Add("DButton")
			card:Dock(TOP)
			card:SetTall(126)
			card:DockMargin(0, 0, 0, 9)
			card:SetText("")
			card.Paint = function(this, width, height)
				local colour = nodeColour(node)
				draw.RoundedBox(4, 0, 0, width, height, this:IsHovered() and Color(11, 29, 44, 250) or PANEL_LIGHT)
				surface.SetDrawColor(colour.r, colour.g, colour.b, this:IsHovered() and 230 or 150)
				surface.DrawRect(0, 0, 5, height)
				draw.SimpleText(string.upper(node.name), "DermaLarge", 20, 14, color_white)
				draw.SimpleText(data.tagline or data.description, "DermaDefault", 21, 51, Color(191, 209, 220))
				draw.SimpleText(string.format("%d ONLINE  •  %d PERSONNEL", online, total), "DermaDefaultBold", 21, 87, colour)
				draw.RoundedBox(3, width - 145, 18, 120, 30, colourWithAlpha(state.colour, 30))
				draw.SimpleText(state.label or string.upper(stateID), "DermaDefaultBold", width - 85, 33, state.colour, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("VIEW REGIMENT  ›", "DermaDefaultBold", width - 25, 91, colour, TEXT_ALIGN_RIGHT)
			end
			card.OnCursorEntered = function() playDatapadSound("move") end
			card.DoClick = function() self:SelectNode(nodeID) end
		end
	end
end

function PANEL:BuildHero(node)
	self.hero:SetTall(112)
	self.hero:DockMargin(0, 0, 0, 9)
	self.hero.Paint = function(_, width, height)
		local data = mergeNodeData(self.snapshot, node)
		local accent = nodeColour(node)
		local stateID, state = getRecruitmentState(self.snapshot, node)
		draw.RoundedBox(4, 0, 0, width, height, PANEL_LIGHT)
		surface.SetDrawColor(accent.r, accent.g, accent.b, 210)
		surface.DrawRect(0, 0, 5, height)
		draw.SimpleText(string.upper(node.name), "DermaLarge", 20, 13, color_white)
		draw.SimpleText(data.tagline or data.description, "DermaDefault", 21, 49, Color(194, 211, 221))
		draw.SimpleText(string.upper(node.kind) .. " • " .. string.upper(node.shortName or node.name), "DermaDefaultBold", 21, 82, accent)
		draw.SimpleText("RECRUITMENT", "DermaDefaultBold", width - 150, 18, TEXT_FAINT)
		draw.RoundedBox(3, width - 150, 43, 125, 31, colourWithAlpha(state.colour, 30))
		draw.SimpleText(state.label or string.upper(stateID), "DermaDefaultBold", width - 87, 58, state.colour, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

function PANEL:BuildTabs(node)
	self.tabs:SetTall(42)
	self.tabs:DockMargin(0, 0, 0, 9)
	local permission = self:GetPermission(node.id)
	local entries = {
		{id = "overview", label = "OVERVIEW"},
		{id = "personnel", label = "PERSONNEL"},
		{id = "training", label = "TRAINING"}
	}

	if (permission > 0) then
		entries[#entries + 1] = {id = "manage", label = "MANAGE"}
	end

	if (self.snapshot.isStaff) then
		entries[#entries + 1] = {id = "models", label = "MODELS"}
	end

	for _, tab in ipairs(entries) do
		local tabID = tab.id
		local tabLabel = tab.label
		local button = self.tabs:Add("DButton")
		button:Dock(LEFT)
		button:SetWide((tabID == "manage" or tabID == "models") and 128 or 132)
		button:DockMargin(0, 0, 7, 0)
		button:SetText(tabLabel)
		button:SetFont("DermaDefaultBold")
		button:SetTextColor(color_white)
		button.Paint = function(this, width, height)
			local selected = self.activeView == tabID
			local accent = nodeColour(node)
			draw.RoundedBox(3, 0, 0, width, height, selected and colourWithAlpha(accent, 150) or Color(8, 20, 31, 235))
			surface.SetDrawColor(accent.r, accent.g, accent.b, selected and 235 or 60)
			surface.DrawRect(0, height - 2, width, 2)
		end
		button.DoClick = function()
			playDatapadSound("move")
			self.activeView = tabID
			self:RefreshView()
		end
	end
end

function PANEL:AddCompactPanel(title, body, accent, tall)
	local panel = self.content:Add("DPanel")
	panel:Dock(TOP)
	panel:SetTall(tall or 88)
	panel:DockMargin(0, 0, 0, 9)
	panel.Paint = function(_, width, height)
		draw.RoundedBox(3, 0, 0, width, height, PANEL_LIGHT)
		surface.SetDrawColor(accent.r, accent.g, accent.b, 150)
		surface.DrawRect(0, 0, 3, height)
		draw.SimpleText(string.upper(title), "DermaDefaultBold", 15, 13, accent)
	end

	local label = panel:Add("DLabel")
	label:Dock(FILL)
	label:DockMargin(15, 37, 15, 10)
	label:SetFont("DermaDefault")
	label:SetText(body or "")
	label:SetTextColor(Color(196, 211, 221))
	label:SetWrap(true)
	label:SetContentAlignment(7)
	return panel
end

function PANEL:BuildOverviewView(node)
	local data = mergeNodeData(self.snapshot, node)
	local accent = nodeColour(node)
	local online, total = self:GetNodeCount(node.id)
	local stateID, state = getRecruitmentState(self.snapshot, node)

	addSectionHeading(self.content, "At a Glance", nil, accent)
	local summary = self.content:Add("DPanel")
	summary:Dock(TOP)
	summary:SetTall(124)
	summary:DockMargin(0, 0, 0, 10)
	summary.Paint = function(_, width, height)
		draw.RoundedBox(3, 0, 0, width, height, PANEL_LIGHT)
		draw.SimpleText(tostring(online), "DermaLarge", 20, 18, ONLINE)
		draw.SimpleText("ONLINE", "DermaDefaultBold", 20, 53, TEXT_FAINT)
		draw.SimpleText(tostring(total), "DermaLarge", 125, 18, color_white)
		draw.SimpleText("ROSTER", "DermaDefaultBold", 125, 53, TEXT_FAINT)
		draw.SimpleText(state.label or string.upper(stateID), "DermaLarge", 230, 18, state.colour)
		draw.SimpleText("RECRUITMENT", "DermaDefaultBold", 230, 53, TEXT_FAINT)
		draw.SimpleText(data.description or "No public briefing available.", "DermaDefault", 20, 86, Color(195, 211, 221))
	end

	if (data.recruitmentNotice and data.recruitmentNotice ~= "") then
		self:AddCompactPanel("Recruitment Notice", data.recruitmentNotice, state.colour, 84)
	end

	if (#(node.commandPositions or {}) > 0) then
		addSectionHeading(self.content, "Command", nil, accent)
		local command = self.content:Add("DPanel")
		command:Dock(TOP)
		command:SetTall(92)
		command:DockMargin(0, 0, 0, 10)
		command.Paint = nil
		command.PerformLayout = function(panel, width, height)
			local children = panel:GetChildren()
			local gap = 7
			local cardWidth = math.floor((width - gap * math.max(#children - 1, 0)) / math.max(#children, 1))
			for index, child in ipairs(children) do
				child:SetPos((index - 1) * (cardWidth + gap), 0)
				child:SetSize(cardWidth, height)
			end
		end

		for _, position in ipairs(node.commandPositions) do
			local holder = self:GetCommandHolder(node, position.id)
			local card = command:Add("DButton")
			card:SetText("")
			card:SetCursor(holder and "hand" or "arrow")
			card.Paint = function(this, width, height)
				draw.RoundedBox(3, 0, 0, width, height, PANEL_LIGHT)
				draw.SimpleText(string.upper(position.title), "DermaDefaultBold", 12, 12, accent)
				draw.SimpleText(holder and (holder.displayName or holder.name) or "POSITION VACANT", "DermaDefaultBold", 12, 40, holder and color_white or TEXT_FAINT)
				if (holder) then
					draw.SimpleText(holder.online and "ONLINE" or "OFFLINE", "DermaDefault", 12, 65, holder.online and ONLINE or OFFLINE)
				end
			end
			card.DoClick = function()
				if (holder) then
					net.Start("swrpRegimentsRequestRecord")
					net.WriteUInt(tonumber(holder.characterID) or 0, 32)
					net.SendToServer()
				end
			end
		end
	end

	addSectionHeading(self.content, "Specialisations", nil, accent)
	local specialisations = self.content:Add("DPanel")
	specialisations:Dock(TOP)
	specialisations:SetTall(math.max(52, math.ceil(math.max(#data.specialisations, 1) / 3) * 45 + 8))
	specialisations:DockMargin(0, 0, 0, 10)
	specialisations.Paint = nil
	specialisations.PerformLayout = function(panel, width)
		local children = panel:GetChildren()
		local columns = 3
		local gap = 7
		local cardWidth = math.floor((width - gap * (columns - 1)) / columns)
		for index, child in ipairs(children) do
			local row = math.floor((index - 1) / columns)
			local column = (index - 1) % columns
			child:SetPos(column * (cardWidth + gap), row * 45)
			child:SetSize(cardWidth, 38)
		end
	end

	local specs = #data.specialisations > 0 and data.specialisations or {"No specialisations listed"}
	for _, value in ipairs(specs) do
		local chip = specialisations:Add("DPanel")
		chip.Paint = function(_, width, height)
			draw.RoundedBox(3, 0, 0, width, height, Color(8, 22, 34, 245))
			surface.SetDrawColor(accent.r, accent.g, accent.b, 120)
			surface.DrawOutlinedRect(0, 0, width, height, 1)
			draw.SimpleText(value, "DermaDefaultBold", 12, height * 0.5, Color(205, 219, 228), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	addSectionHeading(self.content, "Joining Requirements", nil, accent)
	local requirementsText = ""
	for index, requirement in ipairs(data.requirements or {}) do
		requirementsText = requirementsText .. string.format("%d. %s", index, requirement)
		if (index < #data.requirements) then requirementsText = requirementsText .. "\n" end
	end
	if (requirementsText == "") then requirementsText = "No public joining requirements are listed." end
	self:AddCompactPanel("Requirements", requirementsText, accent, math.max(86, 52 + #(data.requirements or {}) * 22))

	local children = REG.GetChildren(node.id)
	if (#children > 0) then
		addSectionHeading(self.content, "Units", "Select a unit for its own roster and training", accent)
		for _, child in ipairs(children) do
			local childNode = child
			local childData = mergeNodeData(self.snapshot, childNode)
			local onlineChild, totalChild = self:GetNodeCount(childNode.id)
			local card = self.content:Add("DButton")
			card:Dock(TOP)
			card:SetTall(78)
			card:DockMargin(0, 0, 0, 7)
			card:SetText("")
			card.Paint = function(this, width, height)
				local childAccent = nodeColour(childNode)
				draw.RoundedBox(3, 0, 0, width, height, this:IsHovered() and Color(12, 30, 45, 248) or PANEL_LIGHT)
				surface.SetDrawColor(childAccent.r, childAccent.g, childAccent.b, 170)
				surface.DrawRect(0, 0, 3, height)
				draw.SimpleText(childNode.name, "DermaDefaultBold", 15, 13, color_white)
				draw.SimpleText(childData.tagline or childData.description, "DermaDefault", 15, 37, TEXT_MUTED)
				draw.SimpleText(string.format("%d/%d  ›", onlineChild, totalChild), "DermaDefaultBold", width - 16, 30, childAccent, TEXT_ALIGN_RIGHT)
			end
			card.DoClick = function() self:SelectNode(childNode.id) end
		end
	end
end

function PANEL:BuildPersonnelView(node)
	local accent = nodeColour(node)
	local searchPanel = self.content:Add("DPanel")
	searchPanel:Dock(TOP)
	searchPanel:SetTall(46)
	searchPanel:DockMargin(0, 0, 0, 9)
	searchPanel.Paint = nil
	local searchButton = searchPanel:Add("DButton")
	searchButton:Dock(RIGHT)
	searchButton:SetWide(92)
	searchButton:DockMargin(7, 0, 0, 0)
	searchButton:SetText("SEARCH")
	searchButton:SetFont("DermaDefaultBold")
	searchButton:SetTextColor(color_white)
	searchButton.Paint = function(this, width, height)
		draw.RoundedBox(3, 0, 0, width, height, colourWithAlpha(accent, this:IsHovered() and 205 or 140))
	end

	local search = searchPanel:Add("DTextEntry")
	search:Dock(FILL)
	search:SetPlaceholderText("Search name, service number, rank or unit...")
	search:SetText(self.searchText or "")
	applyEntryStyle(search, accent)
	local function applySearch()
		self.searchText = string.lower(string.Trim(search:GetValue() or ""))
		self:RefreshView()
	end
	search.OnEnter = applySearch
	searchButton.DoClick = applySearch

	local personnel = self:GetPersonnel(node.id, true)
	addSectionHeading(self.content, "Personnel", string.format("%d public service records", #personnel), accent)

	if (#personnel == 0) then
		self:AddCompactPanel("No personnel found", self.searchText ~= "" and "No records match this search." or "No personnel are currently assigned to this formation.", accent, 80)
		return
	end

	local permission = self:GetPermission(node.id)
	for _, record in ipairs(personnel) do
		local personnelRecord = record
		local row = self.content:Add("DButton")
		row:Dock(TOP)
		row:SetTall(65)
		row:DockMargin(0, 0, 0, 6)
		row:SetText("")
		row.Paint = function(this, width, height)
			draw.RoundedBox(3, 0, 0, width, height, this:IsHovered() and Color(13, 31, 46, 248) or PANEL_LIGHT)
			surface.SetDrawColor(accent.r, accent.g, accent.b, this:IsHovered() and 210 or 90)
			surface.DrawRect(0, 0, 3, height)
			draw.SimpleText(personnelRecord.online and "●" or "○", "DermaDefaultBold", 18, 32, personnelRecord.online and ONLINE or OFFLINE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(personnelRecord.displayName or personnelRecord.name or "UNKNOWN", "DermaDefaultBold", 38, 11, color_white)
			draw.SimpleText(
				string.upper(personnelRecord.rank or "RCT") .. " • " ..
				getNodeName(personnelRecord.unit, getNodeName(personnelRecord.regiment)) .. " • " ..
				string.upper(REG.GetUnitTypeName(personnelRecord.regiment, personnelRecord.unitType)),
				"DermaDefault",
				38,
				36,
				accent
			)
			draw.SimpleText(personnelRecord.billet ~= "" and prettyID(personnelRecord.billet) or string.upper(personnelRecord.serviceStatus or "active"), "DermaDefaultBold", width - (permission > 0 and 88 or 15), 24, TEXT_MUTED, TEXT_ALIGN_RIGHT)
			if (permission > 0 and personnelRecord.online) then
				draw.SimpleText("EDIT", "DermaDefaultBold", width - 18, 24, accent, TEXT_ALIGN_RIGHT)
			end
		end
		row.DoClick = function()
			if (permission > 0 and personnelRecord.online and input.IsKeyDown(KEY_LSHIFT)) then
				openPersonnelEditor(self, node, personnelRecord, permission)
				return
			end

			net.Start("swrpRegimentsRequestRecord")
			net.WriteUInt(tonumber(personnelRecord.characterID) or 0, 32)
			net.SendToServer()
		end

		if (permission > 0 and personnelRecord.online) then
			local edit = row:Add("DButton")
			edit:Dock(RIGHT)
			edit:SetWide(68)
			edit:SetText("")
			edit.Paint = nil
			edit.DoClick = function()
				openPersonnelEditor(self, node, personnelRecord, permission)
			end
		end
	end
end

function PANEL:GetTrainingForNode(node)
	local sessions = {}

	local function collect(current)
		for index, session in ipairs(getNodeTraining(self.snapshot, current.id)) do
			local copy = table.Copy(session)
			copy.node = current
			copy.index = index
			sessions[#sessions + 1] = copy
		end

		if (current.kind ~= "unit") then
			for _, child in ipairs(REG.GetChildren(current.id)) do
				collect(child)
			end
		end
	end

	collect(node)
	return sessions
end

function PANEL:BuildTrainingView(node)
	local accent = nodeColour(node)
	local sessions = self:GetTrainingForNode(node)
	addSectionHeading(self.content, "Training", string.format("%d published sessions", #sessions), accent)

	if (#sessions == 0) then
		self:AddCompactPanel("No sessions published", "There is currently no scheduled training for this formation.", accent, 80)
		return
	end

	for _, session in ipairs(sessions) do
		local sessionAccent = nodeColour(session.node)
		local card = self.content:Add("DPanel")
		card:Dock(TOP)
		card:SetTall(112)
		card:DockMargin(0, 0, 0, 8)
		card.Paint = function(_, width, height)
			draw.RoundedBox(3, 0, 0, width, height, PANEL_LIGHT)
			surface.SetDrawColor(sessionAccent.r, sessionAccent.g, sessionAccent.b, 185)
			surface.DrawRect(0, 0, 4, height)
			draw.SimpleText(string.upper(session.title or "TRAINING SESSION"), "DermaLarge", 17, 12, color_white)
			draw.SimpleText(session.node.name, "DermaDefaultBold", 19, 47, sessionAccent)
			draw.SimpleText(session.schedule ~= "" and session.schedule or "SCHEDULE PENDING", "DermaDefaultBold", 19, 72, Color(211, 224, 232))
			draw.SimpleText("Instructor: " .. (session.instructor ~= "" and session.instructor or "TBA"), "DermaDefault", 19, 93, TEXT_MUTED)
			draw.SimpleText(session.capacity ~= "" and session.capacity or "OPEN", "DermaDefaultBold", width - 17, 18, sessionAccent, TEXT_ALIGN_RIGHT)
			draw.SimpleText(session.requirements ~= "" and session.requirements or "No additional requirements", "DermaDefault", width - 17, 84, TEXT_MUTED, TEXT_ALIGN_RIGHT)
		end
	end
end

function PANEL:BuildModelsView(node)
	local accent = nodeColour(node)

	if (not self.snapshot.isStaff) then
		self:AddCompactPanel("Access denied", "Only server administrators can configure forced unit-type models.", DANGER, 82)
		return
	end

	local regimentID = REG.GetPrimaryRegiment(node.id)
	local regiment = REG.Get(regimentID)
	local unitTypes = REG.GetUnitTypes(regimentID)

	if (not regiment or #unitTypes == 0) then
		self:AddCompactPanel("No model roles available", "This formation has no configurable unit types.", accent, 82)
		return
	end

	addSectionHeading(self.content, "Unit-Type Models", "Administrator-only playermodel mapping for " .. regiment.name, accent)
	self:AddCompactPanel(
		"One model per unit type",
		"Choose Standard Trooper, Heavy, Medic or another available unit type, then assign a completely separate player-model file. Regiment leaders choose who holds each unit type from Manage Personnel.",
		accent,
		96
	)

	local form = self.content:Add("DPanel")
	form:Dock(TOP)
	form:SetTall(570)
	form:DockMargin(0, 0, 0, 10)
	form:DockPadding(14, 14, 14, 14)
	form.Paint = function(_, width, height)
		draw.RoundedBox(3, 0, 0, width, height, PANEL_LIGHT)
	end

	local selectedUnitType = REG.ResolveUnitType(
		regimentID,
		node.unitType or REG.GetDefaultUnitType(regimentID)
	)
	local selectedUnitTypeData = REG.GetUnitType(regimentID, selectedUnitType)

	local previewShell = form:Add("DPanel")
	previewShell:Dock(LEFT)
	previewShell:SetWide(300)
	previewShell:DockMargin(0, 0, 14, 0)
	previewShell:DockPadding(8, 8, 8, 8)
	previewShell.Paint = function(_, width, height)
		draw.RoundedBox(3, 0, 0, width, height, Color(3, 11, 19, 248))
		drawCorners(0, 0, width, height, colourWithAlpha(accent, 100), 14)
		draw.SimpleText("MODEL PREVIEW", "DermaDefaultBold", 14, 13, accent)
		drawFittedText(
			selectedUnitTypeData and string.upper(selectedUnitTypeData.name) or "UNIT TYPE",
			{"Trebuchet24", "DermaDefaultBold"},
			14,
			36,
			width - 28,
			color_white
		)
	end

	local preview = previewShell:Add("DModelPanel")
	preview:Dock(FILL)
	preview:DockMargin(0, 58, 0, 0)
	preview:SetPaintBackground(false)
	preview:SetMouseInputEnabled(false)
	preview:SetVisible(false)

	local controls = form:Add("DPanel")
	controls:Dock(FILL)
	controls.Paint = nil

	addFieldLabel(controls, "Unit type")
	local unitTypeChoice = controls:Add("DComboBox")
	unitTypeChoice:Dock(TOP)
	unitTypeChoice:SetTall(38)
	unitTypeChoice:SetSortItems(false)

	for _, option in ipairs(unitTypes) do
		unitTypeChoice:AddChoice(option.name, option.id)
	end

	addFieldLabel(controls, "Available player models")
	local modelChoice = controls:Add("DComboBox")
	modelChoice:Dock(TOP)
	modelChoice:SetTall(38)
	modelChoice:SetSortItems(false)

	for _, option in ipairs(collectAvailableModels()) do
		modelChoice:AddChoice(option.label .. "  —  " .. option.path, option.path)
	end

	addFieldLabel(controls, "Player-model path")
	local modelPath = addTextField(controls, "", accent, 38, false)
	modelPath:SetPlaceholderText("models/.../player_model.mdl")

	local status = controls:Add("DLabel")
	status:Dock(TOP)
	status:SetTall(72)
	status:DockMargin(0, 10, 0, 0)
	status:SetFont("DermaDefault")
	status:SetWrap(true)
	status:SetTextColor(TEXT_MUTED)

	local saveButton
	local clearButton

	local function previewPath(path)
		path = cleanModelPath(path)

		if (path == "" or not util.IsValidModel(path)) then
			preview:SetVisible(false)
			return false
		end

		preview:SetVisible(true)
		return applyModelPreview(preview, path, 0, {}, "full")
	end

	local function refreshUnitType()
		selectedUnitTypeData = REG.GetUnitType(regimentID, selectedUnitType)
		local direct = resolveUnitTypeModelAssignment(self.snapshot, regimentID, selectedUnitType)
		local defaultUnitType = REG.GetDefaultUnitType(regimentID)
		local fallback

		if (not direct and selectedUnitType ~= defaultUnitType) then
			fallback = resolveUnitTypeModelAssignment(self.snapshot, regimentID, defaultUnitType)
		end

		local directPath = direct and cleanModelPath(direct.model) or ""
		local previewAssignment = direct or fallback
		local previewModel = previewAssignment and cleanModelPath(previewAssignment.model) or ""

		unitTypeChoice:SetValue(selectedUnitTypeData and selectedUnitTypeData.name or selectedUnitType)
		modelPath:SetText(directPath)
		modelChoice:SetValue(directPath ~= "" and directPath or "Select a distinct playermodel")

		if (direct) then
			status:SetText(
				(selectedUnitTypeData and selectedUnitTypeData.name or "This unit type") ..
				" has its own forced playermodel. Personnel assigned to it are updated immediately and again whenever they spawn."
			)
		elseif (fallback) then
			status:SetText(
				"No separate " .. (selectedUnitTypeData and selectedUnitTypeData.name or selectedUnitType) ..
				" model is configured. It currently falls back to the regiment's " ..
				REG.GetUnitTypeName(regimentID, defaultUnitType) .. " model."
			)
		else
			status:SetText(
				"No model is configured for this unit type. Personnel will use the configured CT model or their faction fallback until one is saved."
			)
		end

		previewPath(previewModel)

		if (IsValid(saveButton)) then
			saveButton:SetText("SAVE " .. string.upper(selectedUnitTypeData and selectedUnitTypeData.name or selectedUnitType) .. " MODEL")
		end

		if (IsValid(clearButton)) then
			clearButton:SetText("CLEAR " .. string.upper(selectedUnitTypeData and selectedUnitTypeData.name or selectedUnitType) .. " MODEL")
			clearButton:SetEnabled(direct ~= nil)
			clearButton:SetVisible(direct ~= nil)
		end
	end

	unitTypeChoice.OnSelect = function(_, _, _, data)
		selectedUnitType = REG.ResolveUnitType(regimentID, data)
		refreshUnitType()
	end

	modelChoice.OnSelect = function(_, _, _, data)
		local path = cleanModelPath(data)
		modelPath:SetText(path)
		previewPath(path)
	end

	modelPath.OnEnter = function()
		if (not previewPath(modelPath:GetValue())) then
			notification.AddLegacy("That model path is not currently valid on your client.", NOTIFY_ERROR, 3)
		end
	end

	addActionButton(controls, "PREVIEW MODEL", accent, function()
		if (not previewPath(modelPath:GetValue())) then
			notification.AddLegacy("That model path is not currently valid on your client.", NOTIFY_ERROR, 3)
		end
	end)

	addActionButton(controls, "USE MY CURRENT MODEL", accent, function()
		if (not IsValid(LocalPlayer())) then return end
		local path = cleanModelPath(LocalPlayer():GetModel())
		modelPath:SetText(path)
		previewPath(path)
	end)

	saveButton = addActionButton(controls, "SAVE UNIT-TYPE MODEL", accent, function()
		local path = cleanModelPath(modelPath:GetValue())

		if (path == "" or not util.IsValidModel(path)) then
			notification.AddLegacy("Select a valid player model before saving.", NOTIFY_ERROR, 3)
			return
		end

		sendManagement("save_model_assignment", regimentID, {
			unitType = selectedUnitType,
			model = path
		})
		timer.Simple(0.45, function()
			if (IsValid(self)) then self:RequestSnapshot() end
		end)
	end)

	clearButton = addActionButton(controls, "CLEAR UNIT-TYPE MODEL", DANGER, function()
		local typeName = selectedUnitTypeData and selectedUnitTypeData.name or selectedUnitType
		Derma_Query(
			"Clear the forced " .. typeName .. " model for " .. regiment.name .. "?\n\nPersonnel of this type will fall back to the regiment's standard model, then the CT/faction model.",
			"Clear Unit-Type Model",
			"CLEAR",
			function()
				sendManagement("clear_model_assignment", regimentID, {
					unitType = selectedUnitType
				})
				timer.Simple(0.45, function()
					if (IsValid(self)) then self:RequestSnapshot() end
				end)
			end,
			"CANCEL"
		)
	end, true)

	refreshUnitType()
end

function PANEL:BuildManageView(node)
	local permission = self:GetPermission(node.id)
	local accent = nodeColour(node)

	if (permission <= 0) then
		self:AddCompactPanel("Access denied", "You do not have management permission for this formation.", DANGER, 82)
		return
	end

	local sections = {}
	if (permission >= 3) then
		sections[#sections + 1] = {id = "regiment", label = "REGIMENT"}
		sections[#sections + 1] = {id = "personnel", label = "PERSONNEL"}
	end
	sections[#sections + 1] = {id = "training", label = "TRAINING"}

	local allowed = false
	for _, section in ipairs(sections) do
		if (section.id == self.manageView) then allowed = true end
	end
	if (not allowed) then self.manageView = sections[1].id end

	local nav = self.content:Add("DPanel")
	nav:Dock(TOP)
	nav:SetTall(40)
	nav:DockMargin(0, 0, 0, 10)
	nav.Paint = nil

	for _, section in ipairs(sections) do
		local sectionID = section.id
		local sectionLabel = section.label
		local button = nav:Add("DButton")
		button:Dock(LEFT)
		button:SetWide(126)
		button:DockMargin(0, 0, 7, 0)
		button:SetText(sectionLabel)
		button:SetFont("DermaDefaultBold")
		button:SetTextColor(color_white)
		button.Paint = function(this, width, height)
			local selected = self.manageView == sectionID
			draw.RoundedBox(3, 0, 0, width, height, selected and colourWithAlpha(accent, 145) or Color(8, 20, 31, 235))
		end
		button.DoClick = function()
			self.manageView = sectionID
			self:RefreshView()
		end
	end

	if (self.manageView == "training") then
		self:BuildManageTraining(node, permission)
	elseif (self.manageView == "personnel") then
		self:BuildManagePersonnel(node, permission)
	else
		self:BuildManageRegiment(node, permission)
	end
end

function PANEL:BuildManageRegiment(node, permission)
	local accent = nodeColour(node)
	local data = mergeNodeData(self.snapshot, node)
	local stateID = self.snapshot.recruitment and self.snapshot.recruitment[node.id] or node.defaultRecruitment
	addSectionHeading(self.content, "Regiment Settings", "Only authorised command staff can see this page", accent)

	local form = self.content:Add("DPanel")
	form:Dock(TOP)
	form:SetTall(620)
	form:DockMargin(0, 0, 0, 10)
	form:DockPadding(14, 10, 14, 14)
	form.Paint = function(_, width, height)
		draw.RoundedBox(3, 0, 0, width, height, PANEL_LIGHT)
	end

	addFieldLabel(form, "Recruitment status")
	local selectedRecruitment = stateID or "closed"
	local recruitment = form:Add("DComboBox")
	recruitment:Dock(TOP)
	recruitment:SetTall(36)
	recruitment:SetValue(string.upper(selectedRecruitment))
	recruitment:AddChoice("OPEN", "open")
	recruitment:AddChoice("SELECTIVE", "selective")
	recruitment:AddChoice("CLOSED", "closed")
	recruitment.OnSelect = function(_, _, _, data)
		selectedRecruitment = data or "closed"
	end

	addFieldLabel(form, "Recruitment notice")
	local notice = addTextField(form, data.recruitmentNotice or "", accent, 58, true)
	notice:SetPlaceholderText("A short message shown to prospective recruits")

	addFieldLabel(form, "Public description")
	local description = addTextField(form, data.description or "", accent, 94, true)

	addFieldLabel(form, "Specialisations — one per line")
	local specialisations = addTextField(form, table.concat(data.specialisations or {}, "\n"), accent, 94, true)

	addFieldLabel(form, "Requirements — one per line")
	local requirements = addTextField(form, table.concat(data.requirements or {}, "\n"), accent, 94, true)

	addActionButton(form, "SAVE REGIMENT SETTINGS", accent, function()
		sendManagement("save_overview", node.id, {
			state = selectedRecruitment,
			description = description:GetValue(),
			recruitmentNotice = notice:GetValue(),
			specialisations = specialisations:GetValue(),
			requirements = requirements:GetValue()
		})
		timer.Simple(0.5, function()
			if (IsValid(self)) then self:RequestSnapshot() end
		end)
	end)
end

function PANEL:BuildManagePersonnel(node, permission)
	local accent = nodeColour(node)
	addSectionHeading(self.content, "Personnel Management", "Players must currently be online for edits", accent)
	local personnel = self:GetPersonnel(node.id, false)

	if (#personnel == 0) then
		self:AddCompactPanel("No assigned personnel", "Assign players with the staff commands or wait for roster records to populate.", accent, 80)
		return
	end

	for _, record in ipairs(personnel) do
		local personnelRecord = record
		local row = self.content:Add("DButton")
		row:Dock(TOP)
		row:SetTall(64)
		row:DockMargin(0, 0, 0, 6)
		row:SetText("")
		row:SetEnabled(personnelRecord.online == true)
		row.Paint = function(this, width, height)
			draw.RoundedBox(3, 0, 0, width, height, personnelRecord.online and (this:IsHovered() and Color(13, 31, 46, 248) or PANEL_LIGHT) or Color(10, 16, 22, 235))
			surface.SetDrawColor(accent.r, accent.g, accent.b, personnelRecord.online and 140 or 35)
			surface.DrawRect(0, 0, 3, height)
			draw.SimpleText(personnelRecord.displayName or personnelRecord.name, "DermaDefaultBold", 15, 11, personnelRecord.online and color_white or TEXT_FAINT)
			draw.SimpleText(string.upper(personnelRecord.rank or "RCT") .. " • " .. getNodeName(personnelRecord.unit, node.name), "DermaDefault", 15, 36, personnelRecord.online and accent or TEXT_FAINT)
			draw.SimpleText(personnelRecord.online and "EDIT RECORD  ›" or "OFFLINE", "DermaDefaultBold", width - 16, 24, personnelRecord.online and accent or OFFLINE, TEXT_ALIGN_RIGHT)
		end
		row.DoClick = function()
			if (personnelRecord.online) then openPersonnelEditor(self, node, personnelRecord, permission) end
		end
	end
end

function PANEL:BuildManageTraining(node, permission)
	local accent = nodeColour(node)
	local sessions = getNodeTraining(self.snapshot, node.id)
	addSectionHeading(self.content, "Published Sessions", "Training staff can add or remove sessions", accent)

	if (#sessions == 0) then
		self:AddCompactPanel("No sessions", "Nothing has been published for this formation yet.", accent, 76)
	else
		for index, session in ipairs(sessions) do
			local sessionIndex = index
			local trainingSession = session
			local card = self.content:Add("DPanel")
			card:Dock(TOP)
			card:SetTall(86)
			card:DockMargin(0, 0, 0, 7)
			card.Paint = function(_, width, height)
				draw.RoundedBox(3, 0, 0, width, height, PANEL_LIGHT)
				draw.SimpleText(string.upper(trainingSession.title or "TRAINING"), "DermaDefaultBold", 14, 12, color_white)
				draw.SimpleText((trainingSession.schedule or "Schedule pending") .. " • " .. (trainingSession.instructor or "TBA"), "DermaDefault", 14, 37, accent)
				draw.SimpleText(trainingSession.requirements or "No additional requirements", "DermaDefault", 14, 60, TEXT_MUTED)
			end
			local remove = card:Add("DButton")
			remove:Dock(RIGHT)
			remove:SetWide(92)
			remove:SetText("REMOVE")
			remove:SetFont("DermaDefaultBold")
			remove:SetTextColor(DANGER)
			remove.Paint = function(this, width, height)
				if (this:IsHovered()) then draw.RoundedBox(3, 0, 0, width, height, Color(95, 30, 36, 130)) end
			end
			remove.DoClick = function()
				sendManagement("delete_training", node.id, {index = sessionIndex})
				timer.Simple(0.45, function()
					if (IsValid(self)) then self:RequestSnapshot() end
				end)
			end
		end
	end

	addSectionHeading(self.content, "Publish Training", nil, accent)
	local form = self.content:Add("DPanel")
	form:Dock(TOP)
	form:SetTall(390)
	form:DockMargin(0, 0, 0, 10)
	form:DockPadding(14, 10, 14, 14)
	form.Paint = function(_, width, height) draw.RoundedBox(3, 0, 0, width, height, PANEL_LIGHT) end

	addFieldLabel(form, "Title")
	local title = addTextField(form, "", accent, 36, false)
	addFieldLabel(form, "Schedule")
	local schedule = addTextField(form, "", accent, 36, false)
	schedule:SetPlaceholderText("SATURDAY • 20:00")
	addFieldLabel(form, "Instructor")
	local instructor = addTextField(form, "", accent, 36, false)
	addFieldLabel(form, "Capacity")
	local capacity = addTextField(form, "OPEN", accent, 36, false)
	addFieldLabel(form, "Requirements")
	local requirements = addTextField(form, "", accent, 48, true)
	addActionButton(form, "PUBLISH SESSION", accent, function()
		sendManagement("add_training", node.id, {
			title = title:GetValue(),
			schedule = schedule:GetValue(),
			instructor = instructor:GetValue(),
			capacity = capacity:GetValue(),
			requirements = requirements:GetValue()
		})
		title:SetText("")
		schedule:SetText("")
		instructor:SetText("")
		requirements:SetText("")
		timer.Simple(0.45, function()
			if (IsValid(self)) then self:RequestSnapshot() end
		end)
	end)
end

vgui.Register("swrpRegimentDirectory", PANEL, "DPanel")
