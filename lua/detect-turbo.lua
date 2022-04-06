print("Quick & dirty Turbo/Autofire detector for Fightcade replays")
print("by @pof - April 2022")
print("")

local turbo_treshold = 13
local table=joypad.get()
local prev_table={}
local frames = emu.framecount()
local P1={LP=0,MP=0,HP=0,LK=0,MK=0,HK=0}
local P2={LP=0,MP=0,HP=0,LK=0,MK=0,HK=0}

-- DEBUG, to add more systems:
-- print(table)
print("Waiting for button presses higher than "..turbo_treshold.." Taps Per Second (TPS)")
print("")
while true do
	local fc = emu.framecount()
	if (fc-frames >= 60) then
		if (P1.LP > turbo_treshold) then print("TURBO detected on P1 Button_1="..P1.LP.."tps") end
		if (P1.MP > turbo_treshold) then print("TURBO detected on P1 Button_2="..P1.MP.."tps") end
		if (P1.HP > turbo_treshold) then print("TURBO detected on P1 Button_3="..P1.HP.."tps") end
		if (P1.LK > turbo_treshold) then print("TURBO detected on P1 Button_4="..P1.LK.."tps") end
		if (P1.MK > turbo_treshold) then print("TURBO detected on P1 Button_5="..P1.MK.."tps") end
		if (P1.HK > turbo_treshold) then print("TURBO detected on P1 Button_6="..P1.HK.."tps") end
		if (P2.LP > turbo_treshold) then print("TURBO detected on P2 Button_1="..P2.LP.."tps") end
		if (P2.MP > turbo_treshold) then print("TURBO detected on P2 Button_2="..P2.MP.."tps") end
		if (P2.HP > turbo_treshold) then print("TURBO detected on P2 Button_3="..P2.HP.."tps") end
		if (P2.LK > turbo_treshold) then print("TURBO detected on P2 Button_4="..P2.LK.."tps") end
		if (P2.MK > turbo_treshold) then print("TURBO detected on P2 Button_5="..P2.MK.."tps") end
		if (P2.HK > turbo_treshold) then print("TURBO detected on P2 Button_6="..P2.HK.."tps") end

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

	-- capcom
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

	-- neogeo
	if table["P1 Button B"] and not prev_table["P1 Button B"] then P1.MP = P1.MP + 1 end
	if table["P1 Button A"] and not prev_table["P1 Button A"] then P1.LP = P1.LP + 1 end
	if table["P1 Button D"] and not prev_table["P1 Button D"] then P1.MK = P1.MK + 1 end
	if table["P1 Button C"] and not prev_table["P1 Button C"] then P1.LK = P1.LK + 1 end
	if table["P2 Button B"] and not prev_table["P2 Button B"] then P2.MP = P2.MP + 1 end
	if table["P2 Button A"] and not prev_table["P2 Button A"] then P2.LP = P2.LP + 1 end
	if table["P2 Button D"] and not prev_table["P2 Button D"] then P2.MK = P2.MK + 1 end
	if table["P2 Button C"] and not prev_table["P2 Button C"] then P2.LK = P2.LK + 1 end

	-- midway
	if table["P1 High Punch"] and not prev_table["P1 High Punch"] then P1.HP = P1.HP + 1 end
	if table["P1 Block"] and not prev_table["P1 Block"] then P1.MP = P1.MP + 1 end
	if table["P1 Low Punch"] and not prev_table["P1 Low Punch"] then P1.LP = P1.LP + 1 end
	if table["P1 High Kick"] and not prev_table["P1 High Kick"] then P1.HK = P1.HK + 1 end
	if table["P1 Run"] and not prev_table["P1 Run"] then P1.MK = P1.MK + 1 end
	if table["P1 Low Kick"] and not prev_table["P1 Low Kick"] then P1.LK = P1.LK + 1 end
	if table["P2 High Punch"] and not prev_table["P2 High Punch"] then P2.HP = P2.HP + 1 end
	if table["P2 Block"] and not prev_table["P2 Block"] then P2.MP = P2.MP + 1 end
	if table["P2 Low Punch"] and not prev_table["P2 Low Punch"] then P2.LP = P2.LP + 1 end
	if table["P2 High Kick"] and not prev_table["P2 High Kick"] then P2.HK = P2.HK + 1 end
	if table["P2 Run"] and not prev_table["P2 Run"] then P2.MK = P2.MK + 1 end
	if table["P2 Low Kick"] and not prev_table["P2 Low Kick"] then P2.LK = P2.LK + 1 end

	emu.frameadvance()
end
