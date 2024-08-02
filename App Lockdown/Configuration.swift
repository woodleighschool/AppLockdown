//
//  Configuration.swift
//  App Lockdown
//
//  Created by Alexander Hyde on 1/8/2024.
//

import Foundation

struct Configuration: Decodable {
    let processes: [String]
    let restrictedHours: [String: [String]]
}

enum Day: Int, CaseIterable {
    case sun = 1, mon, tue, wed, thu, fri, sat
    
    var description: String {
        switch self {
        case .sun: return "SUN"
        case .mon: return "MON"
        case .tue: return "TUE"
        case .wed: return "WED"
        case .thu: return "THU"
        case .fri: return "FRI"
        case .sat: return "SAT"
        }
    }
}
