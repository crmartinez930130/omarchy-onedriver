import QtQuick
import QtQuick.Controls
import "../Theme.js" as Theme

Column {
    id: root
    property string fontFamily: "monospace"
    signal loginRequested()
    spacing: 14

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "󰏊"
        color: Theme.accent
        font.family: root.fontFamily
        font.pixelSize: 40
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Connect your OneDrive account"
        color: Theme.text
        font.pixelSize: 14
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Personal Microsoft accounts only"
        color: Theme.textDim
        font.pixelSize: 11
    }

    Button {
        id: signInButton
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Sign in"
        onClicked: loginRequested()

        contentItem: Text {
            text: signInButton.text
            color: Theme.background
            font.bold: true
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 8
            implicitWidth: 110
            implicitHeight: 34
            color: signInButton.down ? Qt.darker(Theme.accent, 1.15) : Theme.accent
        }
    }
}
