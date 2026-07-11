-- swrp/plugins/regiments/libs/sv_directory.lua
-- Server-authoritative public directory data, dynamic service names, deletion cleanup and staff tools.

local REG = SWRP.Regiments

util.AddNetworkString("swrpRegimentsRequest")
util.AddNetworkString("swrpRegimentsSnapshot")
util.AddNetworkString("swrpRegimentsRequestRecord")
util.AddNetworkString("swrpRegimentsRecord")
util.AddNetworkString("swrpRegimentsManage")

REG.publicRecords = REG.publicRecords or {}
REG.recruitmentOverrides = REG.recruitmentOverrides or {}
REG.nodeOverrides = REG.nodeOverrides or {}
REG.trainingOverrides = REG.trainingOverrides or {}
REG.modelAssignments = REG.modelAssignments or {}
REG.requestCooldown = REG.requestCooldown or {}
REG.recordRequestCooldown = REG.recordRequestCooldown or {}
REG.manageCooldown = REG.manageCooldown or {}
REG.identitySync = REG.identitySync or setmetatable({}, {__mode = "k"})
REG.modelSync = REG.modelSync or setmetatable({}, {__mode = "k"})
REG.unitTypeSync = REG.unitTypeSync or setmetatable({}, {__mode = "k"})

local function getCharacterID(character)
	if (not character or not character.GetID) then
		return nil
	end

	return tonumber(character:GetID())
end

local function getCharacterPlayer(character)
	if (not character or not character.GetPlayer) then
		return nil
	end

	local client = character:GetPlayer()
	return IsValid(client) and client or nil
end

local function getModel(character, client)
	if (IsValid(client)) then
		return client:GetModel() or ""
	end

	if (character and character.GetModel) then
		local model = character:GetModel()

		if (istable(model)) then
			return model[1] or ""
		end

		return tostring(model or "")
	end

	return ""
end

local function getModelSkin(client)
	return IsValid(client) and math.max(math.floor(tonumber(client:GetSkin()) or 0), 0) or 0
end

local function getModelBodygroups(client)
	local bodygroups = {}

	if (not IsValid(client)) then
		return bodygroups
	end

	for index = 0, math.max(client:GetNumBodyGroups() - 1, 0) do
		bodygroups[index] = math.max(math.floor(tonumber(client:GetBodygroup(index)) or 0), 0)
	end

	return bodygroups
end

local function safeCharacterValue(character, getterName, default)
	if (not character) then
		return default
	end

	local getter = character[getterName]

	if (not isfunction(getter)) then
		return default
	end

	local ok, value = pcall(getter, character, default)

	if (not ok or value == nil) then
		return default
	end

	return value
end

local function cleanText(value, maximum)
	value = string.Trim(tostring(value or ""))
	value = value:gsub("[%c]", " ")
	return value:sub(1, maximum or 256)
end

local function cleanMultiline(value, maximum)
	value = tostring(value or "")
	value = value:gsub("\r", "")
	value = value:gsub("[^\n\t\32-\126]", "")
	return string.Trim(value):sub(1, maximum or 1200)
end

