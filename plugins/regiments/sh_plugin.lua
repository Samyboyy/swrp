-- swrp/plugins/regiments/sh_plugin.lua

PLUGIN.name = "SWRP Regiment Directory V5"
PLUGIN.author = "Sam"
PLUGIN.description = "Adds regiment personnel management, automatic service names and admin-configured formation model loadouts to the Helix TAB menu."

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
