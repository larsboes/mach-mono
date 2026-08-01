//
//  machNotchApp.swift
//  machNotchApp
//
//  Created by Harsh Vardhan  Goswami  on 02/08/24.
//

#if MACH_NOTCH_SOUNDSCAPE
import machNotchWithSoundscape
#else
import machNotch
#endif

@main
enum DynamicNotchApp {
    static func main() {
        #if MACH_NOTCH_SOUNDSCAPE
        machNotchWithSoundscape.MachNotchAppRoot.main()
        #else
        machNotch.MachNotchAppRoot.main()
        #endif
    }
}
