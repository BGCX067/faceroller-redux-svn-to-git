local VERSION = {string.split(".", GetAddOnMetadata("Faceroller", "Version"))}
local GetSpellName = GetSpellName or GetSpellBookItemName

-- stub for localization.
local L = setmetatable({}, {
	__index = function (t, v)
		t[v] = v
		return v
	end
})

FacerollerDB = {}
FacerollerDB.locked = true
FacerollerDB.debug = false
FacerollerDB.framescale = 1.0
FacerollerDB.framealpha = 1.0
FacerollerDB.rangecheck = 1
FacerollerDB.powercheck = 1
FacerollerDB.overlay_texture = "Interface\\AddOns\\Faceroller\\media\\skin"

FacerollerDB.showinraid = 1
FacerollerDB.showinparty = 1
FacerollerDB.showinpvp = 1
FacerollerDB.showwhensolo = 1
FacerollerDB.showinvehicles = 0

FacerollerDB.anim_fade = 1

FacerollerDB.primary_module = ""
FacerollerDB.primary_module_opts = {}
FacerollerDB.secondary_module = ""
FacerollerDB.secondary_module_opts = {}

FacerollerDB.version = VERSION

FacerollerDB.corner_indicators = 0
FacerollerDB.silent = 0

-- stuff
Faceroller = CreateFrame("Frame")
Faceroller:RegisterEvent("ADDON_LOADED")
Faceroller:SetScript("OnEvent", function(this, event, ...)
	Faceroller[event](this, ...)
end)

Faceroller.version = VERSION
Faceroller.modules = {}
Faceroller.in_combat = false
Faceroller.spec = 0
Faceroller.power = 0
Faceroller.combopoints = 0
Faceroller.target_guid = nil

_G["Faceroller"] = Faceroller
_G["FacerollerDB"] = FacerollerDB

-- for keybind
BINDING_HEADER_FACEROLLER = "Faceroller"
BINDING_NAME_FACEROLLER_SHOW_GUI = L["Show GUI"]

-- stuff thats used in OnUpdate handlers.
local playerBuffs = {}
local playerDebuffs = {}
local playerBuffsOther = {}		-- buffs on player not cast by himself.

local targetDebuffs = {}
local myTargetDebuffs = {}
local gcdSpell = nil
local DisplayFrame = nil
local nextskill_func = nil
local modoptions = nil
local gcd = 0
local spells = {}

local playerinraid = 0
local playerinparty = 0
local playerinpvp = 0

local ghostkeepalive = 0.6

-- local references to often used functions.
local GetTime = GetTime
local GetSpellCooldown = GetSpellCooldown
local GetSpellInfo = GetSpellInfo
local UnitAura = UnitAura
local pairs = pairs
local type = type
local IsUsableSpell = IsUsableSpell
local IsSpellInRange = IsSpellInRange
local UnitPower = UnitPower
local GetComboPoints = GetComboPoints
local UnitGUID = UnitGUID

local gsi_mt
local gsi_icon_mt
local gsi_name_mt

local function make_metatables()
	gsi_mt = setmetatable({}, {__index = function(t, k)
		local x = GetSpellInfo(k)
		t[k] = x
		return x
	end})
	Faceroller.gsi = gsi_mt

	gsi_icon_mt = setmetatable({}, {__index = function(t, k)
		local _, _, x = GetSpellInfo(k)
		if x == nil then
			x = "Interface\\AddOns\\Faceroller\\media\\coffee"
		end

		t[k] = x
		return x
	end})

	gsi_name_mt = setmetatable({}, {__index = function(t, k)
		for i, v in pairs(spells) do
			if v.name == k then
				t[k] = i
				return i
			end
		end

		t[k] = -1
		return -1
	end})
end

-- do it here once so event handlers won't bail.
make_metatables()


-- only enable this for classes that might need them
local powerUpdate = 0
local comboUpdate = 0

do
	local _, playerClass = UnitClass("player")

	if playerClass == "ROGUE"
			or playerClass == "DRUID" then
		comboUpdate = 1
	end

	if playerClass == "WARRIOR"
			or playerClass == "DEATHKNIGHT"
			or playerClass == "DRUID"
			or playerClass == "ROGUE" then
		powerUpdate = 1
	end
end


local function Print(x)
	DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Faceroller:|r " .. x)
end


--
-- called from gui/gui.lua
--
local Faceroller_GUI = nil
function Faceroller:RegisterGUI(ui)
	Faceroller_GUI = ui
end


function Faceroller:ShowGUI()
	if not Faceroller_GUI then
		Print (L["GUI not found."])
		return
	end

	Faceroller_GUI:ShowModuleConf()
end


function Faceroller:updateBuffs(unit, filter, t)
	local now = GetTime()

	for k, v in pairs(t) do
		local n, _, i, cn, _, _, e = UnitAura (unit, k, nil, filter)
		if not n then
			if now > v.ghost then
				v.active = false
				v.ends = 0
				v.count = 0
				v.icon = nil
				v.ghost = 0
			end
		else
			v.count = cn
			v.active = true
			v.ends = e
			v.icon = i
			v.ghost = 0
		end
	end
end


--
-- slash command functions
--
function Faceroller:Debug (x)
	if FacerollerDB.debug then
		DEFAULT_CHAT_FRAME:AddMessage(x)
	end
end


