do
	local _, playerClass = UnitClass("player")
	if playerClass ~= "HUNTER" then return end
end

local MODULE = "simplehunter"
local Faceroller = _G["Faceroller"]
local gsi = Faceroller.gsi

local options
local skills

local have_readiness = false
local have_bw = false
local is_mm = false
local is_sv = false
local ihm = false
local wth = 0.8

local b_serpent
local b_hm
local b_iss
local b_es
local b_st

local abrevtoid = {
	["ars"] = 49045,		-- arcane shot
	["ais"] = 49050,		-- aimed shot
	["ks"] = 61006,			-- kill shot
	["ss"] = 49052,			-- steady shot
	["srs"] = 49001,		-- serpent sting
	["cs"] = 53209,			-- chimera shot
	["es"] = 60053,			-- explosive shot
	["ba"] = 63672,			-- black arrow
	["multi"] = 49048,		-- multi-shot
}


local function suggest()
	local have_ais = Faceroller:HasSpell (49050)
	local r = ""

	if Faceroller:HasSpell (53209) == true then	-- check for cs
		if have_ais == true then
			r = "ks/srs/cs/ais/ars/ss"
		else
			r = "ks/srs/cs/multi/ars/ss"
		end
	elseif Faceroller:HasSpell (60053) == true then	-- check for es
		if have_ais == true then
			r = "ks/es/ba/srs/ais/ss"
		else
			r = "ks/es/ba/srs/multi/ss"
		end
	else
		if have_ais == true then		-- neither (you still have a pet, though :)
			r = "ks/srs/ais/ars/ss"
		else
			r = "ks/srs/multi/ars/ss"
		end
	end
	return r
end


--
-- keep track of corner indicator colors to avoid calling
-- CornerIndicatorSetColor on every update.
--
local ci_tl_c = 0
local ci_tr_c = 0
local ci_bl_c = 0
local ci_br_c = 0

local Init = function(opts)
	skills = {}
	options = opts

	if not opts.priority_order then
		opts.priority_order = suggest ()
		opts.hunters_mark = true
		opts.iss_limbo = true
		opts.wth = 0.8
	end

	-- gui options elements. we don't have to do this but it looks nicer.
	opts.gui = {
		shots = {
			type = "input",
			name = "Shots",
			get = function ()
				return opts.priority_order
			end,
			set = function (i, v)
				opts.priority_order = v
			end,
		},

		hm = {
			type = "toggle",
			name = "Hunter's Mark",
			get = function ()
				return opts.hunters_mark
			end,
			set = function (i, v)
				opts.hunters_mark = v
			end,
		},

		iss = {
			type = "toggle",
			name = "ISS Limbo",
			get = function ()
				return opts.iss_limbo
			end,
			set = function (i, v)
				opts.iss_limbo = v
			end,
		},

		wth = {
			type = "range",
			name = "wait",
			min = 0.1,
			max = 1.4,
			step = 0.05,
			get = function ()
				return opts.wth
			end,
			set = function (i, v)
				opts.wth = v
			end,
		},
	}

	wth = opts.wth

	is_mm = Faceroller:HasSpell (53209)
	is_sv = Faceroller:HasSpell (60053)

	local tbl = {strsplit("/", opts.priority_order)}
	local idx = 1

	for _, v in pairs(tbl) do
		local id = abrevtoid[string.lower(v)]

		if Faceroller:HasSpell (id) == true then
			table.insert(skills, id, idx)
			idx = idx + 1
		else
			print (MODULE .. ": Error: you don't have " .. v .. "?")
		end
	end

	Faceroller:RegisterDebuff(49001, true)

	-- check for ihm talent and hm glyph
	ihm = false

	if opts.hunters_mark == true then
		local _, _, _, _, c, m = GetTalentInfo(2, 5)
		if c > 0 then
			ihm = true
		end

		ihm  = Faceroller:HasGlyph(56829)

		-- if we have either, we want to check for our hunter's mark.
		-- else, any hunter's mark will do.
		Faceroller:RegisterDebuff(53338, ihm)
	end

	if opts.iss_limbo == true and is_mm == true then
		Faceroller:RegisterBuff(53221)
		b_iss = gsi[53221]
	end

	if is_sv == true then
		Faceroller:RegisterDebuff(60053, true)
		b_es = gsi[60053]

		Faceroller:RegisterBuff(53304)
		b_st = gsi[53304]
	end

	b_serpent = gsi[49001]
	b_hm = gsi[53338]


	-- Rapid Fire
	table.insert(skills, 3045, 101)

	-- Readiness
	have_readiness = false
	if Faceroller:HasSpell (23989) == true then
		have_readiness = true
		table.insert(skills, 23989, 101)
	end

	-- Bestial Wrath
	have_bw = false
	if Faceroller:HasSpell (19574) == true then
		have_bw = true
		table.insert(skills, 19574, 102)
	end

	-- Feign Death
	table.insert (skills, 5384, 103)

	-- Misdirection
	table.insert (skills, 34477, 104)

	print (MODULE .. ": now using: " .. opts.priority_order)
	print (MODULE .. ": wait time: " .. wth)

	-- module init resets corner indicators. make sure they get updated.
	ci_tl_c = 0
	ci_tr_c = 0
	ci_bl_c = 0
	ci_br_c = 0

	return skills
