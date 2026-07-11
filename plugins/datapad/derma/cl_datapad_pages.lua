-- swrp/plugins/datapad/derma/cl_datapad_pages.lua
-- Purpose-built SWRP pages used by the Republic Personnel Datapad.

SWRP = SWRP or {}
SWRP.Datapad = SWRP.Datapad or {}

local UPGRADE_AMOUNT = 10
local UPGRADE_COST = 1

local function getAccent()
    return (ix and ix.config and ix.config.Get("color")) or Color(73, 132, 207)
end

local function alphaColor(colour, alpha)
    return Color(colour.r, colour.g, colour.b, alpha)
end

local function drawCorners(x, y, width, height, colour, length, thickness)
    length = length or 14
    thickness = thickness or 1

    surface.SetDrawColor(colour)
    surface.DrawRect(x, y, length, thickness)
    surface.DrawRect(x, y, thickness, length)
    surface.DrawRect(x + width - length, y, length, thickness)
    surface.DrawRect(x + width - thickness, y, thickness, length)
    surface.DrawRect(x, y + height - thickness, length, thickness)
    surface.DrawRect(x, y + height - length, thickness, length)
    surface.DrawRect(x + width - length, y + height - thickness, length, thickness)
    surface.DrawRect(x + width - thickness, y + height - length, thickness, length)
end

local function characterMethod(character, methodName, fallback)
    if not character then
        return fallback
    end

    local method = character[methodName]
    if not isfunction(method) then
        return fallback
    end

    local success, value = pcall(method, character)
    if not success or value == nil then
        return fallback
    end

    return value
end

local function normaliseCloneNumber(value)
    local digits = tostring(value or ""):gsub("%D", "")

    if digits == "" then
        return "----"
    end

    digits = string.sub(digits, -4)
    return string.format("%04d", tonumber(digits) or 0)
end

local function serviceNumberFromName(name)
    name = tostring(name or "")
    return name:match("[Cc][Tt][%s%-_:]*(%d%d%d%d)") or name:match("(%d%d%d%d)")
end

local function callsignFromName(name)
    name = string.Trim(tostring(name or ""))
    local stripped = name:gsub("^[Cc][Tt][%s%-_:]*%d%d%d%d[%s%-_:]*", "")
    stripped = string.Trim(stripped)
    return stripped ~= "" and stripped or name
end

function SWRP.Datapad.GetIdentity(character)
    local fallbackName = IsValid(LocalPlayer()) and LocalPlayer():Nick() or "UNKNOWN PERSONNEL"
    local name = tostring(characterMethod(character, "GetName", fallbackName))
    local callsign = string.Trim(tostring(characterMethod(character, "GetCallsign", "")))
    local rank = string.Trim(tostring(characterMethod(character, "GetRank", "")))
    local regiment = string.Trim(tostring(characterMethod(character, "GetRegiment", "")))
    local storedCloneNumber = tostring(characterMethod(character, "GetCloneNumber", ""))
    local cloneNumber = normaliseCloneNumber(storedCloneNumber ~= "" and storedCloneNumber or serviceNumberFromName(name))

    if callsign == "" then
        callsign = callsignFromName(name)
    end

    local faction
    local class

    if character then
        faction = ix.faction and ix.faction.indices and ix.faction.indices[character:GetFaction()] or nil
        class = ix.class and ix.class.list and ix.class.list[character:GetClass()] or nil
    end

    local assignment = class and L(class.name) or (faction and L(faction.name) or "UNASSIGNED")
    local displayName = callsign ~= "" and callsign or name
    local trainingState = "UNVERIFIED"

    if SWRP.GetOnboardingState then
        trainingState = tostring(SWRP.GetOnboardingState(character) or trainingState)
        trainingState = string.upper(trainingState:gsub("_", " "))
    elseif characterMethod(character, "GetTrainingCompleted", false) then
        trainingState = "TRAINED"
    end

    return {
        name = name,
        callsign = callsign,
        displayName = displayName,
        cloneNumber = cloneNumber,
        serviceCode = "CT-" .. cloneNumber,
        rank = rank ~= "" and rank or "CLONE TROOPER",
        regiment = regiment ~= "" and regiment or "UNASSIGNED",
        assignment = string.upper(tostring(assignment)),
        level = math.max(1, math.floor(tonumber(characterMethod(character, "GetLevel", 1)) or 1)),
        xp = math.max(0, math.floor(tonumber(characterMethod(character, "GetXp", 0)) or 0)),
        skillPoints = math.max(0, math.floor(tonumber(characterMethod(character, "GetSkillPoints", 0)) or 0)),
        trainingState = trainingState
    }
end

local function getCharacter()
    if not IsValid(LocalPlayer()) or not LocalPlayer().GetCharacter then
        return nil
    end

    return LocalPlayer():GetCharacter()
end

local function applyMenuModelFade(panel)
    if not IsValid(panel) or panel.swrpMenuFadeInstalled then
        return
    end

    panel.swrpMenuFadeInstalled = true
    panel.PreDrawModel = function(current, entity)
        local alpha = 1
        local parent = current
        local safety = 0

        -- DModelPanel does not reliably inherit parent alpha. Walk the full
        -- hierarchy so the model follows the datapad fade exactly.
        while IsValid(parent) and safety < 32 do
            alpha = math.min(alpha, (parent:GetAlpha() or 255) / 255)
            parent = parent:GetParent()
            safety = safety + 1
        end

        local menu = ix and ix.gui and ix.gui.menu or nil
        if IsValid(menu) then
            alpha = math.min(alpha, (menu:GetAlpha() or 255) / 255)
        else
            -- The menu reference is cleared only after removal. If it is gone,
            -- never allow a detached model panel to flash on screen.
            return false
        end

        if alpha <= 0.002 then
            return false
        end

        render.SetBlend(alpha)
    end

    panel.PostDrawModel = function()
        render.SetBlend(1)
    end
end

local function configureCharacterModel(panel, fullBody)
    if not IsValid(panel) or not IsValid(LocalPlayer()) then
        return
    end

    applyMenuModelFade(panel)

    local model = LocalPlayer():GetModel()
    if not isstring(model) or model == "" then
        return
    end

    panel:SetModel(model)
    panel:SetFOV(fullBody and 31 or 24)
    panel:SetAmbientLight(Color(82, 116, 140))
    panel:SetDirectionalLight(BOX_FRONT, Color(190, 220, 235))
    panel:SetDirectionalLight(BOX_TOP, Color(85, 125, 155))
    panel:SetDirectionalLight(BOX_RIGHT, Color(45, 75, 100))

    local entity = panel:GetEntity()
    if not IsValid(entity) then
        return
    end

    entity:SetSkin(LocalPlayer():GetSkin() or 0)

    for index = 0, math.max(LocalPlayer():GetNumBodyGroups() - 1, 0) do
        entity:SetBodygroup(index, LocalPlayer():GetBodygroup(index))
    end

    local minimum, maximum = entity:GetRenderBounds()
    local centre = (minimum + maximum) * 0.5
    local height = math.max(maximum.z - minimum.z, 1)

    if fullBody then
        panel:SetLookAt(Vector(0, 0, minimum.z + height * 0.51))
        panel:SetCamPos(Vector(height * 1.05, height * 0.05, minimum.z + height * 0.52))
    else
        panel:SetLookAt(Vector(0, 0, minimum.z + height * 0.80))
        panel:SetCamPos(Vector(height * 0.52, 0, minimum.z + height * 0.80))
    end

    panel.LayoutEntity = function(current, modelEntity)
        if IsValid(modelEntity) then
            modelEntity:SetAngles(Angle(0, 0, 0))
        end
    end
end

local function configureClientModel(panel, client, fullBody)
    if not IsValid(panel) or not IsValid(client) then return end

    applyMenuModelFade(panel)

    local model = client:GetModel()
    if not isstring(model) or model == "" then return end

    panel:SetModel(model)
    panel:SetFOV(fullBody and 31 or 24)
    panel:SetAmbientLight(Color(82, 116, 140))
    panel:SetDirectionalLight(BOX_FRONT, Color(190, 220, 235))
    panel:SetDirectionalLight(BOX_TOP, Color(85, 125, 155))
    panel:SetDirectionalLight(BOX_RIGHT, Color(45, 75, 100))

    local entity = panel:GetEntity()
    if not IsValid(entity) then return end

    entity:SetSkin(client:GetSkin() or 0)
    for index = 0, math.max(client:GetNumBodyGroups() - 1, 0) do
        entity:SetBodygroup(index, client:GetBodygroup(index))
    end

    local minimum, maximum = entity:GetRenderBounds()
    local height = math.max(maximum.z - minimum.z, 1)
    panel:SetLookAt(Vector(0, 0, minimum.z + height * (fullBody and 0.51 or 0.80)))
    panel:SetCamPos(Vector(height * (fullBody and 1.05 or 0.52), 0, minimum.z + height * (fullBody and 0.52 or 0.80)))
    panel.LayoutEntity = function(_, modelEntity)
        if IsValid(modelEntity) then modelEntity:SetAngles(angle_zero) end
    end
end

local function getXPRequirement(character, level)
    if SWRP and SWRP.Datapad and isfunction(SWRP.Datapad.GetXPRequirement) then
        local value = SWRP.Datapad.GetXPRequirement(character, level)
        if isnumber(value) and value > 0 then return math.floor(value) end
    end

    local hooked = hook.Run("SWRPGetXPRequirement", character, level)
    if isnumber(hooked) and hooked > 0 then return math.floor(hooked) end
    return 1000
end

