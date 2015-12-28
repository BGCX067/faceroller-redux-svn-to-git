-- 12/05/2009 (prot warrior module by Opaque)
--
-- "Sergeant Slawter's" Protection Warrior experimental module 11/29/09
-- Using the priority system of: "Shield Slam > Shockwave > Concussion Blow > Revenge > Devastate"-- This mod assumes you have the Focused Rage talent for the power setting on Revenge (if not change it from 2 to 5).

do
	local _, playerClass = UnitClass("player")
	if playerClass ~= "WARRIOR" then return end
end

local Faceroller = _G["Faceroller"]
local gsi = Faceroller.gsi

local spells = {

	[30356] = {	-- shield slam
		priority = 450,
		type = "spell",
	},

	[46968] = {	-- shockwave
		priority = 400,
		type = "spell",
	},

	[12809] = {	-- concussion blow
		priority = 350,
		type = "spell",
	},	

	[30357] = {	-- revenge
		priority = 300,
		type = "spell",
		reactive = true,
		--power = 2,
	},

	[30022] = {	-- devastate
		priority = 100,
		type = "spell",
	},
}

Faceroller:EasyRegister("Warrior_Protection", spells)

