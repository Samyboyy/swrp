
-- swrp/schema/factions/sh_clone_trooper.lua
-- Minimal default faction so characters can be created and tested in Milestone 1.
-- Regiments, ranks and proper models come in later milestones; this is deliberately bare.

FACTION.name = "Clone Trooper"
FACTION.description = "A clone trooper of the Grand Army of the Republic."

-- Exactly one faction in the schema must be the default (available with no whitelist).
FACTION.isDefault = true
FACTION.color = Color(180, 190, 200)

-- PLACEHOLDER MODEL. combine_soldier is a stock Garry's Mod / HL2 model present on every
-- install, so character creation works with zero Workshop content. Replace with real clone
-- trooper models (or per-regiment model sets) in a later milestone.
FACTION.models = {
	"models/player/combine_soldier.mdl"
}

-- Global index for easy reference elsewhere (client:Team() == FACTION_CLONE, etc.).
FACTION_CLONE = FACTION.index
