--[[
	Tags - generic tag plumbing, not a vocabulary. For the actual ability taxonomy
	(Ranged/Melee/Dash/CrowdControl/DamageType/...), see ReplicatedStorage.Shared.AbilitySystem.AbilityTags
	and AbilitySchema - that's where "what kind of ability is this" is decided and checked.

	This module answers a different question: "how do I attach and check a tag on
	anything, consistently" - since abilities are plain Lua tables (no CollectionService)
	while units are real Instances, and some things are runtime STATE on a unit rather
	than a property of an ability at all (e.g. "this target is Untargetable right now").

	Two separate tag surfaces:

	1. INSTANCE TAGS (CollectionService-backed) - for Models/Instances in the world.
		Use Tags.Add / Remove / Has / GetTagged for anything that's a real Instance.
		Example: Tags.Add(dashingUnit, Tags.State.Untargetable) during a dash's active frames;
		Tags.Has(target, Tags.State.Invulnerable) in DamageService.

	2. DATA TAGS - for plain data tables (ability definitions, item definitions, ...)
		that carry a `Tags = { TagName = true, ... }` set, for anything that ISN'T an
		Instance and so can't use CollectionService. Use Tags.DataAdd / DataHas / etc.
		Ability code should tag with AbilityTags constants through these functions rather
		than reinventing a second ad-hoc tag-set format.

	Tags.State below is the one small vocabulary this module still owns: transient
	per-Instance combat/targeting state, which isn't a property of an ability's design
	(that's AbilityTags's job) but of a unit's condition at a given moment in a match.
]]

local CollectionService = game:GetService("CollectionService")

local Tags = {}

-- ===== Canonical tag registry ==================================================

-- Transient targeting/combat states an Instance can carry. These are checked by
-- DamageService and AbilityService targeting so every system agrees on what they mean.
Tags.State = {
	Untargetable = "Untargetable", -- can't be selected as a target (skipped by area/projectile hit-tests)
	Invulnerable = "Invulnerable", -- can be targeted, but Deal() always zeroes the damage
	Stealthed = "Stealthed", -- hidden from enemy targeting/vision (future vision system)
	Suppressed = "Suppressed", -- silenced + can't move/dash (heavier than plain Silence)
}

-- ===== Instance tags (CollectionService-backed) ================================

function Tags.Add(instance: Instance, tag: string)
	CollectionService:AddTag(instance, tag)
end

function Tags.Remove(instance: Instance, tag: string)
	CollectionService:RemoveTag(instance, tag)
end

function Tags.Has(instance: Instance, tag: string): boolean
	return CollectionService:HasTag(instance, tag)
end

-- True if the instance carries any of the given tags.
function Tags.HasAny(instance: Instance, tags: { string }): boolean
	for _, tag in ipairs(tags) do
		if CollectionService:HasTag(instance, tag) then
			return true
		end
	end
	return false
end

function Tags.GetTagged(tag: string): { Instance }
	return CollectionService:GetTagged(tag)
end

function Tags.GetAll(instance: Instance): { string }
	return CollectionService:GetTags(instance)
end

-- ===== Data tags (plain Lua tables, e.g. ability/item definitions) =============

function Tags.DataAdd(data: { [string]: any }, tag: string)
	data.Tags = data.Tags or {}
	(data.Tags :: any)[tag] = true
end

function Tags.DataRemove(data: { [string]: any }, tag: string)
	if data.Tags then
		(data.Tags :: any)[tag] = nil
	end
end

function Tags.DataHas(data: { [string]: any }, tag: string): boolean
	return data.Tags ~= nil and (data.Tags :: any)[tag] == true
end

-- True if the data table carries any / all of the given tags.
function Tags.DataHasAny(data: { [string]: any }, tags: { string }): boolean
	for _, tag in ipairs(tags) do
		if Tags.DataHas(data, tag) then
			return true
		end
	end
	return false
end

function Tags.DataHasAll(data: { [string]: any }, tags: { string }): boolean
	for _, tag in ipairs(tags) do
		if not Tags.DataHas(data, tag) then
			return false
		end
	end
	return true
end

return Tags
