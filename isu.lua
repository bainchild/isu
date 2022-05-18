
-- isu: a minimal, lightweight library for building reactive user interfaces in the Roblox engine.
-- https://github.com/ccreaper/isu

local getType = typeof or type
local coroRunning = coroutine.running
local instanceNew = Instance.new
local pairs = pairs
local setmt = setmetatable
local tweenService = game:GetService("TweenService")

local isu = {}
local _contextStorage = {}

---@class WeakTable
---@field v any

-- Creates a weak reference holder (weak table) and returns it.
-- Data is pointed to by `self.v`, but can be stored anywhere in the table.
---@param value any
---@return WeakTable
local function weakRef(value)
    return setmt({v = value}, {__mode = 'v'})
end

-- Clones a table. If `deep` is truthy, all nested tables will be cloned too.
---@param t table
---@param deep? boolean
---@return table
local function clone(t, deep)
    local nt = {}
    for key, delta in pairs(t) do
        local nK, nD = key, delta
        if getType(key) == 'table' and deep then
            nK = clone(key, deep)
        end
        if getType(delta) == 'table' and deep then
            nD = clone(delta, deep)
        end
        nt[nK] = nD
    end
    return nt
end

---@class Accumulator
---@field stack table
---@return Accumulator
local function accumulator()
    local obj = {stack={}, coro=setmt({},{__mode='v'})}

    function obj:at(i)
        return self.stack[i]
    end

    function obj:write(i, value)
        self.stack[i] = value
    end

    function obj:push(value)
        self.stack[#self.stack+1] = value
        return value
    end

    function obj:reset()
        self.coro[coroRunning()] = 0
    end

    function obj:next()
        local running = coroRunning()
        self.coro[running] = self.coro[running] + 1
        return self:at(self.coro[running]), self.coro[running]
    end

    return obj
end

---@class Context
---@field prev WeakTable|nil Weak reference to the currently rendered object.
---@field props table Properties of the component. Can be mutated on renders.
---@field objects Accumulator Stores and caches created instances.
---@field states Accumulator Variables declared in the renderer.
---@field effects Accumulator Holds mounting callbacks.
---@field unmounts Accumulator Holds unmounting callbacks.
---@field events Accumulator Event callbacks to be connected to rendered objects.
---@field transitions Accumulator Tween generator for mutated properties.
---@field subcomponents Accumulator Nested components created at render time.

-- Sets the coroutine's current context to def.
---@param def any Default value to set context to.
---@param coro? any Apply context to this coroutine. Defaults to current thread.
---@return Context
local function setContext(def, coro)
    coro = coro or coroRunning()
    _contextStorage[coro] = def
    return _contextStorage[coro]
end

-- Retrieves the context from the coroutine. Can be nil.
---@param coro? any Apply context to this coroutine. Defaults to current thread.
---@return Context|nil
local function getContext(coro)
    coro = coro or coroRunning()
    return _contextStorage[coro]
end

-- Calls `fn` with the supplied context `ctx`. Varargs are passed to `fn`.
---@param ctx Context
---@param fn function
---@vararg any
local function withContext(ctx, fn, ...)
    local previous = getContext()
    setContext(ctx)
    local result = fn(...)
    setContext(previous)
    return result
end

local makeInstance
do --> context-aware instance creation
    local function make(className, properties)
        local inst = instanceNew(className)
        for key, delta in pairs(properties) do
            if getType(key) == 'number' then
                delta().Parent = inst
            else
                inst[key] = delta -- todo: event shit
            end
        end
        return inst
    end

    -- Contextually constructs an instance with the provided properties.
    -- If the current context has a listing for this instance, it will be returned instead of instancing a new object.
    ---@param className string
    ---@param properties table
    ---@return Instance
    function makeInstance(className, properties)
        local ctx = getContext()
        local current = ctx.objects:next()
        properties = properties or {}
        if not current then
            current = make(className, properties)
            ctx.objects:push(current)
            current.Destroying:Connect(function()
                for _, unmounter in pairs(ctx.unmounts.stack) do
                    unmounter()
                end
            end)
        end
        for _, event in pairs(ctx.events.stack) do
            event.connection = current[event.name]:Connect(event.fn)
        end
        return current
    end
end

---@class Transition
---@field fn function
---@field name string

-- Performs a transition contextually.
---@param instance Instance
---@param property string
---@param toValue any
---@param transition Transition
---@return boolean
local function performTransition(instance, property, toValue, transition)
    local onEnd
    local function useTransitionComplete(endFn)
        onEnd = endFn
    end

    local tween = tweenService:Create(instance,
        TweenInfo.new(transition.fn(toValue, useTransitionComplete)), {
        [property] = toValue
    })

    if onEnd then
        tween.Completed:Connect(onEnd)
    end
    tween:Play()
    return true
end

-- Mutates an instance conditionally, only overwriting fields when they have changed,
---@param src Instance
---@param new table
---@return Instance
local function mutateConditionally(src, new)
    local ctx = getContext()
    for key, delta in pairs(new) do
        if getType(key) ~= 'number' then
            local t1, t2 = getType(src[key]), getType(delta)
            if t1 ~= t2 then
                -- mutate due to differing types
                src[key] = delta
            elseif src[key] ~= delta then
                -- mutate on differing values
                local hast = {}
                for _, v in pairs(ctx.transitions.stack) do
                    if v.name == key then
                        hast[key] = performTransition(src, key, delta, v)
                    end
                end
                if not hast[key] then
                    src[key] = delta
                end
            end
        else
            delta() -- run rerenderer
        end
    end
    return src
end

-----------------------------------------------

-- Creates a stateful variable, which is a reactive value that can be dynamically updated.
-- The variable is bound to the component in which it has been declared, and any changes made
-- to the variable through its updater function will automatically re-render the component.
-- For more information: https://reactjs.org/docs/hooks-reference.html#usestate
---@generic T : any
---@param value T
---@return T Value @The current value. Will update automatically after the updater has been called.
---@return fun(newValue:T) Updater @The stateful updater. Call this to update the state with a new value.
function isu.useState(value)
    local ctx = getContext()
    local current, i = ctx.states:next()
    if current then
        return current.value, current.updater
    else
        local state
        state = ctx.states:push({
            value = value,
            updater = function(newValue)
                if ctx.states:at(i).value ~= newValue then
                    state.value = newValue
                    ctx.render()
                end
            end
        })
        return state.value, state.updater
    end
end

-- Applies lifecycle hooks to the current component based on `fn`'s behavior.
-- If no states are supplied, then the callback will be invoked when the component is first rendered,
-- and its return value, which can be a function, will be invoked when the component is unmounted.
-- If no function is returned, then nothing will be invoked at unmount. If some states are supplied,
-- then the effect hook will only execute when these specific states are updated.
-- For more information: https://reactjs.org/docs/hooks-reference.html#useeffect
---@param fn function
---@param states? any[]
function isu.useEffect(fn, states)
    local ctx = getContext()
    local current = ctx.effects:next()
    if not current then
        ctx.effects:push(true)
        local unmounter = fn()
        if unmounter and not ctx.unmounts:next() then
            ctx.unmounts:push(unmounter)
        end
    end
end

-- Connects `callback` to the constructed object's event named `eventName`.
-- The event must be directly indexable using the supplied name (for instance,
-- property change events requiring `GetPropertyChangedSignal` cannot be accessed
-- using useEvent and requires special syntax).
-- The callback signal will be dynamically disconnected and reconnected at multiple
-- points during the lifecycle of the component, and the state of the component can
-- be updated at will during an event's invocation.
--
-- **Example used on a TextLabel:**
-- ```
-- useEvent('MouseButton1Click', function()
--     print('The instance has been clicked!')
-- end)
-- ```
---@param eventName string
---@param connection function
function isu.useEvent(eventName, connection)
    local ctx = getContext()
    local current = ctx.events:next()
    if not current then
        ctx.events:push({ name = eventName, fn = connection })
    else
        current.connection:Disconnect()
        current.connection = nil
        current.fn = connection
    end
end

-- Subjects an instance property to a transition (such as a tween) when it is
-- mutated by the reconciliation/diffing process. `tweenCalculator` must be a
-- function that returns the parameters to construct a new tween, and it can
-- accept two arguments: the new value that will be transitioned to, and a
-- callback that accepts a function which will be invoked when the transition ends.
--
-- **Example:**
-- ```
-- useTransition('Position', function(newValue, onTransitionEnd)
--     onTransitionEnd(function()
--         print('Transition has ended.')
--     end)
--     return 0.3, Enum.EasingStyle.Quad
-- end)
-- ```
---@param propertyName string
---@param tweenCalculator fun(newValue:any,onTransitionEnd:fun(callback:function))
function isu.useTransition(propertyName, tweenCalculator)
    local ctx = getContext()
    local current = ctx.transitions:next()
    if not current then
        ctx.transitions:push({name=propertyName, fn=tweenCalculator})
    end
end

-- Creates a new component and returns its factory, a function used to construct
-- component instances. Calling the factory instanciates a component with an initial
-- dictionary of user-defined props passed as a parameter, and returns a function that can
-- be used to (re)render the component, finally returning the instance itself.
--
-- The renderer **must** return a string indicating the class name of the instance
-- to create, and a dictionary of instance properties which can accept reactive values.
-- This dictionary will be used to differentiate, reconcile and update the instance.
-- The dictionary can also have an array part (values without keys) in which you can
-- list child components that will be parented to the instance at mount.
--
-- **Example:**
-- ```
-- component(function(props)
--     return 'TextLabel', {
--         Text = 'Hello world!'
--     }
-- end)
-- ```
---@generic Props any
---@param renderer fun(props:Props):string,table
---@return fun(props:Props):fun():Instance
function isu.component(renderer)
    -- returns a factory which can be made
    -- to build a component from props
    return function(props)
        local context = {}

        if getContext() then
            -- constructed within other component
            local cctx = getContext()
            local current = cctx.subcomponents:next()
            if current then
                current.props = props
                return current.render
            else
                cctx.subcomponents:push(context)
            end
        end

        context.prev = weakRef(nil)
        context.props = props
        context.objects = accumulator()
        context.states = accumulator()
        context.effects = accumulator()
        context.unmounts = accumulator()
        context.events = accumulator()
        context.transitions = accumulator()
        context.subcomponents = accumulator()

        context.render = function()
            return coroutine.wrap(function()
                return withContext(context, function()
                    context.objects:reset()
                    context.states:reset()
                    context.effects:reset()
                    context.unmounts:reset()
                    context.events:reset()
                    context.transitions:reset()
                    context.subcomponents:reset()

                    local className, nprops = renderer(context.props)
                    if getType(className) ~= 'string' or getType(nprops) ~= 'table' then
                        error('Component renderer must return a classname and properties.')
                    end

                    local inst = makeInstance(className, nprops)
                    if not context.prev.v then
                        context.prev.v = inst
                    else
                        mutateConditionally(context.prev.v, nprops)
                    end

                    return inst
                end)
            end)()
        end

        return context.render
    end
end

return isu