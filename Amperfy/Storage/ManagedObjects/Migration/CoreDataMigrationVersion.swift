//
//  CoreDataVersion.swift
//  CoreDataMigration-Example
//
//  Created by William Boles on 02/01/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation
import CoreData

enum CoreDataMigrationVersion: String, CaseIterable {
    case v1 = "Amperfy"
    case v2 = "Amperfy v2"
    case v3 = "Amperfy v3"
    case v4 = "Amperfy v4"
    case v5 = "Amperfy v5"
    case v6 = "Amperfy v6"
    case v7 = "Amperfy v7"
    case v8 = "Amperfy v8"
    case v9 = "Amperfy v9"
    case v10 = "Amperfy v10"
    case v11 = "Amperfy v11"

    
    // MARK: - Current
    
    static var current: CoreDataMigrationVersion {
        guard let latest = allCases.last else {
            fatalError("no model versions found")
        }
        
        return latest
    }
    
    // MARK: - Migration
    
    func nextVersion() -> CoreDataMigrationVersion? {
        switch self {
        case .v1:
            return .v2
        case .v2:
            return .v3
        case .v3:
            return .v4
        case .v4:
            return .v5
        case .v5:
            return .v6
        case .v6:
            return .v7
        case .v7:
            return .v8
        case .v8:
            return .v9
        case .v9:
            return .v10
        case .v10:
            return .v11
        case .v11:
            return nil
        }
    }
}