end


local NextShot = function(gcd, spells, buffs, debuffs, myDebuffs)
	-- Rapid Fire corner indicator: top left
	local cd = spells[3045].cd
	if cd < 2 then
		if ci_tl_c ~= 1 then
			Faceroller:CornerIndicatorSetColor ("TOPLEFT", 0, 1, 0, 1)
			ci_tl_c = 1
		end
	elseif cd < 30 then
		if ci_tl_c ~= 3 then
			Faceroller:CornerIndicatorSetColor ("TOPLEFT", 1, 1, 0, 1)
			ci_tl_c = 3
		end
	else
		if ci_tl_c ~= 2 then
			Faceroller:CornerIndicatorSetColor ("TOPLEFT", 1, 0, 0, 1)
			ci_tl_c = 2
		end
	end

	--
	-- spec specific stuff: top right
	--

	-- Readiness corner indicator
	if have_readiness == true then
		local cd = spells[23989].cd
		if cd < 2 then
			if ci_tr_c ~= 1 then
				Faceroller:CornerIndicatorSetColor ("TOPRIGHT", 0, 1, 0, 1)
				ci_tr_c = 1
			end
		elseif cd < 30 then
			if ci_tr_c ~= 3 then
				Faceroller:CornerIndicatorSetColor ("TOPRIGHT", 1, 1, 0, 1)
				ci_tr_c = 3
			end
		else
			if ci_tr_c ~= 2 then
				Faceroller:CornerIndicatorSetColor ("TOPRIGHT", 1, 0, 0, 1)
				ci_tr_c = 2
			end
		end
	end

	-- Bestial Wrath corner indicator
	if have_bw == true then
		local cd = spells[19574].cd
		if cd < 2 then
			if ci_tr_c ~= 1 then
				Faceroller:CornerIndicatorSetColor ("TOPRIGHT", 0, 1, 0, 1)
				ci_tr_c = 1
			end
		elseif cd < 20 then
			if ci_tr_c ~= 3 then
				Faceroller:CornerIndicatorSetColor ("TOPRIGHT", 1, 1, 0, 1)
				ci_tr_c = 3
			end
		else
			if ci_tr_c ~= 2 then
				Faceroller:CornerIndicatorSetColor ("TOPRIGHT", 1, 0, 0, 1)
				ci_tr_c = 2
			end
		end
	end

	-- sniper training corner indicator
	if is_sv == true then
		local st = buffs[b_st]

		if st.active == false then
			if ci_tr_c ~= 1 then
				Faceroller:CornerIndicatorSetColor ("TOPRIGHT", 1, 0, 0, 1)
				ci_tr_c = 1
			end
		else
			if st.time_left > 8 then
				if ci_tr_c ~= 2 then
					Faceroller:CornerIndicatorSetColor ("TOPRIGHT", 0, 1, 0, 1)
					ci_tr_c = 2
				end
			else
				if ci_tr_c ~= 3 then
					Faceroller:CornerIndicatorSetColor ("TOPRIGHT", 1, 1, 0, 1)
					ci_tr_c = 3
				end
			end
		end
	end

	-- bottom left: Feign Death
	local cd = spells[5384].cd
	if cd < 1.5 then
		if ci_bl_c ~= 1 then
			Faceroller:CornerIndicatorSetColor ("BOTTOMLEFT", 0, 1, 0, 1)
			ci_bl_c = 1
		end
	elseif cd < 3 then
		if ci_bl_c ~= 3 then
			Faceroller:CornerIndicatorSetColor ("BOTTOMLEFT", 1, 1, 0, 1)
			ci_bl_c = 3
		end
	else
		if ci_bl_c ~= 2 then
			Faceroller:CornerIndicatorSetColor ("BOTTOMLEFT", 1, 0, 0, 1)
			ci_bl_c = 2
		end
	end

	-- bottom right: Misdirection
	local cd = spells[34477].cd
	if cd < 1.5 then
		if ci_br_c ~= 1 then
			Faceroller:CornerIndicatorSetColor ("BOTTOMRIGHT", 0, 1, 0, 1)
			ci_br_c = 1
		end
	elseif cd < 3 then
		if ci_br_c ~= 3 then
			Faceroller:CornerIndicatorSetColor ("BOTTOMRIGHT", 1, 1, 0, 1)
			ci_br_c = 3
		end
	else
		if ci_br_c ~= 2 then
			Faceroller:CornerIndicatorSetColor ("BOTTOMRIGHT", 1, 0, 0, 1)
			ci_br_c = 2
		end
	end


	-- hunter's mark
	if options.hunters_mark == true then
		local v

		if ihm == false then
			v = debuffs[b_hm]
		else
			v = myDebuffs[b_hm]
		end

		if v.active == false or v.time_left < 2 then
			return 53338
		end
	end

	local th = max (wth, gcd)
	th = th + 0.1

	local n = 0
	local p = 100

	for k, v in pairs(spells) do
		if v.cd < th then
			if v.data < p then
				if k == 61006 then
					if spells[61006].usable == 1 and spells[61006].enabled ~= 1 then
						n = k
						p = v.data
					end
				elseif k == 49001 then
					local b = myDebuffs[b_serpent]
					if b.active ~= true or b.time_left < 2 then
						n = k
						p = v.data
					end
				elseif k == 60053 then
					-- don't even check for lnl, just if es debuff is still up.
					local b = myDebuffs[b_es]
					if b.active == true and b.time_left > 0.7 then
						return 0
					end
					n = k
					p = v.data
				else
					n = k
					p = v.data
				end
			end
		end
	end

	if options.iss_limbo == true and is_mm == true then
		local iss = false
		local v = buffs[b_iss]

		if v.active == true and v.time_left > 1 then
			iss = true
		end

		-- with iss, choose Multi-Shot over Aimed
		if n == 49050 and iss == true then
			n = 49048
		end

		-- choose steady over arcane with iss up.
		if n == 49045 and iss == true then
			n = 49052
		end
	end

	return n
