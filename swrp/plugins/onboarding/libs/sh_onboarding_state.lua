
-- swrp/plugins/onboarding/libs/sh_onboarding_state.lua
-- The single authoritative function that derives a character's onboarding state.
--
-- Nothing stores the state. It is always computed from persistent training data plus the
-- current map classification, so a stored value can never drift out of sync with reality.
--
-- Truth table:
--   trainingCompleted == true                    -> TRAINED
--   trainingStage      > 0 (and not completed)   -> TRAINING
--   otherwise, on an HQ map                       -> UNTRAINED_HQ
--   otherwise (event map / unlisted map)          -> UNTRAINED_EVENT

--- Derives the onboarding state for a character.
-- @realm shared
-- @param character The Helix character to evaluate (may be nil)
-- @treturn string One of SWRP.STATE.*
function SWRP.GetOnboardingState(character)
	-- Defensive: with no character we can only reason from the map. Treat as untrained so a
	-- missing character never reads as TRAINED.
	if (not character) then
		return SWRP.IsHQMap() and SWRP.STATE.UNTRAINED_HQ or SWRP.STATE.UNTRAINED_EVENT
	end

	if (character:GetTrainingCompleted()) then
		return SWRP.STATE.TRAINED
	end

	if ((character:GetTrainingStage() or 0) > 0) then
		return SWRP.STATE.TRAINING
	end

	if (SWRP.IsHQMap()) then
		return SWRP.STATE.UNTRAINED_HQ
	end

	return SWRP.STATE.UNTRAINED_EVENT
end
