
-- isu: a minimal, lightweight library for building reactive user interfaces in the Roblox engine.
-- https://github.com/ccreaper/isu

local getType = typeof or type
local coroRunning = coroutine.running
local instanceNew = Instance.new
local pairs = pairs
local getmt = getmetatable
local setmt = setmetatable
local tweenService = game:GetService("TweenService")

local isu = {}
local _contextStorage = {}

---@class WeakTable
---@field v any

local WEAK_MT_K = {__mode = 'k'}
local WEAK_MT_V = {__mode = 'v'}
local WEAK_MT_KV = {__mode = 'kv'}
-- Creates a weak reference holder (weak table) and returns it.
-- Data is pointed to by `self.v`, but can be stored anywhere in the table.
---@param value any
---@return WeakTable
local function weakRef(value)
    return setmt({v = value}, WEAK_MT_V)
end
setmt(_contextStorage, WEAK_MT_K)

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
    local obj = {stack={}, coro=setmt({},WEAK_MT_KV)}

    function obj:index()
        return self.coro[coroRunning()]
    end

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

    function obj:denote()
        if self.denotei then
            if self.denotei ~= #self.stack then
                return error('Variadic accumulation has been detected during composition. Make sure that you are not conditionally invoking hooks (for instance, within an if statement).', 2)
            end
        end
        self.denotei = #self.stack
    end

    return obj
end

local CONTEXT_ACCUMULATORS = {
    'objects', 'states', 'effects', 'unmounts', 'events',
    'transitions', 'animations', 'subcomponents', 'subscriptions'
}
---@class Context
---@field prev WeakTable|nil Weak reference to the currently rendered object.
---@field props table Properties of the component. Can be mutated on renders.
---@field objects Accumulator Stores and caches created instances.
---@field states Accumulator Variables declared in the renderer.
---@field effects Accumulator Holds mounting callbacks.
---@field unmounts Accumulator Holds unmounting callbacks.
---@field events Accumulator Event callbacks to be connected to rendered objects.
---@field transitions Accumulator Tween generator for mutated properties.
---@field animations Accumulator Tween generator for user-mutated properties.
---@field animated table Dictionary mapping property names to a boolean representing whether they were user-animated for this render.
---@field subcomponents Accumulator Nested components created at render time.
---@field subscriptions Accumulator Subscription-based stateful variables.

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

-- Verifies if a hook is enabled in this component.
local function assertUsability(hookName)
    return (
        getContext().opts[hookName] or
        getContext().opts['enableAll']
    ) or error('"' .. hookName .. '" is not enabled in this component builder.')
end

local makeInstance
do --> context-aware instance creation
    local function make(className, properties)
        local inst = getType(className) == 'Instance' and className or instanceNew(className)
        for key, delta in pairs(properties) do
            if getType(key) == 'number' then
                delta().Parent = inst
            else
                if getType(delta) == 'table'
                    and getmt(delta)
                    and getmt(delta).__type == 'Subscription' then
                        inst[key] = delta.value
                else
                    inst[key] = delta
                end
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
        if not current then
            properties = properties or {}
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
            if t2 == 'table' then
                -- check if special object
                local mt = getmt(delta)
                if mt and mt.__type then
                    if mt.__type == 'Subscription' then
                        delta.represents.listeners[key] = function(newValue)
                            src[key] = newValue
                        end
                        src[key] = delta.value
                    end
                else
                    src[key] = delta
                end
            elseif t1 ~= t2 then
                -- mutate due to differing types
                src[key] = delta
            elseif ctx.animated[key] then
                for _, v in pairs(ctx.animations.stack) do
                    if v.name == key then
                        performTransition(src, key, ctx.animated[key], v)
                    end
                end
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
        ctx.effects:push({fn=fn,states=states or {}})
    elseif states then
        for i = 1, #states do
            if current.states[i] ~= states[i] then
                current.fn()
                break
            end
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
    assertUsability('useEvent')
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
    assertUsability('useTransition')
    local ctx = getContext()
    local current = ctx.transitions:next()
    if not current then
        ctx.transitions:push({name=propertyName, fn=tweenCalculator})
    end
