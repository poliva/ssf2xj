--========================================--
-- SSF2X Lua Training Mode for Fightcade2 --
--                 by pof                 --
--           v0.3 (2020/10/23)            --
--========================================--
-- Contains borrowed code from:
--  * scrolling-input by Dammit
--  	+ frame display by zass
--  	+ fixed windows crash on FBNeo by pof
--  * hitbox viewer by Dammit, MZ, Felineki
--  * ST HUD by Pasky
--  * training mode & stage selctor by pof
--
print("Super Street Fighter 2X - pof's Training mode for Fightcade2 v0.3")

DELAY=0x0a    -- from 0 to ff (set to ff to disable)
p1timer=0
p2timer=0
p1counter = 32
p2counter = 32
training_mode = 0

local function pof_training_logic()
	
	if training_mode == 0 then
		return
	end

	if training_mode == 1 then
		-- disable dizzy
		memory.writeword(0xFF84AA,0)
		memory.writeword(0xFF88AA,0)
	end

	-- infinite time
	timer = memory.readbyte(0xff8dce)
	if (timer < 0x98) then
		memory.writeword(0xff8dce,0x9928)
	end

	c1 = memory.readbyte(0xff8451)
	c2 = memory.readword(0xff847a)
	c3 = memory.readbyte(0xff8851)
	c4 = memory.readword(0xff887a)
	c5 = memory.readbyte(0xff860b)
	c6 = memory.readbyte(0xff8a0b)

	-- timers
	if c1 == 0x14 or c1 == 0xe then
		p1timer=DELAY
	end
	if c3 == 0x14 or c3 == 0xe then
		p2timer=DELAY
	end
	if p1timer > 0 and DELAY ~= 0xff then
		p1timer=p1timer-1
	end
	if p2timer > 0 and DELAY ~= 0xff then
		p2timer=p2timer-1
	end

	-- method1: recharge energy when opponent is idle/crouching and we're not blocking or after being hit/thrown
	if ((c1 ~= 0x14 and c1 ~= 0xe and c1 ~= 8) and c2 < 90 and (c3==2 or c3==0) and p1timer==0) then
		memory.writeword(0xff8478,0x90)
		memory.writeword(0xff847a,0x90)
		memory.writeword(0xff860a,0x90)
	end
	if ((c3 ~= 0x14 and c3 ~= 0xe and c3 ~= 8) and c4 < 90 and (c1==2 or c1==0) and p2timer==0) then
		memory.writeword(0xff8878,0x90)
		memory.writeword(0xff887a,0x90)
		memory.writeword(0xff8a0a,0x90)
	end

	-- method2: recharge energy when round is about to end
	if (c2 < 0xa and (c1 == 0x14 or c1 == 0xe) and p1counter == 0) or (c5 < 2) or (c2 < 2) then
		memory.writeword(0xff8478,0x90)
		memory.writeword(0xff847a,0x90)
		memory.writeword(0xff860a,0x90)
		memory.writebyte(0xFF82F2,0)
		p1counter = 32
	end
	if (c4 < 0xa and (c3 == 14 or c3 == 0xe) and p2counter == 0) or (c6 < 2) or (c4 < 2) then
		memory.writeword(0xff8878,0x90)
		memory.writeword(0xff887a,0x90)
		memory.writeword(0xff8a0a,0x90)
		memory.writebyte(0xFF82F2,0)
		p2counter = 32
	end
	
	-- fix glitches with stun/dizzy & disable KO slowdown when recharging energy using method2
	if p1counter > 0 then
		memory.writebyte(0xFF84AD,0)
		memory.writeword(0xFF84AE,0)
		memory.writeword(0xFF84AB,0)
		memory.writebyte(0xFF82F2,0)
		p1counter = p1counter - 1
	end
	if p2counter > 0 then
		memory.writebyte(0xFF88AD,0)
		memory.writeword(0xFF88AE,0)
		memory.writeword(0xFF88AB,0)
		memory.writebyte(0xFF82F2,0)
		p2counter = p2counter - 1
	end

	-- infinite super
	if (memory.readword(0xFF8008) == 0xa) then
		memory.writebyte(0xFF8702,0x30)
		memory.writebyte(0xFF8B02,0x30)
	end

	return
end

stage_selector = -1

local function toggle_background_stage()
	if stage_selector == -1 then
		return
	end
	cond = memory.readbyte(0xff8008)
	if cond == 0x04 then
		memory.writebyte(0xff8c4f,stage_selector)
	end
	memory.writebyte(0xFF8C51,0)
	memory.writeword(0xFFE18A,stage_selector)
end



-- SSF2T_HUD

----------------------------------------------------------------------------------------------------
-- Global Variables
----------------------------------------------------------------------------------------------------

p2=0x000400
stage_timer=false
draw_hud=0
draw_hitboxes = true
p1_projectile = false
p2_projectile = false
frameskip = true
----------------------------------------------------------------------------------------------------
--Miscellaneous functions
----------------------------------------------------------------------------------------------------

-- Calculate positional difference between the two dummies
local function calc_range()
	local range = 0
	if memory.readword(0xFF8454) >= memory.readword(0xFF8454+p2) then
		if memory.readword(0xFF8458) >= memory.readword(0xFF8458+p2) then
			range = (memory.readword(0xFF8454) - memory.readword(0xFF8454+p2)) .. "/" .. (memory.readword(0xFF8458) - memory.readword(0xFF8458+p2))
		else
			range = (memory.readword(0xFF8454) - memory.readword(0xFF8454+p2)) .. "/" .. (memory.readword(0xFF8458+p2) - memory.readword(0xFF8458))
		end
	else
		if memory.readword(0xFF8458+p2) >= memory.readword(0xFF8458) then
			range = (memory.readword(0xFF8454+p2) - memory.readword(0xFF8454)) .. "/" .. (memory.readword(0xFF8458+p2) - memory.readword(0xFF8458))
		else
			range = (memory.readword(0xFF8454+p2) - memory.readword(0xFF8454)) .. "/" .. (memory.readword(0xFF8458) - memory.readword(0xFF8458+p2))
		end
	end
	return range
end

--Determines if a projectile is still in game and if one can be exectued
local function projectile_onscreen(player)
	local text
	if player == 0 then
		if memory.readbyte(0xFF8622) > 0 then
			text = "Not Ready"
		else
			text = "Ready"
		end
	else
		if memory.readbyte(0xFF8A22) > 0 then
			text = "Not Ready"
		else
			text = "Ready"
		end
	end
	return text
end

--Determines if a special cancel can be performed after a normal move has been executed
local function check_cancel(player) 
	local text
	if player == 1 then
		if memory.readbyte(0xFF85E3) > 0 then
			text = "Ready"
		else
			text = "Not Ready"
		end
	else
		if memory.readbyte(0xFF85E3+p2) > 0 then
			text = "Ready"
		else
			text = "Not Ready"
		end
	end
	return text
end

