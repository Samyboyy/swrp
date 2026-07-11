-- swrp/plugins/onboarding/derma/cl_character_menu.lua
-- Republic-facing character menu copy and a service-record character loader.

local function safeCharacterValue(character, getter, fallback)
	if (!character or !isfunction(character[getter])) then
		return fallback
	end

	local value = character[getter](character)

	if (value == nil or value == "") then
		return fallback
	end

	return value
end

local roleCapabilities = {
	{"combat_medic", "Combat Medic"},
	{"medic", "Field Medic"},
	{"advanced_pilot", "Advanced Pilot"},
	{"pilot", "Republic Pilot"},
	{"weapons_specialist", "Weapons Specialist"},
	{"launcher_weapons", "Launcher Specialist"},
	{"heavy_weapons", "Heavy Weapons Trooper"},
	{"marksman", "Marksman"}
}

local function getCharacterRole(character)
	local datapad = SWRP and SWRP.Datapad

	if (datapad and isfunction(datapad.HasCapability)) then
		for _, definition in ipairs(roleCapabilities) do
			if (datapad.HasCapability(character, definition[1])) then
				return definition[2]
			end
		end
	end

	local path = SWRP.GetCareerPath(safeCharacterValue(character, "GetCareerPath", ""))

	if (path) then
		return path.shortTitle .. " Aspirant"
	end

	return "Clone Trooper"
end

local function getCareerProgress(character, pathID)
	local tree = SWRP and SWRP.Datapad and SWRP.Datapad.UpgradeTree

	if (!tree or !istable(tree.branches) or !isfunction(tree.GetMask) or !isfunction(tree.IsUnlocked)) then
		return 0, 0, "Open the upgrade network to begin"
	end

	local branch

	for _, candidate in ipairs(tree.branches) do
		if (candidate.id == pathID) then
			branch = candidate
			break
		end
	end

	if (!branch) then
		return 0, 0, "Choose a career interest"
	end

	local mask = tree.GetMask(character)
	local unlocked = 0
	local nextNode

	for _, node in ipairs(branch.nodes or {}) do
		if (tree.IsUnlocked(mask, node)) then
			unlocked = unlocked + 1
		elseif (!nextNode and (!isfunction(tree.PrerequisitesMet) or tree.PrerequisitesMet(mask, node))) then
			nextNode = node
		end
	end

	if (!nextNode) then
		for _, node in ipairs(branch.nodes or {}) do
			if (!tree.IsUnlocked(mask, node)) then
				nextNode = node
				break
			end
		end
	end

	return unlocked, #(branch.nodes or {}), nextNode and nextNode.title or "Career path complete"
end

local function addLabel(parent, font, colour)
	local label = parent:Add("DLabel")
	label:SetFont(font)
	label:SetTextColor(colour or color_white)
	label:SetText("")
	return label
end

DEFINE_BASECLASS("ixCharMenuLoad")

local PANEL = {}

