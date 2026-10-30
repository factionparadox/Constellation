import QtQuick

// Constellation (MangoWM): Hyprland's global shortcuts do not exist on mango. Mango's key
// bindings call Caelestia's IPC instead (qs -c caelestia ipc call ...). Same properties and
// signals as Hyprland's GlobalShortcut, so the shell loads unchanged; it never fires.
QtObject {
    property string name
    property string description
    property string triggerDescription
    property string appid: "caelestia"
    signal pressed
    signal released
}
