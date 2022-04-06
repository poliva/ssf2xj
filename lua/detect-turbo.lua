print("Quick & dirty Turbo/Autofire detector for fightcade replays")
print("by @pof - April 2022")

local turbo_treshold = 10
local table={}
local prev_table={}
local frames = emu.framecount()
local P1={LP=0,MP=0,HP=0,LK=0,MK=0,HK=0}
local P2={LP=0,MP=0,HP=0,LK=0,MK=0,HK=0}
while true do
	local fc = emu.framecount()
	if (fc-frames >= 60) then
		if (P1.HP > turbo_treshold) then print("TURBO detected on P1.HP="..P1.HP) end
		if (P1.MP > turbo_treshold) then print("TURBO detected on P1.MP="..P1.MP) end
		if (P1.LP > turbo_treshold) then print("TURBO detected on P1.LP="..P1.LP) end
		if (P1.HK > turbo_treshold) then print("TURBO detected on P1.HK="..P1.HK) end
		if (P1.MK > turbo_treshold) then print("TURBO detected on P1.MK="..P1.MK) end
		if (P1.LK > turbo_treshold) then print("TURBO detected on P1.LK="..P1.LK) end
		if (P2.HP > turbo_treshold) then print("TURBO detected on P2.HP="..P2.HP) end
		if (P2.MP > turbo_treshold) then print("TURBO detected on P2.MP="..P2.MP) end
		if (P2.LP > turbo_treshold) then print("TURBO detected on P2.LP="..P2.LP) end
		if (P2.HK > turbo_treshold) then print("TURBO detected on P2.HK="..P2.HK) end
		if (P2.MK > turbo_treshold) then print("TURBO detected on P2.MK="..P2.MK) end
		if (P2.LK > turbo_treshold) then print("TURBO detected on P2.LK="..P2.LK) end

		P1.HP=0
		P1.MP=0
		P1.LP=0
		P1.HK=0
		P1.MK=0
		P1.LK=0
		P2.HP=0
		P2.MP=0
		P2.LP=0
		P2.HK=0
		P2.MK=0
		P2.LK=0

		frames=fc

	end
	prev_table=table
	table=joypad.get()

	if table["P1 Strong Punch"] and not prev_table["P1 Strong Punch"] then P1.HP = P1.HP + 1 end
	if table["P1 Medium Punch"] and not prev_table["P1 Medium Punch"] then P1.MP = P1.MP + 1 end
	if table["P1 Weak Punch"] and not prev_table["P1 Weak Punch"] then P1.LP = P1.LP + 1 end
	if table["P1 Strong Kick"] and not prev_table["P1 Strong Kick"] then P1.HK = P1.HK + 1 end
	if table["P1 Medium Kick"] and not prev_table["P1 Medium Kick"] then P1.MK = P1.MK + 1 end
	if table["P1 Weak Kick"] and not prev_table["P1 Weak Kick"] then P1.LK = P1.LK + 1 end
	if table["P2 Strong Punch"] and not prev_table["P2 Strong Punch"] then P2.HP = P2.HP + 1 end
	if table["P2 Medium Punch"] and not prev_table["P2 Medium Punch"] then P2.MP = P2.MP + 1 end
	if table["P2 Weak Punch"] and not prev_table["P2 Weak Punch"] then P2.LP = P2.LP + 1 end
	if table["P2 Strong Kick"] and not prev_table["P2 Strong Kick"] then P2.HK = P2.HK + 1 end
	if table["P2 Medium Kick"] and not prev_table["P2 Medium Kick"] then P2.MK = P2.MK + 1 end
	if table["P2 Weak Kick"] and not prev_table["P2 Weak Kick"] then P2.LK = P2.LK + 1 end


	-- print(table)
	-- {P2 Right=false, Volume Down=false, Service=false, P2 Coin=false, P1 Coin=false, P1 Down=false, P1 Strong Punch=false, P2 Weak Punch=false, P1 Weak Punch=false, Volume Up=false, P1 Start=false, P1 Medium Kick=false, P1 Right=false, P2 Up=false, P1 Strong Kick=false, Diagnostic=false, P1 Medium Punch=false, P2 Down=false, P2 Left=false, P1 Left=false, P2 Medium Kick=false, P2 Medium Punch=false, P2 Strong Punch=false, P1 Weak Kick=false, P2 Weak Kick=false, P1 Up=false, P2 Strong Kick=false, P2 Start=false, Reset=false}	
	--if not table["P1 Strong Punch"] and prev_table["P1 Strong Punch"] then
	--	print("P1: HP released")
 	--end

	emu.frameadvance()
end
--

