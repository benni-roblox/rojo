local InstanceMap = require(script.Parent.InstanceMap)
local Logging = require(script.Parent.Logging)
local setProperty = require(script.Parent.setProperty)
local rojoValueToRobloxValue = require(script.Parent.rojoValueToRobloxValue)

local Reconciler = {}
Reconciler.__index = Reconciler

function Reconciler.new()
	local self = {
		instanceMap = InstanceMap.new(),
	}

	return setmetatable(self, Reconciler)
end

function Reconciler:applyUpdate(requestedIds, virtualInstancesById)
	-- This function may eventually be asynchronous; it will require calls to
	-- the server to resolve instances that don't exist yet.
	local visitedIds = {}

	for _, id in ipairs(requestedIds) do
		self:__applyUpdatePiece(id, visitedIds, virtualInstancesById)
	end
end

--[[
	Update an existing instance, including its properties and children, to match
	the given information.
]]
function Reconciler:reconcile(virtualInstancesById, id, instance)
	local virtualInstance = virtualInstancesById[id]

	-- If an instance changes ClassName, we assume it's very different. That's
	-- not always the case!
	if virtualInstance.ClassName ~= instance.ClassName then
		-- TODO: Preserve existing children instead?
		local parent = instance.Parent
		self.instanceMap:destroyId(id)
		return self:__reify(virtualInstancesById, id, parent)
	end

	self.instanceMap:insert(id, instance)

	-- Some instances don't like being named, even if their name already matches
	setProperty(instance, "Name", virtualInstance.Name)

	for key, value in pairs(virtualInstance.Properties) do
		setProperty(instance, key, rojoValueToRobloxValue(value))
	end

	local existingChildren = instance:GetChildren()

	local unvisitedExistingChildren = {}
	for _, child in ipairs(existingChildren) do
		unvisitedExistingChildren[child] = true
	end

	for _, childId in ipairs(virtualInstance.Children) do
		local childData = virtualInstancesById[childId]

		local existingChildInstance
		for instance in pairs(unvisitedExistingChildren) do
			local ok, name, className = pcall(function()
				return instance.Name, instance.ClassName
			end)

			if ok then
				if name == childData.Name and className == childData.ClassName then
					existingChildInstance = instance
					break
				end
			end
		end

		if existingChildInstance ~= nil then
			unvisitedExistingChildren[existingChildInstance] = nil
			self:reconcile(virtualInstancesById, childId, existingChildInstance)
		else
			self:__reify(virtualInstancesById, childId, instance)
		end
	end

	if self:__shouldClearUnknownInstances(virtualInstance) then
		for existingChildInstance in pairs(unvisitedExistingChildren) do
			self.instanceMap:removeInstance(existingChildInstance)
			existingChildInstance:Destroy()
		end
	end

	-- The root instance of a project won't have a parent, like the DataModel,
	-- so we need to be careful here.
	if virtualInstance.Parent ~= nil then
		local parent = self.instanceMap.fromIds[virtualInstance.Parent]

		if parent == nil then
			Logging.info("Instance %s wanted parent of %s", tostring(id), tostring(virtualInstance.Parent))
			error("Rojo bug: During reconciliation, an instance referred to an instance ID as parent that does not exist.")
		end

		-- Some instances, like services, don't like having their Parent
		-- property poked, even if we're setting it to the same value.
		setProperty(instance, "Parent", parent)
	end

	return instance
end

function Reconciler:__shouldClearUnknownInstances(virtualInstance)
	if virtualInstance.Metadata ~= nil then
		return not virtualInstance.Metadata.ignoreUnknownInstances
	else
		return true
	end
end

function Reconciler:__reify(virtualInstancesById, id, parent)
	local virtualInstance = virtualInstancesById[id]

	local instance = Instance.new(virtualInstance.ClassName)

	for key, value in pairs(virtualInstance.Properties) do
		setProperty(instance, key, rojoValueToRobloxValue(value))
	end

	instance.Name = virtualInstance.Name

	for _, childId in ipairs(virtualInstance.Children) do
		self:__reify(virtualInstancesById, childId, instance)
	end

	setProperty(instance, "Parent", parent)
	self.instanceMap:insert(id, instance)

	return instance
end

function Reconciler:__applyUpdatePiece(id, visitedIds, virtualInstancesById)
	if visitedIds[id] then
		return
	end

	visitedIds[id] = true

	local virtualInstance = virtualInstancesById[id]
	local instance = self.instanceMap.fromIds[id]

	-- The instance was deleted in this update
	if virtualInstance == nil then
		self.instanceMap:destroyId(id)
		return
	end

	-- An instance we know about was updated
	if instance ~= nil then
		self:reconcile(virtualInstancesById, id, instance)
		return instance
	end

	-- If the instance's parent already exists, we can stick it there
	local parentInstance = self.instanceMap.fromIds[virtualInstance.Parent]
	if parentInstance ~= nil then
		self:__reify(virtualInstancesById, id, parentInstance)
		return
	end

	-- Otherwise, we can check if this response payload contained the parent and
	-- work from there instead.
	local parentData = virtualInstancesById[virtualInstance.Parent]
	if parentData ~= nil then
		if visitedIds[virtualInstance.Parent] then
			error("Rojo bug: An instance was present and marked as visited but its instance was missing")
		end

		self:__applyUpdatePiece(virtualInstance.Parent, visitedIds, virtualInstancesById)
		return
	end

	Logging.trace("Instance ID %s, parent ID %s", tostring(id), tostring(virtualInstance.Parent))
	error("Rojo NYI: Instances with parents that weren't mentioned in an update payload")
end

return Reconciler