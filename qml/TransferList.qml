pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

ListView {
    id: root
    signal cancelRequested(string transferId)
    clip: true
    spacing: 2

    delegate: ItemDelegate {
        id: delegate
        required property string transferId
        required property string name
        required property string transferState
        required property real bytesCompleted
        required property real bytesTotal

        readonly property bool cancellable: transferState === "running" || transferState === "queued"
        readonly property string progress: bytesTotal > 0 ? Math.round(100 * bytesCompleted / bytesTotal) + "%" : ""

        width: root.width
        text: name + " — " + transferState + (cancellable && progress !== "" ? " (" + progress + ")" : "")
        enabled: cancellable
        onClicked: root.cancelRequested(transferId)
    }
}
