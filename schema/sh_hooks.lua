-- Here is where all of your shared hooks should go.

function Schema:CanDrive(client, entity)
    return false
end

if (SERVER) then
    local function RaiseHelixWeapon(client, weapon)
        timer.Simple(0, function()
            if (!IsValid(client) or !client:Alive()) then
                return
            end

            weapon = IsValid(weapon) and weapon or client:GetActiveWeapon()

            if (IsValid(weapon)) then
                client:SetWepRaised(true, weapon)
            end
        end)
    end

    -- Helix should always consider the selected weapon raised.
    function Schema:PlayerSwitchWeapon(client, oldWeapon, newWeapon)
        RaiseHelixWeapon(client, newWeapon)
    end

    -- Fallback for spawning or loading a character with a weapon selected.
    function Schema:PlayerSpawn(client)
        RaiseHelixWeapon(client)
    end

    function Schema:PlayerLoadedCharacter(client, character, oldCharacter)
        RaiseHelixWeapon(client)
    end

    -- Prevent players from activating Helix's own raise/lower system.
    function Schema:InitializedSchema()
        local command = ix.command.list["toggleraise"]

        if (command) then
            command.OnRun = function(self, client)
                local weapon = client:GetActiveWeapon()

                if (IsValid(weapon)) then
                    client:SetWepRaised(true, weapon)
                end

                client:Notify("Use the weapon's built-in holster controls.")
            end
        end
    end
end