
-- swrp/schema/libs/sh_swrp_config.lua
-- Central configuration for the Clone Wars Roleplay schema.
--
-- Everything that multiple systems must agree on (maps, classifications, onboarding
-- states, progression thresholds, menu music) is defined here in exactly one place.
-- This file lives in schema/libs/, so Helix auto-includes it early -- before any plugins
-- load -- which means every plugin can safely rely on the SWRP table existing.

SWRP = SWRP or {}
SWRP.config = SWRP.config or {}

--[[--------------------------------------------------------------------------------------
	Character-menu music

	We do NOT modify Helix core. Helix already exposes a "music" config that the character
	menu plays from ("sound/" .. value), or as a raw http URL. We simply point that config
	at a placeholder path for now.

	To use the real track: drop the Boba Fett Suite file at sound/<menuMusic> on the server
	(and fast-download it to clients). No code change is needed -- or change it live in the
	F1 > Config menu. Do NOT put a YouTube URL here.
----------------------------------------------------------------------------------------]]
SWRP.config.menuMusic       = "swrp/theme.mp3" -- relative to the sound/ folder
SWRP.config.stockMusicValue = "music/hl2_song2.mp3"        -- Helix's own default; used to detect "untouched"

if (ix.config and ix.config.SetDefault) then
	-- Make the framework default (and the menu's "reset" target) our placeholder. The
	-- active value is applied on a fresh server in schema/sv_hooks.lua:InitializedConfig.
	ix.config.SetDefault("music", SWRP.config.menuMusic)
end

--[[--------------------------------------------------------------------------------------
	Onboarding states

	These identifiers are DERIVED at runtime from persistent training data plus the current
	map classification (see plugins/onboarding/libs/sh_onboarding_state.lua). They are never
	stored, so they can never contradict the saved data.
----------------------------------------------------------------------------------------]]
SWRP.STATE = {
	UNTRAINED_HQ    = "UNTRAINED_HQ",
	UNTRAINED_EVENT = "UNTRAINED_EVENT",
	TRAINING        = "TRAINING",
	TRAINED         = "TRAINED"
}

--[[--------------------------------------------------------------------------------------
	Training
----------------------------------------------------------------------------------------]]
-- Bump this when the basic-training course changes enough that veterans should (optionally,
-- in a later milestone) be asked to re-train. Stamped onto the character at graduation.
SWRP.config.trainingVersion = 1

--[[--------------------------------------------------------------------------------------
	Progression thresholds
----------------------------------------------------------------------------------------]]
-- How many skill points may be freely reassigned before a build locks (Milestone 1 stores
-- the value only; enforcement arrives with the career system in a later milestone).
SWRP.config.freeChangePointLimit = 10

--[[--------------------------------------------------------------------------------------
	Map classification

	rp_venator_extensive_v1_4 is HQ. Every unlisted map defaults to event behaviour.
	Keys MUST be lowercase -- game.GetMap() always returns a lowercase name.
----------------------------------------------------------------------------------------]]
SWRP.MAP_HQ    = "hq"
SWRP.MAP_EVENT = "event"

SWRP.config.hqMaps = {
	["rp_venator_extensive_v1_4"] = true
	-- Additional HQ maps go here later.
}

--- Returns the permanent, configuration-based classification for a map, ignoring any
--- temporary override.
-- @realm shared
-- @string[opt] map Map name; defaults to the current map
-- @treturn string SWRP.MAP_HQ or SWRP.MAP_EVENT
function SWRP.GetConfiguredMapClassification(map)
	map = tostring(map or game.GetMap()):lower()

	return SWRP.config.hqMaps[map] and SWRP.MAP_HQ or SWRP.MAP_EVENT
end

--- Returns the effective classification for a map: the temporary override if one is active
--- (server only), otherwise the configured value. Call THIS from the rest of the schema.
-- @realm shared
-- @string[opt] map Map name; defaults to the current map
-- @treturn string SWRP.MAP_HQ or SWRP.MAP_EVENT
function SWRP.GetMapClassification(map)
	if (SERVER and SWRP.runtimeMapOverride) then
		return SWRP.runtimeMapOverride
	end

	return SWRP.GetConfiguredMapClassification(map)
end

--- Convenience: is the given (or current) map an HQ map, honouring any override?
-- @realm shared
function SWRP.IsHQMap(map)
	return SWRP.GetMapClassification(map) == SWRP.MAP_HQ
end

if (SERVER) then
	-- Temporary, memory-only testing override. It is never persisted, so it is gone after a
	-- server restart. It survives a live Lua auto-refresh only because SWRP itself does.
	-- Permanent classifications belong in SWRP.config.hqMaps above.

	--- Sets a temporary map-classification override for testing.
	-- @realm server
	-- @string classification SWRP.MAP_HQ or SWRP.MAP_EVENT
	-- @treturn bool Whether the value was valid and applied
	function SWRP.SetMapOverride(classification)
		if (classification ~= SWRP.MAP_HQ and classification ~= SWRP.MAP_EVENT) then
			return false
		end

		SWRP.runtimeMapOverride = classification

		return true
	end

	--- Clears the temporary override, returning to the configured classification.
	-- @realm server
	function SWRP.ClearMapOverride()
		SWRP.runtimeMapOverride = nil
	end

	--- Returns the active override, or nil if none is set.
	-- @realm server
	function SWRP.GetMapOverride()
		return SWRP.runtimeMapOverride
	end
end
