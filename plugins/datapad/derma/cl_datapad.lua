-- swrp/plugins/datapad/derma/cl_datapad.lua
-- Republic personnel datapad / Helix TAB-menu replacement.

SWRP = SWRP or {}
SWRP.Datapad = SWRP.Datapad or {}

SWRP.Datapad.Sounds = {
    move = {"swrp/ui/ui_menuMove.wav", "swrp/ui/ui_menumove.wav"},
    back = {"swrp/ui/ui_menuBack.wav", "swrp/ui/ui_menuback.wav"},
    zoom = {"swrp/ui/ui_planetzoom.wav"}
}

-- UI sounds are emitted on the engine's dedicated UI entity (-2). This avoids
-- positional attenuation and is more reliable than depending on a panel's
-- paint state. The path remains relative to garrysmod/sound/.
function SWRP.Datapad.PlaySound(kind)
    local candidates = SWRP.Datapad.Sounds[kind]
    if not istable(candidates) then
        return false
    end

    local selected = candidates[1]
    for _, path in ipairs(candidates) do
        if isstring(path) and path ~= "" and file.Exists("sound/" .. path, "GAME") then
            selected = path
            break
        end
    end

    if not isstring(selected) or selected == "" then
        return false
    end

    -- Global EmitSound with entity -2 is a non-spatial UI sound. It is local
    -- when called clientside and works with the supplied PCM WAV files.
    EmitSound(selected, vector_origin, -2, CHAN_STATIC, 1, 0, 0, 100)
    return true
end

-- Handy client test: swrp_datapad_test_sounds
concommand.Add("swrp_datapad_test_sounds", function()
    SWRP.Datapad.PlaySound("move")
    timer.Simple(0.8, function() SWRP.Datapad.PlaySound("back") end)
    timer.Simple(1.6, function() SWRP.Datapad.PlaySound("zoom") end)
end)

local ANIMATION_TIME = 0.35

-- Main-menu page metadata. These must live in this Lua chunk because the
-- datapad shell directly consumes them; locals from cl_datapad_pages.lua are
-- not visible here.
local PAGE_DEFINITIONS = {
    navigator = {
        label = "Navigator",
        category = "FIELD OPERATIONS",
        subtitle = "Internal vessel navigation and route guidance",
        order = 10
    },
    you = {
        label = "Character",
        category = "PERSONNEL",
        subtitle = "Service identity, operational status, career progression and permanent upgrades",
        order = 10
    },
    inv = {
        label = "Inventory",
        category = "PERSONNEL",
        subtitle = "Issued equipment, field pack capacity and carried supplies",
        order = 20
    },
    scoreboard = {
        label = "Personnel Roster",
        category = "REPUBLIC NETWORK",
        subtitle = "Connected personnel and active assignments",
        order = 10
    },
    help = {
        label = "Republic Database",
        category = "REPUBLIC NETWORK",
        subtitle = "Commands, operational guidance and schema information",
        order = 20
    },
    settings = {
        label = "Settings",
        category = "SYSTEM",
        subtitle = "Personal interface and gameplay preferences",
        order = 10
    }
}

local CATEGORY_ORDER = {
    "PERSONNEL",
    "FIELD OPERATIONS",
    "REPUBLIC NETWORK",
    "ADDITIONAL SYSTEMS",
    "SYSTEM"
}

local HIDDEN_TABS = {
    business = true,
    config = true
}

local CUSTOM_DATAPAD_PAGES = {
    you = true,
    inv = true,
    scoreboard = true,
    help = true,
    settings = true
}

local function shouldHideBackground(pageKey, info)
    if CUSTOM_DATAPAD_PAGES[pageKey] then
        return false
    end

    return istable(info) and info.bHideBackground == true
end

local function alphaColor(colour, alpha)
    return Color(colour.r, colour.g, colour.b, alpha)
end

-- cl_datapad.lua and cl_datapad_pages.lua are included as separate Lua chunks,
-- so local helpers declared in one file are not visible in the other. Keep an
-- accent accessor in this file for the shared shell and controls.
local function getAccent()
    return (ix and ix.config and ix.config.Get("color")) or Color(73, 132, 207)
end

local function hideModelPanels(root)
    if not IsValid(root) then return end

    for _, child in ipairs(root:GetChildren() or {}) do
        if IsValid(child) then
            if child.GetClassName and child:GetClassName() == "DModelPanel" then
                child:SetVisible(false)
            end

            hideModelPanels(child)
        end
    end
end

local function brighten(colour, amount)
    return Color(
        math.min(colour.r + amount, 255),
        math.min(colour.g + amount, 255),
        math.min(colour.b + amount, 255),
        colour.a or 255
    )
end

local function humaniseKey(value)
    value = tostring(value or "system")
    value = string.gsub(value, "_", " ")
    value = string.gsub(value, "(%l)(%u)", "%1 %2")
    return string.upper(string.sub(value, 1, 1)) .. string.sub(value, 2)
end

local function formatShipTime()
    -- This string is formatted by the server itself, so it follows the server
    -- machine's clock/timezone rather than the client's clock or Helix RP date.
    local serverTime = GetGlobalString("swrpDatapadServerTime", "")
    if serverTime ~= "" then
        return serverTime .. " SERVER TIME"
    end

    return os.date("%H:%M") .. " LOCAL TIME"
end

local function drawCorners(x, y, width, height, colour, length, thickness)
    length = length or 16
    thickness = thickness or 2

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

local function drawScanlines(x, y, width, height, alpha)
    alpha = alpha or 7
    surface.SetDrawColor(90, 185, 235, alpha)

    for lineY = y, y + height, 5 do
        surface.DrawRect(x, lineY, width, 1)
    end
end

local function createFonts()
    local scale = math.Clamp(ScrH() / 1080, 0.72, 1.25)

    surface.CreateFont("swrpDatapadTitle", {
        font = "Roboto",
        size = math.floor(25 * scale),
        weight = 700,
        extended = true
    })

    surface.CreateFont("swrpDatapadSubTitle", {
        font = "Roboto",
        size = math.floor(12 * scale),
        weight = 600,
        extended = true
    })

    surface.CreateFont("swrpDatapadNav", {
        font = "Roboto",
        size = math.floor(19 * scale),
        weight = 400,
        extended = true
    })

    surface.CreateFont("swrpDatapadNavSelected", {
        font = "Roboto",
        size = math.floor(19 * scale),
        weight = 700,
        extended = true
    })

    surface.CreateFont("swrpDatapadCategory", {
        font = "Roboto",
        size = math.floor(10 * scale),
        weight = 700,
        extended = true
    })

    surface.CreateFont("swrpDatapadPageTitle", {
        font = "Roboto",
        size = math.floor(28 * scale),
        weight = 600,
        extended = true
    })

    surface.CreateFont("swrpDatapadBody", {
        font = "Roboto",
        size = math.floor(15 * scale),
        weight = 400,
        extended = true
    })

    surface.CreateFont("swrpDatapadBodyBold", {
        font = "Roboto",
        size = math.floor(15 * scale),
        weight = 700,
        extended = true
    })

    surface.CreateFont("swrpDatapadSmall", {
        font = "Roboto",
        size = math.floor(11 * scale),
        weight = 500,
        extended = true
    })

    surface.CreateFont("swrpDatapadCardValue", {
        font = "Roboto",
        size = math.floor(24 * scale),
        weight = 700,
        extended = true
    })
end

createFonts()
hook.Add("LoadFonts", "swrpDatapadFonts", createFonts)

-- -------------------------------------------------------------------------
-- Shared visual controls
-- -------------------------------------------------------------------------

local PANEL = {}

function PANEL:Init()
    self:SetText("")
    self:SetTall(46)
    self.selected = false
    self.badge = nil
    self.label = ""
    self.hoverFraction = 0
end

function PANEL:SetLabel(text)
    self.label = text or ""
end

function PANEL:SetBadge(text)
    self.badge = text
end

function PANEL:SetSelected(selected)
    self.selected = tobool(selected)
end

function PANEL:OnCursorEntered()
    SWRP.Datapad.PlaySound("move")
end

function PANEL:Think()
    local target = (self:IsHovered() or self.selected) and 1 or 0
    self.hoverFraction = math.Approach(self.hoverFraction, target, FrameTime() * 8)
end

