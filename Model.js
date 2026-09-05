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

function formatBytes(bytes) {
    var value = Number(bytes || 0)
    if (!isFinite(value) || value <= 0) return "0 B"
    var units = ["B", "KB", "MB", "GB", "TB"]
    var index = 0
    while (value >= 1000 && index < units.length - 1) {
        value = value / 1000
        index++
    }
    var decimals = value >= 100 || index === 0 ? 0 : (value >= 10 ? 1 : 2)
    return value.toFixed(decimals) + " " + units[index]
}