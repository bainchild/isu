<p align='center'>
  <img size='200x200' src="https://i.imgur.com/s0zmkyV.png" alt="Logo of isu" width="274" height="157"/><br/>
  <b>isu</b>: a minimal, lightweight library for building reactive user interfaces in the Roblox engine.
</p>

## Overview
- isu is **minimal**. Building and rendering reactive components can be done with an extremely minimal number of calls.
- isu is **portable**. `isu` implements a complete reactive library in a single, portable, and documented file that can be imported anywhere into your game or script, complete with EmmyLua annotations for IDE use. When minified, `isu` goes below _8kb_.
- isu is **functional**. Its component library closely aligns with [React's hooks and functional components](https://reactjs.org/docs/hooks-intro.html), featuring familiar functions such as `useState` and `useEffect` that allows you to build components _without_ classes (or class-like behavior).
- isu has **batteries included.** It comes prepacked with hooks such as `useEvent` and `useTransition` that allows for the efficient composition of event connections and transitive animations, respectively, without the need to import third party libraries.

The `isu` philosophy is to avoid leaking a reference to the underlying Instance wherever possible, instead using pure functions to compose an instance contextually within a component, and relying as much as possible on readily-available library functions instead of data structures to create, access, and store reactive data. This results in a variety of paradigm changes that reduces most operations to simple, self-explanatory function calls instead of operating on classes or objects.

## Getting started
You can obtain the latest version of `isu` on the release page. As `isu` is unopinionated on how it is loaded, you are free to import it however you like. Normal Roblox procedure is to import it as a [ModuleScript](https://create.roblox.com/docs/reference/engine/classes/ModuleScript). The library returns everything you need to build reactive interfaces. In this example, we've made a simple counter that displays a click count, located inside a LocalScript parented to pre-existing ScreenGui in PlayerGui.
```lua
local isu = require(script:WaitForChild('isu'))
local component, useState, useEvent = isu.component, isu.useState, isu.useEvent

local counter = component(function()
	local count, setCount = useState(0)
	
	useEvent('MouseButton1Click', function()
		setCount(count + 1)
	end)
	
	return 'TextButton', {
		Size = UDim2.new(0, 200, 0, 200),
		Text = 'Clicks: ' .. count
	}
end)

counter()().Parent = script.Parent
```
You can read the in-depth introduction, further examples and the API reference [here](http://example.com).

## Roadmap
- [x] Functional stateful components powered by contexual coroutines.
- [x] Instance creation/updating with diffing to avoid unnecessary property mutation. 
- [x] Essential hooks such as `useState`, `useEffect` and mounting/unmounting behavior.
- [x] Event composition through `useEvent` to avoid leaking an object reference to the renderer.
- [x] Animation composition through `useTransition` to simplify tweening and avoid a [notorious Roact problem.](https://devforum.roblox.com/t/tweening-with-roact/83081/2)
- [x] Triggerable animations through `useAnimation`.
- [x] Subscription hooks such as `useSubscription` to create stateful derivable values that does not need the renderer to have an effect, such as when the value is used exclusively as an Instance property.
- [ ] Sequential animations by returning a list of transitions in `useTransition`.
- [ ] Proper documentation hosted on Github Pages

## History
I initially wrote `isu` as a way to fix some of the problems I personally had with [Roact](https://github.com/Roblox/roact) and [Fusion](https://github.com/Elttob/Fusion), as well as to quell my personal disagreement with some of their design choices. Even though I found Fusion to be much closer to what I wanted from a reactive framework, it doesn't use anything contextual for reconciliation and reactivity, instead relying on data structures such as `Computed` that are not associated by design to their rendered components. For better or for worse, I opted into designing a library that was far closer to React in usage, and that yielded `isu`.