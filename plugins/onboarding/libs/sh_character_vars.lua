-- swrp/plugins/onboarding/libs/sh_character_vars.lua
-- Persistent, server-authoritative character variables.

SWRP = SWRP or {}

local function isCloneFaction(factionIndex)
	local faction = ix.faction.indices[tonumber(factionIndex) or -1]

	if (!faction) then
		return false
	end

	return faction.uniqueID == "clone_trooper"
		or (FACTION_CLONE and faction.index == FACTION_CLONE)
end

local function sanitiseCloneNumber(value)
	return tostring(value or ""):gsub("%D", ""):sub(1, 4)
end

-- Hide Helix's free-form name box for clone characters. The clone designation control below
-- writes the authoritative CT-#### name into the creation payload instead.
do
	local nameVar = ix.char.vars.name

	if (nameVar and !nameVar.SWRPOriginalShouldDisplay) then
		nameVar.SWRPOriginalShouldDisplay = nameVar.ShouldDisplay or true

		nameVar.ShouldDisplay = function(self, container, payload)
			if (isCloneFaction(payload.faction)) then
				return false
			end

			if (isfunction(self.SWRPOriginalShouldDisplay)) then
				return self:SWRPOriginalShouldDisplay(container, payload)
			end

			return true
		end
	end
end

-- Give the description field useful guidance without replacing Helix's validation/layout.
do
	local descriptionVar = ix.char.vars.description

	if (descriptionVar and !descriptionVar.SWRPOriginalOnPostSetup) then
		descriptionVar.SWRPOriginalOnPostSetup = descriptionVar.OnPostSetup

		descriptionVar.OnPostSetup = function(self, panel, payload)
			if (isfunction(self.SWRPOriginalOnPostSetup)) then
				self:SWRPOriginalOnPostSetup(panel, payload)
			end

			if (panel.SetPlaceholderText) then
				panel:SetPlaceholderText("Temperament, habits and distinguishing behaviour. Do not claim ranks or qualifications you have not earned.")
			end
		end
	end
end

-- ============================ Identity (networked to all) ============================

