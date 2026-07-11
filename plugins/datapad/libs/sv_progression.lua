-- swrp/plugins/datapad/libs/sv_progression.lua
-- Server-authoritative Republic career-development tree and identity handling.

util.AddNetworkString("swrpDatapadPurchaseUpgrade")
util.AddNetworkString("swrpDatapadUpgradeResult")

local function getTree()
    return SWRP and SWRP.Datapad and SWRP.Datapad.UpgradeTree or nil
end

local function sendUpgradeResult(client, success, message, nodeID)
    if not IsValid(client) then return end

    net.Start("swrpDatapadUpgradeResult")
        net.WriteBool(success)
        net.WriteString(message or "Upgrade request processed.")
        net.WriteString(nodeID or "")
    net.Send(client)
end

local function getAttributeMaximum(attribute, minimum)
    local configuredMaximum = ix.config.Get("maxAttributes", 100)
    return math.max(tonumber(attribute and attribute.maxValue) or tonumber(configuredMaximum) or 100, minimum or 10)
end

function SWRP.Datapad.MigrateUpgradeTree(character)
    local tree = getTree()
    if not tree or not character or not isfunction(character.GetUpgradeTreeVersion) then return end

    local version = math.floor(tonumber(character:GetUpgradeTreeVersion()) or 0)
    if version >= tree.version then return end

    -- V5 changes the graph structure. Preserve purchased attribute values, then
    -- reconstruct the matching conditioning nodes rather than carrying stale bit positions.
    local mask = 0
    local remainingByAttribute = {}

    for _, node in ipairs(tree.nodes or {}) do
        if node.kind == "attribute" and node.attribute then
            remainingByAttribute[node.attribute] = remainingByAttribute[node.attribute]
                or math.Clamp(math.floor((tonumber(character:GetAttribute(node.attribute, 0)) or 0) / tree.amount), 0, 30)
        end
    end

    for _, node in ipairs(tree.nodes or {}) do
        if node.kind == "attribute" and node.attribute and (remainingByAttribute[node.attribute] or 0) > 0 then
            mask = tree.AddToMask(mask, node)
            remainingByAttribute[node.attribute] = remainingByAttribute[node.attribute] - 1
        end
    end

    character:SetUpgradeMask(mask)
    character:SetUpgradeTreeVersion(tree.version)
end

net.Receive("swrpDatapadPurchaseUpgrade", function(_, client)
    if not IsValid(client) then return end
    if (client.swrpNextDatapadUpgrade or 0) > CurTime() then return end
    client.swrpNextDatapadUpgrade = CurTime() + 0.35

    local tree = getTree()
    local nodeID = net.ReadString()
    local character = client:GetCharacter()

    if not tree then
        sendUpgradeResult(client, false, "The Republic development tree is unavailable.", nodeID)
        return
    end

    local node = tree.GetNode(nodeID)
    if not node or node.id == "root" then
        sendUpgradeResult(client, false, "That development node is not recognised.", nodeID)
        return
    end

    if not character then
        sendUpgradeResult(client, false, "No active personnel record was found.", nodeID)
        return
    end

    SWRP.Datapad.MigrateUpgradeTree(character)

    local mask = tree.GetMask(character)
    if tree.IsUnlocked(mask, node) then
        sendUpgradeResult(client, false, "That development node is already installed.", nodeID)
        return
    end

    if not tree.PrerequisitesMet(mask, node) then
        sendUpgradeResult(client, false, "Complete a connected prerequisite path first.", nodeID)
        return
    end

    local points = math.max(math.floor(tonumber(character:GetSkillPoints()) or 0), 0)
    local cost = math.max(math.floor(tonumber(node.cost) or tree.cost or 1), 1)
    if points < cost then
        sendUpgradeResult(client, false, "You do not have enough upgrade points.", nodeID)
        return
    end

    local resultMessage

    if node.kind == "attribute" then
        local attribute = ix.attributes.list[node.attribute]
        if not attribute then
            sendUpgradeResult(client, false, "The linked attribute is not registered.", nodeID)
            return
        end

        local current = tonumber(character:GetAttribute(node.attribute, 0)) or 0
        local maximum = getAttributeMaximum(attribute, tree.amount)
        local amount = math.min(tree.amount, maximum - current)

        if amount <= 0 then
            sendUpgradeResult(client, false, "This conditioning attribute is already at its maximum value.", nodeID)
            return
        end

        character:UpdateAttrib(node.attribute, amount)
        resultMessage = string.format("%s installed: %s increased by +%d.", node.title, L(attribute.name or node.attribute), amount)
    else
        resultMessage = string.format("%s authorised on your Republic service record.", node.title)
    end

    character:SetSkillPoints(points - cost)
    character:SetUpgradeMask(tree.AddToMask(mask, node))
    character:SetUpgradeTreeVersion(tree.version)
    sendUpgradeResult(client, true, resultMessage, nodeID)
end)

