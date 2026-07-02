//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

enum AppLayout {
    /// Whether to use the wide layout (iPad and Mac Catalyst), as opposed to the
    /// compact iPhone layout. Driven by the horizontal size class rather than the
    /// idiom so it also covers Catalyst and multitasking split views.
    static func usesWideLayout(horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
        horizontalSizeClass == .regular
    }
}
