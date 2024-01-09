-- ui.lua

screen = UI.ScreenSize()
center = {x=screen.width/2, y=screen.height/2}
print(version)

KZ = {}

local SyncValueCreate = SyncValueSet(UI)

function TextOffSet(place, value, negative)
	return bool_to_number(place == 'bottom' or place == 'right', value, negative)
end

function getHeight(size)
	return size == 'small' and 22 or size == 'medium' and 42 or size == 'large' and 58 or size == 'verylarge' and 88
end

function UI.Text:SetPosition(set)
	local size = set.Size
	local place = splitstr(set.Place, "-")
	local zoom = set.Zoom
	local Y = TextOffSet(place[1], screen.height) - TextOffSet(place[1], screen.height*zoom, true)
	local X = TextOffSet(place[2], -screen.width*zoom, place[2] ~= 'center')
	
	self:Set({font=size, align=place[2], x=X, y=Y, width=screen.width, height=getHeight(size)})
end

function listFind(inputs)
	local input = nil
	
	for key, bool in pairs(inputs) do
		if bool then
			input = key
		end
	end
	
	return input
end

KZ.Index = UI.PlayerIndex()
KZ.Player = {}
KZ.Event = {}

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- Fade Text Module

FadeText = {}

function FadeText:Setup(object, visibleFrame, keepFrame, fadeoutFrame, alpha)
	local user = setmetatable({}, self)
	self.__index = self
	
	user.text = object
	user.value = 0
	user.visibleFrame = visibleFrame or 1 -- 보여지는 프레임
	user.keepFrame = keepFrame or 1 -- 온전히 보이는 프레임
	user.fadeoutFrame = fadeoutFrame or 1 -- 사라지는 프레임
	user.alpha = alpha
	
	FadeText[#FadeText + 1] = user
	
	return user
end

function FadeText:Fade(string)
	self.text:Set({text=string or self.text:Get().text})
	self.value = 1
end

function FadeText:IsVisible()
	return self.value ~= 0
end

function FadeText:FadeOn()
	local alpha = math.floor((self.alpha/self.visibleFrame) * self.value)
	self.text:Set({a=alpha})
end

function FadeText:FadeOut()
	local alpha = self.alpha - math.floor((self.alpha/self.fadeoutFrame) * (self.value-self.visibleFrame-self.keepFrame))
	self.text:Set({a=alpha})
end

function FadeText:FadeControl()
	if self.value <= self.visibleFrame then
		self:FadeOn()
	elseif self.value >= self.visibleFrame + self.keepFrame + self.fadeoutFrame then
		self.value = 0
		self.text:Set({a=0})
		return
	elseif self.value >= self.visibleFrame + self.keepFrame then
		self:FadeOut()
	end
	
	self.value = self.value + 1
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- Menu Module

Menu = {}

function Menu:IsVisible()
	return self.stack[1]:IsVisible()
end

function Menu:new(titleArg, elemArg, elemCount)
	local menu = setmetatable({}, self)
	self.__index = self
	
	menu.titleArg = titleArg
	menu.elemArg = {}
	
	menu.stack = {}
	
	menu.title = UI.Text.Create()
	menu.title:Set(titleArg)
	
	menu.stack[#menu.stack + 1] = menu.title
	
	menu.elem = {}
	
	for k, v in pairs(elemArg) do
		menu.elem[k] = {}
		menu.elemArg[k] = v
		for i = 1, elemCount do
			menu.elem[k][i] = UI.Text.Create()
			menu.elem[k][i]:Set(v)
			menu.elem[k][i]:Set({y=v.y + ((i-1)*20)})
			menu.stack[#menu.stack + 1] = menu.elem[k][i]
		end
	end
	
	Menu[#Menu + 1] = menu
	
	return menu
end

function Menu:PageSetup(data, elemIndex)
	if not self.iter then
		self.iter = {}
		self.page = 0
	end
	
	self.iter[elemIndex] = data
	self:Page(self.page) -- 내용 새로고침
end

function Menu:Page(page)
	page = page or 0
	
	local maxcount = 0
	local maxnumber = 0
	
	if not self.titleText then
		self.titleText = self.title:Get().text
	end
	
	for k, v in pairs(self.iter) do
		maxcount = #v
		maxnumber = math.min(maxcount - (page * 7), 7)
		
		for i = 1, maxnumber do
			self.elem[k][i]:Set({text=v[i+(page*7)]})
		end
	end
	
	for i = 1, #self.elem do
		for j = 1, maxnumber do
			self.elem[i][j]:Set({a=self.elemArg[i].a})
		end
		
		for j = maxnumber+1, 7 do
			self.elem[i][j]:Set({a=0})
		end
		
		self.elem[i][8]:Set({a=self.elemArg[i].a})
		self.elem[i][9]:Set({a=self.elemArg[i].a})
	end
	
	self.title:Set({text=self.titleText..string.format(" %d/%d", page+1, math.max(math.ceil(maxcount/7), 1))})
	
	if page == 0 then -- Back
		for i = 1, #self.elem do
			self.elem[i][8]:Set({a=80})
		end
	end
	
	if maxcount < ((page+1) * 7) then -- More
		for i = 1, #self.elem do
			self.elem[i][9]:Set({a=80})
		end
	end
end

function Menu:Visible(visible, page)
	if visible then
		if self.page then
			self:Page(page)
		end
		
		for k, v in pairs(self.stack) do
			v:Show()
		end
	else
		for k, v in pairs(self.stack) do
			v:Hide()
		end
		
		if self.page then
			self.page = 0
		end
	end
end

function Menu:PageDown()
	if self.page == nil then
		return
	end
	
	if self.page > 0 then
		self.page = self.page - 1
		self:Visible(true, self.page)
	end
end

function Menu:PageUp()
	if self.page == nil then
		return
	end
	
	for _, v in pairs(self.iter) do
		if #v > ((self.page+1) * 7) then
			self.page = self.page + 1
			self:Visible(true, self.page)
			return
		end
	end
end

function Menu:ActionSetup(number, method)
	-- 메뉴 버튼에 메서드 할당
	if self.event == nil then
		self.event = {}
	end
	
	self.event[number] = method
end

function Menu:Action(number)
	if self.event == nil or self.event[number] == nil then
		return
	end
	
	self.event[number](self)
end

function Menu:Showing()
	-- 보여지고 있는 메뉴 검색
	for k, v in ipairs(Menu) do
		if v:IsVisible() then
			return v
		end
	end
	
	return self
end

function Menu:Toggle()
	-- 보여지고 있는 메뉴를 토글하면 메뉴 숨기기
	-- 보여지고 있는 메뉴와 다른 메뉴를 토글하면 메뉴 새로 보이기
	for k, v in ipairs(Menu) do
		v:Visible(v == self and not v:IsVisible())
	end
end

local title_set = HUD.Menu.Title
local default_color = HUD.Menu.Elem.Color_default
local number_color = HUD.Menu.Elem.Color_number

local menuTitleSet = {font='small', align='left', x=30, y=center.y-124, width=250, height=20,
	r=title_set.Color.r, g=title_set.Color.g, b=title_set.Color.b, a=title_set.Color.a}
local menuNumberSet = {font='small', align='left', x=30, y=center.y-90, width=250, height=20,
	r=number_color.r, g=number_color.g, b=number_color.b, a=number_color.a}
local menuElemSet = {font='small', align='left', x=48, y=center.y-90, width=250, height=20,
	r=default_color.r, g=default_color.g, b=default_color.b, a=default_color.a}

KZ.Menu = Menu

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- HUD

local label_set = HUD.Label

label_1 = UI.Text.Create()
label_2 = UI.Text.Create()

label_1:SetPosition(label_set)
label_2:SetPosition(label_set)

label_1:Set({text=label_set.Text_1, r=label_set.Color_1.r, g=label_set.Color_1.g, b=label_set.Color_1.b, a=label_set.Color_1.a})
label_2:Set({text=label_set.Text_2, r=label_set.Color_2.r, g=label_set.Color_2.g, b=label_set.Color_2.b, a=label_set.Color_2.a})

local descr_set = HUD.Descr.DefaultMenu

descr = UI.Text:Create()
descr:Set({text=descr_set.Text, font='small', align="right", x=-20, y=screen.height/4*3, width=screen.width, height=16,
	r=descr_set.Color.r, g=descr_set.Color.g, b=descr_set.Color.b, a=descr_set.Color.a})

local Notice = HUD.Notice
local main_set = Notice.Main
local under_set = Notice.Under
local issue_set = Notice.Issue

clearNotice = UI.Text.Create()
underNotice = UI.Text.Create()
issueText = UI.Text:Create()

clearNotice:SetPosition(main_set)
underNotice:SetPosition(under_set)

clearNotice:Set({r=main_set.Color.r, g=main_set.Color.g, b=main_set.Color.b, a=main_set.Color.a})
underNotice:Set({r=under_set.Color.r, g=under_set.Color.g, b=under_set.Color.b, a=under_set.Color.a})
issueText:Set({font='small', align="left", x=30, y=screen.height/20*14, width=screen.width, height=screen.height/10,
	r=issue_set.Color.r, g=issue_set.Color.g, b=issue_set.Color.b, a=issue_set.Color.a})

FadeText.main = FadeText:Setup(clearNotice, main_set.VisibleFrame, main_set.KeepFrame, main_set.FadeoutFrame, main_set.Color.a)
FadeText.under = FadeText:Setup(underNotice, under_set.VisibleFrame, under_set.KeepFrame, under_set.FadeoutFrame, under_set.Color.a)
FadeText.issue = FadeText:Setup(issueText, issue_set.VisibleFrame, issue_set.KeepFrame, issue_set.FadeoutFrame, issue_set.Color.a)

if DebugMode then
	clearNotice:Set({text="Unknown 맵 클리어 00:00.00 ( CPs: 0| GCs: 0 ) !"})
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 속도계

local Unit = HUD.Unit
local pre_set = Unit.Pre
local max_set = Unit.Max
local speed_set = Unit.Speed

playerPre = UI.Text.Create()
playerMax = UI.Text.Create()
playerSpeed = UI.Text.Create()

playerPre:SetPosition(pre_set)
playerMax:SetPosition(max_set)
playerSpeed:SetPosition(speed_set)

playerPre:Set({r=pre_set.Color_default.r, g=pre_set.Color_default.g, b=pre_set.Color_default.b, a=pre_set.Color_default.a})
playerMax:Set({r=max_set.Color.r, g=max_set.Color.g, b=max_set.Color.b, a=max_set.Color.a})
playerSpeed:Set({r=speed_set.Color.r, g=speed_set.Color.g, b=speed_set.Color.b, a=speed_set.Color.a})

FadeText.Pre = FadeText:Setup(playerPre, pre_set.VisibleFrame, pre_set.KeepFrame, pre_set.FadeoutFrame, pre_set.Color_default.a)
FadeText.Max = FadeText:Setup(playerMax, max_set.VisibleFrame, max_set.KeepFrame, max_set.FadeoutFrame, max_set.Color.a)

function SetGroundSpeed(index)
	speed = SyncValueCreate(string.format("groundSpeed%i", index))
	
	function speed:OnSync()
		playerSpeed:Set({text=string.format("%d units/sec", math.floor(self.value))})
	end
end

function SetPreStrafe(index)
	pre = SyncValueCreate(string.format("preStrafe%i", index))
	
	function pre:OnSync()
		local str
			
		if self.value >= 10000 then
			local pre = self.value % 10000
			local limit = 250*1.2 -- movement 정보 받을 것
			
			if pre >= limit then
				str = string.format("Your prestrafe %03.3f is too high (%03.3f)", pre, limit)
				playerPre:Set(pre_set.Color_fail)
			else
				str = string.format("%03.3f pre", pre)
				playerPre:Set(pre_set.Color_default)
			end
		else
			str = string.format("%03.3f pre", self.value)
			playerPre:Set(pre_set.Color_default)
		end
		
		FadeText.Pre:Fade(str)
	end
end

function SetMaxSpeed(index)
	maxspeed = SyncValueCreate(string.format("maxSpeed%i", index))
	
	function maxspeed:OnSync()
		if not pre.value or pre.value % 10000 > self.value then
			return
		end
		
		local P = tonumber(pre.value) % 10000
		local M = tonumber(self.value)
		if P > 250*1.2 then P = 250*0.96 end -- movement 정보 받을 것
		local cal = M - P
		if cal < 0 then cal = 0 end
		local str = string.format("Maxspeed: %03.2f (%05.3f)", self.value, cal)
		
		FadeText.Max:Fade(str)
	end
end

function KZ.Event:SetSpeedMeter(index)
	if speed then
		function speed:OnSync()
		end
	end
	
	if pre then
		function pre:OnSync()
		end
	end
	
	if maxspeed then
		function maxspeed:OnSync()
		end
	end
	
	SetGroundSpeed(index)
	SetPreStrafe(index)
	SetMaxSpeed(index)
end

KZ.Event:SetSpeedMeter(KZ.Index)

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 타이머

pauseScreen = {}

pauseScreen_BG = UI.Box.Create()
pauseScreen_BG:Set({width=screen.width, height=screen.height, r=180,g=180,b=255,a=20})
pauseScreen[#pauseScreen + 1] = pauseScreen_BG

pauseScreen_TOP = {}
pauseScreen_LEFT = {}
pauseScreen_RIGHT = {}
pauseScreen_BOTTOM = {}

for i = 1, 80 do
	pauseScreen_TOP[i] = UI.Box.Create()
	pauseScreen_LEFT[i] = UI.Box.Create()
	pauseScreen_RIGHT[i] = UI.Box.Create()
	pauseScreen_BOTTOM[i] = UI.Box.Create()
	
	pauseScreen_TOP[i]:Set({y=i-1, width=screen.width, height=1, r=120,g=120,b=255,a=80-i})
	pauseScreen_LEFT[i]:Set({x=i-1, width=1, height=screen.height, r=120,g=120,b=255,a=80-i})
	pauseScreen_RIGHT[i]:Set({x=screen.width-(i-1), width=1, height=screen.height, r=120,g=120,b=255,a=80-i})
	pauseScreen_BOTTOM[i]:Set({y=screen.height-(i-1), width=screen.width, height=1, r=120,g=120,b=255,a=80-i})
	
	pauseScreen[#pauseScreen + 1] = pauseScreen_TOP[i]
	pauseScreen[#pauseScreen + 1] = pauseScreen_LEFT[i]
	pauseScreen[#pauseScreen + 1] = pauseScreen_RIGHT[i]
	pauseScreen[#pauseScreen + 1] = pauseScreen_BOTTOM[i]
end

function pauseScreenVisible(visible)
	if visible then
		for i = 1, #pauseScreen do
			pauseScreen[i]:Show()
		end
	else
		for i = 1, #pauseScreen do
			pauseScreen[i]:Hide()
		end
	end
end

pauseScreenVisible(false)

Timer = {}

KZ.Player.cp = {}
KZ.Player.gc = {}

local timer_set = HUD.Timer

Timer.timer = UI.Text.Create()
Timer.timer:SetPosition(timer_set)
Timer.timer:Set({text="00:00.00", r=timer_set.Color.r, g=timer_set.Color.g, b=timer_set.Color.b, a=timer_set.Color.a})

function Timer:Init() -- 접속 시
	KZ.Player.cp[UI.PlayerIndex()] = 0
	KZ.Player.gc[UI.PlayerIndex()] = 0
	KZ.Clear = false
	Timer:Reset()
end

function Timer:Reset(clear) -- 타이머 종료, 제트팩 리셋, 세이브 리셋, 종료 리셋
	Timer.pause = false
	Timer.startTime = 0
	Timer.pauseTime = 0
	Timer.pauseStart = 0
	Timer.pauseEnd = 0
	
	if clear then
		-- 맵 클리어가 아니고 타이머 재정비
		Timer.timer:Set({text="00:00.00"})
	end
end

function Timer:GetTime()
	return UI.GetTime() - (Timer.startTime + Timer.pauseTime)
end

function Timer:CanStartAndFinish()
	-- 타이머를 시작/종료할 수 없는 상태면 false
	
	if KZ.Used_JetPack > UI.GetTime() then -- 제트팩 후 3초 방지
		FadeText.under:Fade(ReservedText.UsedJetPack)
		return false
	end
	
	return not Timer.pause
end

function Timer:Start()
	if Timer:CanStartAndFinish() then
		Timer:Reset()
		Timer.startTime = UI.GetTime()
		FadeText.under:Fade(ReservedText.TimerStart)
		KZ.JetPack = false
	end
end

function Timer:Finish()
	if Timer.startTime == 0 then
		FadeText.under:Fade(ReservedText.DidNotStart)
	elseif Timer:CanStartAndFinish() then
		UI.Signal(math.floor(Timer:GetTime()*100))
		Timer:Reset(false)
		KZ.Clear = true
	end
end

function Timer:Pause_On()
	Timer.pause = true
	pauseElem:Set({text="ON", g=255})
	pauseScreenVisible(true)
	Timer.pauseStart = UI.GetTime()
	FadeText.under:Fade(ReservedText.PauseOn)
end

function Timer:Pause_Off(reset)
	Timer.pause = false
	if KZ.JetPack then
		-- 제트팩 강제 종료
		KZ.JetPack = false
		UI.Signal(SIGNAL.ToGame.NC_OFF)
	end
	pauseElem:Set({text="OFF", g=50})
	pauseScreenVisible(false)
	Timer.pauseEnd = Timer.pauseEnd + (UI.GetTime() - Timer.pauseStart)
	FadeText.under:Fade(ReservedText.PauseOff)
	
	if reset then
		-- 퍼즈 중 세이브를 하면 퍼즈 포지션으로 이동하지 않고 리셋만
		UI.Signal(SIGNAL.ToGame.RESET)
	else
		UI.Signal(SIGNAL.ToGame.PAUSE_OFF)
	end
end

function Timer:Refresh()
	local time = Timer:GetTime()
	Timer.timer:Set({text=string.format("%02d:%05.2f", time//60, time%60)})
end

function KZ.Event:Pause()
	if not Timer.pause then
		if Timer.startTime == 0 then
			FadeText.under:Fade(ReservedText.DidNotStart)
		else
			UI.Signal(SIGNAL.ToGame.PAUSE_ON)
		end
	else
		Timer:Pause_Off()
	end
end

KZ.Timer = Timer

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 클리어

sessionRank = SyncValueCreate('sessionRank', 3)
clear = SyncValueCreate('clear')

sessionRanking = {}

for i = 1, 3 do
	local session_set = HUD.Session_Rank[i]
	sessionRanking[i] = UI.Text.Create()
	sessionRanking[i]:Set({font="small", align="left", x=screen.width/35, y=screen.height/8+((i-1)*48), width=300, height=40,
		r=session_set.Color.r, g=session_set.Color.g, b=session_set.Color.b, a=session_set.Color.a})
	
	local rank = sessionRank[i]
	function rank:OnSync()
		sessionRanking[i]:Set({text=session_set.Text.."\n"..self.value})
	end
end

function clear:OnSync()
	FadeText.main:Fade(self.value)
end

if DebugMode then
	for i = 1, 3 do
		local session_set = HUD.Session_Rank[i]
		sessionRanking[i]:Set({text=session_set.Text.."\n".."00:00.00 (0/0) Unknown"})
	end
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 체크포인트

CP = SyncValueCreate('checkPoint', VALUE.MaxPlayer)
GC = SyncValueCreate('goCheck', VALUE.MaxPlayer)

for i = 1, VALUE.MaxPlayer do
	local cp = CP[i]
	local gc = GC[i]
	
	function cp:OnSync()
		if i == UI.PlayerIndex() then
			KZ.Event:OnCheckPoint(self.value)
		end
		
		KZ.Player.cp[i] = self.value
		KZ.Event:RefreshSpecTimer(i)
	end
	
	function gc:OnSync()
		if i == UI.PlayerIndex() then
			KZ.Event:OnGoCheck(self.value)
		end
		
		KZ.Player.gc[i] = self.value
		KZ.Event:RefreshSpecTimer(i)
	end
end

function KZ.Event:OnCheckPoint(value)
	if value ~= 0 then
		local txt = string.format("체크포인트 ＃%d", value)
		FadeText.under:Fade(txt)
	end
	
	local str = string.format("＃%d", value)
	cpElem:Set({text=str})
end

function KZ.Event:OnGoCheck(value)
	if value ~= 0 then
		local txt = string.format("고체크 ＃%d", value)
		FadeText.under:Fade(txt)
	end
	
	local str = string.format("＃%d", value)
	gcElem:Set({text=str})
end

function KZ.Event:CP()
	if MAP.CanCP then
		UI.Signal(SIGNAL.ToGame.CP)
	end
end

function KZ.Event:GC()
	if MAP.CanCP then
		UI.Signal(SIGNAL.ToGame.GC)
	end
end

function KZ.Event:BackCP()
	if MAP.CanCP then
		UI.Signal(SIGNAL.ToGame.BACKCP)
	end
end

function KZ.Event:Start()
	if UndefinedPosition then
		UI.Signal(SIGNAL.ToGame.FREESTART)
	else
		UI.Signal(SIGNAL.ToGame.START)
	end
	
	FadeText.under:Fade(ReservedText.TPtoStart)
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 관전

Spec = {}

KZ.Player.name = {}
KZ.Player.time = {}

specPlayer = SyncValueCreate('specPlayer', VALUE.MaxPlayer)

for k, v in pairs(specPlayer) do
	function v:OnSync()
		KZ.Player.name[k] = self.value
		
		KZ.playerList = KZ.Event:SetPlayerList()
		specMenu:PageSetup(KZ.playerList.name, 2)
		tpMenu:PageSetup(KZ.playerList.name, 2)
	end
end

function KZ.Event:SetPlayerList()
	local list = {}
	
	list.index = {}
	list.name = {}
	
	for index, name in pairs(KZ.Player.name) do
		if name ~= '' then
			list.index[#list.index + 1] = index
			list.name[#list.name + 1] = name
		end
	end
	
	return list
end

specMenu = Menu:new(menuTitleSet, {menuNumberSet, menuElemSet}, 10)

specMenu.title:Set({text=title_set.SpecMenu})
specMenu.elem[1][1]:Set({text="1. "})
specMenu.elem[1][2]:Set({text="2. "})
specMenu.elem[1][3]:Set({text="3. "})
specMenu.elem[1][4]:Set({text="4. "})
specMenu.elem[1][5]:Set({text="5. "})
specMenu.elem[1][6]:Set({text="6. "})
specMenu.elem[1][7]:Set({text="7. "})
specMenu.elem[1][8]:Set({text="8. "})	specMenu.elem[2][8]:Set({text="Bacｋ"})
specMenu.elem[1][9]:Set({text="9. "})	specMenu.elem[2][9]:Set({text="More"})
specMenu.elem[1][10]:Set({text="0. "})	specMenu.elem[2][10]:Set({text="Exit"})

specMenu:PageSetup(KZ.Event:SetPlayerList().name, 2)

specMenu:Visible(false)

local spectimer_set = HUD.Spec.Timer
local specname_set = HUD.Spec.Name

spectating = {}

Spec.timer = UI.Text.Create()
Spec.timer:SetPosition(spectimer_set)
Spec.timer:Set({r=spectimer_set.Color.r, g=spectimer_set.Color.g, b=spectimer_set.Color.b, a=spectimer_set.Color.a})

spectating[#spectating + 1] = Spec.timer

function Spec:OnOff(value)
	-- 관전을 풀 방법이 있을거라 믿고 만들어두자
	if value then
		self.value = true
		Timer.timer:Hide()
		for _, text in ipairs(spectating) do
			text:Show()
		end
		descr:Set({text=HUD.Descr.SpecMenu.Text, r=HUD.Descr.SpecMenu.Color.r, g=HUD.Descr.SpecMenu.Color.g, b=HUD.Descr.SpecMenu.Color.b, a=HUD.Descr.SpecMenu.Color.a})
	else
		self.value = false
		Timer.timer:Show()
		for _, text in ipairs(spectating) do
			text:Hide()
		end
		descr:Set({text=HUD.Descr.DefaultMenu.Text, r=HUD.Descr.DefaultMenu.Color.r, g=HUD.Descr.DefaultMenu.Color.g, b=HUD.Descr.DefaultMenu.Color.b, a=HUD.Descr.DefaultMenu.Color.a})
	end
end

function Spec:playerSelect()
	local i = OnInputNumber + (specMenu.page*7)
	
	if KZ.playerList.index[i] then
		KZ.Event:ConnectIndex(KZ.playerList.index[i])
		specMenu:Toggle()
	end
end

Spec.CPs = {}

sharingTime = SyncValueCreate('sharingTime', VALUE.MaxPlayer)

for i, v in pairs(sharingTime) do
	function v:OnSync()
		KZ.Player.time[i] = self.value
		KZ.Event:RefreshSpecTimer(i)
	end
end

function KZ.Event:ConnectIndex(index)
	-- 인덱스를 받음
	-- 기존에 받던 인덱스의 ui들 초기화
	-- ui 새로고침
	KZ.Index = index
	self:SetSpeedMeter(index)
	
	-- Spectating player.name
	Spec.name:Set({text=string.format("Spectating %s", KZ.playerList.name[index])})
	
	KZ.Event:RefreshSpecTimer(index)
end

function KZ.Event:Spec()
	Spec:OnOff(true)
	UI.Signal(SIGNAL.ToGame.SPEC) -- 플레이어를 죽임
	specMenu:Toggle()
end

function KZ.Event:RefreshSpecTimer(index)
	local CPs = string.format("[CPs: %d, GCs: %d]", KZ.Player.cp[index] or 0, KZ.Player.gc[index] or 0)
	local Time = KZ.Player.time[index] or '00:00'
	
	Spec.CPs[index] = Time.." "..CPs
	
	if KZ.Index == index then
		Spec.timer:Set({text=Spec.CPs[index]})
	end
end

specMenu:ActionSetup(1, Spec.playerSelect)
specMenu:ActionSetup(2, Spec.playerSelect)
specMenu:ActionSetup(3, Spec.playerSelect)
specMenu:ActionSetup(4, Spec.playerSelect)
specMenu:ActionSetup(5, Spec.playerSelect)
specMenu:ActionSetup(6, Spec.playerSelect)
specMenu:ActionSetup(7, Spec.playerSelect)
specMenu:ActionSetup(8, specMenu.PageDown)
specMenu:ActionSetup(9, specMenu.PageUp)

--------------------------------------------------------------------------------------------------

local specoverlay_set = HUD.Spec.Overlay

Spec.input_W = UI.Text.Create()
Spec.input_A = UI.Text.Create()
Spec.input_S = UI.Text.Create()
Spec.input_D = UI.Text.Create()
Spec.pause = UI.Text.Create()
Spec.name = UI.Text.Create()

Spec.input_W:SetPosition(specoverlay_set)
Spec.input_A:SetPosition(specoverlay_set)
Spec.input_S:SetPosition(specoverlay_set)
Spec.input_D:SetPosition(specoverlay_set)
Spec.pause:SetPosition(specoverlay_set)
Spec.name:SetPosition(specoverlay_set)

Spec.input_W:Set({r=specoverlay_set.Color.r, g=specoverlay_set.Color.g, b=specoverlay_set.Color.b, a=specoverlay_set.Color.a})
Spec.input_A:Set({r=specoverlay_set.Color.r, g=specoverlay_set.Color.g, b=specoverlay_set.Color.b, a=specoverlay_set.Color.a})
Spec.input_S:Set({r=specoverlay_set.Color.r, g=specoverlay_set.Color.g, b=specoverlay_set.Color.b, a=specoverlay_set.Color.a})
Spec.input_D:Set({r=specoverlay_set.Color.r, g=specoverlay_set.Color.g, b=specoverlay_set.Color.b, a=specoverlay_set.Color.a})
Spec.pause:Set({r=specoverlay_set.Color.r, g=specoverlay_set.Color.g, b=specoverlay_set.Color.b, a=specoverlay_set.Color.a})
Spec.name:Set({r=specoverlay_set.Color.r, g=specoverlay_set.Color.g, b=specoverlay_set.Color.b, a=specoverlay_set.Color.a})

spectating[#spectating + 1] = Spec.input_W
spectating[#spectating + 1] = Spec.input_A
spectating[#spectating + 1] = Spec.input_S
spectating[#spectating + 1] = Spec.input_D
spectating[#spectating + 1] = Spec.pause
spectating[#spectating + 1] = Spec.name

local W = Spec.input_W:Get()

Spec.input_W:Set({text='·'})
Spec.input_A:Set({text='·', x=W.x-16, y=W.y+16})
Spec.input_S:Set({text='·', y=W.y+16})
Spec.input_D:Set({text='·', x=W.x+16, y=W.y+16})
Spec.pause:Set({x=W.x+TextOffSet(splitstr(specoverlay_set.Place, "-")[2], 32, true), y=W.y-28})
Spec.name:Set({x=W.x+TextOffSet(splitstr(specoverlay_set.Place, "-")[2], 64, true), y=W.y+56})

Spec.input_W:Hide()
Spec.input_A:Hide()
Spec.input_S:Hide()
Spec.input_D:Hide()
Spec.pause:Hide()
Spec.name:Hide()

function KZ.Event:RefreshInputOverlay(index)
	if KZ.Index == index then
		Spec.input_W:Set({text=KZ.Player.input_W[index] and 'W' or '·'})
		Spec.input_A:Set({text=KZ.Player.input_A[index] and 'A' or '·'})
		Spec.input_S:Set({text=KZ.Player.input_S[index] and 'S' or '·'})
		Spec.input_D:Set({text=KZ.Player.input_D[index] and 'D' or '·'})
		Spec.pause:Set({text=KZ.Player.pause[index] and '[PAUSED]' or ''})
	end
end

KZ.Spec = Spec

if DebugMode then
	Spec.timer:Set({text="00:00 [CPs: 0, GCs: 0]"})
	Spec.name:Set({text="Spectating Unknown"})
	for _, text in ipairs(spectating) do
		text:Show()
	end
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 텔레포트 메뉴

TP = {}

tpMenu = Menu:new(menuTitleSet, {menuNumberSet, menuElemSet}, 10)

tpMenu.title:Set({text=title_set.TPMenu})
tpMenu.elem[1][1]:Set({text="1. "})
tpMenu.elem[1][2]:Set({text="2. "})
tpMenu.elem[1][3]:Set({text="3. "})
tpMenu.elem[1][4]:Set({text="4. "})
tpMenu.elem[1][5]:Set({text="5. "})
tpMenu.elem[1][6]:Set({text="6. "})
tpMenu.elem[1][7]:Set({text="7. "})
tpMenu.elem[1][8]:Set({text="8. "})		tpMenu.elem[2][8]:Set({text="Bacｋ"})
tpMenu.elem[1][9]:Set({text="9. "})		tpMenu.elem[2][9]:Set({text="More"})
tpMenu.elem[1][10]:Set({text="0. "})	tpMenu.elem[2][10]:Set({text="Exit"})

tpMenu:PageSetup(KZ.Event:SetPlayerList().name, 2)

tpMenu:Visible(false)

function TP:playerSelect()
	local i = OnInputNumber + (tpMenu.page*7)
	
	if KZ.playerList.index[i] then
		KZ.Event:TeleportToPlayer(KZ.playerList.index[i])
		tpMenu:Toggle()
	end
end

function KZ.Event:TeleportToPlayer(index)
	if KZ.JetPack then
		UI.Signal(index + 900000000)
	else
		FadeText.under:Fade(ReservedText.NeedJetPack)
	end
end

function KZ.Event:TP()
	tpMenu:Toggle()
end

tpMenu:ActionSetup(1, TP.playerSelect)
tpMenu:ActionSetup(2, TP.playerSelect)
tpMenu:ActionSetup(3, TP.playerSelect)
tpMenu:ActionSetup(4, TP.playerSelect)
tpMenu:ActionSetup(5, TP.playerSelect)
tpMenu:ActionSetup(6, TP.playerSelect)
tpMenu:ActionSetup(7, TP.playerSelect)
tpMenu:ActionSetup(8, tpMenu.PageDown)
tpMenu:ActionSetup(9, tpMenu.PageUp)

KZ.TP = TP

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- rtv

RTV = SyncValueCreate('RTV')

local rtv_set = HUD.RTV

rtvPlr_1 = UI.Text:Create()
rtvPlr_2 = UI.Text:Create()
rtvPlr_1:Set({font='small', align="left", x=30, y=screen.height/20*14+20, width=screen.width, height=screen.height/10,
	r=rtv_set.Color_1.r, g=rtv_set.Color_1.g, b=rtv_set.Color_1.b, a=rtv_set.Color_1.a})
rtvPlr_2:Set({font='small', align="left", x=30, y=screen.height/20*14+20, width=screen.width, height=screen.height/10,
	r=rtv_set.Color_2.r, g=rtv_set.Color_2.g, b=rtv_set.Color_2.b, a=rtv_set.Color_2.a})

FadeText.rtv_1 = FadeText:Setup(rtvPlr_1, rtv_set.VisibleFrame, rtv_set.KeepFrame, rtv_set.FadeoutFrame, rtv_set.Color_1.a)
FadeText.rtv_2 = FadeText:Setup(rtvPlr_2, rtv_set.VisibleFrame, rtv_set.KeepFrame, rtv_set.FadeoutFrame, rtv_set.Color_2.a)

function RTV:OnSync()
	local str_1 = string.format("%d 명의 유저 'rtv'가 필요합니다.", self.value)
	local str_2 = string.format("%d", self.value)
	
	FadeText.rtv_1:Fade(str_1)
	FadeText.rtv_2:Fade(str_2)
end

function KZ.Event:RTV()
	UI.Signal(SIGNAL.ToGame.RTV)
end

if DebugMode then
	rtvPlr_1:Set({text="1명의 유저 'rtv'가 필요합니다."})
	rtvPlr_2:Set({text="1"})
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- Log

Log = SyncValueCreate('Log')

function Log:OnSync()
	local value = splitstr(self.value, "|")
	if tonumber(value[1]) == UI.PlayerIndex() then
		for i = 2, #value do
			print(value[i])
		end
	end
end

function KZ.Event:Log()
	UI.Signal(SIGNAL.ToGame.LOG)
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 제트팩

function KZ.Event:NC()
	if (MAP.ClearJetPack and not KZ.Clear) then
		-- 클리어 후 제트팩 사용 가능
		FadeText.under:Fade(ReservedText.CantJP)
	else
		if KZ.JetPack then
			-- 제트팩 ON
			KZ.JetPack = false
			UI.Signal(SIGNAL.ToGame.NC_OFF)
			FadeText.under:Fade(ReservedText.JetPackOff)
		else
			-- 제트팩 OFF
			KZ.JetPack = true
			UI.Signal(SIGNAL.ToGame.NC_ON)
			FadeText.under:Fade(ReservedText.JetPackOn)
			if (Timer.startTime ~= 0 and not Timer.pause) then
				-- 타이머 리셋
				UI.Signal(SIGNAL.ToGame.RESET)
				FadeText.issue:Fade(ReservedText.TimerResetByJetPack)
			end
		end
	end
end

function KZ.Event:UseJetPack()
	if KZ.JetPack then
		UI.Signal(SIGNAL.ToGame.JETPACK)
		KZ.Used_JetPack = UI.GetTime()+3
	elseif MAP.AutoBhop then
		UI.Signal(SIGNAL.ToGame.AUTOBHOP)
	end
end


--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 커맨드

function KZ.Event:OnCommand(command)
	-- MAP.CanCP false 시 불가능한 것 : CP, GC, BackCP, Save
	if command == COMMAND.CP then
		KZ.Event:CP()
	elseif command == COMMAND.GC then
		KZ.Event:GC()
	elseif command == COMMAND.BACKCP then
		KZ.Event:BackCP()
	elseif command == COMMAND.JETPACK then
		KZ.Event:NC()
	elseif command == COMMAND.SPEC then
		KZ.Event:Spec()
	elseif command == COMMAND.START then
		KZ.Event:Start()
	elseif command == COMMAND.ALL then
		KZ.Event:All()
	elseif command == COMMAND.MENU then
		KZ.Event:Menu()
	elseif command == COMMAND.PAUSE then
		KZ.Event:Pause()
	elseif command == COMMAND.BIND then
		KZ.Event:Bind()
	elseif command == COMMAND.UNBIND then
		KZ.Event:UnBind()
	elseif command == COMMAND.LOG then
		KZ.Event:Log()
	elseif command == COMMAND.RTV then
		KZ.Event:RTV()
	elseif command == COMMAND.SAVE then
		KZ.Event:Save()
	end
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 가상 커맨드 -AuMaDeath-

CommandKeySHIFT = false

vcommandInsert = false
vcommand = ''

function InputToChar(keyIndex)
	local s = ''

	-- 스페이스 처리
	if keyIndex == 37 then
		s = ' '
	
	-- 알파벳 입력만 추출
	elseif (UI.KEY.A <= keyIndex and keyIndex <= UI.KEY.Z) then
		s = string.char(keyIndex + 87)
	end

	return s
end

function SetCommandInput(vcommand)
	if vcommandInsert then
		PlayerCommand:Show()
		PlayerCommandLine:Show()
		PlayerCommand:Set({ text = string.format("명령어 입력 중 : %s", vcommand) })
	else
		PlayerCommand:Hide()
		PlayerCommandLine:Hide()
	end
end

PlayerCommand = UI.Text.Create()
PlayerCommand:Set({font="small", align="left", x=center.x-150, y=center.y-66, width=300, height=50, r=222,g=222,b=222,a=222})
PlayerCommandLine = UI.Box.Create()
PlayerCommandLine:Set({x=center.x-152, y=center.y-44, width=304, height=1, r=222,g=222,b=222,a=222})

PlayerCommand:Hide()
PlayerCommandLine:Hide()

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 인풋 오버레이

local keyviewer_set = HUD.KeyViewer

local keyviewer_x = screen.width/5*3
local keyviewer_y = screen.height/10*9

input_W = UI.Text.Create()
input_W:Set({text="W", font='medium', align='center', x=keyviewer_x, y=keyviewer_y-40, width=40, height=41,
	r=keyviewer_set.Color.r, g=keyviewer_set.Color.g, b=keyviewer_set.Color.b, a=40})

input_A = UI.Text.Create()
input_A:Set({text="A", font='medium', align='center', x=keyviewer_x-40, y=keyviewer_y, width=40, height=41,
	r=keyviewer_set.Color.r, g=keyviewer_set.Color.g, b=keyviewer_set.Color.b, a=40})

input_S = UI.Text.Create()
input_S:Set({text="S", font='medium', align='center', x=keyviewer_x, y=keyviewer_y, width=40, height=41,
	r=keyviewer_set.Color.r, g=keyviewer_set.Color.g, b=keyviewer_set.Color.b, a=40})

input_D = UI.Text.Create()
input_D:Set({text="D", font='medium', align='center', x=keyviewer_x+40, y=keyviewer_y, width=40, height=41,
	r=keyviewer_set.Color.r, g=keyviewer_set.Color.g, b=keyviewer_set.Color.b, a=40})

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------

Input_W = SyncValueCreate('input_W', VALUE.MaxPlayer)
Input_A = SyncValueCreate('input_A', VALUE.MaxPlayer)
Input_S = SyncValueCreate('input_S', VALUE.MaxPlayer)
Input_D = SyncValueCreate('input_D', VALUE.MaxPlayer)
Pause = SyncValueCreate('Pause', VALUE.MaxPlayer)

KZ.Player.input_W = {}
KZ.Player.input_A = {}
KZ.Player.input_S = {}
KZ.Player.input_D = {}
KZ.Player.pause = {}

for i = 1, VALUE.MaxPlayer do
	local w = Input_W[i]
	local a = Input_A[i]
	local s = Input_S[i]
	local d = Input_D[i]
	local pause = Pause[i]
	
	function w:OnSync()
		KZ.Player.input_W[i] = self.value
		KZ.Event:RefreshInputOverlay(i)
	end
	
	function a:OnSync()
		KZ.Player.input_A[i] = self.value
		KZ.Event:RefreshInputOverlay(i)
	end
	
	function s:OnSync()
		KZ.Player.input_S[i] = self.value
		KZ.Event:RefreshInputOverlay(i)
	end
	
	function d:OnSync()
		KZ.Player.input_D[i] = self.value
		KZ.Event:RefreshInputOverlay(i)
	end
	
	function pause:OnSync()
		KZ.Player.pause[i] = self.value
		KZ.Event:RefreshInputOverlay(i)
	end
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- UI.Event

KZ.TimeSignal = 0
KZ.Used_JetPack = 0

OnInputNumber = 0

function UI.Event:OnUpdate(time)

	UI.Signal(SIGNAL.ToGame.ONTIME)

	if Timer.startTime ~= 0 then
		if Timer.pause then
			Timer.pauseTime = Timer.pauseEnd + (UI.GetTime() - Timer.pauseStart)
		else
			Timer:Refresh()
			
			if KZ.TimeSignal <= UI.GetTime() then
				KZ.TimeSignal = UI.GetTime()+1
				UI.Signal(1000000000 + math.floor(Timer:GetTime()*100))
			end
		end
	end
	
	for _, text in ipairs(FadeText) do
		if text:IsVisible() then
			text:FadeControl()
		end
	end
end

function UI.Event:OnSignal(signal)
	if signal == SIGNAL.ToUI.TIMER_START then 		Timer:Start()
	elseif signal == SIGNAL.ToUI.TIMER_END then 	Timer:Reset(true)
	elseif signal == SIGNAL.ToUI.FINISH then 		Timer:Finish()
	elseif signal == SIGNAL.ToUI.DONTCP then 		FadeText.under:Fade(ReservedText.DontCP)
	elseif signal == SIGNAL.ToUI.DONTPS then 		FadeText.under:Fade(ReservedText.DontPS)
	elseif signal == SIGNAL.ToUI.DONTGC then 		FadeText.under:Fade(ReservedText.DontGC)
	elseif signal == SIGNAL.ToUI.PAUSE then 		Timer:Pause_On()
	elseif signal == SIGNAL.ToUI.SAVED then 		FadeText.under:Fade(ReservedText.Saved) UI.Signal(SIGNAL.ToGame.RESET)
	elseif signal == SIGNAL.ToUI.LOAD then 			FadeText.under:Fade(ReservedText.Loaded) saveMenu:Toggle()
	elseif signal == SIGNAL.ToUI.NOSAVE then 		FadeText.under:Fade(ReservedText.NoSave)
	elseif signal == SIGNAL.ToUI.INVAILD_POSITION then FadeText.under:Fade(ReservedText.InvaildPosition)
	end
end

function UI.Event:OnSpawn()
	KZ.Event:SetSpeedMeter(KZ.Index)
	if not DebugMode then
		Spec:OnOff(false)
	end
end

function UI.Event:OnKeyDown(inputs)
	-- 가상커맨드 입력 중 다른 키 사용 불가, 이동 불가
	-- 바인드 키 설정 중 다른 키 사용 불가
	-- 고정키 : V, M, NUM1 ~ NUM0, 설정된 바인드 키
	
	if (CommandKeySHIFT and inputs[UI.KEY.C]) or vcommandInsert then
		if vcommandInsert == false then
			UI.StopPlayerControl(true)
			vcommand = ''
			vcommandInsert = true
			SetCommandInput('명령어를 입력해주세요.')
			
			return
		elseif inputs[UI.KEY.ENTER] then
			KZ.Event:OnCommand(string.lower(vcommand))
			
			vcommand = ''
			vcommandInsert = false
			SetCommandInput(vcommand)
			UI.StopPlayerControl(false)
		end
		
		vcommand = vcommand .. InputToChar(listFind(inputs))
		SetCommandInput(vcommand)
		
		return
	elseif Bind.PressKey:IsVisible() then
		KZ.Event:BindSet(Bind:KeyCheck(inputs))
	else
		Bind:OnInput(inputs)
		if inputs[UI.KEY.V] then 				defaultMenu:Toggle()
		elseif (inputs[UI.KEY.M] and Spec.value) then specMenu:Toggle()
		elseif inputs[UI.KEY.NUM0] then 		Menu:Toggle()
		elseif inputs[UI.KEY.NUM1] then	OnInputNumber = 1	Menu:Showing():Action(1)
		elseif inputs[UI.KEY.NUM2] then	OnInputNumber = 2	Menu:Showing():Action(2)
		elseif inputs[UI.KEY.NUM3] then	OnInputNumber = 3	Menu:Showing():Action(3)
		elseif inputs[UI.KEY.NUM4] then	OnInputNumber = 4	Menu:Showing():Action(4)
		elseif inputs[UI.KEY.NUM5] then OnInputNumber = 5	Menu:Showing():Action(5)
		elseif inputs[UI.KEY.NUM6] then	OnInputNumber = 6	Menu:Showing():Action(6)
		elseif inputs[UI.KEY.NUM7] then	OnInputNumber = 7	Menu:Showing():Action(7)
		elseif inputs[UI.KEY.NUM8] then	OnInputNumber = 8	Menu:Showing():Action(8)
		elseif inputs[UI.KEY.NUM9] then OnInputNumber = 9	Menu:Showing():Action(9)
		end
	end
	
	if inputs[UI.KEY.W] then
		UI.Signal(SIGNAL.ToGame.KEYDOWN_W)
		input_W:Set({a=255})
	end
	if inputs[UI.KEY.A] then
		UI.Signal(SIGNAL.ToGame.KEYDOWN_A)
		input_A:Set({a=255})
	end
	if inputs[UI.KEY.S] then
		UI.Signal(SIGNAL.ToGame.KEYDOWN_S)
		input_S:Set({a=255})
	end
	if inputs[UI.KEY.D] then
		UI.Signal(SIGNAL.ToGame.KEYDOWN_D)
		input_D:Set({a=255})
	end
	
	if MoveKeyViewer and inputs[UI.KEY.ENTER] then
		-- 키뷰어 이동 종료
		MoveKeyViewer = false
		UI.StopPlayerControl(false)
		PressArrowKeys:Hide()
	end
end

function UI.Event:OnKeyUp(inputs)
	if inputs[UI.KEY.W] then
		UI.Signal(SIGNAL.ToGame.KEYUP_W)
		input_W:Set({a=40})
	end
	if inputs[UI.KEY.A] then
		UI.Signal(SIGNAL.ToGame.KEYUP_A)
		input_A:Set({a=40})
	end
	if inputs[UI.KEY.S] then
		UI.Signal(SIGNAL.ToGame.KEYUP_S)
		input_S:Set({a=40})
	end
	if inputs[UI.KEY.D] then
		UI.Signal(SIGNAL.ToGame.KEYUP_D)
		input_D:Set({a=40})
	end
end

function UI.Event:OnChat(msg)
	KZ.Event:OnCommand(string.lower(msg))
end

function UI.Event:OnInput(inputs)
	if MoveKeyViewer then
		if inputs[UI.KEY.UP] then
			KZ.Event:MoveUpDownKeyViewer(-2)
		elseif inputs[UI.KEY.DOWN] then
			KZ.Event:MoveUpDownKeyViewer(2)
		elseif inputs[UI.KEY.LEFT] then
			KZ.Event:MoveSideKeyViewer(-2)
		elseif inputs[UI.KEY.RIGHT] then
			KZ.Event:MoveSideKeyViewer(2)
		end
	end
	
	if inputs[UI.KEY.A] and inputs[UI.KEY.D] then
		KZ.Event:SetKeyViewer(UI.Text.Set, {r=keyviewer_set.Color_bad.r, g=keyviewer_set.Color_bad.g, b=keyviewer_set.Color_bad.b})
	else
		KZ.Event:SetKeyViewer(UI.Text.Set, {r=keyviewer_set.Color.r, g=keyviewer_set.Color.g, b=keyviewer_set.Color.b})
	end
	
	if inputs[UI.KEY.SPACE] then
		KZ.Event:UseJetPack()
	end
	
	CommandKeySHIFT = inputs[UI.KEY.SHIFT]
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 랭킹 메뉴

rankFromData = SyncValueCreate('rankFromData')

function rankFromData:OnSync()
	for _, data in pairs(splitstr(self.value, ",")) do
		local info = splitstr(data, "|")
		local name = info[4]
		local time = tonumber(info[1])
		local cp = tonumber(info[2])
		local gc = tonumber(info[3])
		
		table.insert(Records, {Time=time, CP=cp, GC=gc, Name=name})
	end
	
	KZ.Event:RankingUpdate()
end

function KZ.Event:RankingUpdate()
	local temp = Records
	local drop_duplicates = {}
	local record = {}
	
	table.sort(temp, function (a, b) return a.Time > b.Time end) -- 중복 제거 전 내림차순 정렬
	
	for k, v in ipairs(temp) do
		drop_duplicates[v.Name] = {Time=v.Time, CP=v.CP, GC=v.GC, Name=v.Name} -- 중복 제거
	end
	
	for k, v in pairs(drop_duplicates) do
		table.insert(record, v) -- 키 제거(순차적으로 불러올 수가 없음)
	end
	
	table.sort(record, function (a, b) return a.Time < b.Time end) -- 중복 제거 후 오름차순 정렬
	
	local ranking = {}
	
	ranking.rank = {}
	ranking.record = {}
	ranking.player = {}
	
	for i, value in pairs(record) do
		local s = value.Time%10000/100
		local m = value.Time//10000
		ranking.rank[i] = string.format("[%d]", i)
		ranking.record[i] = string.format(dynamicPadding(m)..":%05.2f", s)
		ranking.player[i] = string.format("(%d/%d) %s", value.CP, value.GC, value.Name)
	end
	
	rankingMenu:PageSetup(ranking.rank, 1)
	rankingMenu:PageSetup(ranking.record, 2)
	rankingMenu:PageSetup(ranking.player, 3)
end

local ranking_set = HUD.Ranking

local rankingTitleSet = {text=ranking_set.Title.Text, font="small", align="left", x=30, y=center.y-80, width=screen.width, height=20,
	r=ranking_set.Title.Color.r, g=ranking_set.Title.Color.g, b=ranking_set.Title.Color.b, a=ranking_set.Title.Color.a}
local rankingElemSet_1 = {font="small",align="left", x=30, y=center.y-55, width=screen.width, height=20,
	r=ranking_set.Elem.Color_rank.r, g=ranking_set.Elem.Color_rank.g, b=ranking_set.Elem.Color_rank.b, a=ranking_set.Elem.Color_rank.a}
local rankingElemSet_2 = {font="small",align="left", x=60, y=center.y-55, width=screen.width, height=20,
	r=ranking_set.Elem.Color_record.r, g=ranking_set.Elem.Color_record.g, b=ranking_set.Elem.Color_record.b, a=ranking_set.Elem.Color_record.a}
local rankingElemSet_3 = {font="small",align="left", x=133, y=center.y-55, width=screen.width, height=20,
	r=ranking_set.Elem.Color_player.r, g=ranking_set.Elem.Color_player.g, b=ranking_set.Elem.Color_player.b, a=ranking_set.Elem.Color_player.a}

rankingMenu = Menu:new(rankingTitleSet, {rankingElemSet_1, rankingElemSet_2, rankingElemSet_3}, 10)
KZ.Event:RankingUpdate()

rankingMenu.elem[1][8]:Set({text=" 8."})	rankingMenu.elem[2][8]:Set({text="Bacｋ"})
rankingMenu.elem[1][9]:Set({text=" 9."})	rankingMenu.elem[2][9]:Set({text="More"})
rankingMenu.elem[1][10]:Set({text=" 0."})	rankingMenu.elem[2][10]:Set({text="Exit"})

rankingMenu:Visible(false)

function KZ.Event:All()
	rankingMenu:Toggle()
end

rankingMenu:ActionSetup(8, rankingMenu.PageDown)
rankingMenu:ActionSetup(9, rankingMenu.PageUp)

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 바인드 메뉴

Bind = {}

bindMenu = Menu:new(menuTitleSet, {menuNumberSet, menuElemSet}, 10)

bindMenu.title:Set({text=title_set.BindMenu})
bindMenu.elem[1][1]:Set({text="1. "})
bindMenu.elem[1][2]:Set({text="2. "})
bindMenu.elem[1][3]:Set({text="3. "})
bindMenu.elem[1][4]:Set({text="4. "})
bindMenu.elem[1][5]:Set({text="5. "})
bindMenu.elem[1][6]:Set({text="6. "})
bindMenu.elem[1][7]:Set({text="7. "})
bindMenu.elem[1][8]:Set({text="8. "})	bindMenu.elem[2][8]:Set({text="Bacｋ"})
bindMenu.elem[1][9]:Set({text="9. "})	bindMenu.elem[2][9]:Set({text="More"})
bindMenu.elem[1][10]:Set({text="0. "})	bindMenu.elem[2][10]:Set({text="Exit"})

bindMenu:PageSetup(HUD.Bind, 2)

Bind.Hotkey = {}

bindMenu:Visible(false)

Bind.PressKey = UI.Text.Create()
Bind.PressKey:Set({text=ReservedText.PressBindKey, font='medium', align="center", y=screen.height/4*3, width=screen.width, height=120, r=222,g=222,b=222,a=222})
Bind.PressKey:Hide()

CanNotBeHotKey = {
	-- 사용할 수 없는 키 리스트
	UI.KEY.W,
	UI.KEY.A,
	UI.KEY.S,
	UI.KEY.D,
	UI.KEY.V,
	UI.KEY.M,
	UI.KEY.NUM1,
	UI.KEY.NUM2,
	UI.KEY.NUM4,
	UI.KEY.NUM5,
	UI.KEY.NUM6,
	UI.KEY.NUM7,
	UI.KEY.NUM8,
	UI.KEY.NUM0,
	UI.KEY.ENTER,
	UI.KEY.SPACE,
}

Bind.Hotkey = {}

function KZ.Event:Bind()
	bindMenu:Toggle()
end

function KZ.Event:OnBind()
	Bind.index = OnInputNumber + (bindMenu.page*7)
	Bind.PressKey:Show()
	bindMenu:Toggle()
end

function KZ.Event:BindSet(key, command)
	if command then
		Bind.Hotkey[key] = command
		Bind.PressKey:Hide()
		FadeText.under:Fade(ReservedText.BindSuccess)
	end
end

function KZ.Event:UnBind()
	Bind.Hotkey = {}
end

function Bind:OnInput(inputs)
	for key, command in pairs(self.Hotkey) do
		if inputs[key] then
			KZ.Event:OnCommand(command)
			return
		end
	end
end

function Bind:KeyCheck(inputs)
	local key = listFind(inputs)
	
	for _, v in pairs(CanNotBeHotKey) do
		if key == v then
			return false
		end
	end
	
	return key, HUD.Bind[Bind.index]
end

for i = 1, math.min(#HUD.Bind, 7) do
	bindMenu:ActionSetup(i, KZ.Event.OnBind)
end

bindMenu:ActionSetup(8, bindMenu.PageDown)
bindMenu:ActionSetup(9, bindMenu.PageUp)

KZ.Bind = Bind

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 세이브 메뉴

saveMenu = Menu:new(menuTitleSet, {menuNumberSet, menuElemSet}, 4)

saveMenu.title:Set({text=title_set.SaveMenu})
saveMenu.elem[1][1]:Set({text="1. "})	saveMenu.elem[2][1]:Set({text="저장하기"})
saveMenu.elem[1][2]:Set({text="2. "})	saveMenu.elem[2][2]:Set({text="불러오기"})
saveMenu.elem[1][4]:Set({text="0. "})	saveMenu.elem[2][4]:Set({text="Exit"})

saveMenu:Visible(false)

loadData = SyncValueCreate('loadData')

function loadData:OnSync()
	if self.value == nil then
		return
	end
	
	local args = splitstr(self.value, ",")
	local index = tonumber(args[1])
	local Time = tonumber(args[2])
	
	if index == UI.PlayerIndex() then
		Timer:Reset()
		Timer.startTime = UI.GetTime() - Time/100
		Timer:Refresh()
		Timer:Pause_On()
	end
end

function KZ.Event:Save()
	if MAP.CanCP then
		saveMenu:Toggle()
	end
end

function KZ.Event:OnSave()
	if Timer.startTime == 0 then
		FadeText.under:Fade(ReservedText.DidNotStart)
	else
		local time = Timer:GetTime()
		UI.Signal(2000000000 + math.floor(time*100))
		if Timer.pause then
			Timer:Pause_Off(true) -- 퍼즈중에 세이브하면 퍼즈는 풀고 퍼즈포지션 텔포는 X
		end
	end
	
	defaultMenu:Toggle()
end

function KZ.Event:OnLoad()
	UI.Signal(SIGNAL.ToGame.LOAD)
	defaultMenu:Toggle()
end

saveMenu:ActionSetup(1, KZ.Event.OnSave)
saveMenu:ActionSetup(2, KZ.Event.OnLoad)

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 키뷰어 메뉴

overlayMenu = Menu:new(menuTitleSet, {menuNumberSet, menuElemSet}, 6)

overlayMenu.title:Set({text=title_set.OverlayMenu})
overlayMenu.elem[1][1]:Set({text="1. "})	overlayMenu.elem[2][1]:Set({text="보이기"})
overlayMenu.elem[1][2]:Set({text="2. "})	overlayMenu.elem[2][2]:Set({text="숨기기"})
overlayMenu.elem[1][3]:Set({text="3. "})	overlayMenu.elem[2][3]:Set({text="이동"})
overlayMenu.elem[1][4]:Set({text="4. "})	overlayMenu.elem[2][4]:Set({text="초기화"})
overlayMenu.elem[1][6]:Set({text="0. "})	overlayMenu.elem[2][6]:Set({text="Exit"})

overlayMenu:Visible(false)

PressArrowKeys = UI.Text.Create()
PressArrowKeys:Set({text=ReservedText.PressArrowKeys, font='medium', align="center", y=screen.height/4*3, width=screen.width, height=120, r=222,g=222,b=222,a=222})
PressArrowKeys:Hide()

function KZ.Event:KeyViewer()
	overlayMenu:Toggle()
end

function KZ.Event:SetKeyViewer(action, args)
	action(input_W, args)
	action(input_A, args)
	action(input_S, args)
	action(input_D, args)
end

function KZ.Event:HideKeyViewer()
	KZ.Event:SetKeyViewer(UI.Text.Hide)
	FadeText.under:Fade(ReservedText.HideKeyViewer)
	overlayMenu:Toggle()
end

function KZ.Event:ShowKeyViewer()
	KZ.Event:SetKeyViewer(UI.Text.Show)
	FadeText.under:Fade(ReservedText.ShowKeyViewer)
	overlayMenu:Toggle()
end

function KZ.Event:MoveKeyViewer()
	MoveKeyViewer = true
	UI.StopPlayerControl(true)
	PressArrowKeys:Show()
	overlayMenu:Toggle()
end

function KZ.Event:ResetKeyViewer()
	input_W:Set({x=keyviewer_x, y=keyviewer_y-40})
	input_A:Set({x=keyviewer_x-40, y=keyviewer_y})
	input_S:Set({x=keyviewer_x, y=keyviewer_y})
	input_D:Set({x=keyviewer_x+40, y=keyviewer_y})
	FadeText.under:Fade(ReservedText.ResetKeyViewer)
	overlayMenu:Toggle()
end

function KZ.Event:MoveSideKeyViewer(space)
	input_W:Set({x=input_W:Get().x+space})
	input_A:Set({x=input_A:Get().x+space})
	input_S:Set({x=input_S:Get().x+space})
	input_D:Set({x=input_D:Get().x+space})
end

function KZ.Event:MoveUpDownKeyViewer(space)
	input_W:Set({y=input_W:Get().y+space})
	input_A:Set({y=input_A:Get().y+space})
	input_S:Set({y=input_S:Get().y+space})
	input_D:Set({y=input_D:Get().y+space})
end

overlayMenu:ActionSetup(1, KZ.Event.ShowKeyViewer)
overlayMenu:ActionSetup(2, KZ.Event.HideKeyViewer)
overlayMenu:ActionSetup(3, KZ.Event.MoveKeyViewer)
overlayMenu:ActionSetup(4, KZ.Event.ResetKeyViewer)

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 스타트포지션 메뉴

startMenu = Menu:new(menuTitleSet, {menuNumberSet, menuElemSet}, 4)

startMenu.title:Set({text=title_set.StartPosMenu})
startMenu.elem[1][1]:Set({text="1. "})	startMenu.elem[2][1]:Set({text="설정된 위치"})
startMenu.elem[1][2]:Set({text="2. "})	startMenu.elem[2][2]:Set({text="버튼을 누른 위치"})
startMenu.elem[1][4]:Set({text="0. "})	startMenu.elem[2][4]:Set({text="Exit"})

startMenu:Visible(false)

function KZ.Event:SetStartPosition()
	startMenu:Toggle()
end

function KZ.Event:DefinedPosition()
	-- 설정된 좌표로 이동
	UndefinedPosition = false
	FadeText.under:Fade(ReservedText.SetStartPosition)
	startMenu:Toggle()
end

function KZ.Event:UndefinedPosition()
	-- 마지막에 버튼을 누른 좌표로 이동
	UndefinedPosition = true
	FadeText.under:Fade(ReservedText.SetStartPosition)
	startMenu:Toggle()
end

startMenu:ActionSetup(1, KZ.Event.DefinedPosition)
startMenu:ActionSetup(2, KZ.Event.UndefinedPosition)

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 세팅 메뉴

settingMenu = Menu:new(menuTitleSet, {menuNumberSet, menuElemSet}, 5)

settingMenu.title:Set({text=title_set.SettingMenu})
settingMenu.elem[1][1]:Set({text="1. "})	settingMenu.elem[2][1]:Set({text=title_set.BindMenu})
settingMenu.elem[1][2]:Set({text="2. "})	settingMenu.elem[2][2]:Set({text=title_set.OverlayMenu})
settingMenu.elem[1][3]:Set({text="3. "})	settingMenu.elem[2][3]:Set({text=title_set.StartPosMenu})
settingMenu.elem[1][5]:Set({text="0. "})	settingMenu.elem[2][5]:Set({text="Exit"})

settingMenu:Visible(false)

function KZ.Event:Setting()
	settingMenu:Toggle()
end

settingMenu:ActionSetup(1, KZ.Event.Bind)
settingMenu:ActionSetup(2, KZ.Event.KeyViewer)
settingMenu:ActionSetup(3, KZ.Event.SetStartPosition)

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 기본 메뉴

local menuCountSet = {font="small", align="left", y=center.y-87, width=screen.width, height=15}

defaultMenu = Menu:new(menuTitleSet, {menuNumberSet, menuElemSet, menuCountSet}, 12)

cpElem = defaultMenu.elem[3][1]
gcElem = defaultMenu.elem[3][2]
pauseElem = defaultMenu.elem[3][7]

local elem_set = HUD.Menu.Elem

cpElem:Set({x=154, r=elem_set.Color_count.r, g=elem_set.Color_count.g, b=elem_set.Color_count.b, a=elem_set.Color_count.a})
gcElem:Set({x=134, r=elem_set.Color_count.r, g=elem_set.Color_count.g, b=elem_set.Color_count.b, a=elem_set.Color_count.a})
pauseElem:Set({x=114, r=elem_set.Color_pause_off.r, g=elem_set.Color_pause_off.g, b=elem_set.Color_pause_off.b, a=elem_set.Color_pause_off.a})

function SetPauseColor(onoff)
	if onoff then
		pauseElem:Set({text="ON", r=elem_set.Color_pause_on.r, g=elem_set.Color_pause_on.g, b=elem_set.Color_pause_on.b, a=elem_set.Color_pause_on.a})
	else
		pauseElem:Set({text="OFF", r=elem_set.Color_pause_off.r, g=elem_set.Color_pause_off.g, b=elem_set.Color_pause_off.b, a=elem_set.Color_pause_off.a})
	end
end

defaultMenu.title:Set({text=title_set.MainMenu})
defaultMenu.elem[1][1]:Set({text="1. "})	defaultMenu.elem[2][1]:Set({text="Checkpoint - "})
defaultMenu.elem[1][2]:Set({text="2. "})	defaultMenu.elem[2][2]:Set({text="Gocheck - "})
defaultMenu.elem[1][3]:Set({text="3. "})	defaultMenu.elem[2][3]:Set({text="Stuck"})
defaultMenu.elem[1][5]:Set({text="4. "})	defaultMenu.elem[2][5]:Set({text="Start"})
defaultMenu.elem[1][6]:Set({text="5. "})	defaultMenu.elem[2][6]:Set({text="All Top"})
defaultMenu.elem[1][7]:Set({text="6. "})	defaultMenu.elem[2][7]:Set({text="Pause -"})
defaultMenu.elem[1][9]:Set({text="7. "})	defaultMenu.elem[2][9]:Set({text="Setting"})
defaultMenu.elem[1][10]:Set({text="8. "})	defaultMenu.elem[2][10]:Set({text="Save Position"})
defaultMenu.elem[1][11]:Set({text="9. "})	defaultMenu.elem[2][11]:Set({text="Teleport"})
defaultMenu.elem[1][12]:Set({text="0. "})	defaultMenu.elem[2][12]:Set({text="Exit"})

if not MAP.CanCP then
	for i = 1, 3 do
		defaultMenu.elem[i][1]:Set({a=100})
		defaultMenu.elem[i][2]:Set({a=100})
		defaultMenu.elem[i][3]:Set({a=100})
		defaultMenu.elem[i][9]:Set({a=100})
	end
end

defaultMenu:ActionSetup(1, KZ.Event.CP)
defaultMenu:ActionSetup(2, KZ.Event.GC)
defaultMenu:ActionSetup(3, KZ.Event.BackCP)
defaultMenu:ActionSetup(4, KZ.Event.Start)
defaultMenu:ActionSetup(5, KZ.Event.All)
defaultMenu:ActionSetup(6, KZ.Event.Pause)
defaultMenu:ActionSetup(7, KZ.Event.Setting)
defaultMenu:ActionSetup(8, KZ.Event.Save)
defaultMenu:ActionSetup(9, KZ.Event.TP)

function KZ.Event:Menu()
	defaultMenu:Toggle()
end

SetPauseColor(false)
defaultMenu:Visible(true)

Timer:Init()