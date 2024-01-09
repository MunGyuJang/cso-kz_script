-- game.lua

Game.Rule.respawnable = false
Game.Rule.enemyfire = false
Game.Rule.friendlyfire = false
Game.Rule.breakable = false

local KZ = {}
local SyncValueCreate = SyncValueSet(Game)
--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- player

KZ.Player = {}

for i = 1, VALUE.MaxPlayer do
	KZ.Player[i] = nil
end

function Game.Player:OnTruePosition()
	-- 위치 유효성 검사
	
	if MAP.Mode == 'mpbhop' then
		if not Addons.CanCPBug and self.user.onbhop then
			-- CP버그 체크
			self:Signal(SIGNAL.ToUI.INVAILD_POSITION)
			return false
		end
	end
	
	local monster = Game.Monster:Create(Game.MONSTERTYPE.NORMAL0, {x=191, y=191, z=94})
	monster.position = self.position
	
	if monster.position.x == self.position.x and
		monster.position.y == self.position.y and
		monster.position.z == self.position.z+1 then
		
		monster.position = MAP.MonsterKillBlock or {x=191, y=191, z=94}
		if not MAP.MonsterKillBlock then
			Game.KillAllMonsters()
		end
		
		return true
	else
		self:Signal(SIGNAL.ToUI.INVAILD_POSITION)
		if not MAP.MonsterKillBlock then
			Game.KillAllMonsters()
		end
		
		return false
	end
end

function Game.Player:GetSpeed()
	return math.sqrt(self.velocity.x^2 + self.velocity.y^2)
end

function Game.Player:OnGround()
	return self.velocity.z == 0
end

function Game.Player:Bhop()
	-- 플레이 모드용 착지 감지
	if self.user.vector + 300 < self.velocity.z then
		self.user.vector = self.velocity.z
		return true
	else
		self.user.vector = self.velocity.z
	end
end

function Game.Player:Teleport(position)
	self.position = position
	self.velocity = {x=0, y=0, z=-10}
end

function Game.Player:SetCPs()
	-- 타이머 시작, 세션 퇴장, 세션 입장, 제트팩 활성화 리셋
	self.user.cp = {}
	self.user.gc = {}
	self.user.vcp = nil -- 퍼즈용 가상 체크포인트
	checkPoint[self.index].value = #self.user.cp
	goCheck[self.index].value = #self.user.gc
	self.user.pp = nil -- pause position
	self.user.pause = false
	Pause[self.index].value = false
end

function Game.Player:Init()
	specPlayer[self.index].value = self.name
	self.health = VALUE.PlayerHealth
	self.user.state = true -- 플레이 가능
	self.user.vector = 0 -- 플레이 모드용 버니합 감지 변수
	self.user.pause = false -- 퍼즈 중 가상 체크포인트 확인용 변수
	self.user.stuck = 1 -- Back CP 변수
	self.user.pre = 0 -- pre
	self.user.max = 0 -- max
	self.user.onair = true -- 공중에 있는지
	self.user.holding = 0 -- 공중에 얼마나 있었는지
	self.user.landing = false -- 착지를 했는지(버니블록 전용)
	
	-- mpbhop
	if MAP.Mode == 'mpbhop' then
		self:ResetLevel()
	end
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- rtv

RTV = SyncValueCreate('RTV')

KZ.PlayerVote = 0

function NumPlayer()
	local num = 0
	
	for i, p in pairs(KZ.Player) do
		if (p ~= nil and p.user.state == true) then
			-- 플레이 가능한 플레이어
			num = num + 1
		end
	end
	
	if num >= 8 then
		return 5
	elseif num >= 6 then
		return 4
	elseif num >= 4 then
		return 3
	elseif num >= 2 then
		return 2
	else
		return 1
	end
end

function rockthevote()
	-- 8명 이상 : 5
	-- 6명 이상 : 4
	-- 4명 이상 : 3
	-- 2명 이상 : 2
	local needPlayers = NumPlayer()
	
	if KZ.PlayerVote >= needPlayers then
		Game.Rule:Win(Game.TEAM.SPECTATOR, true)
	else
		RTV.value = needPlayers - KZ.PlayerVote
	end
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 타이머

local StartButton = Game.EntityBlock.Create(MAP.StartButton)
local FinishButton = Game.EntityBlock.Create(MAP.FinishButton)

