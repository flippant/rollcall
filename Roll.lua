--[[
Roll Class

Roll Constructor expects a table of the roll's name (string), number (int), and targets (set)
Rolls save a table for each roll instance in Roll History. rollTargets inside this history are maintained so that names are not repeated 
		ex: { [1]={rollNum=3,rollTargets={Ejiin,Sudox}},[2]={rollNum=4,rollTargets={Flippant}} }
This makes it easier to display roll summaries
]]

Roll = {}

function Roll:new(o)
	o = o or {}
	
	initialTargets = S{}
	for player,__ in pairs(o.rollTargets) do
		initialTargets:add(player)
	end
    
    local attrs = {
		rollName = o.rollName,
        rollNum = o.rollNum,		
		rollTotalTargets = table.sort(o.rollTargets),
		rollHistory = { {rollNum=o.rollNum,rollTargets=initialTargets} }, --table to store rollsNums and rollTargets
		duChanceExp = false, --set to true once DU Chance wears
		rollExp = false --set to true when no rollTotalTargets left or forced to expire through method
    }
    o = attrs
    
    setmetatable(o, self)
    self.__index = self
	
    return o
end

function Roll:update_targets(t)
	for player,__ in pairs(t) do
		if not self.rollTotalTargets:contains(player) then
			self.rollTotalTargets:add(player)
		end
	end
	self.rollTotalTargets = table.sort(self.rollTotalTargets)
end

function Roll:du_exp()
    self.duChanceExp = true
end

function Roll:roll_exp()
    self.rollExp = true
end

function Roll:update_roll(n,t)
	if n>11 then -- roll is busted
		return
	end
	for player,__ in pairs(t) do
		self:remove_target(player)
	end
	table.insert(self.rollHistory,{rollNum=n,rollTargets=t})
	self:update_targets(t)
	self.rollNum = n
	-- for index,rollInstance in pairs(self.rollHistory) do
		-- windower.add_to_chat(140,'---'..index..'---')
		-- windower.add_to_chat(140,rollInstance.rollNum)
		-- for player,__ in pairs(rollInstance.rollTargets) do
			-- windower.add_to_chat(140,player)
		-- end
	-- end
end

function Roll:remove_target(p)
	-- remove player from all rollTarget tables in roll's history 
	for index,rollInstance in pairs(self.rollHistory) do
		set.remove(rollInstance.rollTargets,p)
		-- should be removing any instances in rollHistory that are empty
		-- if rollInstance.rollTargets:length()==0 then
			-- table.remove(self.rollHistory,index)
		-- end
	end
	-- remove player from totalTarget array
	set.remove(self.rollTotalTargets,p)	
end

function Roll:check_if_exp()
	if not self.rollTotalTargets then
		self:roll_exp()
	end
end


return Roll