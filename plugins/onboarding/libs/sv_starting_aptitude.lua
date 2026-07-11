-- swrp/plugins/onboarding/libs/sv_starting_aptitude.lua
-- Applies the small, one-time physical aptitude chosen during character creation.

local function applyStartingAptitude(character)
	if (!character or !isfunction(character.GetStartingAptitude)) then
		return
	end

	if (isfunction(character.GetStartingAptitudeApplied) and character:GetStartingAptitudeApplied()) then
		return
	end

	local aptitude = SWRP.GetStartingAptitude(character:GetStartingAptitude())
	if (!aptitude or !aptitude.attribute) then
		return
	end

	local attribute = ix.attributes.list[aptitude.attribute]
	if (!attribute) then
		return
	end

	local current = tonumber(character:GetAttribute(aptitude.attribute, 0)) or 0
	local configuredMaximum = tonumber(ix.config.Get("maxAttributes", 100)) or 100
	local maximum = math.max(tonumber(attribute.maxValue) or configuredMaximum, 10)
	local amount = math.min(10, maximum - current)

	if (amount > 0) then
		character:UpdateAttrib(aptitude.attribute, amount)
	end

	if (isfunction(character.SetStartingAptitudeApplied)) then
		character:SetStartingAptitudeApplied(true)
	end
end

function PLUGIN:CharacterCreated(client, character)
	-- Mark a brand-new record as using the current graph before the aptitude attribute is
	-- applied. Otherwise the legacy attribute migration could mistake the free +10 for a
	-- purchased conditioning node on the character's first tree interaction.
	local tree = SWRP.GetUpgradeTree and SWRP.GetUpgradeTree() or nil
	if (tree and isfunction(character.SetUpgradeTreeVersion)) then
		character:SetUpgradeTreeVersion(tree.version or 6)
	end

	timer.Simple(0, function()
		applyStartingAptitude(character)
	end)
end

function PLUGIN:PlayerLoadedCharacter(client, character)
	-- Recovery path for a creation interrupted between the database insert and the first
	-- attribute update. The applied flag keeps this strictly one-time.
	timer.Simple(0, function()
		applyStartingAptitude(character)
	end)
end
