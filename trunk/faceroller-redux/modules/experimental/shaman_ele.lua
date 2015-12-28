-- added: 11/14/2009
do
	local _, playerClass = UnitClass("player")
	if playerClass ~= "SHAMAN" then return end
end


local spells = {
	[57960] = {		-- Water Shield
		priority = 600,
		type = "buff",
	},

	[49233] = {		-- Flame Shock
		priority = 500,
		type = "debuff",
		mine = true,
		time_left = 2,
	},

	[60043] = {		-- Lava Burst
		priority = 400,
		type = "spell",
	},

	[49271] = {		-- Chain Lightning
		priority = 300,
		type = "spell",
	},

	[49238] = {		-- Lightning Bolt
		priority = 200,
		type = "spell",
	},
}


Faceroller:EasyRegister("experimental_shaman_ele", spells)
