
-- isu: a minimal, lightweight library for building reactive user interfaces in the Roblox engine.
-- This is the compatibility library for Roact. Uses a lot of Roblox functions.
-- https://github.com/ccreaper/isu

local tt = typeof or type
local nx = next

local isu = nil
local compatRoact = {}

function compatRoact.update(tree, element)
    assert(false, 'Unimplemented')
end
compatRoact.reconcile = compatRoact.update

local SPECIAL_KEYS = {
    ["Children"] = true,
}
function compatRoact.createElement(classNameOrComponent, properties, children)
    if tt(classNameOrComponent) == 'string' then
        -- build instance
        local inst = Instance.new(classNameOrComponent)
        local children = children or properties.Children or {}
        for key, delta in nx, properties do
            if not SPECIAL_KEYS[key] then
                inst[key] = delta
            end
        end
        for childName, childValue in nx, children do
            if tt(childValue) == 'Instance' then
                childValue.Name = childName
                childValue.Parent = inst
            elseif tt(childValue) == 'function' then
                local child = childValue()
                child.Name = childName
                child.Parent = inst
            end
        end
    end
end

function compatRoact.mount(element, parent, key)
    assert(false, 'Unimplemented')
end

function compatRoact.unmount(tree)
    assert(false, 'Unimplemented')
end

return function(isuLibrary)
    isu = isuLibrary
    return compatRoact
end