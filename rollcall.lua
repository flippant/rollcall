_addon.name = 'Rollcall'
_addon.author = 'Flippant'
_addon.version = '1.0'
_addon.commands = {'rc', 'rollcall'}

require('tables')
require('strings')
require('actions')
require('sets')
res = require('resources')
config = require('config')

require('Roll')
local rolls = {}
currentRoll = nil
thisPlayer = windower.ffxi.get_player()

messageColor = 55

require('Display')

static_x = 800
initial_y = 510

local default_settings = {}
default_settings.numplayers = 8
default_settings.sbcolor = 204
default_settings.showallidps = true
default_settings.resetfilters = true
default_settings.visible = true
default_settings.UpdateFrequency = 0.5
default_settings.text = {}

default_settings.display = {}
default_settings.display.pos = {}
default_settings.display.pos.x = static_x
default_settings.display.pos.y = initial_y

default_settings.display.bg = {}
default_settings.display.bg.alpha = 200
default_settings.display.bg.red = 0
default_settings.display.bg.green = 0
default_settings.display.bg.blue = 0

default_settings.display.text = {}
default_settings.display.text.size = 8
default_settings.display.text.font = 'Arial'
default_settings.display.text.fonts = {}
default_settings.display.text.alpha = 255
default_settings.display.text.red = 255
default_settings.display.text.green = 255
default_settings.display.text.blue = 255

settings = default_settings
--settings = config.load(default_settings)

default_bg = {0,0,0}
du_bg = {0,0,150}
bust_bg = {150,150,150}
lucky_bg = {0,150,0}
unlucky_bg = {150,0,0}

local display = Display:new(settings,rolls)

windower.register_event('addon command', function()
    return function(command, ...)
		local params = {...}
        if command == 'r' then
            windower.send_command('lua reload rollcall')
            return
		elseif command == 'update' then
			update_display()
			windower.add_to_chat(messageColor,'Display has been updated.')
			return
		elseif command == 'exp' then
			if type(params[1]) ~= 'string' then
				windower.add_to_chat(messageColor,'Please provide roll in a string. Ex: Chaos Roll.')
			end
			if get_roll_by_name(params[1],false) then
				get_roll_by_name(params[1],false):roll_exp()
				windower.add_to_chat(messageColor,'Roll has been forcibly expired')
			end
			return
        end
	end
end())

windower.register_event('action', function(act)
    if act.category == 6 and act.actor_id == thisPlayer.id then
		if res.job_abilities[act.param].type=="CorsairRoll" then
			local rollName = res.job_abilities[act.param].en
			local rollNumber = act.targets[1].actions[1].param
			local party = windower.ffxi.get_party()
            local rollTargets = S{}
            for player in pairs(party) do
                for affectedTarget = 1, #act.targets do
                    if party[player].mob and act.targets[affectedTarget].id == party[player].mob.id then   
                        rollTargets:add(party[player].name)
                    end
                end
            end
			if currentRoll and currentRoll.rollName==rollName then
				update_roll(rollNumber,rollTargets)
			else
				create_roll(rollName,rollNumber,rollTargets)
			end
		end
	end
end)

-- Need to do more than just end current roll, also need to remove thisPlayer from all rolls
windower.register_event('zone change', function(new_id,old_id)
	end_roll()	
end)

windower.register_event('lose buff', function(buff_id)
	if buff_id == 308 then -- Losing DU
		end_roll()
	end
end)

-- Can't depend on gaining bust to know you've busted roll
-- windower.register_event('gain buff', function(buff_id)
	-- if buff_id == 309 then -- Gaining Bust
		-- bust_roll()
	-- end
-- end)

-- Must find a way to do this without having to parse chat...
windower.register_event('incoming text', function(text) 
	-- if roll wears off of a player remove them from roll table
	if string.find(text,"Roll effect wears off") then
		local explodedText = explode(" ",text)
		local explodedName = explode("'",explodedText[1])
		local rollName = explodedText[2].." Roll"
		local player = explodedName[1]
		remove_player_roll(rollName,player)	
	-- if roll is busted off of a player remove them from roll table
	elseif string.find(text,'loses the effect of') and string.find(text,'Roll.') then
		local explodedText = explode(" ",text)
		local rollName = explodedText[6].." Roll"
		local player = explodedText[1]		
		if player ~= thisPlayer.name then
			remove_player_roll(rollName,player)	
		else
			rollName = explodedText[8].." Roll"
			bust_roll(rollName)
		end		
	end
end)

