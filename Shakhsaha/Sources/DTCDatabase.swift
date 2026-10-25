import Foundation

enum Severity: Int, Codable, Comparable {
    case low = 1, medium = 2, high = 3
    static func < (a: Severity, b: Severity) -> Bool { a.rawValue < b.rawValue }
    var title: String {
        switch self {
        case .low: return L("بسيط", "Low")
        case .medium: return L("متوسط", "Medium")
        case .high: return L("عالي، وقّف السيارة", "High, stop driving")
        }
    }
}

struct DTCInfo: Identifiable, Codable, Hashable {
    var id: String { code }
    let code: String
    let titleAr: String
    let titleEn: String
    let severity: Severity
    let system: String      // engine, fuel, ignition, emissions, cooling, transmission, electrical, network, body, chassis
    let causesAr: [String]
    let causesEn: [String]
    var title: String { L(titleAr, titleEn) }
    var causes: [String] { L10n.lang == .ar ? causesAr : causesEn }
}

/// Offline DTC knowledge base: common generic SAE J2012 codes seen on Saudi-market cars,
/// with Saudi-dialect explanations generated from templates (no network, no AI service).
enum DTCDatabase {
    private static func e(_ c: String, _ ar: String, _ en: String, _ s: Severity, _ sys: String, _ cAr: [String], _ cEn: [String]) -> DTCInfo {
        DTCInfo(code: c, titleAr: ar, titleEn: en, severity: s, system: sys, causesAr: cAr, causesEn: cEn)
    }
    static let all: [String: DTCInfo] = {
        var d: [String: DTCInfo] = [:]
        let list: [DTCInfo] = [
            e("P0420", "كفاءة دبة التلوث (البيئة) ضعيفة - بنك 1", "Catalyst efficiency below threshold (Bank 1)", .medium, "emissions",
              ["دبة التلوث (الكتلايزر) تعبانة أو مسدودة", "حساس الأكسجين الخلفي خربان", "تهريب في الشكمان قبل الحساس", "احتراق ناقص يحرق الدبة"],
              ["Worn or clogged catalytic converter", "Faulty downstream O2 sensor", "Exhaust leak", "Misfires overheating the catalyst"]),
            e("P0430", "كفاءة دبة التلوث ضعيفة - بنك 2", "Catalyst efficiency below threshold (Bank 2)", .medium, "emissions",
              ["دبة التلوث بنك 2 تعبانة", "حساس أكسجين خلفي", "تهريب شكمان"], ["Bank 2 catalyst worn", "Downstream O2 sensor", "Exhaust leak"]),
            e("P0300", "تفويت (احتراق غير منتظم) في أكثر من سلندر", "Random/multiple cylinder misfire", .high, "ignition",
              ["بواجي قديمة", "كويلات ضعيفة", "تهريب هواء (فاكيوم)", "ضغط بنزين ضعيف أو بخاخات وسخة"],
              ["Worn spark plugs", "Weak ignition coils", "Vacuum leak", "Low fuel pressure or dirty injectors"]),
            e("P0301", "تفويت في سلندر 1", "Cylinder 1 misfire", .high, "ignition", ["بوجي سلندر 1", "كويل سلندر 1", "بخاخ سلندر 1"], ["Cyl 1 spark plug", "Cyl 1 coil", "Cyl 1 injector"]),
            e("P0302", "تفويت في سلندر 2", "Cylinder 2 misfire", .high, "ignition", ["بوجي سلندر 2", "كويل سلندر 2", "بخاخ سلندر 2"], ["Cyl 2 spark plug", "Cyl 2 coil", "Cyl 2 injector"]),
            e("P0303", "تفويت في سلندر 3", "Cylinder 3 misfire", .high, "ignition", ["بوجي سلندر 3", "كويل سلندر 3", "بخاخ سلندر 3"], ["Cyl 3 spark plug", "Cyl 3 coil", "Cyl 3 injector"]),
            e("P0304", "تفويت في سلندر 4", "Cylinder 4 misfire", .high, "ignition", ["بوجي سلندر 4", "كويل سلندر 4", "بخاخ سلندر 4"], ["Cyl 4 spark plug", "Cyl 4 coil", "Cyl 4 injector"]),
            e("P0305", "تفويت في سلندر 5", "Cylinder 5 misfire", .high, "ignition", ["بوجي سلندر 5", "كويل سلندر 5"], ["Cyl 5 plug", "Cyl 5 coil"]),
            e("P0306", "تفويت في سلندر 6", "Cylinder 6 misfire", .high, "ignition", ["بوجي سلندر 6", "كويل سلندر 6"], ["Cyl 6 plug", "Cyl 6 coil"]),
            e("P0171", "الخليط فقير (هوا زايد) - بنك 1", "System too lean (Bank 1)", .medium, "fuel",
              ["تهريب هواء بعد حساس الهواء", "حساس الهواء MAF وسخ", "طرمبة بنزين ضعيفة", "فلتر بنزين مسدود"],
              ["Vacuum leak", "Dirty MAF sensor", "Weak fuel pump", "Clogged fuel filter"]),
            e("P0174", "الخليط فقير - بنك 2", "System too lean (Bank 2)", .medium, "fuel", ["تهريب هواء", "حساس MAF وسخ", "ضغط بنزين ضعيف"], ["Vacuum leak", "Dirty MAF", "Low fuel pressure"]),
            e("P0172", "الخليط غني (بنزين زايد) - بنك 1", "System too rich (Bank 1)", .medium, "fuel", ["بخاخ يخر", "حساس أكسجين", "فلتر هوا مسدود"], ["Leaking injector", "O2 sensor", "Clogged air filter"]),
            e("P0128", "حرارة المحرك ما توصل للطبيعي (ثرموستات)", "Coolant temp below thermostat regulating temp", .low, "cooling",
              ["ثرموستات مفتوح دايم", "حساس حرارة الماء"], ["Thermostat stuck open", "Coolant temp sensor"]),
            e("P0217", "ارتفاع حرارة المحرك", "Engine overheat condition", .high, "cooling",
              ["نقص ماء الرديتر أو تهريب", "مروحة الرديتر ما تشتغل", "ثرموستات مسكّر", "طرمبة ماء خربانة", "رديتر مسدود من الغبار"],
              ["Low coolant or leak", "Radiator fan not working", "Thermostat stuck closed", "Failed water pump", "Radiator clogged with dust"]),
            e("P0118", "حساس حرارة الماء قراءته عالية", "Coolant temp sensor circuit high", .medium, "cooling", ["حساس حرارة الماء", "فيش أو سلك مقطوع"], ["ECT sensor", "Open wiring"]),
            e("P0115", "خلل في دائرة حساس حرارة الماء", "Coolant temp sensor circuit", .medium, "cooling", ["حساس حرارة الماء", "توصيلات"], ["ECT sensor", "Wiring"]),
            e("P0101", "حساس الهواء MAF قراءته غلط", "MAF sensor range/performance", .medium, "fuel", ["حساس MAF وسخ من الغبار", "فلتر هوا مسدود", "تهريب هواء"], ["Dirty MAF from dust", "Clogged air filter", "Air leak"]),
            e("P0113", "حساس حرارة الهواء الداخل قراءته عالية", "Intake air temp sensor high", .low, "fuel", ["حساس IAT", "فيش مفصول"], ["IAT sensor", "Unplugged connector"]),
            e("P0130", "خلل في حساس الأكسجين الأمامي - بنك 1", "O2 sensor circuit (B1S1)", .medium, "emissions", ["حساس أكسجين أمامي"], ["Upstream O2 sensor"]),
            e("P0135", "سخّان حساس الأكسجين الأمامي", "O2 sensor heater (B1S1)", .low, "emissions", ["حساس أكسجين أمامي", "فيوز السخان"], ["O2 sensor", "Heater fuse"]),
            e("P0141", "سخّان حساس الأكسجين الخلفي", "O2 sensor heater (B1S2)", .low, "emissions", ["حساس أكسجين خلفي"], ["Downstream O2 sensor"]),
            e("P0440", "خلل في نظام أبخرة البنزين EVAP", "EVAP system malfunction", .low, "emissions", ["غطا البنزين مو مسكّر زين", "صمام بيرج", "تهريب ليّات"], ["Loose gas cap", "Purge valve", "Hose leak"]),
            e("P0442", "تهريب بسيط في نظام EVAP", "EVAP small leak", .low, "emissions", ["غطا البنزين", "ليّ مشقوق"], ["Gas cap", "Cracked hose"]),
            e("P0455", "تهريب كبير في نظام EVAP", "EVAP large leak", .low, "emissions", ["غطا البنزين مفتوح", "صمام بيرج"], ["Gas cap missing/loose", "Purge valve"]),
            e("P0456", "تهريب صغير جداً في EVAP", "EVAP very small leak", .low, "emissions", ["غطا البنزين", "تهريب بسيط"], ["Gas cap", "Tiny leak"]),
            e("P0500", "حساس السرعة", "Vehicle speed sensor", .medium, "transmission", ["حساس السرعة", "توصيلات"], ["VSS sensor", "Wiring"]),
            e("P0505", "خلل في التحكم بالسلانسيه (الدورات الهادية)", "Idle air control system", .low, "fuel", ["بوابة الهواء وسخة", "صمام IAC"], ["Dirty throttle body", "IAC valve"]),
            e("P0506", "السلانسيه أقل من المطلوب", "Idle RPM lower than expected", .low, "fuel", ["بوابة هواء وسخة", "حمل المكيف"], ["Dirty throttle body", "AC load"]),
            e("P0507", "السلانسيه أعلى من المطلوب", "Idle RPM higher than expected", .low, "fuel", ["تهريب هواء", "بوابة الهواء"], ["Vacuum leak", "Throttle body"]),
            e("P0562", "فولت البطارية/الكهرباء ضعيف", "System voltage low", .medium, "electrical", ["بطارية ضعيفة من الحر", "دينمو ما يشحن", "أقطاب مأكولة"], ["Weak battery (heat)", "Alternator not charging", "Corroded terminals"]),
            e("P0563", "فولت الكهرباء عالي", "System voltage high", .medium, "electrical", ["منظّم الدينمو"], ["Alternator regulator"]),
            e("P0700", "عطل في نظام القير (اطلب كود القير)", "Transmission control system malfunction", .medium, "transmission", ["عطل مسجّل في كمبيوتر القير", "زيت قير ناقص أو محروق"], ["Fault stored in TCM", "Low or burnt ATF"]),
            e("P0715", "حساس سرعة دخول القير", "Input/turbine speed sensor", .medium, "transmission", ["حساس سرعة القير"], ["Input speed sensor"]),
            e("P0730", "نسبة القير غلط", "Incorrect gear ratio", .high, "transmission", ["زيت قير ناقص", "قير يزحلق"], ["Low ATF", "Slipping transmission"]),
            e("P0740", "كلتش محوّل العزم", "Torque converter clutch circuit", .medium, "transmission", ["سلونويد TCC", "زيت قير"], ["TCC solenoid", "ATF condition"]),
            e("P0016", "توقيت عمود الكرنك والكامات مو متطابق", "Crank/cam position correlation", .high, "engine", ["سير/جنزير التوقيت مطّ", "حساس كام", "صمام VVT"], ["Stretched timing chain", "Cam sensor", "VVT solenoid"]),
            e("P0011", "توقيت الكامة متقدّم زيادة - بنك 1", "Camshaft timing over-advanced (B1)", .medium, "engine", ["زيت ناقص أو قديم", "صمام VVT"], ["Low/old oil", "VVT solenoid"]),
            e("P0335", "حساس الكرنك", "Crankshaft position sensor", .high, "engine", ["حساس الكرنك", "توصيلات"], ["CKP sensor", "Wiring"]),
            e("P0340", "حساس الكامة", "Camshaft position sensor", .high, "engine", ["حساس الكام", "توصيلات"], ["CMP sensor", "Wiring"]),
            e("P0401", "تدفق EGR قليل", "EGR flow insufficient", .low, "emissions", ["صمام EGR مسدود كربون"], ["Carboned EGR valve"]),
            e("P0121", "حساس دعسة البنزين/بوابة الهواء", "Throttle position sensor range", .medium, "fuel", ["حساس TPS", "بوابة الهواء"], ["TPS sensor", "Throttle body"]),
            e("P2135", "حساسات بوابة الهواء غير متطابقة", "Throttle position sensor A/B correlation", .high, "fuel", ["بوابة هواء إلكترونية", "فيش"], ["Electronic throttle body", "Connector"]),
            e("P0087", "ضغط البنزين في القضيب منخفض", "Fuel rail pressure too low", .high, "fuel", ["طرمبة بنزين", "فلتر بنزين"], ["Fuel pump", "Fuel filter"]),
            e("P0456", "تهريب EVAP صغير جداً", "EVAP very small leak", .low, "emissions", ["غطا البنزين"], ["Gas cap"]),
            e("P0597", "دائرة سخان الثرموستات", "Thermostat heater control circuit", .low, "cooling", ["ثرموستات إلكتروني"], ["Electronic thermostat"]),
            e("P0480", "دائرة مروحة التبريد 1", "Cooling fan 1 control circuit", .high, "cooling", ["ريليه المروحة", "مروحة الرديتر", "فيوز"], ["Fan relay", "Radiator fan", "Fuse"]),
            e("P0532", "حساس ضغط فريون المكيف قراءته منخفضة", "A/C refrigerant pressure sensor low", .low, "body", ["فريون ناقص", "حساس ضغط المكيف"], ["Low refrigerant", "A/C pressure sensor"]),
            e("P0606", "خلل في كمبيوتر المحرك", "ECM processor fault", .high, "engine", ["كمبيوتر المحرك", "أرضي ضعيف"], ["ECM", "Bad ground"]),
            e("U0100", "انقطع الاتصال بكمبيوتر المحرك", "Lost communication with ECM", .high, "network", ["بطارية ضعيفة", "توصيلات شبكة CAN"], ["Weak battery", "CAN wiring"]),
            e("U0101", "انقطع الاتصال بكمبيوتر القير", "Lost communication with TCM", .high, "network", ["توصيلات", "كمبيوتر القير"], ["Wiring", "TCM"]),
            e("U0121", "انقطع الاتصال بكمبيوتر الفرامل ABS", "Lost communication with ABS", .medium, "network", ["فيوز ABS", "توصيلات"], ["ABS fuse", "Wiring"]),
            e("C0035", "حساس سرعة الكفر الأمامي اليسار", "Left front wheel speed sensor", .medium, "chassis", ["حساس ABS", "غبار على الحساس"], ["ABS sensor", "Dirt on sensor"]),
            e("B0001", "دائرة إيرباق السواق", "Driver airbag circuit", .high, "body", ["فيش الإيرباق", "شريط الدركسون"], ["Airbag connector", "Clock spring"]),
        ]
        for i in list { d[i.code] = i }
        return d
    }()