function Faceroller:PrintHelp()
	Print(L["Faceroller options:"])
	Print(L["version - print version number."])
	Print(L["lock - lock/unlock the frame."])
	Print(L["scale <num> - set scaling of the frame."])
	Print(L["alpha <num> - set alpha of the frame."])
	Print(L["list - print a list of available modules."])
	Print(L["mod <name> - active module name for your current spec."])
	Print(L["opt <X> - pass X to the option handling function of the active module."])
	Print(L["show <X> - configure when to show faceroller, /fr show for help."])
	Print(L["range - toggle range check."])
	Print(L["power - toggle power check."])
	Print(L["reset - reset all options."])
	Print(L["config - open the configuration GUI."])
	Print(L["anim - toggle fade animation."])
	Print(L["ci - toggle corner indicators."])
	Print(L["silent - suppress some chat output."])
end


function Faceroller:PrintVersion()
	Print (VERSION[1] .. "." .. VERSION[2] .. "." .. VERSION[3])
end


function Faceroller:setSkin(x)
	FacerollerDB.overlay_texture = "Interface\\AddOns\\Faceroller\\media\\" .. x

	local overlay = DisplayFrame.overlay

	overlay:SetTexture(FacerollerDB.overlay_texture)
end


function Faceroller:DebugOn()
	if FacerollerDB.debug then
		FacerollerDB.debug = false
		Print("debug disabled.")
	else
		FacerollerDB.debug = true
		Print("debug enabled.")
	end
end


function Faceroller:LockUnlock()
	if FacerollerDB.locked then
		FacerollerDB.locked = false
		DisplayFrame.anchor:EnableMouse(true)
		DisplayFrame.anchor:Show()
		Print(L["frame unlocked."])
	else
		FacerollerDB.locked = true
		DisplayFrame.anchor:EnableMouse(false)
		DisplayFrame.anchor:Hide()
		Print(L["frame locked."])
	end
end


function Faceroller:setMod(x)
	if x == nil then
		self:ShowGUI()
		return
	end

	self:UseModule(x)
end


function Faceroller:setScale(x)
	if x == nil then
		Print(L["argument required."])
		return
	end

	FacerollerDB.framescale = tonumber(x)
	DisplayFrame.anchor:SetScale (FacerollerDB.framescale)
	DisplayFrame:SetScale (FacerollerDB.framescale)
end


function Faceroller:ListModules()
	Print (L["available modules:"])
	for n, v in pairs(self.modules) do
		Print (n)
	end
end


function Faceroller:ModuleOption(x)
	if modoptions == nil then
		Print(L["module doesn't have any options."])
		return
	end

	--[[
	if x == nil then
		Print(L["argument required."])
		return
	end
	--]]

	modoptions (x)
	self:UseModuleForSpec()
end


function Faceroller:setAlpha(x)
	if x == nil then
		Print(L["argument required."])
		return
	end

	FacerollerDB.framealpha = tonumber(x)
	DisplayFrame:SetAlpha(FacerollerDB.framealpha)
end


function Faceroller:ResetOptions()
	FacerollerDB = {}
	FacerollerDB.locked = true
	FacerollerDB.debug = false
	FacerollerDB.framescale = 1.0
	FacerollerDB.framealpha = 1.0
	FacerollerDB.overlay_texture = "Interface\\AddOns\\Faceroller\\media\\skin"

	FacerollerDB.primary_module = ""
	FacerollerDB.primary_module_opts = {}
	FacerollerDB.secondary_module = ""
	FacerollerDB.secondary_module_opts = {}

	FacerollerDB.showinraid = 1
	FacerollerDB.showinparty = 1
	FacerollerDB.showinpvp = 1
	FacerollerDB.showwhensolo = 1
	FacerollerDB.showinvehicles = 0

	DisplayFrame.anchor:SetPoint ("CENTER", UIParent, "CENTER", 0, 0)
	DisplayFrame:SetScale(FacerollerDB.framescale)
	DisplayFrame:SetAlpha(FacerollerDB.framealpha)
	FacerollerDB.rangecheck = 1
	FacerollerDB.powercheck = 1
	FacerollerDB.anim_fade = 1

	FacerollerDB.corner_indicators = 0
	FacerollerDB.silent = 0
	Print(L["options have been reset."])
end


function Faceroller:setShow(x)
	if x == "raid" then
		if FacerollerDB.showinraid == 1 then
			FacerollerDB.showinraid = 0
			Print(L["Faceroller will not show in raids."])
		else
			FacerollerDB.showinraid = 1
			Print(L["Faceroller will show in raids."])
		end
	elseif x == "party" then
		if FacerollerDB.showinparty == 1 then
			FacerollerDB.showinparty = 0
			Print(L["Faceroller will not show in parties."])
		else
			FacerollerDB.showinparty = 1
			Print(L["Faceroller will show in parties."])
		end
	elseif x == "solo" then
		if FacerollerDB.showwhensolo == 1 then
			FacerollerDB.showwhensolo = 0
			Print(L["Faceroller will not show when solo."])
		else
			FacerollerDB.showwhensolo = 1
			Print(L["Faceroller will show when solo."])
		end
	elseif x == "pvp" then
		if FacerollerDB.showinpvp == 1 then
			FacerollerDB.showinpvp = 0
			Print(L["Faceroller will not show in pvp."])
		else
			FacerollerDB.showinpvp = 1
			Print(L["Faceroller will show in pvp."])
		end
	elseif x == "vehicles" then
		if FacerollerDB.showinvehicles == 1 then
			FacerollerDB.showinvehicles = 0
			Print(L["Faceroller will not show in vehicles."])
		else
			FacerollerDB.showinvehicles = 1
			Print(L["Faceroller will show in vehicles."])
		end
	else
		Print(L["Show Options:"])
		Print(L["show raid - hide/show in raids."])
		Print(L["show party - hide/show in parties."])
		Print(L["show solo - hide/show solo."])
		Print(L["show pvp - hide/show in pvp."])
		Print(L["show vehicles - hide/show in vehicles."])
	end
