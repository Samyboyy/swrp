
-- swrp/plugins/onboarding/libs/sv_commands.lua
-- Administrator debugging commands for the onboarding foundation.
--
-- All commands are adminOnly (Helix auto-registers a CAMI privilege for each). Every command
-- validates that the target player exists and has a loaded character before touching data.
-- All writes go through the server-only Set<Var> methods, so state stays authoritative.
--
-- State-changing commands (SetStage, SetTrained, ResetTraining, OverrideMapClass) emit
-- detailed console logs via SWRP.Log so the server console explains exactly what changed,
-- beyond Helix's generic command-use log. Read-only commands (MapClass, OnboardingState,
-- DebugChar) rely on that generic log only, as requested.

-- Resolve the target player (defaults to the caller) and their current character.
local function resolveTarget(client, target)
	target = IsValid(target) and target or client

	if (not IsValid(target) or not target:IsPlayer()) then
		return nil, nil
	end

	return target, target:GetCharacter()
end

ix.command.Add("SWRPOnboardingState", {
	description = "Show a player's derived onboarding state and the training data behind it.",
	adminOnly = true,
	arguments = bit.bor(ix.type.player, ix.type.optional),
	OnRun = function(self, client, target)
		local ply, character = resolveTarget(client, target)

		if (not IsValid(ply)) then
			return "Invalid target player."
		elseif (not character) then
			return "That player has no loaded character."
		end

		local state = SWRP.GetOnboardingState(character)

		client:ChatPrint(string.format("[SWRP] Onboarding state for %s:", ply:Nick()))
		client:ChatPrint(string.format("  Derived state: %s", state))
		client:ChatPrint(string.format("  Map: %s  (effective: %s%s)",
			game.GetMap(), SWRP.GetMapClassification(),
			SWRP.GetMapOverride() and "  [OVERRIDE ACTIVE]" or ""))
		client:ChatPrint(string.format("  trainingCompleted: %s", tostring(character:GetTrainingCompleted())))
		client:ChatPrint(string.format("  trainingStage: %d", character:GetTrainingStage() or 0))
		client:ChatPrint(string.format("  trainingVersion: %d", character:GetTrainingVersion() or 0))

		return string.format("Onboarding state for %s: %s", ply:Nick(), state)
	end
})

ix.command.Add("SWRPSetTrained", {
	description = "Mark a player's current character as having completed basic training.",
	adminOnly = true,
	arguments = ix.type.player,
	OnRun = function(self, client, target)
		if (not IsValid(target)) then return "Invalid target player." end

		local character = target:GetCharacter()
		if (not character) then return "That player has no loaded character." end

		local oldState = SWRP.GetOnboardingState(character)

		character:SetTrainingCompleted(true)
		character:SetTrainingStage(0)
		character:SetTrainingCompletedAt(os.time())
		character:SetTrainingVersion(SWRP.config.trainingVersion)

		local newState = SWRP.GetOnboardingState(character)

		SWRP.Log("admin", "ADMIN %s (%s) marked %s (#%d) as trained.",
			client:Nick(), client:SteamID(), character:GetName(), character:GetID())

		if (oldState ~= newState) then
			SWRP.Log("onboarding", "Onboarding state changed: %s -> %s.", oldState, newState)
		end

		SWRP.Log("progression", "Training version: %d.", SWRP.config.trainingVersion)

		return string.format("%s is now marked TRAINED (v%d).", target:Nick(), SWRP.config.trainingVersion)
	end
})