if not DebugMode or StartButton then
	function StartButton:OnUse(player)
		if not player.user.pause then
			-- 퍼즈 중 타이머 시작 불가
			player:Signal(SIGNAL.ToUI.TIMER_START)
			player.user.jetpack = false
			player.user.startposition = player.position -- 스타트 포지션 저장
			player:SetCPs()
		end
	end
end

if not DebugMode or FinishButton then
	function FinishButton:OnUse(player)
		player:Signal(SIGNAL.ToUI.FINISH)
	end
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 체크포인트

checkPoint = SyncValueCreate('checkPoint', VALUE.MaxPlayer)
goCheck = SyncValueCreate('goCheck', VALUE.MaxPlayer)

function Game.Player:CheckPoint()
	if self:OnGround() then
		if self:OnTruePosition() then
			if self.user.pause then
				-- 퍼즈 중이면 가상 체크포인트
				self.user.vcp = self.position
			else
				self.user.cp[#self.user.cp + 1] = self.position
				checkPoint[self.index].value = #self.user.cp
			end
			
			self.user.stuck = 1
		end
	else
		self:Signal(SIGNAL.ToUI.DONTCP)
	end
end

function Game.Player:GoCheck(stuck)
	stuck = stuck or 0
	
	if self.user.cp[#self.user.cp - stuck] or self.user.vcp then
		if self.user.pause then
			-- 퍼즈중일 경우 가상 체크포인트가 없으면 체크포인트를 따라감, 있으면 가상 체크포인트
			-- Back CP일 경우 vcp보다 cp를 우선
			self:Teleport(stuck > 0 and self.user.cp[#self.user.cp - stuck] or self.user.vcp or self.user.cp[#self.user.cp - stuck])
		else
			self.user.gc[#self.user.gc + 1] = self.position
			goCheck[self.index].value = #self.user.gc
			
			self:Teleport(self.user.cp[#self.user.cp - stuck])
		end
		
		self.user.stuck = stuck + 1
	else
		self:Signal(SIGNAL.ToUI.DONTGC)
	end
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 클리어

sessionRank = SyncValueCreate('sessionRank', 3)
clear = SyncValueCreate('clear')
Log = SyncValueCreate('Log')

KZ.Log = {}

function Game.Player:Log()
	local session_log = {self.index}
	
	table.sort(KZ.Log, function (a, b) return a.time < b.time end)
	table.insert(session_log, "+--------------------------+")
	table.insert(session_log, "---------SESSION LOG---------")
	for i = 1, #KZ.Log do
		table.insert(session_log, string.format(KZ.Log[i].name.." #%d", i))
		table.insert(session_log, KZ.Log[i].msg2)
		table.insert(session_log, string.format("%d:%02d:%05.2f", KZ.Log[i].time//3600, KZ.Log[i].time//60%60, KZ.Log[i].time%60))
		table.insert(session_log, "----------------------------")
	end
	table.insert(session_log, "+--------------------------+")
	
	Log.value = table.concat(session_log, "|")
end

function rankUpdate()
	local temp = KZ.Log
	local drop_duplicates = {}
	local records = {}
	
	table.sort(temp, function (a, b) return a.record > b.record end) -- 중복 제거 전 내림차순 정렬
	
	for k, v in ipairs(temp) do
		drop_duplicates[v.name] = {msg = v.msg1, record = v.record} -- 중복 제거
	end
	
	for k, v in pairs(drop_duplicates) do
		table.insert(records, v) -- 키 제거(순차적으로 불러올 수가 없음)
	end
	
	table.sort(records, function (a, b) return a.record < b.record end) -- 중복 제거 후 오름차순 정렬
	
	for i = 1, math.min(3, #records) do
		sessionRank[i].value = records[i].msg
	end
end

function Game.Player:Clear(time)
	-- time : 100 곱해진 .00 까지의 시간
	
	-- 콘솔	player.name 맵 클리어
	--		00:00.00 ( CPs: 0 | GCs: 0 ) !
	
	-- 공지	player.name 맵 클리어 00:00.00 ( CPs: 0 | GCs: 0 ) !
	
	-- 로그	msg1 : 00:00.00 (0/0) player.name	세션 랭킹용 문구
	--		msg2 : 00:00.00 ( CPs: 0 | GCs: 0 ) ! -- 콘솔 확인용 문구

	local realTime = time / 100
	local Time = string.format("%02d:%05.2f", realTime//60, realTime%60)
	local str_name = self.name.." 맵 클리어"
	local str_time = string.format(Time.." ( CPs: %d ｜GCs: %d ) !", #self.user.cp, #self.user.gc)
	
	print("==============================")
	print(str_name.."...")
	print(str_time)
	clear.value = str_name.." "..str_time
	
	local value = {name = self.name, 
					record = realTime, 
					msg1 = string.format(Time.." (%d/%d) "..self.name, #self.user.cp, #self.user.gc),
					msg2 = str_time, 
					time = Game.GetTime()
				}
	table.insert(KZ.Log, value)

	rankUpdate()
	self.user.clear = true
	
	if Game.Rule:CanSave() then
		saveRecord(self, time)
	end
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 속도계

groundSpeed = SyncValueCreate('groundSpeed', VALUE.MaxPlayer)
preStrafe = SyncValueCreate('preStrafe', VALUE.MaxPlayer)
maxSpeed = SyncValueCreate('maxSpeed', VALUE.MaxPlayer)

function Game.Player:SpeedMeter()
	local speed = self:GetSpeed()
	
	if self:OnGround() or self:Bhop() then
		-- 땅에 있는 상황
		if self.user.onair then
			-- 공중에 있었음(Once 실행을 위한 변수)
			if self.user.holding >= 56 then
				-- 정상적인 착지
				maxSpeed[self.index].value = self.user.max
			end
			self.user.onair = false
		end
		
		self.user.pre = speed
		self.user.holding = 0
		
	elseif not self.user.onair and self.user.holding == 0 then
		-- 공중에 뜬 상황
		if self.user.pre >= 60 then
			-- 프리가 60 이상일 경우
			if self.velocity.z > 200 then
				-- 점프
				preStrafe[self.index].value = self.user.pre + 10000
			else
				-- 덕팅
				preStrafe[self.index].value = self.user.pre
			end
		end
		
		self.user.holding = 1
		self.user.onair = true
		
	elseif self.user.holding > 0 then
		-- 공중에 있는 상황
		self.user.holding = self.user.holding + 1
		self.user.max = speed
		
		if self.user.holding >= 72 then
			-- 일반적인 착지 시간
			maxSpeed[self.index].value = self.user.max
			self.user.holding = -1
		end
	end
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 세이브

loadData = SyncValueCreate('loadData')
rankFromData = SyncValueCreate('rankFromData')

KZ.PlayerSave = {}

function stringToPosition(string)
	local result = {}
	local table = splitstr(string, "|")
	
	for i = 1, #table do
		local pos = splitstr(table[i], ",")
		result[i] = {x=tonumber(pos[1]), y=tonumber(pos[2]), z=tonumber(pos[3])}
	end
	
	return result
end

function positionToString(pos)
	local result = {}
	
	for i = 1, #pos do
		result[i] = string.format("%d,%d,%d", pos[i].x, pos[i].y, pos[i].z)
	end
		
	return table.concat(result, "|")
end

function Game.Player:Load()
	-- 그룹 데이터 체크
	local GroupData = Game.Rule:CanSave() and self:GetGameSave(MAP.Title.."save")
	
	if not KZ.PlayerSave[self.name] and not GroupData then
		self:Signal(SIGNAL.ToUI.NOSAVE)
		return
	end
	
	local cp
	local gc
	local time

	if GroupData then
		-- 그룹 데이터 우선
		local data = splitstr(GroupData, "~")
		
		cp = stringToPosition(data[1])
		gc = stringToPosition(data[2])
		time = tonumber(data[3])
		
		-- 정보 삭제
		self:SetGameSave(MAP.Title.."save", false)
	elseif KZ.PlayerSave[self.name] then
		cp = KZ.PlayerSave[self.name].cp
		gc = KZ.PlayerSave[self.name].gc
		time = KZ.PlayerSave[self.name].time
		
		-- 정보 삭제
		KZ.PlayerSave[self.name] = false
	end
		
	self.user.cp = cp
	self.user.gc = gc
		
	checkPoint[self.index].value = #self.user.cp
	goCheck[self.index].value = #self.user.gc
		
	self:Teleport(self.user.cp[#self.user.cp])
		
	loadData.value = string.format("%d,%d", self.index, time)
	self:SharingTime(time//100)
	
	-- 퍼즈 On
	self.user.pause = true
	self.user.pp = self.user.cp[#self.user.cp]
	Pause[self.index].value = true
end

function Game.Player:Save(time)
	if self:OnTruePosition() then
		self.user.cp[#self.user.cp + 1] = self.user.pp or self.position -- 퍼즈 포지션이 있다면(퍼즈 도중 세이브를 함) 퍼즈 포지션을, 아니면 현재 위치를
		self.user.gc[#self.user.gc + 1] = self.position
		
		if Game.Rule:CanSave() then
			-- 저장 그룹이 활성화 되어있다면 그룹에 저장
			local strCP = positionToString(self.user.cp)
			local strGC = positionToString(self.user.gc)
			local strTime = tostring(time)
			local data = string.format("%s~%s~%s", strCP, strGC, strTime)
			
			self:SetGameSave(MAP.Title.."save", data)
		else
			-- 아니면 세션에 저장
			local value = {
				cp = self.user.cp, 
				gc = self.user.gc, 
				time = time
			}
			
			KZ.PlayerSave[self.name] = value
		end
		
		self:Signal(SIGNAL.ToUI.SAVED)
	end
end

if Game.Rule:CanSave() then
	-- 랭킹 자동 저장
	
	function saveRecord(player, record)
		local playerBestLAP = player:GetGameSave(MAP.Title) -- 데이터 이름은 맵 이름으로
		
		if (not playerBestLAP or playerBestLAP > record) then
			-- 기존 데이터가 없거나 이전보다 빠른 기록이면 갱신
			player:SetGameSave(MAP.Title, record)
			
			local playerRecord = string.format("%d|%d|%d|%s", record, #player.user.cp, #player.user.gc, player.name)
			local originalData = Game.Rule:GetGameSave(MAP.Title)
			
			originalData = originalData or '' -- 기존 데이터에 덮어쓰기
			
			Game.Rule:SetGameSave(MAP.Title, originalData..","..playerRecord)
		end
	end

	function fineGroupData()
		-- 중복 제거와 순위 계산은 UI에서
		local data = Game.Rule:GetGameSave(MAP.Title)
		
		if data == nil then
			return
		end
		
		rankFromData.value = data
		
		print("불러오기 완료")
	end
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- 관전

specPlayer = SyncValueCreate('specPlayer', VALUE.MaxPlayer)
sharingTime = SyncValueCreate('sharingTime', VALUE.MaxPlayer)

input_W = SyncValueCreate('input_W', VALUE.MaxPlayer)
input_A = SyncValueCreate('input_A', VALUE.MaxPlayer)
input_S = SyncValueCreate('input_S', VALUE.MaxPlayer)
input_D = SyncValueCreate('input_D', VALUE.MaxPlayer)

Pause = SyncValueCreate('Pause', VALUE.MaxPlayer)

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- mpbhop

if MAP.Mode == 'mpbhop' then
	
	KZ.BhopOff = 35
	
	if not Addons.CanAfter then
		KZ.BhopOff = 20
	end
	
	local TpZone = {}
	local Blocks = {}
	
	function Blocks:Set(level, blocks, backPoint)
		for i, block in ipairs(blocks) do
			self:Check(block, backPoint, level, i)
		end
	end
	
	function Blocks:Check(block, backPoint, level, i)
		if block.x then
			return self:Create(block, backPoint, level, i)
		else
			for j = 1, #block do
				self:Check(block[j], backPoint, level, i)
			end
		end
	end
	
	function Blocks:Create(position, backPoint, level, i)
		position = {x=position.x, y=position.y, z=position.z}
	
		local block = Game.EntityBlock.Create(position)
		assert(block, string.format("오류: %i-%i 영역 블록 없음", level, i))
		
		function block:OnTouch(player)
			local count = BackAndPoint[level].Block[i].count or 1
			player:OnBhopBlock(level, backPoint, i, count)
		end
	end
	
	function sortMinMax(pos)
		local result = {}
	
		result.x1 = math.min(pos.x1, pos.x2)
		result.x2 = math.max(pos.x1, pos.x2)
		result.y1 = math.min(pos.y1, pos.y2)
		result.y2 = math.max(pos.y1, pos.y2)
		result.z1 = math.min(pos.z1, pos.z2)
		result.z2 = math.max(pos.z1, pos.z2)

		return result
	end
	
	for level, v in pairs(BackAndPoint) do
		if v.Block then
			Blocks:Set(level, v.Block, v.BackPoint)
		end
		if v.TpZone then
			TpZone[level] = {
				pos = sortMinMax(v.TpZone),
				BackPoint = v.BackPoint,
			}
		end
	end
	
	function Game.Player:OnBhopBlock(level, position, block, count)
		-- level : 구간 번호
		-- position : 이동될 좌표
		-- block : 블록 번호
		-- count : 점프 가능 횟수
		
		if self.user.jetpack and not Addons.JetPackTeleport then
			-- 제트팩 사용 중 & 제트팩 사용 중 리스폰 미적용 설정 시 함수 종료
			return
		end
		
		if self:OnGround() then
			if self.user.block == block and self.user.level == level or
				-- 같은 블록을 두 번 밟음
				not Addons.CanBhopBack and self.user.block >= block and self.user.level == level then
				-- 이전 버니블록을 밟음
				
				if count > 1 and self:OnLanding() then
					if count <= self.user.count then
						self:Teleport(position)
						self:ResetLevel()
						return
					else
						self.user.landing = true
						self.user.count = self.user.count + 1
						self.user.lapse = 1
					end
				end
				
				if self:OnOverLapse() then
					self:Teleport(position)
					self:ResetLevel()
				end
			else
				-- 새로운 블록을 밟음
				self:SetLevel(level, block)
			end
			
			self.user.onbhop = true
		else
			self.user.landing = false
		end
	end
	
	function Game.Player:OnLanding()
		-- 착지 전 self.user.landing : false
		-- 착지 후 self.user.landing = true
		-- 점프 시 self.user.landing = false
		return not self.user.landing
	end
	
	function Game.Player:OnOverLapse()
		return self.user.lapse >= KZ.BhopOff and self.user.lapse <= 76 -- 92 정도로 해놓으면 애프터 버그 사용 불가
	end
	
	function Game.Player:OnTpZone(pos)
		return
			self.position.x >= pos.x1 and self.position.x <= pos.x2 and
			self.position.y >= pos.y1 and self.position.y <= pos.y2 and
			self.position.z >= pos.z1 and self.position.z <= pos.z2
	end
	
	function Game.Player:SetLevel(level, block)
		-- 새로운 블록을 밟음
		self.user.level = level
		self.user.block = block
		self.user.lapse = 1
		self.user.count = 1
		self.user.landing = true
	end
	
	function Game.Player:ResetLevel()
		-- 리스폰 or 최근에 블록을 밟지 않음
		self.user.level = 1
		self.user.block = 0
		self.user.lapse = 0
		self.user.count = 0
		self.user.landing = false
	end
	
	function Game.Player:StatusCheck()
		-- TPZone, 버니블록 오버랜딩 체크
		if self.user.jetpack and not Addons.JetPackTeleport then
			-- 제트팩 사용 중 & 제트팩 사용 중 리스폰 미적용 설정 시 함수 종료
			return
		end
		
		if self.user.lapse ~= 0 then
			-- 버니 블록에 닿았음
			if self.user.lapse > 96 then
				-- 버니 블록에 닿은지 96프레임이 지나면 리셋
				self:ResetLevel()
			else
				self.user.lapse = self.user.lapse + 1
			end
		end
		
		for k, v in pairs(TpZone) do
			if self:OnTpZone(v.pos) then
				self:Teleport(v.BackPoint)
			end
		end
	end
end

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- Event

KZ.Event = {}

function KZ.Event:Create(method)
	-- OnPlayerSignal 조건문을 줄이기 위한 Game.Player 메서드 생성
	local player = getmetatable(Game.Player)
	player.event = method
	
	return player.event
end

function Game.Player:JetPack()
	self.velocity = {z=VALUE.JetPack}
end

function Game.Player:OnSignalTime()
	-- 클라이언트 프레임 단위로 실행되는 함수
	self:SpeedMeter()
	if MAP.Mode == 'mpbhop' then
		self:StatusCheck()
	end
end

shakePlayer = {
	[1] = {x=100},
	[2] = {y=100},
	[3] = {x=-100},
	[4] = {y=-100},
}

local frame = 1

function Game.Player:OnGameTime()
	-- 서버 프레임 단위로 실행되는 함수
	self.user.onbhop = false
	groundSpeed[self.index].value = self:GetSpeed()
	
	if MAP.BlockPixelWalk and self.velocity.z == -4 then
		-- 벽낑 방지
		self.velocity = shakePlayer[frame]
		frame = frame + 1
		if frame > 4 then
			frame = 1
		end
	end
end

function Game.Player:AutoBhop()
	local speed = self:GetSpeed()
	if self:OnGround() and speed <= VALUE.AutoBhopSpeed then
		self.velocity = {z=260}
	end
end

function Game.Player:NC_ON()
	self.user.jetpack = true
end

function Game.Player:NC_OFF()
	self.user.jetpack = false
end

function Game.Player:Pause_ON()
	if self:OnGround() then
		if self:OnTruePosition() then
			self:Signal(SIGNAL.ToUI.PAUSE)
			self.user.pause = true
			self.user.pp = self.position
			
			Pause[self.index].value = true
		end
	else
		self:Signal(SIGNAL.ToUI.DONTPS)
	end
end

function Game.Player:Pause_OFF()
	self:Teleport(self.user.pp)
	self.user.pause = false
	self.user.vcp = nil
	self.user.pp = nil
	
	Pause[self.index].value = false
end

function Game.Player:RTV()
	if not self.user.rtv then
		KZ.PlayerVote = KZ.PlayerVote + 1
		self.user.rtv = true
	end
	
	rockthevote()
end

function Game.Player:TimerReset()
	-- 제트팩 활성화, 퍼즈 중 타이머 세이브
	self:Signal(SIGNAL.ToUI.TIMER_END)
	sharingTime[self.index].value = false
	self:SetCPs()
end

function Game.Player:BackCP()
	if self.user.stuck >= #self.user.cp then
		self.user.stuck = 0
	end
	
	self:GoCheck(self.user.stuck)
end

function Game.Player:Start()
	self:Teleport(MAP.StartPosition)
end

function Game.Player:FreeStart()
	self:Teleport(self.user.startposition or MAP.StartPosition)
end

function Game.Player:Spec()
	self.armor = 0
	if not DebugMode then
		self:Kill()
		specPlayer[self.index].value = ''
	end
	self.user.state = false
	self:Signal(SIGNAL.ToUI.TIMER_END)
end

function Game.Player:SharingTime(time)
	-- Time : 초 단위
	sharingTime[self.index].value = string.format("%02d:%02d", time//60, time%60)
end

function Game.Player:KeyDown_W()
	input_W[self.index].value = true
end

function Game.Player:KeyDown_A()
	input_A[self.index].value = true
end

function Game.Player:KeyDown_S()
	input_S[self.index].value = true
end

function Game.Player:KeyDown_D()
	input_D[self.index].value = true
end

function Game.Player:KeyUp_W()
	input_W[self.index].value = false
end

function Game.Player:KeyUp_A()
	input_A[self.index].value = false
end

function Game.Player:KeyUp_S()
	input_S[self.index].value = false
end

function Game.Player:KeyUp_D()
	input_D[self.index].value = false
end

function Game.Player:TeleportToPlayer(index)
	self.position = KZ.Player[index].position
end

KZ.Event[SIGNAL.ToGame.JETPACK] = KZ.Event:Create(Game.Player.JetPack)
KZ.Event[SIGNAL.ToGame.ONTIME] = KZ.Event:Create(Game.Player.OnSignalTime)
KZ.Event[SIGNAL.ToGame.AUTOBHOP] = KZ.Event:Create(Game.Player.AutoBhop)
KZ.Event[SIGNAL.ToGame.NC_ON] = KZ.Event:Create(Game.Player.NC_ON)
KZ.Event[SIGNAL.ToGame.NC_OFF] = KZ.Event:Create(Game.Player.NC_OFF)
KZ.Event[SIGNAL.ToGame.PAUSE_ON] = KZ.Event:Create(Game.Player.Pause_ON)
KZ.Event[SIGNAL.ToGame.PAUSE_OFF] = KZ.Event:Create(Game.Player.Pause_OFF)
KZ.Event[SIGNAL.ToGame.RESET] = KZ.Event:Create(Game.Player.TimerReset)
KZ.Event[SIGNAL.ToGame.RTV] = KZ.Event:Create(Game.Player.RTV)
KZ.Event[SIGNAL.ToGame.CP] = KZ.Event:Create(Game.Player.CheckPoint)
KZ.Event[SIGNAL.ToGame.GC] = KZ.Event:Create(Game.Player.GoCheck)
KZ.Event[SIGNAL.ToGame.BACKCP] = KZ.Event:Create(Game.Player.BackCP)
KZ.Event[SIGNAL.ToGame.START] = KZ.Event:Create(Game.Player.Start)
KZ.Event[SIGNAL.ToGame.FREESTART] = KZ.Event:Create(Game.Player.FreeStart)
KZ.Event[SIGNAL.ToGame.LOG] = KZ.Event:Create(Game.Player.Log)
KZ.Event[SIGNAL.ToGame.LOAD] = KZ.Event:Create(Game.Player.Load)
KZ.Event[SIGNAL.ToGame.SPEC] = KZ.Event:Create(Game.Player.Spec)
KZ.Event[SIGNAL.ToGame.KEYDOWN_W] = KZ.Event:Create(Game.Player.KeyDown_W)
KZ.Event[SIGNAL.ToGame.KEYDOWN_A] = KZ.Event:Create(Game.Player.KeyDown_A)
KZ.Event[SIGNAL.ToGame.KEYDOWN_S] = KZ.Event:Create(Game.Player.KeyDown_S)
KZ.Event[SIGNAL.ToGame.KEYDOWN_D] = KZ.Event:Create(Game.Player.KeyDown_D)
KZ.Event[SIGNAL.ToGame.KEYUP_W] = KZ.Event:Create(Game.Player.KeyUp_W)
KZ.Event[SIGNAL.ToGame.KEYUP_A] = KZ.Event:Create(Game.Player.KeyUp_A)
KZ.Event[SIGNAL.ToGame.KEYUP_S] = KZ.Event:Create(Game.Player.KeyUp_S)
KZ.Event[SIGNAL.ToGame.KEYUP_D] = KZ.Event:Create(Game.Player.KeyUp_D)

--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- Game.Rule

function Game.Rule:OnPlayerJoiningSpawn(player)
	KZ.Player[player.index] = player
	player.user.clear = false
	player.user.jetpack = false
	player.user.rtv = false
	
	player:SetCPs()
	if KZ.PlayerSave[player.name] then
		player:Signal(SIGNAL.ToUI.LOAD)
	end
	
	rankUpdate()
end

function Game.Rule:OnPlayerDisconnect(player)
	KZ.Player[player.index] = nil
	specPlayer[player.index].value = ''
	player:Signal(SIGNAL.ToUI.TIMER_END)
	
	if player.user.rtv then
		KZ.PlayerVote = KZ.PlayerVote - 1
	end
	
	loadData.value = nil
end

function Game.Rule:OnPlayerSpawn(player)
	player:Init()
end

function Game.Rule:OnPlayerAttack(victim, attacker, damage, weapontype, hitbox)
	if MAP.FallDamage == false then
		return 0
	else
		if (attacker ~= nil and victim ~= attacker) then
			-- 플레이어의 공격에는 대미지를 입지 않음
			return 0
		end
	end
end

function Game.Rule:OnPlayerKilled(victim, killer, weapontype, hitbox)
	victim:Respawn()
end

function Game.Rule:OnRoundStart()
	if Game.Rule:CanSave() then
		fineGroupData()
	end
end

function Game.Rule:OnLoadGameSave(player)
	if player:GetGameSave(MAP.Title.."save") then
		player:Signal(SIGNAL.ToUI.LOAD)
	end
	
	player.health = VALUE.PlayerHealth
end

function Game.Rule:OnUpdate(time)
	for i, p in pairs(KZ.Player) do
		if p ~= nil then
			p:OnGameTime()
		end
	end
end

function Game.Rule:OnPlayerSignal(player, signal)
	if signal < 0 then
		KZ.Event[signal](player)
	elseif signal >= 2000000000 then -- Save
		player:Save(signal - 2000000000)
	elseif signal >= 1000000000 then -- SharingTime
		player:SharingTime((signal - 1000000000)//100)
	elseif signal >= 900000000 then -- Teleport
		player:TeleportToPlayer(signal - 900000000)
	elseif signal > 0 then -- Clear
		player:Clear(signal)
	end
end