end


function Faceroller:RangeCheck()
	if FacerollerDB.rangecheck == 1 then
		FacerollerDB.rangecheck = 0
		DisplayFrame.icon:SetVertexColor(1, 1, 1)
		Print(L["range check disabled."])
	else
		FacerollerDB.rangecheck = 1
		DisplayFrame.icon:SetVertexColor(1, 1, 1)
		Print(L["range check enabled."])
	end
end


function Faceroller:PowerCheck()
	if FacerollerDB.powercheck == 1 then
		FacerollerDB.powercheck = 0
		DisplayFrame.icon:SetVertexColor(1, 1, 1)
		Print(L["power check disabled."])
	else
		FacerollerDB.powercheck = 1
		DisplayFrame.icon:SetVertexColor(1, 1, 1)
		Print(L["power check enabled."])
	end
end


function Faceroller:setAnim(x)
	if FacerollerDB.anim_fade == 1 then
		FacerollerDB.anim_fade = 0
		Print(L["fade animation disabled after UI reload."])
	else
		FacerollerDB.anim_fade = 1
		Print(L["fade animation enabled after UI reload."])
	end
end


function Faceroller:setCI(x)
	if FacerollerDB.corner_indicators == 0 then
		FacerollerDB.corner_indicators = 1
		Print(L["corner indicators enabled."])
	else
		FacerollerDB.corner_indicators = 0
		Print(L["corner indicators disabled."])
	end
	self:UseModuleForSpec()
end

function Faceroller:setSilent(x)
	if FacerollerDB.silent == 0 then
		FacerollerDB.silent = 1
		Print(L["silent mode enabled."])
	else
		FacerollerDB.silent = 0
		Print(L["silent mode disabled."])
	end
end


local SlashCommands = {
	debug = Faceroller.DebugOn,
	version = Faceroller.PrintVersion,
	lock = Faceroller.LockUnlock,
	mod = Faceroller.setMod,
	scale = Faceroller.setScale,
	alpha = Faceroller.setAlpha,
	list = Faceroller.ListModules,
	opt = Faceroller.ModuleOption,
	reset = Faceroller.ResetOptions,
	show = Faceroller.setShow,
	range = Faceroller.RangeCheck,
	power = Faceroller.PowerCheck,
	config = Faceroller.ShowGUI,
	anim = Faceroller.setAnim,
	skin = Faceroller.setSkin,
	ci = Faceroller.setCI,
	silent = Faceroller.setSilent,
}


--
-- used for range check
--
local last_rangecheck = 1
local last_usablecheck = 1
local last_spell = 0
local last_update = 0
local last_cnsf = 0

function Faceroller:OnUpdateFunc(elapsed)
	last_update = last_update + elapsed

	if last_update < 0.041 then
		return
	end

	last_update = 0

	if FacerollerDB.powercheck == 1 and last_spell ~= 0 then
		if last_spell == 0 then
			return
		end

		local x = IsUsableSpell(gsi_mt[last_spell])

		if x ~= last_usablecheck then
			if x == 1 then
				DisplayFrame.icon:SetVertexColor(1, 1, 1)
			elseif x == nil then
				DisplayFrame.icon:SetVertexColor(0, 0, 1)
			end
			last_usablecheck = x
		end
	end

	if FacerollerDB.rangecheck == 1 and last_spell ~= 0 then
		if last_spell == 0 then
			return
		end

		local x = IsSpellInRange(gsi_mt[last_spell], "target")

		if x ~= last_rangecheck then
			if x == 1 then
				DisplayFrame.icon:SetVertexColor(1, 1, 1)
			elseif x == 0 then
				DisplayFrame.icon:SetVertexColor(1, 0, 0)
			end
			last_rangecheck = x
		end
	end

	if (GetTime() - last_cnsf) > 0.5 then --XXX
		self:CallNextSkillFunc()
	end
end


--
-- call the active modules nextskill function
--
function Faceroller:CallNextSkillFunc()
	if not nextskill_func then
		return
	end

	local now = GetTime()
	local g = gcd - now
	local spell

	last_cnsf = now

	for _, v in pairs(spells) do
		v.cd = v.ends - now
	end

	for _, v in pairs(playerBuffs) do
		v.time_left = v.ends - now
	end

	for _, v in pairs(playerBuffsOther) do
		v.time_left = v.ends - now
	end

	for _, v in pairs(playerDebuffs) do
		v.time_left = v.ends - now
	end

	for _, v in pairs(targetDebuffs) do
		v.time_left = v.ends - now
	end

	for _, v in pairs(myTargetDebuffs) do
		v.time_left = v.ends - now
	end

	if powerUpdate == 1 then
		Faceroller.power = UnitPower ("player")
	end

	if comboUpdate == 1 then
		Faceroller.combopoints = GetComboPoints("player", "target")
	end

	spell = nextskill_func (g,
		spells,
		playerBuffs,
		targetDebuffs,
		myTargetDebuffs,
		playerDebuffs,
		playerBuffsOther)

	if spell == last_spell then
		return
	end

	last_spell = spell
	DisplayFrame.icon:SetTexture(gsi_icon_mt[spell])
end