function PANEL:Init()
	BaseClass.Init(self)

	self.panel:SetTitle("ACCESS SERVICE RECORD", true)

	local infoPanel = self.carousel:GetParent()
	local padding = ScreenScale(8)

	self.serviceRecord = infoPanel:Add("Panel")
	self.serviceRecord:Dock(LEFT)
	self.serviceRecord:DockMargin(0, 0, padding, 0)
	self.serviceRecord:SetWide(math.max(ScrW() * 0.235, ScreenScale(205)))
	self.serviceRecord:SetZPos(-100)

	self.serviceRecord.Paint = function(panel, width, height)
		surface.SetDrawColor(5, 8, 13, 225)
		surface.DrawRect(0, 0, width, height)

		local accent = ix.config.Get("color", color_white)
		surface.SetDrawColor(accent.r, accent.g, accent.b, 225)
		surface.DrawRect(0, 0, 2, height)
		surface.DrawRect(0, 0, width, 1)
	end

	self.recordEyebrow = addLabel(self.serviceRecord, "ixMenuMiniFont", Color(255, 255, 255, 115))
	self.recordEyebrow:SetText("CURRENT PERSONNEL FILE")
	self.recordEyebrow:SizeToContents()

	self.recordName = addLabel(self.serviceRecord, "ixMenuButtonHugeFont")
	self.recordRole = addLabel(self.serviceRecord, "ixMenuButtonFont", ix.config.Get("color", color_white))
	self.recordAssignment = addLabel(self.serviceRecord, "ixMenuMiniFont", Color(255, 255, 255, 180))

	self.recordDivider = self.serviceRecord:Add("Panel")
	self.recordDivider.Paint = function(panel, width, height)
		surface.SetDrawColor(255, 255, 255, 25)
		surface.DrawRect(0, 0, width, 1)
	end

	self.recordCareerLabel = addLabel(self.serviceRecord, "ixMenuMiniFont", Color(255, 255, 255, 105))
	self.recordCareerLabel:SetText("TRACKED CAREER")
	self.recordCareerLabel:SizeToContents()
	self.recordCareer = addLabel(self.serviceRecord, "ixMenuButtonFont")
	self.recordProgress = addLabel(self.serviceRecord, "ixMenuMiniFont", Color(255, 255, 255, 175))

	self.recordNextLabel = addLabel(self.serviceRecord, "ixMenuMiniFont", Color(255, 255, 255, 105))
	self.recordNextLabel:SetText("NEXT DEVELOPMENT TARGET")
	self.recordNextLabel:SizeToContents()
	self.recordNext = addLabel(self.serviceRecord, "ixMenuButtonFont")
	self.recordNext:SetWrap(true)
	self.recordNext:SetAutoStretchVertical(true)

	self.recordDescriptionLabel = addLabel(self.serviceRecord, "ixMenuMiniFont", Color(255, 255, 255, 105))
	self.recordDescriptionLabel:SetText("PERSONNEL NOTES")
	self.recordDescriptionLabel:SizeToContents()
	self.recordDescription = addLabel(self.serviceRecord, "ixMenuMiniFont", Color(255, 255, 255, 155))
	self.recordDescription:SetWrap(true)
	self.recordDescription:SetContentAlignment(7)

	self.serviceRecord.PerformLayout = function(panel, width, height)
		local pad = ScreenScale(10)
		local y = pad

		self.recordEyebrow:SetPos(pad, y)
		y = y + self.recordEyebrow:GetTall() + ScreenScale(4)

		self.recordName:SetPos(pad, y)
		self.recordName:SetWide(width - pad * 2)
		self.recordName:SizeToContentsY()
		y = y + self.recordName:GetTall()

		self.recordRole:SetPos(pad, y)
		self.recordRole:SetWide(width - pad * 2)
		self.recordRole:SizeToContentsY()
		y = y + self.recordRole:GetTall() + ScreenScale(2)

		self.recordAssignment:SetPos(pad, y)
		self.recordAssignment:SetWide(width - pad * 2)
		self.recordAssignment:SizeToContentsY()
		y = y + self.recordAssignment:GetTall() + ScreenScale(8)

		self.recordDivider:SetPos(pad, y)
		self.recordDivider:SetSize(width - pad * 2, 1)
		y = y + ScreenScale(9)

		self.recordCareerLabel:SetPos(pad, y)
		y = y + self.recordCareerLabel:GetTall() + ScreenScale(2)
		self.recordCareer:SetPos(pad, y)
		self.recordCareer:SetWide(width - pad * 2)
		self.recordCareer:SizeToContentsY()
		y = y + self.recordCareer:GetTall() + ScreenScale(1)
		self.recordProgress:SetPos(pad, y)
		self.recordProgress:SetWide(width - pad * 2)
		self.recordProgress:SizeToContentsY()
		y = y + self.recordProgress:GetTall() + ScreenScale(10)

		self.recordNextLabel:SetPos(pad, y)
		y = y + self.recordNextLabel:GetTall() + ScreenScale(2)
		self.recordNext:SetPos(pad, y)
		self.recordNext:SetWide(width - pad * 2)
		self.recordNext:SizeToContentsY()
		y = y + self.recordNext:GetTall() + ScreenScale(10)

		self.recordDescriptionLabel:SetPos(pad, y)
		y = y + self.recordDescriptionLabel:GetTall() + ScreenScale(2)
		self.recordDescription:SetPos(pad, y)
		self.recordDescription:SetSize(width - pad * 2, math.max(height - y - pad, ScreenScale(35)))
	end

	-- The carousel now fills the remaining space to the right of the record card.
	self.carousel:SetZPos(0)
	infoPanel:InvalidateLayout(true)

	-- Reword the stock actions without replacing their proven Helix behaviour.
	local function relabel(root)
		for _, child in ipairs(root:GetChildren()) do
			if (child.GetText and child.SetText and child:GetClassName() == "ixMenuButton") then
				local text = string.lower(string.Trim(child:GetText() or ""))

				if (text == "choose" or text == string.lower(L("choose"))) then
					child:SetText("DEPLOY", true)
					child:SizeToContents()
				elseif (text == "delete" or text == string.lower(L("delete"))) then
					child:SetText("DELETE RECORD", true)
					child:SizeToContents()
				end
			end

			relabel(child)
		end
	end

	relabel(self)
