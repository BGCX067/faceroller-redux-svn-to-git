--
-- example module for Faceroller. Rather then a module
-- considering all if's and when's, this is keept simple
-- for the sake of being an example module.
--
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
local MODULE_NAME = "example"


-- get a reference to the Faceroller module
local Faceroller = _G["Faceroller"]


-- gsi stands for GetSpellInfo. To avoid having to call
-- the function over and over to get spell names from
-- spell ids, the table is used.
local gsi = Faceroller.gsi


-- for convenience. b_serpent is a bit easier to understand
-- then gsi[49001].
local b_serpent
local b_hm


--
-- init function. This is called, well, when the module
-- is initialized (when doing /fr mod <X> or switching
-- dual spec, when logging in or changing module options
-- with /fr opt <X>).
--
-- If it fails, it should return nil. An optional second
-- return value can be returned that will then be print'ed
-- Otherwise a table has to be returned, containing the
-- spells we want cooldown information for.
--
local Init = function()
	-- spells we want the cooldown to be tracked for.
	-- the keys have to be spell ids. The values can
	-- be anything (see comment for NextShot below,
	-- Faceroller_SimpleHunter.lua makes some use of
	-- these values).
	local skills = {
		[61006] = 0,		-- kill shot
		[49050] = 0,		-- aimed shot
		[60053] = 0,		-- explosive shot
		[63672] = 0,		-- black arrow
	}

	-- check if player has all spells in his spell book.
	for k, v in pairs(skills) do
		if Faceroller:HasSpell (k) == false then
			return nil, "spell not found"
		end
	end

	-- hunter's mark
	if Faceroller:HasSpell (53338) == false then
		return nil, "spell not found (hm)"
	end

	-- serpent sting
	if Faceroller:HasSpell (49001) == false then
		return nil, "spell not found (sp)"
	end

	-- register for debuffs we want to track:

	-- serpent sting, but only our own.
	Faceroller:RegisterDebuff(49001, true)

	-- any hunter's mark
	Faceroller:RegisterDebuff(53338)

	-- for convenience (used below).
	b_serpent = gsi[49001]
	b_hm = gsi[53338]

	return skills
end


--
-- function to determine the next spell to use.
--
-- the args are:
--
-- gcd:		time remaining on the global cooldown.
--
-- spells:	a table where the keys are spell ids.
-- 		data fields of interest:
--
-- 		cd:	 cooldown remaining in seconds.
--
-- 		data:	 same value, as used in the table returned by init.
--
-- 		usable:	 if 1, the spell is usable (for reactive abilities).
--
--		enabled: for spells that are used on the next melee swing,
--			 enabled is set to 1, if they are active.
--
-- buffs:	buffs on you. Only buffs you cast on yourself can appear here.
--		For a buff to be tracked you need to register it with
--		Faceroller:RegisterBuff(spellid).
--
-- debuffs:	debuffs on target. For a debuff to appear, you need to register
-- 		for it with Faceroller:RegisterDebuff(spellid). See the Init
-- 		function above for examples.
--
-- myDebuffs:	debuffs that we put up on the target. Need prior registration
-- 		with Faceroller:RegisterDebuff(spellid, true) (Note the second
-- 		argument). See the init function above for examples.
--
--
-- buffs, debuffs and myDebuffs all have the same format:
--
--	t[n] = {
--		time_left = e,
--		count = x,
--		active = true/false,
--		icon = "<path to icon of buff/debuff>",
--	}
--
-- where n is the name of the buff or debuff. When the buff or
-- debuff is expired, active is false. It is not enough to check
-- for time_left! For example, auras, totems and hunter
-- aspects don't have an expiration time.
--
local NextShot = function(gcd, spells, buffs, debuffs, myDebuffs)
	-- threshold to suggest an skill that is still on cooldown.
	local th = max (0.5, gcd)
	th = th + 0.1

	-- check if kill shot can be used.
	if spells[61006].cd < th and spells[61006].usable == 1 then
		return 61006
	end

	-- check for hunter's mark.
	local v = debuffs[b_hm]

	-- if the debuff is not active or about to expire,
	-- return it right away.
	if v.active == false or v.time_left < 2 then
		return 53338
	end

	-- same for Serpent Sting.
	local v = myDebuffs[b_serpent]
	if v.active == false or v.time_left < 2 then
		return 49001
	end

	-- check for various spells:

	-- we will use n as the return value. Setting it here
	-- to steady shot, if nothing else is ready, it will
	-- be used.
	local n = 49052

	-- check if aimed shot can be used. if it can be used
	-- or the cooldown will be ready shortly, set it as
	-- our new return value (thus overwriting steady shot).
	if spells[49050].cd < th then
		n = 49050
	end

	-- do the same with explosive shot ...
	if spells[60053].cd < th then
		n = 60053
	end

	-- ... and for black arrow
	if spells[63672].cd < th then
		n = 63672
	end

	-- now return n. by checking the spells in reverse
	-- order of priority (as lined out in the comment at
	-- the beginning of this file), we make sure the
	-- highest priority spell would overwrite n last.
	return n
end


-- register the module. (the last arg, which we pass as
-- nil here, would be the function to handle module options.
-- see Faceroller_SimpleHunter.lua for an example on
-- how to do that).
Faceroller:RegisterModule(MODULE_NAME, Init, NextShot, nil)
