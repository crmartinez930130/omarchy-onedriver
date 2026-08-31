import QtQuick
import QtQuick.Controls

ListView {
    id: root
    property alias transfers: root.model
    signal cancelRequested(string transferId)
    clip: true
    delegate: ItemDelegate {
        width: root.width
        text: model.name + " — " + model.state
        enabled: model.state === "running" || model.state === "queued"
        onClicked: root.cancelRequested(model.id)
    }
}