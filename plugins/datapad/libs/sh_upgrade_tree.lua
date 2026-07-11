-- swrp/plugins/datapad/libs/sh_upgrade_tree.lua
-- Shared Republic career-development tree and persistent unlock helpers.

SWRP = SWRP or {}
SWRP.Datapad = SWRP.Datapad or {}

local TREE = {}
TREE.version = 5
TREE.cost = 1
TREE.amount = 10
TREE.root = {
    id = "root",
    title = "REPUBLIC SERVICE RECORD",
    description = "Baseline Grand Army personnel profile.",
    x = -620,
    y = 40
}
TREE.nodes = {}
TREE.nodesByID = {}
TREE.branches = {}
TREE.bounds = {
    minX = -760,
    maxX = 1020,
    minY = -500,
    maxY = 570
}

local bitIndex = 0

local function addBranch(definition)
    local branch = {
        id = definition.id,
        title = definition.title,
        subtitle = definition.subtitle,
        colour = definition.colour,
        titleX = definition.titleX or -520,
        titleY = definition.titleY,
        nodes = {}
    }

    for index, data in ipairs(definition.nodes) do
        local node = table.Copy(data)
        node.id = definition.id .. "_" .. data.id
        node.branch = definition.id
        node.colour = definition.colour
        node.order = index
        node.bit = bitIndex
        node.cost = node.cost or TREE.cost
        node.requires = node.requires or {}

        local resolved = {}
        for _, requirement in ipairs(node.requires) do
            resolved[#resolved + 1] = requirement == "root" and "root" or (definition.id .. "_" .. requirement)
        end
        node.requires = resolved

        bitIndex = bitIndex + 1
        TREE.nodes[#TREE.nodes + 1] = node
        TREE.nodesByID[node.id] = node
        branch.nodes[#branch.nodes + 1] = node
    end

    TREE.branches[#TREE.branches + 1] = branch
end

addBranch({
    id = "conditioning",
    title = "PHYSICAL CONDITIONING",
    subtitle = "DURABILITY, MOBILITY AND LOAD HANDLING",
    colour = {73, 154, 219},
    titleY = -455,
    nodes = {
        {id = "endurance_1", title = "Combat Endurance I", kind = "attribute", attribute = "endurance", effect = "+10 Endurance", description = "Raises the character's Endurance conditioning score by 10.", x = -360, y = -315, requires = {"root"}},
        {id = "stamina_1", title = "Cardio Conditioning I", kind = "attribute", attribute = "stamina", effect = "+10 Stamina", description = "Raises the character's Stamina conditioning score by 10.", x = -150, y = -315, requires = {"endurance_1"}},
        {id = "strength_1", title = "Load Conditioning I", kind = "attribute", attribute = "strength", effect = "+10 Strength", description = "Raises the character's Strength conditioning score by 10.", x = 65, y = -375, requires = {"stamina_1"}},
        {id = "endurance_2", title = "Impact Tolerance", kind = "attribute", attribute = "endurance", effect = "+10 Endurance", description = "Improves sustained combat conditioning and impact tolerance.", x = 65, y = -255, requires = {"stamina_1"}},
        {id = "stamina_2", title = "Forced March", kind = "attribute", attribute = "stamina", effect = "+10 Stamina", description = "Improves sustained movement conditioning.", x = 285, y = -395, requires = {"strength_1"}},
        {id = "strength_2", title = "Weapon Stability", kind = "attribute", attribute = "strength", effect = "+10 Strength", description = "Improves load handling and weapon-control conditioning.", x = 285, y = -235, requires = {"endurance_2"}},
        {id = "endurance_3", title = "Trauma Resistance", kind = "attribute", attribute = "endurance", effect = "+10 Endurance", description = "Advances the Endurance conditioning branch.", x = 510, y = -375, requires = {"stamina_2"}},
        {id = "stamina_3", title = "Rapid Recovery", kind = "attribute", attribute = "stamina", effect = "+10 Stamina", description = "Advances the Stamina conditioning branch.", x = 510, y = -255, requires = {"strength_2"}},
        {id = "strength_3", title = "Powered Movement", kind = "attribute", attribute = "strength", effect = "+10 Strength", description = "Advances the Strength conditioning branch.", x = 735, y = -315, requires = {"endurance_3", "stamina_3"}},
        {id = "vanguard", title = "Vanguard Conditioning", kind = "attribute", attribute = "endurance", effect = "+10 Endurance", description = "Final conditioning node for a front-line Republic trooper.", x = 945, y = -315, requires = {"strength_3"}}
    }
})

addBranch({
    id = "aviation",
    title = "AVIATION",
    subtitle = "VEHICLE AND FLIGHT AUTHORISATIONS",
    colour = {87, 190, 224},
    titleY = -170,
    nodes = {
        {id = "aptitude", title = "Flight Aptitude", kind = "capability", capability = "flight_aptitude", effect = "Flight training access", description = "Authorises the character to begin formal flight instruction.", x = -360, y = -80, requires = {"root"}},
        {id = "trainee", title = "Pilot Trainee", kind = "capability", capability = "pilot_trainee", effect = "Training craft access", description = "Records successful completion of introductory flight controls and safety training.", x = -120, y = -80, requires = {"aptitude"}},
        {id = "starfighter", title = "Starfighter Qualification", kind = "capability", capability = "starfighter_pilot", effect = "Starfighter authorisation", description = "Authorises operation of approved Republic starfighters.", x = 150, y = -140, requires = {"trainee"}},
        {id = "transport", title = "Transport Qualification", kind = "capability", capability = "transport_pilot", effect = "Transport authorisation", description = "Authorises operation of approved transports and gunships.", x = 150, y = -20, requires = {"trainee"}},
        {id = "pilot", title = "Republic Pilot", kind = "capability", capability = "pilot", effect = "Pilot certified", description = "Marks the character as a certified Republic pilot. Vehicle systems can query this authorisation.", x = 455, y = -80, requires = {"starfighter", "transport"}, requiresMode = "any"},
        {id = "advanced", title = "Advanced Flight Operations", kind = "capability", capability = "advanced_pilot", effect = "Advanced vehicle clearance", description = "Grants advanced flight-operations clearance for future vehicle systems.", x = 735, y = -80, requires = {"pilot"}}
    }
})

addBranch({
    id = "medical",
    title = "MEDICAL",
    subtitle = "FIELD CARE AND TRAUMA CERTIFICATIONS",
    colour = {92, 205, 176},
    titleY = 80,
    nodes = {
        {id = "basics", title = "Medical Fundamentals", kind = "capability", capability = "medical_fundamentals", effect = "Medical training access", description = "Authorises introductory Republic medical instruction.", x = -360, y = 165, requires = {"root"}},
        {id = "trauma", title = "Trauma Response", kind = "capability", capability = "trauma_response", effect = "Trauma-response trained", description = "Records battlefield trauma-response training.", x = -120, y = 165, requires = {"basics"}},
        {id = "bacta", title = "Bacta Handling", kind = "capability", capability = "bacta_handling", effect = "Bacta authorised", description = "Authorises the character to handle approved bacta equipment.", x = 150, y = 105, requires = {"trauma"}},
        {id = "triage", title = "Field Triage", kind = "capability", capability = "field_triage", effect = "Triage authorised", description = "Records field-triage and casualty-prioritisation training.", x = 150, y = 225, requires = {"trauma"}},
        {id = "medic", title = "Field Medic", kind = "capability", capability = "medic", effect = "Medic certified", description = "Marks the character as a certified field medic. Medical systems can query this authorisation.", x = 455, y = 165, requires = {"bacta", "triage"}},
        {id = "combat_medic", title = "Combat Medic", kind = "capability", capability = "combat_medic", effect = "Advanced medic clearance", description = "Grants advanced battlefield medical clearance.", x = 735, y = 165, requires = {"medic"}}
    }
})

addBranch({
    id = "weapons",
    title = "WEAPONS",
    subtitle = "SPECIALIST WEAPON AUTHORISATIONS",
    colour = {218, 162, 91},
    titleY = 325,
    nodes = {
        {id = "advanced_rifle", title = "Advanced Rifle Drill", kind = "capability", capability = "advanced_rifle", effect = "Advanced rifle authorised", description = "Records advanced service-rifle handling and fire-control training.", x = -360, y = 410, requires = {"root"}},
        {id = "marksman", title = "Marksman Qualification", kind = "capability", capability = "marksman", effect = "Precision weapon authorised", description = "Authorises approved precision and marksman weapon systems.", x = -120, y = 410, requires = {"advanced_rifle"}},
        {id = "heavy", title = "Heavy Weapons", kind = "capability", capability = "heavy_weapons", effect = "Heavy weapons authorised", description = "Authorises approved repeating blasters and heavy weapon platforms.", x = 150, y = 350, requires = {"marksman"}},
        {id = "explosives", title = "Explosives Handling", kind = "capability", capability = "explosives", effect = "Explosives authorised", description = "Authorises approved Republic explosive devices and demolition charges.", x = 150, y = 470, requires = {"marksman"}},
        {id = "launcher", title = "Launcher Systems", kind = "capability", capability = "launcher_weapons", effect = "Launcher authorised", description = "Authorises approved anti-armour and launcher systems.", x = 455, y = 410, requires = {"heavy", "explosives"}, requiresMode = "any"},
        {id = "specialist", title = "Weapons Specialist", kind = "capability", capability = "weapons_specialist", effect = "Specialist arsenal clearance", description = "Grants specialist arsenal clearance for future requisition systems.", x = 735, y = 410, requires = {"launcher"}}
    }
})

function TREE.GetNode(nodeID)
    if nodeID == "root" then
        return TREE.root
    end

    return TREE.nodesByID[tostring(nodeID or "")]
end

function TREE.GetMask(character)
    if not character or not isfunction(character.GetUpgradeMask) then
        return 0
    end

    return math.max(math.floor(tonumber(character:GetUpgradeMask()) or 0), 0)
end

function TREE.IsUnlocked(mask, nodeOrID)
    local node = istable(nodeOrID) and nodeOrID or TREE.GetNode(nodeOrID)

    if not node then
        return false
    end

    if node.id == "root" then
        return true
    end

    mask = math.max(math.floor(tonumber(mask) or 0), 0)
    return bit.band(mask, bit.lshift(1, node.bit)) ~= 0
end

function TREE.AddToMask(mask, nodeOrID)
    local node = istable(nodeOrID) and nodeOrID or TREE.GetNode(nodeOrID)

    if not node or node.id == "root" then
        return math.max(math.floor(tonumber(mask) or 0), 0)
    end

    return bit.bor(math.max(math.floor(tonumber(mask) or 0), 0), bit.lshift(1, node.bit))
end

function TREE.PrerequisitesMet(mask, nodeOrID)
    local node = istable(nodeOrID) and nodeOrID or TREE.GetNode(nodeOrID)
    if not node then return false end

    local requirements = node.requires or {}
    if #requirements == 0 then return true end

    if node.requiresMode == "any" then
        for _, requirementID in ipairs(requirements) do
            if TREE.IsUnlocked(mask, requirementID) then return true end
        end
        return false
    end

    for _, requirementID in ipairs(requirements) do
        if not TREE.IsUnlocked(mask, requirementID) then return false end
    end

    return true
end

function TREE.GetBranchProgress(mask, branch)
    local unlocked = 0
    for _, node in ipairs(branch.nodes or {}) do
        if TREE.IsUnlocked(mask, node) then unlocked = unlocked + 1 end
    end
    return unlocked, #(branch.nodes or {})
end

function TREE.HasCapability(character, capability)
    local mask = TREE.GetMask(character)
    for _, node in ipairs(TREE.nodes) do
        if node.capability == capability and TREE.IsUnlocked(mask, node) then
            return true
        end
    end
    return false
end

function SWRP.Datapad.HasCapability(character, capability)
    return TREE.HasCapability(character, capability)
end

SWRP.Datapad.UpgradeTree = TREE

function SWRP.Datapad.GetXPRequirement(character, level)
    level = math.max(math.floor(tonumber(level) or 1), 1)
    local overridden = hook.Run("SWRPGetXPRequirement", character, level)
    if isnumber(overridden) and overridden > 0 then
        return math.floor(overridden)
    end

    return 1000
end

ix.char.RegisterVar("upgradeMask", {
    field = "upgrade_mask",
    fieldType = ix.type.number,
    default = 0,
    isLocal = true,
    bNoDisplay = true
})

ix.char.RegisterVar("upgradeTreeVersion", {
    field = "upgrade_tree_version",
    fieldType = ix.type.number,
    default = 0,
    isLocal = true,
    bNoDisplay = true
})
