
-- swrp/plugins/onboarding/sh_plugin.lua
-- Onboarding foundation: persistent character variables, the derived onboarding-state
-- function, and administrator debugging commands.
--
-- This plugin is self-contained. Deleting the plugins/onboarding/ folder removes it
-- entirely (see the rollback notes). Files in this plugin's libs/ folder are auto-included
-- by Helix based on their prefix (sh_ = shared, sv_ = server), so there are no manual
-- includes here.

PLUGIN.name = "SWRP Onboarding"
PLUGIN.author = "Sam"
PLUGIN.description = "Persistent onboarding character data, derived player-state, and admin debug tools."