function PANEL:Paint(width, height)
    local accent = getAccent()
    local fraction = self.hoverFraction

    if self.selected then
        surface.SetDrawColor(accent.r, accent.g, accent.b, 34 + 80 * fraction)
        surface.DrawRect(0, 0, width, height)

        surface.SetDrawColor(accent.r, accent.g, accent.b, 235)
        surface.DrawRect(0, 0, 3, height)

        surface.SetDrawColor(accent.r, accent.g, accent.b, 90)
        surface.DrawRect(3, height - 1, width - 3, 1)
    elseif fraction > 0 then
        surface.SetDrawColor(255, 255, 255, 11 * fraction)
        surface.DrawRect(0, 0, width, height)
    end

    local font = self.selected and "swrpDatapadNavSelected" or "swrpDatapadNav"
    local textColour = self.selected and color_white or Color(184, 199, 211)

    draw.SimpleText(self.label, font, 15, height * 0.5, textColour, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    if self.badge and self.badge ~= "" then
        surface.SetFont("swrpDatapadSmall")
        local textWidth = surface.GetTextSize(self.badge)
        local badgeWidth = textWidth + 16
        local badgeHeight = 22
        local badgeX = width - badgeWidth - 10
        local badgeY = math.floor((height - badgeHeight) * 0.5)

        draw.RoundedBox(2, badgeX, badgeY, badgeWidth, badgeHeight, alphaColor(accent, 42))
        surface.SetDrawColor(accent.r, accent.g, accent.b, 130)
        surface.DrawOutlinedRect(badgeX, badgeY, badgeWidth, badgeHeight)
        draw.SimpleText(self.badge, "swrpDatapadSmall", badgeX + badgeWidth * 0.5, badgeY + badgeHeight * 0.5, brighten(accent, 45), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

vgui.Register("swrpDatapadNavButton", PANEL, "DButton")

PANEL = {}

function PANEL:Init()
    self:SetText("")
    self.label = ""
    self.selected = false
end

function PANEL:SetLabel(text)
    self.label = text or ""
end

function PANEL:SetSelected(selected)
    self.selected = tobool(selected)
end

function PANEL:OnCursorEntered()
    SWRP.Datapad.PlaySound("move")
end

function PANEL:Paint(width, height)
    local accent = getAccent()
    local active = self.selected
    local hovered = self:IsHovered()

    local background = Color(8, 18, 29, 220)
    if active then
        background = alphaColor(accent, 66)
    elseif hovered then
        background = Color(15, 31, 46, 235)
    end

    draw.RoundedBox(2, 0, 0, width, height, background)

    surface.SetDrawColor(accent.r, accent.g, accent.b, active and 190 or 55)
    surface.DrawOutlinedRect(0, 0, width, height)

    draw.SimpleText(self.label, "swrpDatapadSubTitle", width * 0.5, height * 0.5, active and color_white or Color(155, 180, 198), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

vgui.Register("swrpDatapadSegmentButton", PANEL, "DButton")

PANEL = {}

function PANEL:Init()
    self.title = ""
    self.value = ""
    self.description = ""
    self.actionLabel = nil
    self.clickable = false
    self.hoverFraction = 0
end

function PANEL:SetCard(title, value, description)
    self.title = title or ""
    self.value = value or ""
    self.description = description or ""
end

function PANEL:SetAction(label, callback)
    self.actionLabel = label
    self.actionCallback = callback
    self.clickable = isfunction(callback)
    self:SetCursor(self.clickable and "hand" or "arrow")
    self:SetMouseInputEnabled(self.clickable)
end

function PANEL:OnMousePressed(code)
    if code == MOUSE_LEFT and self.clickable and self.actionCallback then
        self.actionCallback(self)
    end
end

function PANEL:OnCursorEntered()
    if self.clickable then
        SWRP.Datapad.PlaySound("move")
    end
end

function PANEL:Think()
    local target = (self.clickable and self:IsHovered()) and 1 or 0
    self.hoverFraction = math.Approach(self.hoverFraction, target, FrameTime() * 7)
end

function PANEL:Paint(width, height)
    local accent = getAccent()
    local background = Color(4, 13, 22, 235)

    if self.hoverFraction > 0 then
        background = Color(
            4 + 8 * self.hoverFraction,
            13 + 16 * self.hoverFraction,
            22 + 20 * self.hoverFraction,
            242
        )
    end

    draw.RoundedBox(3, 0, 0, width, height, background)
    drawCorners(0, 0, width, height, alphaColor(accent, 55 + 55 * self.hoverFraction), 13, 1)

    local compact = height < 82
    local titleY = compact and 9 or 13
    draw.SimpleText(string.upper(self.title), "swrpDatapadCategory", 16, titleY, alphaColor(accent, 220))

    local valueFont = compact and "swrpDatapadBodyBold" or "swrpDatapadCardValue"
    surface.SetFont(valueFont)
    local valueWidth = surface.GetTextSize(self.value or "")
    if valueWidth > width - 32 then
        valueFont = "swrpDatapadBodyBold"
    end

    local valueY = compact and math.floor(height * 0.52) or math.floor(height * 0.51)
    draw.SimpleText(self.value, valueFont, 16, valueY, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    if self.description ~= "" and not compact then
        draw.SimpleText(self.description, "swrpDatapadSmall", 16, height - 16, Color(136, 159, 176), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if self.actionLabel then
        draw.SimpleText(string.upper(self.actionLabel), "swrpDatapadSmall", width - 16, height - 16, brighten(accent, 35), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end

vgui.Register("swrpDatapadStatusCard", PANEL, "DPanel")

-- -------------------------------------------------------------------------
-- Overview page
-- -------------------------------------------------------------------------

PANEL = {}

function PANEL:Init()
    self:DockPadding(4, 4, 4, 4)

    self.scroll = self:Add("DScrollPanel")
    self.scroll:Dock(FILL)
    self.scroll:GetCanvas():DockPadding(0, 0, 8, 8)

    self.identity = self.scroll:Add("DPanel")
    self.identity:Dock(TOP)
    self.identity:SetTall(142)
    self.identity:DockMargin(0, 0, 0, 12)
    self.identity.Paint = function(panel, width, height)
        local accent = getAccent()
        local character = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()
        local identity = SWRP.Datapad.GetIdentity and SWRP.Datapad.GetIdentity(character) or {
            serviceCode = "CT-----",
            displayName = character and character:GetName() or LocalPlayer():Nick(),
            rank = "CLONE TROOPER",
            regiment = "UNASSIGNED",
            assignment = "UNASSIGNED PERSONNEL"
        }

        draw.RoundedBox(3, 0, 0, width, height, Color(4, 13, 22, 238))
        drawCorners(0, 0, width, height, alphaColor(accent, 85), 17, 2)
        drawScanlines(0, 0, width, height, 4)

        draw.SimpleText("REPUBLIC PERSONNEL RECORD", "swrpDatapadCategory", 20, 17, alphaColor(accent, 220))
        draw.SimpleText(identity.serviceCode, "swrpDatapadPageTitle", 20, 41, color_white)
        draw.SimpleText(string.upper(identity.displayName), "swrpDatapadBodyBold", 21, 80, alphaColor(accent, 225))
        draw.SimpleText(string.upper(identity.rank .. "  •  " .. identity.regiment), "swrpDatapadSmall", 21, 108, Color(165, 188, 203))

        draw.SimpleText("CURRENT ASSIGNMENT", "swrpDatapadCategory", width - 26, 19, Color(120, 145, 162), TEXT_ALIGN_RIGHT)
        draw.SimpleText(string.upper(identity.assignment), "swrpDatapadBodyBold", width - 26, 42, color_white, TEXT_ALIGN_RIGHT)
        draw.SimpleText("CLEARANCE  //  " .. (LocalPlayer():IsAdmin() and "ADMINISTRATIVE" or "STANDARD"), "swrpDatapadSmall", width - 26, 83, LocalPlayer():IsAdmin() and Color(105, 220, 175) or Color(175, 196, 209), TEXT_ALIGN_RIGHT)
        draw.SimpleText("VESSEL LINK • ACTIVE", "swrpDatapadSmall", width - 26, 108, Color(105, 220, 175), TEXT_ALIGN_RIGHT)
    end

    self.sectionLabel = self.scroll:Add("DLabel")
    self.sectionLabel:Dock(TOP)
    self.sectionLabel:SetTall(25)
    self.sectionLabel:SetFont("swrpDatapadCategory")
    self.sectionLabel:SetText("STATUS OVERVIEW")
    self.sectionLabel:SetTextColor(getAccent())

    self.cards = self.scroll:Add("DIconLayout")
    self.cards:Dock(TOP)
    self.cards:SetTall(126)
    self.cards:SetSpaceX(10)
    self.cards:SetSpaceY(10)
    self.cards:DockMargin(0, 0, 0, 16)

    self.routeCard = self.cards:Add("swrpDatapadStatusCard")
    self.routeCard:SetTall(116)
    self.routeCard:SetAction("Open Navigator", function()
        if IsValid(ix.gui.menu) then
            ix.gui.menu:SelectPage("navigator")
        end
    end)

    self.personnelCard = self.cards:Add("swrpDatapadStatusCard")
    self.personnelCard:SetTall(116)
    self.personnelCard:SetAction("View Roster", function()
        if IsValid(ix.gui.menu) then
            ix.gui.menu:SelectPage("scoreboard")
        end
    end)

    self.assignmentCard = self.cards:Add("swrpDatapadStatusCard")
    self.assignmentCard:SetTall(116)
    self.assignmentCard:SetAction("View Character", function()
        if IsValid(ix.gui.menu) then
            ix.gui.menu:SelectPage("you")
        end
    end)

    self.quickLabel = self.scroll:Add("DLabel")
    self.quickLabel:Dock(TOP)
    self.quickLabel:SetTall(25)
    self.quickLabel:SetFont("swrpDatapadCategory")
    self.quickLabel:SetText("QUICK ACCESS")
    self.quickLabel:SetTextColor(getAccent())

    self.quickActions = self.scroll:Add("DIconLayout")
    self.quickActions:Dock(TOP)
    self.quickActions:SetTall(132)
    self.quickActions:SetSpaceX(10)
    self.quickActions:SetSpaceY(10)

    self:AddQuickAction("NAVIGATOR", "Plot a route through the vessel", "navigator")
    self:AddQuickAction("INVENTORY", "Review issued equipment", "inv")
    self:AddQuickAction("DATABASE", "Commands and system information", "help")
    self:AddQuickAction("SETTINGS", "Interface and gameplay preferences", "settings")

    self.nextRefresh = 0
end

function PANEL:AddQuickAction(title, description, pageKey)
    local button = self.quickActions:Add("DButton")
    button:SetText("")
    button:SetTall(58)
    button.title = title
    button.description = description

    button.Paint = function(current, width, height)
        local accent = getAccent()
        local hovered = current:IsHovered()
        local background = hovered and Color(14, 31, 46, 240) or Color(5, 15, 25, 230)

        draw.RoundedBox(2, 0, 0, width, height, background)
        surface.SetDrawColor(accent.r, accent.g, accent.b, hovered and 145 or 45)
        surface.DrawOutlinedRect(0, 0, width, height)
        surface.DrawRect(0, 0, 3, height)

        draw.SimpleText(current.title, "swrpDatapadBodyBold", 14, 12, color_white)
        draw.SimpleText(current.description, "swrpDatapadSmall", 14, 37, Color(135, 157, 174))
        draw.SimpleText("›", "swrpDatapadPageTitle", width - 16, height * 0.5 - 1, hovered and color_white or alphaColor(accent, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    button.DoClick = function()
        if IsValid(ix.gui.menu) then
            ix.gui.menu:SelectPage(pageKey)
        end
    end

    return button
end

function PANEL:PerformLayout(width, height)
    local cardWidth = math.max(math.floor((width - 30) / 3), 180)
    self.routeCard:SetWide(cardWidth)
    self.personnelCard:SetWide(cardWidth)
    self.assignmentCard:SetWide(cardWidth)

    local quickWidth = math.max(math.floor((width - 18) / 2), 250)
    for _, child in ipairs(self.quickActions:GetChildren()) do
        child:SetWide(quickWidth)
    end
end

function PANEL:RefreshData()
    local routeName = "No active route"
    local routeDescription = "NAVCOM awaiting destination"

    if SWRP and SWRP.Navigator and SWRP.Navigator.GetActiveLocation then
        local location = SWRP.Navigator.GetActiveLocation()
        if location then
            routeName = string.upper(location.name or "ACTIVE ROUTE")
            routeDescription = string.upper(location.deck or location.category or "ROUTE ACTIVE")
        end
    end

    self.routeCard:SetCard("NAVCOM ROUTE", routeName, routeDescription)
    self.personnelCard:SetCard("PERSONNEL ONLINE", tostring(#player.GetAll()), "Connected to this vessel")

    local character = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()
    local faction = character and ix.faction.indices[character:GetFaction()] or nil
    local class = character and ix.class.list[character:GetClass()] or nil
    local assignment = class and L(class.name) or (faction and L(faction.name) or "Unassigned")

    self.assignmentCard:SetCard("CURRENT ASSIGNMENT", string.upper(assignment), "Republic personnel record")
end

function PANEL:Think()
    if CurTime() < self.nextRefresh then
        return
    end

    self.nextRefresh = CurTime() + 0.5
    self:RefreshData()
end

vgui.Register("swrpDatapadOverview", PANEL, "DPanel")

-- -------------------------------------------------------------------------
-- Republic Database: guided command library, admin-only technical references
-- and a server staff/about page.
-- -------------------------------------------------------------------------

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

    if line ~= "" then
        lines[#lines + 1] = line
    end

    maxLines = maxLines or #lines
    for index = 1, math.min(#lines, maxLines) do
        draw.SimpleText(lines[index], font, x, y + (index - 1) * lineHeight, colour)
    end

    return math.min(#lines, maxLines) * lineHeight
end

local COMMAND_CATEGORY_ORDER = {
    "roleplay",
    "animation",
    "communication",
    "character",
    "interaction",
    "administration",
    "other"
}

local COMMAND_CATEGORY_INFO = {
    roleplay = {label = "ROLEPLAY COMMANDS", description = "Actions, scene narration and roleplay tools."},
    animation = {label = "ANIMATION COMMANDS", description = "Character poses, falls, gestures and physical actions."},
    communication = {label = "COMMUNICATION", description = "OOC, local, private and long-range communication."},
    character = {label = "CHARACTER", description = "Identity, description, class and character-management commands."},
    interaction = {label = "INTERACTION", description = "Doors, items, inventory and world interaction."},
    administration = {label = "ADMINISTRATION", description = "Staff-only moderation and server-management commands."},
    other = {label = "OTHER COMMANDS", description = "Additional commands registered by the schema and plugins."}
}

local function commandIsAdministrative(command, commandName)
    if not istable(command) then
        return false
    end

    if command.adminOnly or command.superAdminOnly or command.privilege or command.permission then
        return true
    end

    local lower = string.lower(tostring(commandName or ""))
    return string.find(lower, "ban", 1, true)
        or string.find(lower, "kick", 1, true)
        or string.find(lower, "whitelist", 1, true)
        or string.find(lower, "charset", 1, true)
        or string.find(lower, "ply", 1, true) == 1
        or string.find(lower, "admin", 1, true)
end

local function categoriseCommand(commandName, command)
    local lower = string.lower(tostring(commandName or ""))

    if commandIsAdministrative(command, lower) then
        return "administration"
    end

    if string.find(lower, "fallover", 1, true)
    or string.find(lower, "getup", 1, true)
    or string.find(lower, "anim", 1, true)
    or string.find(lower, "gesture", 1, true)
    or lower == "act" then
        return "animation"
    end

    if lower == "me" or lower == "it" or lower == "action" or lower == "roll"
    or string.find(lower, "roll", 1, true)
    or string.find(lower, "event", 1, true) then
        return "roleplay"
    end

    if lower == "ooc" or lower == "looc" or lower == "pm" or lower == "reply"
    or lower == "w" or lower == "y" or lower == "radio" or lower == "request"
    or string.find(lower, "message", 1, true)
    or string.find(lower, "chat", 1, true) then
        return "communication"
    end

    if string.find(lower, "char", 1, true) == 1
    or string.find(lower, "class", 1, true)
    or string.find(lower, "faction", 1, true) then
        return "character"
    end

    if string.find(lower, "door", 1, true)
    or string.find(lower, "item", 1, true)
    or string.find(lower, "inventory", 1, true)
    or string.find(lower, "drop", 1, true)
    or string.find(lower, "give", 1, true) then
        return "interaction"
    end

    return "other"
end

local function commandDisplayName(key, command)
    local name = istable(command) and command.name or nil
    name = isstring(name) and name ~= "" and name or tostring(key or "command")
    return "/" .. name
end

local function commandSyntax(key, command)
    if istable(command) and isstring(command.syntax) and command.syntax ~= "" then
        local syntax = command.syntax
        if string.sub(syntax, 1, 1) ~= "/" then
            syntax = "/" .. syntax
        end
        return syntax
    end

    local output = commandDisplayName(key, command)
    local argumentNames = istable(command) and command.argumentNames or nil
    local arguments = istable(command) and command.arguments or nil

    if istable(arguments) then
        for index, argument in ipairs(arguments) do
            local name = istable(argument) and (argument.name or argument.label) or nil
            name = name or (istable(argumentNames) and argumentNames[index]) or ("argument " .. index)
            local optional = istable(argument) and (argument.optional or argument.bOptional) or false
            output = output .. (optional and " [" or " <") .. tostring(name) .. (optional and "]" or ">")
        end
    end

    return output
end

local function commandDescription(command)
    local description = istable(command) and command.description or nil
    if isstring(description) and description ~= "" then
        return L(description) or description
    end

    return "No description has been supplied for this command."
end

PANEL = {}

function PANEL:Init()
    self.activeCategory = "roleplay"
    self.searchText = ""
    self.commandGroups = {}
    self.categoryButtons = {}

    self.top = self:Add("DPanel")
    self.top:Dock(TOP)
    self.top:SetTall(58)
    self.top:DockMargin(0, 0, 0, 10)
    self.top:DockPadding(12, 10, 12, 10)
    self.top.Paint = function(panel, width, height)
        local accent = getAccent()
        draw.RoundedBox(2, 0, 0, width, height, Color(4, 13, 22, 240))
        surface.SetDrawColor(accent.r, accent.g, accent.b, 45)
        surface.DrawOutlinedRect(0, 0, width, height)
    end

    self.search = self.top:Add("DTextEntry")
    self.search:Dock(FILL)
    self.search:SetPlaceholderText("Search commands by name, syntax or description...")
    self.search.OnValueChange = function(_, value)
        self.searchText = string.lower(string.Trim(value or ""))
        self:RebuildCommands()
    end

    self.sidebar = self:Add("DScrollPanel")
    self.sidebar:Dock(LEFT)
    self.sidebar:SetWide(math.Clamp(ScrW() * 0.16, 220, 300))
    self.sidebar:DockMargin(0, 0, 10, 0)
    self.sidebar:GetCanvas():DockPadding(8, 8, 8, 8)
    self.sidebar.Paint = function(panel, width, height)
        local accent = getAccent()
        draw.RoundedBox(2, 0, 0, width, height, Color(3, 10, 18, 236))
        surface.SetDrawColor(accent.r, accent.g, accent.b, 35)
        surface.DrawOutlinedRect(0, 0, width, height)
    end

    self.results = self:Add("DScrollPanel")
    self.results:Dock(FILL)
    self.results:GetCanvas():DockPadding(8, 8, 8, 8)
    self.results.Paint = function(panel, width, height)
        draw.RoundedBox(2, 0, 0, width, height, Color(2, 8, 15, 224))
        drawCorners(0, 0, width, height, alphaColor(getAccent(), 38), 14, 1)
    end

    self:CollectCommands()
    self:BuildCategories()

    if not self.commandGroups[self.activeCategory] or #self.commandGroups[self.activeCategory] == 0 then
        for _, categoryID in ipairs(COMMAND_CATEGORY_ORDER) do
            if self.commandGroups[categoryID] and #self.commandGroups[categoryID] > 0 then
                self.activeCategory = categoryID
                break
            end
        end
    end

    self:SelectCategory(self.activeCategory)
end

function PANEL:CollectCommands()
    for _, categoryID in ipairs(COMMAND_CATEGORY_ORDER) do
        self.commandGroups[categoryID] = {}
    end

    for key, command in pairs(ix.command and ix.command.list or {}) do
        local categoryID = categoriseCommand(key, command)
        if categoryID ~= "administration" or LocalPlayer():IsAdmin() then
            self.commandGroups[categoryID][#self.commandGroups[categoryID] + 1] = {
                key = key,
                command = command,
                display = commandDisplayName(key, command),
                syntax = commandSyntax(key, command),
                description = commandDescription(command)
            }
        end
    end

    for _, group in pairs(self.commandGroups) do
        table.sort(group, function(a, b)
            return string.lower(a.display) < string.lower(b.display)
        end)
    end
end

function PANEL:BuildCategories()
    self.sidebar:Clear()

    for _, categoryID in ipairs(COMMAND_CATEGORY_ORDER) do
        local group = self.commandGroups[categoryID] or {}
        if #group > 0 then
            local categoryKey = categoryID
            local categoryGroup = group
            local info = COMMAND_CATEGORY_INFO[categoryKey]
            local button = self.sidebar:Add("DButton")
            button:Dock(TOP)
            button:SetTall(68)
            button:DockMargin(0, 0, 0, 7)
            button:SetText("")
            button.categoryID = categoryKey
            button.OnCursorEntered = function()
                SWRP.Datapad.PlaySound("move")
            end
            button.DoClick = function()
                self:SelectCategory(categoryKey)
            end
            button.Paint = function(current, width, height)
                local accent = getAccent()
                local selected = self.activeCategory == categoryKey
                local background = selected and Color(22, 57, 88, 245) or (current:IsHovered() and Color(12, 29, 44, 245) or Color(5, 15, 24, 232))
                draw.RoundedBox(2, 0, 0, width, height, background)
                surface.SetDrawColor(accent.r, accent.g, accent.b, selected and 155 or 38)
                surface.DrawOutlinedRect(0, 0, width, height)
                if selected then
                    surface.DrawRect(0, 0, 4, height)
                end
                draw.SimpleText(info.label, "swrpDatapadBodyBold", 13, 12, color_white)
                draw.SimpleText(#categoryGroup .. " COMMAND" .. (#categoryGroup == 1 and "" or "S"), "swrpDatapadSmall", 13, 39, selected and alphaColor(accent, 235) or Color(130, 154, 171))
            end

            self.categoryButtons[categoryKey] = button
        end
    end
end

function PANEL:SelectCategory(categoryID)
    self.activeCategory = categoryID
    for id, button in pairs(self.categoryButtons) do
        if IsValid(button) then
            button:SetEnabled(true)
        end
    end
    self:RebuildCommands()
end

function PANEL:RebuildCommands()
    self.results:Clear()

    local info = COMMAND_CATEGORY_INFO[self.activeCategory] or COMMAND_CATEGORY_INFO.other
    local header = self.results:Add("DPanel")
    header:Dock(TOP)
    header:SetTall(78)
    header:DockMargin(0, 0, 0, 10)
    header.Paint = function(panel, width, height)
        local accent = getAccent()
        draw.RoundedBox(2, 0, 0, width, height, Color(4, 14, 23, 240))
        surface.SetDrawColor(accent.r, accent.g, accent.b, 48)
        surface.DrawOutlinedRect(0, 0, width, height)
        draw.SimpleText(info.label, "swrpDatapadPageTitle", 17, 12, color_white)
        draw.SimpleText(info.description, "swrpDatapadSmall", 18, 50, Color(140, 164, 180))
    end

    local visible = 0
    for _, entry in ipairs(self.commandGroups[self.activeCategory] or {}) do
        local haystack = string.lower(entry.display .. " " .. entry.syntax .. " " .. entry.description)
        local matches = self.searchText == "" or string.find(haystack, self.searchText, 1, true)
        if matches then
            visible = visible + 1
            local commandEntry = entry
            local card = self.results:Add("DPanel")
            card:Dock(TOP)
            card:SetTall(104)
            card:DockMargin(0, 0, 0, 8)
            card.Paint = function(panel, width, height)
                local accent = getAccent()
                draw.RoundedBox(2, 0, 0, width, height, Color(5, 15, 25, 238))
                surface.SetDrawColor(accent.r, accent.g, accent.b, 40)
                surface.DrawOutlinedRect(0, 0, width, height)
                surface.DrawRect(0, 0, 4, height)
                draw.SimpleText(string.upper(commandEntry.display), "swrpDatapadBodyBold", 17, 12, alphaColor(accent, 240))
                draw.SimpleText(commandEntry.syntax, "swrpDatapadSmall", 17, 38, color_white)
                drawWrappedText(commandEntry.description, "swrpDatapadBody", 17, 61, width - 34, Color(171, 192, 205), 18, 2)
            end
        end
    end

    if visible == 0 then
        local empty = self.results:Add("DPanel")
        empty:Dock(TOP)
        empty:SetTall(180)
        empty.Paint = function(panel, width, height)
            draw.SimpleText("NO MATCHING COMMANDS", "swrpDatapadPageTitle", width * 0.5, height * 0.42, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("Change the category or search terms.", "swrpDatapadBody", width * 0.5, height * 0.62, Color(140, 164, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

vgui.Register("swrpDatapadCommandLibrary", PANEL, "DPanel")

local function formatLastOnline(timestamp, online)
    if online then
        return "ONLINE NOW"
    end

    timestamp = tonumber(timestamp) or 0
    if timestamp <= 0 then
        return "LAST ONLINE UNKNOWN"
    end

    local elapsed = math.max(os.time() - timestamp, 0)
    if elapsed < 60 then
        return "LAST ONLINE MOMENTS AGO"
    elseif elapsed < 3600 then
        return "LAST ONLINE " .. math.floor(elapsed / 60) .. " MIN AGO"
    elseif elapsed < 86400 then
        return "LAST ONLINE " .. math.floor(elapsed / 3600) .. " H AGO"
    elseif elapsed < 604800 then
        return "LAST ONLINE " .. math.floor(elapsed / 86400) .. " D AGO"
    end

    return "LAST ONLINE " .. os.date("%d %b %Y", timestamp)
end

PANEL = {}

function PANEL:Init()
    self.hero = self:Add("DPanel")
    self.hero:Dock(TOP)
    self.hero:SetTall(196)
    self.hero:DockMargin(0, 0, 0, 12)
    self.hero.Paint = function(panel, width, height)
        local accent = getAccent()
        draw.RoundedBox(2, 0, 0, width, height, Color(4, 13, 22, 244))
        drawCorners(0, 0, width, height, alphaColor(accent, 80), 18, 1)
        drawScanlines(0, 0, width, height, 3)
        surface.SetDrawColor(accent.r, accent.g, accent.b, 18)
        surface.DrawRect(width * 0.61, 0, width * 0.39, height)

        draw.SimpleText("GALACTIC ROLEPLAY", "swrpDatapadPageTitle", 30, 28, color_white)
        draw.SimpleText("REPUBLIC PERSONNEL AND OPERATIONS NETWORK", "swrpDatapadCategory", 31, 69, alphaColor(accent, 230))
        drawWrappedText("A custom Clone Wars roleplay experience built around meaningful service records, progression and organised operations.", "swrpDatapadBody", 31, 103, width * 0.52, Color(183, 203, 216), 22, 3)

        draw.SimpleText("SCHEMA LEAD", "swrpDatapadCategory", width - 31, 37, Color(122, 147, 165), TEXT_ALIGN_RIGHT)
        draw.SimpleText("SAM", "swrpDatapadPageTitle", width - 31, 61, color_white, TEXT_ALIGN_RIGHT)
        draw.SimpleText("DATAPAD  •  NAVCOM  •  SERVER SYSTEMS", "swrpDatapadSmall", width - 31, 105, alphaColor(accent, 220), TEXT_ALIGN_RIGHT)
        draw.SimpleText(GetGlobalString("swrpDatapadServerDate", "SERVER DATE UNAVAILABLE"), "swrpDatapadSmall", width - 31, height - 28, Color(105, 220, 175), TEXT_ALIGN_RIGHT)
    end

    self.staffHeader = self:Add("DPanel")
    self.staffHeader:Dock(TOP)
    self.staffHeader:SetTall(58)
    self.staffHeader:DockMargin(0, 0, 0, 8)
    self.staffHeader.Paint = function(panel, width, height)
        local accent = getAccent()
        draw.RoundedBox(2, 0, 0, width, height, Color(3, 11, 19, 240))
        surface.SetDrawColor(accent.r, accent.g, accent.b, 42)
        surface.DrawOutlinedRect(0, 0, width, height)
        draw.SimpleText("SERVER STAFF", "swrpDatapadBodyBold", 17, 11, color_white)
        draw.SimpleText("Online status and most recent recorded activity", "swrpDatapadSmall", 17, 34, Color(135, 159, 176))
    end

    self.staffScroll = self:Add("DScrollPanel")
    self.staffScroll:Dock(FILL)
    self.staffScroll:GetCanvas():DockPadding(0, 0, 8, 8)

    hook.Add("SWRPDatapadStaffRosterUpdated", self, function(panel)
        if IsValid(panel) then
            panel:RebuildStaff()
        end
    end)

    self:RebuildStaff()
    if SWRP.Datapad.RequestStaffRoster then
        SWRP.Datapad.RequestStaffRoster()
    end
end

function PANEL:RebuildStaff()
    if not IsValid(self.staffScroll) then
        return
    end

    self.staffScroll:Clear()
    local records = SWRP.Datapad.StaffRoster or {}

    if #records == 0 then
        local empty = self.staffScroll:Add("DPanel")
        empty:Dock(TOP)
        empty:SetTall(150)
        empty.Paint = function(panel, width, height)
            draw.SimpleText("STAFF DIRECTORY AWAITING DATA", "swrpDatapadPageTitle", width * 0.5, height * 0.42, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("Records appear after administrators connect to the server.", "swrpDatapadBody", width * 0.5, height * 0.63, Color(140, 164, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        return
    end

    for _, record in ipairs(records) do
        local staffRecord = record
        local card = self.staffScroll:Add("DPanel")
        card:Dock(TOP)
        card:SetTall(86)
        card:DockMargin(0, 0, 0, 8)
        card.Paint = function(panel, width, height)
            local accent = getAccent()
            draw.RoundedBox(2, 0, 0, width, height, Color(5, 15, 25, 240))
            surface.SetDrawColor(accent.r, accent.g, accent.b, staffRecord.online and 90 or 35)
            surface.DrawOutlinedRect(0, 0, width, height)
            surface.DrawRect(0, 0, 4, height)
            draw.SimpleText(string.upper(staffRecord.name or "UNKNOWN STAFF"), "swrpDatapadBodyBold", 82, 14, color_white)
            draw.SimpleText(string.upper(tostring(staffRecord.usergroup or "ADMIN")), "swrpDatapadSmall", 82, 40, alphaColor(accent, 225))
            draw.SimpleText(formatLastOnline(staffRecord.lastOnline, staffRecord.online), "swrpDatapadSmall", width - 18, height * 0.5, staffRecord.online and Color(105, 220, 175) or Color(132, 155, 171), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        local avatar = card:Add("AvatarImage")
        avatar:SetSize(58, 58)
        avatar:SetPos(12, 14)
        avatar:SetSteamID(tostring(staffRecord.steamID64 or "0"), 64)
    end
end

vgui.Register("swrpDatapadAboutPage", PANEL, "DPanel")

PANEL = {}

function PANEL:Init()
    self.categoryPanels = {}
    self.categoryButtons = {}
    self.helpCategories = {}

    local populated = {}
    hook.Run("PopulateHelpMenu", populated)
    for key, populate in pairs(populated) do
        self.helpCategories[string.lower(tostring(key))] = populate
    end

    self.toolbar = self:Add("DPanel")
    self.toolbar:Dock(TOP)
    self.toolbar:SetTall(48)
    self.toolbar:DockMargin(0, 0, 0, 10)
    self.toolbar.Paint = function(panel, width, height)
        draw.RoundedBox(2, 0, 0, width, height, Color(4, 13, 22, 230))
        surface.SetDrawColor(90, 155, 205, 45)
        surface.DrawOutlinedRect(0, 0, width, height)
    end

    self.content = self:Add("DPanel")
    self.content:Dock(FILL)
    self.content.Paint = nil

    self:AddCategory("commands", "COMMAND DIRECTORY")
    self:AddCategory("about", "ABOUT & STAFF")

    if LocalPlayer():IsAdmin() then
        if isfunction(self.helpCategories.flags) then
            self:AddCategory("flags", "FLAGS  •  ADMIN")
        end
        if isfunction(self.helpCategories.plugins) then
            self:AddCategory("plugins", "PLUGINS  •  ADMIN")
        end
    end

    self:SelectCategory("commands")
end

function PANEL:AddCategory(key, label)
    local button = self.toolbar:Add("swrpDatapadSegmentButton")
    button:Dock(LEFT)
    button:SetWide(key == "commands" and 190 or (key == "about" and 170 or 175))
    button:DockMargin(6, 6, 0, 6)
    button:SetLabel(label)
    button.DoClick = function()
        self:SelectCategory(key)
    end
    self.categoryButtons[key] = button
end

function PANEL:CreateCategoryPanel(key)
    local panel = self.content:Add("DPanel")
    panel:Dock(FILL)
    panel:SetVisible(false)
    panel.Paint = nil

    if key == "commands" then
        local library = panel:Add("swrpDatapadCommandLibrary")
        library:Dock(FILL)
    elseif key == "about" then
        local about = panel:Add("swrpDatapadAboutPage")
        about:Dock(FILL)
    elseif key == "flags" or key == "plugins" then
        if not LocalPlayer():IsAdmin() then
            panel:Remove()
            return nil
        end

        local banner = panel:Add("DPanel")
        banner:Dock(TOP)
        banner:SetTall(62)
        banner:DockMargin(0, 0, 0, 8)
        banner.Paint = function(current, width, height)
            local accent = getAccent()
            draw.RoundedBox(2, 0, 0, width, height, Color(27, 20, 8, 242))
            surface.SetDrawColor(218, 162, 91, 90)
            surface.DrawOutlinedRect(0, 0, width, height)
            draw.SimpleText("ADMINISTRATOR REFERENCE", "swrpDatapadBodyBold", 17, 11, Color(235, 190, 112))
            draw.SimpleText("This technical information is hidden from regular players.", "swrpDatapadSmall", 17, 36, Color(185, 166, 127))
        end

        local scroll = panel:Add("DScrollPanel")
        scroll:Dock(FILL)
        scroll:GetCanvas():DockPadding(12, 12, 12, 12)
        scroll.Paint = function(current, width, height)
            draw.RoundedBox(2, 0, 0, width, height, Color(3, 10, 18, 224))
            drawCorners(0, 0, width, height, alphaColor(getAccent(), 40), 14, 1)
        end
        scroll.DisableScrolling = function(current)
            current:GetCanvas():SetVisible(false)
            current:GetVBar():SetVisible(false)
            current.OnChildAdded = function() end
        end

        local populate = self.helpCategories[key]
        if isfunction(populate) then
            populate(scroll)
        end
    end

    self.categoryPanels[key] = panel
    return panel
end

function PANEL:SelectCategory(key)
    if (key == "flags" or key == "plugins") and not LocalPlayer():IsAdmin() then
        return
    end

    local panel = self.categoryPanels[key] or self:CreateCategoryPanel(key)
    if not IsValid(panel) then
        return
    end

    if IsValid(self.activePanel) then
        self.activePanel:SetVisible(false)
    end

    for categoryKey, button in pairs(self.categoryButtons) do
        if IsValid(button) then
            button:SetSelected(categoryKey == key)
        end
    end

    panel:SetVisible(true)
    panel:InvalidateLayout(true)
    self.activePanel = panel
    self.activeCategory = key
end

vgui.Register("swrpDatapadDatabase", PANEL, "DPanel")

-- -------------------------------------------------------------------------
-- Settings page - nests Helix's server config behind an admin-only tab.
-- -------------------------------------------------------------------------

PANEL = {}

function PANEL:Init()
    self.info = nil
    self.configInfo = nil
    self.activeSection = nil
    self.sectionPanels = {}
    self.sectionButtons = {}

    self.toolbar = self:Add("DPanel")
    self.toolbar:Dock(TOP)
    self.toolbar:SetTall(48)
    self.toolbar:DockMargin(0, 0, 0, 10)
    self.toolbar.Paint = function(panel, width, height)
        draw.RoundedBox(2, 0, 0, width, height, Color(4, 13, 22, 230))
        surface.SetDrawColor(90, 155, 205, 45)
        surface.DrawOutlinedRect(0, 0, width, height)
    end

    self.content = self:Add("DPanel")
    self.content:Dock(FILL)
    self.content.Paint = nil
end

function PANEL:SetSourceInfo(settingsInfo, configInfo)
    self.info = settingsInfo
    self.configInfo = configInfo

    self:AddSection("personal", "PERSONAL")

    if LocalPlayer():IsAdmin() then
        self:AddSection("administration", "ADMINISTRATION", "ADMIN")
    end

    self:SelectSection("personal")
end

function PANEL:AddSection(key, label, badge)
    local button = self.toolbar:Add("swrpDatapadSegmentButton")
    button:Dock(LEFT)
    button:SetWide(key == "administration" and 200 or 150)
    button:DockMargin(6, 6, 0, 6)
    button:SetLabel(label .. (badge and "  •  " .. badge or ""))
    button.DoClick = function()
        self:SelectSection(key)
    end

    self.sectionButtons[key] = button
end

function PANEL:CreateSection(key)
    local panel = self.content:Add("DPanel")
    panel:Dock(FILL)
    panel:SetVisible(false)
    panel.Paint = function(current, width, height)
        draw.RoundedBox(2, 0, 0, width, height, Color(3, 10, 18, 210))
        drawCorners(0, 0, width, height, alphaColor(getAccent(), 35), 13, 1)
    end
    panel:DockPadding(10, 10, 10, 10)

    if key == "personal" then
        self:PopulateFromInfo(panel, self.info, "settings")
    elseif key == "administration" then
        if not LocalPlayer():IsAdmin() then
            panel:Remove()
            return nil
        end

        self:BuildAdministrationPanel(panel)
    end

    self.sectionPanels[key] = panel
    return panel
end

function PANEL:BuildAdministrationPanel(container)
    container.adminPanels = {}
    container.adminButtons = {}

    local toolbar = container:Add("DPanel")
    toolbar:Dock(TOP)
    toolbar:SetTall(44)
    toolbar:DockMargin(0, 0, 0, 8)
    toolbar.Paint = function(panel, width, height)
        draw.RoundedBox(2, 0, 0, width, height, Color(4, 13, 22, 232))
        surface.SetDrawColor(90, 155, 205, 42)
        surface.DrawOutlinedRect(0, 0, width, height)
    end

    local content = container:Add("DPanel")
    content:Dock(FILL)
    content.Paint = nil

    local function selectAdminPage(pageKey)
        if IsValid(container.activeAdminPanel) then
            container.activeAdminPanel:SetVisible(false)
        end

        local target = container.adminPanels[pageKey]
        if not IsValid(target) then
            return
        end

        for key, button in pairs(container.adminButtons) do
            if IsValid(button) then
                button:SetSelected(key == pageKey)
            end
        end

        target:SetVisible(true)
        target:InvalidateLayout(true)
        container.activeAdminPanel = target
        container.activeAdminKey = pageKey
    end

    local function addAdminPage(pageKey, label, className)
        local button = toolbar:Add("swrpDatapadSegmentButton")
        button:Dock(LEFT)
        button:SetWide(pageKey == "plugins" and 155 or 190)
        button:DockMargin(6, 5, 0, 5)
        button:SetLabel(label)
        button.DoClick = function()
            selectAdminPage(pageKey)
        end
        container.adminButtons[pageKey] = button

        local host = content:Add("DPanel")
        host:Dock(FILL)
        host:SetVisible(false)
        host:DockPadding(6, 6, 6, 6)
        host.Paint = function(panel, width, height)
            draw.RoundedBox(2, 0, 0, width, height, Color(2, 8, 15, 205))
        end

        local controlTable = vgui.GetControlTable and vgui.GetControlTable(className) or nil
        if controlTable then
            local manager = host:Add(className)
            manager:Dock(FILL)
            host.manager = manager
        else
            local title = host:Add("DLabel")
            title:Dock(TOP)
            title:SetTall(44)
            title:SetFont("swrpDatapadPageTitle")
            title:SetText("ADMINISTRATION MODULE UNAVAILABLE")
            title:SetTextColor(color_white)

            local description = host:Add("DLabel")
            description:Dock(TOP)
            description:SetTall(70)
            description:SetFont("swrpDatapadBody")
            description:SetWrap(true)
            description:SetText("The Helix control '" .. className .. "' has not been registered on this client.")
            description:SetTextColor(Color(155, 178, 194))
        end

        container.adminPanels[pageKey] = host
    end

    addAdminPage("configuration", "SERVER CONFIGURATION", "ixConfigManager")
    addAdminPage("plugins", "PLUGINS", "ixPluginManager")
    selectAdminPage("configuration")
end

function PANEL:PopulateFromInfo(container, info, sourceKey)
    if not info then
        local label = container:Add("DLabel")
        label:Dock(FILL)
        label:SetContentAlignment(5)
        label:SetFont("swrpDatapadBody")
        label:SetText("This module is not currently available.")
        label:SetTextColor(Color(155, 178, 194))
        return
    end

    if istable(info) and isfunction(info.Create) then
        info:Create(container)
    elseif isfunction(info) then
        info(container)
    end

    hook.Run("MenuSubpanelCreated", sourceKey, container)
    container.swrpSourceInfo = info
end

function PANEL:SelectSection(key)
    if key == "administration" and not LocalPlayer():IsAdmin() then
        return
    end

    local oldKey = self.activeSection
    local oldPanel = oldKey and self.sectionPanels[oldKey] or nil
    local oldInfo = oldKey == "personal" and self.info or nil

    if IsValid(oldPanel) then
        if istable(oldInfo) and isfunction(oldInfo.OnDeselected) then
            oldInfo:OnDeselected(oldPanel)
        end
        oldPanel:SetVisible(false)
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
    self.activeSection = key

    local info = key == "personal" and self.info or nil
    if istable(info) and isfunction(info.OnSelected) then
        info:OnSelected(panel)
    end
end

function PANEL:OnMenuDeselected()
    local panel = self.activeSection and self.sectionPanels[self.activeSection] or nil
    local info = self.activeSection == "personal" and self.info or nil

    if IsValid(panel) and istable(info) and isfunction(info.OnDeselected) then
        info:OnDeselected(panel)
    end
end

function PANEL:OnMenuSelected()
    local panel = self.activeSection and self.sectionPanels[self.activeSection] or nil
    local info = self.activeSection == "personal" and self.info or nil

    if IsValid(panel) and istable(info) and isfunction(info.OnSelected) then
        info:OnSelected(panel)
    end
end

vgui.Register("swrpDatapadSettings", PANEL, "DPanel")

-- -------------------------------------------------------------------------
-- Main ixMenu replacement
-- -------------------------------------------------------------------------

DEFINE_BASECLASS("EditablePanel")
PANEL = {}

AccessorFunc(PANEL, "bCharacterOverview", "CharacterOverview", FORCE_BOOL)

function PANEL:Init()
    if IsValid(ix.gui.menu) then
        ix.gui.menu:Remove()
    end

    ix.gui.menu = self

    self.manualChildren = {}
    self.pages = {}
    self.pageOrder = {}
    self.navButtons = {}
    self.rawTabs = {}
    self.currentPageKey = nil
    self.currentAlpha = 0
    self.currentBlur = 1
    self.noAnchor = CurTime() + 0.4
    self.anchorMode = true
    self.bClosing = false

    self.rotationOffset = Angle(0, 180, 0)
    self.projectedTexturePosition = Vector(0, 0, 6)
    self.projectedTextureRotation = Angle(-45, 60, 0)
    self.bCharacterOverview = false
    self.bOverviewOut = false
    self.overviewFraction = 0

    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:SetAlpha(0)

    self:BuildShell()
    self:InvalidateLayout(true)
    if IsValid(self.frame) then
        self.frame:InvalidateLayout(true)
    end
    if IsValid(self.body) then
        self.body:InvalidateLayout(true)
    end
    if IsValid(self.contentShell) then
        self.contentShell:InvalidateLayout(true)
    end

    self:CollectTabs()
    self:BuildNavigation()

    self:MakePopup()
    self:OnOpened()
end

function PANEL:BuildShell()
    local marginX = math.Clamp(ScrW() * 0.025, 24, 52)
    local marginY = math.Clamp(ScrH() * 0.038, 24, 44)

    self.frame = self:Add("DPanel")
    self.frame:SetPos(marginX, marginY)
    self.frame:SetSize(ScrW() - marginX * 2, ScrH() - marginY * 2)
    self.frame:DockPadding(1, 1, 1, 1)
    self.frame.Paint = function(panel, width, height)
        local accent = getAccent()
        draw.RoundedBox(2, 0, 0, width, height, Color(1, 6, 12, 242))
        surface.SetDrawColor(accent.r, accent.g, accent.b, 55)
        surface.DrawOutlinedRect(0, 0, width, height)
        drawCorners(0, 0, width, height, alphaColor(accent, 125), 18, 2)
    end

    self.header = self.frame:Add("DPanel")
    self.header:Dock(TOP)
    self.header:SetTall(math.Clamp(ScrH() * 0.072, 58, 78))
    self.header.Paint = function(panel, width, height)
        local accent = getAccent()
        draw.RoundedBox(1, 0, 0, width, height, Color(3, 11, 19, 249))
        surface.SetDrawColor(accent.r, accent.g, accent.b, 55)
        surface.DrawRect(0, height - 1, width, 1)
        drawScanlines(0, 0, width, height, 3)

        draw.SimpleText("REPUBLIC PERSONNEL DATAPAD", "swrpDatapadTitle", 22, 14, color_white)
        draw.SimpleText("VENATOR-CLASS PERSONNEL AND OPERATIONS TERMINAL", "swrpDatapadSubTitle", 23, height - 19, accent)

        draw.SimpleText("VESSEL LINK  •  ACTIVE", "swrpDatapadSubTitle", width - 22, 15, Color(105, 220, 175), TEXT_ALIGN_RIGHT)
        draw.SimpleText(string.upper(game.GetMap()) .. "  •  " .. formatShipTime(), "swrpDatapadSmall", width - 22, height - 19, Color(116, 145, 164), TEXT_ALIGN_RIGHT)
    end

    self.footer = self.frame:Add("DPanel")
    self.footer:Dock(BOTTOM)
    self.footer:SetTall(math.Clamp(ScrH() * 0.054, 48, 60))
    self.footer.Paint = function(panel, width, height)
        local accent = getAccent()
        draw.RoundedBox(1, 0, 0, width, height, Color(3, 10, 17, 249))
        surface.SetDrawColor(accent.r, accent.g, accent.b, 45)
        surface.DrawRect(0, 0, width, 1)

        draw.SimpleText("TAB  CLOSE DATAPAD", "swrpDatapadSmall", width - 18, height * 0.5, Color(105, 132, 150), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    self.changeCharacter = self.footer:Add("DButton")
    self.changeCharacter:Dock(LEFT)
    self.changeCharacter:SetWide(190)
    self.changeCharacter:DockMargin(10, 8, 0, 8)
    self.changeCharacter:SetText("")
    self.changeCharacter.Paint = function(button, width, height)
        local accent = getAccent()
        local hovered = button:IsHovered()
        if hovered then
            draw.RoundedBox(2, 0, 0, width, height, alphaColor(accent, 38))
        end
        draw.SimpleText("CHANGE CHARACTER", "swrpDatapadSubTitle", 12, height * 0.5, hovered and color_white or Color(168, 187, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    self.changeCharacter.OnCursorEntered = function() SWRP.Datapad.PlaySound("move") end
    self.changeCharacter.DoClick = function()
        SWRP.Datapad.PlaySound("back")
        self:Remove()
        vgui.Create("ixCharMenu")
    end

    self.returnButton = self.footer:Add("DButton")
    self.returnButton:Dock(LEFT)
    self.returnButton:SetWide(160)
    self.returnButton:DockMargin(4, 8, 0, 8)
    self.returnButton:SetText("")
    self.returnButton.Paint = function(button, width, height)
        local accent = getAccent()
        local hovered = button:IsHovered()
        if hovered then
            draw.RoundedBox(2, 0, 0, width, height, alphaColor(accent, 38))
        end
        draw.SimpleText("RETURN TO GAME", "swrpDatapadSubTitle", 12, height * 0.5, hovered and color_white or Color(168, 187, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    self.returnButton.OnCursorEntered = function() SWRP.Datapad.PlaySound("move") end
    self.returnButton.DoClick = function()
        SWRP.Datapad.PlaySound("back")
        self:Remove()
    end

    self.body = self.frame:Add("DPanel")
    self.body:Dock(FILL)
    self.body.Paint = nil

    self.sidebar = self.body:Add("DPanel")
    self.sidebar:Dock(LEFT)
    self.sidebar:SetWide(math.Clamp(ScrW() * 0.17, 238, 322))
    self.sidebar:DockPadding(10, 12, 10, 12)
    self.sidebar.Paint = function(panel, width, height)
        local accent = getAccent()
        draw.RoundedBox(1, 0, 0, width, height, Color(3, 10, 17, 246))
        surface.SetDrawColor(accent.r, accent.g, accent.b, 35)
        surface.DrawRect(width - 1, 0, 1, height)
        drawScanlines(0, 0, width, height, 2)
    end

    self.sidebarIdentity = self.sidebar:Add("swrpDatapadIdentityMini")
    self.sidebarIdentity:Dock(TOP)
    self.sidebarIdentity:DockMargin(0, 0, 0, 8)

    self.navScroll = self.sidebar:Add("DScrollPanel")
    self.navScroll:Dock(FILL)
    self.navScroll:GetVBar():SetWide(3)

    self.contentShell = self.body:Add("DPanel")
    self.contentShell:Dock(FILL)
    self.contentShell:DockPadding(14, 12, 14, 14)
    self.contentShell.Paint = function(panel, width, height)
        local accent = getAccent()
        local definitionPage = self.currentPageKey and self.pages[self.currentPageKey] or nil
        local info = definitionPage and definitionPage.info or nil
        local hideBackground = shouldHideBackground(definitionPage and definitionPage.key or nil, info)
        local backgroundAlpha = hideBackground and 38 or 238

        draw.RoundedBox(1, 0, 0, width, height, Color(2, 8, 15, backgroundAlpha))
        if not hideBackground then
            drawScanlines(0, 0, width, height, 2)
        end
        surface.SetDrawColor(accent.r, accent.g, accent.b, hideBackground and 35 or 18)
        surface.DrawOutlinedRect(0, 0, width, height)
    end

    self.pageHeader = self.contentShell:Add("DPanel")
    self.pageHeader:Dock(TOP)
    self.pageHeader:SetTall(math.Clamp(ScrH() * 0.071, 62, 78))
    self.pageHeader:DockMargin(0, 0, 0, 10)
    self.pageHeader.Paint = function(panel, width, height)
        local accent = getAccent()
        local definition = self:GetCurrentDefinition()
        local title = definition and definition.label or "Republic Datapad"
        local subtitle = definition and definition.subtitle or "Personnel and operations interface"

        draw.RoundedBox(2, 0, 0, width, height, Color(4, 13, 22, 240))
        surface.SetDrawColor(accent.r, accent.g, accent.b, 46)
        surface.DrawOutlinedRect(0, 0, width, height)
        surface.DrawRect(0, 0, 4, height)

        draw.SimpleText(string.upper(title), "swrpDatapadPageTitle", 20, 12, color_white)
        draw.SimpleText(subtitle, "swrpDatapadSmall", 21, height - 17, Color(132, 158, 177))

        if self.currentPageKey == "settings" and LocalPlayer():IsAdmin() then
            local badge = "ADMIN ACCESS"
            surface.SetFont("swrpDatapadSmall")
            local textWidth = surface.GetTextSize(badge)
            local badgeWidth = textWidth + 18
            local badgeHeight = 24
            local x = width - badgeWidth - 16
            local y = 14
            draw.RoundedBox(2, x, y, badgeWidth, badgeHeight, Color(40, 105, 85, 90))
            surface.SetDrawColor(105, 220, 175, 145)
            surface.DrawOutlinedRect(x, y, badgeWidth, badgeHeight)
            draw.SimpleText(badge, "swrpDatapadSmall", x + badgeWidth * 0.5, y + badgeHeight * 0.5, Color(150, 240, 205), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    self.pageContainer = self.contentShell:Add("DPanel")
    self.pageContainer:Dock(FILL)
    self.pageContainer.Paint = nil
end

function PANEL:CollectTabs()
    local tabs = {}
    hook.Run("CreateMenuButtons", tabs)
    self.rawTabs = tabs

    self.configInfo = tabs.config

    -- Some schemas rename the config key. Detect the common alternatives but
    -- never expose them as a normal navigation page.
    if not self.configInfo then
        for key, info in pairs(tabs) do
            local lowerKey = string.lower(tostring(key))
            if lowerKey == "configuration" or lowerKey == "adminconfig" or lowerKey == "admin_config" then
                self.configInfo = info
                HIDDEN_TABS[key] = true
                break
            end
        end
    end
end

function PANEL:BuildNavigation()
    local categorized = {}
    for _, category in ipairs(CATEGORY_ORDER) do
        categorized[category] = {}
    end

    for key, info in pairs(self.rawTabs) do
        if not HIDDEN_TABS[key] then
            local definition = table.Copy(PAGE_DEFINITIONS[key] or {
                label = humaniseKey(key),
                category = "ADDITIONAL SYSTEMS",
                subtitle = "Installed datapad module",
                order = 100
            })

            definition.key = key
            definition.info = info
            categorized[definition.category] = categorized[definition.category] or {}
            table.insert(categorized[definition.category], definition)
        end
    end

    -- Settings is special because it combines user options and admin config.
    if self.rawTabs.settings then
        for _, definition in ipairs(categorized.SYSTEM or {}) do
            if definition.key == "settings" then
                definition.info = self.rawTabs.settings
                definition.configInfo = self.configInfo
            end
        end
    end

    for _, category in ipairs(CATEGORY_ORDER) do
        local entries = categorized[category]
        if entries and #entries > 0 then
            table.sort(entries, function(a, b)
                if (a.order or 100) == (b.order or 100) then
                    return a.label < b.label
                end
                return (a.order or 100) < (b.order or 100)
            end)

            self:AddCategoryLabel(category)
            for _, definition in ipairs(entries) do
                self:AddNavButton(definition.key, definition)
            end
        end
    end

    local initialPage = "you"
    if isstring(ix.gui.lastMenuTab) and self.navButtons[ix.gui.lastMenuTab] then
        initialPage = ix.gui.lastMenuTab
    end

    self:SelectPage(initialPage, true)
end

function PANEL:AddCategoryLabel(text)
    local label = self.navScroll:Add("DLabel")
    label:Dock(TOP)
    label:SetTall(30)
    label:DockMargin(8, 9, 6, 1)
    label:SetFont("swrpDatapadCategory")
    label:SetText(text)
    label:SetTextColor(alphaColor(getAccent(), 205))
end

function PANEL:AddNavButton(key, definition)
    local button = self.navScroll:Add("swrpDatapadNavButton")
    button:Dock(TOP)
    button:DockMargin(0, 0, 3, 3)
    button:SetLabel(definition.label)

    if key == "settings" and LocalPlayer():IsAdmin() then
        button:SetBadge("ADMIN")
    end

    button.DoClick = function()
        self:SelectPage(key)
    end

    self.navButtons[key] = button
    self.pageOrder[#self.pageOrder + 1] = key
    self.pages[key] = {
        key = key,
        definition = definition,
        info = definition.info,
        panel = nil,
        populated = false
    }
end

function PANEL:GetCurrentDefinition()
    local page = self.currentPageKey and self.pages[self.currentPageKey] or nil
    return page and page.definition or nil
end

function PANEL:CreatePage(page)
    local container = self.pageContainer:Add("DPanel")
    container:SetSize(self:GetStandardSubpanelSize())
    container:Dock(FILL)
    container:SetVisible(false)
    container:SetAlpha(255)
    container.Paint = function(panel, width, height)
        local info = page.info
        local hideBackground = shouldHideBackground(page.key, info)

        if not hideBackground and page.key ~= "navigator" then
            draw.RoundedBox(2, 0, 0, width, height, Color(2, 8, 15, 145))
        end
    end

    page.panel = container

    if page.key == "overview" then
        local overview = container:Add("swrpDatapadOverview")
        overview:Dock(FILL)
        page.populated = true
    elseif page.key == "you" then
        local characterPanel = container:Add("swrpDatapadCharacter")
        characterPanel:Dock(FILL)
        page.characterPanel = characterPanel
        page.populated = true
        hook.Run("MenuSubpanelCreated", page.key, container)
    elseif page.key == "inv" then
        local inventoryPanel = container:Add("swrpDatapadInventory")
        inventoryPanel:Dock(FILL)
        inventoryPanel:SetSourceInfo(page.info)
        page.inventoryPanel = inventoryPanel
        page.populated = true
        hook.Run("MenuSubpanelCreated", page.key, container)
    elseif page.key == "scoreboard" then
        local roster = container:Add("swrpDatapadRoster")
        roster:Dock(FILL)
        page.rosterPanel = roster
        page.populated = true
        hook.Run("MenuSubpanelCreated", page.key, container)
    elseif page.key == "settings" then
        local settings = container:Add("swrpDatapadSettings")
        settings:Dock(FILL)
        settings:SetSourceInfo(page.info, page.definition.configInfo or self.configInfo)
        page.settingsPanel = settings
        page.populated = true
        hook.Run("MenuSubpanelCreated", page.key, container)
    elseif page.key == "help" then
        local database = container:Add("swrpDatapadDatabase")
        database:Dock(FILL)
        page.populated = true
        hook.Run("MenuSubpanelCreated", page.key, container)
    else
        self:PopulatePage(page)
    end

    return container
end

function PANEL:PopulatePage(page)
    if page.populated then
        return
    end

    local container = page.panel
    local info = page.info

    if istable(info) and isfunction(info.Create) then
        info:Create(container)
    elseif isfunction(info) then
        info(container)
    end

    hook.Run("MenuSubpanelCreated", page.key, container)
    page.populated = true
end

function PANEL:SelectPage(key, instant)
    if key == "overview" then
        key = "you"
    end

    local page = self.pages[key]
    if not page then
        return
    end

    if self.currentPageKey == key and IsValid(page.panel) then
        return
    end

    local previous = self.currentPageKey and self.pages[self.currentPageKey] or nil

    if previous and IsValid(previous.panel) then
        if previous.key == "settings" and IsValid(previous.settingsPanel) then
            previous.settingsPanel:OnMenuDeselected()
        elseif previous.key == "you" and IsValid(previous.characterPanel) then
            previous.characterPanel:OnMenuDeselected()
        elseif istable(previous.info) and isfunction(previous.info.OnDeselected) then
            previous.info:OnDeselected(previous.panel)
        end

        previous.panel:SetVisible(false)
    end

    if not IsValid(page.panel) then
        self:CreatePage(page)
    elseif not page.populated then
        self:PopulatePage(page)
    end

    for navKey, button in pairs(self.navButtons) do
        if IsValid(button) then
            button:SetSelected(navKey == key)
        end
    end

    page.panel:SetVisible(true)
    page.panel:MoveToFront()
    page.panel:InvalidateLayout(true)

    self.currentPageKey = key
    ix.gui.lastMenuTab = key

    local hideBackground = shouldHideBackground(page.key, page.info)
    if hideBackground then
        self:HideBackground()
    else
        self:ShowBackground()
    end

    if page.key == "settings" and IsValid(page.settingsPanel) then
        page.settingsPanel:OnMenuSelected()
    elseif page.key == "you" and IsValid(page.characterPanel) then
        page.characterPanel:OnMenuSelected()
    elseif istable(page.info) and isfunction(page.info.OnSelected) then
        page.info:OnSelected(page.panel)
    end

    if previous and not instant then
        SWRP.Datapad.PlaySound(key == "navigator" and "zoom" or "move")
    end
end

-- Compatibility with Helix and external plugins that expect these methods.
function PANEL:GetActiveTab()
    return self.currentPageKey
end

function PANEL:GetActiveSubpanel()
    local page = self.currentPageKey and self.pages[self.currentPageKey] or nil
    return page and page.panel or nil
end

function PANEL:GetSubpanel(id)
    local page = self.pages[id]
    return page and page.panel or nil
end

function PANEL:TransitionSubpanel(id)
    if isstring(id) then
        self:SelectPage(id)
        return
    end

    -- Older plugins may have retained a numeric/index reference. Resolve it
    -- against the order in which this menu created its navigation entries.
    local key = self.pageOrder[tonumber(id) or -1]
    if key then
        self:SelectPage(key)
    end
end

function PANEL:GetStandardSubpanelSize()
    if IsValid(self.pageContainer) then
        return self.pageContainer:GetWide(), self.pageContainer:GetTall()
    end

    return ScrW() * 0.75, ScrH() * 0.8
end

function PANEL:AddManuallyPaintedChild(panel)
    if not IsValid(panel) then
        return
    end

    panel:SetParent(self)
    panel:SetPaintedManually(true)
    self.manualChildren[#self.manualChildren + 1] = panel
end

function PANEL:SetCharacterOverview(value, length)
    value = tobool(value)
    length = length or ANIMATION_TIME

    if value then
        if not IsValid(self.projectedTexture) then
            self.projectedTexture = ProjectedTexture()
        end

        local faction = ix.faction.indices[LocalPlayer():Team()]
        local colour = faction and faction.color or color_white

        self.projectedTexture:SetEnableShadows(false)
        self.projectedTexture:SetNearZ(12)
        self.projectedTexture:SetFarZ(64)
        self.projectedTexture:SetFOV(90)
        self.projectedTexture:SetColor(colour)
        self.projectedTexture:SetTexture("effects/flashlight/soft")

        self:CreateAnimation(length, {
            index = 3,
            target = {overviewFraction = 1},
            easing = "outQuint",
            bIgnoreConfig = true
        })

        self.bOverviewOut = false
        self.bCharacterOverview = true
    else
        self:CreateAnimation(length, {
            index = 3,
            target = {overviewFraction = 0},
            easing = "outQuint",
            bIgnoreConfig = true,
            OnComplete = function(animation, panel)
                panel.bCharacterOverview = false
                if IsValid(panel.projectedTexture) then
                    panel.projectedTexture:Remove()
                end
            end
        })

        self.bOverviewOut = true
    end
end

function PANEL:GetOverviewInfo(origin, angles, fov)
    local originAngles = Angle(0, angles.yaw, angles.roll)
    local target = LocalPlayer():GetObserverTarget()
    local fraction = self.overviewFraction
    local drawPlayer = ((fraction > 0.2) or (not self.bOverviewOut and fraction > 0.2)) and not IsValid(target)
    local forward = originAngles:Forward() * 58 - originAngles:Right() * 16
    forward.z = 0

    local newOrigin
    if IsValid(target) then
        newOrigin = target:GetPos() + forward
    else
        newOrigin = origin - LocalPlayer():OBBCenter() * 0.6 + forward
    end

    local newAngles = originAngles + self.rotationOffset
    newAngles.pitch = 5
    newAngles.roll = 0

    return LerpVector(fraction, origin, newOrigin), LerpAngle(fraction, angles, newAngles), Lerp(fraction, fov, 90), drawPlayer
end

function PANEL:HideBackground()
    self:CreateAnimation(ANIMATION_TIME, {
        index = 2,
        target = {currentBlur = 0},
        easing = "outQuint"
    })
end

function PANEL:ShowBackground()
    self:CreateAnimation(ANIMATION_TIME, {
        index = 2,
        target = {currentBlur = 1},
        easing = "outQuint"
    })
end

function PANEL:OnOpened()
    self:SetAlpha(0)
    self:CreateAnimation(ANIMATION_TIME, {
        target = {currentAlpha = 255},
        easing = "outQuint",
        Think = function(animation, panel)
            panel:SetAlpha(panel.currentAlpha)
        end
    })
end

function PANEL:OnKeyCodePressed(key)
    self.noAnchor = CurTime() + 0.5

    if key == KEY_TAB then
        SWRP.Datapad.PlaySound("back")
        self:Remove()
    end
end

function PANEL:Think()
    if IsValid(self.projectedTexture) then
        local forward = LocalPlayer():GetForward()
        forward.z = 0
        local right = LocalPlayer():GetRight()
        right.z = 0

        self.projectedTexture:SetBrightness(self.overviewFraction * 4)
        self.projectedTexture:SetPos(LocalPlayer():GetPos() + right * 16 - forward * 8 + self.projectedTexturePosition)
        self.projectedTexture:SetAngles(forward:Angle() + self.projectedTextureRotation)
        self.projectedTexture:Update()
    end

    if self.bClosing then
        return
    end

    local tabDown = input.IsKeyDown(KEY_TAB)

    if tabDown and (self.noAnchor or CurTime() + 0.4) < CurTime() and self.anchorMode then
        self.anchorMode = false
        SWRP.Datapad.PlaySound("back")
    end

    if (not self.anchorMode and not tabDown) or gui.IsGameUIVisible() then
        self:Remove()

        if ix.option.Get("escCloseMenu", false) then
            gui.HideGameUI()
        end
    end
end

function PANEL:Paint(width, height)
    derma.SkinFunc("PaintMenuBackground", self, width, height, self.currentBlur)

    local overlayAlpha = 45 + 145 * math.Clamp(self.currentBlur or 0, 0, 1)
    surface.SetDrawColor(0, 4, 8, overlayAlpha)
    surface.DrawRect(0, 0, width, height)

    local accent = getAccent()
    local glowX = width * 0.64
    local glowWidth = width * 0.22
    surface.SetDrawColor(accent.r, accent.g, accent.b, 4)
    surface.DrawRect(glowX, 0, glowWidth, height)

end

function PANEL:PaintOver(width, height)
    for index = #self.manualChildren, 1, -1 do
        local child = self.manualChildren[index]
        if IsValid(child) then
            child:PaintManual()
        else
            table.remove(self.manualChildren, index)
        end
    end

    if IsValid(ix.gui.inv1) and ix.gui.inv1.childPanels then
        for _, panel in ipairs(ix.gui.inv1.childPanels) do
            if IsValid(panel) then
                panel:PaintManual()
            end
        end
    end

end

function PANEL:PerformLayout(width, height)
    if not IsValid(self.frame) then
        return
    end

    local marginX = math.Clamp(width * 0.025, 24, 52)
    local marginY = math.Clamp(height * 0.038, 24, 44)
    self.frame:SetPos(marginX, marginY)
    self.frame:SetSize(width - marginX * 2, height - marginY * 2)
end

function PANEL:Remove()
    if self.bClosing then
        return
    end

    self.bClosing = true
    self:SetMouseInputEnabled(false)
    self:SetKeyboardInputEnabled(false)
    self:SetCharacterOverview(false, ANIMATION_TIME * 0.5)

    local current = self.currentPageKey and self.pages[self.currentPageKey] or nil
    if current and current.key == "settings" and IsValid(current.settingsPanel) then
        current.settingsPanel:OnMenuDeselected()
    elseif current and current.key == "you" and IsValid(current.characterPanel) then
        current.characterPanel:OnMenuDeselected()
    elseif current and IsValid(current.panel) and istable(current.info) and isfunction(current.info.OnDeselected) then
        current.info:OnDeselected(current.panel)
    end

    if IsValid(ix.gui.inv1) and ix.gui.inv1.childPanels then
        for _, panel in ipairs(ix.gui.inv1.childPanels) do
            if IsValid(panel) then
                panel:SetMouseInputEnabled(false)
                panel:SetKeyboardInputEnabled(false)
            end
        end
    end

    CloseDermaMenus()
    gui.EnableScreenClicker(false)

    self:CreateAnimation(ANIMATION_TIME * 0.55, {
        index = 2,
        target = {currentBlur = 0},
        easing = "outQuint"
    })

    self:CreateAnimation(ANIMATION_TIME * 0.55, {
        target = {currentAlpha = 0},
        easing = "outQuint",
        Think = function(animation, panel)
            panel:SetAlpha(panel.currentAlpha)
        end,
        OnComplete = function(animation, panel)
            if IsValid(panel.projectedTexture) then
                panel.projectedTexture:Remove()
            end

            -- DModelPanel uses its own render pass and can otherwise draw one
            -- final full-opacity frame after the parent menu reaches alpha 0.
            hideModelPanels(panel)

            local wasActiveMenu = ix.gui.menu == panel
            BaseClass.Remove(panel)

            if wasActiveMenu then
                ix.gui.menu = nil
            end
        end
    })
end

vgui.Register("ixMenu", PANEL, "EditablePanel")

if IsValid(ix.gui.menu) then
    ix.gui.menu:Remove()
end

ix.gui.lastMenuTab = nil