ix.command.Add("SWRPAddSkillPoints", {
    description = "Adds upgrade points to a character's Republic service record.",
    adminOnly = true,
    arguments = {ix.type.player, ix.type.number},
    OnRun = function(self, client, target, amount)
        local character = IsValid(target) and target:GetCharacter() or nil
        if not character then return "That player does not have an active character." end

        amount = math.floor(tonumber(amount) or 0)
        if amount == 0 then return "The amount must be a non-zero whole number." end

        local current = math.max(math.floor(tonumber(character:GetSkillPoints()) or 0), 0)
        local updated = math.max(current + amount, 0)
        character:SetSkillPoints(updated)
        target:Notify(string.format("Your Republic service record now has %d upgrade point%s.", updated, updated == 1 and "" or "s"))
        return string.format("Set %s's available upgrade points to %d.", target:Name(), updated)
    end
})

ix.command.Add("SWRPSetSkillPoints", {
    description = "Sets the exact number of upgrade points on a character's Republic service record.",
    adminOnly = true,
    arguments = {ix.type.player, ix.type.number},
    OnRun = function(self, client, target, amount)
        local character = IsValid(target) and target:GetCharacter() or nil
        if not character then return "That player does not have an active character." end

        amount = math.max(math.floor(tonumber(amount) or 0), 0)
        character:SetSkillPoints(amount)
        target:Notify(string.format("Your Republic service record now has %d upgrade point%s.", amount, amount == 1 and "" or "s"))
        return string.format("Set %s's available upgrade points to %d.", target:Name(), amount)
    end
})

ix.command.Add("SWRPSetCloneNumber", {
    description = "Assigns a four-digit Republic clone service number.",
    adminOnly = true,
    arguments = {ix.type.player, ix.type.string},
    OnRun = function(self, client, target, value)
        local character = IsValid(target) and target:GetCharacter() or nil
        if not character then return "That player does not have an active character." end

        local digits = tostring(value or ""):gsub("%D", "")
        if #digits ~= 4 then return "Clone service numbers must contain exactly four digits." end

        character:SetCloneNumber(digits)
        target:Notify("Your Republic service number has been assigned as CT-" .. digits .. ".")
        return string.format("Assigned %s the service number CT-%s.", target:Name(), digits)
    end
})

-- Adds service XP, performs level-ups and awards one upgrade point per level.
-- Other systems (operations, events, commendations) can call this function.
function SWRP.Datapad.AddServiceXP(character, amount)
    if not character or not isfunction(character.GetXp) or not isfunction(character.SetXp)
    or not isfunction(character.GetLevel) or not isfunction(character.SetLevel) then
        return false, "That character does not support service progression."
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 then return false, "The XP amount must be non-zero." end

    local level = math.max(math.floor(tonumber(character:GetLevel()) or 1), 1)
    local xp = math.max(math.floor(tonumber(character:GetXp()) or 0) + amount, 0)
    local levelsGained = 0

    while amount > 0 do
        local requirement = SWRP.Datapad.GetXPRequirement(character, level)
        if xp < requirement then break end
        xp = xp - requirement
        level = level + 1
        levelsGained = levelsGained + 1
        if levelsGained >= 100 then break end
    end

    character:SetXp(xp)
    character:SetLevel(level)

    if levelsGained > 0 and isfunction(character.GetSkillPoints) and isfunction(character.SetSkillPoints) then
        local points = math.max(math.floor(tonumber(character:GetSkillPoints()) or 0), 0)
        character:SetSkillPoints(points + levelsGained)
    end

    return true, levelsGained
end

ix.command.Add("SWRPAddXP", {
    description = "Adds service XP and processes Republic career level-ups.",
    adminOnly = true,
    arguments = {ix.type.player, ix.type.number},
    OnRun = function(self, client, target, amount)
        local character = IsValid(target) and target:GetCharacter() or nil
        if not character then return "That player does not have an active character." end

        amount = math.floor(tonumber(amount) or 0)
        local success, result = SWRP.Datapad.AddServiceXP(character, amount)
        if not success then return result end

        local level = math.max(math.floor(tonumber(character:GetLevel()) or 1), 1)
        local xp = math.max(math.floor(tonumber(character:GetXp()) or 0), 0)
        local requirement = SWRP.Datapad.GetXPRequirement(character, level)
        target:Notify(string.format("Service record updated: level %d, %d/%d XP.", level, xp, requirement))

        if result > 0 then
            return string.format("Added %d XP to %s. They gained %d level%s and %d upgrade point%s.", amount, target:Name(), result, result == 1 and "" or "s", result, result == 1 and "" or "s")
        end

        return string.format("Added %d XP to %s. Current progress: %d/%d XP at level %d.", amount, target:Name(), xp, requirement, level)
    end
})