end

-- Returns a function that animates a property upon invocation. `useAnimation`
-- accepts the same arguments as `useTransition` and their behavior is the same,
-- but while `useTransition` applies an animation _when_ a property is mutated,
-- `useAnimation` only applies an animation when the user requests it through
-- the returned callback, passing the new value to animate to as an argument.
--
-- **Take note that the callback does not immediately trigger the animation.**
-- Instead, it schedules it to be performed on the next re-render, similarly to
-- `useTransition`'s mechanism. In most cases, the animation should be performed
-- straight away as hook usage often triggers a re-render, but in the case that
-- it doesn't, you can manually force a re-render through `useTriggerableRender`
-- after scheduling your animation(s).
--
-- **Example:**
-- ```
-- local rerender = useTriggerableRender()
-- local anim = useAnimation('Position', function(newValue, onTransitionEnd)
--     onTransitionEnd(function()
--         print('Transition has ended.')
--     end)
--     return 0.3, Enum.EasingStyle.Quad
-- end)
-- useEvent('MouseButton1Click', function()
--     anim(UDim2.new(0, 100 * math.random(), 0, 100 * math.random()))
--     rerender()
-- end)
-- ```
---@generic T
---@param propertyName string
---@param tweenCalculator fun(newValue:any,onTransitionEnd:fun(callback:function))
---@return fun(newValue:T)
function isu.useAnimation(propertyName, tweenCalculator)
    assertUsability('useAnimation')
    local ctx = getContext()
    local current = ctx.animations:next()
    if not current then
        local anim
        anim = {
            name = propertyName,
            fn = tweenCalculator,
            perform = function(newValue)
                ctx.animated[propertyName] = newValue
            end
        }
        ctx.animations:push(anim)
        return anim.perform
    else
        return current.perform
    end
end

local SUBSCRIPTION_MT = {
    __type = 'Subscription',
    __call = function(t, optional)
        if not optional then
            return t.value
        else
            t.represents.updater(optional)
            return optional
        end
    end
}
-- Creates a subscription-based stateful value. This hook serves as a more performant
-- alternative to `useState` when the value only needs to be accessed and updated within another
-- hook (such as `useEvent` or `useEffect`) and not within the renderer function directly.
-- When a subscription's value updates, the value is directly applied to the Instance instead
-- of passing through the library's reconciliation and diffing process, which invokes the renderer.
-- The usual use of a subscription is when a value is used exclusively within an Instance's properties.
--
-- **Subscriptions should not be used if your code repeatedly needs to read its value.** Occasional
-- access through hooks is fine, but `useState` is the superior option to use if your renderer
-- needs to access the value regularly, since the subscription's method of reading is less performant.
-- 
-- `useSubscription` returns a single function which, when called with no arguments, returns the
-- current value. However, when it is called with a single argument, the value of the subscription
-- is updated to the value passed through the argument and the Instance is updated accordingly. Only
-- this function is necessary, but for compatibility with the `useState` syntax, a second function will
-- also be returned that exclusively updates the value of the subscription.
--
-- **Example:**
-- ```
-- local time = useSubscription(workspace.DistributedGameTime)
-- print("This should only be printed once, unlike the useState hook!")
-- useEffect(function()
--		task.spawn(function()
--			while task.wait() do
--				time(workspace.DistributedGameTime)
--			end
--		end)
--	end)
-- return 'TextButton', { Size = UDim2.new(0, 200, 0, 200), Text = time }
-- ```
---@generic T
---@param value any
---@return fun(newValue?:T) @Updater-retriever. Calling it without an argument retrieves the value, and calling it with an argument updates the value.
function isu.useSubscription(value)
    assertUsability('useSubscription')
    local ctx = getContext()
    local current, i = ctx.subscriptions:next()
    if current then
        return current.proxy, current.updater
    else
        local subscription = {}
        subscription.listeners = {}
        subscription.value = value
        subscription.proxy = setmt({
            value = value,
            represents = subscription
        }, SUBSCRIPTION_MT)
        subscription.updater = function(newValue)
            if ctx.subscriptions:at(i).value ~= newValue then
                subscription.value = newValue
                subscription.proxy.value = newValue
                for _, listener in pairs(subscription.listeners) do
                    listener(newValue)
                end
            end
        end
        ctx.subscriptions:push(subscription)
        return subscription.proxy, current.updater
    end
