--========================================--
--       Sako Tick Training Script        --
--             by Born2SPD                --
--                V 1.0                   --
--========================================--

--How I detected the inputs:
--
--	The game saves in the memory the "current state" of
--p1's typhoon in the address 0xFF84E0. Each needed
-- direction/nput is perfomed the game adds 2 to this address.
--When this has a value of 8, it waits a punch input.
--
--I also used Double Typhoon orientation bit which works
--like this:
--	If first Direction is Left: 2, if Right: 0
--		If next direction is Up, +0, if is Down, +1
--	Else, if first Direction is Up: 4, if Down: 6
--		If next direction is Left, + 1, if it's Right: +0
--	Tiis way it knows not only the first direction the player
--	used to spin but also the direction (clockwise or
--	counterclockwise). This is why the script only works with
--	N.Hawk, I didnt needed to implement such detection.
--
--To detect punches I used the lua function joypad.get()
--
--Input Display and Hitbox Viewer were not coded by me,
--	I'm just borrowing them since you can't use more than
--	one Lua script at the same time.
--
--The rest of the code is coded by me though (Born2SPD).
--It's not the most beautiful code you'll see on your life,
--	I just wanted this shit to work.
--
--You may modify or use any part of the code as you wish,
--	just make sure you "remember" who coded it on the first place!
--
-- add permisive mode modification by @pof (June 2014)

--## Constants ##--

MSG_FRAMELIMIT = 600
STATE_FRAMELIMIT = 30

--## Global Vars ##--

sako_analysis = true
show_debug = true
permissive = true
initial_dist=0

msg1 = ""
msg2 = ""
msg3 = ""
state = 0
state_fcount = 0
msg_fcount = 0
min_dist = 0
target_msg = ""
target_msg_align = 0

--These are the global vars that will hold the frames addreses for the Neutral Standing Jab, varies from N to O Hawk
jab_startup_frame = 0x0
jab_hitting_frame = 0x0
jab_recovery_frame = 0x0
jab_last_frame = 0x0
jab_first_walking_frame = 0x0

--## FUNCTIONS ##--

-- Calculates positional difference between the two dummies
-- Borrowed this function from Pasky's STHUD script, removed the Y calcule though
local function calc_range()
	local range = 0
	local p2=0x000400

	if memory.readword(0xFF8454) >= memory.readword(0xFF8454+p2) then
		if memory.readword(0xFF8458) >= memory.readword(0xFF8458+p2) then
			range = (memory.readword(0xFF8454) - memory.readword(0xFF8454+p2))
		else
			range = (memory.readword(0xFF8454) - memory.readword(0xFF8454+p2))
		end
	else
		if memory.readword(0xFF8458+p2) >= memory.readword(0xFF8458) then
			range = (memory.readword(0xFF8454+p2) - memory.readword(0xFF8454))
		else
			range = (memory.readword(0xFF8454+p2) - memory.readword(0xFF8454))
		end
	end
	return range
end

--Checks which character the player 2 is set to and set ups some stuff directly related to it
local function p2_check()	

	if memory.readbyte(0xFF8DD2) == 0x01 then -- 01 = round is over, after the last round the p2_char memory region is always setted to 0, and would produce wrong message for a fraction of time, so this is just a little bugfix...
		return
	end

	if memory.readbyte(0xFF8C0B) == 0x01 then
		min_dist = 94
		target_msg = "Akuma. Minimal Distance: " .. min_dist .. " (Safe from Jab DP and throw range)"
		target_msg_align = 56
		return
	end

	local p2_char = memory.readbyte(0xFF8BDF)
	
	if (p2_char == 0x00) then
		min_dist = 94
		target_msg = "Ryu. Minimal Distance: " .. min_dist .. " (Safe from Jab DP and throw range)"
		target_msg_align = 56
		
	elseif (p2_char == 0x01) then
		if memory.readbyte(0xFF8C04) == 0x00 then -- 0x00 = New, 0x01 = Old
			min_dist = 105
			target_msg = "E.Honda. Minimal Distance: " .. min_dist .. " (Safe from Oicho throw)"
			target_msg_align = 72
		else
			min_dist = 100
			target_msg = "Old E.Honda. Minimal Distance: " .. min_dist .. " (Safe from his throw range)"
			target_msg_align = 56
		end

	elseif (p2_char == 0x02) then
		min_dist = 100
		target_msg = "Blanka. Minimal Distance: " .. min_dist .. " (Safe from Bite Range. Also beats his Beast Rolls)"
		target_msg_align = 16
		
	elseif (p2_char == 0x03) then
		min_dist = 84 --110 is safe against FK first active frames and still viable
		target_msg = "Guile. Minimal Distance: " .. min_dist .. " (Safe from his throw range only)"
		target_msg_align = 56
				
	elseif (p2_char == 0x04) then
		min_dist = 97
		target_msg = "Ken. Minimal Distance: " .. min_dist .. " (Safe from Jab DP and throw range)"
		target_msg_align = 56
		
	elseif (p2_char == 0x05) then
		min_dist = 84 --Safe from her RH Upkick, but you'll only hit her if shes crouching.(84 = safe from throw, 96 = max range to hit her standing)
		target_msg = "Chun Li. Minimal Distance: " .. min_dist .. " (Safe from her throw range. Also beats her UpKicks)"
		target_msg_align = 16
		
	elseif (p2_char == 0x06) then
		min_dist = 119 --At 147, its the ONLY range (yeah only 1 pixel) where you can hit a crouching gief while being out of his SPD range
		target_msg = "Zangief. Minimal Distance: " .. min_dist .. " (Safe from Suplex range only. SPD outranges T.Hawk's Jab)"
		target_msg_align = 1
		
	elseif (p2_char == 0x07) then
		min_dist = 100
		target_msg = "Dhalsim. Minimal Distance: ".. min_dist .. " (Safe from his throw range)"
		target_msg_align = 56
		
	elseif (p2_char == 0x08) then
		min_dist = 88
		target_msg = "Dictator. Minimal Distance: " .. min_dist .. " (Safe from his throw range)"
		target_msg_align = 56
		
	elseif (p2_char == 0x09) then
		min_dist = 101
		target_msg = "Sagat. Minimal Distance: " .. min_dist .. " (Safe from Tiger Uppercut 1st active part and throw range)"
		target_msg_align = 2
		
	elseif (p2_char == 0x0A) then
		min_dist = 87
		target_msg = "Boxer. Minimal Distance: " .. min_dist .. " (Safe from his throw range)"
		target_msg_align = 64
		
	elseif (p2_char == 0x0B) then
		min_dist = 96 --107 = safe from 1st rh flip kick hit, 84= safe from his throw range
		target_msg = "Claw. Minimal Distance: " .. min_dist .. " (Safe from Scarlet Terror's first frames and throw range)"
		target_msg_align = 8
		
	elseif (p2_char == 0x0C) then
		min_dist = 78 --78 = safe from her throw range, 100 is somewhat safe against her thrust kicks
		target_msg = "Cammy. Minimal Distance: " .. min_dist .. " (Safe from her throw only. Unsafe against her Thrust Kicks)"
		target_msg_align = 2		
		
	elseif (p2_char == 0x0D) then
		min_dist = 84
		target_msg = "T.Hawk. Minimal Distance: " .. min_dist .. " (Safe from his normal throw only. Typhoon outranges Jab)"
		target_msg_align = 8
				
	elseif (p2_char == 0x0E) then
		min_dist = 76
		target_msg = "Fei Long. Minimal Distance: " .. min_dist .. " (Safe from throw only. Short Flame Kick outranges Jab)"
		target_msg_align = 8
		
	elseif (p2_char == 0x0F) then
		min_dist = 84
		target_msg = "Dee Jay. Minimal Distance: " .. min_dist .. " (Safe from his throw only. UpKicks outrange T.Hawk's Jab)"
		target_msg_align = 2
	end	
	return
