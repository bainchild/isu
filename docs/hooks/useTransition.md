---
layout: default
title: useTransition
parent: Hooks
nav_order: 4
---

# `useTransition`

```ts
<void> useTransition(propertyName: string, tweenCalculator: (newValue: any, onTransitionEnd: (callback: function) => void) => TweenInfo)
```

Subjects an instance property to a transition (such as a tween) when it is mutated by the reconciliation/diffing process. `tweenCalculator` must be a function that returns the parameters to construct a new tween, and it can accept two arguments: the new value that will be transitioned to, and a callback that accepts a function which will be invoked when the transition ends.

**Important note:** This function is nowhere similar to React's own `useTransition`. Transition in this context is closer to CSS's definition of transition than React's.

**Example:**
```lua
useTransition('Position', function(newValue, onTransitionEnd)
    onTransitionEnd(function()
        print('Transition has ended.')
    end)
    return 0.3, Enum.EasingStyle.Quad
end)
```