local function cleanList(value, maximumEntries, maximumLength)
	local output = {}
	local source = istable(value) and value or string.Explode("\n", tostring(value or ""))

	for _, entry in ipairs(source) do
		entry = cleanText(entry, maximumLength or 96)

		if (entry ~= "") then
			output[#output + 1] = entry
		end

		if (#output >= (maximumEntries or 12)) then
			break
		end
	end

	return output
end


local function cleanModelPath(value)
	local model = string.Trim(tostring(value or "")):gsub("\\", "/")

	if (model == "" or #model > 192 or not string.EndsWith(string.lower(model), ".mdl")) then
		return nil
	end

	if (not util.IsValidModel(model)) then
		return nil
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
	elseif (isstring(value)) then
		for token in string.gmatch(value, "[^,;%s]+") do
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

local function firstValidModel(value)
	if (isstring(value)) then
		return cleanModelPath(value)
	end

	if (not istable(value)) then
		return nil
	end

	for _, nested in pairs(value) do
		local model = firstValidModel(nested)

		if (model) then
			return model
		end
	end

	return nil
end

local function getFactionDefaultModel(character)
	if (not character or not ix.faction or not ix.faction.indices) then
		return nil
	end

	local factionIndex = tonumber(safeCharacterValue(character, "GetFaction", 0)) or 0
	local faction = ix.faction.indices[factionIndex]
	return faction and firstValidModel(faction.models) or nil
end

local function sanitiseModelAssignment(assignment)
	if (not istable(assignment)) then
		return nil
	end

	local model = cleanModelPath(assignment.model)

	if (not model) then
		return nil
	end

	return {
		model = model,
		skin = math.Clamp(math.floor(tonumber(assignment.skin) or 0), 0, 63),
		bodygroups = cleanBodygroups(assignment.bodygroups)
	}
end

function REG.MigrateModelAssignments(rawAssignments)
	local migrated = {}
	rawAssignments = istable(rawAssignments) and rawAssignments or {}

	local function store(regimentID, unitTypeID, assignment, overwrite)
		local primaryID = REG.GetPrimaryRegiment(regimentID)
		local roleID = REG.ResolveUnitType(primaryID, unitTypeID)
		local clean = sanitiseModelAssignment(assignment)

		if (not clean or roleID == "") then
			return
		end

		migrated[primaryID] = migrated[primaryID] or {}

		if (overwrite or not migrated[primaryID][roleID]) then
			migrated[primaryID][roleID] = clean
		end
	end

	-- V5 stored one model directly against each regiment or unit. Preserve the
	-- parent regiment model as that regiment's default unit type first.
	for _, nodeID in ipairs(REG.order or {}) do
		local node = REG.nodes[nodeID]
		local assignment = rawAssignments[nodeID]

		if (node and node.id == REG.GetPrimaryRegiment(node.id) and istable(assignment) and assignment.model) then
			store(node.id, REG.GetDefaultUnitType(node.id), assignment, false)
		end
	end

	-- Specialist V5 unit overrides become the corresponding unit-type model.
	for _, nodeID in ipairs(REG.order or {}) do
		local node = REG.nodes[nodeID]
		local assignment = rawAssignments[nodeID]

		if (node and node.kind == "unit" and node.unitType and istable(assignment) and assignment.model) then
			store(node.id, node.unitType, assignment, true)
		end
	end

	-- V6 format: regimentID -> unitTypeID -> model assignment.
	for rawRegimentID, bucket in pairs(rawAssignments) do
		if (istable(bucket) and not bucket.model) then
			local primaryID = REG.GetPrimaryRegiment(rawRegimentID)

			for rawUnitTypeID, assignment in pairs(bucket) do
				if (REG.GetUnitType(primaryID, rawUnitTypeID)) then
					store(primaryID, rawUnitTypeID, assignment, true)
				end
			end
		end
	end

	return migrated
end

function REG.GetModelAssignment(regimentID, unitTypeID)
	local primaryID = REG.GetPrimaryRegiment(regimentID)
	local roleID = REG.ResolveUnitType(primaryID, unitTypeID)
	local bucket = REG.modelAssignments[primaryID]

	if (not istable(bucket) or roleID == "") then
		return nil
	end

	return sanitiseModelAssignment(bucket[roleID])
end

function REG.SyncCharacterUnitType(character)
	if (not character) then
		return ""
	end

	local regimentID = REG.GetPrimaryRegiment(safeCharacterValue(character, "GetRegiment", "unassigned"))
	local current = tostring(safeCharacterValue(character, "GetUnitType", "") or "")
	local resolved = REG.ResolveUnitType(regimentID, current)

	if (resolved == "") then
		return ""
	end

	if (current ~= resolved and character.SetUnitType and not REG.unitTypeSync[character]) then
		REG.unitTypeSync[character] = true
		character:SetUnitType(resolved)
		timer.Simple(0, function()
			if (character) then
				REG.unitTypeSync[character] = nil
			end
		end)
	end

	return resolved
end

function REG.ResolveModelAssignment(character)
	if (not character) then
		return nil, nil
	end

	local regimentID = REG.GetPrimaryRegiment(safeCharacterValue(character, "GetRegiment", "unassigned"))
	local unitTypeID = REG.SyncCharacterUnitType(character)
	local assignment = REG.GetModelAssignment(regimentID, unitTypeID)

	if (assignment) then
		return assignment, regimentID .. ":" .. unitTypeID
	end

	local defaultUnitType = REG.GetDefaultUnitType(regimentID)

	if (defaultUnitType ~= "" and defaultUnitType ~= unitTypeID) then
		assignment = REG.GetModelAssignment(regimentID, defaultUnitType)

		if (assignment) then
			return assignment, regimentID .. ":" .. defaultUnitType
		end
	end

	-- Never leave someone wearing their previous regiment's armour. When a
	-- regiment/unit-type mapping has not been configured yet, fall back to the
	-- configured CT model and finally the faction's first valid model.
	if (regimentID ~= "unassigned") then
		local ctType = REG.GetDefaultUnitType("unassigned")
		assignment = REG.GetModelAssignment("unassigned", ctType)

		if (assignment) then
			return assignment, "unassigned:" .. ctType
		end
	end

	local fallbackModel = getFactionDefaultModel(character)

	if (fallbackModel) then
		return {model = fallbackModel, skin = 0, bodygroups = {}}, "faction_default"
	end

	return nil, nil
end

local function applyBodygroups(client, bodygroups)
	if (not IsValid(client)) then
		return
	end

	for index = 0, math.max(client:GetNumBodyGroups() - 1, 0) do
		client:SetBodygroup(index, 0)
	end

	for rawIndex, rawValue in pairs(bodygroups or {}) do
		local index = math.floor(tonumber(rawIndex) or -1)
		local value = math.floor(tonumber(rawValue) or 0)

		if (index >= 0 and index < client:GetNumBodyGroups()) then
			client:SetBodygroup(index, math.max(value, 0))
		end
	end
end

function REG.ApplyCharacterModel(character, client)
	if (not character or REG.modelSync[character]) then
		return false
	end

	local cloneNumber = tostring(safeCharacterValue(character, "GetCloneNumber", "") or ""):gsub("%D", "")

	if (cloneNumber == "") then
		return false
	end

	client = IsValid(client) and client or getCharacterPlayer(character)
	local assignment = REG.ResolveModelAssignment(character)

	if (not assignment or not assignment.model) then
		return false
	end

	REG.modelSync[character] = true
	local changed = false
	local currentModel = getModel(character, client)

	if (character.SetModel and string.lower(tostring(currentModel or "")) ~= string.lower(assignment.model)) then
		character:SetModel(assignment.model)
		changed = true
	end

	local function applyToPlayer(target)
		if (not IsValid(target)) then
			return
		end

		if (string.lower(target:GetModel() or "") ~= string.lower(assignment.model)) then
			target:SetModel(assignment.model)
		end

		local maximumSkin = math.max((target:SkinCount() or 1) - 1, 0)
		target:SetSkin(math.Clamp(assignment.skin or 0, 0, maximumSkin))
		applyBodygroups(target, assignment.bodygroups)
	end

	applyToPlayer(client)

	if (IsValid(client)) then
		timer.Simple(0, function()
			applyToPlayer(client)
		end)
	end

	timer.Simple(0, function()
		if (character) then
			REG.modelSync[character] = nil
		end
	end)

	return changed
end

function REG.ApplyAllCharacterModels()
	for _, target in ipairs(player.GetAll()) do
		local character = target:GetCharacter()

		if (character) then
			REG.ApplyCharacterModel(character, target)
			REG.UpdateCachedRecord(character, target, false)
		end
	end
end

function REG.SyncCharacterIdentity(character)
	if (not character or REG.identitySync[character]) then
		return false
	end

	local cloneNumber = tostring(safeCharacterValue(character, "GetCloneNumber", "") or ""):gsub("%D", ""):sub(1, 4)

	-- Non-clone characters do not have a service number and must keep their normal name.
	if (cloneNumber == "") then
		return false
	end

	REG.identitySync[character] = true

	local currentRank = tostring(safeCharacterValue(character, "GetRank", "") or "")
	local normalisedRank = REG.NormalizeRank(currentRank) or "RCT"
	local trainingCompleted = safeCharacterValue(character, "GetTrainingCompleted", false) == true

	-- Passing basic training automatically moves a Recruit to Private, but never
	-- overwrites a higher rank that command staff have already assigned.
	if (trainingCompleted and normalisedRank == "RCT") then
		normalisedRank = "PVT"
	end

	local regimentID = REG.ResolveID(safeCharacterValue(character, "GetRegiment", "unassigned"))
	local callsign = cleanText(safeCharacterValue(character, "GetCallsign", ""), 24)
	local desiredName = REG.FormatServiceName(regimentID, normalisedRank, cloneNumber, callsign)
	local changed = false

	if (currentRank ~= normalisedRank and character.SetRank) then
		character:SetRank(normalisedRank)
		if (trainingCompleted and normalisedRank == "PVT" and character.SetLastPromotionAt) then
			character:SetLastPromotionAt(os.time())
		end
		changed = true
	end

	if (character.SetName and tostring(safeCharacterValue(character, "GetName", "") or "") ~= desiredName) then
		character:SetName(desiredName)
		changed = true
	end

	REG.identitySync[character] = nil
	return changed
end

function REG.RemoveCachedRecord(characterID)
	characterID = tonumber(characterID)

	if (not characterID) then
		return false
	end

	local removed = REG.publicRecords[characterID] ~= nil or REG.publicRecords[tostring(characterID)] ~= nil
	REG.publicRecords[characterID] = nil
	REG.publicRecords[tostring(characterID)] = nil
	return removed
end

function REG.PruneMissingRecords()
	local query = mysql:Select("ix_characters")
	query:Select("id")
	query:Where("schema", Schema.folder)
	query:Callback(function(result)
		if (not istable(result)) then
			return
		end

		local existing = {}
		for _, row in ipairs(result) do
			local characterID = tonumber(row.id)
			if (characterID) then
				existing[characterID] = true
			end
		end

		local removed = false
		for key, record in pairs(REG.publicRecords or {}) do
			local characterID = tonumber(istable(record) and record.characterID or key)
			if (not characterID or not existing[characterID]) then
				REG.publicRecords[key] = nil
				removed = true
			end
		end

		if (removed) then
			REG.QueueSave()
			REG.BroadcastSnapshot()
		end
	end)
	query:Execute()
end

function REG.IsServerStaff(client)
	if (not IsValid(client)) then
		return false
	end

	if (client.IsListenServerHost and client:IsListenServerHost()) then
		return true
	end

	if (client:IsSuperAdmin() or client:IsAdmin()) then
		return true
	end

	local steamID = client:SteamID()
	local steamID64 = client:SteamID64()
	return REG.ownerSteamIDs[steamID] == true or REG.ownerSteamIDs[steamID64] == true
end

local unitScopedBillets = {
	company_commander = true,
	company_executive = true,
	medical_lead = true,
	air_group_commander = true
}

function REG.GetManagementLevel(client, nodeID)
	if (REG.IsServerStaff(client)) then
		return 3
	end

	if (not IsValid(client)) then
		return 0
	end

	local character = client:GetCharacter()
	local node = REG.Get(nodeID)

	if (not character or not node or node.id == "gar" or node.id == "unassigned") then
		return 0
	end

	local billet = string.lower(string.Trim(tostring(safeCharacterValue(character, "GetBillet", "") or "")))
	local permission = REG.managementBillets[billet]

	if (not permission) then
		return 0
	end

	local rank = tostring(safeCharacterValue(character, "GetRank", "RCT") or "RCT")

	if (REG.GetRankWeight(rank) < REG.GetRankWeight(permission.minimumRank)) then
		return 0
	end

	local characterRegiment = REG.ResolveID(safeCharacterValue(character, "GetRegiment", "unassigned"))
	local nodeRegiment = REG.GetPrimaryRegiment(node.id)

	if (characterRegiment ~= nodeRegiment) then
		return 0
	end

	if (unitScopedBillets[billet]) then
		local characterUnit = tostring(safeCharacterValue(character, "GetUnit", "") or "")
		local resolvedUnit = characterUnit ~= "" and REG.ResolveID(characterUnit) or ""

		if (resolvedUnit == "" or node.id ~= resolvedUnit) then
			return 0
		end
	end

	return tonumber(permission.level) or 0
end

function REG.BuildPublicRecord(character, client)
	local characterID = getCharacterID(character)

	if (not characterID) then
		return nil
	end

	client = IsValid(client) and client or getCharacterPlayer(character)

	local regimentID = REG.ResolveID(safeCharacterValue(character, "GetRegiment", "unassigned"))
	local unitValue = tostring(safeCharacterValue(character, "GetUnit", "") or "")
	local unitID = unitValue ~= "" and REG.ResolveID(unitValue) or ""

	if (unitID == "unassigned" and regimentID ~= "unassigned") then
		unitID = ""
	end

	if (unitID ~= "" and not REG.IsDescendant(unitID, regimentID)) then
		unitID = ""
	end

	local unitTypeID = REG.SyncCharacterUnitType(character)

	local cloneNumber = tostring(safeCharacterValue(character, "GetCloneNumber", "") or "")
	local callsign = cleanText(safeCharacterValue(character, "GetCallsign", ""), 24)
	local rank = REG.NormalizeRank(safeCharacterValue(character, "GetRank", "RCT")) or "RCT"
	local name = tostring(safeCharacterValue(character, "GetName", "Unknown Personnel") or "Unknown Personnel")
	local displayName = name

	local enlistedAt = tonumber(safeCharacterValue(character, "GetEnlistedAt", 0)) or 0

	if (enlistedAt <= 0 and character.SetEnlistedAt) then
		enlistedAt = os.time()
		character:SetEnlistedAt(enlistedAt)
	end

	return {
		characterID = characterID,
		name = name,
		displayName = displayName,
		cloneNumber = cloneNumber,
		callsign = callsign,
		rank = rank,
		regiment = regimentID,
		unit = unitID,
		unitType = unitTypeID,
		billet = tostring(safeCharacterValue(character, "GetBillet", "") or ""),
		serviceStatus = tostring(safeCharacterValue(character, "GetServiceStatus", "active") or "active"),
		enlistedAt = enlistedAt,
		lastPromotionAt = tonumber(safeCharacterValue(character, "GetLastPromotionAt", 0)) or 0,
		specialisations = REG.DecodeList(safeCharacterValue(character, "GetSpecialisations", "[]")),
		certifications = REG.DecodeList(safeCharacterValue(character, "GetCertifications", "[]")),
		commendations = REG.DecodeList(safeCharacterValue(character, "GetCommendations", "[]")),
		model = getModel(character, client),
		modelSkin = getModelSkin(client),
		modelBodygroups = getModelBodygroups(client),
		faction = tonumber(safeCharacterValue(character, "GetFaction", 0)) or 0,
		online = IsValid(client),
		entityIndex = IsValid(client) and client:EntIndex() or nil,
		lastSeen = os.time()
	}
end

function REG.UpdateCachedRecord(character, client, shouldSave)
	REG.SyncCharacterIdentity(character)
	local record = REG.BuildPublicRecord(character, client)

	if (not record) then
		return nil
	end

	REG.publicRecords[record.characterID] = record

	if (shouldSave ~= false) then
		REG.QueueSave()
	end

	return record
end

function REG.QueueSave()
	timer.Create("swrpRegimentsSave", 0.75, 1, function()
		local storedRecords = {}

		for characterID, record in pairs(REG.publicRecords or {}) do
			if (istable(record)) then
				local copy = table.Copy(record)
				copy.online = false
				copy.entityIndex = nil
				storedRecords[characterID] = copy
			end
		end

		ix.data.Set("swrpRegimentPublicRecords", storedRecords)
		ix.data.Set("swrpRegimentRecruitment", REG.recruitmentOverrides)
		ix.data.Set("swrpRegimentNodeOverrides", REG.nodeOverrides)
		ix.data.Set("swrpRegimentTrainingOverrides", REG.trainingOverrides)
		ix.data.Set("swrpRegimentModelAssignments", REG.modelAssignments)
	end)
end

function REG.GetRecruitmentState(nodeID)
	nodeID = REG.ResolveID(nodeID)
	local node = REG.Get(nodeID)
	local state = REG.recruitmentOverrides[nodeID]

	if (not REG.recruitmentStates[state]) then
		state = node and node.defaultRecruitment or "closed"
	end

	return state
end

function REG.GetTrainingSessions(nodeID)
	local node = REG.Get(nodeID)

	if (not node) then
		return {}
	end

	local override = REG.trainingOverrides[node.id]

	if (istable(override)) then
		return override
	end

	return node.trainingSessions or {}
end

local function buildPersonnel()
	local merged = {}

	for characterID, record in pairs(REG.publicRecords or {}) do
		if (istable(record)) then
			local copy = table.Copy(record)
			copy.characterID = tonumber(copy.characterID or characterID)
			copy.online = false
			copy.entityIndex = nil
			merged[copy.characterID] = copy
		end
	end

	for _, client in ipairs(player.GetAll()) do
		local character = client:GetCharacter()

		if (character) then
			local record = REG.UpdateCachedRecord(character, client, false)

			if (record) then
				record.online = true
				record.entityIndex = client:EntIndex()
				merged[record.characterID] = record
			end
		end
	end

	local personnel = {}

	for _, record in pairs(merged) do
		personnel[#personnel + 1] = record
	end

	table.sort(personnel, function(a, b)
		if (a.online ~= b.online) then
			return a.online
		end

		local rankA = REG.GetRankWeight(a.rank)
		local rankB = REG.GetRankWeight(b.rank)

		if (rankA ~= rankB) then
			return rankA > rankB
		end

		return string.lower(a.displayName or a.name or "") < string.lower(b.displayName or b.name or "")
	end)

	return personnel
end

function REG.BuildSnapshot(client)
	local recruitment = {}
	local training = {}
	local permissions = {}

	for id in pairs(REG.nodes) do
		recruitment[id] = REG.GetRecruitmentState(id)
		training[id] = table.Copy(REG.GetTrainingSessions(id))
		permissions[id] = REG.GetManagementLevel(client, id)
	end

	local viewerCharacter = IsValid(client) and client:GetCharacter() or nil
	local viewer = viewerCharacter and REG.BuildPublicRecord(viewerCharacter, client) or nil

	return {
		personnel = buildPersonnel(),
		recruitment = recruitment,
		nodeOverrides = table.Copy(REG.nodeOverrides),
		training = training,
		permissions = permissions,
		viewer = viewer,
		isStaff = REG.IsServerStaff(client),
		modelAssignments = REG.IsServerStaff(client) and table.Copy(REG.modelAssignments) or nil,
		generatedAt = os.time()
	}
end

function REG.SendSnapshot(client)
	if (not IsValid(client)) then
		return
	end

	net.Start("swrpRegimentsSnapshot")
	net.WriteTable(REG.BuildSnapshot(client))
	net.Send(client)
end

function REG.BroadcastSnapshot()
	timer.Create("swrpRegimentsBroadcast", 0.35, 1, function()
		for _, client in ipairs(player.GetAll()) do
			REG.SendSnapshot(client)
		end
	end)
end

local function canRequest(client, storage, delay)
	local now = CurTime()
	local nextAllowed = storage[client] or 0

	if (nextAllowed > now) then
		return false
	end

	storage[client] = now + delay
	return true
end

net.Receive("swrpRegimentsRequest", function(_, client)
	if (not canRequest(client, REG.requestCooldown, 0.75)) then
		return
	end

	REG.SendSnapshot(client)
end)

net.Receive("swrpRegimentsRequestRecord", function(_, client)
	if (not canRequest(client, REG.recordRequestCooldown, 0.25)) then
		return
	end

	local characterID = net.ReadUInt(32)
	local record = REG.publicRecords[characterID]

	for _, target in ipairs(player.GetAll()) do
		local character = target:GetCharacter()

		if (character and tonumber(character:GetID()) == characterID) then
			record = REG.UpdateCachedRecord(character, target, false)
			break
		end
	end

	if (not istable(record)) then
		return
	end

	net.Start("swrpRegimentsRecord")
	net.WriteTable(table.Copy(record))
	net.Send(client)
end)

local function findOnlineCharacter(characterID)
	characterID = tonumber(characterID)

	for _, target in ipairs(player.GetAll()) do
		local character = target:GetCharacter()

		if (character and tonumber(character:GetID()) == characterID) then
			return character, target
		end
	end

	return nil, nil
end

local function recordBelongsToNode(record, nodeID)
	local node = REG.Get(nodeID)

	if (not node or not istable(record)) then
		return false
	end

	if (node.kind == "unit") then
		if (node.filterByUnitType and node.unitType) then
			return REG.GetPrimaryRegiment(record.regiment) == REG.GetPrimaryRegiment(node.id)
				and REG.ResolveUnitType(record.regiment, record.unitType) == node.unitType
		end

		return REG.ResolveID(record.unit) == node.id
	end

	if (node.id == "gar") then
		return true
	end

	return REG.ResolveID(record.regiment) == node.id
end

local function requireManagement(client, nodeID, level)
	if (REG.GetManagementLevel(client, nodeID) < level) then
		client:Notify("You do not have permission to manage that formation.")
		return false
	end

	return true
end

local function getMutableSessions(nodeID)
	local node = REG.Get(nodeID)

	if (not node) then
		return nil
	end

	if (not istable(REG.trainingOverrides[node.id])) then
		REG.trainingOverrides[node.id] = table.Copy(node.trainingSessions or {})
	end

	return REG.trainingOverrides[node.id]
end

local function updateListEntry(character, getterName, setterName, value, remove)
	local list = REG.DecodeList(safeCharacterValue(character, getterName, "[]"))
	value = cleanText(value, 96)

	if (value == "") then
		return false
	end

	if (remove) then
		for index = #list, 1, -1 do
			if (string.lower(tostring(list[index])) == string.lower(value)) then
				table.remove(list, index)
			end
		end
	else
		for _, existing in ipairs(list) do
			if (string.lower(tostring(existing)) == string.lower(value)) then
				return false
			end
		end

		list[#list + 1] = value
	end

	character[setterName](character, REG.EncodeList(list))
	return true
end

net.Receive("swrpRegimentsManage", function(_, client)
	if (not canRequest(client, REG.manageCooldown, 0.2)) then
		return
	end

	local action = net.ReadString()
	local nodeID = REG.FindID(net.ReadString())
	local payload = net.ReadTable() or {}

	if (not nodeID or not REG.Get(nodeID)) then
		client:Notify("Unknown regiment or unit.")
		return
	end

	if (action == "save_model_assignment") then
		if (not REG.IsServerStaff(client)) then
			client:Notify("Only server administrators can configure forced models.")
			return
		end

		local regimentID = REG.GetPrimaryRegiment(nodeID)
		local unitType = REG.GetUnitType(regimentID, cleanText(payload.unitType, 48))
		local unitTypeID = unitType and unitType.id or ""
		local model = cleanModelPath(payload.model)

		if (not unitType) then
			client:Notify("Select a valid unit type for that regiment.")
			return
		end

		if (not model) then
			client:Notify("Select a valid player model before saving this unit type.")
			return
		end

		REG.modelAssignments[regimentID] = REG.modelAssignments[regimentID] or {}
		REG.modelAssignments[regimentID][unitTypeID] = {
			model = model,
			skin = 0,
			bodygroups = {}
		}
		REG.ApplyAllCharacterModels()
		client:Notify(string.format("%s model saved for %s.", unitType.name, REG.Get(regimentID).name))
	elseif (action == "clear_model_assignment") then
		if (not REG.IsServerStaff(client)) then
			client:Notify("Only server administrators can configure forced models.")
			return
		end

		local regimentID = REG.GetPrimaryRegiment(nodeID)
		local unitType = REG.GetUnitType(regimentID, cleanText(payload.unitType, 48))
		local unitTypeID = unitType and unitType.id or ""

		if (not unitType) then
			client:Notify("Select a valid unit type for that regiment.")
			return
		end

		if (istable(REG.modelAssignments[regimentID])) then
			REG.modelAssignments[regimentID][unitTypeID] = nil

			if (table.IsEmpty(REG.modelAssignments[regimentID])) then
				REG.modelAssignments[regimentID] = nil
			end
		end

		REG.ApplyAllCharacterModels()
		client:Notify(string.format("%s model cleared for %s.", unitType.name, REG.Get(regimentID).name))
	elseif (action == "set_recruitment") then
		if (not requireManagement(client, nodeID, 3)) then return end
		local state = string.lower(cleanText(payload.state, 16))

		if (not REG.recruitmentStates[state]) then
			client:Notify("Invalid recruitment state.")
			return
		end

		REG.recruitmentOverrides[nodeID] = state
		client:Notify("Recruitment status updated.")
	elseif (action == "save_overview") then
		if (not requireManagement(client, nodeID, 3)) then return end
		local state = string.lower(cleanText(payload.state, 16))
		if (REG.recruitmentStates[state]) then
			REG.recruitmentOverrides[nodeID] = state
		end
		REG.nodeOverrides[nodeID] = REG.nodeOverrides[nodeID] or {}
		local override = REG.nodeOverrides[nodeID]
		override.description = cleanMultiline(payload.description, 700)
		override.recruitmentNotice = cleanMultiline(payload.recruitmentNotice, 240)
		override.specialisations = cleanList(payload.specialisations, 8, 72)
		override.requirements = cleanList(payload.requirements, 8, 96)
		client:Notify("Regiment overview updated.")
	elseif (action == "add_training") then
		if (not requireManagement(client, nodeID, 2)) then return end
		local title = cleanText(payload.title, 64)

		if (title == "") then
			client:Notify("Training requires a title.")
			return
		end

		local sessions = getMutableSessions(nodeID)
		sessions[#sessions + 1] = {
			title = title,
			schedule = cleanText(payload.schedule, 48),
			instructor = cleanText(payload.instructor, 64),
			capacity = cleanText(payload.capacity, 24),
			requirements = cleanText(payload.requirements, 128)
		}
		client:Notify("Training session published.")
	elseif (action == "delete_training") then
		if (not requireManagement(client, nodeID, 2)) then return end
		local sessions = getMutableSessions(nodeID)
		local index = math.floor(tonumber(payload.index) or 0)

		if (index < 1 or index > #sessions) then
			client:Notify("That training session no longer exists.")
			return
		end

		table.remove(sessions, index)
		client:Notify("Training session removed.")
	elseif (action == "update_personnel") then
		if (not requireManagement(client, nodeID, 3)) then return end
		local character, target = findOnlineCharacter(payload.characterID)

		if (not character or not IsValid(target)) then
			client:Notify("Personnel edits currently require the player to be online.")
			return
		end

		local currentRecord = REG.BuildPublicRecord(character, target)

		if (not recordBelongsToNode(currentRecord, nodeID)) then
			client:Notify("That character is outside your command scope.")
			return
		end

		local rank = REG.NormalizeRank(payload.rank)
		local callsign = cleanText(payload.callsign, 24)
		local status = string.lower(cleanText(payload.serviceStatus, 16))
		local billet = string.lower(cleanText(payload.billet, 40)):gsub("%s+", "_")

		if (not rank) then
			client:Notify("Select a valid military rank.")
			return
		end
		local unitValue = cleanText(payload.unit, 48)
		local unitID = unitValue ~= "" and REG.FindID(unitValue) or nil
		local regimentID = REG.GetPrimaryRegiment(character:GetRegiment("unassigned"))
		local selectedUnitType = REG.GetUnitType(regimentID, cleanText(payload.unitType, 48))
		local unitTypeID = selectedUnitType and selectedUnitType.id or ""

		if (not selectedUnitType) then
			client:Notify("Select a valid unit type for that regiment.")
			return
		end

		if (character:GetRank("") ~= rank) then
			character:SetRank(rank)
			character:SetLastPromotionAt(os.time())
		end

		if (character.SetCallsign) then
			character:SetCallsign(callsign)
		end

		if (status == "active" or status == "reserve" or status == "discharged") then
			character:SetServiceStatus(status)
		end

		character:SetBillet(billet == "none" and "" or billet)

		if (unitValue == "" or string.lower(unitValue) == "none") then
			character:SetUnit("")
		elseif (unitID and REG.Get(unitID).kind == "unit" and REG.IsDescendant(unitID, regimentID)) then
			local unitNode = REG.Get(unitID)
			character:SetUnit(unitID)

			if (unitNode.unitType and REG.GetUnitType(regimentID, unitNode.unitType)) then
				unitTypeID = unitNode.unitType
			end
		else
			client:Notify("The selected unit is not valid for that regiment.")
			return
		end

		if (character.SetUnitType) then
			character:SetUnitType(unitTypeID)
		end

		REG.ApplyCharacterModel(character, target)
		REG.UpdateCachedRecord(character, target)
		client:Notify("Personnel record updated.")
	elseif (action == "remove_personnel") then
		if (not requireManagement(client, nodeID, 3)) then return end

		local primaryNodeID = REG.GetPrimaryRegiment(nodeID)
		if (nodeID ~= primaryNodeID and not REG.IsServerStaff(client)) then
			client:Notify("Open the parent regiment to remove personnel from the regiment.")
			return
		end

		local character, target = findOnlineCharacter(payload.characterID)
		if (not character or not IsValid(target)) then
			client:Notify("Personnel removals currently require the player to be online.")
			return
		end

		local currentRecord = REG.BuildPublicRecord(character, target)
		if (not recordBelongsToNode(currentRecord, nodeID)) then
			client:Notify("That character is outside your command scope.")
			return
		end

		-- Capture the old identity before SetRegiment rebuilds the service name.
		local previousName = tostring(character:GetName() or "Unknown Personnel")
		local previousRegimentID = REG.ResolveID(character:GetRegiment("unassigned"))
		local previousRegiment = REG.Get(previousRegimentID)

		-- Regiment removal changes the service prefix back to CT while preserving
		-- the clone's number, callsign and GAR rank.
		character:SetUnit("")
		character:SetBillet("")
		character:SetRegiment("unassigned")
		if (character.SetUnitType) then
			character:SetUnitType(REG.GetDefaultUnitType("unassigned"))
		end
		REG.ApplyCharacterModel(character, target)
		REG.UpdateCachedRecord(character, target)

		client:Notify(string.format(
			"%s has been removed from %s. Their new designation is %s.",
			previousName,
			previousRegiment and previousRegiment.name or "their regiment",
			character:GetName()
		))
	elseif (action == "record_entry") then
		if (not requireManagement(client, nodeID, 2)) then return end
		local character, target = findOnlineCharacter(payload.characterID)

		if (not character or not IsValid(target)) then
			client:Notify("Record edits currently require the player to be online.")
			return
		end

		local currentRecord = REG.BuildPublicRecord(character, target)

		if (not recordBelongsToNode(currentRecord, nodeID)) then
			client:Notify("That character is outside your command scope.")
			return
		end

		local entryType = string.lower(cleanText(payload.entryType, 24))
		local remove = payload.remove == true
		local changed = false

		if (entryType == "certification") then
			changed = updateListEntry(character, "GetCertifications", "SetCertifications", payload.value, remove)
		elseif (entryType == "commendation") then
			changed = updateListEntry(character, "GetCommendations", "SetCommendations", payload.value, remove)
		end

		if (changed) then
			REG.UpdateCachedRecord(character, target)
			client:Notify(remove and "Record entry removed." or "Record entry added.")
		else
			client:Notify("No record change was made.")
		end
	else
		client:Notify("Unknown regiment management action.")
		return
	end

	REG.QueueSave()
	REG.BroadcastSnapshot()
end)

local function getTargetCharacter(client, target)
	if (not IsValid(target)) then
		client:Notify("That player is not available.")
		return nil
	end

	local character = target:GetCharacter()

	if (not character) then
		client:Notify("That player does not have an active character.")
		return nil
	end

	return character
end

local function refreshCharacter(character, target)
	REG.ApplyCharacterModel(character, target)
	REG.UpdateCachedRecord(character, target)
	REG.BroadcastSnapshot()
end

local function staffCommandAccess(self, client)
	return REG.IsServerStaff(client)
end

local function requireStaff(client)
	if (REG.IsServerStaff(client)) then
		return true
	end

	client:Notify("You do not have permission to use regiment staff commands.")
	return false
end

ix.command.Add("RegimentSet", {
	description = "Assign an active character to a regiment. Use none to return them to CT status.",
	OnCheckAccess = staffCommandAccess,
	arguments = {ix.type.player, ix.type.string},
	OnRun = function(self, client, target, regimentValue)
		if (not requireStaff(client)) then return end
		local character = getTargetCharacter(client, target)
		if (not character) then return end
		local cleanValue = string.lower(string.Trim(tostring(regimentValue or "")))
		local regimentID

		if (cleanValue == "none" or cleanValue == "unassigned" or cleanValue == "ct") then
			regimentID = "unassigned"
		else
			local foundID = REG.FindID(regimentValue)
			regimentID = foundID and REG.GetPrimaryRegiment(foundID) or nil
		end

		if (not regimentID) then
			client:Notify("Unknown regiment ID or name.")
			return
		end

		local previousRegiment = REG.ResolveID(character:GetRegiment("unassigned"))
		local previousRegimentNode = REG.Get(previousRegiment)
		local previousName = tostring(character:GetName() or "Unknown Personnel")
		character:SetRegiment(regimentID)
		local unitID = tostring(character:GetUnit("") or "")

		if (unitID ~= "" and not REG.IsDescendant(unitID, regimentID)) then
			character:SetUnit("")
		end

		if (previousRegiment ~= regimentID and character.SetBillet) then
			character:SetBillet("")
		end

		if (previousRegiment ~= regimentID and character.SetUnitType) then
			character:SetUnitType(REG.GetDefaultUnitType(regimentID))
		end

		refreshCharacter(character, target)

		if (regimentID == "unassigned") then
			client:Notify(string.format(
				"%s has been removed from %s. Their new designation is %s.",
				previousName,
				previousRegimentNode and previousRegimentNode.name or "their regiment",
				character:GetName()
			))
		elseif (previousRegiment ~= "unassigned" and previousRegiment ~= regimentID) then
			client:Notify(string.format(
				"Transferred %s from %s to %s. Their new designation is %s.",
				previousName,
				previousRegimentNode and previousRegimentNode.name or "their previous regiment",
				REG.Get(regimentID).name,
				character:GetName()
			))
		else
			client:Notify(string.format("Assigned %s to %s.", character:GetName(), REG.Get(regimentID).name))
		end
	end
})

ix.command.Add("RegimentUnit", {
	description = "Assign an active character to a regiment subunit. Use none to clear it.",
	OnCheckAccess = staffCommandAccess,
	arguments = {ix.type.player, ix.type.string},
	OnRun = function(self, client, target, unitValue)
		if (not requireStaff(client)) then return end
		local character = getTargetCharacter(client, target)
		if (not character) then return end

		if (string.lower(unitValue) == "none") then
			local currentUnit = REG.Get(character:GetUnit(""))
			local regimentID = REG.GetPrimaryRegiment(character:GetRegiment("unassigned"))
			character:SetUnit("")

			if (currentUnit and currentUnit.unitType and character.GetUnitType and character:GetUnitType("") == currentUnit.unitType and character.SetUnitType) then
				character:SetUnitType(REG.GetDefaultUnitType(regimentID))
			end

			refreshCharacter(character, target)
			client:Notify("Cleared the character's subunit assignment.")
			return
		end

		local unitID = REG.FindID(unitValue)
		local regimentID = REG.ResolveID(character:GetRegiment("unassigned"))
		local unit = REG.Get(unitID)

		if (not unit or unit.kind ~= "unit" or not REG.IsDescendant(unitID, regimentID)) then
			client:Notify("That unit does not belong to the character's current regiment.")
			return
		end

		character:SetUnit(unitID)

		if (unit.unitType and character.SetUnitType and REG.GetUnitType(regimentID, unit.unitType)) then
			character:SetUnitType(unit.unitType)
		end

		refreshCharacter(character, target)
		client:Notify(string.format("Assigned %s to %s.", character:GetName(), unit.name))
	end
})

ix.command.Add("RegimentUnitType", {
	description = "Set an active character's regiment unit type, such as trooper, heavy or medic.",
	OnCheckAccess = staffCommandAccess,
	arguments = {ix.type.player, ix.type.string},
	OnRun = function(self, client, target, unitTypeValue)
		if (not requireStaff(client)) then return end
		local character = getTargetCharacter(client, target)
		if (not character) then return end

		local regimentID = REG.GetPrimaryRegiment(character:GetRegiment("unassigned"))
		local unitType = REG.GetUnitType(regimentID, unitTypeValue)
		local unitTypeID = unitType and unitType.id or ""

		if (not unitType) then
			local valid = {}
			for _, option in ipairs(REG.GetUnitTypes(regimentID)) do
				valid[#valid + 1] = option.id
			end
			client:Notify("Valid unit types: " .. table.concat(valid, ", "))
			return
		end

		character:SetUnitType(unitTypeID)
		refreshCharacter(character, target)
		client:Notify(string.format("Set %s's unit type to %s.", character:GetName(), unitType.name))
	end
})

ix.command.Add("RegimentRank", {
	description = "Set an active character's public military rank abbreviation.",
	OnCheckAccess = staffCommandAccess,
	arguments = {ix.type.player, ix.type.string},
	OnRun = function(self, client, target, rank)
		if (not requireStaff(client)) then return end
		local character = getTargetCharacter(client, target)
		if (not character) then return end
		rank = REG.NormalizeRank(rank)

		if (not rank) then
			client:Notify("Valid ranks: " .. table.concat(REG.rankOrder, ", "))
			return
		end

		character:SetRank(rank)
		character:SetLastPromotionAt(os.time())
		refreshCharacter(character, target)
		client:Notify(string.format("Set %s's rank to %s.", character:GetName(), rank))
	end
})

ix.command.Add("RegimentCallsign", {
	description = "Set an active clone character's callsign. Use none to clear it.",
	OnCheckAccess = staffCommandAccess,
	arguments = {ix.type.player, ix.type.string},
	OnRun = function(self, client, target, callsign)
		if (not requireStaff(client)) then return end
		local character = getTargetCharacter(client, target)
		if (not character) then return end

		callsign = cleanText(callsign, 24)
		if (string.lower(callsign) == "none") then
			callsign = ""
		end

		character:SetCallsign(callsign)
		refreshCharacter(character, target)
		client:Notify(callsign == "" and "Cleared the character's callsign." or "Updated the character's callsign.")
	end
})

ix.command.Add("RegimentBillet", {
	description = "Set an active character's command billet ID. Use none to clear it.",
	OnCheckAccess = staffCommandAccess,
	arguments = {ix.type.player, ix.type.string},
	OnRun = function(self, client, target, billet)
		if (not requireStaff(client)) then return end
		local character = getTargetCharacter(client, target)
		if (not character) then return end
		billet = string.lower(string.Trim(billet))
		character:SetBillet(billet == "none" and "" or billet)
		refreshCharacter(character, target)
		client:Notify("Updated the character's public billet.")
	end
})

ix.command.Add("RegimentStatus", {
	description = "Set an active character's service status: active, reserve or discharged.",
	OnCheckAccess = staffCommandAccess,
	arguments = {ix.type.player, ix.type.string},
	OnRun = function(self, client, target, status)
		if (not requireStaff(client)) then return end
		local character = getTargetCharacter(client, target)
		if (not character) then return end
		status = string.lower(string.Trim(status))

		if (status ~= "active" and status ~= "reserve" and status ~= "discharged") then
			client:Notify("Valid statuses are active, reserve and discharged.")
			return
		end

		character:SetServiceStatus(status)
		refreshCharacter(character, target)
		client:Notify("Updated the character's service status.")
	end
})

local function addListEntry(client, target, getterName, setterName, entry, label)
	local character = getTargetCharacter(client, target)
	if (not character) then return end
	entry = string.Trim(entry or "")

	if (entry == "") then
		client:Notify(label .. " cannot be empty.")
		return
	end

	local list = REG.DecodeList(safeCharacterValue(character, getterName, "[]"))

	for _, existing in ipairs(list) do
		if (string.lower(existing) == string.lower(entry)) then
			client:Notify("That entry is already present.")
			return
		end
	end

	list[#list + 1] = entry
	character[setterName](character, REG.EncodeList(list))
	refreshCharacter(character, target)
	client:Notify(string.format("Added %s to %s's public record.", label, character:GetName()))
end

ix.command.Add("RegimentCertificationAdd", {
	description = "Add a certification to an active character's public service record.",
	OnCheckAccess = staffCommandAccess,
	arguments = {ix.type.player, ix.type.text},
	OnRun = function(self, client, target, certification)
		if (not requireStaff(client)) then return end
		addListEntry(client, target, "GetCertifications", "SetCertifications", certification, "certification")
	end
})

ix.command.Add("RegimentCommendationAdd", {
	description = "Add a commendation to an active character's public service record.",
	OnCheckAccess = staffCommandAccess,
	arguments = {ix.type.player, ix.type.text},
	OnRun = function(self, client, target, commendation)
		if (not requireStaff(client)) then return end
		addListEntry(client, target, "GetCommendations", "SetCommendations", commendation, "commendation")
	end
})

ix.command.Add("RegimentRecruitment", {
	description = "Set a regiment or unit's recruitment state: open, selective or closed.",
	OnCheckAccess = staffCommandAccess,
	arguments = {ix.type.string, ix.type.string},
	OnRun = function(self, client, regimentValue, state)
		if (not requireStaff(client)) then return end
		local regimentID = REG.FindID(regimentValue)
		state = string.lower(string.Trim(state))

		if (not regimentID or not REG.nodes[regimentID]) then
			client:Notify("Unknown regiment or unit.")
			return
		end

		if (not REG.recruitmentStates[state]) then
			client:Notify("Valid recruitment states are open, selective and closed.")
			return
		end

		REG.recruitmentOverrides[regimentID] = state
		REG.QueueSave()
		REG.BroadcastSnapshot()
		client:Notify(string.format("Set %s recruitment to %s.", REG.Get(regimentID).name, string.upper(state)))
	end
})

function PLUGIN:InitializedPlugins()
	local storedRecords = ix.data.Get("swrpRegimentPublicRecords", {}) or {}
	REG.publicRecords = {}
	REG.recruitmentOverrides = ix.data.Get("swrpRegimentRecruitment", {}) or {}
	REG.nodeOverrides = ix.data.Get("swrpRegimentNodeOverrides", {}) or {}
	REG.trainingOverrides = ix.data.Get("swrpRegimentTrainingOverrides", {}) or {}
	REG.modelAssignments = REG.MigrateModelAssignments(ix.data.Get("swrpRegimentModelAssignments", {}) or {})

	for key, record in pairs(storedRecords) do
		if (istable(record)) then
			local characterID = tonumber(record.characterID or key)
			if (characterID) then
				record.characterID = characterID
				record.online = false
				record.entityIndex = nil
				record.rank = REG.NormalizeRank(record.rank) or "RCT"
				record.regiment = REG.GetPrimaryRegiment(record.regiment or "unassigned")
				record.unitType = REG.ResolveUnitType(record.regiment, record.unitType)
				REG.publicRecords[characterID] = record
			end
		end
	end

	timer.Simple(0, function()
		REG.PruneMissingRecords()
	end)
end

function PLUGIN:CharacterRestored(character)
	timer.Simple(0, function()
		if (not character) then return end
		local target = getCharacterPlayer(character)
		REG.ApplyCharacterModel(character, target)
		REG.UpdateCachedRecord(character, target)
		REG.BroadcastSnapshot()
	end)
end

function PLUGIN:OnCharacterCreated(client, character)
	if (character.SetEnlistedAt and character:GetEnlistedAt(0) <= 0) then
		character:SetEnlistedAt(os.time())
	end

	REG.ApplyCharacterModel(character, client)
	REG.UpdateCachedRecord(character, client)
	REG.BroadcastSnapshot()
end

function PLUGIN:PlayerLoadedCharacter(client, character)
	timer.Simple(0, function()
		if (not IsValid(client) or not character) then return end
		REG.ApplyCharacterModel(character, client)
		REG.UpdateCachedRecord(character, client)
		REG.BroadcastSnapshot()
	end)
end

function PLUGIN:PlayerSpawn(client)
	timer.Simple(0.1, function()
		if (not IsValid(client)) then return end
		local character = client:GetCharacter()
		if (character) then
			REG.ApplyCharacterModel(character, client)
			REG.UpdateCachedRecord(character, client, false)
		end
	end)
end

function PLUGIN:CharacterVarChanged(character, key)
	local publicKeys = {
		name = true,
		model = true,
		cloneNumber = true,
		callsign = true,
		rank = true,
		trainingCompleted = true,
		regiment = true,
		unit = true,
		unitType = true,
		billet = true,
		serviceStatus = true,
		enlistedAt = true,
		lastPromotionAt = true,
		specialisations = true,
		certifications = true,
		commendations = true
	}

	if (not publicKeys[key]) then return end
	local client = getCharacterPlayer(character)

	if (key == "regiment" or key == "unit" or key == "unitType") then
		REG.ApplyCharacterModel(character, client)
	end

	REG.UpdateCachedRecord(character, client)
	REG.BroadcastSnapshot()
end

function PLUGIN:CharacterDeleted(client, characterID)
	if (REG.RemoveCachedRecord(characterID)) then
		REG.QueueSave()
		REG.BroadcastSnapshot()
	end
end

function PLUGIN:PlayerDisconnected(client)
	local character = client:GetCharacter()

	if (character) then
		local record = REG.UpdateCachedRecord(character, nil)

		if (record) then
			record.online = false
			record.entityIndex = nil
			REG.publicRecords[record.characterID] = record
			REG.QueueSave()
		end
	end

	REG.requestCooldown[client] = nil
	REG.recordRequestCooldown[client] = nil
	REG.manageCooldown[client] = nil
	REG.BroadcastSnapshot()
end
