--
-- Basicly, this is the same as Faceroller_ExampleModule,
-- but instead of doing everything by hand, the Easy*
-- functions are used.
--
-- This module is only suitable for sv hunters and will:
--
-- 1. suggest kill shot, if target is below 20% health and
--    it's off cooldown.
-- 2. suggest hunter's mark, if not on the target.
-- 3. suggest serpent sting, if your sting is not on the target.
-- 4. if off cooldown, suggest (ordered by priority):
-- 	- black arrow,
-- 	- explosive shot or
-- 	- aimed shot
-- 5. suggest steady shot otherwise.
--
-- lock and load (and trinket procs, temporary buffs etc.
-- for that matter) is not specialy considered. You will
-- have to watch for your self to make sure to not clip ES.
--


-- if the module would be useless, don't load it.
do
	local _, playerClass = UnitClass("player")
	if playerClass ~= "HUNTER" then return end
end


-- name of your module, used only below in RegisterModule.
-- XXX: DON'T FORGET TO EDIT THIS!
local MODULE_NAME = "easyexample"



-- spells we want the cooldown to be tracked for.
-- the keys have to be spell ids. The values can
-- be anything.
--
-- But since we intend to use the EasySetup and
-- EasyChooseSpell, the data values are a dictionary.
-- The values should be self explanatory.
--
local skills = {
	[61006] = {		-- kill shot
		priority = 500,
		type = "spell",
		reactive = true,
	},

	[53338] = {		-- hunter's mark
		priority = 450,
		type = "debuff",
	},

	[60053] = {		-- explosive shot
		priority = 400,
		type = "spell",
	},

	[63672] = {		-- black arrow
		priority = 300,
		type = "spell",
	},

	[49001] = {		-- serpent sting
		priority = 250,
		type = "debuff",
		mine = true,
		time_left = 3,
	},

	[49050] = {		-- aimed shot
		priority = 200,
		type = "spell",
	},

	[49052] = {		-- steady shot
		priority = 50,
		type = "spell",
	},

	--
	-- indicators
	--
	[3045] = {		-- rapid fire
		priority = 0,
		type = "indicator",
		pos = "TOPLEFT",
		show = "COOLDOWN",
	},

	[53304] = {		-- sniper training
		priority = 0,
		type = "indicator",
		pos = "BOTTOMLEFT",
		show = "BUFF",
		time_left = 6,
		nospell = true,
	}
}


-- get a reference to the Faceroller addon.
local Faceroller = _G["Faceroller"]

-- register the module.
Faceroller:EasyRegister(MODULE_NAME, skills)
