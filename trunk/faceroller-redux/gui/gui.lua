local Faceroller_GUI = {}
local GetSpellName = GetSpellName or GetSpellBookItemName

Faceroller_GUIDB = {}
Faceroller_GUIDB.use_bf = true
Faceroller_GUIDB.lib_bf = {nil, nil, nil}
Faceroller_GUIDB.editor_text = "local spells = {\n\n}\n"

-- stub for localization.
local L = setmetatable({}, {
	__index = function (t, v)
		t[v] = v
		return v
	end
})

local AceDialog = nil
local guess_spell_text = L["Drag spell from your spellbook here to get the spells id"]


local function Print(x)
	DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Faceroller_GUI:|r " .. x)
end


--
-- register with button facade. also used to check if lbf is loaded.
--
function Faceroller_GUI:BFRegister(test)
	local lbf = LibStub("LibButtonFacade", true)

	if not lbf then
		return false
	end

	if test then
		return true
	end

	if not Faceroller_GUIDB.use_bf then
		return
	end

	local g = lbf:Group ("Faceroller", nil, nil)
	local d = Faceroller.DisplayFrame

	if g == nil or d == nil then
		return
	end

	d.overlay:SetAlpha (0)
	g:AddButton (d, {
		Icon = d.icon,
		Cooldown = d.cd,
	})

	local skin = Faceroller_GUIDB.lib_bf[1]
	local gloss = Faceroller_GUIDB.lib_bf[2]
	local bwhatever = Faceroller_GUIDB.lib_bf[3]

	-- called when the skin is changed. when bf is loaded,
	-- it changes all skins to the default (as set in the
	-- bf options). How nice the lbf doc points that out!
	-- Oh wait, it doesn't ...
	local lbf_cb = function (arg, s, gl, b)
		if arg.is_init == 0 then
			arg.is_init = 1

			if skin ~= nil then
				g:Skin (skin, gloss, bwhatever)
			else
				Faceroller_GUIDB.lib_bf = {s, gl, b}
				g:Skin (s, gl, b)
			end
			return
		end

		Faceroller_GUIDB.lib_bf = {s, gl, b}
	end

	lbf:RegisterSkinCallback ("Faceroller", lbf_cb, {is_init = 0})
end


--
-- option tables
--
local options = {
	type = "group",
	name = "Faceroller",
	args = {}
}


--
-- general
--
options.args.general = {
	type = "group",
	order = 1,
	childGroups = "tab",
	name = L["Appearance"],
	desc = L["Options to chance the appearance of the Faceroller frame."],
	args = {
		frame = {
			type = "group",
			inline = true,
			order = 1,
			name = " ",	-- don't delete the space
			desc = "",
			args = {
				lock = {
					type = "toggle",
					order = 1,
					name = L["Lock frame"],
					desc = L["lock / unlock the Faceroller frame to move it."],
					get = function ()
						return FacerollerDB.locked
					end,
					set = function()
						Faceroller:LockUnlock ()
					end,
				},

				anim = {
					type = "toggle",
					order = 2,
					name = L["Fade animations"],
					desc = L["Fade the Faceroller frame in when you target something and fade it out when you loose your target."],
					get = function ()
						return FacerollerDB.anim_fade == 1
					end,
					set = function()
						Faceroller:setAnim ()
					end,
				},

				power = {
					type = "toggle",
					order = 3,
					name = L["Power check"],
					desc = L["Color the Faceroller frame blue when you can't use a spell."],
					get = function ()
						return FacerollerDB.powercheck == 1
					end,
					set = function()
						Faceroller:PowerCheck ()
					end,
				},

				range = {
					type = "toggle",
					order = 4,
					name = L["Range check"],
					desc = L["Color the Faceroller frame red when you are out of range. This uses the currently suggested for you as reference."],
					get = function ()
						return FacerollerDB.rangecheck == 1
					end,
					set = function()
						Faceroller:RangeCheck ()
					end,
				},

				scale = {
					type = "range",
					order = 5,
					min = 0.1,
					max = 4.0,
					step = 0.05,
					name = L["Scale"],
					desc = L["Changes the size of the frame."],
					get = function ()
						return FacerollerDB.framescale
					end,
					set = function(i, v)
						Faceroller:setScale (v)
					end,
				},

				alpha = {
					type = "range",
					order = 6,
					min = 0.05,
					max = 1.0,
					step = 0.05,
					isPercent = true,
					name = L["Alpha"],
					desc = L["Changes the opacity of the frame."],
					get = function ()
						return FacerollerDB.framealpha
					end,
					set = function(i, v)
						Faceroller:setAlpha (v)
					end,
				}
			}
		},

		misc = {
			type = "group",
			inline = true,
			order = 2,
			name = " ",	-- don't delete the space
			desc = "",
			args = {
				bfs = {
					type = "toggle",
					name = L["ButtonFacade support"],
					desc = L["If enabled, skin the Faceroller frame with ButtonFacade."],
					disabled = function()
						return not Faceroller_GUI:BFRegister(true)
					end,
					get = function ()
						return Faceroller_GUIDB.use_bf
					end,
					set = function (i, v)
						Faceroller_GUIDB.use_bf = v
						Faceroller_GUI:BFRegister(test)
						Print (L["You need to /console reloadui for this setting to apply."])
					end
				},

				-- XXX: non-bf skin select


				ci = {
					type = "toggle",
					order = 4,
					name = L["Corner Indicators"],
					desc = L["Show cooldowns or buffs as colored dots on the Faceroller frame. What is shown where is module specific."],
					get = function ()
						return FacerollerDB.corner_indicators == 1
					end,
					set = function()
						Faceroller:setCI()
					end,
				},

				silent = {
					type = "toggle",
					order = 4,
					name = L["Silent module init"],
					desc = L["Suppress some chat output."],
					get = function ()
						return FacerollerDB.silent == 1
					end,
					set = function(i, v)
						if v == true then
							FacerollerDB.silent = 1
						else
							FacerollerDB.silent = 0
						end
					end,
				},
			}
		}
	}
}


