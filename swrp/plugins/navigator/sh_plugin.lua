-- swrp/plugins/navigator/sh_plugin.lua
-- Republic NAVCOM ship navigator.

PLUGIN.name = "SWRP Navigator"
PLUGIN.author = "Sam"
PLUGIN.description = "Adds a searchable Republic NAVCOM navigator to the Helix TAB menu."

if (CLIENT) then
    function PLUGIN:CreateMenuButtons(tabs)
        tabs["navigator"] = function(container)
            local panel = container:Add("swrpNavigator")

            if (IsValid(panel)) then
                panel:Dock(FILL)
            end
        end
    end
end
