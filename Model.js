.pragma library

function driveItem(item) {
    return {
        id: item.id || "",
        name: item.name || "",
        isFolder: !!item.folder,
        size: item.size || 0,
        modified: item.lastModifiedDateTime || "",
        webUrl: item.webUrl || ""
    }
}

function items(payload) {
    return (payload.items || []).map(driveItem)
}