ix.command.Add("SWRPResetTraining", {
	description = "Reset a player's basic-training progress back to untrained.",
	adminOnly = true,
	arguments = ix.type.player,
	OnRun = function(self, client, target)
		if (not IsValid(target)) then return "Invalid target player." end

		local character = target:GetCharacter()
		if (not character) then return "That player has no loaded character." end

		local oldState = SWRP.GetOnboardingState(character)

		character:SetTrainingCompleted(false)
		character:SetTrainingStage(0)
		character:SetTrainingCompletedAt(0)
		character:SetTrainingVersion(0)

		local newState = SWRP.GetOnboardingState(character)

		SWRP.Log("admin", "ADMIN %s (%s) reset training for %s (#%d).",
			client:Nick(), client:SteamID(), character:GetName(), character:GetID())

		if (oldState ~= newState) then
			SWRP.Log("onboarding", "Onboarding state changed: %s -> %s.", oldState, newState)
		end

		return string.format("Training reset for %s.", target:Nick())
	end
})

ix.command.Add("SWRPSetStage", {
	description = "Set a player's current training stage (0 = not started).",
	adminOnly = true,
	arguments = {
		ix.type.player,
		ix.type.number
	},
	OnRun = function(self, client, target, stage)
		if (not IsValid(target)) then return "Invalid target player." end

		local character = target:GetCharacter()
		if (not character) then return "That player has no loaded character." end

		stage = math.floor(tonumber(stage) or 0)
		if (stage < 0) then
			return "Stage must be 0 or greater."
		end

		local oldStage = character:GetTrainingStage() or 0
		local oldState = SWRP.GetOnboardingState(character)

		character:SetTrainingStage(stage)

		-- A positive stage means they are mid-course, so they cannot also be "completed".
		if (stage > 0 and character:GetTrainingCompleted()) then
			character:SetTrainingCompleted(false)
		end

		local newState = SWRP.GetOnboardingState(character)

		SWRP.Log("progression", "ADMIN %s (%s) changed training stage for %s (#%d): %d -> %d.",
			client:Nick(), client:SteamID(), character:GetName(), character:GetID(), oldStage, stage)

		if (oldState ~= newState) then
			SWRP.Log("onboarding", "Onboarding state changed: %s -> %s.", oldState, newState)
		end

		return string.format("%s training stage set to %d.", target:Nick(), stage)
	end
})

ix.command.Add("SWRPMapClass", {
	description = "Show the current map's classification (configured, override, effective).",
	adminOnly = true,
	OnRun = function(self, client)
		client:ChatPrint(string.format("[SWRP] Map: %s", game.GetMap()))
		client:ChatPrint(string.format("  Configured: %s", SWRP.GetConfiguredMapClassification()))
		client:ChatPrint(string.format("  Override:   %s", SWRP.GetMapOverride() or "none"))
		client:ChatPrint(string.format("  Effective:  %s", SWRP.GetMapClassification()))

		return string.format("Map is currently classified as: %s", SWRP.GetMapClassification())
	end
})

ix.command.Add("SWRPOverrideMapClass", {
	description = "Temporarily override this map's classification for testing (memory only; resets on restart). Use: hq, event, or clear.",
	adminOnly = true,
	arguments = ix.type.string,
	OnRun = function(self, client, value)
		value = tostring(value):lower()

		local bClear = (value == "clear" or value == "none" or value == "reset")
		local applied = true

		if (bClear) then
			SWRP.ClearMapOverride()
		elseif (value == "hq") then
			SWRP.SetMapOverride(SWRP.MAP_HQ)
		elseif (value == "event") then
			SWRP.SetMapOverride(SWRP.MAP_EVENT)
		else
			applied = false
		end

		if (not applied) then
			return "Invalid value. Use: hq, event, or clear."
		end

		SWRP.Log("admin", "ADMIN %s (%s) changed the temporary map override.",
			client:Nick(), client:SteamID())
		SWRP.Log("map", "Map: %s", game.GetMap())
		SWRP.Log("map", "Configured: %s", SWRP.GetConfiguredMapClassification())
		SWRP.Log("map", "Override: %s", SWRP.GetMapOverride() or "none")
		SWRP.Log("map", "Effective: %s", SWRP.GetMapClassification())

		if (bClear) then
			return "Map override cleared; using the configured classification."
		end

		return string.format("Map override set to %s (temporary, memory only).", value:upper())
	end
})

