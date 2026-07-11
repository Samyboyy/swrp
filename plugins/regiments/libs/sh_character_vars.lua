-- swrp/plugins/regiments/libs/sh_character_vars.lua
-- Extra service-record fields. Existing onboarding identity fields are reused.

local function registerIfMissing(name, data)
	if (ix.char.vars[name]) then
		return
	end

	ix.char.RegisterVar(name, data)
end

registerIfMissing("unit", {
	field = "unit",
	fieldType = ix.type.string,
	default = "",
	bNoDisplay = true
})

registerIfMissing("billet", {
	field = "billet",
	fieldType = ix.type.string,
	default = "",
	bNoDisplay = true
})


registerIfMissing("unitType", {
	field = "unit_type",
	fieldType = ix.type.string,
	default = "",
	bNoDisplay = true
})

registerIfMissing("serviceStatus", {
	field = "service_status",
	fieldType = ix.type.string,
	default = "active",
	bNoDisplay = true
})

registerIfMissing("enlistedAt", {
	field = "enlisted_at",
	fieldType = ix.type.number,
	default = 0,
	bNoDisplay = true
})

registerIfMissing("lastPromotionAt", {
	field = "last_promotion_at",
	fieldType = ix.type.number,
	default = 0,
	bNoDisplay = true
})

registerIfMissing("specialisations", {
	field = "specialisations",
	fieldType = ix.type.string,
	default = "[]",
	bNoNetworking = true,
	bNoDisplay = true
})

registerIfMissing("certifications", {
	field = "certifications",
	fieldType = ix.type.string,
	default = "[]",
	bNoNetworking = true,
	bNoDisplay = true
})

registerIfMissing("commendations", {
	field = "commendations",
	fieldType = ix.type.string,
	default = "[]",
	bNoNetworking = true,
	bNoDisplay = true
})
