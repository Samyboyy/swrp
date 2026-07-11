
-- swrp/schema/libs/sh_swrp_logging.lua
-- Lightweight central logging helper for SWRP.
--
-- SWRP.Log(category, message, ...) prints a single formatted line to the server console:
--     [SWRP][CATEGORY] message
--
-- Intentionally minimal for Milestone 1. This is NOT a database audit log, Discord relay,
-- or webhook -- it just makes state-changing admin actions readable in the console beyond
-- Helix's generic "player used a command" line. Extra arguments are passed to string.format.
--
-- Lives in schema/libs/, so it is auto-included before any plugin and is available to the
-- onboarding commands.

SWRP = SWRP or {}

--- Prints a formatted SWRP log line to the console.
-- @realm shared (only called server-side in Milestone 1)
-- @string category Short tag, e.g. "onboarding", "map", "admin", "progression"
-- @string message Message text, optionally a string.format template
-- @param ... Optional string.format arguments
function SWRP.Log(category, message, ...)
	category = tostring(category or "general"):upper()

	if (select("#", ...) > 0) then
		message = string.format(message, ...)
	end

	MsgN(string.format("[SWRP][%s] %s", category, tostring(message)))
end
