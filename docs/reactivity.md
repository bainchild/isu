---
title: Introduction to reactivity
---

# Introduction to reactivity

If _reactivity_ is a new concept for you, then you will surely enjoy its use in programming. Reactivity, in a word, is the composition of objects whose properties are dynamically updated as you change their values in your code. If we take the example of an object whose rendered text reflects a mouse click counter, in conventional programming, you would have to manually re-assign the object's text to a string representing the count every time a mouse click is detected through an event. This is not really hard for most developers, but it can be redundant.

A reactive framework abstracts away the procedure of taking a value and assigning it to an object every time something occurs. If we reuse the example of the mouse click counter, with a reactive framework, you can simply tell it to declare a value and point your object's text property to that value. Now, every single time you change the value when a mouse click is detected, the reactive framework will intelligently detect that the value has changed and update your object accordingly, saving you time.

Compare these two snippets of (_pseudo_)code. The first example was written without reactivity using Roblox's APIs, and the second was written with reactivity in a framework inspired by `isu`.

```lua
local clicks = 0
local counter = Instance.new("TextButton")
counter.Size = UDim2.new(0, 100, 0, 100)
counter.Text = 'Clicks: 0'

counter.MouseButton1Click:Connect(function()
    clicks = clicks + 1
    counter.Text = 'Clicks: ' .. clicks
end)
```

```lua
local counter = component(function(props)
    local clicks, setClicks = useState(0)
    useEvent('MouseButton1Click', function()
        setClicks(clicks + 1)
    end)
    return 'TextButton', { Size = UDim2.new(0, 100, 0, 100), Text = 'Clicks: ' .. clicks }
end)()()
```

The first example manually instanciates the TextButton and assigns its default properties. It then listens to the `MouseButton1Click` event with a callback that increments the counter by 1 every time it fires, then computes the text property from the previously calculated value before assigning it to the object. **This method stores, accesses and updates the clicker imperatively and assigns it to the counter manually, meaning you are responsible for detecting and applying the changed counter.**

The second example, instead, declares a value through `useState`. It tells the framework that it should listen to the `MouseButton1Click` event with a callback that increments the value using its updater. It ends by simply returning the instance it wants to create, alongside the properties it should have, including the computed `Text` property. **Even though you are not updating the instance directly anywhere, the framework will detect whenever the `clicks` state is updated and re-render the implicitly created TextButton accordingly.**

The `useState` function is called a _hook_, which is a function whose results are [memoized](https://en.wikipedia.org/wiki/Memoization). In short, even though the renderer function passed to `component` will be invoked every time the state is modified, `useState` will _not_ always declare a new variable and instead return the previously stored value and updater whenever it is reused across renders. The same principle is applied for every hook, and their stateful data is stored within a _context_, which is an object tied to a specific execution flow that is reset when the execution flow exits. You will not have to interact with the _context_ at any point while using a reactive framework like `isu`, unless you are extending the framework. [You can learn more about `isu`'s contextual approach here.](context.md)