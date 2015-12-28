-- added: 11/14/2009
--
-- update:
-- added config options.
--
do
	local _, playerClass = UnitClass("player")
	if playerClass ~= "MAGE" then return end
end

local b_ab
local b_mb

local opt

local function Init(opts)
	Faceroller:RegisterBuff (36032, false, true)	-- Arcane Blast
	Faceroller:RegisterBuff (44401)			-- Missle Barrage

	if not opts.ab_stack then
		opts.ab_stack = 4
		opts.use_abar = false
	end

	opts.gui = {
		uab = {
			type = "toggle",
			name = "Use Arcane Barrage",
			get = function ()
				return opts.use_abar
			end,
			set = function (i, v)
				opts.use_abar = v
			end,
		},
		abs = {
			type = "range",
			name = "Arcane Blast Stack",
			min = 1,
			max = 4,
			step = 1,
			get = function ()
				return opts.ab_stack
			end,
			set = function (i, v)
				opts.ab_stack = v
			end,
		},
	}

	opt = opts

	b_ab = Faceroller.gsi[36032]
	b_mb = Faceroller.gsi[44401]
	return {}
end


local function Next(gcd, spells, buffs, tarDbuffs, tarMyDebuffs, pDebuffs)
	local th = max(0.5, gcd) + 0.1
	local v


	-- check for Arcane Blast buff
	v = pDebuffs[b_ab]

	-- if it's not up or we have less then ab_stack stacks, use Arcane Blast
	if not v.active or v.count < opt.ab_stack then
		return 42897
	end

	-- check for Missle Barrage
	v = buffs[b_mb]

	-- if it's up, use Arcane Missle
	if v.active and v.time_left > 0.5 then
		return 42846
	end

	-- else use Arcane Barrage, if we should
	if opt.use_abar then
		return 44781
	end

	-- else use Arcane Missle
	return 42846
end


Faceroller:RegisterModule("experimental_mage_arcane", Init, Next, nil)
