//
//  PropertyChecklist.swift
//  Dock
//
//  Created by Dock AI on 2026-01-15.
//

import Foundation

// MARK: - Filter Enum

enum ChecklistFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case flagged = "Flagged"
    case completed = "Completed"
    
    var id: String { rawValue }
}

enum ChecklistAuthorization: String, Codable, Sendable {
    case notStarted
    case inProgress
    case complete
}

struct ChecklistItem: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var title: String
    var isChecked: Bool = false
    var answer: String? // For questions that need specific input
    var note: String? // For additional context
    var isFlagged: Bool = false // For "Red Flags" or important items
    
    // For hierarchical items if needed, though flat list per section is simpler for now
    var subItems: [ChecklistItem]?
}

struct ChecklistSection: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var title: String
    var type: SectionType
    var items: [ChecklistItem]
    
    enum SectionType: String, Codable, Sendable {
        case before = "Before the Tour"
        case during = "During the Tour"
        case after = "After the Tour"
        
        var icon: String {
            switch self {
            case .before: return "magnifyingglass.circle.fill"
            case .during: return "door.left.hand.open"
            case .after: return "doc.text.fill"
            }
        }
    }
    
    var progress: Double {
        guard !items.isEmpty else { return 0 }
        let completedCount = items.filter { $0.isChecked }.count
        return Double(completedCount) / Double(items.count)
    }
}

struct PropertyChecklist: Hashable, Codable, Sendable {
    var sections: [ChecklistSection]
    
    var totalProgress: Double {
        let totalItems = sections.flatMap { $0.items }.count
        guard totalItems > 0 else { return 0 }
        let completedItems = sections.flatMap { $0.items }.filter { $0.isChecked }.count
        return Double(completedItems) / Double(totalItems)
    }
    
