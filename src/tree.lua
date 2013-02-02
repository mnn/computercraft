-- tree chopper
-- by monnef

local slot_FUEL = 1
local slot_WOOD = 2
local slot_LEAVES = 3
local slot_SAPLINGS = 4

local importantSlots = {slot_FUEL, slot_LEAVES, slot_SAPLINGS, slot_WOOD}

local debug = true

local maxPos = { 16, 7, 7 }

local saveFile = "/tree_save"

-- END of settings
-- turtle must be in front of a chest with one block free above flood (so it's above saplings) facing from the chest
-- chest is also above saplings level
-- there is needed a border made of something not leaves|wood on a left and back side of a starting position of a turtle

-- border | chest     - level  0
-- sapling | torch    - level -1
-- floor              - level -2

-- map of sample configuration, X - wall, C - chest, T - turtle, " " - air/wood/leaves
-- XXXXXX
-- CT   X
-- C    X
-- XXXXXX

local state_SHUTTINGDOWN = -1
local state_WANDERING = 0
local state_CHOPPING = 1
local state_DESCENDING = 2
local state_WAITINGFORFUEL = 3

local myState = state_WANDERING

local relPos = { }
local dir = 0

local pX, pY, pZ = 1, 2, 3
relPos[pX] = 0
relPos[pY] = 0
relPos[pZ] = 0

local move_matrix = { {1, 0}, {0, 1}, {-1, 0}, {0, -1} }

local takesLeft = true
local goHome = false

-- ^ x
-- |
-- S --> y

-- 0 forw
-- 1 right
-- 2 back
-- 3 left

-- table functions
local function tableContains(table, element)
	for _, value in pairs(table) do
		if value == element then
			return true
		end
	end
	return false
end

local function tableCopy(t)
	local t2 = {}
	for k,v in pairs(t) do
		t2[k] = v
	end
	return t2
end
-- end of table functions

local function myToNumber(arg)
	if arg == nil then
		return nil
	else
		return tonumber(arg)
	end
end

local function loadStatus()
	local f = fs.open(saveFile ,"r")
	if f == nil then
		print("cannot load save file")
		return false
	end
	relPos[pX] = myToNumber(f.readLine())
	relPos[pY] = myToNumber(f.readLine())
	relPos[pZ] = myToNumber(f.readLine())
	dir = myToNumber(f.readLine())
	myState = myToNumber(f.readLine())
	if relPos[pX]==nil or relPos[pY]==nil or relPos[pZ]==nil or dir==nil or myState==nil then
		print("corrupted save")
		return false
	end
	f.close()
	return true
end

local function saveStatus()
	local f = fs.open(saveFile ,"w")
	if f == nil then
		print("cannot save status")
		return false
	end
	f.writeLine(relPos[pX])
	f.writeLine(relPos[pY])
	f.writeLine(relPos[pZ])
	f.writeLine(dir)
	f.writeLine(myState)
	f.close()
	return true
end

local function moveForwardPosition(position, direction)
	local cur_diff = move_matrix[direction + 1]
	position[pX] = position[pX] + cur_diff[1]
	position[pY] = position[pY] + cur_diff[2]
end

local function tw_move_forward()
	local ret = turtle.forward()
	if ret then
		moveForwardPosition(relPos, dir)
		saveStatus()
	end
	return ret
end

local function tw_fix_dir()
	if dir < 0 then dir = dir + 4 end
	dir = dir % 4
end

local function tw_turn_left()
	turtle.turnLeft()
	dir = dir - 1
	tw_fix_dir()
	saveStatus()
end

local function tw_turn_right()
	turtle.turnRight()
	dir = dir + 1
	tw_fix_dir()
	saveStatus()
end

local function tw_move_up()
	local ret = turtle.up()
	if ret then
		relPos[pZ] = relPos[pZ] + 1
	end
	saveStatus()
	return ret
end

local function tw_move_down()
	local ret = turtle.down()
	if ret then
		relPos[pZ] = relPos[pZ] - 1
	end
	saveStatus()
	return ret
end

local function checkSlots()
	if turtle.getItemCount(slot_FUEL) == 0 then return "fuel" end
	if turtle.getItemCount(slot_LEAVES) == 0 then return "leaves" end
	if turtle.getItemCount(slot_SAPLINGS) == 0 then return "saplings" end
	if turtle.getItemCount(slot_WOOD) == 0 then return "wood" end
	return true
end

local function isTree()
	turtle.select(slot_WOOD)
	return turtle.compare()
end

local function isTreeUp()
	turtle.select(slot_WOOD)
	return turtle.compareUp()
end

local function isTreeDown()
	turtle.select(slot_WOOD)
	return turtle.compareDown()
end

local function downFree()
	--	if not turtle.detectDown() then return true end
	--	turtle.select(slot_SAPLINGS)
	--	return turtle.compareDown()
	return not turtle.detectDown()
end

local function isChoppableAny(compareFunc)
	turtle.select(slot_WOOD)
	return compareFunc()
end

local function isChoppableDown()
	return isChoppableAny(turtle.compareDown)
end

local function isChoppableFront()
	return isChoppableAny(turtle.compare)
end

local function chop()
	turtle.digUp()
	tw_move_up()
end

local function safeToDig()
	if relPos[pZ] < 0 or relPos[pZ] >= maxPos[pZ] then return false end
	local digPos = tableCopy(relPos)
	moveForwardPosition(digPos, dir)
	if digPos[pX] < 0 or digPos[pX] >= maxPos[pX] then return false end
	if digPos[pY] < 0 or digPos[pY] >= maxPos[pY] then return false end

	return true
end

local nextTimeDoTurn = false

local function wander()
	if math.random(1,15) == 1 or nextTimeDoTurn then
		nextTimeDoTurn = false

		if math.random(1,30)== 1 then takesLeft = not takesLeft end

		local skipTurn = false
		if goHome and ( dir ~= 2 or dir ~=3 ) then
			if dir == 0 then
				takesLeft = true -- fowr -> left
			elseif dir == 1 then
				takesLeft = false -- right -> back
			end
		end

		if not skipTurn then
			if takesLeft then
				tw_turn_left()
			else
				tw_turn_right()
			end
		end
	else
		if safeToDig() then turtle.dig() end
		if not tw_move_forward() then nextTimeDoTurn = true end
		while turtle.suckDown() do end
	end
end

local function descent()
	tw_move_down()
end

local function findSameItem(slotNumber)
	if debug then print("finding same item as in "..slotNumber) end
	local ret = 17 -- starting from the end of inventory +1
	turtle.select(slotNumber)
	repeat
		ret = ret - 1
		-- skip slot we are comparing to
		if ret == slotNumber then ret = ret - 1 end
	until turtle.compareTo(ret) or ret < 1
	if ret < 1 then ret = 0 end

	return ret
end

local function isSignificant(slotNumber)
	return tableContains(importantSlots, slotNumber)
end

local function resupplySignificantSlot(slotToSupply)
	local foundSlot = findSameItem(slotToSupply)
	if foundSlot ~= 0 then
		if debug then print("resuppling from slot "..foundSlot.." to "..slotToSupply) end
		turtle.select(foundSlot)
		local itemsCount = turtle.getItemCount(foundSlot)
		if isSignificant(foundSlot) then itemsCount = itemsCount - 1 end
		if debug then
			print("items count ~ "..itemsCount)
		end
		turtle.transferTo(slotToSupply, itemsCount)
	else
		if debug then print("slot for resuply wasnt found - "..slotToSupply) end
	end
end

local function checkFuel()
	local fuel = turtle.getFuelLevel()
	if fuel == "unlimited" then return true end

	if turtle.getItemCount(slot_FUEL) < 2 then
		resupplySignificantSlot(slot_FUEL)
	end

	if fuel < 50 then
		turtle.select(slot_FUEL)
		if not turtle.refuel(1) then
			return false
		else
			print("refueled "..fuel.." -> "..turtle.getFuelLevel())
			return true
		end
	end

	return true
end

local function securityProtocolCheck()
	if relPos[pX] < 0 or relPos[pY] < 0 or relPos[pZ] < -1 or relPos[pX] > maxPos[pX] or relPos[pY] > maxPos[pY] or relPos[pZ] > relPos[pZ] then
		return false
	end

	return true
end

local function plantSapling()
	if turtle.getItemCount(slot_SAPLINGS) < 2 then
		resupplySignificantSlot(slot_SAPLINGS)
	end

	if turtle.getItemCount(slot_SAPLINGS) > 2 then -- do NOT lose all saplings, we don't want turtle to plant e.g. wood
		turtle.select(slot_SAPLINGS)
		turtle.placeDown()
	else
		-- don't have saplings, going home
		goHome = true
		print("out of saplings, going home")
	end

end

-- main

local c = checkSlots()
if c ~= true then
	print("missing sample in slot labeled: "..c)
	print("expected inv: fuel@"..slot_FUEL..", wood@"..slot_WOOD..", leaves@"..slot_LEAVES..", saplings@"..slot_SAPLINGS)
	return
end

if fs.exists(saveFile) then
	if not loadStatus() then
		print("load failed, terminating")
		return
	end
end

local newState = myState
while myState ~= state_SHUTTINGDOWN do
	if myState == state_WANDERING then
		if isChoppableFront() then
			turtle.dig()
			tw_move_forward()
			turtle.digDown()
			newState = state_CHOPPING
		else
			wander()
		end
	elseif myState == state_CHOPPING then
		if isTreeUp() then
			chop()
		else
			newState = state_DESCENDING
			turtle.digUp() -- remove top of a tree
		end
	elseif myState == state_DESCENDING then
		if downFree() and relPos[pZ] > -1 then
			descent()
		else
			if relPos[pZ] == -1 or not turtle.digDown() then
				if relPos[pZ] ~= -1 then
					print("unknown obstacle, can't descent (currLevel was expected to be -1) - taking a break, then trying to chop my way through")
					sleep(5)
					if relPos[pZ] > 0 and turtle.detectDown() then
						turtle.digDown()
					else
						-- mob?
						turtle.attackDown()
					end
					--return
				else
					newState = state_WANDERING
					tw_move_up() -- go above saplings and torches
					turtle.suckDown()
					plantSapling()
				end
			end
		end
	elseif myState == state_WAITINGFORFUEL then
		-- do nothing
		sleep(5)
	else
		print("unknown state")
		return
	end

	if not checkFuel() then
		if myState == state_WANDERING then
		--newState = state_WAITINGFORFUEL
		end
		--if newState ~= myState then print("no fuel, waiting") end
		if not goHome then
			print("going home, go no fuel")
		end
		goHome = true
	else
		if myState == state_WAITINGFORFUEL then
			newState = state_WANDERING
		end
	end

	if not securityProtocolCheck() then
		print("security protocol detected possible lose turtle, shutting down")
		newState = state_SHUTTINGDOWN
	end

	if goHome then
		if relPos[pX] == 0 and relPos[pY] == 0 and relPos[pZ] == 0 then
			-- I'm home!
			goHome = false
			newState = state_SHUTTINGDOWN
			print("home reached, shutting down")
		end
	end

	--term.write(myState.."->"..newState.." ")
	myState = newState
	saveStatus()
	sleep(0.2)
end

-- go down after work
while (not turtle.detectDown()) and tw_move_down() and relPos[pZ]>0 do end

