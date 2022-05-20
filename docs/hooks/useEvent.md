---
layout: default
title: useEvent
parent: Hooks
nav_order: 3
---

# `useEvent`

```ts
<void> useEvent(eventName: string, callback: function)
```

Connects `callback` to the constructed object's event named `eventName`. The event must be directly indexable using the supplied name (for instance, property change events requiring `GetPropertyChangedSignal` cannot be accessed using useEvent and requires special syntax). The callback signal will be dynamically disconnected and reconnected at multiple points during the lifecycle of the component, and the state of the component can be updated at will during an event's invocation.

**Example used on a TextLabel:**
```lua
component(function()
	useEvent('MouseButton1Click', function()
		print('The instance has been clicked!')
	end)
	return 'TextLabel', { Size = UDim2.new(0, 100, 0, 100) }
end)
```