local MAJOR, MINOR = "libCandyIcon-1.0", 1
local libCandyIcon, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not libCandyIcon then return end


--[[

values for lci_state. candy icons go from:

 - OFF (initial state) to FADEIN when Play() is called,
 - from FADEIN to IDLE automaticly,
 * if the candy icon has no fadein animations, it goes
   from OFF to IDLE on Play().
 - from IDLE to FADEOUT, when Stop() is called,
 - from FADEOUT to OFF automaticly.
 * if no fadeout animations were set, from IDLE to OFF
   on Stop()

--]]
local ANIM_OFF = 0
local ANIM_FADEIN = 1
local ANIM_FADEOUT = 2
local ANIM_IDLE = 3


--[[

animation functions get two parameters: 

	self:	the candy icon frame
	c:	the completion of the animation as a number [0..1],
		if the animation is used to fade, or the elapsed
		time since animation kick off.

if a animation needs to save additional data, it should do so
in a field in the candy icon frame object (preferably in a field
named lci_<animation_name>).

--]]
local function ZoominFunc(self, c)
	local s = self.lci_size * c

	self:SetHeight (s)
	self:SetWidth (s)
end


local function ZoomoutFunc(self, c)
	local s = self.lci_size - (self.lci_size * c)

	self:SetHeight (s)
	self:SetWidth (s)
end


local function FadeinFunc(self, c)
	local a = self.lci_alpha * c
	self:SetAlpha (a)
end


local function FadeoutFunc(self, c)
	local a = self.lci_alpha - (self.lci_alpha * c)
	self:SetAlpha (a)
end


local function BounceFunc(self, c)
	local s = self.lci_size + (self.lci_size * 0.1) * sin(c * 500)

	self:SetHeight (s)
	self:SetWidth (s)
end


local function MagnifyFunc(self, c)
	local s = self.lci_size + self.lci_size * c

	self:SetHeight (s)
	self:SetWidth (s)
end


local function ShrinkFunc(self, c)
	local s = self.lci_size + self.lci_size * (1 - c)

	self:SetHeight (s)
	self:SetWidth (s)
end

--[[

the candy frame currently carries animations as a string
of animation names, seperated by '|'. Probably should
create a table of functions and call each in turn. But
this will do for now.

--]]
local animations = {
	["zoomin"] = ZoominFunc,
	["zoomout"] = ZoomoutFunc,
	["fadein"] = FadeinFunc,
	["fadeout"] = FadeoutFunc,
	["bounce"] = BounceFunc,
	["magnify"] = MagnifyFunc,
	["shrink"] = ShrinkFunc,
}


local function RunAnimations(self, x, c)
	for i, v in pairs(animations) do
		if string.find (x, i) ~= nil then
			v(self,c)
		end
	end
end


--
-- update function
--
local function CandyIconUpdateFunc(self, t)
	local c

	self.tick = self.tick + t

	if self.lci_state == ANIM_FADEIN then
		c = self.tick / self.lci_fadein_duration
		if c > 1 then c = 1 end

		RunAnimations(self, self.lci_fadein_anim, c)

		if c == 1 then
			self.lci_state = ANIM_IDLE
			self.tick = 0
		end
	elseif self.lci_state == ANIM_FADEOUT then
		c = self.tick / self.lci_fadeout_duration
		if c > 1 then c = 1 end

		RunAnimations(self, self.lci_fadeout_anim, c)

		if c == 1 then
			self.lci_state = ANIM_OFF
			self:SetScript("OnUpdate", nil)
			self:lci_Hide()
		end
	elseif self.lci_state == ANIM_IDLE then
		if self.lci_idle_anim == nil or self.lci_idle_anim == "" then
			self:SetScript ("OnUpdate", nil)
		else
			RunAnimations(self, self.lci_idle_anim, self.tick)
		end
	elseif self.lci_state == ANIM_OFF then
		-- should never end up here.
		-- print ("libCandyIcon: off but update? disabling OnUpdate.")
		self:SetScript ("OnUpdate", nil)
	end
end


