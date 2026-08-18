import Foundation

enum SampleMarket {
    struct Store {
        var division: String
        var district: String
        var om: String
        var store: String
        var name: String
    }

    static let stores: [Store] = [
        .init(division: "Jewel Osco", district: "J1", om: "Shelly Selof", store: "1487", name: "Chicago Pulaski"),
        .init(division: "Jewel Osco", district: "J1", om: "Shelly Selof", store: "1597", name: "Chicago Kedzie"),
        .init(division: "Jewel Osco", district: "J1", om: "Shelly Selof", store: "2144", name: "Cicero Cermak"),
        .init(division: "Jewel Osco", district: "J1", om: "Shelly Selof", store: "3361", name: "Berwyn Harlem"),
        .init(division: "Jewel Osco", district: "J2", om: "Shelly Selof", store: "2788", name: "Evanston Dempster"),
        .init(division: "Jewel Osco", district: "J2", om: "Shelly Selof", store: "3901", name: "Skokie Old Orchard"),
        .init(division: "Jewel Osco", district: "J2", om: "Shelly Selof", store: "4120", name: "Niles Golf Mill"),
        .init(division: "Jewel Osco", district: "J2", om: "Shelly Selof", store: "5503", name: "Des Plaines"),
        .init(division: "Jewel Osco", district: "J3", om: "Andrew Quinn", store: "1088", name: "Joliet Larkin"),
        .init(division: "Jewel Osco", district: "J3", om: "Andrew Quinn", store: "2230", name: "Aurora Fox Valley"),
        .init(division: "Jewel Osco", district: "J3", om: "Andrew Quinn", store: "3677", name: "Naperville Ogden"),
        .init(division: "Jewel Osco", district: "J3", om: "Andrew Quinn", store: "4890", name: "Bolingbrook"),
        .init(division: "Haggen", district: "39", om: "Luke Lomas", store: "1755", name: "Orland Park"),
        .init(division: "Haggen", district: "39", om: "Luke Lomas", store: "2904", name: "Tinley Park"),
        .init(division: "Haggen", district: "39", om: "Luke Lomas", store: "3440", name: "New Lenox"),
        .init(division: "Haggen", district: "39", om: "Luke Lomas", store: "5288", name: "Frankfort"),
    ]

    static let dates = ["2026-08-03", "2026-08-10", "2026-08-17"]