--Determine the character being used and draw approriate readings
local function determine_char(player)
	local text
	if player == 1 then
		if memory.readbyte(0xFF87DF) == 0x0A then
			--Balrog
			gui.text(2,65,"Ground Straight: ".. memory.readbyte(0xFF84CE))
			gui.text(2,73,"Ground Upper: " ..memory.readbyte(0xFF84D6))
			gui.text(2,81,"Straight: " .. memory.readbyte(0xFF852B))
			gui.text(80,65,"Upper Dash: " .. memory.readbyte(0xFF8524))
			gui.text(80,73,"Buffalo Headbutt: " .. memory.readbyte(0xFF850E))
			gui.text(80,81,"Crazy Buffalo: " .. memory.readbyte(0xFF8522))
			p1_projectile = false
			return
		elseif memory.readbyte(0xFF87DF) == 0x02 then
			--Blanka
			gui.text(2,65,"Normal Roll: " .. memory.readbyte(0xFF8507))
			gui.text(2,73,"Vertical Roll: " .. memory.readbyte(0xFF84FE))
			gui.text(2,81,"Ground Shave Roll: " .. memory.readbyte(0xFF850F))
			p1_projectile = false
			return
		elseif memory.readbyte(0xFF87DF) == 0x0C then
			--Cammy
			gui.text(2,65,"Spin Knuckle: " .. memory.readbyte(0xFF84F0))
			gui.text(2,73,"Cannon Spike: " .. memory.readbyte(0xFF84E0))
			gui.text(2,81,"Spiral Arrow: ".. memory.readbyte(0xFF84E4))
			gui.text(80,65,"Hooligan Combination: " .. memory.readbyte(0xFF84F7))
			gui.text(80,73,"Spin Drive Smasher: " .. memory.readbyte(0xFF84F4))
			p1_projectile = false
			return
		elseif memory.readbyte(0xFF87DF) == 0x05 then
			--Chun Li
			gui.text(2,65,"Kikouken: ".. memory.readbyte(0xFF84CE))
			gui.text(2,73,"Up Kicks: " .. memory.readbyte(0xFF8508))
			gui.text(2,81,"Spinning Bird Kick: " .. memory.readbyte(0xFF84FE))
			gui.text(80,65,"Senretsu Kyaku: " .. memory.readbyte(0xFF850D))
			p1_projectile = true
			return
		elseif memory.readbyte(0xFF87DF) == 0x0F then
			--Dee Jay
			gui.text(2,65,"Air Slasher: " .. memory.readbyte(0xFF84E0))
			gui.text(2,73,"Sovat Kick: " .. memory.readbyte(0xFF84F4))
			gui.text(2,81,"Jack Knife: ".. memory.readbyte(0xFF84E4))
			gui.text(80,65,"Machine Gun Upper: " .. memory.readbyte(0xFF84F9))
			gui.text(80,73,"Sovat Carnival: " .. memory.readbyte(0xFF84FD))
			p1_projectile = true
			return
		elseif memory.readbyte(0xFF87DF) == 0x07 then  
			--Dhalsim
			gui.text(2,65,"Yoga Blast: " .. memory.readbyte(0xFF84D2))
			gui.text(2,73,"Yoga Flame: " .. memory.readbyte(0xFF84E8))
			gui.text(2,81,"Yoga Fire: " .. memory.readbyte(0xFF84CE))
			gui.text(80,65,"Yoga Teleport: ".. memory.readbyte(0xFF84D6))
			gui.text(80,73,"Yoga Inferno: " .. memory.readbyte(0xFF84E4))	
			p1_projectile = true
			return
		elseif memory.readbyte(0xFF87DF) == 0x01 then
			--Honda
			gui.text(2,65,"Flying Headbutt: " .. memory.readbyte(0xFF84D6))
			gui.text(2,73,"Butt Drop: " .. memory.readbyte(0xFF84DE))
			gui.text(2,81,"Oichio Throw: " .. memory.readbyte(0xFF84E4))
			gui.text(80,65, "Double Headbutt" .. memory.readbyte(0xFF84E2))
			p1_projectile = false
			return
		elseif memory.readbyte(0xFF87DF) == 0x0E then
			--Fei Long
			gui.text(2,65,"Rekka: " .. memory.readbyte(0xFF84DE))
			gui.text(2,73,"Rekka 2: " .. memory.readbyte(0xFF84EE))
			gui.text(2,81,"Flame Kick: " .. memory.readbyte(0xFF84E2))
			gui.text(80,65,"Chicken Wing: " .. memory.readbyte(0xFF8502))
			gui.text(80,73,"Rekka Sinken: " .. memory.readbyte(0xFF84FE))
			p1_projectile = false
			return
		elseif memory.readbyte(0xFF87DF) == 0x03 then 
			--Guile
			gui.text(2,65,"Sonic Boom: " .. memory.readbyte(0xFF84CE))
			gui.text(2,73,"Flash Kick: " .. memory.readbyte(0xFF84D4))
			gui.text(2,81,"Double Somersault: " .. memory.readbyte(0xFF84E2))
			p1_projectile = true
			return
		elseif memory.readbyte(0xFF87DF) == 0x04 then 
			--Ken
			gui.text(2,65, "Hadouken: ".. memory.readbyte(0xFF84E2))
			gui.text(2,73, "Shoryuken: " .. memory.readbyte(0xFF84E6))
			gui.text(2,81, "Hurricane Kick: " .. memory.readbyte(0xFF84DE))
			gui.text(42,89, "Shoryureppa: " .. memory.readbyte(0xFF84EE))
			gui.text(80,65, "Crazy Kick 1: " .. memory.readbyte(0xFF8534))
			gui.text(80,73, "Crazy Kick 2: " .. memory.readbyte(0xFF8536))
			gui.text(80,81, "Crazy Kick 3: " .. memory.readbyte(0xFF8538))
			p1_projectile = true
			return
		elseif memory.readbyte(0xFF87DF) == 0x08 then 
			--Dictator
			gui.text(2,65,"Scissor Kick: " .. memory.readbyte(0xFF84D6))
			gui.text(2,73,"Head Stomp: ".. memory.readbyte(0xFF84DF))
			gui.text(2,81,"Devil's Reverse: " .. memory.readbyte(0xFF84FA))
			gui.text(80,65,"Psycho Crusher: " .. memory.readbyte(0xFF84CE))
			gui.text(80,73,"Knee Press Knightmare: " .. memory.readbyte(0xFF8513))
			p1_projectile = false
			return
		elseif memory.readbyte(0xFF87DF) == 0x00 then 
			--Ryu
			gui.text(2,65,"Hadouken: " .. memory.readbyte(0xFF84E2))
			gui.text(2,73,"Shoryuken: " .. memory.readbyte(0xFF84E6))
			gui.text(2,81, "Hurricane Kick: " .. memory.readbyte(0xFF84DE))
			gui.text(80,65, "Red Hadouken: " .. memory.readbyte(0xFF852E))
			gui.text(80,73, "Shinku Hadouken: " .. memory.readbyte(0xFF84EE))
			p1_projectile = true
		elseif memory.readbyte(0xFF87DF) == 0x09 then 
			--Sagat
			gui.text(2,65,"Tiger Shot: " .. memory.readbyte(0xFF84DA))
			gui.text(2,73,"Tiger Knee: " .. memory.readbyte(0xFF84D2))
			gui.text(2,81,"Tiger Uppercut: " .. memory.readbyte(0xFF84CE))
			gui.text(80,65, "Tiger Genocide: " .. memory.readbyte(0xFF84EC))
			p1_projectile = true
			return
		elseif memory.readbyte(0xFF87DF) == 0x0D then  
			--T.Hawk
			gui.text(2,65,"Mexican Typhoon: " .. memory.readbyte(0xFF84E0) .. ", " .. memory.readbyte(0xFF84E1))
			gui.text(2,73,"Tomahawk: " .. memory.readbyte(0xFF84DB))
			gui.text(2,81,"Double Typhoon: " .. memory.readbyte(0xFF84E0) .. ", " .. memory.readbyte(0xFF84ED))
			p1_projectile = false
			return
		elseif memory.readbyte(0xFF87DF) == 0x0B then 
			--Claw
			gui.text(2,65,"Wall Dive (Kick): " .. memory.readbyte(0xFF84DA))
			gui.text(2,73,"Wall Dive (Punch): " .. memory.readbyte(0xFF84DE))
			gui.text(2,81,"Crystal Flash: " .. memory.readbyte(0xFF84D6))
			gui.text(90,65,"Flip Kick: " .. memory.readbyte(0xFF84EB))
			gui.text(90,73,"Rolling Izuna Drop: " .. memory.readbyte(0xFF84E7))
			p1_projectile = false
			return
		elseif memory.readbyte(0xFF87DF) == 0x06 then 
			--Zangief
			gui.text(2,65, "Bear Grab: " .. memory.readbyte(0xFF84E9) ..  ", " .. memory.readbyte(0xFF84EA))
			gui.text(2,73, "Spinning Pile Driver: " .. memory.readbyte(0xFF84CE) .. ", " .. memory.readbyte(0xFF84CF))
			gui.text(2,81, "Banishing Flat: " .. memory.readbyte(0xFF8501))
			gui.text(2,89, "Final Atomic Buster: " .. memory.readbyte(0xFF84FA) .. ", " .. memory.readbyte(0xFF84FB))
			p1_projectile = false
			return
		end
	else
		if memory.readbyte(0xFF8BDF) == 0x0A then
			--Balrog
			gui.text(230,65,"Ground Straight: " .. memory.readbyte(0xFF84CE+p2))
			gui.text(230,73,"Ground Upper: " ..memory.readbyte(0xFF84D6+p2))
			gui.text(230,81,"Straight: " .. memory.readbyte(0xFF852B+p2))
			gui.text(307,65,"Upper Dash: " .. memory.readbyte(0xFF8524+p2))
			gui.text(307,73,"Buffalo Headbutt: " .. memory.readbyte(0xFF850E+p2))
			gui.text(307,81,"Crazy Buffalo: " .. memory.readbyte(0xFF8522+p2))
			p2_projectile = false
			return
		elseif memory.readbyte(0xFF8BDF) == 0x02 then
			--Blanka
			gui.text(302,65,"Normal Roll: " .. memory.readbyte(0xFF8507+p2))
			gui.text(302,73,"Vertical Roll: " .. memory.readbyte(0xFF84FE+p2))
			gui.text(302,81,"Ground Shave Roll: " .. memory.readbyte(0xFF850F+p2))
			p2_projectile = false
			return
		elseif memory.readbyte(0xFF8BDF) == 0x0C then
			--Cammy
			gui.text(218,65,"Spin Knuckle: " .. memory.readbyte(0xFF84F0+p2))
			gui.text(218,73,"Cannon Spike: " .. memory.readbyte(0xFF84E0+p2))
			gui.text(218,81,"Spiral Arrow: " .. memory.readbyte(0xFF84E4+p2))
			gui.text(290,65,"Hooligan Combination: " .. memory.readbyte(0xFF84F7+p2))
			gui.text(290,73,"Spin Drive Smasher: " .. memory.readbyte(0xFF84F4+p2))
			p2_projectile = false
			return
		elseif memory.readbyte(0xFF8BDF) == 0x05 then
			--Chun Li
			gui.text(233,65,"Kikouken: " .. memory.readbyte(0xFF84CE+p2))
			gui.text(233,73,"Up Kicks: " .. memory.readbyte(0xFF8508+p2))
			gui.text(233,81,"Spinning Bird Kick: " .. memory.readbyte(0xFF84FE+p2))
			gui.text(313,65,"Senretsu Kyaku: " .. memory.readbyte(0xFF850D+p2))
			p2_projectile = true
			return
		elseif memory.readbyte(0xFF8BDF) == 0x0F then
			--Dee Jay
			gui.text(223,65,"Air Slasher: " .. memory.readbyte(0xFF84E0+p2))
			gui.text(223,73,"Sovat Kick: " .. memory.readbyte(0xFF84F4+p2))
			gui.text(223,81,"Jack Knife: " .. memory.readbyte(0xFF84E4+p2))
			gui.text(303,65,"Machine Gun Upper: " .. memory.readbyte(0xFF84F9+p2))
			gui.text(303,73,"Sovat Carnival: " .. memory.readbyte(0xFF84FD+p2))
			p2_projectile = true
			return
		elseif memory.readbyte(0xFF8BDF) == 0x07 then  
			--Dhalsim
			gui.text(223,65,"Yoga Blast: " .. memory.readbyte(0xFF84D2+p2))
			gui.text(223,73,"Yoga Flame: " .. memory.readbyte(0xFF84E8+p2))
			gui.text(223,81,"Yoga Fire: " .. memory.readbyte(0xFF84CE+p2))
			gui.text(303,65,"Yoga Teleport: ".. memory.readbyte(0xFF84D6+p2))
			gui.text(303,73,"Yoga Inferno: " .. memory.readbyte(0xFF84E4+p2))
			p2_projectile = true
			return
		elseif memory.readbyte(0xFF8BDF) == 0x01 then
			--Honda
			gui.text(223,65,"Flying Headbutt: " .. memory.readbyte(0xFF84D6+p2))
			gui.text(223,73,"Butt Drop: " .. memory.readbyte(0xFF84DE+p2))
			gui.text(223,81,"Oichio Throw: " .. memory.readbyte(0xFF84E4+p2))
			gui.text(303,65, "Double Headbutt: " .. memory.readbyte(0xFF84E2+p2))
			p2_projectile = false
			return
		elseif memory.readbyte(0xFF8BDF) == 0x0E then
			--Fei Long
			gui.text(242,65,"Rekka: " .. memory.readbyte(0xFF84DE+p2))
			gui.text(242,73,"Rekka 2: "	.. memory.readbyte(0xFF84EE+p2))
			gui.text(242,81,"Flame Kick: " .. memory.readbyte(0xFF84E2+p2))
			gui.text(322,65, "Chicken Wing: " .. memory.readbyte(0xFF8502+p2))
			gui.text(322,73, "Rekka Sinken: " .. memory.readbyte(0xFF84FE+p2))
			p2_projectile = false
			return
		elseif memory.readbyte(0xFF8BDF) == 0x03 then 
			--Guile
			gui.text(302,65,"Sonic Boom: " .. memory.readbyte(0xFF84CE+p2))
			gui.text(302,73,"Flash Kick: " .. memory.readbyte(0xFF84D4+p2))
			gui.text(302,81,"Double Somersault: " .. memory.readbyte(0xFF84E2+p2))
			p2_projectile = true
			return
		elseif memory.readbyte(0xFF8BDF) == 0x04 then 
			--Ken
			gui.text(223,65, "Hadouken: " .. memory.readbyte(0xFF84E2+p2))
			gui.text(223,73, "Shoryuken: " .. memory.readbyte(0xFF84E6+p2))
			gui.text(223,81, "Hurricane Kick: " .. memory.readbyte(0xFF84DE+p2))
			gui.text(322,65, "Crazy Kick 1: " .. memory.readbyte(0xFF8534+p2))
			gui.text(322,73, "Crazy Kick 2: " .. memory.readbyte(0xFF8536+p2))
			gui.text(322,81, "Crazy Kick 3: " .. memory.readbyte(0xFF8538+p2))
			gui.text(272,89, "Shoryureppa: " .. memory.readbyte(0xFF84EE+p2))
			p2_projectile = true
			return
		elseif memory.readbyte(0xFF8BDF) == 0x08 then 
			--Dictator
			gui.text(217,65,"Scissor Kick: " .. memory.readbyte(0xFF84D6+p2))
			gui.text(217,73,"Headstomp: " .. memory.readbyte(0xFF84DF+p2))
			gui.text(217,81,"Devil's Reverse: " .. memory.readbyte(0xFF84FA+p2))
			gui.text(290,65,"Psycho Crusher: " .. memory.readbyte(0xFF84CE+p2))
			gui.text(290,73,"Knee Press Nightmare: " .. memory.readbyte(0xFF8513+p2))
			p2_projectile = false
			return
		elseif memory.readbyte(0xFF8BDF) == 0x00 then 
			--Ryu
			gui.text(210,65,"Hadouken: " .. memory.readbyte(0xFF84E2+p2))
			gui.text(210,73,"Shoryuken: " .. memory.readbyte(0xFF84E6+p2))
			gui.text(210,81, "Hurricane Kick: " .. memory.readbyte(0xFF84DE+p2))
			gui.text(310,65, "Red Hadouken: " .. memory.readbyte(0xFF852E+p2))
			gui.text(310,73, "Shinku Hadouken: " .. memory.readbyte(0xFF84EE+p2))
			p2_projectile = true
			return
		elseif memory.readbyte(0xFF8BDF) == 0x09 then 
			--Sagat
			gui.text(214,65,"Tiger Shot: " .. memory.readbyte(0xFF84DA+p2))
			gui.text(214,73,"Tiger Knee: " .. memory.readbyte(0xFF84D2+p2))
			gui.text(214,81,"Tiger Uppercut: " .. memory.readbyte(0xFF84CE+p2))
			gui.text(314,65, "Tiger Genocide: " .. memory.readbyte(0xFF84EC+p2))
			p2_projectile = true
			return
		elseif memory.readbyte(0xFF8BDF) == 0x0D then 
			--T.Hawk
			gui.text(294,65,"Mexican Typhoon: " .. memory.readbyte(0xFF84E0+p2) .. ", " .. memory.readbyte(0xFF84E1+p2))
			gui.text(294,73,"Tomahawk: " .. memory.readbyte(0xFF84DB+p2))
			gui.text(294,81,"Double Typhoon: " .. memory.readbyte(0xFF84E0+p2) .. ", " .. memory.readbyte(0xFF84ED+p2))
			p2_projectile = false
			return
		elseif memory.readbyte(0xFF8BDF) == 0x0B then 
			--Claw
			gui.text(210,65,"Wall Dive (Kick): " .. memory.readbyte(0xFF84DA+p2))
			gui.text(210,73,"Wall Dive (Punch): " .. memory.readbyte(0xFF84DE+p2))
			gui.text(210,81,"Crystal Flash: " .. memory.readbyte(0xFF84D6+p2))
			gui.text(298,65,"Flip Kick: " .. memory.readbyte(0xFF84EB+p2))
			gui.text(298,73,"Rolling Izuna Drop: " .. memory.readbyte(0xFF84E7+p2))
			p2_projectile = false
			return
		elseif memory.readbyte(0xFF8BDF) == 0x06 then 
			--Zangief
			gui.text(275,65, "Bear Grab: " .. memory.readbyte(0xFF84E9+p2) ..  ", " .. memory.readbyte(0xFF84EA+p2))
			gui.text(275,73, "Spinning Pile Driver: " .. memory.readbyte(0xFF84CE+p2) .. ", " .. memory.readbyte(0xFF84CF+p2))
			gui.text(275,81, "Banishing Flat: " .. memory.readbyte(0xFF8501+p2))
			gui.text(275,89, "Final Atomic Buster: " .. memory.readbyte(0xFF84FA+p2) .. ", " .. memory.readbyte(0xFF84FB+p2))
			p2_projectile = false
			return
		end
	end
