# HelloPlugin

A working third-party mach.notch plugin, built against the public SDK only.

```sh
swift build
swift test
```

Both run from this directory with no Xcode and no Tuist. That is the point: if
this package stops building, the Plugin SDK has stopped being consumable from
outside the repo.

## What it shows

| File | Demonstrates |
| --- | --- |
| `Sources/HelloPlugin/HelloPlugin.swift` | The six required `NotchPlugin` members, one optional UI slot, scoped service access, namespaced settings, and an event subscription released in `deactivate()`. |
| `Sources/HelloPlugin/HelloPluginDescriptor.swift` | Registration metadata, and `capabilities` as a permission grant rather than a hint. |
| `Tests/HelloPluginTests/HelloPluginTests.swift` | Identity stability, capability honesty, and that building a descriptor does not construct the plugin. |

## Starting your own

1. Copy this directory.
2. Change `id` to your own reverse-DNS identifier, in both the plugin and the
   descriptor. It is permanent — it keys the settings namespace and the enabled
   state, so changing it later orphans every user's configuration.
3. Replace `.package(path: "../../Packages/NotchPlugins")` with the released
   package.
4. Declare the narrowest `capabilities` that cover what you actually use.
   Reaching for an undeclared service group traps at activation, so it fails the
   first time you enable the plugin rather than in the field.

Full reference: [Plugin SDK docs](https://larsboes.github.io/mach-mono/plugins/overview).
