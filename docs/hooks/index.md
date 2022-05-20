---
layout: default
title: Hooks
has_children: true
---

# Hooks

**Hooks** are pure functions that allow you to compose a component through function calls. They were created to avoid the class-based nature of class components, and are generally simplier to use than class components too. You must follow the [Rules of Hooks](https://reactjs.org/docs/hooks-rules.html) at _all times_ while programming with hooks, or otherwise you can encounter undefined behavior that can crash your code (or worse). These two rules are actually pretty simple and are applied the same way in `isu`, but the second rule is interpreted differently.

In `isu`, hooks are the building blocks of a component and as such, can only be called in a renderer function passed to `isu.component` or in the functions that that the renderer calls, as long they remain within the execution flow of the renderer. The latter is often done to compose _custom hooks_, which you can see in the examples below.

For instance, the following example is _invalid_:
```lua
local x, setX = useState(0) -- used outside of a component, therefore errors
local counter = component(function()
    return 'TextLabel', { Text = x }
end)
```

The following example is _valid_:
```lua
local counter = component(function()
    local x, setX = useState(0) -- used within a component, therefore works
    return 'TextLabel', { Text = x }
end)
```

The following example is _also valid_, since it's within the execution flow of the rendering function:
```lua
local function customHook()
    local x, setX = useState(0)
    -- do something with x/setX
    return x
end

local counter = component(function()
    return 'TextLabel', { Text = customHook() }
end)
```

**Hooks work across yields** thanks to contextual coroutines. However, it is easy to make errors by becoming _too comfortable_ with the use of yields and tasks within components. Even though it is technically possible to yield and run asynchronous code within a renderer without issues, it is likely that you will have problems structuring your code in a way that avoids stack overflows or uselessly repeating expensive computations. Sometimes, you can even cause a memory leak by fundamentally misunderstanding the principle of the renderer.

```lua
-- DO NOT RUN THIS CODE! This problematic example is provided for educational purposes.
component(function()
    local time, setTime = useState(tick())
    task.spawn(function()
        while task.wait() do
            setTime(tick())
        end
    end)
    return 'TextLabel', { Text = time }
end)
```
The consequences of running the above code for some time results in the whooping consumption of over _21 GB_ of memory. Obviously, this is a problem, and it's caused by inadvertently causing a memory leak by spawning a new task _every time_ the component re-renders.

![You wouldn't want your code to crash people's computers, right?](https://i.imgur.com/FtuME2F.png)

**Hooks are provided to fix the above issue.** Instead of spawning the task _every single time the component renders_, you can spawn it once using a `useEffect` hook, which runs code only when the component is initially mounted.

```lua
component(function()
    local time, setTime = useState(tick())
    useEffect(function()
        task.spawn(function()
            while task.wait() do
                setTime(tick())
            end
        end)
    end)
    return 'TextLabel', { Text = time }
end)
```

**Every hook exists to solve a particular problem.** If writing something is unexpectedly hard, cumbersome, entirely impossible or strangely erroring for no apparent reason, then it's most likely that you need to use a hook to accomplish what you want to do. Over time, new hooks may be added to simplify certain recurring problems that prop up during development, but we'll try to keep it to a minimum.