end

--Returns true if too close, false if not, character dependent
local function too_close()	
	if permissive and (calc_range() < min_dist-5) then
		return true
	elseif not permissive and (calc_range() < min_dist) then
		return true
	else
		return false
	end
end

--Function that checks if P1 is using T.Hawk and sets some stuff
--that depends directly on the character version (Old/New)
--Edit: removed O.Hawk support
local function thawk_check()
	if memory.readbyte(0xFF87DF) ~= 0x0D then -- 0x0D = T.Hawk
		msg1 = "Pick T.Hawk, Dumbass."
		msg2 = ""
		msg3 = ""
		return false
	elseif memory.readbyte(0xFF8804) == 0x00 then -- 0x00 = New, 0x01 = Old
		jab_startup_frame = 0x00177b4a		--3 frames of duration
		jab_hitting_frame = 0x00177b62		--4 frames of duration
		jab_recovery_frame = 0x00177b92		--3 frames of duration
		jab_last_frame = 0x00177b92			--1 frame  of duration
		jab_first_walking_frame = 0x00179686
		return true
	else									--Frame data is the same for O.Hawk
--		jab_startup_frame = 0x0020772E
--		jab_hitting_frame = 0x00207746
--		jab_recovery_frame = 0x0020775E
--		jab_last_frame = 0x00207776
--		jab_first_walking_frame = 0x00209002
--		return true
		msg1 = "Only the New version of T.Hawk is supported."
		msg2 = ""
		msg3 = ""
		return false
	end
end

--Updates the Error Message
local function update_msg(er_code)
	msg2 = ""
	msg3 = ""	
	msg_fcount = 1
	if er_code == 0 then --resets
		msg1 = "Waiting for a Sako tick attempt from the propper range. "
		msg2 = "Do the Jab and right after it hold the other punches, "
		msg3 = "wait a bit, and then start the 270 from up to forward."
		msg_fcount = 0
	elseif er_code == 1 then
		msg1 = "You're too close to the opponent, you must tick "
		msg2 = "him from far enough."
		msg_fcount = MSG_FRAMELIMIT-1
	elseif er_code == 2 then
		msg1 = "You wont hit him from that distance..."
		msg_fcount = MSG_FRAMELIMIT-90
	elseif er_code == 3 then
		msg1 = "You must complete the motion before the Jab animation "
		msg2 = "ends. T.Hawk is crouching for a moment: you're doing "
		msg3 = "the motion too slow or you're starting it too late."
	elseif er_code == 41 then --Thawk on left side
		msg1 = "Input must be ^ < v >, you messed it somewhere. "
		msg2 = "Check it on the input display."
	elseif er_code == 42 then --Thawk on the right side
		msg1 = "Input must be ^ > v <, you messed it somewhere. "
		msg2 = "Check it n the input display."
	elseif er_code == 51 then --Thawk on left side
		msg1 = "The first input was detected as > instead of ^. "
		msg2 = "It can still work but it will limit the grabbable "
		msg3 = "walking frames so try to delay the Typhoon a bit."
	elseif er_code == 52 then --Thawk on the right side
		msg1 = "The first input was detected as < instead of ^. "
		msg2 = "It can still work but it will limit the grabbable "
		msg3 = "walking frames so try to delay the Typhoon a bit."
	elseif er_code == 6 then
		msg1 = "Why are you not holding PPP? Press and hold Strong "
		msg2 = "and Fierce right after you pressed Jab for the tick. "
		msg3 = "You'll only release them for the Typhoon."
	elseif er_code == 7 then
		msg1 = "You must be walking after the Jab's last frame, and "
		msg2 = "only stop when the opponent gets out of hitstun."
	elseif er_code == 81 then
		msg1 = "One or more punch buttons were released too soon. "
		msg2 = "The opponent is still in hitstun, this also means that "
		msg3 = "is invulnerable to throws."
	elseif er_code == 82 then
		msg1 = "You're releasing punches too soon AND in the wrong order. "
		msg2 = "Must be Fierce first, Jab last."
	elseif er_code == 9 then --does this ever happen?
		msg1 = "The Typhoon input has vanished from the motion buffer. "
		msg2 = "Are you doing the 270 motion too fast?"
	elseif er_code == 10 then
		msg1 = "You're taking too long to release the Punch buttons, "
		msg2 = "the typhoon input already vanished from the motion buffer."
	elseif er_code == 11 then
		msg1 = "T.Hawk is too far for you to release the buttons. Delay the "
		msg2 = "button releases a little."
	elseif er_code == 12 then
		msg1 = "Good, you did it well. The only mistake is that you're "
		msg2 = "taking too long to block after releasing the Punch buttons."
		if (initial_dist < min_dist) then
			msg3 = "Now try again from a bit farther."
		end
	else
		msg1 = "Well done."
		if (initial_dist < min_dist) then
			msg2 = "Now try again from a bit farther."
		end
		msg_fcount = MSG_FRAMELIMIT-60
	end
	return
end

local function clean_screen()
	update_msg(0)
	return
end

--Resets the state and its frame counter
local function reset_state()
	state = 0
	state_fcount = 0
	return
end

--Resets the error message and its frame counter
local function reset_msg()
	update_msg(0)
	return
end

--Increments state
local function inc_state()
	state = state + 1
	state_fcount = 1
	return
end

local function p2_is_on_hitfreeze()
	if memory.readbyte(0xFF8895) ~= 0x00 then --hitfreeze counter
		return true
	else return false
	end
end

local function p2_is_on_hitstun()
	if memory.readbyte(0xFF8851) >= 0x0E then --not a counter
		return true
	else return false
	end
end