--
-- create the display frame, anchor etc.
--
function Faceroller:createFrames(name)
	-- anchor for spell frame
	local anchor = CreateFrame ("Frame", name .. "_Anchor", UIParent)
	anchor:RegisterForDrag("LeftButton")

	anchor:SetWidth (60)
	anchor:SetHeight (60)
	anchor:SetMovable(true)
	anchor:EnableMouse(true)
	anchor:ClearAllPoints()
	anchor:SetPoint ("CENTER", UIParent, "CENTER", 0, 0)

	-- anchor background
	local bg = anchor:CreateTexture (name .. "_AnchorBG", "PARENT")
	bg:SetAllPoints (anchor)
	bg:SetBlendMode ("BLEND")
	bg:SetTexture (0, 0, 0, 0.4)

	anchor:SetScript("OnDragStart", self.StartMoving)
	anchor:SetScript("OnDragStop", self.StopMovingOrSizing)
	anchor:SetScale (FacerollerDB.framescale)

	if FacerollerDB.locked == false then
		anchor:EnableMouse(true)
		anchor:Show()
	else
		anchor:EnableMouse(false)
		anchor:Hide()
	end

	-- spell frame
	local button = CreateFrame("Button", name .. "_Button", UIParent)
	button:SetPoint("CENTER", anchor, "CENTER")
	button:SetWidth (40)
	button:SetHeight (40)
	button:SetScale (FacerollerDB.framescale)

	button.anchor = anchor
	button.anchor_bg = bg

	-- spell icon
	local icon = button:CreateTexture(name .. "_icon", "BACKGROUND")
	icon:SetVertexColor(1.0, 1.0, 1.0)
	icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
	icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
	icon:SetTexture("Interface\\AddOns\\Faceroller\\media\\coffee")
	button.icon = icon

	-- cooldown spiral
	local cd = CreateFrame("Cooldown", name .. "_cd", button)
	cd:SetAllPoints(button)
	button.cd = cd

	-- skin
	local overlay = button:CreateTexture(name .. "_skin", "OVERLAY")
	overlay:SetTexture(FacerollerDB.overlay_texture)
	overlay:SetAllPoints(button)
	button.overlay = overlay

	local ci_frame_level = cd:GetFrameLevel() + 1

	-- corner indicators: top left
	local ci_tl = CreateFrame("Button", name .. "_ci_tl", button)
	ci_tl:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
	ci_tl:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeSize = 0,
		insets = {left = 0, right = 0, top = 0, bottom = 0}
	});

	ci_tl:SetFrameLevel(ci_frame_level)
	ci_tl:SetWidth (5)
	ci_tl:SetHeight (5)
	ci_tl:SetBackdropColor (0, 0, 0, 0)
	button.ci_tl = ci_tl

	-- top right
	local ci_tr = CreateFrame("Button", name .. "_ci_tr", button)
	ci_tr:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
	ci_tr:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeSize = 0,
		insets = {left = 0, right = 0, top = 0, bottom = 0}
	});

	ci_tr:SetFrameLevel(ci_frame_level)
	ci_tr:SetWidth (5)
	ci_tr:SetHeight (5)
	ci_tr:SetBackdropColor (0, 0, 0, 0)
	button.ci_tr = ci_tr

	-- bottom left
	local ci_bl = CreateFrame("Button", name .. "_ci_bl", button)
	ci_bl:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
	ci_bl:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeSize = 0,
		insets = {left = 0, right = 0, top = 0, bottom = 0}
	});

	ci_bl:SetFrameLevel(ci_frame_level)
	ci_bl:SetWidth (5)
	ci_bl:SetHeight (5)
	ci_bl:SetBackdropColor (0, 0, 0, 0)
	button.ci_bl = ci_bl

	-- bottom right
	local ci_br = CreateFrame("Button", name .. "_ci_br", button)
	ci_br:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
	ci_br:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeSize = 0,
		insets = {left = 0, right = 0, top = 0, bottom = 0}
	});

	ci_br:SetFrameLevel(ci_frame_level)
	ci_br:SetWidth (5)
	ci_br:SetHeight (5)
	ci_br:SetBackdropColor (0, 0, 0, 1)
	button.ci_br = ci_br

	button:SetAlpha(FacerollerDB.framealpha)
	button:EnableMouse(false)
	button:Hide()

	local lci
	if FacerollerDB.anim_fade == 1 then
		lci = LibStub("libCandyIcon-1.0", true)
	end

	if lci then
		local lbf = LibStub("LibButtonFacade", true)
		local fia = "shrink|fadein"
		local foa = "magnify|fadeout"

		if lbf and Faceroller_GUIDB and Faceroller_GUIDB.use_bf then
			fia = "fadein"
			foa = "fadeout"
		end

		lci:MakeCandyIcon (button, {
			["alpha"] = FacerollerDB.framealpha,
			["fadein_anim"] = fia,
			["fadein_duration"] = 0.2,
			["fadeout_anim"] = foa,
			["fadeout_duration"] = 0.2,
			["idle_anim"] = nil,
		})

		--[[
		-- when selecting / deselecting a target very fast this did not
		-- always fire ...
		button:SetScript ("OnShow", function(self)
			Print("b show")
			self:Play()
		end)
		--]]

		button.RealShow = button.Show
		button.Show = function (self)
			--Print("b show")
			self:RealShow()
			self:Play()
		end

		button.Hide = function (self)
			--Print ("b hide")
			self:Stop()
		end
	end

	return button
end


--
-- API
--

-- HasGlyph(spellid):
--
-- Check if player has the glyph spellid. Returns true if glyph is found,
-- false otherwise.
--
function Faceroller:HasGlyph(spellid)
	for i = 1, 6 do
		local _, _, g = GetGlyphSocketInfo(i)
		if g == spellid then
			return true
		end
	end
	return false
end


