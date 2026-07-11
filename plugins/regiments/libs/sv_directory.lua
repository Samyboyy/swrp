-- swrp/plugins/regiments/libs/sv_directory.lua
-- Server-authoritative public directory data, regiment management and staff tools.

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
REG.requestCooldown = REG.requestCooldown or {}
REG.recordRequestCooldown = REG.recordRequestCooldown or {}
REG.manageCooldown = REG.manageCooldown or {}

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

	local rank = tostring(safeCharacterValue(character, "GetRank", "CT") or "CT")

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

	local cloneNumber = tostring(safeCharacterValue(character, "GetCloneNumber", "") or "")
	local callsign = tostring(safeCharacterValue(character, "GetCallsign", "") or "")
	local rank = tostring(safeCharacterValue(character, "GetRank", "CT") or "CT")
	local name = tostring(safeCharacterValue(character, "GetName", "Unknown Personnel") or "Unknown Personnel")
	local displayName = name

	if (callsign ~= "") then
		displayName = string.format("%s \"%s\"", name, callsign)
	end

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
		billet = tostring(safeCharacterValue(character, "GetBillet", "") or ""),
		serviceStatus = tostring(safeCharacterValue(character, "GetServiceStatus", "active") or "active"),
		enlistedAt = enlistedAt,
		lastPromotionAt = tonumber(safeCharacterValue(character, "GetLastPromotionAt", 0)) or 0,
		specialisations = REG.DecodeList(safeCharacterValue(character, "GetSpecialisations", "[]")),
		certifications = REG.DecodeList(safeCharacterValue(character, "GetCertifications", "[]")),
		commendations = REG.DecodeList(safeCharacterValue(character, "GetCommendations", "[]")),
		model = getModel(character, client),
		faction = tonumber(safeCharacterValue(character, "GetFaction", 0)) or 0,
		online = IsValid(client),
		entityIndex = IsValid(client) and client:EntIndex() or nil,
		lastSeen = os.time()
	}
end

function REG.UpdateCachedRecord(character, client, shouldSave)
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

	if (action == "set_recruitment") then
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

		local rank = string.upper(cleanText(payload.rank, 12))
		local status = string.lower(cleanText(payload.serviceStatus, 16))
		local billet = string.lower(cleanText(payload.billet, 40)):gsub("%s+", "_")
		local unitValue = cleanText(payload.unit, 48)
		local unitID = unitValue ~= "" and REG.FindID(unitValue) or nil
		local regimentID = REG.ResolveID(character:GetRegiment("unassigned"))

		if (rank ~= "") then
			character:SetRank(rank)
			character:SetLastPromotionAt(os.time())
		end

		if (status == "active" or status == "reserve" or status == "discharged") then
			character:SetServiceStatus(status)
		end

		character:SetBillet(billet == "none" and "" or billet)

		if (unitValue == "" or string.lower(unitValue) == "none") then
			character:SetUnit("")
		elseif (unitID and REG.Get(unitID).kind == "unit" and REG.IsDescendant(unitID, regimentID)) then
			character:SetUnit(unitID)
		else
			client:Notify("The selected unit is not valid for that regiment.")
			return
		end

		REG.UpdateCachedRecord(character, target)
		client:Notify("Personnel record updated.")
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
	description = "Assign an active character to a regiment.",
	OnCheckAccess = staffCommandAccess,
	arguments = {ix.type.player, ix.type.string},
	OnRun = function(self, client, target, regimentValue)
		if (not requireStaff(client)) then return end
		local character = getTargetCharacter(client, target)
		if (not character) then return end
		local regimentID = REG.FindID(regimentValue)

		if (not regimentID) then
			client:Notify("Unknown regiment ID or name.")
			return
		end

		character:SetRegiment(regimentID)
		local unitID = tostring(character:GetUnit("") or "")

		if (unitID ~= "" and not REG.IsDescendant(unitID, regimentID)) then
			character:SetUnit("")
		end

		refreshCharacter(character, target)
		client:Notify(string.format("Assigned %s to %s.", character:GetName(), REG.Get(regimentID).name))
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
			character:SetUnit("")
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
		refreshCharacter(character, target)
		client:Notify(string.format("Assigned %s to %s.", character:GetName(), unit.name))
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
		rank = string.upper(string.Trim(rank)):sub(1, 12)
		character:SetRank(rank)
		character:SetLastPromotionAt(os.time())
		refreshCharacter(character, target)
		client:Notify(string.format("Set %s's rank to %s.", character:GetName(), rank))
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
	REG.publicRecords = ix.data.Get("swrpRegimentPublicRecords", {}) or {}
	REG.recruitmentOverrides = ix.data.Get("swrpRegimentRecruitment", {}) or {}
	REG.nodeOverrides = ix.data.Get("swrpRegimentNodeOverrides", {}) or {}
	REG.trainingOverrides = ix.data.Get("swrpRegimentTrainingOverrides", {}) or {}

	for _, record in pairs(REG.publicRecords) do
		if (istable(record)) then
			record.online = false
			record.entityIndex = nil
		end
	end
end

function PLUGIN:OnCharacterCreated(client, character)
	if (character.SetEnlistedAt and character:GetEnlistedAt(0) <= 0) then
		character:SetEnlistedAt(os.time())
	end

	REG.UpdateCachedRecord(character, client)
	REG.BroadcastSnapshot()
end

function PLUGIN:PlayerLoadedCharacter(client, character)
	timer.Simple(0, function()
		if (not IsValid(client) or not character) then return end
		REG.UpdateCachedRecord(character, client)
		REG.BroadcastSnapshot()
	end)
end

function PLUGIN:CharacterVarChanged(character, key)
	local publicKeys = {
		name = true,
		model = true,
		cloneNumber = true,
		callsign = true,
		rank = true,
		regiment = true,
		unit = true,
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
	REG.UpdateCachedRecord(character, client)
	REG.BroadcastSnapshot()
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
