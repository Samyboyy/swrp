-- swrp/plugins/datapad/libs/sh_upgrade_tree.lua
-- Shared Republic career-development tree and persistent unlock helpers.
--
-- Node bit positions (and therefore the persistent upgrade_mask) are derived from
-- branch order and node order below. DO NOT reorder branches or nodes, rename ids,
-- or bump TREE.version without a matching migration: doing so shifts bit positions
-- and corrupts every character's saved progression.
--
-- Node screen positions are NOT stored anywhere. They are recomputed here from the
-- prerequisite graph (SWRP.Datapad.LayoutUpgradeTree) so the client can render the
-- tree as a readable progression path rather than hand-scattered coordinates.

SWRP = SWRP or {}
SWRP.Datapad = SWRP.Datapad or {}

local TREE = {}
TREE.version = 7
TREE.cost = 1
TREE.amount = 10
TREE.root = {
    id = "root",
    title = "REPUBLIC SERVICE RECORD",
    description = "Baseline Grand Army personnel profile.",
    x = 0,
    y = 0
}
TREE.nodes = {}
TREE.nodesByID = {}
TREE.branches = {}
TREE.bounds = {minX = -1100, maxX = 1100, minY = -1100, maxY = 1100}

local bitIndex = 0

local function addBranch(definition)
    local branch = {
        id = definition.id,
        title = definition.title,
        subtitle = definition.subtitle,
        colour = definition.colour,
        direction = definition.direction,
        nodes = {},
        -- Presentation fields below are filled in by LayoutUpgradeTree().
        titleX = 0,
        titleY = 0,
        titleAlign = "center",
        sectorStart = 0,
        sectorEnd = 0
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

-- direction is the unit vector the branch grows along (screen space, +y is down):
--   conditioning up {0,-1}, aviation right {1,0}, medical left {-1,0}, weapons down {0,1}.
addBranch({
    id = "conditioning",
    title = "PHYSICAL CONDITIONING",
    subtitle = "DURABILITY, MOBILITY AND LOAD HANDLING",
    colour = {73, 154, 219},
    direction = {0, -1},
    nodes = {
        {id = "endurance_1", title = "Combat Endurance I", kind = "attribute", attribute = "endurance", effect = "+10 Endurance", description = "Raises the character's Endurance conditioning score by 10.", requires = {"root"}},
        {id = "stamina_1", title = "Cardio Conditioning I", kind = "attribute", attribute = "stamina", effect = "+10 Stamina", description = "Raises the character's Stamina conditioning score by 10.", requires = {"endurance_1"}},
        {id = "strength_1", title = "Load Conditioning I", kind = "attribute", attribute = "strength", effect = "+10 Strength", description = "Raises the character's Strength conditioning score by 10.", requires = {"endurance_1"}},
        {id = "endurance_2", title = "Impact Tolerance", kind = "attribute", attribute = "endurance", effect = "+10 Endurance", description = "Improves sustained combat conditioning and impact tolerance.", requires = {"stamina_1"}},
        {id = "stamina_2", title = "Forced March", kind = "attribute", attribute = "stamina", effect = "+10 Stamina", description = "Improves sustained movement conditioning.", requires = {"stamina_1", "strength_1"}, requiresMode = "any"},
        {id = "strength_2", title = "Weapon Stability", kind = "attribute", attribute = "strength", effect = "+10 Strength", description = "Improves load handling and weapon-control conditioning.", requires = {"strength_1"}},
        {id = "endurance_3", title = "Trauma Resistance", kind = "attribute", attribute = "endurance", effect = "+10 Endurance", description = "Advances the Endurance conditioning branch.", requires = {"endurance_2"}},
        {id = "stamina_3", title = "Rapid Recovery", kind = "attribute", attribute = "stamina", effect = "+10 Stamina", description = "Advances the Stamina conditioning branch.", requires = {"stamina_2", "strength_2"}, requiresMode = "any"},
        {id = "strength_3", title = "Powered Movement", kind = "attribute", attribute = "strength", effect = "+10 Strength", description = "Advances the Strength conditioning branch.", requires = {"endurance_3", "stamina_3"}},
        {id = "vanguard", title = "Vanguard Conditioning", kind = "attribute", attribute = "endurance", effect = "+10 Endurance", description = "Final conditioning node for a front-line Republic trooper.", requires = {"strength_3"}}
    }
})

addBranch({
    id = "aviation",
    title = "AVIATION",
    subtitle = "VEHICLE AND FLIGHT AUTHORISATIONS",
    colour = {87, 190, 224},
    direction = {1, 0},
    nodes = {
        {id = "aptitude", title = "Flight Aptitude", kind = "capability", capability = "flight_aptitude", effect = "Flight training access", description = "Authorises the character to begin formal flight instruction.", requires = {"root"}},
        {id = "trainee", title = "Pilot Trainee", kind = "capability", capability = "pilot_trainee", effect = "Training craft access", description = "Records successful completion of introductory flight controls and safety training.", requires = {"aptitude"}},
        {id = "starfighter", title = "Starfighter Qualification", kind = "capability", capability = "starfighter_pilot", effect = "Starfighter authorisation", description = "Authorises operation of approved Republic starfighters.", requires = {"trainee"}},
        {id = "transport", title = "Transport Qualification", kind = "capability", capability = "transport_pilot", effect = "Transport authorisation", description = "Authorises operation of approved transports and gunships.", requires = {"trainee"}},
        {id = "pilot", title = "Republic Pilot", kind = "capability", capability = "pilot", effect = "Pilot certified", description = "Marks the character as a certified Republic pilot. Vehicle systems can query this authorisation.", requires = {"starfighter", "transport"}},
        {id = "advanced", title = "Advanced Flight Operations", kind = "capability", capability = "advanced_pilot", effect = "Advanced vehicle clearance", description = "Grants advanced flight-operations clearance for future vehicle systems.", requires = {"pilot"}}
    }
})

addBranch({
    id = "medical",
    title = "MEDICAL",
    subtitle = "FIELD CARE AND TRAUMA CERTIFICATIONS",
    colour = {92, 205, 176},
    direction = {-1, 0},
    nodes = {
        {id = "basics", title = "Medical Fundamentals", kind = "capability", capability = "medical_fundamentals", effect = "Medical training access", description = "Authorises introductory Republic medical instruction.", requires = {"root"}},
        {id = "trauma", title = "Trauma Response", kind = "capability", capability = "trauma_response", effect = "Trauma-response trained", description = "Records battlefield trauma-response training.", requires = {"basics"}},
        {id = "bacta", title = "Bacta Handling", kind = "capability", capability = "bacta_handling", effect = "Bacta authorised", description = "Authorises the character to handle approved bacta equipment.", requires = {"trauma"}},
        {id = "triage", title = "Field Triage", kind = "capability", capability = "field_triage", effect = "Triage authorised", description = "Records field-triage and casualty-prioritisation training.", requires = {"trauma"}},
        {id = "medic", title = "Field Medic", kind = "capability", capability = "medic", effect = "Medic certified", description = "Marks the character as a certified field medic. Medical systems can query this authorisation.", requires = {"bacta", "triage"}},
        {id = "combat_medic", title = "Combat Medic", kind = "capability", capability = "combat_medic", effect = "Advanced medic clearance", description = "Grants advanced battlefield medical clearance.", requires = {"medic"}}
    }
})

addBranch({
    id = "weapons",
    title = "WEAPONS",
    subtitle = "SPECIALIST WEAPON AUTHORISATIONS",
    colour = {218, 162, 91},
    direction = {0, 1},
    nodes = {
        {id = "advanced_rifle", title = "Advanced Rifle Drill", kind = "capability", capability = "advanced_rifle", effect = "Advanced rifle authorised", description = "Records advanced service-rifle handling and fire-control training.", requires = {"root"}},
        {id = "marksman", title = "Marksman Qualification", kind = "capability", capability = "marksman", effect = "Precision weapon authorised", description = "Authorises approved precision and marksman weapon systems.", requires = {"advanced_rifle"}},
        {id = "heavy", title = "Heavy Weapons", kind = "capability", capability = "heavy_weapons", effect = "Heavy weapons authorised", description = "Authorises approved repeating blasters and heavy weapon platforms.", requires = {"marksman"}},
        {id = "explosives", title = "Explosives Handling", kind = "capability", capability = "explosives", effect = "Explosives authorised", description = "Authorises approved Republic explosive devices and demolition charges.", requires = {"marksman"}},
        {id = "launcher", title = "Launcher Systems", kind = "capability", capability = "launcher_weapons", effect = "Launcher authorised", description = "Authorises approved anti-armour and launcher systems.", requires = {"heavy", "explosives"}},
        {id = "specialist", title = "Weapons Specialist", kind = "capability", capability = "weapons_specialist", effect = "Specialist arsenal clearance", description = "Grants specialist arsenal clearance for future requisition systems.", requires = {"launcher"}}
    }
})

-- Deterministic layout derived purely from the prerequisite graph.
--   * depth  = longest prerequisite chain from the root (a node is never placed
--     closer to the centre than any of its prerequisites).
--   * along-axis distance is a function of depth; siblings at the same depth are
--     spread perpendicular to the branch direction, centred on the parent path.
-- The optional per-node nudgeX/nudgeY fields (unused by default) exist only as a
-- future manual-polish hook; the base structure stays fully deterministic.
local INNER_GAP = 205      -- distance of depth-1 nodes from the centre
local DEPTH_STEP = 150     -- extra distance per depth level
local PERP_STEP = 150      -- spacing between siblings across the branch axis
local SECTOR_HALF = 35     -- half-width (degrees) of each branch's coloured region

local function branchDepths(branch)
    local depth = {}
    local maxDepth = 0
    for _, node in ipairs(branch.nodes) do
        local d = 0
        for _, requirementID in ipairs(node.requires) do
            if requirementID ~= "root" then
                d = math.max(d, depth[requirementID] or 0)
            end
        end
        depth[node.id] = d + 1
        maxDepth = math.max(maxDepth, d + 1)
    end
    return depth, maxDepth
end

function SWRP.Datapad.LayoutUpgradeTree()
    local minX, minY, maxX, maxY = 0, 0, 0, 0

    for _, branch in ipairs(TREE.branches) do
        local dir = branch.direction or {0, -1}
        local dx, dy = dir[1], dir[2]
        local depth, maxDepth = branchDepths(branch)

        -- Group nodes by depth (preserving node order for stable tie-breaks).
        local byDepth = {}
        for _, node in ipairs(branch.nodes) do
            local d = depth[node.id]
            byDepth[d] = byDepth[d] or {}
            byDepth[d][#byDepth[d] + 1] = node
        end

        -- Perpendicular offset: barycentre of parents, then evenly spaced per depth.
        local perp = {}
        for d = 1, maxDepth do
            local group = byDepth[d] or {}
            for _, node in ipairs(group) do
                local sum, count = 0, 0
                for _, requirementID in ipairs(node.requires) do
                    if requirementID ~= "root" and perp[requirementID] then
                        sum = sum + perp[requirementID]
                        count = count + 1
                    end
                end
                node._guess = count > 0 and (sum / count) or 0
            end

            table.sort(group, function(a, b)
                if a._guess == b._guess then return a.order < b.order end
                return a._guess < b._guess
            end)

            local count = #group
            for i, node in ipairs(group) do
                perp[node.id] = count > 1 and (i - (count + 1) * 0.5) * PERP_STEP or node._guess
                node._guess = nil
            end
        end

        -- Map (depth, perpendicular) into world coordinates along the branch axis.
        local far = 0
        for _, node in ipairs(branch.nodes) do
            local along = INNER_GAP + (depth[node.id] - 1) * DEPTH_STEP
            local p = perp[node.id] or 0
            node.depth = depth[node.id]
            node.x = math.Round(dx * along + (-dy) * p + (node.nudgeX or 0))
            node.y = math.Round(dy * along + (dx) * p + (node.nudgeY or 0))
            far = math.max(far, node.x * dx + node.y * dy)

            minX, maxX = math.min(minX, node.x), math.max(maxX, node.x)
            minY, maxY = math.min(minY, node.y), math.max(maxY, node.y)
        end

        -- Coloured sector centred on the branch direction, leaving a gap to neighbours.
        local centreAngle = math.deg(math.atan2(dy, dx))
        branch.sectorStart = centreAngle - SECTOR_HALF
        branch.sectorEnd = centreAngle + SECTOR_HALF

        -- Heading sits just beyond the outermost node, aligned so it grows away
        -- from the tree instead of back across the nodes.
        branch.titleX = math.Round(dx * (far + 150))
        branch.titleY = math.Round(dy * (far + 150))
        if dx > 0.5 then
            branch.titleAlign = "left"
        elseif dx < -0.5 then
            branch.titleAlign = "right"
        else
            branch.titleAlign = "center"
        end
    end

    -- Reserve horizontal room so CENTRE frames the left/right heading anchors.
    -- (Heading text is fixed-pixel and lives inside ResetView's screen padding.)
    for _, branch in ipairs(TREE.branches) do
        if branch.titleAlign == "left" then
            maxX = math.max(maxX, branch.titleX + 130)
        elseif branch.titleAlign == "right" then
            minX = math.min(minX, branch.titleX - 130)
        end
    end

    TREE.bounds = {
        minX = minX - 120,
        maxX = maxX + 120,
        minY = minY - 150,
        maxY = maxY + 120
    }
end

SWRP.Datapad.LayoutUpgradeTree()

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
