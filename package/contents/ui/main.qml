import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    property bool monitorsOn: true
    property bool busy: false
    property string pendingAction: ""
    property string lastError: ""

    readonly property string doctor: "/usr/bin/kscreen-doctor"

    readonly property string offCommand:
        doctor + " output.DP-2.disable output.DP-3.disable"

    // Re-enable first, then restore geometry/modes in a second KScreen call.
    // KWin/Wayland may need a short settle period before mode/position changes
    // are accepted for outputs that were fully disabled.
    readonly property string enableCommand:
        doctor + " output.DP-2.enable output.DP-3.enable"

    readonly property string restoreCommand:
        doctor +
        " output.DP-2.mode.1920x1080@60" +
        " output.DP-2.scale.0.85" +
        " output.DP-2.rotation.right" +
        " output.DP-2.position.0,0" +
        " output.DP-2.priority.3" +
        " output.DP-1.position.1271,550" +
        " output.DP-1.priority.1" +
        " output.DP-3.mode.1920x1080@74.97" +
        " output.DP-3.scale.1" +
        " output.DP-3.rotation.none" +
        " output.DP-3.position.3831,550" +
        " output.DP-3.priority.2"

    readonly property string statusCommand: doctor + " -o"

    Plasmoid.icon: "video-display"
    toolTipMainText: "DP-2 + DP-3"
    toolTipSubText: busy
        ? "Changing monitor state…"
        : (lastError.length
            ? lastError
            : (monitorsOn ? "External monitors are ON"
                          : "External monitors are OFF"))

    // For panel use, render the native Plasma button directly.
    preferredRepresentation: fullRepresentation
    activationTogglesExpanded: false

    function execute(command) {
        if (runner.connectedSources.indexOf(command) !== -1)
            runner.disconnectSource(command)
        runner.connectSource(command)
    }

    function setMonitorState(turnOn) {
        if (busy)
            return

        busy = true
        lastError = ""

        if (turnOn) {
            pendingAction = "enable"
            console.log("[DP23 Toggle] action ON stage 1: enable outputs")
            execute(enableCommand)
        } else {
            pendingAction = "off"
            console.log("[DP23 Toggle] action OFF")
            execute(offCommand)
        }
    }

    function refreshState() {
        if (!busy)
            execute(statusCommand)
    }

    function parseStatus(text) {
        // kscreen-doctor normally writes to stdout, but accept either stream.
        // Only change state if BOTH connector blocks are found; otherwise keep
        // the last known-good state rather than falsely forcing OFF.
        var dp2Block = text.match(/Output:\s+\d+\s+DP-2\b[\s\S]*?(?=Output:\s+\d+\s+|\s*$)/)
        var dp3Block = text.match(/Output:\s+\d+\s+DP-3\b[\s\S]*?(?=Output:\s+\d+\s+|\s*$)/)

        if (!dp2Block || !dp3Block) {
            console.log("[DP23 Toggle] status parse incomplete; preserving state")
            return false
        }

        var dp2On = /(^|\n)\s*enabled\s*(\n|$)/m.test(dp2Block[0])
        var dp3On = /(^|\n)\s*enabled\s*(\n|$)/m.test(dp3Block[0])

        monitorsOn = dp2On && dp3On
        console.log("[DP23 Toggle] detected DP-2:", dp2On,
                    "DP-3:", dp3On,
                    "combined:", monitorsOn)
        return true
    }

    Plasma5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var code = Number(data["exit code"])
            var stdout = data["stdout"] || ""
            var stderr = data["stderr"] || ""
            var combined = stdout + "\n" + stderr

            console.log("[DP23 Toggle] source finished:", sourceName, "exit:", code)

            disconnectSource(sourceName)

            if (sourceName === root.statusCommand) {
                if (code === 0) {
                    root.parseStatus(combined)
                } else {
                    root.lastError = "Status check failed: " +
                        (stderr.length ? stderr : "exit " + code)
                }
                return
            }

            if (code !== 0) {
                root.busy = false
                root.pendingAction = ""
                root.lastError = "kscreen-doctor failed: " +
                    (stderr.length ? stderr : "exit " + code)
                console.log("[DP23 Toggle] ERROR:", root.lastError)
                return
            }

            if (sourceName === root.offCommand) {
                root.monitorsOn = false
                root.busy = false
                root.pendingAction = ""
                console.log("[DP23 Toggle] state set OFF after successful action")
                settleTimer.restart()
                return
            }

            if (sourceName === root.enableCommand) {
                // Outputs exist again; wait briefly before restoring their
                // full geometry/mode configuration.
                root.pendingAction = "restore"
                root.monitorsOn = true
                console.log("[DP23 Toggle] ON stage 1 complete; waiting to restore layout")
                restoreTimer.restart()
                return
            }

            if (sourceName === root.restoreCommand) {
                root.monitorsOn = true
                root.busy = false
                root.pendingAction = ""
                console.log("[DP23 Toggle] ON stage 2 complete; layout restored")
                settleTimer.restart()
                return
            }

            root.busy = false
            root.pendingAction = ""
        }
    }

    Timer {
        id: restoreTimer
        interval: 750
        repeat: false
        onTriggered: {
            console.log("[DP23 Toggle] action ON stage 2: restore layout")
            root.execute(root.restoreCommand)
        }
    }

    Timer {
        id: settleTimer
        interval: 1200
        repeat: false
        onTriggered: root.refreshState()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refreshState()
    }

    Component.onCompleted: refreshState()

    fullRepresentation: PlasmaComponents.ToolButton {
        id: panelButton

        implicitWidth: Kirigami.Units.gridUnit * 2.6
        implicitHeight: Kirigami.Units.gridUnit * 2.0

        enabled: !root.busy
        display: PlasmaComponents.AbstractButton.IconOnly

        // Keep a standard panel-sized hit target while drawing a compact
        // toggle inside the button.
        contentItem: Item {
            implicitWidth: Kirigami.Units.gridUnit * 2.1
            implicitHeight: Kirigami.Units.gridUnit * 1.2

            Rectangle {
                id: track
                anchors.centerIn: parent
                width: Math.min(parent.width * 0.80, 34)
                height: Math.min(parent.height * 0.72, 18)
                radius: height / 2

                color: root.monitorsOn
                    ? Kirigami.Theme.highlightColor
                    : Kirigami.Theme.disabledTextColor
                opacity: root.busy ? 0.5 : 1.0

                Rectangle {
                    width: Math.max(8, parent.height - 4)
                    height: width
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.monitorsOn
                        ? parent.width - width - 2
                        : 2
                    color: Kirigami.Theme.backgroundColor

                    Behavior on x {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        onClicked: {
            console.log("[DP23 Toggle] BUTTON CLICK")
            root.setMonitorState(!root.monitorsOn)
        }
    }
}