ix.command.Add("SWRPDebugChar", {
	description = "Print all SWRP persistent variables for a player's current character.",
	adminOnly = true,
	arguments = bit.bor(ix.type.player, ix.type.optional),
	OnRun = function(self, client, target)
		local ply, character = resolveTarget(client, target)

		if (not IsValid(ply)) then
			return "Invalid target player."
		elseif (not character) then
			return "That player has no loaded character."
		end

		client:ChatPrint(string.format("[SWRP] Character #%d (%s) owned by %s:",
			character:GetID(), character:GetName(), ply:Nick()))
		client:ChatPrint(string.format("  cloneNumber:       %q", character:GetCloneNumber()))
		client:ChatPrint(string.format("  callsign:          %q", character:GetCallsign()))
		client:ChatPrint(string.format("  rank:              %q", character:GetRank()))
		client:ChatPrint(string.format("  regiment:          %q", character:GetRegiment()))
		client:ChatPrint(string.format("  preferredRegiment: %q", character:GetPreferredRegiment()))
		client:ChatPrint(string.format("  careerPath:        %q", character:GetCareerPath()))
		client:ChatPrint(string.format("  careerTarget:      %q  [legacy]", character:GetCareerTarget()))
		client:ChatPrint(string.format("  startingAptitude:  %q  applied: %s",
			character:GetStartingAptitude(), tostring(character:GetStartingAptitudeApplied())))
		client:ChatPrint(string.format("  creditVersion:     %d", character:GetProgressionCreditVersion() or 0))
		client:ChatPrint(string.format("  discordUsername:   %q", character:GetDiscordUsername()))
		client:ChatPrint(string.format("  xp: %d   level: %d", character:GetXp() or 0, character:GetLevel() or 0))
		client:ChatPrint(string.format("  developmentCredits: %d   freeChangePointsSpent: %d",
			character:GetSkillPoints() or 0, character:GetFreeChangePointsSpent() or 0))
		client:ChatPrint(string.format("  buildLocked: %s", tostring(character:GetBuildLocked())))
		client:ChatPrint(string.format("  trainingCompleted: %s   stage: %d   version: %d",
			tostring(character:GetTrainingCompleted()),
			character:GetTrainingStage() or 0, character:GetTrainingVersion() or 0))
		client:ChatPrint(string.format("  trainingCompletedAt: %d", character:GetTrainingCompletedAt() or 0))
		client:ChatPrint(string.format("  => derived onboarding state: %s", SWRP.GetOnboardingState(character)))

		return string.format("Printed SWRP data for %s to your chat.", ply:Nick())
	end
})

ix.command.Add("SWRPSetDoctrine", {
	description = "Assign a development doctrine to an existing character (infantry, medical, heavy, aviation).",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.string},
	OnRun = function(self, client, target, value)
		if (not IsValid(target)) then return "Invalid target player." end
		local character = target:GetCharacter()
		if (not character) then return "That player has no loaded character." end

		local aliases = {
			infantry = "conditioning",
			physical = "conditioning",
			conditioning = "conditioning",
			medical = "medical",
			medic = "medical",
			heavy = "weapons",
			weapons = "weapons",
			aviation = "aviation",
			pilot = "aviation"
		}
		local doctrineID = aliases[string.lower(string.Trim(tostring(value or "")))]
		local doctrine = doctrineID and SWRP.GetCareerPath(doctrineID) or nil
		if (not doctrine) then return "Invalid doctrine. Use: infantry, medical, heavy, or aviation." end

		character:SetCareerPath(doctrineID)
		character:SetCareerTarget("")
		target:Notify("Your development doctrine is now " .. doctrine.title .. ".")
		return string.format("Assigned %s to the %s doctrine.", target:Name(), doctrine.title)
	end
})