    static let defaultChecklist: PropertyChecklist = {
        let beforeItems = [
            ChecklistItem(title: "Commute time to work/school"),
            ChecklistItem(title: "Noise sources nearby (highways, railroads, bars, airports)"),
            ChecklistItem(title: "Flood zone, wildfire risk, earthquake risk"),
            ChecklistItem(title: "Crime rates and safety trends"),
            ChecklistItem(title: "Nearby amenities (grocery, hospital, parks, transit)"),
            ChecklistItem(title: "School district quality"),
            ChecklistItem(title: "Future developments planned nearby"),
            ChecklistItem(title: "Year built"),
            ChecklistItem(title: "Lot size and boundaries"),
            ChecklistItem(title: "HOA existence, fees, and rules"),
            ChecklistItem(title: "Property taxes (current and historical)"),
            ChecklistItem(title: "Utility costs (averages)"),
            ChecklistItem(title: "Time on market"),
            ChecklistItem(title: "Price changes since listing"),
            ChecklistItem(title: "Recent comparable sales nearby"),
            ChecklistItem(title: "Reason for selling"),
            ChecklistItem(title: "Must-haves vs nice-to-haves defined"),
            ChecklistItem(title: "Renovation budget estimated"),
            ChecklistItem(title: "Lender pre-approval ready"),
            ChecklistItem(title: "Phone fully charged")
        ]
        
        // During - Exterior & General
        let duringItems = [
            ChecklistItem(title: "Smell (musty, mold, smoke, pet odors)"),
            ChecklistItem(title: "Temperature consistency between rooms"),
            ChecklistItem(title: "Overall maintenance level"),
            ChecklistItem(title: "Natural light"),
            ChecklistItem(title: "Roof condition (age, missing shingles)"),
            ChecklistItem(title: "Gutters and downspouts"),
            ChecklistItem(title: "Foundation cracks"),
            ChecklistItem(title: "Grading slopes away from house"),
            ChecklistItem(title: "Siding/brick condition"),
            ChecklistItem(title: "Driveway cracks or pooling"),
            ChecklistItem(title: "Yard drainage issues"),
            ChecklistItem(title: "Fencing condition"),
            ChecklistItem(title: "Open and close several windows", answer: ""),
            ChecklistItem(title: "Drafts or condensation between panes"),
            ChecklistItem(title: "Locks work properly"),
            ChecklistItem(title: "Exterior doors aligned and sealed"),
            ChecklistItem(title: "Cracks in walls or ceilings"),
            ChecklistItem(title: "Uneven or sloping floors"),
            ChecklistItem(title: "Stains (water damage signs)"),
            ChecklistItem(title: "Fresh paint in isolated spots"),
            ChecklistItem(title: "Squeaks or soft spots in floors"),
            
            // Kitchen
            ChecklistItem(title: "Water pressure at sink"),
            ChecklistItem(title: "Check under sink for leaks"),
            ChecklistItem(title: "Appliance age and condition", answer: ""),
            ChecklistItem(title: "Cabinets open/close smoothly"),
            ChecklistItem(title: "Adequate outlets (GFCI near sink)"),
            ChecklistItem(title: "Venting (outside vs recirculating)"),
            
            // Bathrooms
            ChecklistItem(title: "Flush toilets"),
            ChecklistItem(title: "Water pressure and drainage"),
            ChecklistItem(title: "Tile cracks or loose grout"),
            ChecklistItem(title: "Signs of mold or mildew"),
            ChecklistItem(title: "Vent fans actually vent outside"),
            
            // Other Rooms/Systems
            ChecklistItem(title: "Adequate closet space"),
            ChecklistItem(title: "Egress windows in bedrooms"),
            ChecklistItem(title: "Noise levels in bedrooms"),
            ChecklistItem(title: "Electrical panel age and labeling"),
            ChecklistItem(title: "Breaker vs fuse box"),
            ChecklistItem(title: "Enough outlets per room"),
            ChecklistItem(title: "GFCI outlets in wet areas"),
            ChecklistItem(title: "Light switches function properly"),
            ChecklistItem(title: "Age of furnace/AC/heat pump", answer: ""),
            ChecklistItem(title: "Airflow from vents"),
            ChecklistItem(title: "Thermostat works"),
            ChecklistItem(title: "Water heater age and type"),
            ChecklistItem(title: "Visible rust or leaks"),
            
            // Attic/Bsmt/Garage
            ChecklistItem(title: "Attic/Bsmt moisture or water"),
            ChecklistItem(title: "Mold or mildew smell"),
            ChecklistItem(title: "Adequate insulation"),
            ChecklistItem(title: "Structural supports intact"),
            ChecklistItem(title: "Pest evidence"),
            ChecklistItem(title: "Garage door opens/closes"),
            ChecklistItem(title: "Auto-reverse safety"),
            ChecklistItem(title: "Garage outlets"),
            ChecklistItem(title: "Cracks or water intrusion in garage"),
            
            // Red Flags
            ChecklistItem(title: "Strong air fresheners everywhere", isFlagged: true),
            ChecklistItem(title: "Multiple recent patch jobs", isFlagged: true),
            ChecklistItem(title: "Seller avoids direct answers", isFlagged: true),
            ChecklistItem(title: "Water stains with 'it was fixed' but no doc", isFlagged: true),
            ChecklistItem(title: "Obvious DIY electrical/plumbing", isFlagged: true)
        ]
        
        let afterItems = [
            ChecklistItem(title: "Write notes while memory is fresh"),
            ChecklistItem(title: "Review photos/videos taken"),
            ChecklistItem(title: "Compare against must-have list"),
            ChecklistItem(title: "Rank concerns by severity"),
            ChecklistItem(title: "Request seller disclosures"),
            ChecklistItem(title: "Review HOA documents"),
            ChecklistItem(title: "Get insurance quotes"),
            ChecklistItem(title: "Research permit history"),
            ChecklistItem(title: "Check property boundaries"),
            ChecklistItem(title: "General home inspection"),
            ChecklistItem(title: "Sewer scope"),
            ChecklistItem(title: "Radon test"),
            ChecklistItem(title: "Termite/pest inspection"),
            ChecklistItem(title: "Roof inspection (if older)"),
            ChecklistItem(title: "Structural engineer (if needed)")
        ]
        
        return PropertyChecklist(sections: [
            ChecklistSection(title: "Research & Preparation", type: .before, items: beforeItems),
            ChecklistSection(title: "Inspection & Questions", type: .during, items: duringItems),
            ChecklistSection(title: "Due Diligence", type: .after, items: afterItems)
        ])
    }()
}