    static func info(_ code: String) -> DTCInfo {
        if let i = all[code] { return i }
        return generic(code)
    }

    /// Range-based fallback so no code is ever shown as "unknown".
    static func generic(_ code: String) -> DTCInfo {
        let p = code.prefix(1), n = Int(code.dropFirst(2).prefix(1), radix: 16) ?? 0
        let manufacturer = code.dropFirst().prefix(1) == "1" || code.dropFirst().prefix(1) == "3"
        var sysAr = "المحرك", sysEn = "Powertrain", sys = "engine"
        switch p {
        case "P":
            switch n {
            case 0, 1, 2: (sysAr, sysEn, sys) = ("الوقود والهواء", "Fuel & air metering", "fuel")
            case 3: (sysAr, sysEn, sys) = ("الاحتراق والبواجي", "Ignition / misfire", "ignition")
            case 4: (sysAr, sysEn, sys) = ("التلوث والانبعاثات", "Emissions controls", "emissions")
            case 5: (sysAr, sysEn, sys) = ("السرعة والسلانسيه", "Speed & idle control", "fuel")
            case 6: (sysAr, sysEn, sys) = ("الكمبيوتر والدوائر", "Computer & circuits", "electrical")
            default: (sysAr, sysEn, sys) = ("القير", "Transmission", "transmission")
            }
        case "C": (sysAr, sysEn, sys) = ("الشاصي والفرامل", "Chassis / brakes", "chassis")
        case "B": (sysAr, sysEn, sys) = ("البودي والراحة", "Body", "body")
        default: (sysAr, sysEn, sys) = ("شبكة الاتصال", "Network", "network")
        }
        let mAr = manufacturer ? " (كود خاص بالشركة)" : ""
        let mEn = manufacturer ? " (manufacturer specific)" : ""
        return DTCInfo(code: code, titleAr: "عطل في نظام \(sysAr)\(mAr)", titleEn: "\(sysEn) fault\(mEn)",
                       severity: p == "U" || p == "B" ? .medium : .medium, system: sys,
                       causesAr: ["يحتاج فحص عند ورشة متخصصة بنوع سيارتك"], causesEn: ["Needs a make-specific workshop check"])
    }