-- Alternate method to parsing chat, but this does not work
-- windower.register_event('action_message', function(actor_id, target_id, actor_index, target_index, message_id, param_1, param_2, param_3) 
	-- print('action '..message_id)
	-- if actor_id==thisPlayer.id then
		-- print('me')
		-- if message_id==426 then
			-- print('bust')
		-- elseif message_id==206 then
			-- print('possibly roll wore off')
		-- end
	-- end
-- end)

-- Find the rolls by that name with that player in table, and remove them from target list (do I need to validate player in table? do I need to run backwards?)
function remove_player_roll(r,p)	
	for index=#rolls,1,-1 do
		if r == rolls[index].rollName and rolls[index].rollTotalTargets:contains(p) then
			rolls[index]:remove_target(p)
			--if no targets are left in the roll's total targets, roll should be expired
			rolls[index]:check_if_exp()
		end
	end
	update_display(rolls)
end

-- Find roll by name, 'latest' should be true if you want the latest roll, false if you want the oldest non-expired roll (false by default)
function get_roll_by_name(r,latest)
	if not latest then
		for i,roll in pairs(rolls) do
			if r==roll.rollName and not roll.rollExp then
				return roll
			end
		end
	else
		for index=#rolls,1,-1 do
			if r==roll.rollName then
				return roll
			end
		end
	end
	return false
end

-- Create new Roll object
function create_roll(r,n,t)
	for index,roll in pairs(rolls) do
		if not roll.duChanceExp then
			currentRoll:du_exp()
		end
	end
	currentRoll = Roll:new{rollName=r,rollNum=n,rollTargets=t}
	table.insert(rolls,currentRoll)	
	check_active_rolls()
	update_display()
end

-- Update Roll object with next instance of number and target table
function update_roll(n,t)
	if not currentRoll then
		return
	end
	currentRoll:update_roll(n,t)
	update_display()
end

-- Carry out events in case of busted roll (thisPlayer should be removed from table)
function bust_roll(r)
	remove_player_roll(r,thisPlayer.name)
	update_display()	
end

-- Carry out events in case of ended roll (DU chance has expired)
function end_roll()
	if not currentRoll then
		return
	end
	currentRoll:du_exp()
	currentRoll = nil
	update_display()
end

-- Expires roll (I don't need this?)
-- function kill_roll(roll)
	-- if roll then
		-- rolls:roll_exp()
	-- end
	-- update_display()
-- end

-- Check through roll table to find rolls that have been overwritten on other players (should only need to check when creating new roll)
function check_active_rolls()
	-- compile new array to store all targets and how many rolls they have
	local allTargets = {}
	-- traverse roll array backwards
	for index=#rolls,1,-1 do		
		if not rolls[index].rollExp then
			-- traverse each roll's player list and add them to allTargets array for each roll
			for player,__ in pairs(rolls[index].rollTotalTargets) do				
				if allTargets[player] then
					if not allTargets[player][rolls[index].rollName] then -- if roll has not already been counted, add roll to player's list
						allTargets[player].rolls = allTargets[player].rolls + 1
						allTargets[player][rolls[index].rollName] = true
					else -- if roll has already been counted, then must be an old roll and player should be removed
						rolls[index]:remove_target(player)
					end
				else
					allTargets[player] = {}
					allTargets[player].rolls = 1	
					allTargets[player][rolls[index].rollName] = true				
				end
				
				-- if player already has 2 rolls, then target should be deleted from extra rolls
				if allTargets[player].rolls > 2 then	
					rolls[index]:remove_target(player)
				end
				
				-- if no targets are left in the roll's total targets, roll should be expired
				rolls[index]:check_if_exp()
			end
		end
	end
end

-- Explode parse into array
function explode(delimiter,str)
	if (delimiter=='') then return false end
	local pos,arr = 0,{}
	for st,sp in function() return string.find(str,delimiter,pos,true) end do
		table.insert(arr,string.sub(str,pos,st-1))
		pos = sp + 1
	end
	table.insert(arr,string.sub(str,pos))
	return arr
end

-- Update Display object with Roll objects
function update_display()
	display:reset()
	display:update_rolls(rolls)
	display:display_objects()
end

-- I should clean rolls table and remove all expired rolls
function clean_rolls()
end