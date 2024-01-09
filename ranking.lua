-- ranking.lua

--[[
	기록 작성 예시 ex) 00:50.45 (7/15) 익스트림버니합 : {Time = 005045, CP = 7, GC = 15, Name = "익스트림버니합"}
	
	Records = {
		{Time = 005045, CP = 7, GC = 15, Name = "익스트림버니합"},
		{Time = 912345, CP = 0, GC = 0, Name = "Unknown1"},
		{Time = 1890001, CP = 0, GC = 0, Name = "Unknown2"},
		{Time = 789123, CP = 0, GC = 0, Name = "Unknown3"},
		{Time = 678912, CP = 0, GC = 0, Name = "Unknown4"},
		{Time = 567891, CP = 0, GC = 0, Name = "Unknown5"},
		{Time = 456789, CP = 0, GC = 0, Name = "익스트림버니합"},
		{Time = 345678, CP = 0, GC = 0, Name = "Unknown6"},
		{Time = 234567, CP = 0, GC = 0, Name = "익스트림버니합"},
		{Time = 123456, CP = 0, GC = 0, Name = "Unknown8"},
		{Time = 455123, CP = 0, GC = 0, Name = "익스트림버니합"},
	}
	
	Records 테이블 내의 순서는 상관 없으며, 기록만으로 루아에서 직접 정렬함
	중복된 닉네임이 있을 경우 가장 빠른 기록만 랭킹에 반영
]]--

Records = {
	
}