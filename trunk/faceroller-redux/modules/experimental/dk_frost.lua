-- hectolights frost dk module.
-- 11/20/2009
do
	local _, playerClass = UnitClass("player")
	if playerClass ~= "DEATHKNIGHT" then return end
end

local MODULE_NAME = "dkdwfrost"

local Faceroller = _G.Faceroller
local gsi = Faceroller.gsi

local b_ff
local b_bp
local b_rm
local b_km
local b_soe
local b_hw

local function Init()
	local skills = 
	{
		-- howling blast 
		[51411] = 0,
		-- bs
		[49930] = 0,
		-- obliterate
		[51425] = 0,
		-- frost strike
		[55268] = 0,
		-- how
		[57623] = 0,
	}

	Faceroller:RegisterBuff(51124)
	Faceroller:RegisterBuff(59052)
	Faceroller:RegisterBuff(57623)

	-- strength of earth totem
	Faceroller:RegisterBuff(58646)

	Faceroller:RegisterDebuff(55078,true)
	Faceroller:RegisterDebuff(55095,true)

	b_bp = gsi[55078]
	b_ff = gsi[55095]
	b_hw = gsi[57623]

	b_km = gsi[51124]
	b_rm = gsi[59052]
	b_soe = gsi[58646]
	return skills
end

local function NextShot(gcd, spells, buffs, debuffs, myDebuffs)
	local th = max (0.5, gcd)
	th = th + 0.1

	local v = myDebuffs[b_bp]
	-- blood plague
	if v.active == false or v.time_left < 3 then
		return 49921
	end
	v = myDebuffs[b_ff]
	-- frost fever
	if v.active == false or v.time_left < 3 then
		return 49909
	end

	if buffs[b_soe].active == false then
		if buffs[b_hw].active == false and spells[57623].cd < 2 then
			return 57623
		end
	end

	v = buffs[b_km]
	if v.active == true then
		if buffs[b_rm].active == true then
			return 51411
		elseif spells[55268].usable == 1 then
			return 55268
		end
	end
	v = buffs[b_rm]
	if v.active == true then
		return 51411
	end
	local n = 49930
	-- blood strike
	if GetRuneType(1) == 4 and GetRuneType(2) == 4 then
		n = 0
	end
	-- frost strike
	if spells[55268].usable == 1 then
		n = 55268
	end
	-- obliterate
	if spells[51425].usable == 1 then
		n = 51425
	end

	return n     
end

Faceroller:RegisterModule(MODULE_NAME, Init, NextShot, nil)

