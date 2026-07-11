-- swrp/plugins/regiments/libs/sh_registry.lua
-- Shared regiment hierarchy and presentation definitions.

SWRP = SWRP or {}
SWRP.Regiments = SWRP.Regiments or {}

local REG = SWRP.Regiments
REG.nodes = {}
REG.order = {}

REG.recruitmentStates = {
	open = {
		label = "OPEN",
		colour = Color(92, 218, 156)
	},
	selective = {
		label = "SELECTIVE",
		colour = Color(239, 183, 73)
	},
	closed = {
		label = "CLOSED",
		colour = Color(224, 91, 91)
	}
}

REG.rankOrder = {
	"RCT",
	"PVT",
	"PFC",
	"LCPL",
	"CPL",
	"SGT",
	"SSGT",
	"MSGT",
	"2LT",
	"1LT",
	"CPT",
	"MJR",
	"LCOL",
	"COL",
	"GRL"
}

REG.rankNames = {
	RCT = "Recruit",
	PVT = "Private",
	PFC = "Private First Class",
	LCPL = "Lance Corporal",
	CPL = "Corporal",
	SGT = "Sergeant",
	SSGT = "Staff Sergeant",
	MSGT = "Master Sergeant",
	["2LT"] = "2nd Lieutenant",
	["1LT"] = "1st Lieutenant",
	CPT = "Captain",
	MJR = "Major",
	LCOL = "Lieutenant Colonel",
	COL = "Colonel",
	GRL = "General"
}

REG.rankWeights = {}
for index, abbreviation in ipairs(REG.rankOrder) do
	REG.rankWeights[abbreviation] = index * 10
end

-- Legacy values from the earliest prototype are migrated into the final rank set.
REG.rankAliases = {
	CT = "RCT",
	CR = "RCT",
	GEN = "GRL",
	MAJ = "MJR",
	LT = "2LT",
	["2NDLT"] = "2LT",
	["1STLT"] = "1LT"
}


-- Server owner bootstrap access. This avoids being locked out before the normal
-- Garry's Mod/Helix admin group has been configured on a fresh development server.
-- Remove or replace these values before distributing the schema publicly.
REG.ownerSteamIDs = REG.ownerSteamIDs or {
    ["STEAM_0:0:59791733"] = true,
    ["76561198079849194"] = true
}

-- Management levels are deliberately simple:
-- 1 = training/record assistance, 2 = personnel management, 3 = full regiment control.
REG.managementBillets = REG.managementBillets or {
    marshal_commander = {level = 3, minimumRank = "CPT"},
    high_command_adjutant = {level = 3, minimumRank = "2LT"},
    commanding_officer = {level = 3, minimumRank = "2LT"},
    executive_officer = {level = 3, minimumRank = "2LT"},
    naval_commanding_officer = {level = 3, minimumRank = "2LT"},
    company_commander = {level = 3, minimumRank = "SGT"},
    company_executive = {level = 2, minimumRank = "SGT"},
    senior_nco = {level = 2, minimumRank = "SGT"},
    medical_lead = {level = 2, minimumRank = "SGT"},
    air_group_commander = {level = 2, minimumRank = "SGT"}
}

REG.browseOrder = {
    "501st",
    "212th",
    "republic_navy"
}

local function normaliseID(value)
	return string.lower(string.Trim(tostring(value or "")))
		:gsub("[%s%-]+", "_")
		:gsub("[^%w_]", "")
end

