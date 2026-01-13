//
//  PropertyNote.swift
//  Dock
//
//  Notes system for property visits with areas and media
//

import Foundation
import SwiftUI

// MARK: - Property Note

struct PropertyNote: Identifiable, Hashable, Sendable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var areaName: String
    var content: String
    var sortOrder: Int
    var media: [NoteMedia]
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        areaName: String = "",
        content: String = "",
        sortOrder: Int = 0,
        media: [NoteMedia] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.areaName = areaName
        self.content = content
        self.sortOrder = sortOrder
        self.media = media
    }
}

// MARK: - Note Media

struct NoteMedia: Identifiable, Hashable, Sendable {
    let id: UUID
    var createdAt: Date
    var mediaType: MediaType
    var localPath: String?
    var cloudKitRecordID: String?
    var thumbnailData: Data?
    var caption: String
    var sortOrder: Int
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        mediaType: MediaType = .photo,
        localPath: String? = nil,
        cloudKitRecordID: String? = nil,
        thumbnailData: Data? = nil,
        caption: String = "",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.mediaType = mediaType
        self.localPath = localPath
        self.cloudKitRecordID = cloudKitRecordID
        self.thumbnailData = thumbnailData
        self.caption = caption
        self.sortOrder = sortOrder
    }
}

enum MediaType: String, Codable, Sendable {
    case photo = "photo"
    case video = "video"
    
    var icon: String {
        switch self {
        case .photo: return "photo.fill"
        case .video: return "video.fill"
        }
    }
}

// MARK: - Property Areas

enum PropertyArea: String, CaseIterable, Identifiable, Sendable {
    case exterior = "Exterior"
    case livingRoom = "Living Room"
    case kitchen = "Kitchen"
    case diningRoom = "Dining Room"
    case masterBedroom = "Master Bedroom"
    case bedroom2 = "Bedroom 2"
    case bedroom3 = "Bedroom 3"
    case bedroom4 = "Bedroom 4"
    case masterBath = "Master Bath"
    case bathroom2 = "Bathroom 2"
    case bathroom3 = "Bathroom 3"
    case basement = "Basement"
    case attic = "Attic"
    case garage = "Garage"
    case backyard = "Backyard"
    case frontYard = "Front Yard"
    case roof = "Roof"
    case hvac = "HVAC"
    case electrical = "Electrical"
    case plumbing = "Plumbing"
    case foundation = "Foundation"
    case windows = "Windows"
    case flooring = "Flooring"
    case appliances = "Appliances"
    case laundry = "Laundry"
    case storage = "Storage"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .exterior: return "house.fill"
        case .livingRoom: return "sofa.fill"
        case .kitchen: return "refrigerator.fill"
        case .diningRoom: return "fork.knife"
        case .masterBedroom, .bedroom2, .bedroom3, .bedroom4: return "bed.double.fill"
        case .masterBath, .bathroom2, .bathroom3: return "shower.fill"
        case .basement: return "arrow.down.to.line"
        case .attic: return "arrow.up.to.line"
        case .garage: return "car.fill"
        case .backyard: return "tree.fill"
        case .frontYard: return "leaf.fill"
        case .roof: return "house.lodge.fill"
        case .hvac: return "fan.fill"
        case .electrical: return "bolt.fill"
        case .plumbing: return "drop.fill"
        case .foundation: return "square.stack.fill"
        case .windows: return "window.horizontal.closed"
        case .flooring: return "square.grid.2x2.fill"
        case .appliances: return "washer.fill"
        case .laundry: return "washer.fill"
        case .storage: return "archivebox.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    var category: PropertyAreaCategory {
        switch self {
        case .exterior, .backyard, .frontYard, .roof, .foundation:
            return .exterior
        case .livingRoom, .diningRoom:
            return .commonAreas
        case .kitchen, .laundry, .appliances:
            return .kitchen
        case .masterBedroom, .bedroom2, .bedroom3, .bedroom4:
            return .bedrooms
        case .masterBath, .bathroom2, .bathroom3:
            return .bathrooms
        case .basement, .attic, .garage, .storage:
            return .utility
        case .hvac, .electrical, .plumbing, .windows, .flooring:
            return .systems
        case .other:
            return .other
        }
    }
}

enum PropertyAreaCategory: String, CaseIterable, Sendable {
    case exterior = "Exterior"
    case commonAreas = "Common Areas"
    case kitchen = "Kitchen & Laundry"
    case bedrooms = "Bedrooms"
    case bathrooms = "Bathrooms"
    case utility = "Utility Spaces"
    case systems = "Systems & Components"
    case other = "Other"
    
    var areas: [PropertyArea] {
        PropertyArea.allCases.filter { $0.category == self }
    }
}

// MARK: - Quick Note Templates

struct QuickNoteTemplate: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let content: String
    let category: NoteCategory
    
    static let templates: [QuickNoteTemplate] = [
        // Condition
        QuickNoteTemplate(title: "Needs Work", content: "Requires significant renovation/repair", category: .condition),
        QuickNoteTemplate(title: "Good Condition", content: "Well maintained, minimal work needed", category: .condition),
        QuickNoteTemplate(title: "Move-in Ready", content: "Excellent condition, no immediate work required", category: .condition),
        
        // Issues
        QuickNoteTemplate(title: "Water Damage", content: "Signs of water damage observed", category: .issue),
        QuickNoteTemplate(title: "Foundation Concern", content: "Possible foundation issues - recommend inspection", category: .issue),
        QuickNoteTemplate(title: "Outdated", content: "Dated finishes, may need updating for rental market", category: .issue),
        QuickNoteTemplate(title: "Code Violation", content: "Potential code violation - verify before purchase", category: .issue),
        
        // Positive
        QuickNoteTemplate(title: "Updated", content: "Recently updated/renovated", category: .positive),
        QuickNoteTemplate(title: "Good Layout", content: "Functional floor plan, good flow", category: .positive),
        QuickNoteTemplate(title: "Curb Appeal", content: "Strong curb appeal, attractive exterior", category: .positive),
        QuickNoteTemplate(title: "Natural Light", content: "Great natural light throughout", category: .positive),
        
        // Follow-up
        QuickNoteTemplate(title: "Get Quote", content: "Need contractor quote for: ", category: .followUp),
        QuickNoteTemplate(title: "Verify", content: "Need to verify: ", category: .followUp),
        QuickNoteTemplate(title: "Compare", content: "Compare with similar properties", category: .followUp),
    ]
}

enum NoteCategory: String, CaseIterable, Sendable {
    case condition = "Condition"
    case issue = "Issues"
    case positive = "Positives"
    case followUp = "Follow-up"
    
    var color: Color {
        switch self {
        case .condition: return .blue
        case .issue: return .red
        case .positive: return .green
        case .followUp: return .orange
        }
    }
}
