import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "qml" as Components

Item {
    id: root

    property string moduleName: "crmartinez.onedrive"
    property var service: null

    implicitWidth: 380
    implicitHeight: 460

    ListModel { id: itemsModel }
    ListModel { id: transfersModel }

    function _syncItems() {
        itemsModel.clear()
        var list = service ? service.items : []
        for (var i = 0; i < list.length; i++) {
            var entry = list[i]
            itemsModel.append({
                itemId: entry.id,
                name: entry.name,
                isFolder: entry.isFolder,
                size: entry.size
            })
        }
    }

    function _syncTransfers() {
        transfersModel.clear()
        var list = service ? service.transfers : []
        for (var i = 0; i < list.length; i++) {
            var transfer = list[i]
            transfersModel.append({
                transferId: transfer.id,
                name: transfer.name,
                transferState: transfer.state,
                bytesCompleted: transfer.bytesCompleted,
                bytesTotal: transfer.bytesTotal
            })
        }
    }

    onServiceChanged: { _syncItems(); _syncTransfers() }

    Connections {
        target: root.service
        function onItemsChanged() { root._syncItems() }
        function onTransfersChanged() { root._syncTransfers() }
    }

    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e"
        radius: 12
        border.color: "#45475a"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: "OneDrive"
                    color: "#cdd6f4"
                    font.bold: true
                    font.pixelSize: 20
                    Layout.fillWidth: true
                }

                BusyIndicator {
                    running: root.service ? root.service.busy : false
                    implicitWidth: 18
                    implicitHeight: 18
                }

                Button {
                    text: "Sign out"
                    visible: root.service && root.service.signedIn
                    onClicked: root.service.logout()
                }
            }

            Components.AuthView {
                Layout.fillWidth: true
                visible: !(root.service && root.service.signedIn)
                onLoginRequested: if (root.service) root.service.login()
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.service && root.service.signedIn
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        text: "‹ Back"
                        enabled: root.service && root.service.folderStack.length > 0
                        onClicked: root.service.goBack()
                    }

                    Label {
                        text: root.service ? root.service.currentFolderName : ""
                        color: "#a6adc8"
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "⟳"
                        onClicked: if (root.service) root.service.refresh()
                    }
                }

                Components.DriveList {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: itemsModel
                    onFolderRequested: function (itemId, name) { root.service.openFolder(itemId, name) }
                    onFileRequested: function (itemId, name) { root.service.startDownload(itemId, name) }
                }

                Label {
                    visible: root.service && root.service.lastError !== ""
                    text: root.service ? root.service.lastError : ""
                    color: "#f38ba8"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Label {
                    visible: transfersModel.count > 0
                    text: "Transfers"
                    color: "#a6adc8"
                }

                Components.TransferList {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    visible: transfersModel.count > 0
                    model: transfersModel
                    onCancelRequested: function (transferId) { root.service.cancelTransfer(transferId) }
                }
            }
        }
    }
}
