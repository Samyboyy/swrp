-- swrp/plugins/onboarding/libs/sh_career_paths.lua
-- Shared presentation helpers for the non-binding career target selected at creation.

SWRP = SWRP or {}

SWRP.CareerPaths = {
	conditioning = {
		id = "conditioning",
		title = "PHYSICAL",
		fullTitle = "PHYSICAL CONDITIONING",
		shortTitle = "Physical",
		description = "Durability, mobility and front-line resilience.",
		colour = Color(73, 154, 219)
	},
	aviation = {
		id = "aviation",
		title = "AVIATION",
		fullTitle = "AVIATION",
		shortTitle = "Aviation",
		description = "Vehicle and flight authorisations.",
		colour = Color(87, 190, 224)
	},
	medical = {
		id = "medical",
		title = "MEDICAL",
		fullTitle = "MEDICAL",
		shortTitle = "Medical",
		description = "Field care and trauma certifications.",
		colour = Color(92, 205, 176)
	},
	weapons = {
		id = "weapons",
		title = "HEAVY",
		fullTitle = "HEAVY SPECIALIST",
		shortTitle = "Heavy",
		description = "Heavy weapons and specialist arsenal clearance.",
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