end

local function fskip()
	if frameskip == true	then
		memory.writebyte(0xFF8CD3,0x70)
	else
		memory.writebyte(0xFF8CD3,0xFF)
	end
end

----------------------------------------------------------------------------------------------------
--Dizzy meters
----------------------------------------------------------------------------------------------------

--Determine the color of the bar based on the value (higher = darker)
local function diz_col(val,type)
	local color = 0x00000000
	
	if type == 0 then
		if val <= 5.66 then
			color = 0x00FF5DA0
			return color
		elseif val > 5.66 and val <= 11.22 then
			color = 0x54FF00A0
			return color
		elseif val > 11.22 and val <= 16.88 then
			color = 0xAEFF00A0
			return color
		elseif val > 16.88 and val <= 22.44 then
			color = 0xFAFF00A0
			return color
		elseif val > 22.4 and val <= 28.04 then
			color = 0xFF5400A0
			return color
		elseif val > 28.04 then
			color = 0xFF0026A0
			return color
		end
	else
		if val <= 10922.5 then
			color = 0x00FF5DA0
			return color
		elseif val > 10922.5 and val <= 21845 then
			color = 0x54FF00A0
			return color
		elseif val > 21845 and val <= 32767.5 then
			color = 0xAEFF00A0
			return color
		elseif val > 32767.5 and val <= 43690 then
			color = 0xFAFF00A0
			return color
		elseif val > 43690 and val <= 54612.5 then
			color = 0xFF5400A0
			return color
		elseif val > 54612.5 then
			color = 0xFF0026A0
			return color
		end
	end
