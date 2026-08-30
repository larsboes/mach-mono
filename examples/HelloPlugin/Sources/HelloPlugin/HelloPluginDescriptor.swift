import NotchPluginCore

extension HelloPlugin {

    /// Registration metadata. The host reads this without constructing the plugin,
    /// so a disabled plugin costs nothing at launch.
    ///
    /// `capabilities` is a permission grant, not just a UI hint: the plugin can
    /// reach `context.mediaServices` because `.mediaServices` is declared here,
    /// and reaching for any other service group would trap at activation.
    public static func makeDescriptor() -> PluginDescriptor {
        PluginDescriptor(
            id: "com.example.hello",
            metadata: HelloPlugin().metadata,
            origin: .external("com.example.hello"),
            capabilities: [.mediaServices, .expandedPanelContent],
            factory: { HelloPlugin() }
        )
    }
}