    static func rows() -> [MetricRow] {
        var out: [MetricRow] = []
        for (index, store) in stores.enumerated() {
            for (week, date) in dates.enumerated() {
                let trend = Double(week) * 0.04
                out.append(MetricRow(
                    section: .fiveStar,
                    division: store.division,
                    operationsOM: store.om,
                    storeNumber: store.store,
                    storeName: store.name,
                    recordedOn: date,
                    payload: [
                        "star_rating": clamp(4.15 + jitter(index + 3, 0.7) + trend, 3.4, 5).rounded(2),
                        "otp_pct": clamp(91 + jitter(index + 11, 7) + Double(week) * 0.6, 78, 99.4).rounded(1),
                        "fill_rate_pct": clamp(93 + jitter(index + 19, 6) + Double(week) * 0.4, 82, 99.6).rounded(1),
                        "quality_score": clamp(94 + jitter(index + 29, 5), 84, 99.5).rounded(1),
                        "cx_score": clamp(88 + jitter(index + 41, 8) + Double(week) * 0.5, 72, 98).rounded(1),
                    ]
                ))

                let compliance = clamp(90 + jitter(index + 7, 9) + Double(week) * 0.8, 74, 99.2)
                let picks = (420 + jitter(index + 13, 80)).rounded()
                let compliant = ((picks * compliance) / 100).rounded()
                out.append(MetricRow(
                    section: .pickPath,
                    division: store.division,
                    operationsOM: store.om,
                    storeNumber: store.store,
                    storeName: store.name,
                    recordedOn: date,
                    payload: [
                        "compliance_pct": compliance.rounded(1),
                        "picks_total": picks,
                        "picks_compliant": compliant,
                        "exception_count": max(0, picks - compliant),
                    ]
                ))

                let pnrRate = clamp(3.8 + jitter(index + 17, 3.2) - Double(week) * 0.35, 0.4, 9.5)
                let due = (210 + jitter(index + 23, 50)).rounded()
                let pnr = ((due * pnrRate) / 100).rounded()
                out.append(MetricRow(
                    section: .prepNotReady,
                    division: store.division,
                    operationsOM: store.om,
                    storeNumber: store.store,
                    storeName: store.name,
                    recordedOn: date,
                    payload: [
                        "pnr_count": pnr,
                        "orders_due": due,
                        "pnr_rate_pct": pnrRate.rounded(1),
                        "avg_late_min": clamp(8 + jitter(index + 31, 10), 2, 28).rounded(1),
                    ]
                ))

                let recPickup = [36, 40, 44, 48, 52][index % 5]
                let recDelivery = [20, 24, 28, 32][index % 4]
                let drift = (index % 5 == 0 && week == 2) ? 12 : (index % 4 == 1 ? -8 : 0)
                out.append(MetricRow(
                    section: .dynacap,
                    division: store.division,
                    operationsOM: store.om,
                    storeNumber: store.store,
                    storeName: store.name,
                    recordedOn: date,
                    payload: [
                        "pickup_capacity": Double(recPickup + drift),
                        "delivery_capacity": Double(recDelivery + (index % 6 == 2 ? 6 : 0)),
                        "rec_pickup": Double(recPickup),
                        "rec_delivery": Double(recDelivery),
                        "pickup_util_pct": clamp(78 + jitter(index + 5, 14), 52, 99).rounded(1),
                        "delivery_util_pct": clamp(74 + jitter(index + 9, 16), 48, 99).rounded(1),
                    ]
                ))

                let efficiency = clamp(91 + jitter(index + 21, 8) + Double(week) * 0.5, 78, 99.4)
                let over = max(0, (6 + jitter(index + 27, 8)).rounded())
                let under = max(0, (4 + jitter(index + 33, 6)).rounded())
                out.append(MetricRow(
                    section: .scheduleQuality,
                    division: store.division,
                    operationsOM: store.om,
                    storeNumber: store.store,
                    storeName: store.name,
                    recordedOn: date,
                    payload: [
                        "schedule_efficiency_pct": efficiency.rounded(1),
                        "over_scheduled": over,
                        "under_scheduled": under,
                    ]
                ))

                let pph = clamp(58 + jitter(index + 37, 14) + Double(week) * 1.1, 38, 92)
                let hours = clamp(28 + jitter(index + 43, 6), 18, 40)
                let pphPicks = (pph * hours).rounded()
                out.append(MetricRow(
                    section: .pph,
                    division: store.division,
                    operationsOM: store.om,
                    storeNumber: store.store,
                    storeName: store.name,
                    recordedOn: date,
                    payload: [
                        "pph": pph.rounded(1),
                        "picks_total": pphPicks,
                        "pick_hours": hours.rounded(1),
                        "goal_pph": 65,
                    ]
                ))

                let shoppers = [
                    ("\(store.name.split(separator: " ").first ?? "Store") A", 0),
                    ("\(store.name.split(separator: " ").first ?? "Store") B", 1),
                ]
                let firstNames = ["L. Ramirez", "J. Cole", "M. Singh", "A. Nguyen", "T. Brooks", "K. Patel", "S. Ortiz", "D. Walsh"]
                for (slot, _) in shoppers.enumerated() {
                    let name = firstNames[(index * 2 + slot) % firstNames.count]
                    let shopperPPH = clamp(48 + jitter(index + slot * 9 + 51, 18) + Double(week) * 0.8, 32, 94)
                    let path = clamp(84 + jitter(index + slot * 5 + 61, 12) + Double(week) * 0.6, 68, 99.4)
                    let quality = clamp(90 + jitter(index + slot * 7 + 71, 8), 78, 99.5)
                    out.append(MetricRow(
                        section: .pickerScorecard,
                        division: store.division,
                        operationsOM: store.om,
                        storeNumber: store.store,
                        storeName: store.name,
                        recordedOn: date,
                        payload: [
                            "pph": shopperPPH.rounded(1),
                            "compliance_pct": path.rounded(1),
                            "quality_score": quality.rounded(1),
                            "picks_total": (shopperPPH * 7).rounded(),
                            "goal_pph": 65,
                        ],
                        textPayload: [
                            "shopper_name": name,
                            "shopper_id": "S\(store.store)-\(slot + 1)",
                        ]
                    ))
                }
            }
        }
        return out.map { row in
            var copy = row
            if let store = stores.first(where: { $0.store == row.storeNumber }) {
                copy.textPayload["district"] = store.district
                copy.textPayload["om_area"] = store.division == "Haggen" ? "Haggen 1" : "Chicago 1"
            }
            return copy
        }
    }

