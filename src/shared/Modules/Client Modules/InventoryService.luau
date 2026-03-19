local module = {}

local player = game.Players.LocalPlayer

local UIS = game:GetService("UserInputService")

local player_gui = player.PlayerGui
local inventory_ui = player_gui:WaitForChild("Inventory")
local main_frame = inventory_ui:WaitForChild("Main")
local example_frame = main_frame.Example

local empty_icon = "rbxassetid://87184018440060"

local InventorySlots = {
	["1"] = {Keybind = Enum.KeyCode.One,   Tool = nil, UI = nil, Designation = "Primary",      PermanentUISpot = true},
	["2"] = {Keybind = Enum.KeyCode.Two,   Tool = nil, UI = nil, Designation = "Secondary",    PermanentUISpot = true},
	["3"] = {Keybind = Enum.KeyCode.Three, Tool = nil, UI = nil, Designation = "Melee",        PermanentUISpot = true},
	["4"] = {Keybind = Enum.KeyCode.Four,  Tool = nil, UI = nil, Designation = "Mining",       PermanentUISpot = true},
	["5"] = {Keybind = Enum.KeyCode.Five,  Tool = nil, UI = nil, Designation = "Miscellanous", PermanentUISpot = false},
	["6"] = {Keybind = Enum.KeyCode.Six,   Tool = nil, UI = nil, Designation = "Miscellanous", PermanentUISpot = false},
	["7"] = {Keybind = Enum.KeyCode.Seven, Tool = nil, UI = nil, Designation = "Miscellanous", PermanentUISpot = false},
	["8"] = {Keybind = Enum.KeyCode.Eight, Tool = nil, UI = nil, Designation = "Miscellanous", PermanentUISpot = false},
	["9"] = {Keybind = Enum.KeyCode.Nine,  Tool = nil, UI = nil, Designation = "Miscellanous", PermanentUISpot = false},
	["0"] = {Keybind = Enum.KeyCode.Zero,  Tool = nil, UI = nil, Designation = "Miscellanous", PermanentUISpot = false},
}

-- Explicit ordering: 1–9 then 0.
-- All loops use this so iteration is always deterministic.
local SLOT_ORDER = {"1","2","3","4","5","6","7","8","9","0"}

local current_equipped = nil

-- // Helpers

local function find_existing_tool(toolObject)
	for _, key in ipairs(SLOT_ORDER) do
		if InventorySlots[key].Tool == toolObject then
			return true
		end
	end
	return false
end

local function find_first_empty_slot(designation)
	-- First pass: prefer a slot whose designation matches
	for _, key in ipairs(SLOT_ORDER) do
		local slot = InventorySlots[key]
		if not slot.Tool and slot.Designation == designation then
			return key
		end
	end

	-- Second pass: any empty slot
	for _, key in ipairs(SLOT_ORDER) do
		local slot = InventorySlots[key]
		if not slot.Tool and slot.Designation == "Miscellanous" then
			return key
		end
	end

	return nil
end

local function create_slot_ui(slotNumber, slot)
	local ui = example_frame:Clone()
	ui.Name = "Slot_" .. slotNumber
	ui.Parent = main_frame
	ui.Visible = true

	ui.Hotkey.Text = slotNumber
	ui.ImageLabel.Image = empty_icon

	slot.UI = ui
end

local function update_slot_ui(slot)
	if not slot.UI then return end

	if slot.Tool and slot.Tool.item_image then
		slot.UI.ImageLabel.Image = slot.Tool.item_image
	else
		slot.UI.ImageLabel.Image = empty_icon
	end
end

local function equip_tool(toolObject)
	if not toolObject then return end

	if current_equipped and current_equipped ~= toolObject then
		current_equipped:unequip()
	end

	toolObject:equip()
	current_equipped = toolObject
end

local function assign_tool(toolObject)
	if find_existing_tool(toolObject) then return end

	local designation = toolObject.Designation or "Miscellanous"
	local slot_number = find_first_empty_slot(designation)

	if not slot_number then
		warn("no empty slots")
		return
	end

	local slot = InventorySlots[slot_number]
	slot.Tool = toolObject

	if not slot.UI then
		create_slot_ui(slot_number, slot)
	end

	update_slot_ui(slot)
end

local function remove_tool(toolObject)
	for _, key in ipairs(SLOT_ORDER) do
		local slot = InventorySlots[key]
		if slot.Tool == toolObject then

			if current_equipped == toolObject then
				toolObject:unequip()
				current_equipped = nil
			end

			slot.Tool = nil

			if slot.UI then
				if slot.PermanentUISpot then
					update_slot_ui(slot)
				else
					slot.UI:Destroy()
					slot.UI = nil
				end
			end

			-- Don't break — a tool should only ever be in one slot,
			-- but this cleans up any accidental duplicates too.
		end
	end
end

-- // Main

function module.start_module()
	for _, key in ipairs(SLOT_ORDER) do
		local slot = InventorySlots[key]
		if slot.PermanentUISpot then
			create_slot_ui(key, slot)
		end
	end

	UIS.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		for _, key in ipairs(SLOT_ORDER) do
			local slot = InventorySlots[key]
			if input.KeyCode == slot.Keybind then
				if not slot.Tool then continue end

				if current_equipped == slot.Tool then
					slot.Tool:unequip()
					current_equipped = nil
				else
					equip_tool(slot.Tool)
				end
			end
		end
	end)
end

function module.assign_tool(tool)
	assign_tool(tool)
	print("Assigned tool", tool)
end

function module.remove_tool(tool)
	print("Removed Tool", tool)
	remove_tool(tool)
end

return module