local function p2_was_thrown()
	if memory.readbyte(0xFF88b1) == 0xFF then
		return true
	else return false
	end
end

--Checks if the animation frame passed as argument is the current one
local function p1_curr_anim_frame_is(anim_frame)
	if memory.readdword(0xFF8468) == anim_frame then
		return true
	else
		return false
	end
end

--If P1 is attacking with a Ground normal
local function p1_is_attacking()
	if memory.readbyte(0xFF8451) == 0xA then
		return true
	else return false
	end
end

local function p1_is_on_left_side()
	if memory.readbyte(0xFF860c) == 0x1 then
		return true
	else return false
	end
end

local function p1_is_on_air()
	if memory.readbyte(0xFF85cf) == 0x1 then
		return true
	else return false
	end
end

--If P1 is currently on the typhoon animation
local function p1_typhoon()
	local curr_anim = memory.readdword(0xFF8468)
	--                  (N.Hawk Typhoon frames)                                      (O.Hawk Typhoon frames)
	if ((curr_anim >= 0x0017922e) and (curr_anim <= 0x0017939e)) or ((curr_anim >= 0x00208e12) and (curr_anim <= 0x00208f6a)) then
		return true
	else return false
	end
end

local function p1_is_holding_forward_direction()
	local keytable = joypad.get()
	if p1_is_on_left_side() then
		if keytable["P1 Right"] then
			return true
		else
			return false
		end
	else
		if keytable["P1 Left"] then
			return true
		else
			return false
		end
	end
end

local function p1_is_blocking()
	local keytable = joypad.get()
	if p1_is_on_left_side() then
		if ((keytable["P1 Left"]) and (keytable["P1 Down"])) then
			return true
		else
			return false
		end
	else
		if ((keytable["P1 Right"]) and (keytable["P1 Down"])) then
			return true
		else
			return false
		end
	end
end

--Returns how much frames are left for the the current animation
--when this goes to 0 the next animation is activated by the game itself
local function p1_frames_left_of_curr_anim()
	return memory.readbyte(0xFF8467)
end

--Returns the Typhoon Input bit value
local function p1_typhoon_input_code()
	return memory.readbyte(0xFF84E0)
end

--Returns the Double Typhoon Input Direction bit value (Thank god this exists, made everything easier...)
local function p1_super_input_direction_code()
	return memory.readbyte(0xFF84ED)
end

local function p1_punches_are_being_held()
	local punchbit = 0
	local keytable = joypad.get()
	if keytable["P1 Button 1"] then
		punchbit = punchbit + 1
	end
	if keytable["P1 Button 2"] then
		punchbit = punchbit + 2
	end
	if keytable["P1 Button 3"] then
		punchbit = punchbit + 4
	end
	return punchbit
end

-- Main function
local function sako_logic()

	if not(thawk_check()) then
		return
	end
	p2_check()
	
--##### STATE 0: Waiting for Jab #####--
	if state == 0 then
		if ((too_close()) and not(p1_typhoon())) then
			if (p1_curr_anim_frame_is(jab_hitting_frame)) then
				initial_dist=calc_range()
			end
			reset_state()
			update_msg(1)	--too close, no point in training sakos from this range
			return
		elseif p1_curr_anim_frame_is(jab_hitting_frame) then
			if p2_is_on_hitfreeze() then
				initial_dist=calc_range()
				inc_state()
				reset_msg()	--jab hit the opponent from far enough, sends to next state
				return
			end
		elseif (p1_curr_anim_frame_is(jab_recovery_frame)) and not(p2_is_on_hitstun()) then
			initial_dist=calc_range()
			reset_state()
			update_msg(2) --jab didnt hit the opponent, he is too far for it
		end
		return
	end

--###### STATE 1: Jab OK, waiting for other punches to be held as well as the next inputs ######--
	if state == 1 then
		if not(p1_is_attacking()) then --T.Hawk Jab animation is complete, if you didnt passed to the next state yet, something is wrong
			reset_state()
			update_msg(3)
			return
		elseif ((p1_is_on_left_side()) and (p1_typhoon_input_code() == 8)) then -- If the player already did the Typhoon
			if p1_super_input_direction_code() == 5 or (p1_super_input_direction_code() == 0 and permissive) then --if first direction was up and the second was left
				if p1_punches_are_being_held() == 7 then --go to next state		
					inc_state()
					reset_msg()
					return
				else					-- not holding PPP
					reset_state()
					update_msg(6)
					return
				end
			elseif p1_super_input_direction_code() == 0 and not permissive then --the direction thawk used to walk was registered in the tphoon input, wrong
				reset_state()
				update_msg(51)
				return
			else			
				reset_state()
				update_msg(41)	--input is wrong
				return
			end
		elseif (not(p1_is_on_left_side()) and (p1_typhoon_input_code() == 8)) then -- If the player already did the Typhoon
			if p1_super_input_direction_code() == 4 or (p1_super_input_direction_code() == 2 and permissive) then --if first direction was up and the second was right
				if p1_punches_are_being_held() == 7 then --go to next state		
					inc_state()
					reset_msg()
					return
				else					-- not holding PPP
					reset_state()
					update_msg(6)
					return
				end
			elseif p1_super_input_direction_code() == 2 and not permissive then --the direction thawk used to walk was registered in the tphoon input, wrong
				reset_state()
				update_msg(52)
				return
			else
				reset_state()
				update_msg(42)	--input is wrong
				return
			end
		end
		return --goes here if he didnt started the 270 yet
	end

--###### STATE 2: p2 is on hit stun. p1 must continue walking forward and continue holding PPP, to only release them when P2 is throwable ######--
	if state == 2 then
		if not(p1_is_holding_forward_direction()) then --not walking
			reset_state()
			update_msg(7)
			return
		elseif p1_punches_are_being_held() < 3 and not permissive then --releasing PPP too soon, fierce is ignored for leniency
			reset_state()
			update_msg(81)
			return
		elseif (p1_punches_are_being_held() == 6) or (p1_punches_are_being_held() == 4) then -- releasing jab first, totally wrong
			reset_state()
			update_msg(82)
			return
		elseif p1_typhoon_input_code() == 0 then --the typhoon input has vanished from the input buffer
			reset_state()
			update_msg(9)
			return		
		end
		if p2_is_on_hitstun() then
			return --p1 is walking and holding punches, but p2 still on hitstun, rechecks everything till he gets out of it
		else
			inc_state()
			reset_msg()
			return
		end
	end
	
--###### STATE 3: p1 is holding PPP and walking forward. p2 is now throwable, time to release punches and go to defense ######--
	if state == 3 then
		if p1_typhoon() then
			if not(p1_is_on_air()) then
				if p1_is_blocking() then
					inc_state()
					reset_msg()
					return
				else
					return --he is not blocking yet, will check if he will in the next frame
				end
			else
				reset_state()
				update_msg(12)
				return	
			end

		--need to find another way to detect punch releases done too soon.
			
		elseif (p1_punches_are_being_held() == 0) then
