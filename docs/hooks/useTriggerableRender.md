---
layout: default
title: useTriggerableRender
parent: Hooks
nav_order: 7
---
# `useTriggerableRender`

```ts
<function> useTriggerableRender()
```

Returns a callback that re-renders the component when invoked. Avoids React's [forced re-render problem](https://stackoverflow.com/questions/46240647/react-how-to-force-a-function-component-to-render/53837442) in functional components, which is essentially the only thing that class-based components does better than functional components (at least in React).

**Do not call this directly in the renderer.** You will enter an unescapable infinite loop. Use this function _exclusively_ as part of a hook that you know will not be invoked every single render, or anywhere else in your code that simply isn't within the direct execution flow of the renderer.

**Example:**
```lua
local render = useTriggerableRender()
useEvent('MouseButton1Click', function()
	render() -- re-render the component on click
end)
```