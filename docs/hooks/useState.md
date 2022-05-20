---
layout: default
title: useState
parent: Hooks
nav_order: 1
---

# `useState`

```ts
<[any, (newValue: any)]> useState(defaultValue: any)
```

Creates a stateful variable, which is a reactive value that can be dynamically updated. The variable is bound to the component in which it has been declared, and any changes made to the variable through its updater function will automatically re-render the component. For more information: https://reactjs.org/docs/hooks-reference.html#usestate

**Example:**
```lua
component(function()
	local count, setCount = useState(0)
	
	useEvent('MouseButton1Click', function()
		setCount(count + 1)
	end)
	
	return 'TextButton', {
		Size = UDim2.new(0, 200, 0, 200),
		Text = 'Clicks: ' .. count
	}
end)
```