-- swrp/plugins/regiments/sh_plugin.lua

PLUGIN.name = "SWRP Regiment Directory V2"
PLUGIN.author = "Sam"
PLUGIN.description = "Adds a simplified player directory and permission-controlled regiment management suite to the Helix TAB menu."

if (CLIENT) then
	function PLUGIN:CreateMenuButtons(tabs)
		tabs["regiments"] = function(container)
			local panel = container:Add("swrpRegimentDirectory")

			if (IsValid(panel)) then
				panel:Dock(FILL)
			end
		end
	end
end
