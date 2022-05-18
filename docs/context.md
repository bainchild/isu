---
title: The contextual approach
---

# The contextual approach

If you have ever used React (_or similar reactive frameworks_) in the past, you may have wondered how hooks such as `useState` become aware of the component they must interact with. This is especially interesting since hooks _does not_ accept a reference to any component or object, and seemingly stores and applies their values to rendered components like magic. It's actually nothing like magic.

In the case of React, they use what is called a [dispatcher](https://github.com/facebook/react/blob/835d9c9f4724b71b429a6b7aaced6da1448e7fb8/packages/react/src/ReactHooks.js#L24) to store a reference to the component that is currently being manipulated. It basically stores the component information in a global variable whenever it enters that component's code, and hooks retrieve the information from [that one global variable](https://github.com/facebook/react/blob/main/packages/react/src/ReactCurrentDispatcher.js). This approach works in JavaScript and many other languages because they commonly end up in runtime implementations where they are subject to [event loops and job queues](https://www.youtube.com/watch?v=8aGhZQkoFbQ) that enforces single-threadedness, which means it is impossible for the dispatcher to be used or overwritten by two threads working at the same time and therefore atomicity doesn't have to be enforced through [critical sections](https://en.wikipedia.org/wiki/Critical_section) or [mutexes](https://en.wikipedia.org/wiki/Lock_(computer_science)). The use of coroutines in JavaScript is also relatively rare outside of automatically-generated code ([_polyfills_](https://en.wikipedia.org/wiki/Polyfill_(programming))) in compilers such as Babel, which means problems of concurrency are rarely a problem in JavaScript.

However, the convenience of event loops and single-threadedness isn't always best, and some runtimes/languages have varying models of concurrency that _allows_ a single resource to be used across threads or coroutines. This is more common in languages operating closer to the metal, such as `C`/`C++`, which can have completely independent threads whose scheduling is left to the processor if not explicitly managed by the program. Some models of concurrency, most relevantly the one implemented in Roblox as the [_task scheduler_](https://developer.roblox.com/en-us/articles/task-scheduler) for their Luau runtime, can also face race condition-like problems due to the prevalence of coroutine use. Because of this, `isu` was developed in a way that doesn't rely on a React-like dispatcher retrieval mechanism, and instead doubles down on being coroutine-agnostic by employing their use _as a way_ to store and retrieve context.

## Implementing thread-local storage for contextual execution

Many languages implement [thread-local storage](https://en.wikipedia.org/wiki/Thread-local_storage#Python), which is memory specifically allocated to a thread that is generally only accessible by it. Roblox themselves make use of TLS as to provide [independently running threads with distinct identities](https://roblox.fandom.com/wiki/Security_context), which can restrict their access to some parts of the engine and prevent security vulnerabilities or bad things from happening in general. However, Lua does not come* with any mechanism for thread-local storage out of the box, but that doesn't mean it cannot be implemented.

`isu` implements thread-local storage by globally storing a weak dictionary of coroutine objects to their context table, and implementing interfacing functions such as `getContext`, `setContext` and `withContext` that can manipulate the TLS. Whenever an execution flow requires thread-local storage for contextual execution, such as when a component must render, `isu` wraps the callback to be "contextualized" with a coroutine, then maps the coroutine to its context in the weak dictionary. The coroutine then can retrieve its context from the weak dictionary at any given time by indexing it with itself. A sample implementation of TLS in Lua would look like this:

```lua
local tls = {}
local _store = {}

function tls.get()
    return _store[coroutine.running()]
end

function tls.set(value)
    _store[coroutine.running()] = value
end

return tls
```

The `isu` implementation of TLS is more complex, using a weak dictionary to prevent the potentially leaky storing of contexts and coroutines whose sole existence is ready to be purged by the garbage collector. The framework mainly stores resetable `Accumulator` structures inside of the context, which allows successive hook invocations to reuse memoized (cached) data. For instance, every time `useState` is called within a contextualized coroutine, it tries to index the state accumulator's stack with its current index and see if a state already exists at that index. If the state exists, then it just returns its current value alongside its updater, but otherwise instanciates a new state and creates the updater. In either case, the accumulator's index is incremented, allowing the subsequent `useState` invocation to refer to another piece of data. The accumulators are reset every time `isu` assigns a component context to a coroutine.

## *Upvalues as Lua's contextualized execution mechanism?

While initially looking at implementing TLS for `isu`, I tried to leverage Lua's upvalue system as the basis for contextualized execution. After all, upvalues are instanciated every time a closure is allocated, which would allow distinct components to store their states and other hook-related data in a centralized table that can then be passed down to the renderer. The issue with this method however is that it replicates one of the design features in Roact I've found distasteful, which is passing the component's state down to the renderer directly for manipulation and access.

Passing the state down is not necessarily a bad thing, with itself leveraging the centralizing opportunity of objects. This object-oriented method is attractive to many programmers, but for those looking for a more purely functional approach, it is obviously not what they're seeking. React _thankfully_ provides functional components empowered by hooks that fulfills this need, but this paradigm is entirely lacking in Roact, and isn't used everywhere in Fusion as it still relies on a lot of objects for storing, accessing and updating data in stateful components.