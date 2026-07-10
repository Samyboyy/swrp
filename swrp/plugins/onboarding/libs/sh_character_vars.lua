
-- swrp/plugins/onboarding/libs/sh_character_vars.lua
-- Persistent, server-authoritative character variables.
--
-- All of these are per-Helix-character: a clone career belongs to the character, and a
-- player may keep several characters. Each uses a real column in the ix_characters table
-- via field/fieldType, so values persist automatically across disconnects and map changes.
-- No manual save code is required -- a disconnect cannot wipe completed training.
--
-- Networking is chosen per variable, least-networking-first:
--   * default (broadcast to everyone)   -> identity others can see: clone number, callsign, rank, regiment
--   * isLocal = true (owner only)        -> personal progression the owner's own UI will read
--   * bNoNetworking = true (server only) -> values clients never need: discord, timestamps, training version
--
-- Every variable sets bNoDisplay = true so none of them appear in the character-creation
-- menu. Set<Var> functions are generated on the SERVER only (Helix behaviour), so clients
-- cannot modify these -- state stays authoritative.

-- ============================ Identity (networked to all) ============================

ix.char.RegisterVar("cloneNumber", {
	field = "clone_number",
	fieldType = ix.type.string,
	default = "",
	bNoDisplay = true
})

ix.char.RegisterVar("callsign", {
	field = "callsign",
	fieldType = ix.type.string,
	default = "",
	bNoDisplay = true
})

ix.char.RegisterVar("rank", {
	field = "rank",
	fieldType = ix.type.string,
	default = "",
	bNoDisplay = true
})

ix.char.RegisterVar("regiment", {
	field = "regiment",
	fieldType = ix.type.string,
	default = "",
	bNoDisplay = true
})

-- ============================ Progression (owner-local) ============================

ix.char.RegisterVar("xp", {
	field = "xp",
	fieldType = ix.type.number,
	default = 0,
	isLocal = true,
	bNoDisplay = true
})

ix.char.RegisterVar("level", {
	field = "level",
	fieldType = ix.type.number,
	default = 1,
	isLocal = true,
	bNoDisplay = true
})

ix.char.RegisterVar("preferredRegiment", {
	field = "preferred_regiment",
	fieldType = ix.type.string,
	default = "",
	isLocal = true,
	bNoDisplay = true
})

ix.char.RegisterVar("skillPoints", {
	field = "skill_points",
	fieldType = ix.type.number,
	default = 0,
	isLocal = true,
	bNoDisplay = true
})

ix.char.RegisterVar("freeChangePointsSpent", {
	field = "free_change_points_spent",
	fieldType = ix.type.number,
	default = 0,
	isLocal = true,
	bNoDisplay = true
})

ix.char.RegisterVar("buildLocked", {
	field = "build_locked",
	fieldType = ix.type.bool,
	default = false,
	isLocal = true,
	bNoDisplay = true
})

-- ============================ Training progress ============================
-- trainingCompleted / trainingStage are owner-local because the player's own onboarding UI
-- (a later milestone) will read them. trainingCompletedAt / trainingVersion are server-only
-- internal bookkeeping the client never needs.

ix.char.RegisterVar("trainingCompleted", {
	field = "training_completed",
	fieldType = ix.type.bool,
	default = false,
	isLocal = true,
	bNoDisplay = true
})

ix.char.RegisterVar("trainingStage", {
	field = "training_stage",
	fieldType = ix.type.number,
	default = 0,
	isLocal = true,
	bNoDisplay = true
})

ix.char.RegisterVar("trainingCompletedAt", {
	field = "training_completed_at",
	fieldType = ix.type.number,
	default = 0,
	bNoNetworking = true,
	bNoDisplay = true
})

ix.char.RegisterVar("trainingVersion", {
	field = "training_version",
	fieldType = ix.type.number,
	default = 0,
	bNoNetworking = true,
	bNoDisplay = true
})

-- ============================ Contact (server only) ============================

ix.char.RegisterVar("discordUsername", {
	field = "discord_username",
	fieldType = ix.type.string,
	default = "",
	bNoNetworking = true,
	bNoDisplay = true
})
