---
layout: default
title: useSubscription
parent: Hooks
nav_order: 6
---
# `useSubscription`

```ts
<function> useSubscription(defaultValue: any)
```

Creates a subscription-based stateful value. This hook serves as a more performant
alternative to `useState` when the value only needs to be accessed and updated within another hook (such as `useEvent` or `useEffect`) and not within the renderer function directly. When a subscription's value updates, the value is directly applied to the Instance instead of passing through the library's reconciliation and diffing process, which invokes the renderer. The usual use of a subscription is when a value is used exclusively within an Instance's properties. 

**Subscriptions should not be used if your code repeatedly needs to read its value.** Occasional access through hooks is fine, but `useState` is the superior option to use if your renderer needs to access the value regularly, since the subscription's method of reading is less performant.

`useSubscription` returns a single function which, when called with no arguments, returns the current value. However, when it is called with a single argument, the value of the subscription is updated to the value passed through the argument and the Instance is updated accordingly. Only this function is necessary, but for compatibility with the `useState` syntax, a second function will also be returned that exclusively updates the value of the subscription.

**Example:**
```lua
local time = useSubscription(workspace.DistributedGameTime)
print("This should only be printed once, unlike the useState hook!")
useEffect(function()
	task.spawn(function()
		while task.wait() do
			time(workspace.DistributedGameTime)
		end
	end)
end)
return 'TextButton', { Size = UDim2.new(0, 200, 0, 200), Text = time }
```