end

local function draw_dizzy()

	local p1_s = memory.readbyte(0xFF84AD)
	local p1_c = memory.readword(0xFF84AB)
	local p1_d = memory.readword(0xFF84AE)
	local p1_f = memory.readword(0xFF863E)
	
	local p2_s = memory.readbyte(0xFF88AD)
	local p2_c = memory.readword(0xFF88AB)
	local p2_d = memory.readword(0xFF88AE)
	local p2_f = memory.readbyte(0xFF8A3E)
	
	-- P1 Stun meter
	if p1_s > 0 then
		if p1_s <= 10 then
			gui.box(35,45,(35+(3.38 * p1_s)),49,diz_col(p1_s,0),0x000000FF)
		elseif p1_s > 10 and p1_s <= 20 then
			gui.box(35,45,(35+(3.38 * p1_s)),49,diz_col(p1_s,0),0x000000FF)
		elseif p1_s > 20 then
			gui.box(35,45,(35+(3.38 * p1_s)),49,diz_col(p1_s,0),0x000000FF)
		end
	end
	
	-- P1 Stun counter
	if p1_c > 0 then
		if p1_c <= 70 then
			gui.box(35,49,(35+(0.001754 * p1_c)),53,diz_col(p1_c,1),0x000000FF)
		elseif p1_c > 70 and p1_c <= 150 then
			gui.box(35,49,(35+(0.001754* p1_c)),53,diz_col(p1_c,1),0x000000FF)
		elseif p1_c > 150 then
			gui.box(35,49,(35+(0.001754 * p1_c)),53,diz_col(p1_c,1),0x000000FF)
		end
	end
	
	-- P2 Stun meter
	if p2_s > 0 then
		if p2_s <= 10 then
			gui.box(233,45,(233+(3.38 * p2_s)),49,diz_col(p2_s,0),0x000000FF)
		elseif p2_s > 10 and p2_s <= 20 then
			gui.box(233,45,(233+(3.38 * p2_s)),49,diz_col(p2_s,0),0x000000FF)
		elseif p2_s > 20 then
			gui.box(233,45,(233+(3.38 * p2_s)),49,diz_col(p2_s,0),0x000000FF)
		end
	end
	
	-- P2 Stun counter
	if p2_c > 0 then
		if p2_c <= 70 then
			gui.box(233,49,(233+(0.001754 * p2_c)),53,diz_col(p2_c,1),0x000000FF)
		elseif p2_c > 70 and p2_c <= 150 then
			gui.box(233,49,(233+(0.001754 * p2_c)),53,diz_col(p2_c,1),0x000000FF)
		elseif p2_c > 150 then
			gui.box(233,49,(233+(0.001754 * p2_c)),53,diz_col(p2_c,1),0x000000FF)
		end
	end
	
	if p1_f > 0 then
		gui.box(3,100,11,190,0x00000040,0x000000FF)
		gui.box(3,190,11,(190 - (0.428 * p1_d)),0xFF0000B0,0x00000000)
		gui.text(3,192,p1_d)
	end
	

	if p2_f > 0 then
		gui.box(370,100,378,190,0x00000040,0x000000FF)
		gui.box(370,190,378,(190 - (0.428 * p2_d)),0xFF0000B0,0x00000000)
		gui.text(365,192,p2_d)
	end
	
end

----------------------------------------------------------------------------------------------------
--Grab meters
----------------------------------------------------------------------------------------------------

local function draw_grab(player,p1_char,p2_char,p_gc)

