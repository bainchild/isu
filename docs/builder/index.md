---
layout: default
title: Builder
has_children: true
---

# Builder

**`isu`'s builder allows you to componentize pretty much anything you want.** Whereas most reactive libraries limits you to components based on native Instances, `isu` allows you to compose components for _any data structure_. To do this, you simply need to create a component builder through the `isu.builder` function, which `isu` uses itself to create the Instance component builder available at `isu.component`.

**Creating a component builder requires you to have good knowledge of how reactive libraries work internally.** Reconciliation, diffing and conditional mutation, despite being relatively simple concepts, _must_ be grasped before implementing a builder since `isu` does not provide these facilities out of the box for third party use (_you could fork `isu` and extract our implementations for your own use, but they were written specifically for Roblox instances._)

To implement a builder though `isu.builder`, you must provide two distinct functions:
- The **instantiator**, which creates an instance of the data structure you want to componentize, and applies the passed properties **without caching or optimizations.** It must accept a class name and a dictionary of properties, which can optionally include an array component (_values with numbers as key_) listing children. However, the array can be safely ignored if it is irrelevant in your use case.
- The **mutator**, which accepts an already-existing instance and a dictionary of properties. It is during mutation that animations must be triggered and diffing applied - most of the optimization is done here. Generally, the implementation can be very similar to the one found in the instantiator, but without instance creation and most preferably with caching of the properties so you can avoid useless overwrites when the new value is the same as the old one.

With these two functions, **`isu` will provide reactivity to your built components.** They will be able to use stateful values (`useEffect`), effects (`useEffect`) and more if implemented. However, not _all_ hooks are immediately available since some requires special consideration in your callbacks.
- The `useTransition` and `useAnimation` hooks require that your mutator index the current context's `transitions` and `animations` stacks respectively, and executes the animations in order. [You can read `isu`'s own `mutateConditionally` function in the source code](https://github.com/ccreaper/isu/blob/main/isu.lua) to understand how `isu` applies transitions and animations to Instances. If this is implemented, you can set the `useTransition` and `useAnimation` hooks to `true` in your `isu.builder` call.
- The `useEvent` hook by default indexes the context and disconnects the signal depending on the component lifecycle. Unless your event mechanism supports the `:Disconnect` method **and** your instantiator/mutator assigns a `.connection` field to event objects in the context's `events` stack, it is recommended to leave `useEvent` off. If you can guarantee that your event syntax is interchangeable with Roblox's event syntax, and your instantiator/mutator properly assigns `.connection` to the event object in the contextual event stack, then you can _probably_ turn `useEvent` on in your builder options.
- The `useSubscription` hook relies on special behavior in the instantiator and mutator. When any property-changing mechanism detects a subscription object as a value for any property (_doable by verifying if the object is a table **and** has a `__type` metafield equal to `'Subscription'`_), it needs to set the property to `{subscriptionObject}.value` and map the property to a property setting function accepting a single value in the dictionary located at `{subscriptionObject}.represents.listeners`. This is generally the easiest special hook to implement.

Here is an example in pseudocode that defines a simple component builder for tables. It obviously isn't feature-complete nor optimized, but should provide a general overlook at how a component builder is created.
```lua
local isu = require(...) -- locate the isu module or file
local someEventListener = ... -- function that connects a callback to an event
local someEventTrigger = ... -- function that triggers the event

local createTableComponent = isu.builder(function(className, properties)
    local newTable = setmetatable({}, { __type = className })

    for key, value in pairs(properties) do
        newTable[key] = value
    end

    return newTable
end, function(existingTable, newProperties)
    for key, value in pairs(newProperties) do
        existingTable[key] = value
    end
end)

local myComponent = createTableComponent(function(props)
    local count, setCount = useState(0)

    someEventListener(function()
        setCount(count + 1)
    end)

    return 'myTableType', {
        value = count
    }
end)

local myInstance = myComponent()()
print(myInstance.value) -- should be 0
someEventTrigger()
print(myInstance.value) -- should be 1
```