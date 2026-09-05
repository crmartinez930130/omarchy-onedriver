pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as Theme

ListView {
    id: root
    signal cancelRequested(string transferId)
    clip: true
    spacing: 4
    boundsBehavior: Flickable.StopAtBounds

    delegate: Item {
        id: row
        required property string transferId
        required property string name
        required property string transferState
        required property real bytesCompleted
        required property real bytesTotal

        readonly property bool cancellable: transferState === "running" || transferState === "queued"
        readonly property real fraction: bytesTotal > 0 ? Math.min(1, bytesCompleted / bytesTotal) : 0
        readonly property color stateColor: transferState === "failed" ? Theme.error
            : transferState === "completed" ? Theme.success : Theme.accent

        width: root.width
        height: 40

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: row.name
                    color: Theme.text
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: row.transferState + (row.cancellable && row.bytesTotal > 0 ? " · " + Math.round(row.fraction * 100) + "%" : "")
                    color: row.stateColor
                    font.pixelSize: 11
                }

                ToolButton {
                    visible: row.cancellable
                    implicitWidth: 20
                    implicitHeight: 20
                    background: Item {}
                    contentItem: Text {
                        text: "✕"
                        color: Theme.textMuted
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: root.cancelRequested(row.transferId)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                radius: 1.5
                color: Theme.surfaceHover
                visible: row.cancellable

                Rectangle {
                    width: parent.width * row.fraction
                    height: parent.height
                    radius: 1.5
                    color: Theme.accent
                }
            }
        }
    }
}