local p_a = 0
local p1_hg = memory.readbyte(0xFF84CD)
local p2_hg = memory.readbyte(0xFF88CD)

	if player == 0 then
	
		-- Draw the grab speed meter
		
		if p1_hg == 0x15 then
			gui.box(16,190,22,180,0xFF0C00C0,0x000000FF)
			gui.text(18,182,"1")
		elseif p1_hg == 0x12 then
			gui.box(16,190,22,170,0xFF0C00C0,0x000000FF)
			gui.text(18,172,"2")
		elseif p1_hg == 0x0F then
			gui.box(16,190,22,160,0xFF0C00C0,0x000000FF)
			gui.text(18,162,"3")
		elseif p1_hg == 0x0C then
			gui.box(16,190,22,150,0xFF0C00C0,0x000000FF)
			gui.text(18,152,"4")
		elseif p1_hg == 0x09 then
			gui.box(16,190,22,140,0xFF0C00C0,0x000000FF)
			gui.text(18,142,"5")
		elseif p1_hg == 0x06 then
			gui.box(16,190,22,130,0xFF0C00C0,0x000000FF)
			gui.text(18,132,"6")
		elseif p1_hg == 0x03 then
			gui.box(16,190,22,120,0xFF0C00FF,0x000000FF)
			gui.text(18,122,"7")
		end
		
		
		gui.box(16,120,22,190,0x00000040,0x000000FF)
		gui.line(16,130,22,130,0x000000FF,0x000000FF)
		gui.line(16,140,22,140,0x000000FF,0x000000FF)
		gui.line(16,150,22,150,0x000000FF,0x000000FF)
		gui.line(16,160,22,160,0x000000FF,0x000000FF)
		gui.line(16,170,22,170,0x000000FF,0x000000FF)
		gui.line(16,180,22,180,0x000000FF,0x000000FF)


		if p1_char == 0x04 or p1_char == 0x0D then
		--Ken thawk
		p_a = (90 / 120)
		gui.box(3,100,11,190,0x00000040,0x000000FF)
		gui.box(370,100,378,190,0x00000040,0x000000FF)
		gui.box(3,190,11,190 - (p_a * memory.readbyte(p_gc)),0xFFFF00B0,0x00000000)
		gui.box(370,190,378,190 - ((90 / 63) * memory.readbyte(0xFF88CB)),0xFF0000B0,0x00000000)
		gui.text(363,192,memory.readbyte(0xFF88CB) .. "/" .. "63")
		gui.text(1,192,memory.readbyte(p_gc) .. "/" .. "120")
		elseif p1_char == 0x02 or p1_char == 0x01 then
		--Blanka E.Honda
		p_a = (90 / 130)
		gui.box(3,100,11,190,0x00000040,0x000000FF)
		gui.box(370,100,378,190,0x00000040,0x000000FF)
		gui.box(3,190,11,190 - (p_a * memory.readbyte(p_gc)),0xFFFF00B0,0x00000000)
		gui.box(370,190,378,190 - ((90 / 63) * memory.readbyte(0xFF88CB)),0xFF0000B0,0x00000000)
		gui.text(363,192,memory.readbyte(0xFF88CB) .. "/" .. "63")
		gui.text(1,192,memory.readbyte(p_gc) .. "/" .. "130")
		elseif p1_char == 0x06 or p1_char == 0x07 then
		--Dhalsim Zangief
		p_a = (90 / 180)
		gui.box(3,100,11,190,0x00000040,0x000000FF)
		gui.box(370,100,378,190,0x00000040,0x000000FF)
		gui.box(3,190,11,190 - (p_a * memory.readbyte(p_gc)),0xFFFF00B0,0x00000000)
		gui.box(370,190,378,190 - ((90 / 63) * memory.readbyte(0xFF88CB)),0xFF0000B0,0x00000000)
		gui.text(363,192,memory.readbyte(0xFF88CB) .. "/" .. "63")
		gui.text(1,192,memory.readbyte(p_gc) .. "/" .. "180")
		elseif p1_char == 0x0A then
		--Boxer
		p_a = (90 / 210)
		gui.box(3,100,11,190,0x00000040,0x000000FF)
		gui.box(370,100,378,190,0x00000040,0x000000FF)
		gui.box(3,190,11,190 - (p_a * memory.readbyte(p_gc)),0xFFFF00B0,0x00000000)
		gui.box(370,190,378,190 - ((90 / 63) * memory.readbyte(0xFF88CB)),0xFF0000B0,0x00000000)
		gui.text(363,192,memory.readbyte(0xFF88CB) .. "/" .. "63")
		gui.text(1,192,memory.readbyte(p_gc) .. "/" .. "210")
		end
		
	else
	
		-- Draw grab speed
		
		if p2_hg == 0x15 then
			gui.box(357,190,363,180,0xFF0C00C0,0x000000FF)
			gui.text(359,182,"1")
		elseif p2_hg == 0x12 then
			gui.box(357,190,363,170,0xFF0C00C0,0x000000FF)
			gui.text(359,172,"2")
		elseif p2_hg == 0x0F then
			gui.box(357,190,363,160,0xFF0C00C0,0x000000FF)
			gui.text(359,162,"3")
		elseif p2_hg == 0x0C then
			gui.box(357,190,363,150,0xFF0C00C0,0x000000FF)
			gui.text(359,152,"4")
		elseif p2_hg == 0x09 then
			gui.box(357,190,363,140,0xFF0C00C0,0x000000FF)
			gui.text(359,142,"5")
		elseif p2_hg == 0x06 then
			gui.box(357,190,363,130,0xFF0C00C0,0x000000FF)
			gui.text(359,132,"6")
		elseif p2_hg == 0x03 then
			gui.box(357,190,363,120,0xFF0C00C0,0x000000FF)
			gui.text(359,122,"7")
		end
		
		
		gui.box(357,190,363,120,0x00000040,0x000000FF)
		gui.line(357,130,363,130,0x000000FF,0x000000FF)
		gui.line(357,140,363,140,0x000000FF,0x000000FF)
		gui.line(357,150,363,150,0x000000FF,0x000000FF)
		gui.line(357,160,363,160,0x000000FF,0x000000FF)
		gui.line(357,170,363,170,0x000000FF,0x000000FF)
		gui.line(357,180,363,180,0x000000FF,0x000000FF)
		if p2_char == 0x04 or p2_char == 0x0D then
		--Ken thawk
		p_a = (90 / 120)
		gui.box(3,100,11,190,0x00000040,0x000000FF)
		gui.box(370,100,378,190,0x00000040,0x000000FF)
		gui.box(370,190,378,190 - (p_a * memory.readbyte(p_gc)),0xFFFF00B0,0x00000000)
		gui.box(3,190,11,190 - ((90 / 63) * memory.readbyte(0xFF84CB)),0xFF0000B0,0x00000000)
		gui.text(1,192,memory.readbyte(0xFF84CB) .. "/" .. "63")
		gui.text(355,192,memory.readbyte(p_gc) .. "/" .. "120")
		elseif p2_char == 0x02 or p2_char == 0x01 then
		--Blanka E.Honda
		p_a = (90 / 130)
		gui.box(3,100,11,190,0x00000040,0x000000FF)
		gui.box(370,100,378,190,0x00000040,0x000000FF)
		gui.box(370,190,378,190 - (p_a * memory.readbyte(p_gc)),0xFFFF00B0,0x00000000)
		gui.box(3,190,11,190 - ((90 / 63) * memory.readbyte(0xFF84CB)),0xFF0000B0,0x00000000)
		gui.text(1,192,memory.readbyte(0xFF84CB) .. "/" .. "63")
		gui.text(355,192,memory.readbyte(p_gc) .. "/" .. "130")
		elseif p2_char == 0x06 or p2_char == 0x07 then
		--Dhalsim Zangief
		p_a = (90 / 180)
		gui.box(3,100,11,190,0x00000040,0x000000FF)
		gui.box(370,100,378,190,0x00000040,0x000000FF)
		gui.box(370,190,378,190 - (p_a * memory.readbyte(p_gc)),0xFFFF00B0,0x00000000)
		gui.box(3,190,11,190 - ((90 / 63) * memory.readbyte(0xFF84CB)),0xFF0000B0,0x00000000)
		gui.text(1,192,memory.readbyte(0xFF84CB) .. "/" .. "63")
		gui.text(355,192,memory.readbyte(p_gc) .. "/" .. "180")
		elseif p2_char == 0x0A then
		--Boxer
		p_a = (90 / 210)
		gui.box(3,100,11,190,0x00000040,0x000000FF)
		gui.box(370,100,378,190,0x00000040,0x000000FF)
		gui.box(370,190,378,190 - (p_a * memory.readbyte(p_gc)),0xFFFF00A0,0x00000000)
		gui.box(3,190,11,190 - ((90 / 63) * memory.readbyte(0xFF84CB)),0xFF0000B0,0x00000000)
		gui.text(1,192,memory.readbyte(0xFF84CB) .. "/" .. "63")
		gui.text(355,192,memory.readbyte(p_gc) .. "/" .. "210")
		end
	end

end

local function check_grab()

local p1_c = memory.readbyte(0xFF87DF) -- P1 Character
local p1_gc = 0 -- P1 Grab counter
local p1_gb = memory.readbyte(0xFF84CB) -- P1 Grab Break
local p1_gf = memory.readbyte(0xFF85CE) -- P1 Grab flag
local p1_tf = memory.readbyte(0xFF84B1) -- P1 Throw Flag
 