    /// Saudi-dialect "AI-style" explanation built from offline templates.
    static func explain(_ i: DTCInfo) -> String {
        if L10n.lang == .en {
            let s: String
            switch i.severity {
            case .high: s = "Don't ignore this one. Drive gently to a workshop or get it towed."
            case .medium: s = "Not an emergency, but book a check this week before it causes more damage."
            case .low: s = "Minor. You can keep driving, just fix it at your next service."
            }
            return "Your car is reporting \(i.code): \(i.titleEn). Most likely: \(i.causesEn.prefix(2).joined(separator: ", ")). \(s)"
        }
        let s: String
        switch i.severity {
        case .high: s = "هذا لا تطنّشه. امشِ بهدوء لأقرب ورشة أو اطلب سطحة، خصوصاً لو الحرارة عالية."
        case .medium: s = "مو طوارئ، بس افحصه هالأسبوع قبل يكبر الخراب ويغلى التصليح."
        case .low: s = "بسيط، تقدر تمشي عادي وتصلحه مع الصيانة الجاية."
        }
        let heat = i.system == "cooling" || i.system == "electrical" ? " وتراه يكثر في الصيف عندنا مع الحر." : ""
        return "سيارتك تقول \(i.code): \(i.titleAr). الغالب السبب \(i.causesAr.prefix(2).joined(separator: " أو ")).\(heat) \(s)"
    }

