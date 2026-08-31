import QtQuick
import QtQuick.Controls
import "Model.js" as Model
import "qml" as Components

Item {
    id: root

    property string moduleName: "crmartinez.onedrive"
    implicitWidth: 420
    implicitHeight: 280

    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e"
        radius: 12
        border.color: "#45475a"

        Column {
            anchors.centerIn: parent
            spacing: 12

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "OneDrive"
                color: "#cdd6f4"
                font.bold: true
                font.pixelSize: 20
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Connect your personal Microsoft account"
                color: "#a6adc8"
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Sign in"
                enabled: false
            }

            Components.DriveList {
                width: 360
                height: 120
                visible: false
                model: ListModel {}
            }
        }
    }
}