local p2_c = memory.readbyte(0xFF8BDF) -- P2 Character
local p2_gc = 0 -- P1 Grab counter
local p2_gb = memory.readbyte(0xFF88CB) -- P2 Grab Break
local p2_gf = memory.readbyte(0xFF89CE) -- P2 Throw flag
local p2_tf = memory.readbyte(0xFF88B1) -- P2 Throw Flag

	if p1_c == 0x01 or p1_c == 0x02 or p1_c == 0x04 or p1_c == 0x06 or p1_c == 0x07 or p1_c == 0x0A or p1_c == 0x0D then
		if p1_c == 0x01  or p1_c == 0x02 or p1_c == 0x04 or p1_c == 0x07 or p1_c == 0x0D then -- Blanka, Dhalsim, E.Honda, Ken, T.Hawk
			if p1_c == 0x07 then
				p1_gv = 0x06
			end
			p1_gc = 0xFF846C
		elseif p1_c == 0x06 then -- Gief
			p1_gc = 0xFF84D7
		elseif p1_c == 0x0A then -- Boxer
			p1_gc = 0xFF84E3
		end
		
		if p2_tf == 0xFF then
			if p1_c == 0x04 or p1_c == 0x02 then -- Check ken and Blanka
				if p1_gf == 0x07 then
					draw_grab(0,p1_c,p2_c,p1_gc)
				end
			elseif p1_c == 0x01 then -- Check Honda
				if p1_gf == 0x07 or p1_gf == 0x04 then
					draw_grab(0,p1_c,p2_c,p1_gc)
				end
			elseif p1_c == 0x07 then  -- Check Dhalsim
				if p1_gf == 0x06 then
					draw_grab(0,p1_c,p2_c,p1_gc)
				end
			elseif p1_c == 0x0A then -- Check Balrog
				if p1_gf == 0x06 or p1_gf == 0x05 then
					draw_grab(0,p1_c,p2_c,p1_gc)
				end
			elseif p1_c == 0x0D then -- Check Hawk
				if p1_gf == 0x06 or p1_gf == 0x07 then
					draw_grab(0,p1_c,p2_c,p1_gc)
				end
			elseif p1_c == 0x06 then -- Check Zangief
				if p1_gf == 0x05 or p1_gf == 0x06 or p1_gf == 0x03 then
					draw_grab(0,p1_c,p2_c,p1_gc)
				end
			end
		end
		
	--	if p1_gf == p1_gv and p2_tf == 0xFF then
			
	--		draw_grab(0,p1_c,p2_c,p1_gc)
	--	end
	end
	
	if p2_c == 0x01 or p2_c == 0x02 or p2_c == 0x04 or p2_c == 0x06 or p2_c == 0x07 or p2_c == 0x0A or p2_c == 0x0D then
		if p2_c == 0x01  or p2_c == 0x02 or p2_c == 0x04 or p2_c == 0x07 or p2_c == 0x0D then  -- Blanka, Dhalsim, E.Honda, Ken, T.Hawk
			p2_gc = 0xFF886C
		elseif p2_c == 0x06 then -- Gief
			p2_gc = 0xFF88D7
		elseif p2_c == 0x0A then -- Boxer
			p2_gc = 0xFF88E3
		end
		
		if p1_tf == 0xFF then
			if p2_c == 0x04 or p2_c == 0x02 then -- Check ken and Blanka
				if p2_gf == 0x07 then
					draw_grab(1,p1_c,p2_c,p2_gc)
				end
			elseif p2_c == 0x01 then -- Check Honda
				if p2_gf == 0x07 or p2_gf == 0x04 then
					draw_grab(1,p1_c,p2_c,p2_gc)
				end
			elseif p2_c == 0x07 then  -- Check Dhalsim
				if p2_gf == 0x06 then
					draw_grab(1,p1_c,p2_c,p2_gc)
				end
			elseif p2_c == 0x0A then -- Check Balrog
				if p2_gf == 0x06 or p2_gf == 0x05 then
					draw_grab(1,p1_c,p2_c,p2_gc)
				end
			elseif p2_c == 0x0D then -- Check Hawk
				if p2_gf == 0x06 or p2_gf == 0x07 then
					draw_grab(1,p1_c,p2_c,p2_gc) 
				end
			elseif p2_c == 0x06 then -- Check Zangief
				if p2_gf == 0x05 or p2_gf == 0x06 or p2_gf == 0x03 then
					draw_grab(1,p1_c,p2_c,p2_gc)
				end
			end
		end
			
				
	--	if p2_gf == p2_gv and p1_tf == 0xFF  then
		--	draw_grab(1,p1_c,p2_c,p2_gc)
		--end
	end
end

----------------------------------------------------------------------------------------------------
--Draw HUD
----------------------------------------------------------------------------------------------------

local function render_st_hud()

	in_match = memory.readword(0xFF847F)
	
	if in_match == 0 then
		return
	end
	
		if draw_hud > 0 then
			--Universal
			gui.text(153,12,"Distance X/Y: " .. calc_range()) 
			--P1
			gui.text(6,16,"X/Y: ") 
			gui.text(2,24,memory.readword(0xFF8454) .. "," .. memory.readword(0xFF8458))
			gui.text(35,22,"Life: " .. memory.readbyte(0xFF8479))
			gui.text(154,41,memory.readbyte(0xFF84AD) .. "/34")
			gui.text(154,50,memory.readword(0xFF84AB))
			gui.box(35,45,150,49,0x00000040,0x000000FF)
			gui.box(35,49,150,53,0x00000040,0x000000FF)
			gui.line(136,45,136,49,0x000000FF)
			gui.text(22,206,"Super: " .. memory.readbyte(0xFF8702))
			gui.text(6,216,"Special/Super Cancel: " .. check_cancel(1))
			--P2
			gui.text(363,16,"X/Y: ")
			gui.text(356,24,memory.readword(0xFF8854) .. "," .. memory.readword(0xFF8858))
			gui.text(314,22,"Life: " .. memory.readbyte(0xFF8879))
			gui.text(212,41,memory.readbyte(0xFF88AD) .. "/34")
			gui.text(212,50,memory.readword(0xFF88AB))
			gui.box(233,45,348,49,0x00000040,0x000000FF)
			gui.box(233,49,348,53,0x00000040,0x000000FF)
			gui.line(334,45,334,49,0x000000FF)
			gui.text(327,206,"Super: " .. memory.readbyte(0xFF8B02))
			gui.text(255,216,"Special/Super Cancel: " .. check_cancel(2))
			
			-- Character specific HUD
			if draw_hud == 2 then
				determine_char(1)
				determine_char(2)
			end 
			if p1_projectile == true then
				gui.text(34,56,"Projectile: " .. projectile_onscreen(0))
			end
			if p2_projectile == true then
				gui.text(266,56,"Projectile: " .. projectile_onscreen(1))
			end
			draw_dizzy()
			check_grab()
			fskip()
		end
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


png={}
png[1]="89504E470D0A1A0A0000000D4948445200000040000000200203000000DFF3961700000009504C5445000000FFFFFF00000073C683710000000174524E530040E6D8660000002449444154289163605AC0800A3813D00454B3D0944C0D252480A105C3500C6B47C1A0040033D007895CB63ACD0000000049454E44AE426082"
png[2]="89504E470D0A1A0A0000000D4948445200000040000000200203000000DFF3961700000009504C5445000000FFFFFF00000073C683710000000174524E530040E6D8660000002649444154289163605AC0800A9866A009AC9A86263035740101010C2D188662583B0A062500002EE5080D13A28F410000000049454E44AE426082"
png[3]="89504E470D0A1A0A0000000D4948445200000040000000200203000000DFF3961700000009504C5445000000FFFFFF00000073C683710000000174524E530040E6D8660000002949444154289163605AC0800A3823D00454C3D004A686A2E9591985268061068600D70A8651300400008A8706202173B2D70000000049454E44AE426082"
png[4]="89504E470D0A1A0A0000000D4948445200000040000000200203000000DFF3961700000009504C5445000000FFFFFF00000073C683710000000174524E530040E6D8660000002649444154289163E05AC1800A38230809AC8C5A802A3035144D40358C90194C683A46C1E004008E7206204B55C5510000000049454E44AE426082"
png[5]="89504E470D0A1A0A0000000D4948445200000040000000200203000000DFF3961700000009504C5445000000999999000000A55445040000000174524E530040E6D8660000002949444154289163D05AC1800AA646A00B24105231330C4D60D1D40568226A687C060E74815130180100A6950696CDA8F4A30000000049454E44AE426082"
png[6]="89504E470D0A1A0A0000000D4948445200000040000000200203000000DFF3961700000009504C5445000000999999000000A55445040000000174524E530040E6D8660000002A49444154289163E05AC5800A384317A00A304D5D4040856A249AC0D4243401B506345B381846C1500000E9B8074BC03E891B0000000049454E44AE426082"
png[7]="89504E470D0A1A0A0000000D4948445200000040000000200203000000DFF3961700000009504C5445000000999999000000A55445040000000174524E530040E6D866000000294944415428916360E06040036A68FC455317A00ACC0C43533135025D2081900AAD15E8D68E82C1080033C40696E5C0BC450000000049454E44AE426082"
png[8]="89504E470D0A1A0A0000000D4948445200000040000000200203000000DFF3961700000009504C5445000000999999000000A55445040000000174524E530040E6D8660000002A49444154289163E06040036A0D6802539316A00AA846A2097086A209304D25A4826B15BABDA36030020091CC074B27E0B0C80000000049454E44AE426082"
png[9]="89504E470D0A1A0A0000000D4948445200000040000000200203000000DFF3961700000009504C544500000000FFFF000000970228BD0000000174524E530040E6D8660000002549444154289163D05AB5800105A886A209A8AD24A802DD0CB5060602025AE802A360500200541E087E115994D60000000049454E44AE426082"
png[10]="89504E470D0A1A0A0000000D4948445200000040000000200203000000DFF3961700000009504C5445000000FFFF00000000ADC385800000000174524E530040E6D8660000002549444154289163D05AB5800105A886A209A8AD24A802DD0CB5060602025AE802A360500200541E087E115994D60000000049454E44AE426082"
png[11]="89504E470D0A1A0A0000000D4948445200000040000000200203000000DFF3961700000009504C5445000000FF000000000067A7420C0000000174524E530040E6D8660000002549444154289163D05AB5800105A886A209A8AD24A802DD0CB5060602025AE802A360500200541E087E115994D60000000049454E44AE426082"
png[12]="89504E470D0A1A0A0000000D4948445200000040000000200203000000DFF3961700000009504C544500000000FFFF000000970228BD0000000174524E530040E6D8660000002349444154289163D0EA6240056ACBD005A6A109A8461012C0D082612886B5A36050020047490573033E95880000000049454E44AE426082"
png[13]="89504E470D0A1A0A0000000D4948445200000040000000200203000000DFF3961700000009504C5445000000FFFF00000000ADC385800000000174524E530040E6D8660000002349444154289163D0EA6240056ACBD005A6A109A8461012C0D082612886B5A36050020047490573033E95880000000049454E44AE426082"
png[14]="89504E470D0A1A0A0000000D4948445200000040000000200203000000DFF3961700000009504C5445000000FF000000000067A7420C0000000174524E530040E6D8660000002349444154289163D0EA6240056ACBD005A6A109A8461012C0D082612886B5A36050020047490573033E95880000000049454E44AE426082"
png[15]="89504E470D0A1A0A0000000D4948445200000040000000200203000000DFF3961700000009504C54450000006600FF00000083CB03760000000174524E530040E6D8660000002149444154289163E05AC1800A54C3D004D408AAE05A464805A616744347C1A00400184404CF4B586E0D0000000049454E44AE426082"