    static func templateCSV(for section: MetricSection) -> String {
        switch section {
        case .fiveStar:
            return """
            Division,Operations OM,Store Number,Store Name,Date,Star Rating,OTP %,Fill Rate %,Quality Score,CX Score
            10,A. Brooks,1487,Chicago Pulaski,2026-08-17,4.72,96.1,97.4,95.2,91.0
            """
        case .pickPath:
            return """
            WEEK_ID,,,,,,202620,202620,202620,202621,202621,202621
            DIVISION,DISTRICT,OM_AREA,OM_ID,STORE_ID,EMPLOYEE_ALTERNATE_ID,Pick Path Compliance,Orders,Pure PPH (excluding Reshop),Pick Path Compliance,Orders,Pure PPH (excluding Reshop)
            Portland,73,Portland 2,JR Ehline,4313,Total,0.8907,411,91.9,0.8889,462,93.8
            Portland,73,Portland 2,JR Ehline,4313,RPAL114,0.9885,23,106.5,0.9474,22,113.3
            Portland,73,Portland 2,JR Ehline,1762,Total,0.8979,517,97.2,0.8906,602,94.8
            Haggen,39,Haggen 1,Luke Lomas,3427,Total,0.9610,288,88.4,0.9540,301,87.1
            """
        case .prepNotReady:
            return """
            Division,Operations OM,Store Number,Store Name,Date,PNR Count,Orders Due,PNR Rate %,Avg Late Min
            10,A. Brooks,1487,Chicago Pulaski,2026-08-17,6,214,2.8,7.4
            """
        case .dynacap:
            return """
            Division,Operations OM,Store Number,Store Name,Date,Pickup Capacity,Delivery Capacity,Rec Pickup,Rec Delivery,Pickup Util %,Delivery Util %
            10,A. Brooks,1487,Chicago Pulaski,2026-08-17,36,20,36,20,81.0,76.0
            """
        case .scheduleQuality:
            return """
            Division,Operations OM,Store Number,Store Name,Date,Schedule Efficiency %,Over Scheduled,Under Scheduled
            10,A. Brooks,1487,Chicago Pulaski,2026-08-17,94.6,4,2
            """
        case .pph:
            return """
            WEEK_ID,,,,,202618,202619,202620,202621,202622,202623,202624,202625,Total
            DIVISION,DISTRICT,OM_AREA,OM_ID,STORE,Pure PPH,Pure PPH,Pure PPH,Pure PPH,Pure PPH,Pure PPH,Pure PPH,Pure PPH,Pure PPH
            Jewel Osco,J1,Chicago 1,Shelly Selof,1,62.1,59.6,59.6,67.5,64.8,64.9,70.2,65.0,63.9
            Jewel Osco,J1,Chicago 1,Shelly Selof,606,64.8,61.1,62.9,64.2,67.1,66.3,60.9,63.0,63.9
            Haggen,39,Haggen 1,Luke Lomas,3427,87.9,88.8,85.8,84.8,83.2,85.7,82.4,87.0,85.5
            """
        case .pickerScorecard:
            return """
            Division,Operations OM,Store Number,Store Name,Date,Shopper,Shopper ID,PPH,Pick Path %,Quality,Picks Total,Goal PPH
            10,A. Brooks,1487,Chicago Pulaski,2026-08-17,L. Ramirez,S1487-1,71.2,96.4,97.1,498,65
            10,A. Brooks,1487,Chicago Pulaski,2026-08-17,J. Cole,S1487-2,52.1,81.0,88.4,365,65
            """
        }
    }

    private static func clamp(_ n: Double, _ minV: Double, _ maxV: Double) -> Double {
        min(maxV, max(minV, n))
    }

    private static func jitter(_ seed: Int, _ spread: Double) -> Double {
        let x = sin(Double(seed) * 12.9898) * 43758.5453
        return (x - floor(x) - 0.5) * 2 * spread
    }
}

private extension Double {
    func rounded(_ places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
