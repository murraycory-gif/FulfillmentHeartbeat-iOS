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
                        "flash_pct": clamp(78 + jitter(index + 11, 18), 40, 99).rounded(1),
                        "ott_pct": clamp(93 + jitter(index + 17, 8), 82, 100).rounded(1),
                        "presub_pct": clamp(3.4 + jitter(index + 21, 3.2), 0.8, 9.5).rounded(1),
                        "coe_pct": clamp(28 + jitter(index + 27, 22), -8, 72).rounded(1),
                        "oth5_pct": clamp(90 + jitter(index + 33, 10), 70, 100).rounded(1),
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

                out.append(MetricRow(
                    section: .dynacap,
                    division: store.division,
                    operationsOM: store.om,
                    storeNumber: store.store,
                    storeName: store.name,
                    recordedOn: date,
                    payload: [
                        "dynacap_rate": clamp(61 + jitter(index + 11, 12), 48, 88).rounded(1),
                        "utilization_pct": clamp(42 + jitter(index + 5, 14), 18, 72).rounded(1),
                        "dpa_dynacap": Double(240000 + index * 1200),
                        "used_capacity": Double(110000 + index * 800),
                    ],
                    textPayload: ["district": store.district]
                ))

                let efficiency = clamp(91 + jitter(index + 21, 8) + Double(week) * 0.5, 78, 99.4)
                out.append(MetricRow(
                    section: .scheduleQuality,
                    division: store.division,
                    operationsOM: store.om,
                    storeNumber: store.store,
                    storeName: store.name,
                    recordedOn: date,
                    payload: [
                        "schedule_efficiency_pct": efficiency.rounded(1),
                        "staffing_efficiency_pct": clamp(efficiency + jitter(index + 41, 4), 76, 99).rounded(1),
                        "over_schedule_pct": max(0, (2 + jitter(index + 27, 6))).rounded(1),
                        "under_schedule_pct": max(0, (1.5 + jitter(index + 33, 5))).rounded(1),
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

                let tva = clamp(jitter(index + 41, 5) - 0.4, -2.5, 6.5)
                out.append(MetricRow(
                    section: .labor,
                    division: store.division,
                    operationsOM: store.om,
                    storeNumber: store.store,
                    storeName: store.name,
                    recordedOn: "202624",
                    payload: [
                        "target_vs_actual_pct": tva.rounded(2),
                        "cost_trgt_pct": clamp(11 + jitter(index + 7, 4), 8, 18).rounded(1),
                        "act_cost_pct": clamp(12 + jitter(index + 9, 8), 6, 28).rounded(1),
                        "act_hrs": clamp(120 + jitter(index, 40), 80, 200).rounded(1),
                        "sch_hrs": clamp(118 + jitter(index + 2, 36), 80, 200).rounded(1),
                    ],
                    textPayload: ["labor_grain": "store", "week": "202624", "district": store.district]
                ))
                for day in 0..<3 {
                    let dayTva = clamp(tva + jitter(index + day, 1.2), -3, 7)
                    out.append(MetricRow(
                        section: .labor,
                        division: store.division,
                        operationsOM: store.om,
                        storeNumber: store.store,
                        storeName: store.name,
                        recordedOn: String(format: "2026-06-%02d", 8 + day),
                        payload: [
                            "target_vs_actual_pct": dayTva.rounded(2),
                            "cost_trgt_pct": clamp(11 + jitter(index + day, 4), 8, 18).rounded(1),
                            "act_cost_pct": clamp(12 + jitter(index + day + 3, 8), 6, 28).rounded(1),
                            "act_hrs": clamp(18 + jitter(index + day, 6), 10, 32).rounded(1),
                        ],
                        textPayload: ["labor_grain": "day", "week": "202624", "district": store.district]
                    ))
                }

                let sales = clamp(9_000 + jitter(index + 53, 6_000), 1_200, 28_000)
                let lostRate = clamp(0.028 + jitter(index + 59, 0.035), 0.006, 0.12)
                let lost = (sales * lostRate).rounded(2)
                out.append(MetricRow(
                    section: .lostRevenue,
                    division: store.division,
                    operationsOM: store.om,
                    storeNumber: store.store,
                    storeName: store.name,
                    recordedOn: date,
                    payload: [
                        "ecomm_sales": sales.rounded(2),
                        "lost_revenue": lost,
                        "lost_revenue_pct": (lostRate * 100).rounded(2),
                        "lost_revenue_goal": (lost * 0.62).rounded(2),
                        "lost_revenue_goal_pct": (lostRate * 62).rounded(2),
                        "post_sub_oos_foregone": (lost * 0.55).rounded(2),
                        "refund_lost": (lost * 0.22).rounded(2),
                        "missed_sales": (lost * 0.14).rounded(2),
                    ],
                    textPayload: ["lost_grain": "store", "district": store.district]
                ))

                var miPayload: [String: Double] = [
                    "mi_grocery": clamp(3.2 + jitter(index + 61, 6), 0.4, 18).rounded(1),
                    "mi_alcohol": clamp(2.4 + jitter(index + 63, 5), 0.2, 14).rounded(1),
                    "mi_pharmacy": clamp(18 + jitter(index + 65, 20), 0, 75).rounded(1),
                    "mi_food_service": clamp(28 + jitter(index + 67, 22), 4, 92).rounded(1),
                    "mi_deli": clamp(12 + jitter(index + 69, 10), 1, 42).rounded(1),
                    "mi_gm_hbc": clamp(9 + jitter(index + 71, 8), 1, 28).rounded(1),
                    "mi_dairy": clamp(1.8 + jitter(index + 73, 2.4), 0.2, 10).rounded(1),
                    "mi_floral": clamp(78 + jitter(index + 75, 18), 20, 100).rounded(1),
                    "mi_bakery": clamp(32 + jitter(index + 77, 24), 4, 96).rounded(1),
                    "mi_frozen": clamp(4.2 + jitter(index + 79, 4), 0.4, 16).rounded(1),
                    "mi_coffee": clamp(88 + jitter(index + 81, 12), 40, 100).rounded(1),
                    "mi_produce": clamp(8.5 + jitter(index + 83, 8), 1, 32).rounded(1),
                    "mi_seafood": clamp(14 + jitter(index + 85, 12), 2, 48).rounded(1),
                    "mi_meat": clamp(11 + jitter(index + 87, 9), 1, 36).rounded(1),
                    "mi_bakery_pkgd": clamp(7.5 + jitter(index + 89, 7), 0.8, 28).rounded(1),
                ]
                miPayload["mi_pct"] = clamp(4.1 + jitter(index + 91, 4.8), 0.8, 16).rounded(1)
                out.append(MetricRow(
                    section: .missingItems,
                    division: store.division,
                    operationsOM: store.om,
                    storeNumber: store.store,
                    storeName: store.name,
                    recordedOn: date,
                    payload: miPayload,
                    textPayload: ["district": store.district]
                ))

                var preSubPayload = miPayload
                preSubPayload["mi_pct"] = clamp(3.6 + jitter(index + 97, 5.2), 0.4, 18).rounded(1)
                preSubPayload["mi_grocery"] = clamp(4.8 + jitter(index + 99, 5), 0.4, 16).rounded(1)
                preSubPayload["mi_bakery"] = clamp(12 + jitter(index + 101, 10), 1, 40).rounded(1)
                out.append(MetricRow(
                    section: .preSubOOS,
                    division: store.division,
                    operationsOM: store.om,
                    storeNumber: store.store,
                    storeName: store.name,
                    recordedOn: date,
                    payload: preSubPayload,
                    textPayload: ["district": store.district, "presub_dept": "1", "data_window": "Aug 30 – Aug 31, 2026"]
                ))

                let shoppers = [
                    ("\(store.name.split(separator: " ").first ?? "Store") A", 0),
                    ("\(store.name.split(separator: " ").first ?? "Store") B", 1),
                ]
                let firstNames = ["L. Ramirez", "J. Cole", "M. Singh", "A. Nguyen", "T. Brooks", "K. Patel", "S. Ortiz", "D. Walsh"]
                for (slot, _) in shoppers.enumerated() {
                    let name = firstNames[(index * 2 + slot) % firstNames.count]
                    let shopperPPH = clamp(48 + jitter(index + slot * 9 + 51, 18) + Double(week) * 0.8, 32, 94)
                    out.append(MetricRow(
                        section: .pickerScorecard,
                        division: store.division,
                        operationsOM: store.om,
                        storeNumber: store.store,
                        storeName: store.name,
                        recordedOn: date,
                        payload: [
                            "pph": shopperPPH.rounded(1),
                            "ott_pct": slot == 0 ? 100 : 0,
                            "presub_pct": clamp(3.2 + jitter(index + slot * 4, 4), 0.5, 12).rounded(1),
                            "oth5_pct": clamp(88 + jitter(index + slot * 6, 10), 70, 100).rounded(1),
                            "coe_pct": clamp(18 + jitter(index + slot * 8, 24), -20, 70).rounded(1),
                            "orders": (12 + jitter(index + slot, 10)).rounded(),
                            "pick_hours": clamp(6 + jitter(index + slot * 3, 5), 1.5, 18).rounded(1),
                        ],
                        textPayload: [
                            "shopper_name": name,
                            "shopper_id": "S\(store.store)-\(slot + 1)",
                        ]
                    ))
                }
            }
        }
        for (index, store) in stores.enumerated() {
            let mapper: String
            let sequence: String
            switch index % 4 {
            case 0:
                mapper = "2021-03-05"
                sequence = "2024-08-06"
            case 1:
                mapper = "2024-09-16"
                sequence = "2024-09-16"
            case 2:
                mapper = "2026-07-01"
                sequence = "2026-08-17"
            default:
                mapper = "2026-08-20"
                sequence = "2026-08-24"
            }
            out.append(MetricRow(
                section: .aisleMapper,
                division: store.division,
                operationsOM: store.om,
                storeNumber: store.store,
                storeName: store.name,
                recordedOn: sequence,
                payload: [:],
                textPayload: [
                    "district": store.district,
                    AisleMapperMath.mapperKey: mapper,
                    AisleMapperMath.sequenceKey: sequence,
                ]
            ))
        }
        out.append(contentsOf: [
            MetricRow(
                section: .preSubOOSItem,
                division: "Jewel Osco",
                operationsOM: "Shelly Selof",
                storeNumber: "1",
                payload: ["ord_qty": 1755, "sub_count": 2, "presub_pct": 12.1, "presub_count": 213, "presub_dollars": 425.89, "oos_count": 211, "oos_pct": 12.0, "oos_dollars": 420.91],
                textPayload: ["district": "J1", "presub_item": "1", "bpn": "184350009 - Sweet Corn"]
            ),
            MetricRow(
                section: .preSubOOSItem,
                division: "Jewel Osco",
                operationsOM: "Shelly Selof",
                storeNumber: "76",
                payload: ["ord_qty": 278, "sub_count": 57, "presub_pct": 55.4, "presub_count": 154, "presub_dollars": 1076.46, "oos_count": 97, "oos_pct": 34.9, "oos_dollars": 678.03],
                textPayload: ["district": "J6", "presub_item": "1", "bpn": "960012546 - Strawberries Prepacked - 2 Lb"]
            ),
            MetricRow(
                section: .preSubOOSItem,
                division: "Haggen",
                operationsOM: "Luke Lomas",
                storeNumber: "3427",
                payload: ["ord_qty": 92, "sub_count": 0, "presub_pct": 4.2, "presub_count": 4, "presub_dollars": 8.4, "oos_count": 4, "oos_pct": 4.2, "oos_dollars": 8.4],
                textPayload: ["district": "39", "presub_item": "1", "bpn": "184060007 - Banana"]
            ),
        ])
        let lastDate = dates.last ?? ""
        let lostStores = out.filter { $0.section == .lostRevenue && $0.recordedOn == lastDate }
        let lostDollars = lostStores.compactMap { $0.number("lost_revenue") }.reduce(0, +)
        let lostSales = lostStores.compactMap { $0.number("ecomm_sales") }.reduce(0, +)
        out.append(MetricRow(
            section: .lostRevenue,
            division: "",
            operationsOM: "",
            storeNumber: "",
            storeName: "Total",
            recordedOn: lastDate,
            payload: [
                "ecomm_sales": lostSales,
                "lost_revenue": lostDollars,
                "lost_revenue_pct": lostSales > 0 ? lostDollars / lostSales * 100 : 0,
            ],
            textPayload: ["lost_grain": "market"]
        ))
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
            Store,Division,OM,District,Total Rating,Pass Rate (4.0+),Flash Availability % (Make it Convenient),OTT % (Make it Convenient),Pre-Sub OOS % (Give Me What I Ordered),COE % (Give Me What I Ordered),OTH5 % (Pleasant Handoff),Flash Availability % (Star),OTT % (Star),Pre-Sub OOS % (Star),COE % (Star),OTH5 % (Star)
            1,Jewel Osco,Shelly Selof,J1,5,Pass,0.91,0.98,0.023,0.66,0.96,1,1,1,1,1
            606,Jewel Osco,Shelly Selof,J1,3.5,Fail,0.52,0.88,0.071,0.05,0.80,0,0.5,0,0.5,0.5
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
        case .pickPathPicker:
            return """
            WEEK_ID,202625,202625,202625,Total,Total,Total
            EMPLOYEE_ALTERNATE_ID,Pick Path Compliance,Orders,Pure PPH (excluding Reshop),Pick Path Compliance,Orders,Pure PPH (excluding Reshop)
            RPAL114,0.9474,22,113.3,0.9885,23,106.5
            AABRA77,1,1,105.88,1,17,129.9
            """
        case .prepNotReady:
            return """
            DIVISION,District,OM,Store,Prep Not Ready Hours %,Store #
            Haggen,39,Luke Lomas,3427,0.016979,1
            Jewel Osco,J1,Shelly Selof,1,0.0148,1
            Jewel Osco,J1,Shelly Selof,2219,0.07455,1
            Shaws,B2,Sharon Reynolds,1432,0.1103,1
            """
        case .dynacap:
            return """
            DISTRICT,DPA_DYNACAP,EOT Capacity,Total Pieces/Total Hrs,% Change,Used Capacity,Utilization%
            J1,537898,538204,74.07,0.0005,224231,0.4168
            J2,493735,522454,72.04,0.0582,227154,0.4352
            39,151880,151697,83.15,-0.0012,28576,0.1884
            """
        case .scheduleQuality:
            return """
            Division,District,Store,Schedule Efficicency % (Sch vs Tgt),Under Schedule % (Sch vs Tgt),Over Schedule % (Sch vs Tgt)
            JEWEL,J1,0001,0.931,0.012,0.008
            JEWEL,J1,0606,0.884,0.061,0.014
            HAGGEN,39,3427,0.952,0.000,0.000
            """
        case .pph:
            return """
            WEEK_ID,,,,,202618,202619,202620,202621,202622,202623,202624,202625,Total
            DIVISION,DISTRICT,OM_AREA,OM_ID,STORE,Pure PPH,Pure PPH,Pure PPH,Pure PPH,Pure PPH,Pure PPH,Pure PPH,Pure PPH,Pure PPH
            Jewel Osco,J1,Chicago 1,Shelly Selof,1,62.1,59.6,59.6,67.5,64.8,64.9,70.2,65.0,63.9
            Jewel Osco,J1,Chicago 1,Shelly Selof,606,64.8,61.1,62.9,64.2,67.1,66.3,60.9,63.0,63.9
            Haggen,39,Haggen 1,Luke Lomas,3427,87.9,88.8,85.8,84.8,83.2,85.7,82.4,87.0,85.5
            """
        case .labor:
            return """
            WEEK_ID,D_DATE,DIVISION_NM,DISTRICT,STORE_ID,CostTrgt%,ActCost%,Target vs Actual%,ActHrs,Sch_Hrs
            202624,Total,JEWEL,J1,1,0.115,0.118,0.003,120,118
            202624,2026-06-08,JEWEL,J1,1,0.115,0.121,0.006,18,17
            202624,Total,HAGGEN,39,3427,0.149,0.140,-0.009,95,96
            """
        case .pickerScorecard:
            return """
            DATE,,Total
            STORE,PICKER,Pure_PPH,Pre_SUB_OOS_%,OOS_%,PICK_HOURS,SUBS,ORDERS,Ttl DUG ORDERS,OTH_ELIG,OTH5%,OTT %,Refund_AMT
            1,Total,74.2,0.04,0.02,18.4,12,80,60,0.96,0.91,0.84,42.10
            1,AWHOR08,91.4,0.023,0.011,8.2,4,42,31,0.97,0.96,1,12.50
            606,JCOLE02,52.1,0.071,0.048,6.1,9,18,11,0.88,0.80,0,21.40
            """
        case .lostRevenue:
            return """
            Store,eComm Sales,Total Lost Revenue (Total Opportunity),Total Lost Revenue % (Total Opportunity)
            1,10000,450,0.045
            606,8000,560,0.07
            Total,18000,1010,0.056111
            """
        case .missingItems:
            return """
            Department Desc,,,,301 GROCERY,303 ALCOHOLIC BEVERAGES,304 PHARMACY,306 FOOD SERVICE,309 DELICATESSEN,311 GM/HBC,314 DAIRY,315 FLORAL,316 BAKERY,317 FROZEN GROCERY,328 COFFEE KIOSK,329 PRODUCE,330 SEAFOOD,333 MEAT,336 BAKERY PKGD OUTSIDE,Total
            Division > Store > Group > Product,District,OM,Store,% Items Without Aisle in Store Tag Subscription Data,% Items Without Aisle in Store Tag Subscription Data,% Items Without Aisle in Store Tag Subscription Data,% Items Without Aisle in Store Tag Subscription Data,% Items Without Aisle in Store Tag Subscription Data,% Items Without Aisle in Store Tag Subscription Data,% Items Without Aisle in Store Tag Subscription Data,% Items Without Aisle in Store Tag Subscription Data,% Items Without Aisle in Store Tag Subscription Data,% Items Without Aisle in Store Tag Subscription Data,% Items Without Aisle in Store Tag Subscription Data,% Items Without Aisle in Store Tag Subscription Data,% Items Without Aisle in Store Tag Subscription Data,% Items Without Aisle in Store Tag Subscription Data,% Items Without Aisle in Store Tag Subscription Data,% Items Without Aisle in Store Tag Subscription Data
            Jewel Osco,J1,Shelly Selof,1,0.04,0.03,0.2,0.28,0.12,0.09,0.018,0.8,0.32,0.042,0.9,0.085,0.14,0.11,0.075,0.045
            Jewel Osco,J1,Shelly Selof,606,0.062,0.051,0.5,0.41,0.19,0.14,0.028,0.99,0.55,0.061,1,0.12,0.21,0.16,0.11,0.068
            Haggen,39,Luke Lomas,3427,0.031,0.022,0.1,0.18,0.08,0.06,0.012,0.72,0.24,0.028,0.85,0.055,0.09,0.07,0.042,0.038
            """
        case .preSubOOS:
            return """
            DEPARTMENT_NM,ALCOHOLIC BEVERAGES,BAKERY,BAKERY PKGD OUTSIDE,DAIRY,DELICATESSEN,FLORAL,FOOD SERVICE,FROZEN GROCERY,GM/HBC,GROCERY,MEAT,PHARMACY,PRODUCE,SEAFOOD,Total
            STORE_ID,Pre-Sub OOS%,Pre-Sub OOS%,Pre-Sub OOS%,Pre-Sub OOS%,Pre-Sub OOS%,Pre-Sub OOS%,Pre-Sub OOS%,Pre-Sub OOS%,Pre-Sub OOS%,Pre-Sub OOS%,Pre-Sub OOS%,Pre-Sub OOS%,Pre-Sub OOS%,Pre-Sub OOS%,Pre-Sub OOS%
            1,0,0.0869565217391304,0.0461538461538462,0.0174563591022444,0.0108695652173913,1,0.0476190476190476,0.0280373831775701,0.101123595505618,0.0188284518828452,0.0202020202020202,,0.00831946755407654,0.111111111111111,0.0198974977389207
            606,0.25,0.260869565217391,0.168831168831169,0.0931372549019608,0.144736842105263,0,0.19047619047619,0.109649122807018,0.277777777777778,0.0840425531914894,0.219047619047619,,0.139664804469274,0.387096774193548,0.071
            3427,0,0.0952380952380952,0.0263157894736842,0.0375,0.05,0.25,0,0.0238095238095238,0.111111111111111,0.0134228187919463,0.037037037037037,,0.00766283524904215,0,0.038
            Total,0.0632380510620204,0.144513477233039,0.0811279849348813,0.0622186454029183,0.0790007553685119,0.370154230929554,0.147040931606848,0.0722434786892514,0.0816591541909625,0.055595269040811,0.0906783008783752,0.125541125541126,0.0307631829755623,0.113365813301466,0.0570090596706524
            Applied filters: Excluded (2) (Blank) (DIVISION), (Blank) (DEPARTMENT_NM) WEEK_ID is greater than or equal to 202513 DTE is on or after 8/30/2026 and is before 9/1/2026
            """
        case .aisleMapper:
            return """
            DIVISION,District,OM,Store,Latest Aisle Mapper Update Date,Latest Aisle Sequence Update Date
            Jewel Osco,J1,Shelly Selof,1,2026-08-20,2026-08-24
            Jewel Osco,J1,Shelly Selof,606,2021-03-05,2024-08-06
            Haggen,39,Luke Lomas,3427,2026-07-01,2026-08-17
            """
        case .preSubOOSItem:
            return """
            STORE_ID,DIVISION,DISTRICT,BPN DESC,ORD_QTY,Subs,Pre-Sub OOS%,Pre-Sub OOS,$Pre-Sub OOS,Subs%,$Subs,OOS,OOS%,$OOS
            1,Jewel Osco,J1,184350009 - Sweet Corn,1755,2,0.121367521367521,213,425.89,0.00113960113960114,4.98,211,0.12022792022792,420.91
            76,Jewel Osco,J6,960012546 - Strawberries Prepacked - 2 Lb,278,57,0.553956834532374,154,1076.46,0.205035971223022,398.43,97,0.348920863309353,678.03
            3427,Haggen,39,184060007 - Banana,92,0,0.042,4,8.40,0,0,4,0.042,8.40
            Total,,, ,7536605,48582,0.017726681974178,133599,616674.06,0.00644613854646754,247768.28,85017,0.0112805434277105,368905.78
            Applied filters: BPN DESC top 20 by OOS
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
