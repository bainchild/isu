---
layout: default
title: useAnimation
parent: Hooks
nav_order: 5
---

# `useAnimation`

```ts
<(newValue: any) => void> useAnimation(propertyName: string, tweenCalculator: (newValue: any, onTransitionEnd: (callback: function) => void) => TweenInfo)
```

Returns a function that animates a property upon invocation. `useAnimation` accepts the same arguments as `useTransition` and their behavior is the same, but while `useTransition` applies an animation _when_ a property is mutated, `useAnimation` only applies an animation when the user requests it through the returned callback, passing the new value to animate to as an argument.

**Take note that the callback does not immediately trigger the animation.** Instead, it schedules it to be performed on the next re-render, similarly to `useTransition`'s mechanism. In most cases, the animation should be performed straight away as hook usage often triggers a re-render, but in the case that it doesn't, you can manually force a re-render through `useTriggerableRender` after scheduling your animation(s).

**Example:**
```lua
local rerender = useTriggerableRender()
local anim = useAnimation('Position', function(newValue, onTransitionEnd)
    onTransitionEnd(function()
        print('Transition has ended.')
    end)
    return 0.3, Enum.EasingStyle.Quad
end)
useEvent('MouseButton1Click', function()
    anim(UDim2.new(0, 100 * math.random(), 0, 100 * math.random()))
    rerender()
end)
```