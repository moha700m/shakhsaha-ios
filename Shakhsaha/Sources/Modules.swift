import Foundation

/// Full-system scan over ISO 15765 CAN with physical addressing (ATSH) and UDS 0x19 ReadDTCInformation.
/// Only reads. Modules that don't answer are reported honestly as "not reachable with ELM327".
struct ECUModule: Identifiable, Hashable {
    let id: String
    let ar: String
    let en: String
    let header: String     // request CAN id
    let img: String
    var name: String { L(ar, en) }
}

enum ModuleStatus: Equatable {
    case pending, scanning, ok(Int), noResponse, generic
}

struct ModuleResult: Identifiable {
    var id: String { module.id }
    let module: ECUModule
    var status: ModuleStatus
    var codes: [String]
}

enum Modules {
    /// Common physical request ids. Many Toyota/Hyundai/Kia/Nissan/Ford/GM CAN vehicles answer on these; others won't.
    static let all: [ECUModule] = [
        ECUModule(id: "engine", ar: "المحرك", en: "Engine (ECM)", header: "7E0", img: "Engine"),
        ECUModule(id: "trans", ar: "القير", en: "Transmission (TCM)", header: "7E1", img: "Engine"),
        ECUModule(id: "abs", ar: "الفرامل ABS", en: "ABS / Brakes", header: "7B0", img: "Maint"),
        ECUModule(id: "abs2", ar: "الفرامل (عنوان بديل)", en: "ABS (alt. address)", header: "760", img: "Maint"),
        ECUModule(id: "srs", ar: "الإيرباقات", en: "Airbag (SRS)", header: "780", img: "Report"),
        ECUModule(id: "srs2", ar: "الإيرباقات (عنوان بديل)", en: "Airbag (alt. address)", header: "7D2", img: "Report"),
        ECUModule(id: "bcm", ar: "البودي BCM", en: "Body (BCM)", header: "750", img: "Report"),
        ECUModule(id: "bcm2", ar: "البودي (عنوان بديل)", en: "Body (alt. address)", header: "726", img: "Report"),
        ECUModule(id: "hvac", ar: "المكيف", en: "Climate (HVAC)", header: "7C4", img: "Heat"),
        ECUModule(id: "cluster", ar: "الطبلون", en: "Instrument cluster", header: "7C0", img: "Report"),
    ]

    /// Parses UDS 59 02 <mask> [DTC_HI DTC_MID DTC_LO STATUS]* (3-byte DTCs, shown as SAE 2-byte code).
    static func parseUDS(_ raw: String) -> [String]? {
        if ELMParser.isError(raw) { return nil }
        let b = ELMParser.bytes(raw)
        if b.contains(0x7F) && !b.contains(0x59) { return nil }  // negative response
        guard let i = b.firstIndex(of: 0x59), i + 2 < b.count, b[i + 1] == 0x02 else { return nil }
        var out: [String] = []
        var j = i + 3
        while j + 3 < b.count {
            let st = b[j + 3]
            if (b[j] != 0 || b[j + 1] != 0) && st & 0x09 != 0 {   // testFailed or confirmed
                let c = ELMParser.dtcString(b[j], b[j + 1])
                if !out.contains(c) { out.append(c) }
            }
            j += 4
        }
        return out
    }
}
