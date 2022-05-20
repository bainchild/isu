---
layout: default
title: useEffect
parent: Hooks
nav_order: 2
---

# `useEffect`

```ts
<void> useEffect(fn: function, triggers?: any[])
```

Applies lifecycle hooks to the current component based on `fn`'s behavior. If no states are supplied, then the callback will be invoked when the component is first rendered, and its return value, which can be a function, will be invoked when the component is unmounted. If no function is returned, then nothing will be invoked at unmount. If some states are supplied, then the effect hook will only execute when these specific states are updated. For more information: https://reactjs.org/docs/hooks-reference.html#useeffect

**Example:**
```lua
component(function()
	local count, setCount = useState(0)
	local anotherCount, setAnotherCount = useState(0)

	useEffect(function()
		print("Called once after the component's first render!")
		return function()
			print("Called once after the component unmounts!")
		end
	end)

	useEffect(function()
		print("Called when count changes, but not anotherCount!")
	end, {count})

	useEvent('MouseButton1Click', function()
		setCount(count + 1)
		setAnotherCount(count + 1)
	end)
	
	return 'TextButton', {
		Size = UDim2.new(0, 200, 0, 200),
		Text = 'Clicks: ' .. count
	}
end)
```