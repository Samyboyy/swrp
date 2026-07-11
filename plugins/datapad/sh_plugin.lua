-- swrp/plugins/datapad/sh_plugin.lua
-- Replaces Helix's default TAB menu with a Republic personnel datapad.

PLUGIN.name = "Republic Datapad"
PLUGIN.author = "Sam"
PLUGIN.description = "A Republic personnel interface with NAVCOM, service identity, equipment and career progression."

SWRP = SWRP or {}
SWRP.Datapad = SWRP.Datapad or {}

-- Helix inventories have a current width/height, but Helix does not define a
-- universal unlock ceiling. These optional settings only control the visual
-- expansion ceiling in the datapad. Leave either value at 0 to use the
-- character's real current inventory dimension and avoid inventing fake slots.
ix.config.Add("datapadInventoryMaxWidth", 0, "Maximum visible datapad inventory width. 0 uses the character's current inventory width.", nil, {
    data = {min = 0, max = 20},
    category = "Republic Datapad"
})

ix.config.Add("datapadInventoryMaxHeight", 0, "Maximum visible datapad inventory height. 0 uses the character's current inventory height.", nil, {
    data = {min = 0, max = 20},
    category = "Republic Datapad"
})

-- The default Helix business page is a generic item shop and has no useful
-- context in this schema yet. Keep it hidden until it is replaced by a proper
-- requisitions/logistics system.
function PLUGIN:BuildBusinessMenu()
    return false
end

