//
//  StackedFolderView.swift
//  Dock
//
//  Wallet-style stacked folder view for properties
//

import SwiftUI
import CoreData

struct StackedFolderView: View {
    let folder: PropertyFolder
    let properties: [Property]
    let isExpanded: Bool
    let cardBackground: Color
    let colorScheme: ColorScheme
    let namespace: Namespace.ID
    
    let onToggleExpand: () -> Void
    let onPropertyTap: (Property) -> Void
    let onPropertyPin: (Property) -> Void
    let onPropertyDelete: (Property) -> Void
    let onPropertyDrop: (Property) -> Void
    let onRemoveFromFolder: ((Property) -> Void)?
    let onDeleteFolder: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Folder Header
            folderHeader
            
            // Stacked Cards
            if !properties.isEmpty {
                stackedCards
            } else {
                emptyFolderPlaceholder
            }
        }
        .animation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.5), value: isExpanded)
    }
    
    // MARK: - Folder Header
    
    private var folderHeader: some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.5)) {
                onToggleExpand()
            }
        } label: {
            HStack(spacing: 8) {
                // Color indicator
                Circle()
                    .fill(folder.color)
                    .frame(width: 8, height: 8)
                
                Text(folder.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text("\(properties.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Expand/collapse indicator
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDeleteFolder()
            } label: {
                Label("Delete Folder", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Stacked Cards
    
    private var stackedCards: some View {
        ZStack(alignment: .topLeading) {
            // Invisible spacer to establish the frame size
            Color.clear
                .frame(height: calculateStackHeight())
            
            ForEach(Array(properties.enumerated()), id: \.element.id) { index, property in
                StackedPropertyCard(
                    property: property,
                    index: index,
                    totalCount: properties.count,
                    isExpanded: isExpanded,
                    cardBackground: cardBackground,
                    colorScheme: colorScheme,
                    onTap: { onPropertyTap(property) },
                    onExpand: { onToggleExpand() },
                    onPin: { onPropertyPin(property) },
                    onDelete: { onPropertyDelete(property) },
                    onRemoveFromFolder: onRemoveFromFolder != nil ? { onRemoveFromFolder?(property) } : nil
                )
                .matchedTransitionSource(id: property.id, in: namespace)
                .zIndex(Double(properties.count - index))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Empty Folder Placeholder
    
    private var emptyFolderPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("Drag properties here")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(cardBackground.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(.secondary.opacity(0.25))
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
    
    // MARK: - Helper Methods
    
    private func calculateStackHeight() -> CGFloat {
        let cardHeight: CGFloat = 120
        let collapsedOffset: CGFloat = 15
        let expandedSpacing: CGFloat = cardHeight + 12
        
        if isExpanded {
            // Height = last card's offset + card height
            let lastCardOffset = CGFloat(properties.count - 1) * expandedSpacing
            return lastCardOffset + cardHeight
        } else {
            // Show stacked with peek offsets
            let peekCount = min(properties.count, 3)
            return cardHeight + CGFloat(peekCount - 1) * collapsedOffset
        }
    }
}

// MARK: - Stacked Property Card

struct StackedPropertyCard: View {
    let property: Property
    let index: Int
    let totalCount: Int
    let isExpanded: Bool
    let cardBackground: Color
    let colorScheme: ColorScheme
    let onTap: () -> Void
    let onExpand: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void
    let onRemoveFromFolder: (() -> Void)?
    
    // Swipe state
    @State private var swipeOffset: CGFloat = 0
    @State private var isRevealed: Bool = false
    @State private var notes: [PropertyNote] = []
    @State private var tags: [NoteTag] = []
    @State private var showingAddNote: Bool = false
    @State private var newNoteContent: String = ""
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var isEditMode: Bool = false
    @State private var noteToDelete: PropertyNote?
    @State private var showingDeleteConfirmation: Bool = false
    
    private let revealWidth: CGFloat = 260
    private let dragThreshold: CGFloat = 70
    
    private var score: Double {
        property.metrics.overallScore
    }
    
    private var recommendation: InvestmentRecommendation {
        property.metrics.recommendation
    }
    
    // Calculate offsets for stacking effect
    private var yOffset: CGFloat {
        let cardHeight: CGFloat = 120
        let expandedSpacing: CGFloat = cardHeight + 12
        let collapsedOffset: CGFloat = 15
        
        if isExpanded {
            return CGFloat(index) * expandedSpacing
        } else {
            // Only show first 3 cards peeking
            let visibleIndex = min(index, 2)
            return CGFloat(visibleIndex) * collapsedOffset
        }
    }
    
    private var scaleEffect: CGFloat {
        if isExpanded {
            return 1.0
        } else {
            // Scale down cards further back in the stack
            let visibleIndex = min(index, 2)
            return 1.0 - (CGFloat(visibleIndex) * 0.03)
        }
    }
    
    private var opacity: CGFloat {
        if isExpanded {
            return 1.0
        } else {
            // Hide cards beyond the 3rd
            if index > 2 {
                return 0.0
            }
            return 1.0 - (CGFloat(index) * 0.1)
        }
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Notes panel (only when expanded)
            if isExpanded {
                stackedNotesPanel
                    .frame(width: revealWidth, height: 120)
                    .opacity(swipeOffset < -20 ? 1 : 0)
            }
            
            // Card content
            cardContent
                .offset(x: isExpanded ? swipeOffset : 0)
                .simultaneousGesture(isExpanded ? swipeGesture : nil)
                .onTapGesture {
                    if isRevealed {
                        closeReveal()
                    } else if isExpanded {
                        onTap()
                        HapticManager.shared.impact(.light)
                    } else {
                        withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.5)) {
                            onExpand()
                        }
                        HapticManager.shared.impact(.light)
                    }
                }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(isExpanded ? 0.08 : 0.12), radius: isExpanded ? 4 : 8, y: isExpanded ? 2 : 4)
        .offset(y: yOffset)
        .scaleEffect(scaleEffect)
        .opacity(opacity)
        .contextMenu {
            if isExpanded {
                Button {
                    onPin()
                } label: {
                    Label(property.isPinned ? "Unpin" : "Pin", systemImage: property.isPinned ? "pin.slash" : "pin")
                }
                
                if let onRemoveFromFolder = onRemoveFromFolder {
                    Button {
                        onRemoveFromFolder()
                    } label: {
                        Label("Remove from Folder", systemImage: "folder.badge.minus")
                    }
                }
                
                Divider()
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .draggable(property.id.uuidString)
        .onAppear {
            loadNotes()
            loadTags()
        }
        .onChange(of: isExpanded) { _, expanded in
            if !expanded {
                closeReveal()
            }
        }
        .sheet(isPresented: $showingAddNote) {
            QuickAddNoteSheet(
                propertyID: property.id,
                availableTags: tags,
                content: $newNoteContent,
                selectedTagIDs: $selectedTagIDs,
                onAdd: {
                    Task {
                        await addNote()
                        showingAddNote = false
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert("Delete Note?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                noteToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let note = noteToDelete {
                    Task {
                        await deleteNote(note)
                    }
                }
            }
        } message: {
            Text("This note will be permanently deleted.")
        }
    }
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                // Only handle horizontal swipes - check if horizontal movement dominates
                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                
                // Require horizontal to be at least 1.5x vertical to be considered a swipe
                guard horizontal > vertical * 1.5 else { return }
                
                let translation = value.translation.width
                if isRevealed {
                    let newOffset = -revealWidth + translation
                    swipeOffset = min(0, max(-revealWidth, newOffset))
                } else {
                    swipeOffset = min(0, translation)
                }
            }
            .onEnded { value in
                // Only process if we actually moved the card
                guard swipeOffset != 0 else { return }
                
                let velocity = value.velocity.width
                let shouldReveal: Bool
                
                if isRevealed {
                    shouldReveal = swipeOffset < -revealWidth / 2 && velocity < 500
                } else {
                    shouldReveal = swipeOffset < -dragThreshold || velocity < -500
                }
                
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if shouldReveal {
                        swipeOffset = -revealWidth
                        isRevealed = true
                    } else {
                        swipeOffset = 0
                        isRevealed = false
                    }
                }
                
                if shouldReveal {
                    HapticManager.shared.impact(.light)
                }
            }
    }
    
    private func closeReveal() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            swipeOffset = 0
            isRevealed = false
        }
    }
    
    // MARK: - Stacked Notes Panel
    
    private var stackedNotesPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with action buttons
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                
                Text("Notes")
                    .font(.system(size: 11))
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Edit button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditMode.toggle()
                    }
                    HapticManager.shared.impact(.light)
                } label: {
                    Image(systemName: isEditMode ? "checkmark" : "pencil")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 24, height: 24)
                }
                .glassEffect(.regular, in: .circle)
                
                // Add button
                Button {
                    showingAddNote = true
                    HapticManager.shared.impact(.light)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 24, height: 24)
                }
                .glassEffect(.regular, in: .circle)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            
            if notes.isEmpty {
                // Empty state
                VStack(spacing: 4) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                    Text("No notes")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Notes in flow layout
                ScrollView(.vertical, showsIndicators: false) {
                    NoteCapsuleFlowLayout(spacing: 4) {
                        ForEach(notes) { note in
                            StackedNoteCapsule(
                                note: note,
                                isEditMode: isEditMode,
                                colorScheme: colorScheme,
                                onDelete: {
                                    noteToDelete = note
                                    showingDeleteConfirmation = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private var cardContent: some View {
        HStack(spacing: 14) {
            // Property image
            propertyImage
                .frame(width: 90, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Price and score
                HStack {
                    Text(property.askingPrice.asCompactCurrency)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    
                    Spacer()
                    
                    scoreBadge
                    
                    if property.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                
                // Address
                Text(property.address)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text("\(property.city), \(property.state)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Stats
                HStack(spacing: 10) {
                    CompactStat(value: "\(property.bedrooms)", label: "bd")
                    CompactStat(value: String(format: "%.1f", property.bathrooms), label: "ba")
                    
                    Spacer()
                    
                    cashFlowBadge
                }
            }
        }
        .padding(10)
        .frame(height: 120)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    
    @ViewBuilder
    private var propertyImage: some View {
        if let photoData = property.primaryPhotoData,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let firstURL = property.photoURLs.first,
                  let url = URL(string: firstURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.primary.opacity(0.06),
                        Color.primary.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: property.propertyType.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.primary.opacity(0.2))
            }
    }
    
    private var scoreBadge: some View {
        HStack(spacing: 4) {
            Text("\(Int(score))")
                .font(.system(.caption, design: .rounded, weight: .bold))
            
            Circle()
                .fill(recommendation.color)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
    
    private var cashFlowBadge: some View {
        let cashFlow = property.metrics.dealEconomics.monthlyCashFlow
        return Text(cashFlow.asCurrency)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundStyle(cashFlow >= 0 ? .green : .red)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background((cashFlow >= 0 ? Color.green : Color.red).opacity(0.1))
            .clipShape(Capsule())
    }
    
    // MARK: - Data Loading
    
    private func loadNotes() {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "property.id == %@", property.id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NoteEntity.createdAt, ascending: false)]
        request.fetchLimit = 10
        
        do {
            let entities = try context.fetch(request)
            notes = entities.map { entity in
                var tagIDs: [UUID] = []
                if let tagIDsString = entity.tagIDs {
                    tagIDs = tagIDsString.components(separatedBy: ",").compactMap { UUID(uuidString: $0) }
                }
                
                return PropertyNote(
                    id: entity.id ?? UUID(),
                    createdAt: entity.createdAt ?? Date(),
                    updatedAt: entity.updatedAt ?? Date(),
                    areaName: entity.areaName ?? "",
                    content: entity.content ?? "",
                    sortOrder: Int(entity.sortOrder),
                    tagIDs: tagIDs
                )
            }
        } catch {
            print("Failed to load notes: \(error)")
        }
    }
    
    private func loadTags() {
        let tagsKey = "app.dock.noteTags"
        if let data = UserDefaults.standard.data(forKey: tagsKey),
           let loadedTags = try? JSONDecoder().decode([NoteTag].self, from: data) {
            tags = loadedTags.sorted { $0.name < $1.name }
        }
    }
    
    private func addNote() async {
        guard !newNoteContent.isEmpty else { return }
        
        let context = PersistenceController.shared.container.viewContext
        let entity = NoteEntity(context: context)
        entity.id = UUID()
        entity.createdAt = Date()
        entity.updatedAt = Date()
        entity.content = newNoteContent
        entity.sortOrder = Int16(notes.count)
        entity.tagIDs = selectedTagIDs.map { $0.uuidString }.joined(separator: ",")
        
        let propertyRequest: NSFetchRequest<PropertyEntity> = PropertyEntity.fetchRequest()
        propertyRequest.predicate = NSPredicate(format: "id == %@", property.id as CVarArg)
        
        do {
            if let propertyEntity = try context.fetch(propertyRequest).first {
                entity.property = propertyEntity
            }
            try context.save()
            
            let newNote = PropertyNote(
                id: entity.id ?? UUID(),
                createdAt: Date(),
                content: newNoteContent,
                tagIDs: Array(selectedTagIDs)
            )
            notes.insert(newNote, at: 0)
            
            newNoteContent = ""
            selectedTagIDs = []
            
            HapticManager.shared.success()
        } catch {
            print("Failed to save note: \(error)")
        }
    }
    
    private func deleteNote(_ note: PropertyNote) async {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                try context.save()
                notes.removeAll { $0.id == note.id }
                noteToDelete = nil
                HapticManager.shared.notification(.success)
            }
        } catch {
            print("Failed to delete note: \(error)")
        }
    }
}

// MARK: - Stacked Note Capsule (Compact)

struct StackedNoteCapsule: View {
    let note: PropertyNote
    let isEditMode: Bool
    let colorScheme: ColorScheme
    let onDelete: () -> Void
    
    var body: some View {
        Button {
            if isEditMode {
                onDelete()
                HapticManager.shared.impact(.medium)
            }
        } label: {
            HStack(spacing: 3) {
                if isEditMode {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
                
                Text(note.content)
                    .font(.system(size: 10))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isEditMode ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isEditMode)
    }
}

// MARK: - Create Folder Sheet

struct CreateFolderSheet: View {
    @Binding var folderName: String
    @Binding var folderColor: String
    let onCreate: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private let colors: [String] = [
        "#007AFF", // Blue
        "#34C759", // Green
        "#FF9500", // Orange
        "#FF3B30", // Red
        "#AF52DE", // Purple
        "#FF2D55", // Pink
        "#5856D6", // Indigo
        "#00C7BE", // Teal
    ]
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    TextField("Enter folder name", text: $folderName)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Color picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Color")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Button {
                                folderColor = color
                                HapticManager.shared.selection()
                            } label: {
                                Circle()
                                    .fill(Color(hex: color) ?? .blue)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if folderColor == color {
                                            Circle()
                                                .stroke(.white, lineWidth: 2.5)
                                                .frame(width: 22, height: 22)
                                        }
                                    }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate()
                    }
                    .fontWeight(.semibold)
                    .disabled(folderName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
