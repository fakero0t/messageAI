//
//  User.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let displayName: String
    var online: Bool = false
}