local function gii(x)
	local l = GetInventoryItemLink("player", x)

	if l == nil then
		return 0
	end

	local _, ret = string.split(":", l)
	return tonumber(ret)
end


--
-- GetItemId (slot):
--
function Faceroller:GetItemId(x)
	return gii(x)
end


--
-- GetSetItemSlotItems():
--
-- Returns the item ids of head, shoulder, chest, legs and gloves
-- item slot (in that order).
--
function Faceroller:GetSetItemSlotItems()
	-- head, shoulder, chest, legs, gloves
	return gii(1), gii(3), gii(5), gii(7), gii(10)
end


--
-- CornerIndicatorSetColor(pos, r, g, b, a):
--
-- set the color of corner indicator pos to (r, g, b, a). pos
-- may be one of TOPLEFT, TOPRIGHT, BOTTOMLEFT or BOTTOMRIGHT.
--
function Faceroller:CornerIndicatorSetColor (pos, r, g, b, a)
	if FacerollerDB.corner_indicators == 0 then
		return
	end

	local ci = nil

	if pos == "TOPLEFT" then
		ci = DisplayFrame.ci_tl
	elseif pos == "TOPRIGHT" then
		ci = DisplayFrame.ci_tr
	elseif pos == "BOTTOMLEFT" then
		ci = DisplayFrame.ci_bl
	elseif pos == "BOTTOMRIGHT" then
		ci = DisplayFrame.ci_br
	end

	if ci == nil then
		return
	end

	ci:SetBackdropColor (r, g, b, a)
end


--
-- HasSpell(spell):
--
-- find spell in players spellbook. Return true when found,
-- false otherwise.
--
function Faceroller:HasSpell(spell)
	if type(spell) == "number" then
		spell = gsi_mt[spell]
	end

	for t = 1, 4 do
		local _, _, o, n = GetSpellTabInfo(t)

		for i = (1 + o), (o + n) do
			local s = GetSpellName(i, BOOKTYPE_SPELL)

			if (s == spell) then
				return true
			end
		end
	end

	self:Debug("HasSpell for \"" .. tostring(spell) .. "\" failed.")
	return false
end

--
-- RegisterBuff(spell):
--
-- Add a buff to the buffs table.
--
function Faceroller:RegisterBuff(spell, others, isdebuff)
	if type(spell) == "number" then
		spell = gsi_mt[spell]
	end

	if others then
		self:Debug("RegisterBuff: " .. spell .. " (others)")
		playerBuffsOther[spell] = {
			count = 0,
			time_left = 0,
			active = false,
			ends = 0,
			icon = nil,
			ghost = 0,
		}
		return
	end

	if isdebuff then
		self:Debug("RegisterBuff: " .. spell .. " (debuff)")
		playerDebuffs[spell] = {
			count = 0,
			time_left = 0,
			active = false,
			ends = 0,
			icon = nil,
			ghost = 0,
		}
		return
	end

	self:Debug("RegisterBuff: " .. spell .. " (buff)")
	playerBuffs[spell] = {
		count = 0,
		time_left = 0,
		active = false,
		ends = 0,
		icon = nil,
		ghost = 0,
	}
end


--
-- RegisterDebuff(spell [, mine]):
--
-- Add a debuff to the debuffs table. If mine is true,
-- only check for debuff cast by us.
--
function Faceroller:RegisterDebuff(spell, mine)
	if type(spell) == "number" then
		spell = gsi_mt[spell]
	end

	if mine == true then
		myTargetDebuffs[spell] = {
			count = 0,
			time_left = 0,
			active = false,
			ends = 0,
			icon = nil,
			ghost = 0,
		}
	else
		targetDebuffs[spell] = {
			count = 0,
			time_left = 0,
			active = false,
			ends = 0,
			icon = nil,
			ghost = 0,
		}
	end
end


--
-- EasyChooseSpell(t):
--
-- XXX: doc
--
function Faceroller:EasyChooseSpell(t)
	local g = gcd - GetTime()
	local n = 0
	local p = 1
	local th
	local th2
	local power = 0

	if t == nil then
		th = max (g, 0.5) + 0.1
	else
		th = max (g, t) + 0.1
	end

	for k, v in pairs(spells) do
		local vd = v.data

		if vd.wait_time then
			th2 = vd.wait_time
		else
			th2 = th
		end

		if vd.power then
			power = vd.power
		else
			power = 0
		end

		if vd.type == "indicator" then
			if vd.show == "cooldown" then
				if v.cd < 2 then
					self:CornerIndicatorSetColor (vd.pos, 0, 1, 0, 1)
				else
					self:CornerIndicatorSetColor (vd.pos, 1, 0, 0, 1)
				end
			elseif vd.show == "buff" then
				local d = playerBuffs[gsi_mt[k]]
				local tl = 1

				if vd.time_left then
					tl = vd.time_left
				end

				if d.active == false or d.time_left < tl then
					self:CornerIndicatorSetColor (vd.pos, 1, 0, 0, 1)
				else
					self:CornerIndicatorSetColor (vd.pos, 0, 1, 0, 1)
				end
			end
		end

		if v.cd < th2 and Faceroller.power >= power then
			if vd.priority > p then
				if vd.type == "debuff" then
					local d = nil
					local tl = 1

					if vd.time_left then
						tl = vd.time_left
					end

					if vd.mine then
						d = myTargetDebuffs[gsi_mt[k]]
					else
						d = targetDebuffs[gsi_mt[k]]
					end

					if d.active == false or d.time_left < tl then
						if vd.retid then
							n = vd.retid
						else
							n = k
						end
						p = vd.priority
					end
				elseif vd.type == "buff" then
					local d = playerBuffs[gsi_mt[k]]
					local tl = 1
					local up = (vd.up == true)

					if vd.time_left then
						tl = vd.time_left
					end

					if not up then
						if d.active == false or d.time_left < tl then
							if vd.retid then
								n = vd.retid
							else
								n = k
							end
							p = vd.priority
						end
					else
						if d.active == true and d.time_left > tl then
							if vd.retid then
								n = vd.retid
							else
								n = k
							end
							p = vd.priority
						end
					end
				elseif vd.type == "spell" then
					if vd.reactive then
						if v.usable and v.enabled == 0 then
							if vd.retid then
								n = vd.retid
							else
								n = k
							end
							p = vd.priority
						end
					else
						if vd.retid then
							n = vd.retid
						else
							n = k
						end
						p = vd.priority
					end
				end
			end
		end
	end

	return n