--
-- functions added to the candy icon frame object
--
local function CandyIconPlayFunction(self)
	-- no fadein animation set. go directly to idle.
	if self.lci_fadein_anim == nil or self.lci_fadein_anim == "" then
		self:SetAlpha(self.lci_alpha)
		self.lci_state = ANIM_IDLE
		return
	end

	-- don't care about current state, except when fadeing out. in that
	-- case, start off elapsed time.
	if self.lci_state ~= ANIM_FADEOUT then
		self.tick = 0
	end

	self.lci_state = ANIM_FADEIN
	self:lci_Show()
	self:SetScript ("OnUpdate", CandyIconUpdateFunc)
end


local function CandyIconStopFunction(self)
	-- still in ANIM_FADEIN, start of elapsed time
	if self.lci_state == ANIM_FADEIN then
		self.lci_state = ANIM_FADEOUT
		return
	end

	-- no fadeout animation set. go directly to off.
	if self.lci_fadeout_anim == nil or self.lci_fadeout_anim == "" then
		self:SetScript ("OnUpdate", nil)
		self:lci_Hide()
		self.lci_state = ANIM_OFF
		return
	end

	self.tick = 0
	self:SetAlpha(0)
	self.lci_state = ANIM_FADEOUT
	self:SetScript ("OnUpdate", CandyIconUpdateFunc)
end


--
-- the visible API
--

--[[

RegisterAnimation:

Register a animation to use for candy icons.

Parameters:
	name (string):		name of the animation.
	func (function):	the animation function.

--]]
function libCandyIcon:RegisterAnimation(name, func)
	table.insert(animations, name, func)
end


function libCandyIcon:MakeCandyIcon(f, values)
	f.lci_size = f:GetHeight()
	f.lci_alpha = f:GetAlpha()

	f.lci_fadein_anim = "zoomin|fadein"
	f.lci_fadein_duration = 0.5
	f.lci_fadeout_anim = "zoomout|fadeout"
	f.lci_fadeout_duration = 0.5
	f.lci_idle_anim = nil
	f.lci_state = ANIM_OFF

	f.lci_tick = 0

	f.Play = CandyIconPlayFunction
	f.Stop = CandyIconStopFunction

	f.lci_Hide = f.Hide
	f.lci_Show = f.Show

	if values then
		if values["alpha"] then
			f:SetAlpha(values["alpha"])
			f.lci_alpha = values["alpha"]
		end

		if values["size"] then
			f:SetHeight(values["size"])
			f:SetWidth(values["size"])
		end

		if values["fadein_anim"] then
			f.lci_fadein_anim = values["fadein_anim"]
		end

		if values["fadein_duration"] then
			f.lci_fadein_duration = values["fadein_duration"]
		end

		if values["fadeout_anim"] then
			f.lci_fadeout_anim = values["fadeout_anim"]
		end

		if values["fadeout_duration"] then
			f.lci_fadeout_duration = values["fadeout_duration"]
		end

		if values["idle_anim"] then
			f.lci_idle_anim = values["idle_anim"]
		end

		-- XXX what else do we need here ...
	end
end

--[[

NewCandyIcon:

Create a new candy icon.

Parameters:
	name (string):		frame name.
	parent (frame obj):	the parent of the frame.
	values (dictionary):	used to set default values when frame is created.

--]]
function libCandyIcon:NewCandyIcon(name, parent, values)
	if not parent then
		parent = UIParent
	end

	local size = 100
	f = CreateFrame("Frame", name, parent)

	f:SetFrameStrata("BACKGROUND")
	f:SetWidth(size)
	f:SetHeight(size)
	f:SetScale(1)
	f:SetAlpha(1)
	f:SetMovable(false)
	f:SetClampedToScreen(true)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

	f.texture = f:CreateTexture(nil, "BACKGROUND")

	f.texture:ClearAllPoints()
	f.texture:SetAllPoints(f)
	f.texture:SetTexture("Interface\\Icons\\Ability_Hunter_LongShots")
	f.texture:SetVertexColor(1, 1, 1)

	self:MakeCandyIcon (f, values)

	f:lci_Hide()
	return f
end
