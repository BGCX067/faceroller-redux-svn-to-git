--
-- simple Enhancement Shaman module.
--
do
	local _, playerClass = UnitClass("player")
	if playerClass ~= "SHAMAN" then return end
end

local Faceroller = _G["Faceroller"]

local b_maelstrom
local b_lightning

local skills = {
	[17364] = {
		priority = 400,
		type = "spell",
	},		-- Stormstrike

	[8042] = {
		priority = 200,
		type = "spell",
	},		-- Earth Shock

	[60103] = {
		priority = 100,
		type = "spell",
	},		-- Lava Lash

	[324] = {
		priority = 500,
		type = "buff",
	},		-- lightning shield


	-- corner indicators
	[30823] = {	-- shamanistic rage
		priority = 0,
		type = "indicator",
		pos = "TOPLEFT",
		show = "COOLDOWN",
	},

	[51533] = {	-- feral spirit
		priority = 0,
		type = "indicator",
		pos = "TOPRIGHT",
		show = "COOLDOWN",
	},

}


local Init = function()
	if Faceroller:EasySetup (skills) == nil then
		return nil, "Missing Spell?"
	end

	Faceroller:RegisterBuff(51532)	-- maelstrom weapon
	b_maelstrom = Faceroller.gsi[51532]
	b_lightning = Faceroller.gsi[324]
	return skills
end


local NextShot = function(gcd, spells, buffs, debuffs, myDebuffs)
	local th = max(1.0, gcd) + 0.1
	local n = 0

	-- check if we have 5 stacks of maelstrom weapon
	local v = buffs[b_maelstrom]
	if v.active and v.count == 5 and v.time_left > 1 then
		return 403
	end

	n = Faceroller:EasyChooseSpell(th)

	if n == 0 then
		-- nothing to do. refresh lightning shield.
		if buffs[b_lightning].count < 6 then
			return 324
		end
	end

	return n
end


Faceroller:RegisterModule("enh", Init, NextShot, nil)