end


--
-- EasySetup(s):
--
-- XXX: doc
--
function Faceroller:EasySetup(s)
	for k, v in pairs(s) do
		v.type = string.lower(v.type)
		if not v.nospell then
			if Faceroller:HasSpell (k) == false then
				return nil
			end
		end

		if v.type == "debuff" then
			if v.mine then
				self:RegisterDebuff(k, true)
			else
				self:RegisterDebuff(k)
			end
		elseif v.type == "buff" then
			self:RegisterBuff(k)
		elseif v.type == "indicator" then
			v.show = string.lower (v.show)
			if v.show == "buff" then
				self:RegisterBuff(k)
			end
		end
	end

	return s
end


--
-- SetSpells(spells):
--
-- Set spells to use. Spells has to be a table where
-- the keys are the spell ids. The values are ignored.
--
function Faceroller:SetSpells(s)
	spells = {}

	for k, v in pairs(s) do
		spells[k] = {
			name = gsi_mt[k],
			data = v,
			cd = 600,
			usable = 0,
			enabled = 0,
			ends = 0,
		}
	end
end


--
-- RegisterModule(name, spells, init_func, nextskill_func):
--
-- registers a module with name name. spells has to be a table fit
-- for use in SetSpells. init_func is a function called, when the
-- module is used (it is only called once). nextskill_func is called
-- on a regular basis and should be used to determine which spell
-- to suggest next. opt is the options function.
--
function Faceroller:RegisterModule(name, init, nextskill_func, opt)
	if self.modules[name] ~= nil then
		Print(string.format(L["Error: a module with the name \"%s\" already exists!"], name))
		return
	end

	self.modules[name] = {
		init_func = init,
		nextskill_func = nextskill_func,
		option_func = opt,
	}
end


--
-- UnregisterModule(name):
--
-- Unregister a module.
--
function Faceroller:UnregisterModule (name)
	self.modules[name] = nil
end


--
-- EasyRegister (spells):
--
-- Register a module as name with a spells table, as used by EasySetup and
-- EasyChooseSpell. EasySetup is used as the init function and EasyChooseSpell
-- is used as the next spell function. opt_func is the options handling
-- function (this argument is optional).
--
function Faceroller:EasyRegister(name, spells_tab, opt_func)
	local i = function ()
		return Faceroller:EasySetup (spells_tab)
	end

	local n = function ()
		return Faceroller:EasyChooseSpell()
	end

	self:RegisterModule(name, i, n, opt_func)
end


function Faceroller:UseModuleForSpec()
	local m = nil

	if self.spec == 1 then
		m = FacerollerDB.primary_module
	elseif self.spec == 2 then
		m = FacerollerDB.secondary_module
	else
		Print(L["you should never see this message. (1)"])
		return
	end

	self:UseModule(m)
end


