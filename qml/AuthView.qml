import QtQuick
import QtQuick.Controls
import "../Theme.js" as Theme

Column {
    id: root
    property string fontFamily: "monospace"
    property string title: "Connect your OneDrive account"
    property string subtitle: "Personal Microsoft accounts only"
    property string signInLabel: "Sign in"
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
        text: root.title
        color: Theme.text
        font.pixelSize: 14
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.subtitle
        color: Theme.textDim
        font.pixelSize: 11
    }

    Button {
        id: signInButton
        hoverEnabled: true
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.signInLabel
        leftPadding: 20
        rightPadding: 20
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
            implicitHeight: 34
            color: signInButton.down ? Qt.darker(Theme.accent, 1.3)
                : (signInButton.hovered ? Qt.darker(Theme.accent, 1.15) : Theme.accent)
        }
    }
}