--			reset_state()
			update_msg(11) --buttons released too soon
			return		
		elseif (p1_typhoon_input_code() == 0) and (p1_punches_are_being_held() > 0) then
			reset_state()
			update_msg(10) --took too long to release the punch buttons, the typhoon input vanished from the motion buffer
			return	
		end	
	end

--###### STATE 4: Just tells the player that he did it well ######--
	if state == 4 then
		update_msg(-1)
	end
	return
end

local function draw_messages()

	if memory.readword(0xFF847F) == 0 then --if not in match
		return
	end
	
	if not sako_analysis then
		return
	end
	
	--Updates the messages
	if msg_fcount >= MSG_FRAMELIMIT then
		reset_msg()
	elseif msg_fcount > 0 then
		msg_fcount = msg_fcount + 1
	end
	
	if state_fcount >= STATE_FRAMELIMIT then
		reset_state()
	elseif state_fcount > 0 then
		state_fcount = state_fcount + 1
	end

	--Draw Stuff
	if show_debug then		
		gui.text(112,10,"State: " .. state .. "  Input: " .. p1_typhoon_input_code() .. "  Direction: " .. p1_super_input_direction_code() .. " Dist: " .. initial_dist)
	end

	--Sako tips
	gui.text(92,56,msg1)
	gui.text(92,64,msg2)
	gui.text(92,72,msg3)

	--Distance stuff
	gui.text(160,208,"Distance: " .. calc_range())
	gui.text(target_msg_align,216,"Target: " .. target_msg)	

	return
end

