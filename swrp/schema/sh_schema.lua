-- The shared init file.

-- Schema identity shown on the character menu and in framework-facing UI.
Schema.name = "Galactic Roleplay"
Schema.author = "Sam"
Schema.description = "Republic personnel and deployment network."

-- Additional files that are not auto-included.
ix.util.Include("cl_schema.lua")
ix.util.Include("sv_schema.lua")

ix.util.Include("cl_hooks.lua")
ix.util.Include("sh_hooks.lua")
ix.util.Include("sv_hooks.lua")

-- Meta extensions are not auto-included by Helix.
ix.util.Include("meta/sh_character.lua")
ix.util.Include("meta/sh_player.lua")
