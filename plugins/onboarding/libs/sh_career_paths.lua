-- swrp/plugins/onboarding/libs/sh_career_paths.lua
-- Shared doctrine and starting-aptitude definitions used by onboarding and progression.

SWRP = SWRP or {}

SWRP.CareerPaths = {
	conditioning = {
		id = "conditioning",
		title = "INFANTRY",
		fullTitle = "INFANTRY DOCTRINE",
		shortTitle = "Infantry",
		description = "Mobility, endurance and front-line combat conditioning.",
		benefit = "25% lower development-credit cost in Physical Conditioning.",
		access = "Available immediately",
		minimumLevel = 1,
		colour = Color(73, 154, 219)
	},
	aviation = {
		id = "aviation",
		title = "AVIATION",
		fullTitle = "AVIATION DOCTRINE",
		shortTitle = "Aviation",
		description = "Flight aptitude, transport operation and starfighter authorisations.",
		benefit = "25% lower development-credit cost in Aviation.",
		access = "Progression opens at Level 10; certification is still required",
		minimumLevel = 10,
		colour = Color(87, 190, 224)
	},
	medical = {
		id = "medical",
		title = "MEDICAL",
		fullTitle = "MEDICAL DOCTRINE",
		shortTitle = "Medical",
		description = "Battlefield care, trauma response and casualty stabilisation.",
		benefit = "25% lower development-credit cost in Medical.",
		access = "Progression opens at Level 5; certification is still required",
		minimumLevel = 5,
		colour = Color(92, 205, 176)
	},
	weapons = {
		id = "weapons",
		title = "HEAVY",
		fullTitle = "HEAVY DOCTRINE",
		shortTitle = "Heavy",
		description = "Heavy weapons, suppression and specialist arsenal clearance.",
		benefit = "25% lower development-credit cost in Heavy.",
		access = "Progression opens at Level 7; certification is still required",
		minimumLevel = 7,
		colour = Color(218, 162, 91)
	}
}

SWRP.CareerPathOrder = {
	"conditioning",
	"medical",
	"weapons",
	"aviation"
}

SWRP.StartingAptitudes = {
	mobility = {
		id = "mobility",
		title = "MOBILITY",
		attribute = "stamina",
		effect = "+10 Stamina",
		description = "A stronger base for sustained sprinting and rapid repositioning.",
		colour = Color(87, 190, 224)
	},
	resilience = {
		id = "resilience",
		title = "RESILIENCE",
		attribute = "endurance",
		effect = "+10 Endurance",
		description = "A tougher baseline for surviving prolonged front-line pressure.",
		colour = Color(92, 205, 176)
	},
	power = {
		id = "power",
		title = "POWER",
		attribute = "strength",
		effect = "+10 Strength",
		description = "A stronger baseline for load handling and weapon stability.",
		colour = Color(218, 162, 91)
	}
}

SWRP.StartingAptitudeOrder = {
	"mobility",
	"resilience",
	"power"
}

function SWRP.GetCareerPath(pathID)
	return SWRP.CareerPaths[tostring(pathID or "")]
end

function SWRP.IsCareerPath(pathID)
	return SWRP.GetCareerPath(pathID) ~= nil
end

function SWRP.GetStartingAptitude(aptitudeID)
	return SWRP.StartingAptitudes[tostring(aptitudeID or "")]
end

function SWRP.IsStartingAptitude(aptitudeID)
	return SWRP.GetStartingAptitude(aptitudeID) ~= nil
end

function SWRP.GetUpgradeTree()
	return SWRP.Datapad and SWRP.Datapad.UpgradeTree
end

function SWRP.GetCareerTarget(targetID)
	local tree = SWRP.GetUpgradeTree()

	if (!tree or !isfunction(tree.GetNode)) then
		return nil
	end

	local node = tree.GetNode(tostring(targetID or ""))

	if (!node or node.id == "root") then
		return nil
	end

	return node
end

function SWRP.GetCareerBranch(pathID)
	local tree = SWRP.GetUpgradeTree()

	if (!tree or !istable(tree.branches)) then
		return nil
	end

	for _, branch in ipairs(tree.branches) do
		if (branch.id == pathID) then
			return branch
		end
	end
end
