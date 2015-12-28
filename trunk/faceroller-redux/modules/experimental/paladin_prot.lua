--
-- lloydbates prot paladin module.
--
-- TODO:
--
-- - "More of a problem would the condition of having
-- Hammer of the Righteous and 1 or 2 points in
-- Improved Judgement. Not having these two talents
-- will break the rotation." => add talent check.
--
-- - config.
--
-- 11/15/2009
--
local _, class = UnitClass("player")
if class ~= "PALADIN" then return end

local Faceroller = _G.Faceroller
if not Faceroller then return end

local MODULE_NAME = "protpala"

-- basic 96969 rotation
local ROTATION = {
	[1] = 20271,	-- Judgement of Light
	[2] = 53595,	-- Hammer of the Righteous
	[3] = 48952,	-- Holy Shield(Rank 6)	
	[4] = 61411,	-- Shield of Righteousness(Rank 2)
	[5] = 48819,	-- Consecration(Rank 8)	
}

-- build a skill list
local function Init()
	local skills = {}
	for k, v in pairs(ROTATION) do
		skills[v] = 0
	end
	return skills
end

-- decide what spell to use next
local function NextSpell(gcd, spells, _, _, _)
	local th = max(.5, gcd) + .1

	-- iterate rotation and stop as soon as we've found a usable spell
	for k, v in ipairs(ROTATION) do
		if spells[v].cd < th and spells[v].usable == 1 then
			return v
		end
	end

	-- default to show
	return 20271	-- Judgement of Light
end

-- say hello to faceroller
Faceroller:RegisterModule(MODULE_NAME, Init, NextSpell, nil)
