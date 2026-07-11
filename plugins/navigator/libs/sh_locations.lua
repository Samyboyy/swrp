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
	-- Keep the ship rotating, but allow individual locations to opt into a
	-- calibrated 2D marker when the compiled model does not expose a reliable
	-- interior anchor. This is more stable for ship room callouts than trying to
	-- infer an exact deck coordinate from a decorative hologram mesh.
	staticCamera = false,
	fixedOrbitDegrees = 90,
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

		-- For ship interiors, a calibrated screen-space point is more dependable
		-- than trying to map an arbitrary room to a decorative hull mesh. The 3D
		-- model still rotates, but the visible target dot stays locked to the
		-- approved place on the ship silhouette.
		hologramScreenAnchor = Vector(-0.04, 0.42, 0),
		hologramCalloutAnchor = Vector(0.23, 0.30, 0),
		hologramScreenOffset = Vector(0, 0, 0),
		hologramAnchor = Vector(0.54, 0.50, 0.34),
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
			hologramScreenAnchor = location.hologramScreenAnchor,
			hologramCalloutAnchor = location.hologramCalloutAnchor,
			hologramScreenOffset = location.hologramScreenOffset,
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
