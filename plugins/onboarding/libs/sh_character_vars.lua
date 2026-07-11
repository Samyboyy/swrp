-- swrp/plugins/onboarding/libs/sh_character_vars.lua
-- Persistent, server-authoritative character variables used by onboarding and progression.

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

local function sanitiseCallsign(value)
	value = tostring(value or "")
	value = value:gsub("[^%w%s%-']", "")
	value = value:gsub("%s+", " ")
	return string.Trim(value):sub(1, 24)
end

local function buildCloneName(number, callsign)
	number = sanitiseCloneNumber(number)
	callsign = sanitiseCallsign(callsign)

	if (callsign == "") then
		return "CT " .. number
	end

	return string.format("CT %s %s", number, callsign)
end

-- The SWRP creator supplies identity itself. Keep Helix's stock fields hidden for clones as a fallback.
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

	local descriptionVar = ix.char.vars.description

	if (descriptionVar and !descriptionVar.SWRPOriginalShouldDisplay) then
		descriptionVar.SWRPOriginalShouldDisplay = descriptionVar.ShouldDisplay or true

		descriptionVar.ShouldDisplay = function(self, container, payload)
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

-- ============================ Identity (networked to all) ============================

ix.char.RegisterVar("cloneNumber", {
	field = "clone_number",
	fieldType = ix.type.string,
	default = "",
	bNoDisplay = true,

	OnValidate = function(self, value, payload)
		if (!isCloneFaction(payload and payload.faction)) then
			return value
		end

		value = sanitiseCloneNumber(value)

		if (#value ~= 4 or value == "0000") then
			return false, "cloneNumberInvalid"
		end

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
		if (!isCloneFaction(data and data.faction)) then
			return
		end

		local number = sanitiseCloneNumber(value)
		local callsign = sanitiseCallsign(data.callsign or newData.callsign)

		newData.cloneNumber = number
		newData.callsign = callsign
		newData.name = buildCloneName(number, callsign)
		newData.rank = "CT"
		newData.regiment = "Unassigned"
	end
})

ix.char.RegisterVar("callsign", {
	field = "callsign",
	fieldType = ix.type.string,
	default = "",
	bNoDisplay = true,

	OnValidate = function(self, value, payload)
		if (!isCloneFaction(payload and payload.faction)) then
			return value
		end

		value = sanitiseCallsign(value)

		if (#value < 2 or #value > 24) then
			return false, "cloneCallsignInvalid"
		end

		return value
	end,

	OnAdjust = function(self, client, data, value, newData)
		if (!isCloneFaction(data and data.faction)) then
			return
		end

		local callsign = sanitiseCallsign(value)
		local number = sanitiseCloneNumber(data.cloneNumber or newData.cloneNumber)

		newData.callsign = callsign
		newData.name = buildCloneName(number, callsign)
	end
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
	isLocal = true,
	bNoDisplay = true,

	OnValidate = function(self, value, payload)
		if (!isCloneFaction(payload and payload.faction)) then
			return value
		end

		value = tostring(value or "")

		if (!SWRP.IsCareerPath(value)) then
			return false, "chooseDoctrine"
		end

		return value
	end,

	OnAdjust = function(self, client, data, value, newData)
		if (!isCloneFaction(data and data.faction)) then
			return
		end

		newData.careerPath = tostring(value or "")
		newData.careerTarget = ""
		newData.progressionCreditVersion = 1
	end
})

-- Retained for records created by the earlier career-target creator. V4 no longer asks
-- a new player to choose a node, so an empty value is valid and expected.
ix.char.RegisterVar("careerTarget", {
	field = "career_target",
	fieldType = ix.type.string,
	default = "",
	isLocal = true,
	bNoDisplay = true,

	OnValidate = function(self, value, payload)
		if (!isCloneFaction(payload and payload.faction)) then
			return value
		end

		value = tostring(value or "")
		if (value == "") then return "" end

		local node = SWRP.GetCareerTarget(value)
		if (!node) then return "" end

		return node.id
	end
})

ix.char.RegisterVar("startingAptitude", {
	field = "starting_aptitude",
	fieldType = ix.type.string,
	default = "",
	isLocal = true,
	bNoDisplay = true,

	OnValidate = function(self, value, payload)
		if (!isCloneFaction(payload and payload.faction)) then
			return value
		end

		value = tostring(value or "")
		if (!SWRP.IsStartingAptitude(value)) then
			return false, "chooseStartingAptitude"
		end

		return value
	end
})

ix.char.RegisterVar("startingAptitudeApplied", {
	field = "starting_aptitude_applied",
	fieldType = ix.type.bool,
	default = false,
	isLocal = true,
	bNoDisplay = true
})

ix.char.RegisterVar("progressionCreditVersion", {
	field = "progression_credit_version",
	fieldType = ix.type.number,
	default = 0,
	isLocal = true,
	bNoDisplay = true
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
