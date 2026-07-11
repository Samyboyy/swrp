-- swrp/plugins/onboarding/libs/sh_career_paths.lua
-- Shared presentation data for the non-binding career interest chosen at character creation.
-- IDs deliberately match the branch IDs in plugins/datapad/libs/sh_upgrade_tree.lua.

SWRP = SWRP or {}

SWRP.CareerPaths = {
	conditioning = {
		id = "conditioning",
		title = "INFANTRY",
		shortTitle = "Infantry",
		description = "Front-line endurance and battlefield resilience.",
		preview = "Endurance  >  Vanguard",
		colour = Color(73, 154, 219)
	},
	aviation = {
		id = "aviation",
		title = "AVIATION",
		shortTitle = "Aviation",
		description = "Transport and starfighter flight certification.",
		preview = "Aptitude  >  Republic Pilot",
		colour = Color(87, 190, 224)
	},
	medical = {
		id = "medical",
		title = "MEDICAL",
		shortTitle = "Medical",
		description = "Battlefield care and casualty stabilisation.",
		preview = "Fundamentals  >  Combat Medic",
		colour = Color(92, 205, 176)
	},
	weapons = {
		id = "weapons",
		title = "WEAPONS",
		shortTitle = "Weapons",
		description = "Advanced rifle and heavy weapon clearance.",
		preview = "Rifle Drill  >  Weapons Specialist",
		colour = Color(218, 162, 91)
	}
}

SWRP.CareerPathOrder = {
	"conditioning",
	"aviation",
	"medical",
	"weapons"
}

function SWRP.GetCareerPath(pathID)
	return SWRP.CareerPaths[tostring(pathID or "")]
end

function SWRP.IsCareerPath(pathID)
	return SWRP.GetCareerPath(pathID) ~= nil
end
