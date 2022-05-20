---
title: Use outside of Roblox
---

# Can I use `isu` outside of the Roblox engine?

**Yes.** As `isu` is written in plain Lua and doesn't rely on Roblox-specific syntax additions, the library will compile and run in Lua 5.1+ runtimes. That said, using any default component factories (such as `isu.component` and `isu.hydrate`) will result in assertion errors as Roblox's instantiation library will be missing.

_However_, you can definitely use the builder library to componentize your own data structures and apply reactivity wherever you need it. So while the default factories and hydrators are written specifically for Roblox's instances, you can still create reactive components by defining builders as explained in our [building section](builder/index.md), and make use of hooks such as `useState` and `useEffect`.