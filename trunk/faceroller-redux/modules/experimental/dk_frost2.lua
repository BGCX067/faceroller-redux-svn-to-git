-- Kallsuh frost dk module.
-- 12/06/2009
do
	local _, playerClass = UnitClass("player")
	if playerClass ~= "DEATHKNIGHT" then return end
end

local MODULE_NAME = "dkdwfrost_Kall"

local Faceroller = _G.Faceroller
local gsi = Faceroller.gsi

local b_ff
-- frost fewer
local b_bp
-- blood plague
local b_rm
-- rime
local b_km
-- killing machine
local b_soe
-- strenght of earth
local b_hw
-- Horn of winter

local function Init()
	local skills = {
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

	if buffs[b_soe].active == false then
		-- if totem not active
		if buffs[b_hw].active == false and spells[57623].cd < 2 then
			-- if horn of winter not active and cd on horn less then 2 sec
			return 57623
			-- do horn of winter
		end
	end

	if GetRuneType(1)==1 and GetRuneType(2)~=1 then
		-- if I have a spare blood rune use it!
		local _,_,cool_first = GetRuneCooldown(1)
		if cool_first==true then
			return 49930
		end
	end

	if GetRuneType(1)~=1 and GetRuneType(2)==1 then
		-- if I have a spare blood rune use it!
		local _,_,cool_first = GetRuneCooldown(2)
		if cool_first==true then
			return 49930
		end
	end

	v = myDebuffs[b_ff]
	-- if no frost fever, or frost fever less then 2 sec
	if v.active == false or v.time_left < 2 then
		return 49909
	end

	local v = myDebuffs[b_bp]
	-- if no blood plague or blood plague less then 2 sec
	if v.active == false or v.time_left < 2 then
		return 49921
	end

	v = buffs[b_km]
	if v.active == true then
		if buffs[b_rm].active == true then
			-- Howling blast, if both killing machine and rime are active
			return 51411
		end
	end

	v = buffs[b_rm]
	if v.active == true and v.time_left < 4 then
		-- Howling blast, if rime proc have less then 4 sec remaining
		return 51411
	end

	if Faceroller.power > 90 then
		-- frost strike if more then 90 runic power
		return 55268
	end

	if spells[55268].usable == 1 and myDebuffs[b_ff].time_left < 5 and buffs[b_km]. active == true then
		-- frost strike if forst strike is available, frost fever is about to end and killing machine in active
		-- do not want to waste a killing machine proc on a icy touch
		return 55268
	end

	if GetRuneType(3)==2 and GetRuneType(5)==3 then
		local _,_,cool_first = GetRuneCooldown(3)
		local _,_,cool_last = GetRuneCooldown(5)
		if cool_first==true and cool_last==true then
			-- obliterate on rune 3 and 5
			return 51425
		end
	end

	if GetRuneType(3)==2 and GetRuneType(6)==3 then
		-- obliterate on rune 3 and 6
		local _,_,cool_first = GetRuneCooldown(3)
		local _,_,cool_last = GetRuneCooldown(6)
		if cool_first==true and cool_last==true then

			return 51425
		end
	end

	if GetRuneType(4)==2 and GetRuneType(5)==3 then
		-- obliterate on rune 4 and 5
		local _,_,cool_first = GetRuneCooldown(4)
		local _,_,cool_last = GetRuneCooldown(5)
		if cool_first==true and cool_last==true then
			return 51425
		end
	end

	if GetRuneType(4)==2 and GetRuneType(6)==3 then
		-- obliterate on rune 4 and 6
		local _,_,cool_first = GetRuneCooldown(4)
		local _,_,cool_last = GetRuneCooldown(6)
		if cool_first==true and cool_last==true then
			return 51425
		end
	end

	if GetRuneType(1)==4 and GetRuneType(2)==4 then
		local _,_,cool_first = GetRuneCooldown(1)
		local _,_,cool_last = GetRuneCooldown(2)
		if cool_first==true and cool_last==true then
			-- obliterate on rune 1 and 2
			return 51425
		end
	end

	-- i want to be sure thato obliterate is not used on rune, for example, 1 and 5 leaving rune 2 death alone

	if GetRuneType(1) == 1 and GetRuneType (2) == 1 then
		if spells[49930].usable == 1 then
			-- blood strike one time if both blood rune not on CD (nor death)
			-- the second blood strike will be still done couse now we will have a spare blood rune
			return 49930
		end
	end

	if spells[55268].usable == 1 then
		-- frost strike if is usable
		return 55268
	end

	if spells[57623].cd <= 1 then
		-- horn of winter if is usable
		return 57623
	end

	return 0
	-- if nothing else can be done
end

Faceroller:RegisterModule(MODULE_NAME, Init, NextShot, nil)

