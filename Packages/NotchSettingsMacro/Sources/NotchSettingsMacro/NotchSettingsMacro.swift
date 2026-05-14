@attached(peer, names: arbitrary)
public macro Setting<T>(key: String? = nil, default: T) = #externalMacro(module: "NotchSettingsMacroPlugin", type: "SettingMacro")
