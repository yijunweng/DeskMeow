import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: OverlayWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        guard let screen else {
            assertionFailure("No active screen found")
            NSApp.terminate(nil)
            return
        }

        let controller = OverlayWindowController(screenFrame: screen.frame)
        controller.showWindow(nil)
        overlayController = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlayController?.shutdown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func application(_ sender: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        // Placeholder for future remote notifications
    }
}