end


local Options = function(cmd)
	if cmd == nil or cmd == "help" then
		print (MODULE .. ": Options:")
		print (MODULE .. ": pr <X> - use priority ordering X.")
		print (MODULE .. ": wth <X> - set wait time to X.")
		print (MODULE .. ": suggest - set 'default' for your current spec.")
		print (MODULE .. ": iss - with iss procs, choose ss over ars and multi over ais.")
		print (MODULE .. ": abrev - print all abreviations understood by the module.")
		print (MODULE .. ": Currently using: " .. options.priority_order)
		return
	end

	local Cmd, Args = strsplit(" ", cmd:lower(), 2)

	if Cmd == "pr" then
		options.priority_order = Args
	elseif Cmd == "suggest" then
		options.priority_order = suggest()
	elseif Cmd == "hm" then
		if options.hunters_mark == true then
			options.hunters_mark = false
			print (MODULE .. ": disabled suggesting hunter's mark")
		else
			options.hunters_mark = true
			print (MODULE .. ": enabled suggesting hunter's mark")
		end
	elseif Cmd == "iss" then
		if options.iss_limbo == true then
			options.iss_limbo = false
			print (MODULE .. ": enabled iss limbo.")
		else
			options.iss_limbo = true
			print (MODULE .. ": disabled iss limbo.")
		end
	elseif Cmd == "abrev" then
		print (MODULE .. ": Abreviation: Spell:")
		for k, v in pairs(abrevtoid) do
			print (MODULE .. ": " .. k .. ": " .. gsi[v])
		end
	elseif Cmd == "wth" then
		x = tonumber(Args)
		options.wth = x
		wth = x
	end
end


--
-- for profiling
--
Faceroller_SimpleHunter = {}
Faceroller_SimpleHunter.init = Init
Faceroller_SimpleHunter.nextskill = NextShot


Faceroller:RegisterModule(MODULE, Init, NextShot, Options)