buffersize   = 13     --how many lines to show
margin_left  = 0.4      --space from the left of the screen, in tiles, for player 1
margin_right = 7      --space from the right of the screen, in tiles, for player 2
margin_top   = 12      --space from the top of the screen, in tiles
timeout      = 45     --how many idle frames until old lines are cleared on the next input
screenwidth  = 256    --pixel width of the screen for spacing calculations (only applies if emu.screenwidth() is unavailable)
max_input	 = 999    --how long to hold input counter for
frameskip_address = 0xFF801D


----------------------------------------------------------------------------------------------------

gamekeys = {
	{ set =
		{ "capcom",            fba,       mame },
		{      "l",         "Left",     "Left" },
		{      "r",        "Right",    "Right" },
		{      "u",           "Up",       "Up" },
		{      "d",         "Down",     "Down" },
		{     "ul"},
		{     "ur"},
		{     "dl"},
		{     "dr"},
		{     "LP",   "Weak Punch", "Button 1" },
		{     "MP", "Medium Punch", "Button 2" },
		{     "HP", "Strong Punch", "Button 3" },
		{     "LK",    "Weak Kick", "Button 4" },
		{     "MK",  "Medium Kick", "Button 5" },
		{     "HK",  "Strong Kick", "Button 6" },
		{      "S",        "Start",    "Start" },
	},
}

local gd = require "gd"
local minimum_tile_size, maximum_tile_size = 8, 32
local icon_size  = minimum_tile_size
local thisframe, lastframe, module, keyset, changed = {}, {}
local margin, rescale_icons, recording, display, start, effective_width = {}, true, false
local draw = { [1] = true, [2] = true }
local allinputcounters  = { [1] =   {}, [2] =   {} }
local nullinputcounters = { [1] = {[1] = 0}, [2] = {[1] = 0}}  -- counters for null input for player 1 and player 2
local activeinputcounters = { [1] = {[1] = 0}, [2] = {[1] = 0}}  -- counters for active inputs player 1 and player 2
local idle = { [1] =    0, [2] =    0 }
local isplayernullinput = { [1] = true, [2] = true }

local frameskip_currval = 0
local frameskip_prevval = 0
local was_frameskip = false

for m, scheme in ipairs(gamekeys) do --Detect what set to use.
	if string.find("capcom", scheme.set[1]:lower()) then
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
if not module then error("There's no module available for capcom", 0) end
if not keyset then error("The '" .. module.set[1] .. "' module isn't prepared for this emulator.", 0) end

