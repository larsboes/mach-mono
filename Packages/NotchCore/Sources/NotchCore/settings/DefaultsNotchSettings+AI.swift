//
//  DefaultsNotchSettings+AI.swift
//  NotchCore
//

import Defaults
import NotchSettingsMacro

public extension DefaultsNotchSettings {

    @Setting<Bool>(key: "omlxProviderEnabled", default: false)
    var omlxProviderEnabled: Bool {
        get { Defaults[Self.omlxProviderEnabledKey] }
        set { Defaults[Self.omlxProviderEnabledKey] = newValue }
    }

    @Setting<String>(key: "omlxProviderHost", default: "http://127.0.0.1:8000/v1")
    var omlxProviderHost: String {
        get { Defaults[Self.omlxProviderHostKey] }
        set { Defaults[Self.omlxProviderHostKey] = newValue }
    }

    @Setting<String?>(key: "omlxPreferredModelId", default: nil)
    var omlxPreferredModelId: String? {
        get { Defaults[Self.omlxPreferredModelIdKey] }
        set { Defaults[Self.omlxPreferredModelIdKey] = newValue }
    }

    @Setting<Bool>(key: "omlxAllowNonLocalhostHost", default: false)
    var omlxAllowNonLocalhostHost: Bool {
        get { Defaults[Self.omlxAllowNonLocalhostHostKey] }
        set { Defaults[Self.omlxAllowNonLocalhostHostKey] = newValue }
    }
}