    /// What to tell the mechanic, so the user isn't overcharged.
    static func mechanicScript(_ i: DTCInfo) -> String {
        L("قل للميكانيكي: «طالع عندي كود \(i.code) (\(i.titleAr))، أبيك تفحص \(i.causesAr.first ?? "السبب") قبل تبدّل أي قطعة، وعطني السعر قبل تبدأ».",
          "Tell the mechanic: \"I have code \(i.code) (\(i.titleEn)). Please check \(i.causesEn.first ?? "the cause") before replacing parts, and quote me first.\"")
    }

    static func steps(_ i: DTCInfo) -> [String] {
        var s: [String] = []
        if L10n.lang == .ar {
            s.append("اقرأ الكود مرة ثانية بعد ما تطفي وتشغّل، وشوف هل هو «مخزّن» ولا «معلّق».")
            for c in i.causesAr { s.append("افحص: \(c).") }
            s.append("بعد التصليح امسح الكود، وامشِ ٢٠-٣٠ دقيقة، وافحص من جديد.")
        } else {
            s.append("Re-read the code after a restart and check whether it is stored or pending.")
            for c in i.causesEn { s.append("Check: \(c).") }
            s.append("After repair, clear the code, drive 20-30 minutes, then rescan.")
        }
        return s
    }
}
