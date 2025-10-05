//
//  Item.swift
//  wattsapp
//
//  Created by PANburger on 2025/10/05.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