end

function PANEL:UpdateServiceRecord(character)
	if (!IsValid(self.serviceRecord)) then
		return
	end

	if (!character) then
		self.recordName:SetText("NO RECORD SELECTED")
		self.recordRole:SetText("")
		self.recordAssignment:SetText("")
		self.recordCareer:SetText("Unassigned")
		self.recordProgress:SetText("")
		self.recordNext:SetText("")
		self.recordDescription:SetText("")
		self.serviceRecord:InvalidateLayout(true)
		return
	end

	local pathID = safeCharacterValue(character, "GetCareerPath", "")
	local path = SWRP.GetCareerPath(pathID)
	local rank = safeCharacterValue(character, "GetRank", "CT")
	local regiment = safeCharacterValue(character, "GetRegiment", "Unassigned")
	local level = math.max(tonumber(safeCharacterValue(character, "GetLevel", 1)) or 1, 1)
	local unlocked, total, nextTarget = getCareerProgress(character, pathID)
	local description = tostring(character:GetDescription() or "No personnel notes supplied.")

	if (#description > 260) then
		description = description:sub(1, 257) .. "..."
	end

	self.recordName:SetText(character:GetName():utf8upper())
	self.recordRole:SetText(getCharacterRole(character):utf8upper())
	self.recordAssignment:SetText(string.format("%s  /  %s  /  LEVEL %d", rank, regiment, level))
	self.recordCareer:SetText(path and path.title or "UNASSIGNED")
	self.recordCareer:SetTextColor(path and path.colour or color_white)
	self.recordProgress:SetText(total > 0 and string.format("%d OF %d QUALIFICATIONS RECORDED", unlocked, total) or "NO QUALIFICATIONS RECORDED")
	self.recordNext:SetText(tostring(nextTarget or "Open the upgrade network to begin"):utf8upper())
	self.recordDescription:SetText(description)
	self.serviceRecord:InvalidateLayout(true)
end

function PANEL:Populate(ignoreID)
	BaseClass.Populate(self, ignoreID)
	self:UpdateServiceRecord(self.character)
end

function PANEL:OnCharacterButtonSelected(button)
	BaseClass.OnCharacterButtonSelected(self, button)
	self:UpdateServiceRecord(button.character)
end

vgui.Register("swrpCharMenuLoad", PANEL, "ixCharMenuLoad")

function PLUGIN:OnCharacterMenuCreated(menu)
	-- Replace only the load panel, retaining Helix networking/deletion/selection behaviour
	-- through inheritance. Existing main-menu closures reference menu.loadCharacterPanel at
	-- click time, so they continue to work with the replacement.
	if (IsValid(menu.loadCharacterPanel)) then
		menu.loadCharacterPanel:Remove()
	end

	menu.loadCharacterPanel = menu:Add("swrpCharMenuLoad")
	menu.loadCharacterPanel:SlideDown(0)

	local main = menu.mainPanel

	if (IsValid(main) and IsValid(main.mainButtonList)) then
		local buttons = main.mainButtonList:GetCanvas():GetChildren()
		local menuButtons = {}

		for _, button in ipairs(buttons) do
			if (button:GetClassName() == "ixMenuButton") then
				menuButtons[#menuButtons + 1] = button
			end
		end

		if (IsValid(menuButtons[1])) then
			menuButtons[1]:SetText("CREATE PERSONNEL RECORD", true)
			menuButtons[1]:SizeToContents()
		end

		if (IsValid(main.loadButton)) then
			main.loadButton:SetText("ACCESS SERVICE RECORD", true)
			main.loadButton:SizeToContents()
		end

		local originalUpdateReturnButton = main.UpdateReturnButton
		main.UpdateReturnButton = function(panel, value)
			originalUpdateReturnButton(panel, value)
			panel.returnButton:SetText(panel.bUsingCharacter and "RETURN TO DEPLOYMENT" or "DISCONNECT", true)
			panel.returnButton:SizeToContents()
			panel.mainButtonList:SizeToContents()
		end
		main:UpdateReturnButton()
		main.mainButtonList:SizeToContents()
	end

	local creator = menu.newCharacterPanel

	if (IsValid(creator)) then
		if (IsValid(creator.factionPanel)) then
			creator.factionPanel:SetTitle("SELECT PERSONNEL TYPE", true)
		end

		if (IsValid(creator.description)) then
			creator.description:SetTitle("CREATE PERSONNEL RECORD", true)
		end

		if (IsValid(creator.attributes)) then
			creator.attributes:SetTitle("FINALISE SERVICE RECORD", true)
		end
	end
end
