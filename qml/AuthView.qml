import QtQuick
import QtQuick.Controls

Column {
    signal loginRequested()
    spacing: 12
    Label { text: "Sign in to OneDrive" }
    Button { text: "Sign in"; onClicked: loginRequested() }
}