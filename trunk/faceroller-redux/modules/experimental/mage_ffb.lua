-- added: 11/14/2009
do
	local _, playerClass = UnitClass("player")
	if playerClass ~= "MAGE" then return end
end


local spells = {
	[12873] = {		-- Improved Scorch
		priority = 400,
		type = "debuff",
		time_left = 3,
		nospell = true,
		retid = 42859,
	},

	[55360] = {		-- Living Bomb
		priority = 300,
		type = "debuff",
		mine = true,
		time_left = 0,
	},

	[48108] = {		-- Hot Streak
		priority = 200,
		type = "buff",
		nospell = true,
		up = true,
		retid = 42891,
	},

	[47610] = {		-- Frostfire Bolt
		priority = 100,
		type = "spell",
	},

}


Faceroller:EasyRegister("experimental_mage_ffb", spells)