--
-- visibility
--
options.args.visibility = {
	type = "group",
	order = 2,
	childGroups = "tab",
	name = L["Visibility"],
	desc = L["Configure when the Faceroller frames is visible."],
	args = {
		notegroup = {
			type = "group",
			inline = true,
			order = 1,
			name = " ",	-- don't delete the space
			desc = "",
			args = {
				note = {
					type = "description",
					name = L["Note: the Faceroller frame will always only show when you target something that you can attack."],
				}
			}
		},

		showframe = {
			type = "group",
			inline = true,
			name = L["Show frame ..."],
			desc = "",
			args = {
				solo = {
					type = "toggle",
					name = L["when alone"],
					desc = L[""],
					get = function ()
						return FacerollerDB.showwhensolo == 1
					end,
					set = function()
						Faceroller:setShow ("solo")
					end,
				},

				party = {
					type = "toggle",
					name = L["in parties"],
					get = function ()
						return FacerollerDB.showinparty == 1
					end,
					set = function()
						Faceroller:setShow ("party")
					end,
				},

				raid = {
					type = "toggle",
					name = L["in raids"],
					get = function ()
						return FacerollerDB.showinraid == 1
					end,
					set = function()
						Faceroller:setShow ("raid")
					end,
				},

				pvp = {
					type = "toggle",
					name = L["in pvp"],
					get = function ()
						return FacerollerDB.showinpvp == 1
					end,
					set = function()
						Faceroller:setShow ("pvp")
					end,
				},

				vehicles = {
					type = "toggle",
					name = L["in vehicles"],
					get = function ()
						return FacerollerDB.showinvehicles == 1
					end,
					set = function()
						Faceroller:setShow ("vehicles")
					end,
				}
			}
		}
	}
}


--
-- modules
--
options.args.modules = {
	type = "group",
	order = 3,
	childGroups = "tab",
	name = L["Modules"],
	desc = L["Module options."],
	args = {
		moduleselect = {
			type = "select",
			order = 0,
			name = L["Select module"],
			values = function()
				local ret = {}

				ret["none"] = "none"
				for k, v in pairs(Faceroller.modules) do
					ret[k] = k
				end

				return ret
			end,
			get = function()
				local ret = nil

				if Faceroller.spec == 1 then
					ret = FacerollerDB.primary_module
				elseif Faceroller.spec == 2 then
					ret = FacerollerDB.secondary_module
				end

				if not ret or ret == "" then
					return "none"
				end

				return ret
			end,
			set = function (i, v)
				Faceroller:setMod (v)
			end
		},

		modopt = {
			type = "group",
			order = 1,
			name = L["Module Options"],
			desc = L["Options for the selected module"],
			inline = true,
			args = {},
			plugins = {}
		},

		apply_modopt = {
			type = "execute",
			order = 2,
			name = L["Apply Options"],
			desc = L["Some modules may require that you press this button to work properly after you changed options."],
			func = function ()
				Faceroller:UseModuleForSpec()
			end
		}
	}
}


--
-- editor
--
options.args.misc = {
	type = "group",
	order = 4,
	childGroups = "tab",
	name = L["Misc"],
	desc = L["Stuff to help with module developement."],
	args = {
		code = {
			type = "input",
			order = 2,
			width = "full",
			name = L["Module Code"],
			desc = L["You can paste a table fit for use with the Easy API function here, press the accept button below, and test what the code does. The tables name MUST be spells."],
			multiline = true,
			get = function ()
				return Faceroller_GUIDB.editor_text
			end,
			set = function (i, v)
				Faceroller_GUIDB.editor_text = v
				Faceroller_GUI:EditorApplyPressed()
			end,
		},

		talents = {
			type = "input",
			order = 3,
			width = "full",
			name = L["GetTalentInfo help"],
			desc = L["If you need to check for talents in your module and don't feel like figuring out the correct GetTalentInfo call by yourself, just look it up here."],
			multiline = true,
			get = function ()
				return Faceroller_GUI:GetTalentsText()
			end,
			set = function (i, v)
			end,
		},

		spellid = {
			type = "input",
			order = 1,
			width = "full",
			name = L["Get SpellID"],
			desc = L["Don't want to search each spell on wowhead? Drag a spell from your spellbook into the textfield and watch the chat window."],
			get = function ()
				return guess_spell_text
			end,
			set = function (i, v)
				guess_spell_text = v
				Print (string.format(L["%s has spell id %d"], v, Faceroller_GUI:GetSpellID(v)))
			end,
		},

	}
}


