--[[
	InventoryService - 6 item slots + the shop transactions (buy / sell / rearrange).

	Items contribute stats through StatService modifiers keyed "Item_<slot>", so any stat
	(including hidden ones) can come from items. Gameplay effects can be added later via
	the item's `Effects` field.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)

local PlayerState = require(script.Parent.PlayerState)
local StatService = require(script.Parent.StatService)
local GoldService = require(script.Parent.GoldService)
local Remotes = require(script.Parent.Remotes)

local InventoryService = {}

local function itemModifiers(item)
	local mods = {}
	for stat, amount in pairs(item.Stats or {}) do
		mods[stat] = mods[stat] or {}
		mods[stat].Flat = (mods[stat].Flat or 0) + amount
	end
	for stat, amount in pairs(item.PercentStats or {}) do
		mods[stat] = mods[stat] or {}
		mods[stat].Percent = (mods[stat].Percent or 0) + amount
	end
	return mods
end

local function refreshSlot(player: Player, state, slot: number)
	local itemId = state.Items[slot]
	PlayerState.Publish(player, "Item_" .. slot, itemId or "")
	local item = itemId and Items.Get(itemId)
	if item then
		state.Modifiers["Item_" .. slot] = itemModifiers(item)
	else
		state.Modifiers["Item_" .. slot] = nil
	end
end

local function getPurchasePlan(state, item)
	local credit = 0
	local componentSlots = {}
	local usedSlots = {}

	-- Only direct recipe components are credited here. This mirrors the shop's
	-- displayed build path and keeps the purchase calculation deterministic.
	for _, requiredId in ipairs(item.BuildFrom or {}) do
		for slot = 1, Config.InventorySlots do
			if not usedSlots[slot] and state.Items[slot] == requiredId then
				local component = Items.Get(requiredId)
				if component then
					credit += component.Cost or 0
				end
				usedSlots[slot] = true
				table.insert(componentSlots, slot)
				break
			end
		end
	end

	local remainingCost = math.max(0, (item.Cost or 0) - credit)
	return remainingCost, componentSlots, credit
end

local function firstEmptySlot(state): number?
	for i = 1, Config.InventorySlots do
		if not state.Items[i] then
			return i
		end
	end
	return nil
end

function InventoryService.Buy(player: Player, itemId: string): boolean
	local state = PlayerState.Get(player)
	if not state or not state.Deployed then
		return false
	end

	local item = Items.Get(itemId)
	if not item then
		return false
	end

	local purchaseCost, componentSlots = getPurchasePlan(state, item)

	if not GoldService.RemoveGold(player, purchaseCost) then
		local currentGold = player:GetAttribute("Gold") or 0
		Remotes.Notify:FireClient(
			player,
			string.format("Need %d more gold", math.max(0, purchaseCost - currentGold))
		)
		return false
	end

	-- If recipe components are owned, replace them in-place with the completed
	-- item. This allows upgrades even when the inventory was already full.
	if #componentSlots > 0 then
		local targetSlot = componentSlots[1]

		for _, slot in ipairs(componentSlots) do
			state.Items[slot] = nil
			refreshSlot(player, state, slot)
		end

		state.Items[targetSlot] = itemId
		refreshSlot(player, state, targetSlot)
	else
		local slot = firstEmptySlot(state)
		if not slot then
			-- Refund the purchase because there was nowhere to place the item.
			GoldService.AddGold(player, purchaseCost)
			Remotes.Notify:FireClient(player, "Inventory full")
			return false
		end

		state.Items[slot] = itemId
		refreshSlot(player, state, slot)
	end

	StatService.Recompute(player)
	return true
end

function InventoryService.Sell(player: Player, slot: number): boolean
	local state = PlayerState.Get(player)
	if not state or not state.Deployed then
		return false
	end
	local itemId = state.Items[slot]
	local item = itemId and Items.Get(itemId)
	if not item then
		return false
	end
	state.Items[slot] = nil
	refreshSlot(player, state, slot)
	GoldService.AddGold(player, math.floor(item.Cost * Config.SellRefundRatio))
	StatService.Recompute(player)
	return true
end

function InventoryService.Move(player: Player, from: number, to: number)
	local state = PlayerState.Get(player)
	if not state or not state.Deployed or from == to then
		return
	end
	state.Items[from], state.Items[to] = state.Items[to], state.Items[from]
	refreshSlot(player, state, from)
	refreshSlot(player, state, to)
	StatService.Recompute(player)
end

local function validSlot(value: any): boolean
	return typeof(value) == "number" and value == math.floor(value) and value >= 1 and value <= Config.InventorySlots
end

function InventoryService.Init()
	Remotes.ShopBuy.OnServerEvent:Connect(function(player, itemId)
		if typeof(itemId) == "string" then
			InventoryService.Buy(player, itemId)
		end
	end)
	Remotes.ShopSell.OnServerEvent:Connect(function(player, slot)
		if validSlot(slot) then
			InventoryService.Sell(player, slot)
		end
	end)
	Remotes.MoveItem.OnServerEvent:Connect(function(player, from, to)
		if validSlot(from) and validSlot(to) then
			InventoryService.Move(player, from, to)
		end
	end)
end

return InventoryService