-- printing functions
function table_print (tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    local sb = {}
    for key, value in pairs (tt) do
      table.insert(sb, string.rep (" ", indent)) -- indent it
      if type (value) == "table" and not done [value] then
        done [value] = true
        table.insert(sb, key .. " = {\n");
        table.insert(sb, table_print (value, indent + 2, done))
        table.insert(sb, string.rep (" ", indent)) -- indent it
        table.insert(sb, "}\n");
      elseif "number" == type(key) then
        table.insert(sb, string.format("\"%s\"\n", tostring(value)))
      else
        table.insert(sb, string.format(
            "%s = \"%s\"\n", tostring (key), tostring(value)))
       end
    end
    return table.concat(sb)
  else
    return tt .. "\n"
  end
end

function to_string( tbl )
    if  "nil"       == type( tbl ) then
        return tostring(nil)
    elseif  "table" == type( tbl ) then
        return table_print(tbl)
    elseif  "string" == type( tbl ) then
        return tbl
    else
        return tostring(tbl)
    end
end
---

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
	gui.gdoverlay(x, y, img[row])
end

display = image

img={}
local function readimages()
	local scaled_width = icon_size
	if rescale_icons and emu.screenwidth and emu.screenheight then
		scaled_width = icon_size * emu.screenwidth()/emu.screenheight() / (4/3)
	end
	if display == image then
		for n, key in ipairs(module) do
			img[n] = gd.createFromPngStr(hexdump_to_string(png[n])):gdStr()
		end
	end
	effective_width = scaled_width
end
readimages()

----------------------------------------------------------------------------------------------------
-- update functions

local function filterinput(p, frame)
    isplayernullinput[p] = true
	for pressed, state in pairs(joypad.getdown(p)) do --Check current controller state >
		for row, name in pairs(module) do               --but ignore non-gameplay buttons.
			if pressed == name[keyset]
		--Arcade does not distinguish joypads, so inputs must be filtered by "P1" and "P2".
			or pressed == "P" .. p .. " " .. tostring(name[keyset])
		--MAME also has unusual names for the start buttons.
			or pressed == p .. (p == 1 and " Player " or " Players ") .. tostring(name[keyset]) then
				frame[row] = state
				isplayernullinput[p] = false
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
	if lastframe then                               -- zass: add check for full state change
		for key, state in pairs(lastframe) do       -- also check that a key last frame
			if thisframe and not thisframe[key] then  --that wasn't pressed this frame >
				changed = true                          --then changes were made.
				break
			end
		end
	end
end

-- updated by zass to show counters
local function updaterecords(player, frame, nullinputcounters, activeinputcounters)
--print("player = " .. player)
if allinputcounters == nil then
-- 	print("input was nil")
	allinputcounters = { [1] =   {}, [2] =   {} }
--	draw = { [1] = true, [2] = true }
else
	if allinputcounters[player] == nil then
--  	print("input player was nil")
		allinputcounters[player] = {}
--		draw = { [1] = true, [2] = true }
	end
end
-- print(to_string(allinputcounters))
 local input = allinputcounters[player]
-- print(to_string(input))

		if changed then                         --If changes were made >
			for record = buffersize, 2, -1 do
				if input ~= nil then
					input[record] = input[record-1]   --then shift every old record by 1 >
				end
				nullinputcounters[record] = nullinputcounters[record-1]   --then shift every old record by 1 >
				activeinputcounters[record] = activeinputcounters[record-1]   --then shift every old record by 1 >
			end

			idle[player] = 0                      --Reset the idle count >
				input[1] = {}                         --and set current input as record 1 >
		if isplayernullinput[player] == true then
			nullinputcounters[1] = 1;
			activeinputcounters[1] = 0;
			if was_frameskip then
				nullinputcounters[1] = 2;
				activeinputcounters[1] = 0;
			end
		else
			nullinputcounters[1] = 0;
			activeinputcounters[1] = 1;
			if was_frameskip then
				nullinputcounters[1] = 0;
				activeinputcounters[1] = 2;
			end

		end
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
		if idle[player] == nil then
			idle[player] = 0
		end
		idle[player] = idle[player]+1         --Increment the idle count if nothing changed.
		if isplayernullinput[player] == true then
			nullinputcounters[1] = nullinputcounters[1] + 1
			if nullinputcounters[1] > max_input then
				nullinputcounters[1] = max_input
			end
			if was_frameskip then             -- increment again if there was a frameskip
				nullinputcounters[1] = nullinputcounters[1] + 1
				if nullinputcounters[1] > max_input then
					nullinputcounters[1] = max_input
				end
			end
		else
			activeinputcounters[1] = activeinputcounters[1] + 1
			if activeinputcounters[1] > max_input then
				activeinputcounters[1] = max_input
			end
			if was_frameskip then
				activeinputcounters[1] = activeinputcounters[1] + 1
				if activeinputcounters[1] > max_input then
					activeinputcounters[1] = max_input
				end
			end
		end
	end
end

-- added by zass, increment counters if frameskip
local function checkframeskip()
	frameskip_prevval = frameskip_currval
	frameskip_currval = memory.readbyte(frameskip_address)
	local x = frameskip_currval - frameskip_prevval
	if x % 2 == 0 then
		was_frameskip = true
	else
		was_frameskip = false
	end
end

emu.registerafter(function()
	margin[1] = margin_left*effective_width
	margin[2] = (emu.screenwidth and emu.screenwidth() or screenwidth) - margin_right*effective_width
	margin[3] = margin_top*icon_size
	for player = 1, 2 do
		thisframe = {}
		if player == 1 then
			checkframeskip() -- only check frameskip once
		end
		filterinput(player, thisframe)
		compositeinput(thisframe)
		detectchanges(lastframe[player], thisframe)
		updaterecords(player, thisframe, nullinputcounters[player], activeinputcounters[player])
		lastframe[player] = thisframe

	end
end)


----------------------------------------------------------------------------------------------------
-- hotkey functions

local function toggleplayer()
	if not draw[1] and not draw[2] then
		draw[1] = true
		draw[2] = false
		print("> Input display: P1 on / P2 off")
	elseif draw[1] and not draw[2] then
		draw[1] = false
		draw[2] = true
		print("> Input display: P1 off / P2 on")
	elseif not draw[1] and draw[2] then
		draw[1] = true
		draw[2] = true
		print("> Input display: Both players on")
	elseif draw[1] and draw[2] then
		draw[1] = false
		draw[2] = false
		print("> Input display: Both players off")
	end
end

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
				--print("drawing " .. shortname .. " hitboxes")
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

training_mode = 0
input.registerhotkey(1, function()
	training_mode = training_mode + 1
	if training_mode > 2 then
		training_mode = 0
	end
	if training_mode == 0 then
		print("> Training mode Disabled")
	elseif training_mode == 1 then
		print("> Training mode Enabled: Dizzy OFF")
	elseif training_mode == 2 then
		print("> Training mode Enabled: Dizzy ON")
	end
	--training_enabled = not training_enabled
	-- print("> Training mode " .. (training_enabled and "ON" or "OFF"))

end)

input.registerhotkey(2, function()
	draw_hitboxes = not draw_hitboxes
	print((draw_hitboxes and "> Showing" or "> Hiding") .. " Hitboxes")
end)

input.registerhotkey(3, function()
	toggleplayer()
end)

input.registerhotkey(4, function()
	-- Toggle ST HUD
	if draw_hud == 0 then
		draw_hud = 1
		print("> HUD: Hiding special move displays")
	elseif draw_hud == 1 then
		draw_hud = 2
		print("> HUD: Showing full HUD")
	elseif draw_hud == 2 then
		draw_hud = 0
		print("> HUD: Hiding HUD")
	end
end)

input.registerhotkey(5, function()
	if stage_selector >= 0xf then
		stage_selector=-1
	end
	stage_selector = stage_selector + 1
	if stage_selector == 0 then
		print("> Stage: Japan (Ryu)")
	elseif stage_selector == 1 then
		print("> Stage: Japan (Honda)")
	elseif stage_selector == 2 then
		print("> Stage: Brazil (Blanka)")
	elseif stage_selector == 3 then
		print("> Stage: USA (Guile)")
	elseif stage_selector == 4 then
		print("> Stage: USA (Ken)")
	elseif stage_selector == 5 then
		print("> Stage: China (Chun-Li)")
	elseif stage_selector == 6 then
		print("> Stage: USSR (Zangief)")
	elseif stage_selector == 7 then
		print("> Stage: India (Dhalsim)")
	elseif stage_selector == 8 then
		print("> Stage: Thailand (Dictator)")
	elseif stage_selector == 9 then
		print("> Stage: Thailand (Sagat)")
	elseif stage_selector == 0xa then
		print("> Stage: USA (Boxer)")
	elseif stage_selector == 0xb then
		print("> Stage: Spain (Claw)")
	elseif stage_selector == 0xc then
		print("> Stage: England (Cammy)")
	elseif stage_selector == 0xd then
		print("> Stage: Mexico (T.Hawk)")
	elseif stage_selector == 0xe then
		print("> Stage: HongKong (Fei-Long)")
	elseif stage_selector == 0xf then
		print("> Stage: Jamaica (DeeJay)")
	else
		print("> Stage: ", stage_selector)
	end
end)

print("---------------------------------------------------------------------------------")
print("Lua Hotkey 1 (Alt+1): Toggle Training Mode on/off")
print("Lua Hotkey 2 (Alt+2): Display/Hide Hitboxes")
print("Lua Hotkey 3 (Alt+3): Display/Hide Scrolling Input")
print("Lua Hotkey 4 (Alt+4): Toggle HUD Display")
print("Lua Hotkey 5 (Alt+5): Toggle Background Stage Selector")
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

--		--Scrolling Input display
--		for player = 1, 2 do
--			if draw[player] then
--				for line in pairs(inp[player]) do
--					for index,row in pairs(inp[player][line]) do
--						display(margin[player] + (index-1)*effective_width, margin[3] + (line-1)*icon_size, row)
--					end
--				end
--			end
--		end

		--Scrolling Input display
		for player = 1, 2 do
--			print("inputd- player " .. player)
--			print("inputd- draw player " .. to_string(draw[player]))
			-- draw[player] = true -- hack for this going to nil after savestate
			if draw[player] then
			local i = 0
			local skip = 0
--							print ("going to draw player " .. player)
--							print(to_string(allinputcounters[player]))
				for line in pairs(allinputcounters[player]) do
				i = i + 1


-- if nullinputcounters is nill, set it to 0
--[[					if nullinputcounters[player][i] == nil then
						nullinputcounters[player][i] = 0
					end
					if nullinputcounters[player][i+1] == nil then
						nullinputcounters[player][i+1] = 0
					end
					if activeinputcounters[player][i] == nil then
						activeinputcounters[player][i] = 0
					end
--]]
-- if it's line 1 and input is null, just show nullinputs
-- if it's line 1 and input is active, show i-1 nullinputs, and activeinputs


					if nullinputcounters[player][i] > 0 and i == 1 then
						gui.text(margin[player] + effective_width - 10, margin[3] + (line-1)*icon_size, "" .. nullinputcounters[player][i], 0xAACCCCFF)
					elseif i == 1 then
						if nullinputcounters[player][i+1] and nullinputcounters[player][i+1] > 0 then
							gui.text(margin[player] + effective_width - 10, margin[3] + (line-1)*icon_size, "" .. nullinputcounters[player][i+1], 0xAACCCCFF)
						end
						gui.text(margin[player] + effective_width  + 5, margin[3] + (line-1)*icon_size, "" .. activeinputcounters[player][i])

-- if it's line 2 or higher
					elseif activeinputcounters[player][i] == 0 then
						skip = skip + 1 -- log a skip for an empty input
					else
						if nullinputcounters[player][i+1] and nullinputcounters[player][i+1] > 0 then
							gui.text(margin[player] + effective_width - 10, margin[3] + (line-1-skip)*icon_size, "" .. nullinputcounters[player][i+1], 0xAACCCCFF)
						end
						gui.text(margin[player] + effective_width  + 5, margin[3] + (line-1-skip)*icon_size, "" .. activeinputcounters[player][i], "yellow")
					end

-- if frameskip, draw something	- this is for debugging
--[[
					if was_frameskip == true then
						gui.text(margin[player] + effective_width + 50, margin[3] + (line-1-skip)*icon_size, "fs", "red")
					end
						gui.text(margin[player] + effective_width + 85, margin[3] + (line-1-skip)*icon_size, "" .. frameskip_currval, "blue")
						gui.text(margin[player] + effective_width + 105, margin[3] + (line-1-skip)*icon_size, "" .. frameskip_prevval, "orange")
]]
-- display inputs, skipping a line for every empty input.
					for index,row in pairs(allinputcounters[player][line]) do
						display(margin[player] + (index-1)*effective_width + 30, margin[3] + (line-1-skip)*icon_size, row)
					end


				end
			end
		end

		-- Training Script stuff
		pof_training_logic()

		toggle_background_stage()

		-- ST HUD
		render_st_hud()

	end)
	--Pause the script until the next frame
	emu.frameadvance()
end