end

-- Returns a callback that re-renders the component when invoked.
-- Avoids React's [forced re-render problem](https://stackoverflow.com/questions/46240647/react-how-to-force-a-function-component-to-render/53837442)
-- in functional components.
---@return function
function isu.useTriggerableRender()
    return getContext().render
end

-- Creates a component builder, which can be called to create new components
-- with a renderer and hooks. The library uses the builder to construct the
-- Instance component factory at `isu.component`.
---@param instantiator function @This function must accept a class name and a dictionary of properties at minimum. The table can also include an array part composed of subcomponents, but this behavior may be safely ignored if not relevant.
---@param mutator function @This function is used to mutate an existing object. It must accept the instance to mutate and a dictionary of properties to assign. A common optimization is to only assign a property if its value has changed.
---@param opts? table @You can enable special hooks (such as `useEvent` and `useAnimation`) by setting them to true in this table (`["useEvent"] = true`). Essential hooks such as `useState` and `useEffect` are always available.
---@return function
function isu.builder(instantiator, mutator, opts)
    opts = opts or {}
    -- returns a factory which can be made
    -- to build a component from props
    return function(renderer, hydrateThis)
        return function(props)
            if not opts.hydration and hydrateThis then
                return error('Hydration not enabled in builder options.')
            end

            local context = {
                opts = opts,
                prev = weakRef(nil),
                props = props,
                animated = {}
            }

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

            for _, v in pairs(CONTEXT_ACCUMULATORS) do
                context[v] = accumulator()
            end

            context.render = coroutine.wrap(function()
                while true do
                    coroutine.yield(withContext(context, function()
                        for _, v in pairs(CONTEXT_ACCUMULATORS) do
                            context[v]:reset()
                        end

                        local className, nprops = renderer(context.props)
                        if getType(className) ~= 'string' or getType(nprops) ~= 'table' then
                            error('Component renderer must return a classname and properties.')
                        end

                        -- Can detect varadic (conditional) hook use.
                        -- Error if the current hook counts aren't similar
                        -- to the previous hook counts.
                        -- An exception is made for the objects accumulator,
                        -- whose value is mediated by the mutator and not
                        -- by the renderer.
                        for _, v in pairs(CONTEXT_ACCUMULATORS) do
                            if v ~= 'objects' then
                                context[v]:denote()
                            end
                        end

                        local inst = instantiator(hydrateThis or className, nprops)
                        mutator(inst, nprops)
                        if not context.prev.v or (not context.prev.v and hydrateThis) then
                            context.prev.v = inst
                            for _, effect in pairs(context.effects.stack) do
                                local unmounter = effect.fn()
                                if unmounter and not context.unmounts:next() then
                                    context.unmounts:push(unmounter)
                                end
                            end
                        end

                        if opts.useAnimation then
                            context.animated = {}
                        end
                        return inst
                    end))
                end
            end)

            return context.render
        end
    end
end

local INSTANCE_BUILDER = isu.builder(makeInstance, mutateConditionally, {
    enableAll = true -- enable all hooks on instances
})
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
    return INSTANCE_BUILDER(renderer)
end

local INSTANCE_HYDRATE = isu.builder(makeInstance, mutateConditionally, {
    hydration = true, -- enable hydration for this builder
    enableAll = true -- enable all hooks on instances
})
-- Hydrates (updates) an already existing object with the renderer instead of
-- creating one. Initial properties can also be provided. Otherwise, behavior
-- is the exact same as the component factory, but returns nothing.
--
-- **Hydration does not automatically hydrate any subcomponents.**
-- You will have to hydrate any children manually and remove their factory
-- in the renderer's returned properties, or leave their creation up to the
-- renderer.
---@param object Instance
---@param renderer function
---@param props? table
function isu.hydrate(object, renderer, props)
    INSTANCE_HYDRATE(renderer, object)(props)()
end

return isu