----------------------------------------------------------------------------------------------------
-- Scrolling Input
-- Original Authors for this Script: Dammit
-- Homepage: http://code.google.com/p/mame-rr/
-- requires the Lua gd library (http://luaforge.net/projects/lua-gd/)
----------------------------------------------------------------------------------------------------

--[[
Scrolling input display Lua script
requires the Lua gd library (http://luaforge.net/projects/lua-gd/)
written by Dammit (dammit9x at hotmail dot com)

Works with MAME, FBA, pcsx, snes9x and Gens:
http://code.google.com/p/mame-rr/downloads/list
http://code.google.com/p/fbarr/downloads/list
http://code.google.com/p/pcsxrr/downloads/list
http://code.google.com/p/snes9x-rr/downloads/list
http://code.google.com/p/gens-rerecording/downloads/list
]]

version      = "11/10/2010"

iconfile     = "icons-capcom-8.png"  --file containing the icons to be shown

buffersize   = 16     --how many lines to show
margin_left  = 1      --space from the left of the screen, in tiles, for player 1
margin_right = 2      --space from the right of the screen, in tiles, for player 2
margin_top   = 9      --space from the top of the screen, in tiles
timeout      = 15     --how many idle frames until old lines are cleared on the next input
screenwidth  = 256    --pixel width of the screen for spacing calculations (only applies if emu.screenwidth() is unavailable)

--Key bindings below only apply if the emulator does not support Lua hotkeys.
--playerswitch = "Q"         --key pressed to toggle players on/off
--clearkey     = "tilde"     --key pressed to clear screen
--sizekey      = "semicolon" --key pressed to change icon size
--scalekey     = "quote"     --key pressed to toggle icon stretching
--recordkey    = "numpad/"   --key pressed to start/stop recording video

----------------------------------------------------------------------------------------------------

gamekeys = {
	{ set =
		{ "capcom",   snes9x,    gens,       pcsx,            fba,       mame },
		{      "l",   "left",  "left",     "left",         "Left",     "Left" },
		{      "r",  "right", "right",    "right",        "Right",    "Right" },
		{      "u",     "up",    "up",       "up",           "Up",       "Up" },
		{      "d",   "down",  "down",     "down",         "Down",     "Down" },
		{     "ul"},
		{     "ur"},
		{     "dl"},
		{     "dr"},
		{     "LP",      "Y",     "X",   "square",   "Weak Punch", "Button 1" },
		{     "MP",      "X",     "Y", "triangle", "Medium Punch", "Button 2" },
		{     "HP",      "L",     "Z",       "r1", "Strong Punch", "Button 3" },
		{     "LK",      "B",     "A",        "x",    "Weak Kick", "Button 4" },
		{     "MK",      "A",     "B",   "circle",  "Medium Kick", "Button 5" },
		{     "HK",      "R",     "C",       "r2",  "Strong Kick", "Button 6" },
		{      "S", "select",  "none",    "start",        "Start",    "Start" },
	},
	{ set =
		{ "neogeo",       pcsx,        fba,       mame },
		{      "l",     "left",     "Left",     "Left" },
		{      "r",    "right",    "Right",    "Right" },
		{      "u",       "up",       "Up",       "Up" },
		{      "d",     "down",     "Down",     "Down" },
		{     "ul"},
		{     "ur"},
		{     "dl"},
		{     "dr"},
		{      "A",   "square", "Button A", "Button 1" },
		{      "B", "triangle", "Button B", "Button 2" },
		{      "C",        "x", "Button C", "Button 3" },
		{      "D",   "circle", "Button D", "Button 4" },
		{      "S",    "start",    "Start",    "Start" },
	},
	{ set =
		{ "tekken",       pcsx,       mame },
		{      "l",     "left",     "Left" },
		{      "r",    "right",    "Right" },
		{      "u",       "up",       "Up" },
		{      "d",     "down",     "Down" },
		{     "ul"},
		{     "ur"},
		{     "dl"},
		{     "dr"},
		{      "1",   "square", "Button 1" },
		{      "2", "triangle", "Button 2" },
		{      "T",        nil, "Button 3" },
		{      "3",        "x", "Button 4" },
		{      "4",   "circle", "Button 5" },
		{      "S",    "start",    "Start" },
	},
}

--folder with scrolling-input-code.lua, icon files, & frame dump folder (relative to this lua file)
resourcepath = "scrolling-input"

-- This file is meant to be run by scrolling-input-display.lua
-- user: Do not edit this file.

local recordpath = "framedump" --(relative to resourcepath)

--print("Scrolling input display Lua script, " .. version)
--print("Press " .. (input.registerhotkey and "Lua hotkey 1" or playerswitch) .. " to toggle players.")
--print("Press " .. (input.registerhotkey and "Lua hotkey 2" or clearkey) .. " to clear the screen.")
--print("Press " .. (input.registerhotkey and "Lua hotkey 3" or sizekey) .. " to resize the icons.")
--print("Press " .. (input.registerhotkey and "Lua hotkey 4" or scalekey) .. " to toggle icon stretching.")
--print("Press " .. (input.registerhotkey and "Lua hotkey 5" or recordkey) .. " to start/stop recording to '" .. recordpath .. "' folder")
--print()

local gd = require "gd"
local minimum_tile_size, maximum_tile_size = 8, 32
local icon_size, image_icon_size = minimum_tile_size
local thisframe, lastframe, module, keyset, changed = {}, {}
local margin, rescale_icons, recording, display, start, effective_width = {}, true, false
local draw = { [1] = true, [2] = true }
local inp  = { [1] =   {}, [2] =   {} }
local idle = { [1] =    0, [2] =    0 }

for m, scheme in ipairs(gamekeys) do --Detect what set to use.
	if string.find(iconfile:lower(), scheme.set[1]:lower()) then
		module = scheme
		for k, emu in pairs(scheme.set) do --Detect what emulator this is.
			if k > 1 and emu then
				keyset = k
				break
			end
		end
		break
	end
end
if not module then error("There's no module available for " .. iconfile, 0) end
if not keyset then error("The '" .. module.set[1] .. "' module isn't prepared for this emulator.", 0) end

--hardcoded check corrects button mapping discrepancy between Tekken 1/2 and Tekken3/TTT
if mame and emu.sourcename() == "namcos11.c" then
	module[11][keyset],module[12][keyset],module[13][keyset] = nil,"Button 3","Button 4"
end

resourcepath = resourcepath .. "/"
recordpath = recordpath .. "/"
emu = emu or gens
----------------------------------------------------------------------------------------------------
-- image-string conversion functions

local function hexdump_to_string(hexdump)
	local str = ""
	for n = 1, hexdump:len(), 2 do
		str = str .. string.char("0x" .. hexdump:sub(n,n+1))
	end
	return str
end

local function string_to_hexdump(str)
	local hexdump = ""
	for n = 1, str:len() do
		hexdump = hexdump .. string.format("%02X",str:sub(n,n):byte())
	end
	return hexdump
end
--example usage:
--local image = gd.createFromPng("image.png")
--local str = image:pngStr()
--local hexdump = string_to_hexdump(str)

local blank_img_hexdump = 
"89504E470D0A1A0A0000000D49484452000000400000002001030000009853ECC700000003504C5445000000A77A3DDA00" ..

"00000174524E530040E6D8660000000D49444154189563601805F8000001200001BFC1B1A80000000049454E44AE426082"
local blank_img_string = hexdump_to_string(blank_img_hexdump)

----------------------------------------------------------------------------------------------------
-- display functions

local function text(x, y, row)
	gui.text(x, y, module[row][1])
end

local function image(x, y, row)
	gui.gdoverlay(x, y, module[row].img:gdStr())
end

display = image
if not io.open(resourcepath .. iconfile, "rb") then
	print("Icon file " .. iconfile .. " not found.")
	print("Falling back on text mode.")
	display = text
end

local function readimages()
	local scaled_width = icon_size
	if rescale_icons and emu.screenwidth and emu.screenheight then
		scaled_width = icon_size * emu.screenwidth()/emu.screenheight() / (4/3)
	end
	if display == image then
		local sourceimg = gd.createFromPng(resourcepath .. iconfile)
		image_icon_size = sourceimg:sizeX()/2
		for n, key in ipairs(module) do
			key.img = gd.createFromPngStr(blank_img_string)
			gd.copyResampled(key.img, sourceimg, 0, 0, 0,(n-1)*image_icon_size, scaled_width, icon_size, image_icon_size, image_icon_size)
		end
	end
	effective_width = scaled_width
end
readimages()

----------------------------------------------------------------------------------------------------
-- update functions

local function filterinput(p, frame)
	for pressed, state in pairs(joypad.getdown(p)) do --Check current controller state >
		for row, name in pairs(module) do               --but ignore non-gameplay buttons.
			if pressed == name[keyset]
		--Arcade does not distinguish joypads, so inputs must be filtered by "P1" and "P2".
			or pressed == "P" .. p .. " " .. tostring(name[keyset])
		--MAME also has unusual names for the start buttons.
			or pressed == p .. (p == 1 and " Player " or " Players ") .. tostring(name[keyset]) then
				frame[row] = state
				break
			end
		end
	end
end

local function compositeinput(frame)          --Convert individual directions to diagonals.
	for _,dir in pairs({ {1,3,5}, {2,3,6}, {1,4,7}, {2,4,8} }) do --ul, ur, dl, dr
		if frame[dir[1]] and frame[dir[2]] then
			frame[dir[1]], frame[dir[2]], frame[dir[3]] = nil, nil, true
		end
	end
end

local function detectchanges(lastframe, thisframe)
	changed = false
	for key, state in pairs(thisframe) do       --If a key is pressed >
		if lastframe and not lastframe[key] then  --that wasn't pressed last frame >
			changed = true                          --then changes were made.
			break
		end
	end
end

local function updaterecords(player, frame, input)
	if changed then                         --If changes were made >
		if idle[player] < timeout then        --and the player hasn't been idle too long >
			for record = buffersize, 2, -1 do
				input[record] = input[record-1]   --then shift every old record by 1 >
			end
		else
			for record = buffersize, 2, -1 do
				input[record] = nil               --otherwise wipe out the old records.
			end
		end
		idle[player] = 0                      --Reset the idle count >
		input[1] = {}                         --and set current input as record 1 >
		local index = 1
		for row, name in ipairs(module) do    --but the order must not deviate from gamekeys.
			for key, state in pairs(frame) do
				if key == row then
					input[1][index] = row
					index = index+1
					break
				end
			end
		end
	else
		idle[player] = idle[player]+1         --Increment the idle count if nothing changed.
	end
end

emu.registerafter(function()
	margin[1] = margin_left*effective_width
	margin[2] = (emu.screenwidth and emu.screenwidth() or screenwidth) - margin_right*effective_width
	margin[3] = margin_top*icon_size
	for player = 1, 2 do
		thisframe = {}
		filterinput(player, thisframe)
		compositeinput(thisframe)
		detectchanges(lastframe[player], thisframe)
		updaterecords(player, thisframe, inp[player])
		lastframe[player] = thisframe
	end
	if recording then
		gd.createFromGdStr(gui.gdscreenshot()):png(resourcepath .. recordpath .. string.format("moviedump-%06d.png", movie.framecount()))
	end
end)

----------------------------------------------------------------------------------------------------
-- savestate functions

if savestate.registersave and savestate.registerload then --registersave/registerload are unavailable in some emus
	savestate.registersave(function(slot)
		return draw, inp, idle
	end)

	savestate.registerload(function(slot)
		draw, inp, idle = savestate.loadscriptdata(slot)
		if type(draw) ~= "table" then draw = { [1] = true, [2] = true } end
		if type(inp)  ~= "table" then inp  = { [1] =   {}, [2] =   {} } end
		if type(idle) ~= "table" then idle = { [1] =    0, [2] =    0 } end
	end)
end

----------------------------------------------------------------------------------------------------
-- hotkey functions

local function toggleplayer()
	if draw[1] and draw[2] then
		draw[1] = false
--		emu.message("Player 1 off.")
	print("---------------------------------------------------------------------------------")
	print("Player 1 off.")
	print("---------------------------------------------------------------------------------")
	elseif not draw[1] and draw[2] then
		draw[1] = true
		draw[2] = false
--		emu.message("Player 2 off.")
	print("---------------------------------------------------------------------------------")
	print("Player 2 off.")
	print("---------------------------------------------------------------------------------")
	elseif draw[1] and not draw[2] then
		draw[2] = true
--		emu.message("Both players on.")
	print("---------------------------------------------------------------------------------")
	print("Both players on.")
	print("---------------------------------------------------------------------------------")
	end
end

local function clear()
	inp = { [1] = {}, [2] = {} }
	emu.message("Cleared screen.")
end

local function resize()
	if icon_size < maximum_tile_size then
		icon_size = icon_size + minimum_tile_size/4
	else
		icon_size = minimum_tile_size
	end
	emu.message("Icon size: " .. icon_size)
	readimages()
end

local function togglescaling()
	rescale_icons = not rescale_icons
	if emu.screenwidth and emu.screenheight then
		emu.message("Icon stretching " .. (rescale_icons and "on." or "off."))
		readimages()
	else
		emu.message("This emulator does not support icon scaling.")
	end
end

local function togglerecording()
	recording = not recording
	if recording then
		start = movie.framecount()
		print("Started recording.")
	else
		local stop = movie.framecount()
		print("Stopped recording. (" .. stop - start .. " frames)")
		if stop > start then
			print(string.format("'moviedump-%06d.png' to 'moviedump-%06d.png'", start, stop-1))
		end
		print()
		start = nil
	end
end

--if input.registerhotkey then
--	input.registerhotkey(1, function()
--		toggleplayer()
--	end)
--
--	input.registerhotkey(2, function()
--		clear()
--	end)
--
--	input.registerhotkey(3, function()
--		resize()
--	end)
--
--	input.registerhotkey(4, function()
--		togglescaling()
--	end)
--
--	input.registerhotkey(5, function()
--		togglerecording()
--	end)
--end

--local oldswitch, oldclearkey, oldsizekey, oldscalekey, oldrecordkey
--emu.registerbefore( function()
--	if not input.registerhotkey then --use input.get if registerhotkey is unavailable
--		local nowswitch = input.get()[playerswitch]
--		if nowswitch and not oldswitch then
--				toggleplayer()
--		end
--		oldswitch = nowswitch
--
--		local nowclearkey = input.get()[clearkey]
--		if nowclearkey and not oldclearkey then
--			clear()
--		end
--		oldclearkey = nowclearkey
--
--		local nowsizekey = input.get()[sizekey]
--		if nowsizekey and not oldsizekey then
--			resize()
--		end
--		oldsizekey = nowsizekey
--
--		local nowscalekey = input.get()[scalekey]
--		if nowscalekey and not oldscalekey then
--			togglescaling()
--		end
--		oldscalekey = nowscalekey
--
--		local nowrecordkey = input.get()[recordkey]
--		if nowrecordkey and not oldrecordkey then
--			togglerecording()
--		end
--		oldrecordkey = nowrecordkey
--	end
--end)

----------------------------------------------------------------------------------------------------
--End Scrolling Input script by: Dammit
--Homepage: http://code.google.com/p/mame-rr/
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
-- Hitboxes
-- Original Authors for this Script: Dammit, MZ, Felineki
-- Homepage: http://code.google.com/p/mame-rr/
----------------------------------------------------------------------------------------------------

local boxes = {
	      ["vulnerability"] = {color = 0x0000FF, fill = 0x00, outline = 0xFF},
	             ["attack"] = {color = 0xFF0000, fill = 0x00, outline = 0xFF},
	["proj. vulnerability"] = {color = 0x00FFFF, fill = 0x00, outline = 0xFF},
	       ["proj. attack"] = {color = 0xFF6600, fill = 0x00, outline = 0xFF},
	               ["push"] = {color = 0x00FF00, fill = 0x00, outline = 0xFF},
	               ["weak"] = {color = 0xFF00FF, fill = 0x00, outline = 0xFF},
	              ["throw"] = {color = 0xFFFF00, fill = 0x00, outline = 0xFF},
	          ["throwable"] = {color = 0xF0F0F0, fill = 0x00, outline = 0xFF},
	      ["air throwable"] = {color = 0x202020, fill = 0x00, outline = 0xFF},
}

local AXIS_COLOR           = 0x7F7F7FFF
local BLANK_COLOR          = 0xFFFFFFFF
local AXIS_SIZE            = 4
local MINI_AXIS_SIZE       = 2
local BLANK_SCREEN         = false
local DRAW_AXIS            = true
local DRAW_MINI_AXIS       = false
local DRAW_PUSHBOXES       = true
local DRAW_THROWABLE_BOXES = true
local DRAW_DELAY           = 1
local NUMBER_OF_PLAYERS    = 2
local MAX_GAME_PROJECTILES = 8
local MAX_BONUS_OBJECTS    = 16
local draw_hitboxes = 1

local profile = {
	{
		games = {"ssf2t"},
		status_type = "normal",
		address = {
			player           = 0xFF844E,
			projectile       = 0xFF97A2,
			left_screen_edge = 0xFF8ED4,
			stage            = 0xFFE18B,
		},
		player_space       = 0x400,
		box_parameter_size = 1,
		box_list = {
			{addr_table = 0x8, id_ptr = 0xD, id_space = 0x04, type = "push"},
			{addr_table = 0x0, id_ptr = 0x8, id_space = 0x04, type = "vulnerability"},
			{addr_table = 0x2, id_ptr = 0x9, id_space = 0x04, type = "vulnerability"},
			{addr_table = 0x4, id_ptr = 0xA, id_space = 0x04, type = "vulnerability"},
			{addr_table = 0x6, id_ptr = 0xC, id_space = 0x10, type = "attack"},
		},
		throw_box_list = {
			{param_offset = 0x6C, type = "throwable"},
			{param_offset = 0x64, type = "throw"},
		}
	},
}

for _,game in ipairs(profile) do
	game.box_number = #game.box_list + #game.throw_box_list
end

for _,box in pairs(boxes) do
	box.fill    = box.color * 0x100 + box.fill
	box.outline = box.color * 0x100 + box.outline
end

local game, effective_delay

local globals = {
	game_phase       = 0,
	left_screen_edge = 0,
	top_screen_edge  = 0,
}
local player       = {}
local projectiles  = {}
local frame_buffer = {}
if fba then
	DRAW_DELAY = DRAW_DELAY + 1
end


--------------------------------------------------------------------------------
-- prepare the hitboxes

local function adjust_delay(address)
	if not address or not mame then
		return DRAW_DELAY
	end
	local stage = memory.readbyte(address)
	for _, val in ipairs({
		0xA, --Boxer
		0xC, --Cammy
		0xD, --T.Hawk
		0xF, --Dee Jay
	}) do
		if stage == val then
			return DRAW_DELAY + 1 --these stages have an extra frame of lag
		end
	end
	return DRAW_DELAY
end



local get_status = {
	["normal"] = function()
		if bit.band(memory.readword(0xFF8008), 0x08) > 0 then
			return true
		end
	end,

	["hsf2"] = function()
		if memory.readword(0xFF8004) == 0x08 then
			return true
		end
	end,
}

local function update_globals()
	globals.left_screen_edge = memory.readword(game.address.left_screen_edge)
	globals.top_screen_edge  = memory.readword(game.address.left_screen_edge + 0x4)
	globals.game_playing     = get_status[game.status_type]()
end


local function get_x(x)
	return x - globals.left_screen_edge
end


local function get_y(y)
	return emu.screenheight() - (y - 15) + globals.top_screen_edge
end


local get_box_parameters = {
	[1] = function(box)
		box.hval   = memory.readbytesigned(box.address + 0)
		box.hval2  = memory.readbyte(box.address + 5)
		if box.hval2 >= 0x80 and box.type == "attack" then
			box.hval = -box.hval2
		end
		box.vval   = memory.readbytesigned(box.address + 1)
		box.hrad   = memory.readbyte(box.address + 2)
		box.vrad   = memory.readbyte(box.address + 3)
	end,

	[2] = function(box)
		box.hval   = memory.readwordsigned(box.address + 0)
		box.vval   = memory.readwordsigned(box.address + 2)
		box.hrad   = memory.readword(box.address + 4)
		box.vrad   = memory.readword(box.address + 6)
	end,
}


local process_box_type = {
	["vulnerability"] = function(obj, box)
	end,

	["attack"] = function(obj, box)
		if obj.projectile then
			box.type = "proj. attack"
		elseif memory.readbyte(obj.base + 0x03) == 0 then
			return false
		end
	end,

	["push"] = function(obj, box)
		if obj.projectile then
			box.type = "proj. vulnerability"
		elseif not DRAW_PUSHBOXES then
			return false
		end
	end,

	["weak"] = function(obj, box)
		if (game.char_mode and memory.readbyte(obj.base + game.char_mode) ~= 0x4)
			or memory.readbyte(obj.animation_ptr + 0x15) ~= 2 then
			return false
		end
	end,

	["throw"] = function(obj, box)
		get_box_parameters[2](box)
		if box.hval == 0 and box.vval == 0 and box.hrad == 0 and box.vrad == 0 then
			return false
		end

		for offset = 0,6,2 do
			memory.writeword(box.address + offset, 0) --bad
		end

		box.hval   = obj.pos_x + box.hval * (obj.facing_dir == 1 and -1 or 1)
		box.vval   = obj.pos_y - box.vval
		box.left   = box.hval - box.hrad
		box.right  = box.hval + box.hrad
		box.top    = box.vval - box.vrad
		box.bottom = box.vval + box.vrad
	end,

	["throwable"] = function(obj, box)
		if not DRAW_THROWABLE_BOXES or
			(memory.readbyte(obj.animation_ptr + 0x8) == 0 and
			memory.readbyte(obj.animation_ptr + 0x9) == 0 and
			memory.readbyte(obj.animation_ptr + 0xA) == 0) or
			memory.readbyte(obj.base + 0x3) == 0x0E or
			memory.readbyte(obj.base + 0x3) == 0x14 or
			memory.readbyte(obj.base + 0x143) > 0 or
			memory.readbyte(obj.base + 0x1BF) > 0 or
			memory.readbyte(obj.base + 0x1A1) > 0 then
			return false
		elseif memory.readbyte(obj.base + 0x181) > 0 then
			box.type = "air throwable"
		end

		box.hrad = memory.readword(box.address + 0)
		box.vrad = memory.readword(box.address + 2)
		box.hval = obj.pos_x
		box.vval = obj.pos_y - box.vrad/2
		box.left   = box.hval - box.hrad
		box.right  = box.hval + box.hrad
		box.top    = obj.pos_y - box.vrad
		box.bottom = obj.pos_y
	end,
}


local function define_box(obj, entry)
	local box = {
		type = game.box_list[entry].type,
		id = memory.readbyte(obj.animation_ptr + game.box_list[entry].id_ptr),
	}

	if box.id == 0 or process_box_type[box.type](obj, box) == false then
		return nil
	end

	local addr_table = obj.hitbox_ptr + memory.readwordsigned(obj.hitbox_ptr + game.box_list[entry].addr_table)
	box.address = addr_table + box.id * game.box_list[entry].id_space
	get_box_parameters[game.box_parameter_size](box)

	box.hval   = obj.pos_x + box.hval * (obj.facing_dir == 1 and -1 or 1)
	box.vval   = obj.pos_y - box.vval
	box.left   = box.hval - box.hrad
	box.right  = box.hval + box.hrad
	box.top    = box.vval - box.vrad
	box.bottom = box.vval + box.vrad

	return box
end


local function define_throw_box(obj, entry)
	local box = {
		type = game.throw_box_list[entry].type,
		address = obj.base + game.throw_box_list[entry].param_offset,
	}

	if process_box_type[box.type](obj, box) == false then
		return nil
	end

	return box
end


local function update_game_object(obj)
	obj.facing_dir    = memory.readbyte(obj.base + 0x12)
	obj.pos_x         = get_x(memory.readwordsigned(obj.base + 0x06))
	obj.pos_y         = get_y(memory.readwordsigned(obj.base + 0x0A))
	obj.animation_ptr = memory.readdword(obj.base + 0x1A)
	obj.hitbox_ptr    = memory.readdword(obj.base + 0x34)

	for entry in ipairs(game.box_list) do
		table.insert(obj, define_box(obj, entry))
	end
end


local function read_projectiles()
	local current_projectiles = {}

	for i = 1, MAX_GAME_PROJECTILES do
		local obj = {base = game.address.projectile + (i-1) * 0xC0}
		if memory.readword(obj.base) == 0x0101 then
			obj.projectile = true
			update_game_object(obj)
			table.insert(current_projectiles, obj)
		end
	end

	for i = 1, MAX_BONUS_OBJECTS do
		local obj = {base = game.address.projectile + (MAX_GAME_PROJECTILES + i-1) * 0xC0}
		if bit.band(0xff00, memory.readword(obj.base)) == 0x0100 then
			update_game_object(obj)
			table.insert(current_projectiles, obj)
		end
	end

	return current_projectiles
end


local function update_sf2_hitboxes()
	if not game then
		return
	end
	effective_delay = adjust_delay(game.address.stage)
	update_globals()

	for f = 1, effective_delay do
		frame_buffer[f].status = frame_buffer[f+1].status
		for p = 1, NUMBER_OF_PLAYERS do
			frame_buffer[f][player][p] = copytable(frame_buffer[f+1][player][p])
		end
		frame_buffer[f][projectiles] = copytable(frame_buffer[f+1][projectiles])
	end

	frame_buffer[effective_delay+1].status = globals.game_playing
	for p = 1, NUMBER_OF_PLAYERS do
		player[p] = {base = game.address.player + (p-1) * game.player_space}
		if memory.readword(player[p].base) > 0x0100 then
			update_game_object(player[p])
		end
		frame_buffer[effective_delay+1][player][p] = player[p]

		local prev_frame = frame_buffer[effective_delay][player][p]
		if prev_frame and prev_frame.pos_x then
			for entry in ipairs(game.throw_box_list) do
				table.insert(prev_frame, define_throw_box(prev_frame, entry))
			end
		end

	end
	frame_buffer[effective_delay+1][projectiles] = read_projectiles()
end


--------------------------------------------------------------------------------
-- draw the hitboxes

local function draw_hitbox(obj, entry)
	local hb = obj[entry]

	if DRAW_MINI_AXIS then
		gui.drawline(hb.hval, hb.vval-MINI_AXIS_SIZE, hb.hval, hb.vval+MINI_AXIS_SIZE, boxes[hb.type].outline)
		gui.drawline(hb.hval-MINI_AXIS_SIZE, hb.vval, hb.hval+MINI_AXIS_SIZE, hb.vval, boxes[hb.type].outline)
	end

	gui.box(hb.left, hb.top, hb.right, hb.bottom, boxes[hb.type].fill, boxes[hb.type].outline)
end


local function draw_axis(obj)
	if not obj or not obj.pos_x then
		return
	end
	
	gui.drawline(obj.pos_x, obj.pos_y-AXIS_SIZE, obj.pos_x, obj.pos_y+AXIS_SIZE, AXIS_COLOR)
	gui.drawline(obj.pos_x-AXIS_SIZE, obj.pos_y, obj.pos_x+AXIS_SIZE, obj.pos_y, AXIS_COLOR)
end


local function render_sf2_hitboxes()
	gui.clearuncommitted()
	if not game or not frame_buffer[1].status or not draw_hitboxes then
		return
	end

	if BLANK_SCREEN then
		gui.box(0, 0, emu.screenwidth(), emu.screenheight(), BLANK_COLOR)
	end

	for entry = 1, game.box_number do
		for i in ipairs(frame_buffer[1][projectiles]) do
			local obj = frame_buffer[1][projectiles][i]
			if obj[entry] then
				draw_hitbox(obj, entry)
			end
		end

		for p = 1, NUMBER_OF_PLAYERS do
			local obj = frame_buffer[1][player][p]
			if obj and obj[entry] then
				draw_hitbox(obj, entry)
			end
		end
	end

	if DRAW_AXIS then
		for p = 1, NUMBER_OF_PLAYERS do
			draw_axis(frame_buffer[1][player][p])
		end
		for i in ipairs(frame_buffer[1][projectiles]) do
			draw_axis(frame_buffer[1][projectiles][i])
		end
	end
end

--------------------------------------------------------------------------------
-- initialize on game startup

local function whatgame()
	game = nil
	for n, module in ipairs(profile) do
		for m, shortname in ipairs(module.games) do
			if emu.romname() == shortname or emu.parentname() == shortname then
				print("drawing " .. shortname .. " hitboxes")
				game = module
				for p = 1, NUMBER_OF_PLAYERS do
					player[p] = {}
				end
				for f = 1, DRAW_DELAY + 2 do
					frame_buffer[f] = {}
					frame_buffer[f][player] = {}
					frame_buffer[f][projectiles] = {}
				end
				return
			end
		end
	end
	print("not prepared for " .. emu.romname() .. " hitboxes")
end


emu.registerstart( function()
	whatgame()
end)

----------------------------------------------------------------------------------------------------
--End Hit box script by: Dammit, MZ, Felineki
--Homepage: http://code.google.com/p/mame-rr/
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
--Hot Keys
----------------------------------------------------------------------------------------------------

input.registerhotkey(1, function()
	sako_analysis = not sako_analysis
	print("---------------------------------------------------------------------------------")
	print((sako_analysis and "Showing" or "Hiding") .. " Sako Tick Execution Tips")
	print("---------------------------------------------------------------------------------")
end)

input.registerhotkey(2, function()
	draw_hitboxes = not draw_hitboxes
	print("---------------------------------------------------------------------------------")
	print((draw_hitboxes and "Showing" or "Hiding") .. " Hitboxes")
	print("---------------------------------------------------------------------------------")
end)

input.registerhotkey(3, function()
	toggleplayer()
end)

input.registerhotkey(4, function()
	clean_screen()
	print("---------------------------------------------------------------------------------")
	print("Cleanned the messages on screen")
	print("---------------------------------------------------------------------------------")
end)

input.registerhotkey(5, function()
	permissive = not permissive
	print("---------------------------------------------------------------------------------")
	print("Permisive mode " .. (permissive and "ON" or "OFF"))
	print("---------------------------------------------------------------------------------")
end)

print("Sako Trainning Script by Born2SPD v0.1")
print("---------------------------------------------------------------------------------")
print("Lua Hotkey 1: Display/Hide Sako Tick Execution Tips")
print("Lua Hotkey 2: Display/Hide Hitboxes")
print("Lua Hotkey 3: Display/Hide Scrolling Input")
print("Lua Hotkey 4: Clean the messages on screen")
print("Lua Hotkey 5: Toggle permissive mode on/off")
print("---------------------------------------------------------------------------------")


----------------------------------------------------------------------------------------------------
--Main loop
----------------------------------------------------------------------------------------------------
while true do
	-- Draw these functions on the same frame data is read
	gui.register(function()
		--Hitbox rendering
		update_sf2_hitboxes()
		render_sf2_hitboxes()

		--Scrolling Input display
		for player = 1, 2 do
			if draw[player] then
				for line in pairs(inp[player]) do
					for index,row in pairs(inp[player][line]) do
						display(margin[player] + (index-1)*effective_width, margin[3] + (line-1)*icon_size, row)
					end
				end
			end
		end

		--Sako Tick Script stuff
		sako_logic()
		draw_messages()
	end)
	--Pause the script until the next frame
	emu.frameadvance()
end