function Faceroller_GUI:SetModuleOptions(name, t, disabled)
	local isempty = t == nil or next(t, nil) == nil

	if isempty then
		t = {}
		t.gui = {}
		t.gui["Note"] = {
			type = "description",
			name = L["This module doesn't have any options."],
		}
	else
		if not t.gui then
			-- module didn't set it's own gui layout.
			local gui = {}

			for k, v in pairs(t) do
				local ent = {
					name = k,
					get = function ()
						return t[k]
					end,
					set = function (i, x)
						t[k] = x
					end
				}

				if disabled then
					ent.disabled = true
				end

				if type(v) == "string" then
					ent.type = "input"
				elseif type(v) == "number" then
					ent.type = "range"
				elseif type(v) == "boolean" then
					ent.type = "toggle"
				end

				gui[k] = ent
			end
			t.gui = gui
		end
	end
	options.args.modules.args.modopt.plugins["mod"] = t.gui
end


--
-- register with ldb
--
function Faceroller_GUI:LDBRegister()
	local icon = "Interface\\AddOns\\Faceroller\\media\\coffee"
	local ldb = LibStub:GetLibrary("LibDataBroker-1.1")

	if not ldb then
		return false
	end

	ldb:NewDataObject("Faceroller", {
		type = "launcher",
		icon = icon,
		label = "Faceroller",
		OnClick = function()
			Faceroller_GUI:ShowModuleConf()
		end,
		OnTooltipShow = function(t)
			t:AddLine("Faceroller")
			t:AddLine("click to show menu.")
		end,
	})

	return true
end


--
-- get spellid from "Spellname (Rank X)"
--
local spellid_table = nil

function Faceroller_GUI:GetSpellID(name_rank)
	if spellid_table == nil then
		spellid_table = {}
		for t = 1, 4 do
			local _, _, o, n = GetSpellTabInfo(t)

			for i = (1 + o), (o + n) do
				local name, rank = GetSpellName(i, BOOKTYPE_SPELL)

				if rank ~= "" then
					name = name .. "(" .. rank .. ")"
				end

				local id = tonumber(GetSpellLink(i, BOOKTYPE_SPELL):match("spell:(%d+)"))
				if id and id > 0 then
					spellid_table[name] = id
				end
			end
		end
	end

	local t = spellid_table[name_rank]
	if t == nil then
		return -1
	end

	return t
end


--
-- "compile" editor code.
--
function Faceroller_GUI:EditorApplyPressed()
	local x = loadstring (Faceroller_GUIDB.editor_text .. "\nreturn spells\n")

	if x == nil then
		Print (L["Error: can't compile code!"])
		return
	end

	Faceroller:UnregisterModule("gui")
	Faceroller:EasyRegister ("gui", x())
	Faceroller:UseModule ("gui")
end


function Faceroller_GUI:GetTalentsText()
	local ret = ""
	local numTabs = GetNumTalentTabs()

	for t = 1, numTabs do
		local numTalents = GetNumTalents(t)
		for i = 1, numTalents do
			local name, icon, tier, column, currRank, maxRank = GetTalentInfo(t,i)
			ret = ret .. name .. ": " .. "GetTalentInfo(" .. t .. ", " .. i .. ")\n"

		end
		ret = ret .. "\n"
	end

	return ret
end


--
-- used by Faceroller to open the options menu
--
function Faceroller_GUI:ShowModuleConf()
	if not AceDialog then
		AceDialog = LibStub("AceConfigDialog-3.0")
		local AceConfig = LibStub("AceConfig-3.0")

		AceConfig:RegisterOptionsTable("Faceroller", options)
		AceDialog:SetDefaultSize ("Faceroller", 620, 310)
	end

	AceDialog:Open ("Faceroller")
end


function Faceroller_GUI:Init()
	local f = CreateFrame("Frame")
	f.name = "Faceroller"

	local b = CreateFrame("Button", nil, f, "OptionsButtonTemplate")
	b:SetPoint ("TOPLEFT", f, "TOPLEFT", 20, -20)
	b:SetText ("Open Config")
	b:SetScript ("OnClick", function ()
		InterfaceOptionsFrameCancel_OnClick()
		HideUIPanel(GameMenuFrame)
		Faceroller_GUI:ShowModuleConf()
	end)

	InterfaceOptions_AddCategory(f)
end


-- regist with ldb
Faceroller_GUI:LDBRegister()

-- init gui
Faceroller_GUI:Init()

-- register gui with faceroller
Faceroller:RegisterGUI(Faceroller_GUI)
