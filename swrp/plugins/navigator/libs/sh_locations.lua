-- swrp/plugins/navigator/libs/sh_locations.lua
-- Permanent navigator destinations and hologram presentation configuration.

SWRP = SWRP or {}
SWRP.Navigator = SWRP.Navigator or {}

SWRP.Navigator.arrivalDistance = 128

-- The camera is framed from the model's render bounds rather than its Blender origin.
-- If the compiled model still needs a small visual adjustment, change centreOffset only.
SWRP.Navigator.hologram = {
	model = "models/swrp/venator_hologram.mdl",
	fov = 36,
	orbitSpeed = 7,
	distanceMultiplier = 1.12,
	cameraHeightMultiplier = 0.30,
	centreOffset = Vector(0, 0, 0)
}

SWRP.Navigator.maps = SWRP.Navigator.maps or {}

SWRP.Navigator.maps["rp_venator_extensive_v1_4"] = {
	training_room = {
		name = "Training Room",
		category = "Training",
		deck = "Training Deck",
		description = "Basic training, formations and Republic instruction.",
		instruction = "Proceed toward the Training Room.",
		position = Vector(-6150.256348, -2974.776611, -3583.817871),
		angles = Angle(8.274025, 89.974602, 0),

		-- Position on the rotating Venator hologram. Values are normalised across the
		-- model render bounds: 0 = minimum edge, 1 = maximum edge on each axis.
		-- This lets the marker remain attached to the ship while the camera orbits.
		hologramAnchor = Vector(0.55, 0.50, 0.41),
		hologramLabel = "Training Room",
		hologramCode = "TRN-01"
	}
}

function SWRP.Navigator.GetLocations(mapName)
	mapName = tostring(mapName or game.GetMap()):lower()
	return SWRP.Navigator.maps[mapName] or {}
end

function SWRP.Navigator.GetLocation(locationID, mapName)
	return SWRP.Navigator.GetLocations(mapName)[tostring(locationID or "")]
end

function SWRP.Navigator.GetSortedLocations(mapName)
	local output = {}

	for locationID, location in pairs(SWRP.Navigator.GetLocations(mapName)) do
		output[#output + 1] = {
			id = locationID,
			name = location.name,
			category = location.category,
			deck = location.deck,
			description = location.description,
			instruction = location.instruction,
			position = location.position,
			angles = location.angles,
			hologramAnchor = location.hologramAnchor,
			hologramLabel = location.hologramLabel,
			hologramCode = location.hologramCode
		}
	end

	table.sort(output, function(a, b)
		local categoryA = tostring(a.category or "")
		local categoryB = tostring(b.category or "")

		if (categoryA == categoryB) then
			return tostring(a.name or a.id) < tostring(b.name or b.id)
		end

		return categoryA < categoryB
	end)

	return output
end