function REG.Register(id, data)
	id = normaliseID(id)

	if (id == "" or not istable(data)) then
		return
	end

	data.id = id
	data.name = data.name or id
	data.shortName = data.shortName or data.name
	data.kind = data.kind or "unit"
	data.colour = data.colour or Color(72, 164, 220)
	data.description = data.description or "No public briefing is currently available."
	data.specialisations = data.specialisations or {}
	data.requirements = data.requirements or {}
	data.commandPositions = data.commandPositions or {}
	data.trainingSessions = data.trainingSessions or {}
	data.defaultRecruitment = data.defaultRecruitment or "closed"
	data.aliases = data.aliases or {}
	data.tagline = data.tagline or data.description
	data.browseVisible = data.browseVisible ~= false
	data.unitTypes = istable(data.unitTypes) and data.unitTypes or {}
	data.unitTypeLookup = {}

	for index, unitType in ipairs(data.unitTypes) do
		if (istable(unitType)) then
			local unitTypeID = normaliseID(unitType.id or unitType.name)

			if (unitTypeID ~= "") then
				unitType.id = unitTypeID
				unitType.name = unitType.name or unitTypeID
				unitType.description = unitType.description or ""
				unitType.aliases = istable(unitType.aliases) and unitType.aliases or {}
				data.unitTypeLookup[unitTypeID] = unitType
				data.unitTypes[index] = unitType
			end
		end
	end

	data.defaultUnitType = normaliseID(data.defaultUnitType or (data.unitTypes[1] and data.unitTypes[1].id) or "")

	if (data.defaultUnitType == "" or not data.unitTypeLookup[data.defaultUnitType]) then
		data.defaultUnitType = data.unitTypes[1] and data.unitTypes[1].id or ""
	end

	REG.nodes[id] = data
	REG.order[#REG.order + 1] = id
end

function REG.FindID(value)
	local wanted = normaliseID(value)

	if (wanted == "") then
		return nil
	end

	if (REG.nodes[wanted]) then
		return wanted
	end

	for id, node in pairs(REG.nodes) do
		if (normaliseID(node.name) == wanted or normaliseID(node.shortName) == wanted) then
			return id
		end

		for _, alias in ipairs(node.aliases or {}) do
			if (normaliseID(alias) == wanted) then
				return id
			end
		end
	end

	return nil
end

function REG.ResolveID(value)
	local wanted = normaliseID(value)

	if (wanted == "" or wanted == "none") then
		return "unassigned"
	end

	return REG.FindID(value) or "unassigned"
end

function REG.Get(id)
	return REG.nodes[REG.ResolveID(id)]
end

function REG.GetChildren(parentID)
	parentID = REG.ResolveID(parentID)
	local children = {}

	for _, id in ipairs(REG.order) do
		local node = REG.nodes[id]

		if (node.parent == parentID) then
			children[#children + 1] = node
		end
	end

	return children
end

function REG.GetPrimaryRegiment(nodeID)
	local node = REG.Get(nodeID)
	local safety = 0

	while (node and safety < 16) do
		if (node.kind == "regiment" or node.kind == "command" or node.id == "unassigned") then
			return node.id
		end

		node = REG.Get(node.parent)
		safety = safety + 1
	end

	return "unassigned"
end

function REG.IsDescendant(nodeID, parentID)
	nodeID = REG.ResolveID(nodeID)
	parentID = REG.ResolveID(parentID)
	local node = REG.Get(nodeID)
	local safety = 0

	while (node and safety < 16) do
		if (node.id == parentID) then
			return true
		end

		node = REG.Get(node.parent)
		safety = safety + 1
	end

	return false
end

function REG.NormalizeRank(rank)
	local clean = string.upper(string.Trim(tostring(rank or "")))
	clean = REG.rankAliases[clean] or clean

	if (REG.rankWeights[clean]) then
		return clean
	end

	return nil
end

function REG.IsValidRank(rank)
	return REG.NormalizeRank(rank) ~= nil
end

function REG.GetRankWeight(rank)
	local clean = REG.NormalizeRank(rank)
	return clean and REG.rankWeights[clean] or 0
end

function REG.GetRankName(rank)
	local clean = REG.NormalizeRank(rank)
	return clean and REG.rankNames[clean] or "Unknown Rank"
end

function REG.GetRegimentPrefix(regimentID)
	local primaryID = REG.GetPrimaryRegiment(regimentID)
	local node = REG.Get(primaryID)
	return node and node.namePrefix or "CT"
end

function REG.GetUnitTypes(regimentID)
	local primaryID = REG.GetPrimaryRegiment(regimentID)
	local node = REG.Get(primaryID)
	return node and node.unitTypes or {}
end

function REG.GetUnitType(regimentID, unitTypeID)
	local primaryID = REG.GetPrimaryRegiment(regimentID)
	local node = REG.Get(primaryID)

	if (not node) then
		return nil
	end

	local wanted = normaliseID(unitTypeID)

	if (wanted ~= "" and node.unitTypeLookup and node.unitTypeLookup[wanted]) then
		return node.unitTypeLookup[wanted]
	end

	for _, unitType in ipairs(node.unitTypes or {}) do
		if (normaliseID(unitType.name) == wanted) then
			return unitType
		end

		for _, alias in ipairs(unitType.aliases or {}) do
			if (normaliseID(alias) == wanted) then
				return unitType
			end
		end
	end

	return nil
end

function REG.GetDefaultUnitType(regimentID)
	local primaryID = REG.GetPrimaryRegiment(regimentID)
	local node = REG.Get(primaryID)
	return node and node.defaultUnitType or ""
end

function REG.ResolveUnitType(regimentID, unitTypeID)
	local unitType = REG.GetUnitType(regimentID, unitTypeID)

	if (unitType) then
		return unitType.id
	end

	return REG.GetDefaultUnitType(regimentID)
end

function REG.GetUnitTypeName(regimentID, unitTypeID)
	local unitType = REG.GetUnitType(regimentID, unitTypeID)
	return unitType and unitType.name or "Standard Personnel"
end

function REG.FormatServiceName(regimentID, rank, cloneNumber, callsign)
	local prefix = REG.GetRegimentPrefix(regimentID)
	local cleanRank = REG.NormalizeRank(rank) or "RCT"
	local cleanNumber = tostring(cloneNumber or ""):gsub("%D", ""):sub(1, 4)
	local cleanCallsign = string.Trim(tostring(callsign or "")):gsub("[%c]", " "):sub(1, 24)
	local parts = {prefix, cleanRank}

	if (cleanNumber ~= "") then
		parts[#parts + 1] = cleanNumber
	end

	if (cleanCallsign ~= "") then
		parts[#parts + 1] = cleanCallsign
	end

	return table.concat(parts, " ")
end

function REG.DecodeList(value)
	if (istable(value)) then
		return value
	end

	if (not isstring(value) or value == "") then
		return {}
	end

	local decoded = util.JSONToTable(value)
	return istable(decoded) and decoded or {}
end

function REG.EncodeList(value)
	return util.TableToJSON(istable(value) and value or {}) or "[]"
end

REG.Register("gar", {
	name = "Grand Army of the Republic",
	shortName = "GAR",
	namePrefix = "GAR",
	kind = "root",
	browseVisible = false,
	colour = Color(94, 186, 232),
	description = "The central military body of the Galactic Republic. Browse High Command, frontline formations, specialist detachments and naval personnel from this directory.",
	specialisations = {"Planetary defence", "Expeditionary warfare", "Fleet support", "Republic security"},
	requirements = {"Authorised Republic military personnel"},
	defaultRecruitment = "closed"
})

REG.Register("high_command", {
	name = "High Command",
	browseVisible = false,
	shortName = "HIGHCOM",
	namePrefix = "GAR",
	kind = "command",
	parent = "gar",
	colour = Color(211, 174, 75),
	description = "Strategic command authority responsible for Republic deployments, operational doctrine and coordination between army formations.",
	specialisations = {"Strategic planning", "Operational command", "Inter-regimental coordination"},
	requirements = {"Commissioned command appointment", "High Command authorisation"},
	defaultRecruitment = "closed",
	defaultUnitType = "command",
	unitTypes = {
		{id = "command", name = "High Command", description = "Grand Army High Command personnel model.", aliases = {"officer"}}
	},
	commandPositions = {
		{id = "marshal_commander", title = "Marshal Commander"},
		{id = "high_command_adjutant", title = "High Command Adjutant"}
	}
})

REG.Register("unassigned", {
	name = "Unassigned Personnel",
	browseVisible = false,
	shortName = "UNASSIGNED",
	namePrefix = "CT",
	kind = "regiment",
	parent = "gar",
	colour = Color(145, 158, 171),
	description = "Clone personnel who have completed initial processing but have not yet received a permanent regimental assignment.",
	specialisations = {"Basic combat duties", "Training support"},
	requirements = {"Complete basic training", "Await a regiment tryout or transfer"},
	defaultRecruitment = "closed",
	defaultUnitType = "clone_trooper",
	unitTypes = {
		{id = "clone_trooper", name = "Clone Trooper", description = "Standard unassigned clone armour.", aliases = {"ct", "trooper"}}
	}
})

REG.Register("501st", {
	name = "501st Legion",
	tagline = "Fast, aggressive frontline infantry.",
	shortName = "501ST",
	namePrefix = "501st",
	kind = "regiment",
	parent = "gar",
	colour = Color(63, 116, 214),
	aliases = {"501st Legion", "501"},
	description = "An elite frontline assault formation specialising in aggressive infantry operations, ship boarding and rapid deployment into contested positions.",
	specialisations = {"Frontline assault", "Boarding operations", "Urban combat", "Rapid deployment"},
	requirements = {"Basic training completed", "No active disciplinary restriction", "Pass a 501st tryout"},
	defaultRecruitment = "open",
	defaultUnitType = "trooper",
	unitTypes = {
		{id = "trooper", name = "Standard Trooper", description = "The default 501st infantry model.", aliases = {"infantry", "standard"}},
		{id = "heavy", name = "Heavy", description = "Heavy weapons specialist model."},
		{id = "medic", name = "Medic", description = "Combat medical specialist model.", aliases = {"medical"}},
		{id = "command", name = "Command", description = "501st command personnel model.", aliases = {"officer"}}
	},
	commandPositions = {
		{id = "commanding_officer", title = "Commanding Officer"},
		{id = "executive_officer", title = "Executive Officer"},
		{id = "senior_nco", title = "Senior NCO"}
	},
	trainingSessions = {
		{title = "Legion Combat Exercise", schedule = "SATURDAY • 20:00", instructor = "501st Command", capacity = "OPEN", requirements = "501st personnel and approved recruits"}
	}
})

REG.Register("501st_command", {
	name = "Legion Command",
	unitType = "command",
	shortName = "COMMAND",
	kind = "unit",
	parent = "501st",
	colour = Color(77, 137, 235),
	description = "The command element responsible for directing 501st deployments, standards, promotions and operational readiness.",
	specialisations = {"Command", "Leadership", "Operational planning"},
	requirements = {"Appointment by senior command"},
	defaultRecruitment = "closed",
	commandPositions = {
		{id = "commanding_officer", title = "Commanding Officer"},
		{id = "executive_officer", title = "Executive Officer"}
	}
})

REG.Register("torrent_company", {
	name = "Torrent Company",
	shortName = "TORRENT",
	kind = "unit",
	parent = "501st",
	colour = Color(69, 126, 224),
	description = "A 501st combat company built around coordinated infantry manoeuvres, disciplined aggression and close support between squads.",
	specialisations = {"Infantry manoeuvre", "Breaching", "Combined squad tactics"},
	requirements = {"501st membership", "Company assignment"},
	defaultRecruitment = "selective",
	commandPositions = {
		{id = "company_commander", title = "Company Commander"},
		{id = "company_executive", title = "Company Executive"}
	},
	trainingSessions = {
		{title = "Advanced Breaching", schedule = "WEDNESDAY • 19:30", instructor = "Torrent Training Staff", capacity = "12 SLOTS", requirements = "Basic Combat Training"}
	}
})

REG.Register("501st_medical", {
	name = "501st Medical Personnel",
	unitType = "medic",
	filterByUnitType = true,
	shortName = "MEDICAL",
	kind = "unit",
	parent = "501st",
	colour = Color(85, 185, 213),
	description = "Combat medics embedded with the legion to stabilise casualties, maintain squad endurance and coordinate battlefield evacuation.",
	specialisations = {"Combat medicine", "Triage", "Casualty evacuation"},
	requirements = {"501st membership", "Medical certification"},
	defaultRecruitment = "selective",
	commandPositions = {
		{id = "medical_lead", title = "Medical Lead"}
	}
})

REG.Register("501st_heavy", {
	name = "501st Heavy Personnel",
	unitType = "heavy",
	filterByUnitType = true,
	shortName = "HEAVY",
	kind = "unit",
	parent = "501st",
	colour = Color(56, 103, 190),
	description = "Heavy weapons specialists who provide sustained fire, anti-armour capability and defensive anchoring for 501st infantry.",
	specialisations = {"Heavy weapons", "Anti-armour", "Suppression"},
	requirements = {"501st membership", "Heavy weapons certification"},
	defaultRecruitment = "selective"
})

REG.Register("212th", {
	name = "212th Attack Battalion",
	tagline = "Disciplined combined-arms assault troops.",
	shortName = "212TH",
	namePrefix = "212th",
	kind = "regiment",
	parent = "gar",
	colour = Color(226, 141, 47),
	aliases = {"212th Attack Battalion", "212"},
	description = "A battle-tested attack battalion recognised for disciplined combined-arms assaults, defensive resilience and coordinated battlefield control.",
	specialisations = {"Combined-arms assault", "Defensive operations", "Siege warfare", "Reconnaissance"},
	requirements = {"Basic training completed", "No active disciplinary restriction", "Pass a 212th tryout"},
	defaultRecruitment = "open",
	defaultUnitType = "trooper",
	unitTypes = {
		{id = "trooper", name = "Standard Trooper", description = "The default 212th infantry model.", aliases = {"infantry", "standard"}},
		{id = "heavy", name = "Heavy", description = "Heavy weapons specialist model."},
		{id = "medic", name = "Medic", description = "Combat medical specialist model.", aliases = {"medical"}},
		{id = "recon", name = "Recon", description = "Reconnaissance and rapid-response specialist model.", aliases = {"scout"}},
		{id = "command", name = "Command", description = "212th command personnel model.", aliases = {"officer"}}
	},
	commandPositions = {
		{id = "commanding_officer", title = "Commanding Officer"},
		{id = "executive_officer", title = "Executive Officer"},
		{id = "senior_nco", title = "Senior NCO"}
	},
	trainingSessions = {
		{title = "Combined Arms Drill", schedule = "SUNDAY • 19:00", instructor = "212th Command", capacity = "OPEN", requirements = "212th personnel and approved recruits"}
	}
})

REG.Register("212th_command", {
	name = "Battalion Command",
	unitType = "command",
	shortName = "COMMAND",
	kind = "unit",
	parent = "212th",
	colour = Color(238, 156, 62),
	description = "The battalion command element responsible for readiness, deployment planning and maintaining 212th operational standards.",
	specialisations = {"Command", "Combined-arms planning", "Leadership"},
	requirements = {"Appointment by senior command"},
	defaultRecruitment = "closed",
	commandPositions = {
		{id = "commanding_officer", title = "Commanding Officer"},
		{id = "executive_officer", title = "Executive Officer"}
	}
})

REG.Register("ghost_company", {
	name = "Ghost Company",
	unitType = "recon",
	shortName = "GHOST",
	kind = "unit",
	parent = "212th",
	colour = Color(214, 129, 38),
	description = "A specialist 212th company focused on adaptable infantry operations, reconnaissance and rapid battlefield response.",
	specialisations = {"Reconnaissance", "Rapid response", "Specialist infantry"},
	requirements = {"212th membership", "Company assignment"},
	defaultRecruitment = "selective",
	commandPositions = {
		{id = "company_commander", title = "Company Commander"},
		{id = "company_executive", title = "Company Executive"}
	}
})

REG.Register("212th_medical", {
	name = "212th Medical Personnel",
	unitType = "medic",
	filterByUnitType = true,
	shortName = "MEDICAL",
	kind = "unit",
	parent = "212th",
	colour = Color(232, 177, 93),
	description = "Battalion medical personnel trained to sustain assault elements during prolonged and high-casualty operations.",
	specialisations = {"Combat medicine", "Triage", "Field stabilisation"},
	requirements = {"212th membership", "Medical certification"},
	defaultRecruitment = "selective",
	commandPositions = {
		{id = "medical_lead", title = "Medical Lead"}
	}
})

REG.Register("republic_navy", {
	name = "Republic Navy",
	tagline = "Fleet, engineering and flight operations.",
	shortName = "NAVY",
	namePrefix = "Navy",
	kind = "regiment",
	parent = "gar",
	colour = Color(92, 177, 194),
	aliases = {"Navy", "Republic Navy"},
	description = "Naval personnel responsible for vessel command, flight operations, navigation, engineering and coordination with embarked army formations.",
	specialisations = {"Fleet operations", "Navigation", "Engineering", "Aviation"},
	requirements = {"Naval assignment", "Role-specific qualification"},
	defaultRecruitment = "selective",
	defaultUnitType = "crew",
	unitTypes = {
		{id = "crew", name = "Naval Crew", description = "Standard Republic Navy personnel model.", aliases = {"crewman", "standard"}},
		{id = "aviation", name = "Aviation", description = "Pilot and flight operations model.", aliases = {"pilot"}},
		{id = "engineering", name = "Engineering", description = "Naval engineering personnel model.", aliases = {"engineer"}},
		{id = "command", name = "Command", description = "Republic Navy command personnel model.", aliases = {"officer"}}
	},
	commandPositions = {
		{id = "naval_commanding_officer", title = "Naval Commanding Officer"},
		{id = "executive_officer", title = "Executive Officer"}
	}
})

REG.Register("naval_command", {
	name = "Naval Command",
	unitType = "command",
	shortName = "COMMAND",
	kind = "unit",
	parent = "republic_navy",
	colour = Color(105, 193, 208),
	description = "The shipboard command team responsible for vessel readiness, mission execution and coordination with embarked formations.",
	specialisations = {"Vessel command", "Mission coordination", "Fleet doctrine"},
	requirements = {"Commissioned naval appointment"},
	defaultRecruitment = "closed"
})

REG.Register("naval_aviation", {
	name = "Naval Aviation",
	unitType = "aviation",
	shortName = "AVIATION",
	kind = "unit",
	parent = "republic_navy",
	colour = Color(75, 158, 178),
	description = "Pilots, flight controllers and support personnel responsible for the vessel's embarked air wing.",
	specialisations = {"Starfighter operations", "Transport aviation", "Flight control"},
	requirements = {"Republic Navy membership", "Flight qualification"},
	defaultRecruitment = "selective",
	commandPositions = {
		{id = "air_group_commander", title = "Air Group Commander"}
	}
})