local function drawWrappedText(textValue, font, x, y, maxWidth, colour, lineHeight, maxLines)
    surface.SetFont(font)
    local words = string.Explode(" ", tostring(textValue or ""), false)
    local line = ""
    local lines = {}

    for _, word in ipairs(words) do
        local candidate = line == "" and word or (line .. " " .. word)
        local width = surface.GetTextSize(candidate)
        if width > maxWidth and line ~= "" then
            lines[#lines + 1] = line
            line = word
        else
            line = candidate
        end
    end
    if line ~= "" then lines[#lines + 1] = line end

    maxLines = maxLines or #lines
    for index = 1, math.min(#lines, maxLines) do
        draw.SimpleText(lines[index], font, x, y + (index - 1) * lineHeight, colour)
    end

    return math.min(#lines, maxLines) * lineHeight
end

-- -------------------------------------------------------------------------
-- Compact identity card displayed on every datapad page.
-- -------------------------------------------------------------------------

local PANEL = {}

function PANEL:Init()
    self:SetTall(96)
    self:DockPadding(8, 8, 8, 8)

    self.model = self:Add("DModelPanel")
    self.model:SetSize(76, 76)
    self.model:SetPos(8, 10)
    self.model:SetMouseInputEnabled(false)
    self.model:SetPaintBackground(false)

    timer.Simple(0, function()
        if IsValid(self.model) then
            configureCharacterModel(self.model, false)
        end
    end)

    self.nextModelRefresh = 0
end

function PANEL:Think()
    if CurTime() >= self.nextModelRefresh then
        self.nextModelRefresh = CurTime() + 2
        configureCharacterModel(self.model, false)
    end
end

function PANEL:Paint(width, height)
    local accent = getAccent()
    local identity = SWRP.Datapad.GetIdentity(getCharacter())

    draw.RoundedBox(2, 0, 0, width, height, Color(4, 13, 22, 242))
    drawCorners(0, 0, width, height, alphaColor(accent, 70), 13, 1)
    surface.SetDrawColor(accent.r, accent.g, accent.b, 34)
    surface.DrawRect(0, height - 1, width, 1)

    draw.SimpleText(identity.serviceCode, "swrpDatapadBodyBold", 92, 17, color_white)
    draw.SimpleText(string.upper(identity.displayName), "swrpDatapadSmall", 92, 43, alphaColor(accent, 230))
    draw.SimpleText(string.upper(identity.rank), "swrpDatapadSmall", 92, 64, Color(144, 165, 181))

    if identity.regiment ~= "UNASSIGNED" then
        draw.SimpleText(string.upper(identity.regiment), "swrpDatapadCategory", width - 10, height - 14, Color(105, 220, 175), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end

vgui.Register("swrpDatapadIdentityMini", PANEL, "DPanel")

-- -------------------------------------------------------------------------
-- Character conditioning, career progression and qualification controls.
-- -------------------------------------------------------------------------

local ATTRIBUTE_DETAILS = {
    endurance = {label = "ENDURANCE", detail = "Survivability and sustained-combat conditioning."},
    stamina = {label = "STAMINA", detail = "Sprint duration and movement conditioning."},
    strength = {label = "STRENGTH", detail = "Equipment load, recoil control and physical force."}
}

local function getAttributeEffectText(character, attributeID, value, attributeData)
    local custom = hook.Run("SWRPGetAttributeEffectText", character, attributeID, value, attributeData)
    if isstring(custom) and custom ~= "" then return custom end

    if attributeData and isstring(attributeData.description) and attributeData.description ~= "" then
        return attributeData.description
    end

    local details = ATTRIBUTE_DETAILS[attributeID]
    return details and details.detail or "Republic personnel conditioning score."
end

PANEL = {}

function PANEL:Init()
    self.attributeID = nil
    self.attributeData = nil
    self:SetTall(92)
end

function PANEL:SetAttribute(attributeID, attributeData)
    self.attributeID = attributeID
    self.attributeData = attributeData or {}
end

function PANEL:GetValues()
    local character = getCharacter()
    local value = character and character:GetAttribute(self.attributeID, 0) or 0
    local maximum = (self.attributeData and self.attributeData.maxValue) or (ix.config and ix.config.Get("maxAttributes", 100)) or 100
    return tonumber(value) or 0, math.max(tonumber(maximum) or 100, 1)
end

function PANEL:Paint(width, height)
    local accent = getAccent()
    local value, maximum = self:GetValues()
    local fraction = math.Clamp(value / maximum, 0, 1)
    local fallbackName = self.attributeData and L(self.attributeData.name) or tostring(self.attributeID or "ATTRIBUTE")
    local details = ATTRIBUTE_DETAILS[self.attributeID] or {label = string.upper(fallbackName), detail = "Republic personnel conditioning score."}
    local effectText = getAttributeEffectText(getCharacter(), self.attributeID, value, self.attributeData)

    draw.RoundedBox(2, 0, 0, width, height, Color(5, 15, 25, 235))
    surface.SetDrawColor(accent.r, accent.g, accent.b, 52)
    surface.DrawOutlinedRect(0, 0, width, height)

    draw.SimpleText(details.label, "swrpDatapadBodyBold", 14, 11, color_white)
    draw.SimpleText(string.format("%d / %d", math.floor(value), math.floor(maximum)), "swrpDatapadBodyBold", width - 14, 11, alphaColor(accent, 235), TEXT_ALIGN_RIGHT)
    draw.SimpleText(effectText, "swrpDatapadSmall", 14, 36, Color(132, 157, 174))

    local barX, barY = 14, height - 22
    local barWidth, barHeight = width - 28, 10
    draw.RoundedBox(1, barX, barY, barWidth, barHeight, Color(10, 25, 37, 255))
    draw.RoundedBox(1, barX, barY, math.max(0, barWidth * fraction), barHeight, alphaColor(accent, 220))
    surface.SetDrawColor(255, 255, 255, 18)
    surface.DrawOutlinedRect(barX, barY, barWidth, barHeight)
end

vgui.Register("swrpDatapadAttributeCard", PANEL, "DPanel")

PANEL = {}

function PANEL:Init()
    self.label = "QUALIFICATION"
    self.detail = ""
    self.authorised = false
    self:SetTall(68)
end

function PANEL:SetQualification(label, detail, authorised)
    self.label = label or "QUALIFICATION"
    self.detail = detail or ""
    self.authorised = tobool(authorised)
end

function PANEL:Paint(width, height)
    local accent = getAccent()
    local stateColour = self.authorised and Color(105, 220, 175) or Color(105, 124, 139)
    draw.RoundedBox(2, 0, 0, width, height, Color(5, 15, 25, 235))
    surface.SetDrawColor(accent.r, accent.g, accent.b, 42)
    surface.DrawOutlinedRect(0, 0, width, height)

    local boxSize = 22
    local boxX, boxY = 13, math.floor((height - boxSize) * 0.5)
    surface.SetDrawColor(stateColour.r, stateColour.g, stateColour.b, 220)
    surface.DrawOutlinedRect(boxX, boxY, boxSize, boxSize)
    if self.authorised then
        draw.SimpleText("✓", "swrpDatapadBodyBold", boxX + boxSize * 0.5, boxY + boxSize * 0.5 - 1, stateColour, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    draw.SimpleText(string.upper(self.label), "swrpDatapadBodyBold", 46, 13, color_white)
    draw.SimpleText(self.detail, "swrpDatapadSmall", 46, 39, self.authorised and stateColour or Color(129, 151, 166))
end

vgui.Register("swrpDatapadQualificationCard", PANEL, "DPanel")

PANEL = {}

function PANEL:Paint(width, height)
    local accent = getAccent()
    local character = getCharacter()
    local identity = SWRP.Datapad.GetIdentity(character)
    local requirement = getXPRequirement(character, identity.level)
    local current = math.Clamp(identity.xp, 0, requirement)
    local fraction = requirement > 0 and math.Clamp(current / requirement, 0, 1) or 0

    draw.RoundedBox(2, 0, 0, width, height, Color(4, 13, 22, 238))
    drawCorners(0, 0, width, height, alphaColor(accent, 58), 13, 1)
    draw.SimpleText("SERVICE LEVEL", "swrpDatapadCategory", 16, 13, alphaColor(accent, 225))
    draw.SimpleText(tostring(identity.level), "swrpDatapadPageTitle", 18, 37, color_white)

    local barX = 94
    local barY = 45
    local barWidth = width - barX - 18
    draw.SimpleText(string.format("%d XP", current), "swrpDatapadSmall", barX, 20, Color(184, 204, 216))
    draw.SimpleText(string.format("%d XP REQUIRED", requirement), "swrpDatapadSmall", width - 18, 20, Color(184, 204, 216), TEXT_ALIGN_RIGHT)
    draw.RoundedBox(1, barX, barY, barWidth, 16, Color(9, 25, 38, 255))
    draw.RoundedBox(1, barX, barY, barWidth * fraction, 16, alphaColor(accent, 230))
    surface.SetDrawColor(255, 255, 255, 18)
    surface.DrawOutlinedRect(barX, barY, barWidth, 16)
    draw.SimpleText(string.format("%d / %d", current, requirement), "swrpDatapadSmall", barX + barWidth * 0.5, barY + 8, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(string.format("LEVEL %d  →  LEVEL %d", identity.level, identity.level + 1), "swrpDatapadSmall", barX, height - 18, Color(126, 150, 167), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

vgui.Register("swrpDatapadCareerProgress", PANEL, "DPanel")

-- -------------------------------------------------------------------------
-- Character profile and skill-tree page.
-- -------------------------------------------------------------------------

PANEL = {}

function PANEL:Init()
    self.attributeCards = {}
    self.upgradeBranches = {}
    self.activeSection = nil
    self.sectionPanels = {}
    self.sectionButtons = {}

    self.modelShell = self:Add("DPanel")
    self.modelShell:Dock(LEFT)
    self.modelShell:SetWide(math.Clamp(ScrW() * 0.235, 300, 455))
    self.modelShell:DockMargin(0, 0, 12, 0)
    self.modelShell.Paint = function(panel, width, height)
        local accent = getAccent()
        draw.RoundedBox(2, 0, 0, width, height, Color(3, 11, 19, 245))
        drawCorners(0, 0, width, height, alphaColor(accent, 72), 16, 1)

        surface.SetDrawColor(accent.r, accent.g, accent.b, 16)
        for x = 0, width, 32 do
            surface.DrawLine(width * 0.5, height * 0.72, x, height)
        end
        for y = math.floor(height * 0.72), height, 18 do
            surface.DrawLine(0, y, width, y)
        end
    end

    self.model = self.modelShell:Add("DModelPanel")
    self.model:Dock(FILL)
    self.model:DockMargin(8, 8, 8, 116)
    self.model:SetMouseInputEnabled(false)
    self.model:SetPaintBackground(false)

    self.modelIdentity = self.modelShell:Add("DPanel")
    self.modelIdentity:Dock(BOTTOM)
    self.modelIdentity:SetTall(108)
    self.modelIdentity:DockMargin(8, 0, 8, 8)
    self.modelIdentity.Paint = function(panel, width, height)
        local accent = getAccent()
        local identity = SWRP.Datapad.GetIdentity(getCharacter())

        draw.RoundedBox(2, 0, 0, width, height, Color(4, 14, 23, 248))
        surface.SetDrawColor(accent.r, accent.g, accent.b, 65)
        surface.DrawOutlinedRect(0, 0, width, height)
        surface.DrawRect(0, 0, 4, height)

        draw.SimpleText(identity.serviceCode, "swrpDatapadPageTitle", 16, 12, color_white)
        draw.SimpleText(string.upper(identity.displayName), "swrpDatapadBodyBold", 17, 51, alphaColor(accent, 235))
        draw.SimpleText(string.upper(identity.rank .. "  •  " .. identity.regiment), "swrpDatapadSmall", 17, 78, Color(145, 167, 182))
    end

    self.right = self:Add("DPanel")
    self.right:Dock(FILL)
    self.right.Paint = nil

    self.toolbar = self.right:Add("DPanel")
    self.toolbar:Dock(TOP)
    self.toolbar:SetTall(48)
    self.toolbar:DockMargin(0, 0, 0, 10)
    self.toolbar.Paint = function(panel, width, height)
        draw.RoundedBox(2, 0, 0, width, height, Color(4, 13, 22, 235))
        surface.SetDrawColor(90, 155, 205, 45)
        surface.DrawOutlinedRect(0, 0, width, height)
    end

    self.content = self.right:Add("DPanel")
    self.content:Dock(FILL)
    self.content.Paint = nil

    self:AddSection("profile", "SERVICE PROFILE")
    self:AddSection("upgrades", "UPGRADES")
    self:SelectSection("profile")

    timer.Simple(0, function()
        if IsValid(self.model) then
            configureCharacterModel(self.model, true)
        end
    end)

    self.nextModelRefresh = 0
end

function PANEL:AddSection(key, label)
    local button = self.toolbar:Add("swrpDatapadSegmentButton")
    button:Dock(LEFT)
    button:SetWide(key == "profile" and 190 or 160)
    button:DockMargin(6, 6, 0, 6)
    button:SetLabel(label)
    button.DoClick = function()
        self:SelectSection(key)
    end

    self.sectionButtons[key] = button
end

function PANEL:CreateSection(key)
    local panel = self.content:Add("DPanel")
    panel:Dock(FILL)
    panel:SetVisible(false)
    panel.Paint = nil

    if key == "profile" then
        self:BuildProfile(panel)
    elseif key == "upgrades" then
        self:BuildUpgrades(panel)
    end

    self.sectionPanels[key] = panel
    return panel
end

function PANEL:SelectSection(key)
    if IsValid(self.activePanel) then
        self.activePanel:SetVisible(false)
    end

    local panel = self.sectionPanels[key] or self:CreateSection(key)
    if not IsValid(panel) then
        return
    end

    for sectionKey, button in pairs(self.sectionButtons) do
        if IsValid(button) then
            button:SetSelected(sectionKey == key)
        end
    end

    panel:SetVisible(true)
    panel:InvalidateLayout(true)
    self.activePanel = panel
    self.activeSection = key
end

function PANEL:BuildProfile(container)
    local scroll = container:Add("DScrollPanel")
    scroll:Dock(FILL)
    scroll:GetCanvas():DockPadding(0, 0, 8, 8)

    local identityPanel = scroll:Add("DPanel")
    identityPanel:Dock(TOP)
    identityPanel:SetTall(132)
    identityPanel:DockMargin(0, 0, 0, 12)
    identityPanel.Paint = function(panel, width, height)
        local accent = getAccent()
        local identity = SWRP.Datapad.GetIdentity(getCharacter())
        draw.RoundedBox(2, 0, 0, width, height, Color(4, 13, 22, 242))
        drawCorners(0, 0, width, height, alphaColor(accent, 82), 15, 1)
        draw.SimpleText("REPUBLIC SERVICE IDENTIFICATION", "swrpDatapadCategory", 18, 15, alphaColor(accent, 225))
        draw.SimpleText(identity.serviceCode, "swrpDatapadPageTitle", 18, 39, color_white)
        draw.SimpleText(string.upper(identity.displayName), "swrpDatapadBodyBold", 19, 79, Color(190, 209, 220))

        draw.SimpleText("RANK", "swrpDatapadCategory", width * 0.55, 19, Color(115, 141, 159))
        draw.SimpleText(string.upper(identity.rank), "swrpDatapadBodyBold", width * 0.55, 43, color_white)
        draw.SimpleText("REGIMENT", "swrpDatapadCategory", width * 0.77, 19, Color(115, 141, 159))
        draw.SimpleText(string.upper(identity.regiment), "swrpDatapadBodyBold", width * 0.77, 43, color_white)
        draw.SimpleText("TRAINING STATUS", "swrpDatapadCategory", width * 0.55, 77, Color(115, 141, 159))
        draw.SimpleText(identity.trainingState, "swrpDatapadBodyBold", width * 0.55, 102, Color(105, 220, 175))
        draw.SimpleText("CLEARANCE", "swrpDatapadCategory", width * 0.77, 77, Color(115, 141, 159))
        draw.SimpleText(LocalPlayer():IsAdmin() and "ADMIN" or "STANDARD", "swrpDatapadBodyBold", width * 0.77, 102, color_white)
    end

    local operationalLabel = scroll:Add("DLabel")
    operationalLabel:Dock(TOP)
    operationalLabel:SetTall(24)
    operationalLabel:SetFont("swrpDatapadCategory")
    operationalLabel:SetText("OPERATIONAL STATUS")
    operationalLabel:SetTextColor(getAccent())

    self.operationalCards = scroll:Add("DIconLayout")
    self.operationalCards:Dock(TOP)
    self.operationalCards:SetTall(122)
    self.operationalCards:SetSpaceX(10)
    self.operationalCards:SetSpaceY(10)
    self.operationalCards:DockMargin(0, 0, 0, 14)

    self.assignmentStatusCard = self.operationalCards:Add("swrpDatapadStatusCard")
    self.routeStatusCard = self.operationalCards:Add("swrpDatapadStatusCard")
    self.vesselStatusCard = self.operationalCards:Add("swrpDatapadStatusCard")
    for _, card in ipairs({self.assignmentStatusCard, self.routeStatusCard, self.vesselStatusCard}) do card:SetTall(112) end

    local operationalPerformLayout = self.operationalCards.PerformLayout
    self.operationalCards.PerformLayout = function(layout, width, height)
        local cardWidth = math.max(math.floor((width - 20) / 3), 145)
        self.assignmentStatusCard:SetWide(cardWidth)
        self.routeStatusCard:SetWide(cardWidth)
        self.vesselStatusCard:SetWide(cardWidth)
        operationalPerformLayout(layout, width, height)
    end

    local statusLabel = scroll:Add("DLabel")
    statusLabel:Dock(TOP)
    statusLabel:SetTall(24)
    statusLabel:SetFont("swrpDatapadCategory")
    statusLabel:SetText("CAREER PROGRESSION")
    statusLabel:SetTextColor(getAccent())

    local careerRow = scroll:Add("DPanel")
    careerRow:Dock(TOP)
    careerRow:SetTall(108)
    careerRow:DockMargin(0, 0, 0, 14)
    careerRow.Paint = nil

    self.pointsCard = careerRow:Add("swrpDatapadStatusCard")
    self.pointsCard:Dock(RIGHT)
    self.pointsCard:SetWide(math.Clamp(ScrW() * 0.18, 230, 320))
    self.pointsCard:SetAction("Open Upgrades", function() self:SelectSection("upgrades") end)

    self.careerProgress = careerRow:Add("swrpDatapadCareerProgress")
    self.careerProgress:Dock(FILL)
    self.careerProgress:DockMargin(0, 0, 10, 0)

    local qualificationLabel = scroll:Add("DLabel")
    qualificationLabel:Dock(TOP)
    qualificationLabel:SetTall(24)
    qualificationLabel:SetFont("swrpDatapadCategory")
    qualificationLabel:SetText("QUALIFICATIONS & AUTHORISATIONS")
    qualificationLabel:SetTextColor(getAccent())

    self.qualificationLayout = scroll:Add("DIconLayout")
    self.qualificationLayout:Dock(TOP)
    self.qualificationLayout:SetTall(156)
    self.qualificationLayout:SetSpaceX(10)
    self.qualificationLayout:SetSpaceY(10)
    self.qualificationLayout:DockMargin(0, 0, 0, 14)
    self.qualificationCards = {}
    for _ = 1, 6 do
        local card = self.qualificationLayout:Add("swrpDatapadQualificationCard")
        self.qualificationCards[#self.qualificationCards + 1] = card
    end
    local qualificationPerformLayout = self.qualificationLayout.PerformLayout
    self.qualificationLayout.PerformLayout = function(layout, width, height)
        local cardWidth = math.max(math.floor((width - 20) / 3), 210)
        for _, card in ipairs(self.qualificationCards) do card:SetWide(cardWidth) end
        qualificationPerformLayout(layout, width, height)
    end

    local performanceLabel = scroll:Add("DLabel")
    performanceLabel:Dock(TOP)
    performanceLabel:SetTall(24)
    performanceLabel:SetFont("swrpDatapadCategory")
    performanceLabel:SetText("CURRENT FIELD PERFORMANCE")
    performanceLabel:SetTextColor(getAccent())

    self.performanceLayout = scroll:Add("DIconLayout")
    self.performanceLayout:Dock(TOP)
    self.performanceLayout:SetTall(92)
    self.performanceLayout:SetSpaceX(10)
    self.performanceLayout:SetSpaceY(10)
    self.performanceLayout:DockMargin(0, 0, 0, 14)
    self.performanceCards = {}
    for _ = 1, 4 do
        local card = self.performanceLayout:Add("swrpDatapadStatusCard")
        card:SetTall(82)
        self.performanceCards[#self.performanceCards + 1] = card
    end
    local performancePerformLayout = self.performanceLayout.PerformLayout
    self.performanceLayout.PerformLayout = function(layout, width, height)
        local columns = width < 760 and 2 or 4
        local cardWidth = math.max(math.floor((width - (columns - 1) * 10) / columns), 150)
        for _, card in ipairs(self.performanceCards) do card:SetWide(cardWidth) end
        local rows = math.ceil(#self.performanceCards / columns)
        layout:SetTall(rows * 82 + math.max(rows - 1, 0) * 10)
        performancePerformLayout(layout, width, layout:GetTall())
    end

    local attributeLabel = scroll:Add("DLabel")
    attributeLabel:Dock(TOP)
    attributeLabel:SetTall(24)
    attributeLabel:SetFont("swrpDatapadCategory")
    attributeLabel:SetText("CONDITIONING SCORES")
    attributeLabel:SetTextColor(getAccent())

    self.attributeLayout = scroll:Add("DIconLayout")
    self.attributeLayout:Dock(TOP)
    self.attributeLayout:SetSpaceX(10)
    self.attributeLayout:SetSpaceY(10)
    self.attributeLayout:DockMargin(0, 0, 0, 14)

    for attributeID, attributeData in SortedPairsByMemberValue(ix.attributes.list or {}, "name") do
        local card = self.attributeLayout:Add("swrpDatapadAttributeCard")
        card:SetAttribute(attributeID, attributeData)
        self.attributeCards[#self.attributeCards + 1] = card
    end

    local rows = math.max(math.ceil(#self.attributeCards / 2), 1)
    self.attributeLayout:SetTall(rows * 102)
    local attributePerformLayout = self.attributeLayout.PerformLayout
    self.attributeLayout.PerformLayout = function(layout, width, height)
        local cardWidth = math.max(math.floor((width - 10) / 2), 220)
        for _, card in ipairs(self.attributeCards) do if IsValid(card) then card:SetWide(cardWidth) end end
        attributePerformLayout(layout, width, height)
    end
end

function PANEL:BuildUpgrades(container)
    local pointHeader = container:Add("DPanel")
    pointHeader:Dock(TOP)
    pointHeader:SetTall(86)
    pointHeader:DockMargin(0, 0, 0, 10)
    pointHeader.Paint = function(panel, width, height)
        local accent = getAccent()
        local identity = SWRP.Datapad.GetIdentity(getCharacter())
        local tree = SWRP.Datapad.UpgradeTree
        local mask = tree and tree.GetMask(getCharacter()) or 0
        local installed = 0

        if tree then
            for _, node in ipairs(tree.nodes or {}) do
                if tree.IsUnlocked(mask, node) then
                    installed = installed + 1
                end
            end
        end

        draw.RoundedBox(2, 0, 0, width, height, Color(4, 13, 22, 242))
        drawCorners(0, 0, width, height, alphaColor(accent, 88), 15, 1)
        draw.SimpleText("AVAILABLE UPGRADE POINTS", "swrpDatapadCategory", 18, 14, alphaColor(accent, 230))
        draw.SimpleText(tostring(identity.skillPoints), "swrpDatapadPageTitle", 18, 35, color_white)
        draw.SimpleText("Interactive Republic career-development tree", "swrpDatapadBodyBold", 86, 34, Color(185, 205, 218))
        draw.SimpleText("LEFT-DRAG TO PAN  •  WHEEL TO ZOOM  •  SELECT A NODE, THEN USE BUY", "swrpDatapadSmall", 86, 58, Color(126, 151, 168))
        draw.SimpleText(string.format("%s  //  %d NODE%s INSTALLED", identity.serviceCode, installed, installed == 1 and "" or "S"), "swrpDatapadSmall", width - 18, height - 18, Color(105, 220, 175), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    self.upgradeTree = container:Add("swrpDatapadUpgradeTree")
    self.upgradeTree:Dock(FILL)
end

function PANEL:Think()
    if CurTime() >= self.nextModelRefresh then
        self.nextModelRefresh = CurTime() + 2
        configureCharacterModel(self.model, true)
    end

    if not IsValid(self.pointsCard) then return end

    local character = getCharacter()
    local identity = SWRP.Datapad.GetIdentity(character)
    self.pointsCard:SetCard("UPGRADE POINTS", tostring(identity.skillPoints), "Available development points")

    self.assignmentStatusCard:SetCard("CURRENT ASSIGNMENT", string.upper(identity.assignment or "UNASSIGNED"), string.upper(identity.regiment or "REPUBLIC PERSONNEL"))
    self.routeStatusCard:SetCard("SERVICE RANK", string.upper(identity.rank or "CLONE TROOPER"), "Server-authoritative personnel rank")
    self.vesselStatusCard:SetCard("VESSEL PERSONNEL", tostring(#player.GetAll()) .. " ONLINE", "Connected personnel")

    local client = LocalPlayer()
    local performance = {
        {"MAX HEALTH", IsValid(client) and tostring(client:GetMaxHealth()) or "—", "Current spawned value"},
        {"WALK SPEED", IsValid(client) and tostring(math.floor(client:GetWalkSpeed())) .. " u/s" or "—", "Current movement value"},
        {"SPRINT SPEED", IsValid(client) and tostring(math.floor(client:GetRunSpeed())) .. " u/s" or "—", "Current movement value"},
        {"JUMP POWER", IsValid(client) and tostring(math.floor(client:GetJumpPower())) or "—", "Current spawned value"}
    }
    for index, data in ipairs(performance) do
        if self.performanceCards and IsValid(self.performanceCards[index]) then
            self.performanceCards[index]:SetCard(data[1], data[2], data[3])
        end
    end

    local tree = SWRP.Datapad.UpgradeTree
    local has = function(capability) return tree and tree.HasCapability(character, capability) or false end
    local qualifications = {
        {"BASIC INFANTRY", "STANDARD ISSUE WEAPONS", true},
        {"PILOT TRAINED", has("pilot") and "REPUBLIC PILOT" or "NOT CERTIFIED", has("pilot")},
        {"MEDIC TRAINED", has("medic") and "FIELD MEDIC" or "NOT CERTIFIED", has("medic")},
        {"MARKSMAN", has("marksman") and "PRECISION AUTHORISED" or "NOT AUTHORISED", has("marksman")},
        {"HEAVY WEAPONS", has("heavy_weapons") and "HEAVY AUTHORISED" or "NOT AUTHORISED", has("heavy_weapons")},
        {"EXPLOSIVES", has("explosives") and "DEMOLITIONS AUTHORISED" or "NOT AUTHORISED", has("explosives")}
    }
    for index, data in ipairs(qualifications) do
        if IsValid(self.qualificationCards[index]) then self.qualificationCards[index]:SetQualification(data[1], data[2], data[3]) end
    end
end

function PANEL:OnMenuSelected()
    configureCharacterModel(self.model, true)
end

function PANEL:OnMenuDeselected()
end

vgui.Register("swrpDatapadCharacter", PANEL, "DPanel")

-- -------------------------------------------------------------------------
-- Interactive graphical career tree. All graph rendering and hit testing use
-- the same panel-space transformation, preventing the previous offset bug.
-- -------------------------------------------------------------------------

local function filledCircle(x, y, radius, colour, segments)
    segments = segments or 32
    local vertices = {}
    for index = 0, segments do
        local angle = math.rad((index / segments) * 360)
        vertices[#vertices + 1] = {x = x + math.cos(angle) * radius, y = y + math.sin(angle) * radius}
    end
    draw.NoTexture()
    surface.SetDrawColor(colour)
    surface.DrawPoly(vertices)
end

local function drawBeam(x1, y1, x2, y2, colour, thickness)
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0.001 then return end
    local half = (thickness or 3) * 0.5
    local nx, ny = -dy / length * half, dx / length * half
    draw.NoTexture()
    surface.SetDrawColor(colour)
    surface.DrawPoly({
        {x = x1 + nx, y = y1 + ny}, {x = x2 + nx, y = y2 + ny},
        {x = x2 - nx, y = y2 - ny}, {x = x1 - nx, y = y1 - ny}
    })
end

local function branchColour(node, alpha)
    local colour = node and node.colour or {73, 132, 207}
    return Color(colour[1] or 73, colour[2] or 132, colour[3] or 207, alpha or 255)
end

PANEL = {}

function PANEL:Init()
    self:SetMouseInputEnabled(true)
    self.zoom = 0.65
    self.panX, self.panY = 0, 0
    self.dragging, self.dragMoved = false, false
    self.hoveredNodeID, self.selectedNodeID = nil, nil
    self.pendingNodeID, self.pendingUntil = nil, 0
    self.lastHoverSoundNode = nil
    self.lastZoomSound = 0
    self.lastLayoutWidth, self.lastLayoutHeight = 0, 0

    local function addControl(label, action)
        local button = self:Add("DButton")
        button:SetText("")
        button.swrpLabel = label
        button.DoClick = function()
            SWRP.Datapad.PlaySound("move")
            action()
        end
        button.OnCursorEntered = function() SWRP.Datapad.PlaySound("move") end
        button.Paint = function(control, width, height)
            local accent = getAccent()
            local hovered = control:IsHovered()
            draw.RoundedBox(2, 0, 0, width, height, hovered and Color(14, 35, 52, 248) or Color(5, 16, 27, 242))
            surface.SetDrawColor(accent.r, accent.g, accent.b, hovered and 150 or 55)
            surface.DrawOutlinedRect(0, 0, width, height)
            draw.SimpleText(control.swrpLabel, "swrpDatapadBodyBold", width * 0.5, height * 0.5, hovered and color_white or Color(156, 180, 196), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        return button
    end

    self.zoomOutButton = addControl("-", function() self:SetZoom(self.zoom - 0.08, self:GetWide() * 0.5, self:GetTall() * 0.5) end)
    self.zoomInButton = addControl("+", function() self:SetZoom(self.zoom + 0.08, self:GetWide() * 0.5, self:GetTall() * 0.5) end)
    self.resetButton = addControl("CENTRE", function() self:ResetView() end)

    self.purchaseButton = self:Add("DButton")
    self.purchaseButton:SetText("")
    self.purchaseButton:SetVisible(false)
    self.purchaseButton:SetZPos(500)
    self.purchaseButton.OnCursorEntered = function(button)
        if button:IsEnabled() then
            SWRP.Datapad.PlaySound("move")
        end
    end
    self.purchaseButton.DoClick = function()
        local tree = self:GetTree()
        local node = tree and self.selectedNodeID and tree.GetNode(self.selectedNodeID) or nil
        if node then
            self:TryPurchase(node)
        end
    end
    self.purchaseButton.Paint = function(button, width, height)
        local enabled = button:IsEnabled()
        local hovered = enabled and button:IsHovered()
        local accent = enabled and getAccent() or Color(74, 86, 96)
        local background = enabled and (hovered and Color(24, 64, 91, 252) or Color(11, 36, 55, 250)) or Color(18, 22, 26, 245)
        draw.RoundedBox(2, 0, 0, width, height, background)
        surface.SetDrawColor(accent.r, accent.g, accent.b, enabled and 190 or 70)
        surface.DrawOutlinedRect(0, 0, width, height)
        draw.SimpleText(button.swrpLabel or "SELECT NODE", "swrpDatapadBodyBold", width * 0.5, height * 0.5, enabled and color_white or Color(122, 131, 138), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

function PANEL:GetTree() return SWRP.Datapad and SWRP.Datapad.UpgradeTree or nil end
function PANEL:GetMask() local tree = self:GetTree() return tree and tree.GetMask(getCharacter()) or 0 end

function PANEL:GetNodeState(node)
    local tree, character = self:GetTree(), getCharacter()
    if not tree or not node or not character then return "locked", false, 0, 0, 0 end
    local mask = tree.GetMask(character)
    local points = math.max(0, math.floor(tonumber(characterMethod(character, "GetSkillPoints", 0)) or 0))
    if tree.IsUnlocked(mask, node) then return "installed", false, 0, 0, points end
    if not tree.PrerequisitesMet(mask, node) then return "locked", false, 0, 0, points end

    if node.kind == "attribute" then
        local current = tonumber(character:GetAttribute(node.attribute, 0)) or 0
        local attribute = ix.attributes.list[node.attribute]
        local maximum = math.max(tonumber(attribute and attribute.maxValue) or tonumber(ix.config.Get("maxAttributes", 100)) or 100, tree.amount)
        if current >= maximum then return "capped", false, current, maximum, points end
        if points < (node.cost or tree.cost) then return "no_points", false, current, maximum, points end
        return "available", true, current, maximum, points
    end

    if points < (node.cost or tree.cost) then return "no_points", false, 0, 0, points end
    return "available", true, 0, 0, points
end

function PANEL:WorldToPanel(x, y)
    return self:GetWide() * 0.5 + self.panX + x * self.zoom, self:GetTall() * 0.5 + self.panY + y * self.zoom
end

function PANEL:PanelToWorld(x, y)
    return (x - self:GetWide() * 0.5 - self.panX) / self.zoom, (y - self:GetTall() * 0.5 - self.panY) / self.zoom
end

function PANEL:ResetView()
    local width, height = self:GetSize()
    local tree = self:GetTree()
    if width <= 0 or height <= 0 or not tree or not tree.bounds then return end

    local bounds = tree.bounds
    local worldWidth = math.max(bounds.maxX - bounds.minX, 1)
    local worldHeight = math.max(bounds.maxY - bounds.minY, 1)
    local paddingX, paddingY = 150, 120
    local availableWidth = math.max(width - paddingX * 2, 1)
    local availableHeight = math.max(height - paddingY * 2, 1)
    local centreX = (bounds.minX + bounds.maxX) * 0.5
    local centreY = (bounds.minY + bounds.maxY) * 0.5

    self.zoom = math.Clamp(math.min(availableWidth / worldWidth, availableHeight / worldHeight), 0.34, 0.94)
    self.panX = -centreX * self.zoom
    self.panY = -centreY * self.zoom
    self.viewInitialised = true
end

function PANEL:ClampPan()
    local tree = self:GetTree()
    if not tree or not tree.bounds then return end

    local width, height = self:GetSize()
    local bounds = tree.bounds
    local padding = 95

    local lowerX = padding - width * 0.5 - bounds.minX * self.zoom
    local upperX = width * 0.5 - padding - bounds.maxX * self.zoom
    local lowerY = padding - height * 0.5 - bounds.minY * self.zoom
    local upperY = height * 0.5 - padding - bounds.maxY * self.zoom

    if lowerX <= upperX then
        self.panX = math.Clamp(self.panX, lowerX, upperX)
    else
        self.panX = -((bounds.minX + bounds.maxX) * 0.5) * self.zoom
    end

    if lowerY <= upperY then
        self.panY = math.Clamp(self.panY, lowerY, upperY)
    else
        self.panY = -((bounds.minY + bounds.maxY) * 0.5) * self.zoom
    end
end

function PANEL:SetZoom(value, cursorX, cursorY)
    local newZoom = math.Clamp(value, 0.34, 1.25)
    cursorX, cursorY = cursorX or self:GetWide() * 0.5, cursorY or self:GetTall() * 0.5
    local worldX, worldY = self:PanelToWorld(cursorX, cursorY)
    self.zoom = newZoom
    self.panX = cursorX - self:GetWide() * 0.5 - worldX * newZoom
    self.panY = cursorY - self:GetTall() * 0.5 - worldY * newZoom
    self:ClampPan()
end

function PANEL:FindNodeAt(x, y)
    local tree = self:GetTree()
    if not tree then return nil end
    for index = #tree.nodes, 1, -1 do
        local node = tree.nodes[index]
        local nodeX, nodeY = self:WorldToPanel(node.x, node.y)
        local radius = math.Clamp(43 * self.zoom, 25, 48)
        local dx, dy = x - nodeX, y - nodeY
        if dx * dx + dy * dy <= radius * radius then return node end
    end
    return nil
end

function PANEL:TryPurchase(node)
    if not node or self.pendingUntil > CurTime() then return end
    local state, available = self:GetNodeState(node)
    self.selectedNodeID = node.id
    if not available then
        local messages = {
            installed = "That development node is already installed.",
            locked = "Complete a connected prerequisite path first.",
            no_points = "You do not have enough upgrade points.",
            capped = "That conditioning score is already at its maximum value."
        }
        notification.AddLegacy(messages[state] or "That node is unavailable.", NOTIFY_ERROR, 3)
        SWRP.Datapad.PlaySound("back")
        return
    end
    self.pendingNodeID = node.id
    self.pendingUntil = CurTime() + 1.25
    SWRP.Datapad.PlaySound("move")
    net.Start("swrpDatapadPurchaseUpgrade") net.WriteString(node.id) net.SendToServer()
end

function PANEL:OnMousePressed(mouseCode)
    if mouseCode ~= MOUSE_LEFT then return end
    local x, y = self:CursorPos()
    local node = self:FindNodeAt(x, y)
    self.dragging, self.dragMoved = true, false
    self.pressX, self.pressY = x, y
    self.startPanX, self.startPanY = self.panX, self.panY
    self.pressedNodeID = node and node.id or nil
    self:MouseCapture(true)
end

function PANEL:OnCursorMoved(x, y)
    if not self.dragging then return end
    local dx, dy = x - self.pressX, y - self.pressY
    if dx * dx + dy * dy > 20 then self.dragMoved = true end
    if self.dragMoved then
        self.panX, self.panY = self.startPanX + dx, self.startPanY + dy
        self:ClampPan()
    end
end

function PANEL:OnMouseReleased(mouseCode)
    if mouseCode ~= MOUSE_LEFT or not self.dragging then return end
    self:MouseCapture(false)
    local x, y = self:CursorPos()
    local releasedNode = self:FindNodeAt(x, y)
    if not self.dragMoved and self.pressedNodeID and releasedNode and releasedNode.id == self.pressedNodeID then
        self.selectedNodeID = releasedNode.id
        SWRP.Datapad.PlaySound("move")
    end
    self.dragging, self.dragMoved, self.pressedNodeID = false, false, nil
end

function PANEL:OnMouseWheeled(delta)
    local x, y = self:CursorPos()
    self:SetZoom(self.zoom + delta * 0.07, x, y)
    if self.lastZoomSound < CurTime() then
        self.lastZoomSound = CurTime() + 0.12
        SWRP.Datapad.PlaySound("move")
    end
    return true
end

function PANEL:GetTooltipRect(node)
    local width, height = self:GetSize()
    local tooltipWidth = math.min(720, math.floor(width * 0.62))
    local tooltipHeight = math.min(310, math.floor(height * 0.48))
    local nodeX = node and select(1, self:WorldToPanel(node.x, node.y)) or width * 0.5
    local tooltipX = nodeX > width * 0.54 and 16 or width - tooltipWidth - 16
    local tooltipY = height - tooltipHeight - 16
    return tooltipX, tooltipY, tooltipWidth, tooltipHeight
end

function PANEL:UpdatePurchaseButton()
    if not IsValid(self.purchaseButton) then
        return
    end

    local tree = self:GetTree()
    local node = tree and self.selectedNodeID and tree.GetNode(self.selectedNodeID) or nil
    if not node then
        self.purchaseButton:SetVisible(false)
        return
    end

    local state, available, _, _, points = self:GetNodeState(node)
    local cost = tonumber(node.cost or tree.cost) or 1
    local labels = {
        installed = "INSTALLED",
        locked = "LOCKED",
        no_points = "NEED " .. cost .. " POINT" .. (cost == 1 and "" or "S"),
        capped = "MAXIMUM REACHED",
        available = "BUY  •  " .. cost .. " POINT" .. (cost == 1 and "" or "S")
    }

    local x, y, width, height = self:GetTooltipRect(node)
    self.purchaseButton:SetPos(x + width - 206, y + height - 52)
    self.purchaseButton:SetSize(186, 36)
    self.purchaseButton.swrpLabel = labels[state] or "UNAVAILABLE"
    self.purchaseButton:SetEnabled(available and points >= cost)
    self.purchaseButton:SetVisible(true)
    self.purchaseButton:MoveToFront()
end

function PANEL:PerformLayout(width, height)
    local buttonHeight = 30
    self.resetButton:SetSize(82, buttonHeight) self.resetButton:SetPos(width - 92, 10)
    self.zoomInButton:SetSize(30, buttonHeight) self.zoomInButton:SetPos(width - 128, 10)
    self.zoomOutButton:SetSize(30, buttonHeight) self.zoomOutButton:SetPos(width - 164, 10)
    self:UpdatePurchaseButton()

    if math.abs(width - self.lastLayoutWidth) > 4 or math.abs(height - self.lastLayoutHeight) > 4 then
        self.lastLayoutWidth, self.lastLayoutHeight = width, height
        timer.Simple(0, function() if IsValid(self) then self:ResetView() end end)
    end
end

function PANEL:Think()
    local x, y = self:CursorPos()
    local node = self:FindNodeAt(x, y)
    self.hoveredNodeID = node and node.id or nil

    if self.hoveredNodeID and self.hoveredNodeID ~= self.lastHoverSoundNode then
        self.lastHoverSoundNode = self.hoveredNodeID
        SWRP.Datapad.PlaySound("move")
    elseif not self.hoveredNodeID then
        self.lastHoverSoundNode = nil
    end

    self:SetCursor(self.dragging and "sizeall" or (node and "hand" or "sizeall"))
    if self.pendingUntil <= CurTime() then self.pendingNodeID = nil end
    self:UpdatePurchaseButton()
end

function PANEL:DrawTreeNode(node)
    local state = self:GetNodeState(node)
    local installed, available = state == "installed", state == "available"
    local hovered = self.hoveredNodeID == node.id
    local selected = self.selectedNodeID == node.id
    local pending = self.pendingNodeID == node.id
    local branch = branchColour(node, 255)
    local ring, fill, textColour = branch, Color(5, 16, 27, 248), Color(125, 148, 164)
    if installed then ring, fill, textColour = Color(105, 220, 175), Color(8, 35, 34, 252), Color(204, 244, 227)
    elseif available then fill, textColour = hovered and Color(17, 48, 70, 252) or Color(9, 29, 45, 250), color_white
    elseif state == "no_points" then ring, fill, textColour = Color(190, 151, 75), Color(31, 25, 14, 248), Color(211, 186, 131)
    elseif state == "locked" then ring = Color(64, 83, 98) end

    local x, y = self:WorldToPanel(node.x, node.y)
    local radius = math.Clamp(43 * self.zoom, 25, 48)
    if hovered or selected or pending then filledCircle(x, y, radius + 10, Color(ring.r, ring.g, ring.b, hovered and 34 or 20), 36) end
    filledCircle(x, y, radius, fill, 36)
    surface.SetDrawColor(ring.r, ring.g, ring.b, available and 240 or 175)
    surface.DrawCircle(x, y, radius, ring.r, ring.g, ring.b, available and 240 or 175)
    surface.DrawCircle(x, y, math.max(radius - 5, 1), ring.r, ring.g, ring.b, 85)

    local symbol = installed and "✓" or (pending and "…" or string.format("%02d", node.order))
    draw.SimpleText(symbol, radius >= 35 and "swrpDatapadBodyBold" or "swrpDatapadSmall", x, y, textColour, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    if self.zoom >= 0.58 then
        draw.SimpleText(string.upper(node.title), "swrpDatapadCategory", x, y + radius + 13, textColour, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(node.effect or "", "swrpDatapadSmall", x, y + radius + 31, Color(ring.r, ring.g, ring.b, (installed or available) and 225 or 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

function PANEL:Paint(width, height)
    local tree, accent = self:GetTree(), getAccent()
    draw.RoundedBox(2, 0, 0, width, height, Color(2, 9, 16, 248))
    drawCorners(0, 0, width, height, alphaColor(accent, 70), 15, 1)

    surface.SetDrawColor(accent.r, accent.g, accent.b, 9)
    local gridSize = math.max(math.floor(90 * self.zoom), 34)
    local gridOffsetX = (self.panX + width * 0.5) % gridSize
    local gridOffsetY = (self.panY + height * 0.5) % gridSize
    for x = gridOffsetX, width, gridSize do surface.DrawLine(x, 0, x, height) end
    for y = gridOffsetY, height, gridSize do surface.DrawLine(0, y, width, y) end

    if not tree then
        draw.SimpleText("CAREER TREE LINK UNAVAILABLE", "swrpDatapadPageTitle", width * 0.5, height * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if IsValid(self.purchaseButton) then self.purchaseButton:SetVisible(false) end
        return
    end

    local mask = self:GetMask()

    -- Each discipline occupies its own tinted lane so players can immediately
    -- understand which path a node belongs to, even when zoomed out.
    for _, branch in ipairs(tree.branches or {}) do
        local minimumY, maximumY = math.huge, -math.huge
        local maximumX = tree.root.x
        for _, node in ipairs(branch.nodes or {}) do
            minimumY = math.min(minimumY, node.y)
            maximumY = math.max(maximumY, node.y)
            maximumX = math.max(maximumX, node.x)
        end

        if minimumY ~= math.huge then
            local x1, y1 = self:WorldToPanel(-505, minimumY - 92)
            local x2, y2 = self:WorldToPanel(maximumX + 95, maximumY + 92)
            local left, top = math.min(x1, x2), math.min(y1, y2)
            local laneWidth, laneHeight = math.abs(x2 - x1), math.abs(y2 - y1)
            local colour = Color(branch.colour[1], branch.colour[2], branch.colour[3])

            draw.RoundedBox(3, left, top, laneWidth, laneHeight, Color(colour.r, colour.g, colour.b, 7))
            surface.SetDrawColor(colour.r, colour.g, colour.b, 28)
            surface.DrawOutlinedRect(left, top, laneWidth, laneHeight)
            surface.SetDrawColor(colour.r, colour.g, colour.b, 105)
            surface.DrawRect(left, top, math.max(3, math.floor(4 * self.zoom)), laneHeight)
        end
    end

    -- Draw connections before nodes. Locked paths remain visible, while the
    -- currently available route is bright enough to read at every zoom level.
    for _, node in ipairs(tree.nodes or {}) do
        for _, requirementID in ipairs(node.requires or {}) do
            local requirement = tree.GetNode(requirementID)
            if requirement then
                local x1, y1 = self:WorldToPanel(requirement.x, requirement.y)
                local x2, y2 = self:WorldToPanel(node.x, node.y)
                local colour = branchColour(node, 95)

                if tree.IsUnlocked(mask, requirement) and tree.IsUnlocked(mask, node) then
                    colour = Color(105, 220, 175, 235)
                elseif tree.PrerequisitesMet(mask, node) then
                    colour = branchColour(node, 230)
                elseif tree.IsUnlocked(mask, requirement) then
                    colour = branchColour(node, 155)
                end

                drawBeam(x1, y1, x2, y2, Color(colour.r, colour.g, colour.b, math.floor((colour.a or 255) * 0.18)), math.Clamp(18 * self.zoom, 8, 18))
                drawBeam(x1, y1, x2, y2, colour, math.Clamp(5 * self.zoom, 2.5, 5))
            end
        end
    end

    local rootX, rootY = self:WorldToPanel(tree.root.x, tree.root.y)
    local rootRadius = math.Clamp(58 * self.zoom, 35, 62)
    filledCircle(rootX, rootY, rootRadius + 10, Color(accent.r, accent.g, accent.b, 22), 42)
    filledCircle(rootX, rootY, rootRadius, Color(7, 24, 37, 252), 42)
    surface.SetDrawColor(accent.r, accent.g, accent.b, 210)
    surface.DrawCircle(rootX, rootY, rootRadius, accent.r, accent.g, accent.b, 210)
    draw.SimpleText("CT", "swrpDatapadPageTitle", rootX, rootY - 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(tree.root.title, "swrpDatapadBodyBold", rootX, rootY + rootRadius + 20, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    for _, branch in ipairs(tree.branches or {}) do
        local unlocked, total = tree.GetBranchProgress(mask, branch)
        local titleX, titleY = self:WorldToPanel(branch.titleX, branch.titleY)
        local colour = Color(branch.colour[1], branch.colour[2], branch.colour[3])
        draw.SimpleText(branch.title, "swrpDatapadBodyBold", titleX, titleY, colour)
        draw.SimpleText(branch.subtitle .. "  //  " .. unlocked .. "/" .. total, "swrpDatapadSmall", titleX, titleY + 22, Color(colour.r, colour.g, colour.b, 210))
    end

    for _, node in ipairs(tree.nodes or {}) do
        self:DrawTreeNode(node)
    end

    draw.SimpleText("CAREER DEVELOPMENT TREE", "swrpDatapadCategory", 16, 14, alphaColor(accent, 225))
    draw.SimpleText(string.format("ZOOM  %d%%", math.Round(self.zoom * 100)), "swrpDatapadSmall", 16, 34, Color(126, 151, 168))

    local selectedNode = self.selectedNodeID and tree.GetNode(self.selectedNodeID) or nil
    if not selectedNode then
        if IsValid(self.purchaseButton) then self.purchaseButton:SetVisible(false) end
        draw.SimpleText("SELECT A NODE TO REVIEW ITS AUTHORISATION", "swrpDatapadSmall", width * 0.5, height - 25, Color(120, 145, 162), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        return
    end

    local state, available, current, maximum, points = self:GetNodeState(selectedNode)
    local stateLabels = {
        installed = "INSTALLED",
        available = "AVAILABLE FOR PURCHASE",
        locked = "LOCKED — COMPLETE THE CONNECTED PREREQUISITE",
        no_points = "READY — INSUFFICIENT UPGRADE POINTS",
        capped = "CONDITIONING MAXIMUM REACHED"
    }
    local tooltipX, tooltipY, tooltipWidth, tooltipHeight = self:GetTooltipRect(selectedNode)
    local nodeColour = branchColour(selectedNode, 255)

    draw.RoundedBox(3, tooltipX, tooltipY, tooltipWidth, tooltipHeight, Color(3, 13, 22, 253))
    surface.SetDrawColor(nodeColour.r, nodeColour.g, nodeColour.b, 145)
    surface.DrawOutlinedRect(tooltipX, tooltipY, tooltipWidth, tooltipHeight)
    surface.DrawRect(tooltipX, tooltipY, 5, tooltipHeight)

    draw.SimpleText(string.upper(selectedNode.title), "swrpDatapadPageTitle", tooltipX + 20, tooltipY + 15, color_white)
    draw.SimpleText(string.upper(selectedNode.branch or "DEVELOPMENT"), "swrpDatapadCategory", tooltipX + 21, tooltipY + 53, nodeColour)
    draw.SimpleText(selectedNode.effect or "AUTHORISATION", "swrpDatapadBodyBold", tooltipX + 21, tooltipY + 78, nodeColour)
    drawWrappedText(selectedNode.description or "No additional information available.", "swrpDatapadBody", tooltipX + 21, tooltipY + 108, tooltipWidth - 42, Color(190, 210, 222), 20, 5)

    local requirementNames = {}
    for _, requirementID in ipairs(selectedNode.requires or {}) do
        local requirement = tree.GetNode(requirementID)
        requirementNames[#requirementNames + 1] = requirement and requirement.title or requirementID
    end
    local requirementText = #requirementNames > 0 and table.concat(requirementNames, selectedNode.requiresMode == "any" and "  OR  " or "  +  ") or "BASELINE SERVICE RECORD"
    draw.SimpleText("PREREQUISITE", "swrpDatapadCategory", tooltipX + 21, tooltipY + tooltipHeight - 91, Color(126, 151, 168))
    drawWrappedText(string.upper(requirementText), "swrpDatapadSmall", tooltipX + 21, tooltipY + tooltipHeight - 70, tooltipWidth - 250, Color(176, 197, 210), 17, 2)

    local stateText = stateLabels[state] or string.upper(state)
    if selectedNode.kind == "attribute" and maximum > 0 then
        stateText = stateText .. string.format("  •  CURRENT %d/%d", math.floor(current), math.floor(maximum))
    end

    draw.SimpleText(stateText, "swrpDatapadCategory", tooltipX + 21, tooltipY + tooltipHeight - 27, available and Color(105, 220, 175) or Color(158, 178, 191), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText("AVAILABLE POINTS  " .. points, "swrpDatapadSmall", tooltipX + tooltipWidth - 224, tooltipY + tooltipHeight - 70, Color(126, 151, 168), TEXT_ALIGN_RIGHT)
    self:UpdatePurchaseButton()
end

vgui.Register("swrpDatapadUpgradeTree", PANEL, "DPanel")

-- -------------------------------------------------------------------------
-- Inventory page. The real Helix inventory panel is resized to occupy the
-- full equipment bay. Optional expansion cells only appear when a genuine
-- datapad maximum has been configured by staff.
-- -------------------------------------------------------------------------

PANEL = {}

function PANEL:Init()
    self.sourceInfo = nil
    self.inventoryCanvas = nil

    self.inventoryShell = self:Add("DPanel")
    self.inventoryShell:Dock(LEFT)
    self.inventoryShell:SetWide(math.Clamp(ScrW() * 0.52, 660, 930))
    self.inventoryShell:DockMargin(0, 0, 12, 0)
    self.inventoryShell:DockPadding(14, 64, 14, 14)
    self.inventoryShell.Paint = function(panel, width, height)
        local accent = getAccent()
        local _, _, _, gridWidth, gridHeight = self:GetInventorySummary()
        local maxWidth, maxHeight = self:GetInventoryLimits(gridWidth, gridHeight)
        local currentSlots = gridWidth * gridHeight
        local maximumSlots = maxWidth * maxHeight

        draw.RoundedBox(2, 0, 0, width, height, Color(3, 11, 19, 244))
        drawCorners(0, 0, width, height, alphaColor(accent, 72), 15, 1)
        draw.SimpleText("FIELD EQUIPMENT GRID", "swrpDatapadBodyBold", 16, 15, color_white)
        draw.SimpleText(string.format("%d / %d SLOTS AVAILABLE", currentSlots, maximumSlots), "swrpDatapadSmall", 16, 40, Color(128, 151, 168))
    end

    self.inventoryHost = self.inventoryShell:Add("DPanel")
    self.inventoryHost:Dock(FILL)
    self.inventoryHost.Paint = function(panel, width, height)
        self:PaintCapacityGrid(width, height)
    end

    self.manifest = self:Add("DPanel")
    self.manifest:Dock(FILL)
    self.manifest.Paint = function(panel, width, height)
        self:PaintManifest(width, height)
    end
end

function PANEL:SetSourceInfo(info)
    self.sourceInfo = info

    if istable(info) and isfunction(info.Create) then
        info:Create(self.inventoryHost)
    elseif isfunction(info) then
        info(self.inventoryHost)
    end

    self.inventoryCanvas = ix.gui.menuInventoryContainer
    if IsValid(self.inventoryCanvas) then
        self.inventoryCanvas:SetBorder(0)
        self.inventoryCanvas:SetSpaceX(0)
        self.inventoryCanvas:SetSpaceY(0)
        self.inventoryCanvas.Paint = nil
        self.inventoryCanvas.PerformLayout = function()
            self:LayoutInventoryPanel()
        end
    end

    timer.Simple(0, function()
        if IsValid(self) then
            self:LayoutInventoryPanel()
        end
    end)
end

function PANEL:GetInventorySummary()
    local character = getCharacter()
    local inventory = character and character:GetInventory() or nil
    local items, count = {}, 0

    if inventory and inventory.GetItems then
        for _, item in pairs(inventory:GetItems() or {}) do
            count = count + 1
            items[#items + 1] = item
        end
    end

    table.sort(items, function(a, b)
        local aName = a.GetName and a:GetName() or a.name or ""
        local bName = b.GetName and b:GetName() or b.name or ""
        return tostring(aName) < tostring(bName)
    end)

    local width, height = 0, 0
    if inventory and inventory.GetSize then
        width, height = inventory:GetSize()
    elseif inventory then
        width, height = tonumber(inventory.w) or 0, tonumber(inventory.h) or 0
    end

    return inventory, items, count, math.max(tonumber(width) or 0, 1), math.max(tonumber(height) or 0, 1)
end

function PANEL:GetInventoryLimits(gridWidth, gridHeight)
    local configuredWidth = tonumber(ix.config.Get("datapadInventoryMaxWidth", 0)) or 0
    local configuredHeight = tonumber(ix.config.Get("datapadInventoryMaxHeight", 0)) or 0

    local maximumWidth = configuredWidth > 0 and math.max(configuredWidth, gridWidth) or gridWidth
    local maximumHeight = configuredHeight > 0 and math.max(configuredHeight, gridHeight) or gridHeight
    return maximumWidth, maximumHeight
end

function PANEL:GetGridGeometry(width, height)
    local _, _, _, gridWidth, gridHeight = self:GetInventorySummary()
    local maxWidth, maxHeight = self:GetInventoryLimits(gridWidth, gridHeight)
    local padding = 12
    local cell = math.floor(math.min((width - padding * 2) / maxWidth, (height - padding * 2) / maxHeight))
    cell = math.max(cell, 22)
    local totalWidth, totalHeight = cell * maxWidth, cell * maxHeight
    local originX = math.floor((width - totalWidth) * 0.5)
    local originY = math.floor((height - totalHeight) * 0.5)
    return originX, originY, cell, gridWidth, gridHeight, maxWidth, maxHeight
end

function PANEL:LayoutInventoryPanel()
    local canvas = self.inventoryCanvas
    local inventoryPanel = ix.gui.inv1
    if not IsValid(canvas) or not IsValid(inventoryPanel) or not IsValid(self.inventoryHost) then
        return
    end

    local width, height = self.inventoryHost:GetSize()
    if width <= 0 or height <= 0 then
        return
    end

    local originX, originY, cell, gridWidth, gridHeight = self:GetGridGeometry(width, height)
    inventoryPanel:SetIconSize(cell)
    inventoryPanel:SetGridSize(gridWidth, gridHeight)
    inventoryPanel:SetPos(originX - 4, originY - inventoryPanel:GetPadding(2))
    inventoryPanel:SetZPos(10)
    inventoryPanel:RebuildItems()
end

function PANEL:PaintCapacityGrid(width, height)
    local accent = getAccent()
    local originX, originY, cell, gridWidth, gridHeight, maxWidth, maxHeight = self:GetGridGeometry(width, height)

    draw.RoundedBox(2, 0, 0, width, height, Color(2, 8, 14, 238))
    surface.SetDrawColor(accent.r, accent.g, accent.b, 38)
    surface.DrawOutlinedRect(0, 0, width, height)

    -- Only draw cells outside the real Helix inventory. The active cells are
    -- the actual interactive inventory slots layered above this panel.
    for row = 1, maxHeight do
        for column = 1, maxWidth do
            local active = column <= gridWidth and row <= gridHeight
            if not active then
                local x = originX + (column - 1) * cell
                local y = originY + (row - 1) * cell
                draw.RoundedBox(1, x + 2, y + 2, cell - 4, cell - 4, Color(4, 9, 14, 220))
                surface.SetDrawColor(accent.r, accent.g, accent.b, 18)
                surface.DrawOutlinedRect(x + 2, y + 2, cell - 4, cell - 4)
                surface.SetDrawColor(100, 120, 135, 14)
                surface.DrawLine(x + 7, y + 7, x + cell - 7, y + cell - 7)
                surface.DrawLine(x + cell - 7, y + 7, x + 7, y + cell - 7)
            end
        end
    end

    if maxWidth == gridWidth and maxHeight == gridHeight then
        draw.SimpleText("CURRENT HELIX INVENTORY CAPACITY", "swrpDatapadSmall", width * 0.5, height - 16, Color(112, 136, 153), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        draw.SimpleText("FADED CELLS REQUIRE INVENTORY EXPANSION", "swrpDatapadSmall", width * 0.5, height - 16, Color(112, 136, 153), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

function PANEL:PaintManifest(width, height)
    local accent = getAccent()
    local _, items, count, gridWidth, gridHeight = self:GetInventorySummary()
    local maxWidth, maxHeight = self:GetInventoryLimits(gridWidth, gridHeight)
    local capacity = gridWidth * gridHeight
    local maximum = maxWidth * maxHeight

    draw.RoundedBox(2, 0, 0, width, height, Color(3, 11, 19, 244))
    drawCorners(0, 0, width, height, alphaColor(accent, 72), 15, 1)
    draw.SimpleText("EQUIPMENT MANIFEST", "swrpDatapadBodyBold", 18, 17, color_white)
    draw.SimpleText("ISSUED TO  " .. SWRP.Datapad.GetIdentity(getCharacter()).serviceCode, "swrpDatapadSmall", 18, 44, alphaColor(accent, 225))

    local cardY, cardHeight = 78, 88
    local cardWidth = math.floor((width - 46) / 2)
    local function drawStatCard(x, title, value, description, fraction)
        draw.RoundedBox(2, x, cardY, cardWidth, cardHeight, Color(5, 15, 25, 238))
        surface.SetDrawColor(accent.r, accent.g, accent.b, 43)
        surface.DrawOutlinedRect(x, cardY, cardWidth, cardHeight)
        draw.SimpleText(title, "swrpDatapadCategory", x + 13, cardY + 12, alphaColor(accent, 220))
        draw.SimpleText(value, "swrpDatapadCardValue", x + 13, cardY + 31, color_white)
        draw.SimpleText(description, "swrpDatapadSmall", x + 13, cardY + 69, Color(128, 151, 168), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if fraction then
            draw.RoundedBox(1, x + 13, cardY + cardHeight - 8, cardWidth - 26, 3, Color(10, 25, 37))
            draw.RoundedBox(1, x + 13, cardY + cardHeight - 8, (cardWidth - 26) * math.Clamp(fraction, 0, 1), 3, accent)
        end
    end

    drawStatCard(16, "ITEMS CARRIED", tostring(count), "Inventory objects", capacity > 0 and count / capacity or 0)
    drawStatCard(30 + cardWidth, "GRID CAPACITY", string.format("%d / %d SLOTS", capacity, maximum), maximum > capacity and string.format("%d expansion slots", maximum - capacity) or "Current configured maximum", maximum > 0 and capacity / maximum or 1)

    local listY = cardY + cardHeight + 30
    draw.SimpleText("CURRENT LOADOUT", "swrpDatapadCategory", 18, listY, alphaColor(accent, 220))

    if count == 0 then
        local emptyY, emptyHeight = listY + 32, math.min(230, height - listY - 52)
        draw.RoundedBox(2, 16, emptyY, width - 32, emptyHeight, Color(4, 13, 22, 225))
        surface.SetDrawColor(accent.r, accent.g, accent.b, 35)
        surface.DrawOutlinedRect(16, emptyY, width - 32, emptyHeight)
        draw.SimpleText("[  EMPTY  ]", "swrpDatapadPageTitle", width * 0.5, emptyY + emptyHeight * 0.35, alphaColor(accent, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("NO EQUIPMENT ISSUED", "swrpDatapadBodyBold", width * 0.5, emptyY + emptyHeight * 0.57, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Requisitioned supplies and carried mission items will appear here.", "swrpDatapadSmall", width * 0.5, emptyY + emptyHeight * 0.72, Color(137, 159, 175), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        return
    end

    local rowY = listY + 28
    for index, item in ipairs(items) do
        if index > 9 then
            draw.SimpleText("+ " .. tostring(count - 9) .. " ADDITIONAL ITEMS", "swrpDatapadSmall", 20, rowY + 8, Color(128, 151, 168))
            break
        end

        local itemName = item.GetName and item:GetName() or item.name or item.uniqueID or "UNKNOWN ITEM"
        local itemID = item.uniqueID or "equipment"
        draw.RoundedBox(1, 16, rowY, width - 32, 42, Color(5, 15, 25, 225))
        surface.SetDrawColor(accent.r, accent.g, accent.b, 31)
        surface.DrawOutlinedRect(16, rowY, width - 32, 42)
        draw.SimpleText(string.upper(tostring(itemName)), "swrpDatapadBodyBold", 28, rowY + 9, color_white)
        draw.SimpleText(string.upper(tostring(itemID)), "swrpDatapadSmall", width - 28, rowY + 21, Color(125, 149, 166), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        rowY = rowY + 48
    end
end

function PANEL:PerformLayout(width, height)
    self.inventoryShell:SetWide(math.floor(width * 0.62))
    timer.Simple(0, function()
        if IsValid(self) then
            self:LayoutInventoryPanel()
        end
    end)
end

vgui.Register("swrpDatapadInventory", PANEL, "DPanel")

-- -------------------------------------------------------------------------
-- Personnel roster grouped by faction, with each connected player's actual
-- playermodel and a vessel-summary column that keeps the page informative.
-- -------------------------------------------------------------------------

PANEL = {}

function PANEL:Init()
    self.signature, self.nextRefresh = "", 0

    self.summary = self:Add("DPanel")
    self.summary:Dock(TOP)
    self.summary:SetTall(100)
    self.summary:DockMargin(0, 0, 0, 10)
    self.summary.Paint = function(panel, width, height)
        local accent = getAccent()
        local clients = player.GetAll()
        local factionSet = {}
        local staff = 0
        local totalPing = 0

        for _, client in ipairs(clients) do
            local character = client.GetCharacter and client:GetCharacter() or nil
            local faction = character and ix.faction.indices[character:GetFaction()] or nil
            factionSet[faction and L(faction.name) or "UNASSIGNED"] = true
            if client:IsAdmin() then staff = staff + 1 end
            totalPing = totalPing + client:Ping()
        end

        local factionCount = table.Count(factionSet)
        local averagePing = #clients > 0 and math.floor(totalPing / #clients) or 0
        draw.RoundedBox(2, 0, 0, width, height, Color(4, 13, 22, 240))
        drawCorners(0, 0, width, height, alphaColor(accent, 75), 14, 1)

        local metrics = {
            {"CONNECTED", tostring(#clients)},
            {"FACTIONS", tostring(factionCount)},
            {"STAFF ONLINE", tostring(staff)},
            {"AVERAGE PING", tostring(averagePing) .. " ms"}
        }

        local metricWidth = width / #metrics
        for index, metric in ipairs(metrics) do
            local x = (index - 1) * metricWidth
            if index > 1 then
                surface.SetDrawColor(accent.r, accent.g, accent.b, 28)
                surface.DrawRect(x, 14, 1, height - 28)
            end
            draw.SimpleText(metric[1], "swrpDatapadCategory", x + 17, 18, alphaColor(accent, 220))
            draw.SimpleText(metric[2], "swrpDatapadPageTitle", x + 17, 45, color_white)
        end
    end

    self.body = self:Add("DPanel")
    self.body:Dock(FILL)
    self.body.Paint = nil

    self.sideSummary = self.body:Add("DPanel")
    self.sideSummary:Dock(RIGHT)
    self.sideSummary:SetWide(math.Clamp(ScrW() * 0.17, 260, 340))
    self.sideSummary:DockMargin(10, 0, 0, 0)
    self.sideSummary.Paint = function(panel, width, height)
        self:PaintVesselSummary(width, height)
    end

    self.scroll = self.body:Add("DScrollPanel")
    self.scroll:Dock(FILL)
    self.scroll:GetCanvas():DockPadding(0, 2, 8, 6)
    self:Rebuild()
end

function PANEL:BuildSignature()
    local pieces = {}
    for _, client in ipairs(player.GetAll()) do
        local character = client.GetCharacter and client:GetCharacter() or nil
        local identity = SWRP.Datapad.GetIdentity(character)
        pieces[#pieces + 1] = table.concat({
            tostring(client:EntIndex()), identity.serviceCode, identity.displayName,
            identity.rank, identity.regiment, identity.trainingState,
            tostring(identity.level), client:GetModel(), tostring(client:Ping())
        }, ":")
    end
    table.sort(pieces)
    return table.concat(pieces, "|")
end

function PANEL:GetGroupedPersonnel()
    local grouped = {}
    for _, client in ipairs(player.GetAll()) do
        local character = client.GetCharacter and client:GetCharacter() or nil
        local faction = character and ix.faction.indices[character:GetFaction()] or nil
        local factionName = faction and L(faction.name) or "UNASSIGNED PERSONNEL"
        grouped[factionName] = grouped[factionName] or {faction = faction, clients = {}}
        grouped[factionName].clients[#grouped[factionName].clients + 1] = client
    end
    return grouped
end

function PANEL:PaintVesselSummary(width, height)
    local accent = getAccent()
    local grouped = self:GetGroupedPersonnel()
    local staff = {}

    for _, client in ipairs(player.GetAll()) do
        if client:IsAdmin() then
            staff[#staff + 1] = client
        end
    end

    draw.RoundedBox(2, 0, 0, width, height, Color(3, 11, 19, 242))
    drawCorners(0, 0, width, height, alphaColor(accent, 65), 14, 1)
    draw.SimpleText("VESSEL SUMMARY", "swrpDatapadBodyBold", 16, 16, color_white)
    draw.SimpleText("ACTIVE FACTIONS", "swrpDatapadCategory", 16, 51, alphaColor(accent, 220))

    local y = 76
    for factionName, group in SortedPairs(grouped) do
        local colour = group.faction and group.faction.color or accent
        draw.RoundedBox(2, 14, y, width - 28, 54, Color(5, 15, 25, 230))
        surface.SetDrawColor(colour.r, colour.g, colour.b, 100)
        surface.DrawRect(14, y, 4, 54)
        draw.SimpleText(string.upper(factionName), "swrpDatapadSmall", 27, y + 11, color_white)
        draw.SimpleText(#group.clients .. " ONLINE", "swrpDatapadBodyBold", 27, y + 29, Color(colour.r, colour.g, colour.b))
        y = y + 62
    end

    y = y + 14
    draw.SimpleText("COMMAND STAFF ONLINE", "swrpDatapadCategory", 16, y, alphaColor(accent, 220))
    y = y + 26

    if #staff == 0 then
        draw.SimpleText("NO STAFF CURRENTLY CONNECTED", "swrpDatapadSmall", 16, y, Color(130, 153, 169))
    else
        for _, client in ipairs(staff) do
            draw.RoundedBox(2, 14, y, width - 28, 44, Color(5, 15, 25, 225))
            draw.SimpleText(string.upper(client:Nick()), "swrpDatapadBodyBold", 26, y + 8, color_white)
            draw.SimpleText(string.upper(client:GetUserGroup()), "swrpDatapadSmall", width - 24, y + 22, Color(105, 220, 175), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            y = y + 50
        end
    end

    draw.SimpleText("MODELS AND IDENTITIES ARE READ LIVE FROM CONNECTED CHARACTERS.", "swrpDatapadSmall", 16, height - 20, Color(105, 132, 149), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function PANEL:Rebuild()
    self.scroll:Clear()
    local grouped = self:GetGroupedPersonnel()

    for factionName, group in SortedPairs(grouped) do
        local factionLabel = factionName
        local factionGroup = group
        table.sort(factionGroup.clients, function(a, b)
            local ai = SWRP.Datapad.GetIdentity(a.GetCharacter and a:GetCharacter() or nil)
            local bi = SWRP.Datapad.GetIdentity(b.GetCharacter and b:GetCharacter() or nil)
            return ai.cloneNumber < bi.cloneNumber
        end)

        local header = self.scroll:Add("DPanel")
        header:Dock(TOP)
        header:SetTall(48)
        header:DockMargin(0, 4, 0, 6)
        header.Paint = function(panel, width, height)
            local colour = factionGroup.faction and factionGroup.faction.color or getAccent()
            draw.RoundedBox(2, 0, 0, width, height, Color(7, 20, 31, 245))
            surface.SetDrawColor(colour.r, colour.g, colour.b, 180)
            surface.DrawRect(0, 0, 4, height)
            draw.SimpleText(string.upper(factionLabel), "swrpDatapadBodyBold", 16, height * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(#factionGroup.clients) .. " PERSONNEL", "swrpDatapadSmall", width - 16, height * 0.5, Color(colour.r, colour.g, colour.b), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        for _, client in ipairs(factionGroup.clients) do
            local rosterClient = client
            local rosterFactionLabel = factionLabel
            local row = self.scroll:Add("DPanel")
            row:Dock(TOP)
            row:SetTall(142)
            row:DockMargin(0, 0, 0, 8)

            local model = row:Add("DModelPanel")
            model:SetPos(10, 10)
            model:SetSize(118, 122)
            model:SetMouseInputEnabled(false)
            model:SetPaintBackground(false)
            timer.Simple(0, function()
                if IsValid(model) and IsValid(rosterClient) then
                    configureClientModel(model, rosterClient, false)
                end
            end)

            row.Paint = function(panel, width, height)
                if not IsValid(rosterClient) then return end
                local accent = getAccent()
                local character = rosterClient.GetCharacter and rosterClient:GetCharacter() or nil
                local identity = SWRP.Datapad.GetIdentity(character)
                local localClient = rosterClient == LocalPlayer()
                local faction = character and ix.faction.indices[character:GetFaction()] or nil
                local factionColour = faction and faction.color or accent

                draw.RoundedBox(2, 0, 0, width, height, localClient and Color(12, 31, 47, 242) or Color(4, 13, 22, 238))
                surface.SetDrawColor(factionColour.r, factionColour.g, factionColour.b, localClient and 135 or 52)
                surface.DrawOutlinedRect(0, 0, width, height)
                surface.DrawRect(0, 0, 4, height)

                draw.SimpleText(identity.serviceCode, "swrpDatapadPageTitle", 144, 16, color_white)
                draw.SimpleText(string.upper(identity.displayName), "swrpDatapadBodyBold", 146, 53, alphaColor(accent, 230))
                draw.SimpleText(string.upper(rosterFactionLabel), "swrpDatapadSmall", 146, 78, Color(factionColour.r, factionColour.g, factionColour.b))

                local columnX = math.max(width * 0.48, 390)
                draw.SimpleText("RANK", "swrpDatapadCategory", columnX, 18, Color(112, 137, 154))
                draw.SimpleText(string.upper(identity.rank), "swrpDatapadBodyBold", columnX, 41, color_white)
                draw.SimpleText("REGIMENT", "swrpDatapadCategory", columnX, 78, Color(112, 137, 154))
                draw.SimpleText(string.upper(identity.regiment), "swrpDatapadBodyBold", columnX, 101, color_white)

                local statusX = math.max(width * 0.72, columnX + 180)
                draw.SimpleText("TRAINING", "swrpDatapadCategory", statusX, 18, Color(112, 137, 154))
                draw.SimpleText(identity.trainingState, "swrpDatapadBodyBold", statusX, 41, Color(105, 220, 175))
                draw.SimpleText("SERVICE LEVEL", "swrpDatapadCategory", statusX, 78, Color(112, 137, 154))
                draw.SimpleText(tostring(identity.level), "swrpDatapadBodyBold", statusX, 101, color_white)

                draw.SimpleText("ACTIVE", "swrpDatapadBodyBold", width - 18, 22, Color(105, 220, 175), TEXT_ALIGN_RIGHT)
                draw.SimpleText(tostring(rosterClient:Ping()) .. " ms", "swrpDatapadSmall", width - 18, 51, Color(143, 164, 179), TEXT_ALIGN_RIGHT)
                draw.SimpleText(string.upper(rosterClient:GetUserGroup()), "swrpDatapadSmall", width - 18, 105, rosterClient:IsAdmin() and Color(218, 162, 91) or Color(120, 144, 160), TEXT_ALIGN_RIGHT)
            end
        end
    end

    self.signature = self:BuildSignature()
end

function PANEL:Think()
    if CurTime() < self.nextRefresh then return end
    self.nextRefresh = CurTime() + 1
    local signature = self:BuildSignature()
    if signature ~= self.signature then self:Rebuild() end
end

vgui.Register("swrpDatapadRoster", PANEL, "DPanel")

-- Upgrade result feedback. Character attributes and points remain server-authoritative;
-- this only refreshes open controls and reports the result to the player.
net.Receive("swrpDatapadUpgradeResult", function()
    local success = net.ReadBool()
    local message = net.ReadString()
    local nodeID = net.ReadString()

    notification.AddLegacy(message, success and NOTIFY_GENERIC or NOTIFY_ERROR, 4)
    SWRP.Datapad.PlaySound(success and "move" or "back")
    hook.Run("SWRPDatapadUpgradeResult", success, message, nodeID)
end)