--
-- UseModule(name):
--
-- use module name for the current spec.
--
function Faceroller:UseModule(name)
	local Pr = function() end

	if FacerollerDB.silent == 0 then
		Pr = Print
	end

	if self.spec == 0 then
		Print(L["you should never see this message. (2)"])
		return
	end

	if name == nil or name == "" then
		if self.spec == 1 then
			FacerollerDB.primary_module = ""
			Print(L["No module for primary spec."])
		else
			FacerollerDB.secondary_module = ""
			Print(L["No module for secondary spec."])
		end

		nextskill_func = nil

		playerBuffs = {}
		playerBuffsOther = {}
		playerDebuffs = {}
		targetDebuffs = {}
		myTargetDebuffs = {}
		return
	end

	if name == "none" then
		if self.spec == 1 then
			Print(L["Disabled for primary spec."])
			FacerollerDB.primary_module = ""
		else
			Print(L["Disabled for secondary spec."])
			FacerollerDB.secondary_module = ""
		end

		nextskill_func = nil

		playerBuffs = {}
		playerBuffsOther = {}
		playerDebuffs = {}
		targetDebuffs = {}
		myTargetDebuffs = {}
		return
	end

	for n, v in pairs(self.modules) do
		if n == name then
			make_metatables ()
			local pb = playerBuffs
			local pbo = playerBuffsOther
			local pd = playerDebuffs
			local td = targetDebuffs
			local mtd = myTargetDebuffs

			local s
			local m
			local opts = nil

			DisplayFrame.ci_bl:SetBackdropColor (0, 0, 0, 0)
			DisplayFrame.ci_br:SetBackdropColor (0, 0, 0, 0)
			DisplayFrame.ci_tl:SetBackdropColor (0, 0, 0, 0)
			DisplayFrame.ci_tr:SetBackdropColor (0, 0, 0, 0)

			playerBuffs = {}
			playerBuffsOther = {}
			playerDebuffs = {}
			targetDebuffs = {}
			myTargetDebuffs = {}

			if self.spec == 1 then
				if FacerollerDB.primary_module_opts[n] then
					opts = FacerollerDB.primary_module_opts[n]
				else
					opts = {}
				end
			else
				if FacerollerDB.secondary_module_opts[n] then
					opts = FacerollerDB.secondary_module_opts[n]
				else
					opts = {}
				end
			end

			s, m = v.init_func(opts)

			if s == nil then
				if opts.gui then
					opts.gui = nil
				end

				if m == nil then
					m = "none given"
				end
				Print (string.format(L["Error: init failed for module %s (Reason: %s)"], n, m))

				playerBuffs = pb
				playerBuffsOther = pbo
				playerDebuffs = pd
				targetDebuffs = td
				myTargetDebuffs = mtd

				return
			end

			if self.spec == 1 then
				Pr(string.format(L["Using module %s for primary spec."], n))
				FacerollerDB.primary_module = n
				FacerollerDB.primary_module_opts[n] = opts
			else
				Pr(string.format (L["Using module %s for secondary spec."], n))
				FacerollerDB.secondary_module = n
				FacerollerDB.secondary_module_opts[n] = opts
			end

			self:SetSpells(s)
			nextskill_func = v.nextskill_func
			modoptions = v.option_func

			if Faceroller_GUI then
				if modoptions then
					Faceroller_GUI:SetModuleOptions(n, opts)
				else
					Faceroller_GUI:SetModuleOptions(n, opts, true)
				end
			end

			if opts.gui then
				opts.gui = nil
			end

			self:updateBuffs("player", "HELPFUL|PLAYER", playerBuffs)
			self:updateBuffs("player", "HELPFUL", playerBuffsOther)
			self:updateBuffs("player", "HARMFUL", playerDebuffs)
			local n = UnitName("target")
			if n ~= nil then
				self:updateBuffs("target", "HARMFUL|PLAYER", myTargetDebuffs)
				self:updateBuffs("target", "HARMFUL", targetDebuffs)
			end
			return
		end
	end
	Print (string.format (L["no such module: %s"], name))
end


--
-- event handlers
--

-- init addon.
function Faceroller:ADDON_LOADED(addon)
	if addon ~= "Faceroller" then
		return nil
	end

	-- new in 0.1.4
	if not FacerollerDB.anim_fade then
		FacerollerDB.anim_fade = 1
	end

	DisplayFrame = self:createFrames("Faceroller_df")
	self.DisplayFrame = DisplayFrame

	if Faceroller_GUI then
		Faceroller_GUI:BFRegister()
	end

	self:UnregisterEvent("ADDON_LOADED")
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("UNIT_AURA")
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
	self:RegisterEvent("SPELL_UPDATE_USABLE")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED")
	self:RegisterEvent("UNIT_SPELLCAST_SENT")
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self:RegisterEvent("UNIT_FACTION")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")

	self:RegisterEvent("SKILL_LINES_CHANGED")

	SlashCmdList["FACEROLLER"] = function (cmd)
		local Cmd, Args = strsplit(" ", cmd:lower(), 2)
		if SlashCommands[Cmd] then
			return SlashCommands[Cmd](Faceroller, Args)
		else
			self:PrintHelp ()
		end
	end

	SLASH_FACEROLLER1 = "/faceroller"
	SLASH_FACEROLLER2 = "/fr"
	SLASH_FACEROLLER3 = "/face"

	-- make sure all variables are in the db after version updates
	-- (deleted all compatability stuff for < 0.1.0)

	-- new in 0.2.0
	if not FacerollerDB.corner_indicators then
		FacerollerDB.corner_indicators = 0
	end

	-- new in 0.2.9
	if not FacerollerDB.silent then
		FacerollerDB.silent = 0
	end

	-- update db to newest version
	FacerollerDB.version = VERSION
end


function Faceroller:ACTIONBAR_UPDATE_COOLDOWN()
	if gcdSpell ~= nil then
		local s, d = GetSpellCooldown (gcdSpell)
		gcd = d + s

		if s ~= 0 then
			DisplayFrame.cd:SetCooldown(s, d)
		end
		self:CallNextSkillFunc()
	end
end


function Faceroller:PLAYER_REGEN_ENABLED()
	self.in_combat = false
end


function Faceroller:PLAYER_REGEN_DISABLED()
	self.in_combat = true
end


function Faceroller:PLAYER_TARGET_CHANGED()
	local n = UnitName("target")
	local guid = UnitGUID("target")


	if (n == nil)
			or (nextskill_func == nil)
			or (not UnitCanAttack("player", "target"))
			or UnitIsDead("target")
			or (playerinpvp == 1 and FacerollerDB.showinpvp == 0)
			or (playerinraid == 1 and FacerollerDB.showinraid == 0)
			or (playerinraid == 0 and playerinparty == 1 and FacerollerDB.showinparty == 0)
			or (playerinraid == 0 and playerinparty == 0 and FacerollerDB.showwhensolo == 0)
			or (FacerollerDB.showinvehicles == 0 and UnitInVehicle("player") == 1) then
		self.target_guid = nil
		Faceroller:SetScript ("OnUpdate", nil)
		DisplayFrame:Hide()
		return
	end

	-- it appears PLAYER_TARGET_CHANGED sometimes just fires
	-- (for no reason?) during combat, without target change.
	-- happens shortly after entering combat.
	if guid == self.target_guid then
		return
	end

	self.target_guid = guid

	for _, v in pairs (spells) do
		v.enabled = 0
	end

	self:updateBuffs("target", "HARMFUL|PLAYER", myTargetDebuffs)
	self:updateBuffs("target", "HARMFUL", targetDebuffs)

	if FacerollerDB.rangecheck == 1 or FacerollerDB.powercheck == 1 then
		self:SetScript ("OnUpdate", self.OnUpdateFunc)
	end
	DisplayFrame:Show()
	self:CallNextSkillFunc()