ix.char.RegisterVar("cloneNumber", {
	field = "clone_number",
	fieldType = ix.type.string,
	default = "",
	index = 1.1,
	category = "description",

	ShouldDisplay = function(self, container, payload)
		return isCloneFaction(payload.faction)
	end,

	OnDisplay = function(self, container, payload)
		local panel = container:Add("Panel")
		panel:Dock(TOP)
		panel:SetTall(ScreenScale(38))
		panel.entries = {}
		panel.bUpdating = false

		local accent = ix.config.Get("color", color_white)
		local current = sanitiseCloneNumber(payload.cloneNumber)

		if (#current ~= 4 or current == "0000") then
			current = string.format("%04d", math.random(1, 9999))
		end

		local function updatePayload()
			local digits = ""

			for i = 1, 4 do
				digits = digits .. sanitiseCloneNumber(panel.entries[i]:GetValue()):sub(1, 1)
			end

			payload:Set("cloneNumber", digits)
			payload:Set("name", "CT-" .. digits)
		end

		local function applyDigits(digits)
			digits = sanitiseCloneNumber(digits)
			panel.bUpdating = true

			for i = 1, 4 do
				panel.entries[i]:SetText(digits:sub(i, i))
			end

			panel.bUpdating = false
			updatePayload()
		end

		for i = 1, 4 do
			local entry = panel:Add("DTextEntry")
			entry:SetFont("ixMenuButtonHugeFont")
			entry:SetTextColor(color_white)
			entry:SetDrawLanguageID(false)
			entry:SetUpdateOnType(true)
			entry:SetContentAlignment(5)
			entry:SetNumeric(true)
			entry:SetPaintBackground(false)
			entry.digitIndex = i

			entry.Paint = function(this, width, height)
				surface.SetDrawColor(255, 255, 255, 18)
				surface.DrawRect(0, 0, width, height)

				local colour = this:HasFocus() and accent or Color(255, 255, 255, 55)
				surface.SetDrawColor(colour)
				surface.DrawOutlinedRect(0, 0, width, height, 1)
				this:DrawTextEntryText(color_white, accent, color_white)
			end

			entry.OnGetFocus = function(this)
				this:SelectAllText()
			end

			entry.OnTextChanged = function(this)
				if (panel.bUpdating) then
					return
				end

				local clean = sanitiseCloneNumber(this:GetValue())

				-- Pasting several digits into one box distributes them across the remaining boxes.
				if (#clean > 1) then
					panel.bUpdating = true

					for offset = 0, math.min(#clean - 1, 4 - this.digitIndex) do
						panel.entries[this.digitIndex + offset]:SetText(clean:sub(offset + 1, offset + 1))
					end

					panel.bUpdating = false
				elseif (this:GetValue() ~= clean) then
					panel.bUpdating = true
					this:SetText(clean)
					panel.bUpdating = false
				end

				updatePayload()

				if (#clean > 0 and this.digitIndex < 4) then
					panel.entries[this.digitIndex + 1]:RequestFocus()
				end
			end

			local baseOnKeyCodeTyped = entry.OnKeyCodeTyped

			entry.OnKeyCodeTyped = function(this, keyCode)
				if (keyCode == KEY_BACKSPACE and this:GetValue() == "" and this.digitIndex > 1) then
					local previous = panel.entries[this.digitIndex - 1]
					previous:RequestFocus()
					previous:SelectAllText()
					return
				end

				if (baseOnKeyCodeTyped) then
					baseOnKeyCodeTyped(this, keyCode)
				end
			end

			panel.entries[i] = entry
		end

		panel.randomise = panel:Add("ixMenuButton")
		panel.randomise:SetText("RANDOMISE", true)
		panel.randomise:SetContentAlignment(5)
		panel.randomise:SizeToContents()
		panel.randomise.DoClick = function()
			applyDigits(string.format("%04d", math.random(1, 9999)))
		end

		panel.preview = panel:Add("DLabel")
		panel.preview:SetFont("ixMenuMiniFont")
		panel.preview:SetTextColor(Color(255, 255, 255, 150))
		panel.preview:SetText("Your permanent service designation")
		panel.preview:SizeToContents()

		panel.PerformLayout = function(this, width, height)
			local gap = ScreenScale(3)
			local box = math.min(ScreenScale(28), height - ScreenScale(8))
			local y = math.floor((height - box) * 0.5)

			for i = 1, 4 do
				this.entries[i]:SetSize(box, box)
				this.entries[i]:SetPos((i - 1) * (box + gap), y)
			end

			local x = (box + gap) * 4 + ScreenScale(5)
			this.randomise:SetPos(x, y)
			this.randomise:SetTall(box)
			this.preview:SetPos(x + this.randomise:GetWide() + ScreenScale(6), math.floor((height - this.preview:GetTall()) * 0.5))
		end

		applyDigits(current)

		return panel
	end,

	OnValidate = function(self, value, payload, client)
		value = sanitiseCloneNumber(value)

		if (#value ~= 4 or value == "0000") then
			return false, "cloneNumberInvalid"
		end

		-- Fast in-memory collision check. A database-level reservation can be added later for
		-- guaranteed uniqueness across players who have not connected since a restart.
		if (SERVER) then
			for _, character in pairs(ix.char.loaded) do
				if (character:GetCloneNumber("") == value) then
					return false, "cloneNumberTaken"
				end
			end
		end

		return value
	end,

	OnAdjust = function(self, client, data, value, newData)
		local cloneNumber = sanitiseCloneNumber(value)
		newData.cloneNumber = cloneNumber
		newData.name = "CT-" .. cloneNumber
		newData.callsign = ""
		newData.rank = "CT"
		newData.regiment = "Unassigned"
	end
})

ix.char.RegisterVar("callsign", {
	field = "callsign",
	fieldType = ix.type.string,
	default = "",
	bNoDisplay = true
})

ix.char.RegisterVar("rank", {
	field = "rank",
	fieldType = ix.type.string,
	default = "",
	bNoDisplay = true
})

ix.char.RegisterVar("regiment", {
	field = "regiment",
	fieldType = ix.type.string,
	default = "",
	bNoDisplay = true
})

-- ============================ Progression (owner-local) ============================

ix.char.RegisterVar("careerPath", {
	field = "career_path",
	fieldType = ix.type.string,
	default = "",
	index = 2.5,
	category = "description",
	isLocal = true,

	ShouldDisplay = function(self, container, payload)
		return isCloneFaction(payload.faction)
	end,

	OnDisplay = function(self, container, payload)
		local panel = container:Add("Panel")
		panel:Dock(TOP)
		panel:SetTall(ScreenScale(142))
		panel.buttons = {}

		for _, pathID in ipairs(SWRP.CareerPathOrder or {}) do
			local path = SWRP.GetCareerPath(pathID)
			local button = panel:Add("DButton")
			button:SetText("")
			button:SetCursor("hand")
			button.pathID = pathID

			button.DoClick = function(this)
				payload:Set("careerPath", this.pathID)
			end

			button.Paint = function(this, width, height)
				local selected = payload.careerPath == this.pathID
				local hovered = this:IsHovered()
				local colour = path.colour or color_white

				surface.SetDrawColor(255, 255, 255, selected and 30 or (hovered and 20 or 10))
				surface.DrawRect(0, 0, width, height)

				surface.SetDrawColor(colour.r, colour.g, colour.b, selected and 255 or (hovered and 180 or 85))
				surface.DrawOutlinedRect(0, 0, width, height, selected and 2 or 1)
				surface.DrawRect(0, 0, selected and 4 or 2, height)

				draw.SimpleText(path.title, "ixMenuButtonFont", ScreenScale(7), ScreenScale(6), selected and colour or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				draw.SimpleText(path.description, "ixMenuMiniFont", ScreenScale(7), ScreenScale(21), Color(255, 255, 255, 165), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				draw.SimpleText(path.preview, "ixMenuMiniFont", ScreenScale(7), height - ScreenScale(8), colour, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			end

			panel.buttons[#panel.buttons + 1] = button
		end

		panel.PerformLayout = function(this, width, height)
			local gap = ScreenScale(4)
			local cardWidth = math.floor((width - gap) * 0.5)
			local cardHeight = math.floor((height - gap) * 0.5)

			for i, button in ipairs(this.buttons) do
				local column = (i - 1) % 2
				local row = math.floor((i - 1) / 2)
				button:SetSize(cardWidth, cardHeight)
				button:SetPos(column * (cardWidth + gap), row * (cardHeight + gap))
			end
		end

		return panel
	end,

	OnValidate = function(self, value)
		value = tostring(value or "")

		if (!SWRP.IsCareerPath(value)) then
			return false, "chooseCareerPath"
		end

		return value
	end
})

ix.char.RegisterVar("xp", {
	field = "xp",
	fieldType = ix.type.number,
	default = 0,
	isLocal = true,
	bNoDisplay = true
})

ix.char.RegisterVar("level", {
	field = "level",
	fieldType = ix.type.number,
	default = 1,
	isLocal = true,
	bNoDisplay = true
})

ix.char.RegisterVar("preferredRegiment", {
	field = "preferred_regiment",
	fieldType = ix.type.string,
	default = "",
	isLocal = true,
	bNoDisplay = true
})

ix.char.RegisterVar("skillPoints", {
	field = "skill_points",
	fieldType = ix.type.number,
	default = 0,
	isLocal = true,
	bNoDisplay = true
})

ix.char.RegisterVar("freeChangePointsSpent", {
	field = "free_change_points_spent",
	fieldType = ix.type.number,
	default = 0,
	isLocal = true,
	bNoDisplay = true
})

ix.char.RegisterVar("buildLocked", {
	field = "build_locked",
	fieldType = ix.type.bool,
	default = false,
	isLocal = true,
	bNoDisplay = true
})

-- ============================ Training progress ============================

ix.char.RegisterVar("trainingCompleted", {
	field = "training_completed",
	fieldType = ix.type.bool,
	default = false,
	isLocal = true,
	bNoDisplay = true
})

ix.char.RegisterVar("trainingStage", {
	field = "training_stage",
	fieldType = ix.type.number,
	default = 0,
	isLocal = true,
	bNoDisplay = true
})

ix.char.RegisterVar("trainingCompletedAt", {
	field = "training_completed_at",
	fieldType = ix.type.number,
	default = 0,
	bNoNetworking = true,
	bNoDisplay = true
})

ix.char.RegisterVar("trainingVersion", {
	field = "training_version",
	fieldType = ix.type.number,
	default = 0,
	bNoNetworking = true,
	bNoDisplay = true
})

-- ============================ Contact (server only) ============================

ix.char.RegisterVar("discordUsername", {
	field = "discord_username",
	fieldType = ix.type.string,
	default = "",
	bNoNetworking = true,
	bNoDisplay = true
})
