import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Set accessory mode so it operates as a background utility without showing a Dock icon
app.setActivationPolicy(.accessory)

app.run()
