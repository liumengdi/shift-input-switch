import Carbon
import Foundation

struct InputSourceRow {
    let id: String
    let localizedName: String
    let enabled: Bool
    let enableCapable: Bool
    let selectCapable: Bool
    let asciiCapable: Bool
    let languages: [String]
    let type: String
}

func property(_ source: TISInputSource, key: CFString) -> AnyObject? {
    guard let raw = TISGetInputSourceProperty(source, key) else {
        return nil
    }

    return Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue()
}

func boolProperty(_ source: TISInputSource, key: CFString) -> Bool {
    property(source, key: key) as? Bool ?? false
}

func stringProperty(_ source: TISInputSource, key: CFString) -> String? {
    property(source, key: key) as? String
}

func stringArrayProperty(_ source: TISInputSource, key: CFString) -> [String] {
    property(source, key: key) as? [String] ?? []
}

let filter = [
    kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource
] as CFDictionary

let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] ?? []
let rows = sources.compactMap { source -> InputSourceRow? in
    guard let id = stringProperty(source, key: kTISPropertyInputSourceID),
          let name = stringProperty(source, key: kTISPropertyLocalizedName) else {
        return nil
    }

    return InputSourceRow(
        id: id,
        localizedName: name,
        enabled: boolProperty(source, key: kTISPropertyInputSourceIsEnabled),
        enableCapable: boolProperty(source, key: kTISPropertyInputSourceIsEnableCapable),
        selectCapable: boolProperty(source, key: kTISPropertyInputSourceIsSelectCapable),
        asciiCapable: boolProperty(source, key: kTISPropertyInputSourceIsASCIICapable),
        languages: stringArrayProperty(source, key: kTISPropertyInputSourceLanguages),
        type: stringProperty(source, key: kTISPropertyInputSourceType) ?? ""
    )
}
.sorted { lhs, rhs in
    if lhs.enabled != rhs.enabled {
        return lhs.enabled && !rhs.enabled
    }

    return lhs.localizedName.localizedStandardCompare(rhs.localizedName) == .orderedAscending
}

for row in rows {
    let languages = row.languages.isEmpty ? "-" : row.languages.joined(separator: ",")
    print("""
    name=\(row.localizedName)
      id=\(row.id)
      enabled=\(row.enabled) enableCapable=\(row.enableCapable) selectCapable=\(row.selectCapable) asciiCapable=\(row.asciiCapable)
      languages=\(languages)
      type=\(row.type)
    """)
}
