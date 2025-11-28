//
//  Date+Format.swift
//  RealTimeChat
//
//   Created by Priyanka Ghosh on 28/11/25.
//

import Foundation

extension Date {
    static let sharedTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    var formattedTime: String {
        Date.sharedTimeFormatter.string(from: self)
    }
}



