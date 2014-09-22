local texts = require('texts')

--[[
Display Class

Class to create and destroy text instances for each roll at every update.
Display Constructor expects a table of Settings and a table of Rolls.
]]

Display = {}

function Display:new(settings, rollList)
    local t = setmetatable({rollList = rollList}, self)
    self.dSettings = settings
	self.displayedObjects = {}
    self.__index = self

    return t
end

function Display:update_rolls(rollList)
	if rollList then
		self.rollList = rollList
		return true
	else
		return false
	end
end

-- Determine what rolls should be displayed and create text objects for each one
function Display:display_objects()
	local objectsToDisplay = {}
		
	for key,roll in pairs(self.rollList) do
		local text = ""	
		local bg_colors = default_bg
		local s = self.dSettings
		
		if not roll.rollExp and roll.rollTotalTargets:length()>0 then
			text = text..'  '.. roll.rollName .. ' '
			for key,rollInfo in pairs(roll.rollHistory) do
				if rollInfo.rollTargets:length()>0 then
					text = text..' '.. rollInfo.rollNum ..'  ('
					for player,__ in pairs(rollInfo.rollTargets) do
						text = text..' '.. player ..'  '
					end
					text = text..')  '
				end
			end
			
			-- If DoubleUp Chance has not expired, set bg color to alt color
			if roll.duChanceExp then
				bg_colors = default_bg
			else
				bg_colors = du_bg
			end
			
			-- Insert in table to be displayed
			table.insert(objectsToDisplay,{text=text,settings=s,rgb=bg_colors})
		end	
	end
	
	-- Iterate over table and create new text object for each roll
	for key,object in pairs(objectsToDisplay) do
		self.displayedObjects[key] = texts.new(object.text,object.settings.display,object.settings)
		
		self.displayedObjects[key]:pos_x(static_x)
		self.displayedObjects[key]:pos_y(initial_y+(20*key))
		self.displayedObjects[key]:visible(true)		
		self.displayedObjects[key]:bg_color(object.rgb[1],object.rgb[2],object.rgb[3])		
	end
end

-- Destroy all displayed objects
function Display:reset()
	for key,object in pairs(self.displayedObjects) do
		self.displayedObjects[key]:destroy()
	end
end

return Display