if SERVER then
    resource.AddFile("sound/swrp/ui/ui_menuBack.wav")
    resource.AddFile("sound/swrp/ui/ui_menuMove.wav")
    resource.AddFile("sound/swrp/ui/ui_planetzoom.wav")

    util.AddNetworkString("swrpDatapadRequestStaff")
    util.AddNetworkString("swrpDatapadStaffRoster")

    local STAFF_DATA_KEY = "swrpDatapadStaffRoster"

    local function updateServerClock()
        SetGlobalString("swrpDatapadServerTime", os.date("%H:%M"))
        SetGlobalString("swrpDatapadServerDate", os.date("%d %b %Y"))
    end

    updateServerClock()
    timer.Create("swrpDatapadServerClock", 15, 0, updateServerClock)

    local function getStoredStaff()
        local records = ix.data.Get(STAFF_DATA_KEY, {})
        return istable(records) and records or {}
    end

    local function saveStoredStaff(records)
        ix.data.Set(STAFF_DATA_KEY, records)
    end

    local function updateStaffRecord(client, online)
        if not IsValid(client) or not client:IsAdmin() then
            return
        end

        local steamID64 = client:SteamID64()
        if not isstring(steamID64) or not steamID64:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") or steamID64 == "0" then
            return
        end

        local records = getStoredStaff()
        records[steamID64] = {
            steamID64 = steamID64,
            name = client:Nick(),
            usergroup = client:GetUserGroup(),
            lastOnline = os.time(),
            online = online == true
        }
        saveStoredStaff(records)
    end

    hook.Add("PlayerInitialSpawn", "swrpDatapadTrackStaffJoin", function(client)
        timer.Simple(5, function()
            if IsValid(client) then
                updateStaffRecord(client, true)
            end
        end)
    end)

    hook.Add("PlayerDisconnected", "swrpDatapadTrackStaffLeave", function(client)
        updateStaffRecord(client, false)
    end)

    local function buildStaffRoster()
        local stored = getStoredStaff()
        local canonical = {}
        local liveNames = {}

        -- Live data is authoritative and also gives us a name/usergroup key for
        -- removing stale duplicate records created by older builds.
        for _, client in ipairs(player.GetAll()) do
            if client:IsAdmin() then
                local steamID64 = tostring(client:SteamID64() or "")
                if steamID64:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") and steamID64 ~= "0" then
                    local record = {
                        steamID64 = steamID64,
                        name = client:Nick(),
                        usergroup = client:GetUserGroup(),
                        lastOnline = os.time(),
                        online = true
                    }
                    canonical[steamID64] = record
                    liveNames[string.lower(record.name .. "|" .. record.usergroup)] = true
                end
            end
        end

        for storageKey, record in pairs(stored) do
            if istable(record) then
                local steamID64 = tostring(record.steamID64 or storageKey or "")
                local name = tostring(record.name or "Unknown Staff")
                local usergroup = tostring(record.usergroup or "admin")
                local nameKey = string.lower(name .. "|" .. usergroup)
                local validID = steamID64:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") and steamID64 ~= "0"

                -- Do not add an offline copy when the same staff identity is
                -- currently connected under a valid SteamID64.
                if validID and not canonical[steamID64] and not liveNames[nameKey] then
                    canonical[steamID64] = {
                        steamID64 = steamID64,
                        name = name,
                        usergroup = usergroup,
                        lastOnline = tonumber(record.lastOnline) or 0,
                        online = false
                    }
                end
            end
        end

        -- Persist the cleaned canonical map so legacy duplicates disappear.
        saveStoredStaff(canonical)

        local output = {}
        for _, record in pairs(canonical) do
            output[#output + 1] = record
        end

        table.sort(output, function(a, b)
            if a.online ~= b.online then
                return a.online
            end

            if a.lastOnline ~= b.lastOnline then
                return a.lastOnline > b.lastOnline
            end

            return string.lower(a.name) < string.lower(b.name)
        end)

        return output
    end

    net.Receive("swrpDatapadRequestStaff", function(_, client)
        net.Start("swrpDatapadStaffRoster")
            net.WriteTable(buildStaffRoster())
        net.Send(client)
    end)

    local function getAutomaticServiceNumber(character)
        local characterID = math.max(math.floor(tonumber(character:GetID()) or 1), 1)
        local serviceNumber = ((characterID - 1) % 9999) + 1
        return string.format("%04d", serviceNumber)
    end

    local function getServiceNumberFromName(character)
        if not character or not isfunction(character.GetName) then
            return nil
        end

        local name = tostring(character:GetName() or "")
        return name:match("[Cc][Tt][%s%-_:]*(%d%d%d%d)") or name:match("(%d%d%d%d)")
    end

    local function assignServiceNumber(character)
        if not character or not isfunction(character.GetCloneNumber) or not isfunction(character.SetCloneNumber) then
            return
        end

        if not isnumber(FACTION_CLONE) or character:GetFaction() ~= FACTION_CLONE then
            return
        end

        local existing = tostring(character:GetCloneNumber() or ""):gsub("%D", "")
        local parsed = getServiceNumberFromName(character)
        local automatic = getAutomaticServiceNumber(character)

        -- Existing pre-datapad characters often already contain their service
        -- number in names such as "CT 1093 Sam". Prefer that real number over
        -- the temporary character-ID fallback generated by V2.
        if parsed and #parsed == 4 and (existing == "" or existing == automatic) then
            character:SetCloneNumber(parsed)
            return
        end

        if #existing == 4 then
            return
        end

        character:SetCloneNumber(automatic)
    end

    function PLUGIN:PlayerLoadedCharacter(client, character, previousCharacter)
        timer.Simple(0, function()
            if IsValid(client) and client:GetCharacter() == character then
                assignServiceNumber(character)
                updateStaffRecord(client, true)

                if SWRP and SWRP.Datapad and isfunction(SWRP.Datapad.MigrateUpgradeTree) then
                    SWRP.Datapad.MigrateUpgradeTree(character)
                end
            end
        end)
    end
else
    SWRP.Datapad.StaffRoster = SWRP.Datapad.StaffRoster or {}

    function SWRP.Datapad.RequestStaffRoster()
        net.Start("swrpDatapadRequestStaff")
        net.SendToServer()
    end

    net.Receive("swrpDatapadStaffRoster", function()
        SWRP.Datapad.StaffRoster = net.ReadTable() or {}
        hook.Run("SWRPDatapadStaffRosterUpdated", SWRP.Datapad.StaffRoster)
    end)
end