end


function Faceroller:UNIT_FACTION()
	self:PLAYER_TARGET_CHANGED()
end


-- update buffs / debuffs for player / target.
function Faceroller:UNIT_AURA(unit)
	if unit == "target" then
		self:updateBuffs("target", "HARMFUL|PLAYER", myTargetDebuffs)
		self:updateBuffs("target", "HARMFUL", targetDebuffs)
		self:CallNextSkillFunc()
		return
	elseif unit == "player" then
		self:updateBuffs("player", "HELPFUL|PLAYER", playerBuffs)
		self:updateBuffs("player", "HELPFUL", playerBuffsOther)
		self:updateBuffs("player", "HARMFUL", playerDebuffs)
		self:CallNextSkillFunc()
		return
	end
end


function Faceroller:PLAYER_ENTERING_WORLD()
	-- make sure buffs are updated when doing a reloadui
	self:updateBuffs("player", "HELPFUL|PLAYER", playerBuffs)
	self:updateBuffs("player", "HELPFUL", playerBuffsOther)
	self:updateBuffs("player", "HARMFUL", playerDebuffs)

	local _, t = GetInstanceInfo ()
	if t == "pvp" then
		playerinpvp = 1
	else
		playerinpvp = 0
	end
end


function Faceroller:PARTY_MEMBERS_CHANGED()
	if GetNumRaidMembers() > 0 then
		playerinraid = 1
	else
		playerinraid = 0
	end

	if GetNumPartyMembers() > 0 then
		playerinparty = 1
	else
		playerinparty = 0
	end
end


function Faceroller:SPELL_UPDATE_COOLDOWN()
	for k, v in pairs(spells) do
		local s, d = GetSpellCooldown (k)
		v.ends = s + d
	end
	self:CallNextSkillFunc()
end


function Faceroller:SPELL_UPDATE_USABLE()
	for _, v in pairs (spells) do
		if v.name then
			v.usable = IsUsableSpell(v.name)
		end
	end
	self:CallNextSkillFunc()
end


function Faceroller:UNIT_SPELLCAST_SENT(caster, spell, rank, target)
	if caster == "player" then
		local x = gsi_name_mt[spell]

		if x ~= -1 then
			spells[x].enabled = 1
		end
		self:CallNextSkillFunc()
	end
end


function Faceroller:UNIT_SPELLCAST_SUCCEEDED(caster, spell, rank)
	if caster == "player" then
		local x = gsi_name_mt[spell]

		if x ~= -1 then
			spells[x].enabled = 0
		end

		-- try to guess debuff application. If the spell name
		-- matches one of the debuffs we watch for our self,
		-- assume the spell will hit and apply the debuff.
		-- (XXX: spell icons)
		local mtd

		mtd = myTargetDebuffs[spell]
		if mtd and not mtd.active then
			local now = GetTime()
			mtd.ghost = now + ghostkeepalive
			mtd.active = true
			mtd.ends = now + 20
		end

		mtd = targetDebuffs[spell]
		if mtd and not mtd.active then
			local now = GetTime()
			mtd.ghost = now + ghostkeepalive
			mtd.active = true
			mtd.ends = now + 20
		end

		-- special case: Arcane Blast applies a debuff to
		-- us and it stacks.
		mtd = playerDebuffs[spell]
		if mtd then
			local now = GetTime()

			mtd.ghost = now + ghostkeepalive
			mtd.ends = now + 6

			if mtd.active then
				mtd.count = mtd.count + 1
			else
				mtd.active = true
				mtd.count = 1
			end
		end

		self:CallNextSkillFunc()
	end
end


function Faceroller:PLAYER_TALENT_UPDATE()
	local s = GetActiveTalentGroup()

	if s ~= self.spec then
		self.spec = s
		self:UseModuleForSpec()
	end
end


-- this event is registered in ADDON_LOADED and unregistered
-- once it fired. The reason for this is that on login, the
-- spellbook is not initialized, but after SKILL_LINES_CHANGED
-- fired.
function Faceroller:SKILL_LINES_CHANGED()
	self:RegisterEvent("PLAYER_TALENT_UPDATE")
	self:UnregisterEvent("SKILL_LINES_CHANGED")

	-- find suitable spell for gcdSpell
	local referenceSpells = {
		49892,			-- Death Coil (Death Knight)
		66215,			-- Blood Strike (Death Knight)
		1978,			-- Serpent Sting (Hunter)
		585,			-- Smite (Priest)
		19740,			-- Blessing of Might (Paladin)
		172,			-- Corruption (Warlock)
		5504,			-- Conjure Water (Mage)
		772,			-- Rend (Warrior)
		331,			-- Healing Wave (Shaman)
		1752,			-- Sinister Strike (Rogue)
		5176,			-- Wrath (Druid)
	}

	for _, lspell in pairs(referenceSpells) do
		local x = self:HasSpell(lspell)
		if x ~= nil then
			gcdSpell = lspell
			break
		end
	end

	if gcdSpell == nil then
		Print(L["Error: didn't find a reference spell for the global coldown. Cooldown spiral on the Faceroller frame disabled."])
	end

	self.spec = GetActiveTalentGroup()
	self:UseModuleForSpec()
end
