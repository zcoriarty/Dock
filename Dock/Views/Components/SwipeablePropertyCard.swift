//
//  SwipeablePropertyCard.swift
//  Dock
//
//  Swipeable property card with notes and tags reveal
//

import SwiftUI
import CoreData

struct SwipeablePropertyCard: View {
    let property: Property
    let cardBackground: Color
    let colorScheme: ColorScheme
    let onPin: () -> Void
    let onDelete: () -> Void
    let onTap: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isRevealed: Bool = false
    @State private var notes: [PropertyNote] = []
    @State private var tags: [NoteTag] = []
    @State private var showingAddNote: Bool = false
    @State private var newNoteContent: String = ""
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var isEditMode: Bool = false
    @State private var noteToDelete: PropertyNote?
    @State private var showingDeleteConfirmation: Bool = false
    
    private let revealWidth: CGFloat = 280
    private let dragThreshold: CGFloat = 80
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Notes reveal panel (behind the card)
            notesRevealPanel
                .frame(width: revealWidth)
                .opacity(offset < -20 ? 1 : 0)
            
            // Main property card
            PropertyCard(
                property: property,
                cardBackground: cardBackground,
                colorScheme: colorScheme,
                onPin: onPin,
                onDelete: onDelete
            )
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        // Only handle horizontal swipes - check if horizontal movement dominates
                        let horizontal = abs(value.translation.width)
                        let vertical = abs(value.translation.height)
                        
                        // Require horizontal to be at least 1.5x vertical to be considered a swipe
                        guard horizontal > vertical * 1.5 else { return }
                        
                        let translation = value.translation.width
                        if isRevealed {
                            // If already revealed, allow dragging back
                            let newOffset = -revealWidth + translation
                            offset = min(0, max(-revealWidth, newOffset))
                        } else {
                            // Only allow left swipe
                            offset = min(0, translation)
                        }
                    }
                    .onEnded { value in
                        // Only process if we actually moved the card
                        guard offset != 0 else { return }
                        
                        let velocity = value.velocity.width
                        let shouldReveal: Bool
                        
                        if isRevealed {
                            // Close if dragged enough to the right or velocity is right
                            shouldReveal = offset < -revealWidth / 2 && velocity < 500
                        } else {
                            // Open if dragged enough to the left or velocity is left
                            shouldReveal = offset < -dragThreshold || velocity < -500
                        }
                        
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if shouldReveal {
                                offset = -revealWidth
                                isRevealed = true
                            } else {
                                offset = 0
                                isRevealed = false
                            }
                        }
                        
                        if shouldReveal {
                            HapticManager.shared.impact(.light)
                        }
                    }
            )
            .onTapGesture {
                if isRevealed {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        offset = 0
                        isRevealed = false
                    }
                } else {
                    onTap()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onAppear {
            loadNotes()
            loadTags()
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
    
    // MARK: - Notes Reveal Panel
    
    private var notesRevealPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with action buttons
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Notes")
                    .font(.caption)
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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 28, height: 28)
                }
                .glassEffect(.regular, in: .circle)

                // Add button
                Button {
                    showingAddNote = true
                    HapticManager.shared.impact(.light)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 28, height: 28)
                }
                .glassEffect(.regular, in: .circle)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            
            // Notes content in scroll view
            if notes.isEmpty {
                emptyNotesState
            } else {
                notesScrollView
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Empty Notes State
    
    private var emptyNotesState: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)
            
            Text("No notes yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Notes Scroll View
    
    private var notesScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            NoteCapsuleFlowLayout(spacing: 6) {
                ForEach(notes) { note in
                    NoteCapsule(
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
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
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
        
        // Link to property
        let propertyRequest: NSFetchRequest<PropertyEntity> = PropertyEntity.fetchRequest()
        propertyRequest.predicate = NSPredicate(format: "id == %@", property.id as CVarArg)
        
        do {
            if let propertyEntity = try context.fetch(propertyRequest).first {
                entity.property = propertyEntity
            }
            try context.save()
            
            // Create the note object and add to our list
            let newNote = PropertyNote(
                id: entity.id ?? UUID(),
                createdAt: Date(),
                content: newNoteContent,
                tagIDs: Array(selectedTagIDs)
            )
            notes.insert(newNote, at: 0)
            
            // Reset form
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

// MARK: - Note Capsule

struct NoteCapsule: View {
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
            HStack(spacing: 4) {
                if isEditMode {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                
                Text(note.content)
                    .font(.system(size: 11))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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

// MARK: - Note Capsule Flow Layout

struct NoteCapsuleFlowLayout: Layout {
    var spacing: CGFloat = 6
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flowResult(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flowResult(in: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ),
                proposal: .unspecified
            )
        }
    }
    
    private func flowResult(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        
        return (CGSize(width: width, height: y + rowHeight), positions)
    }
}

// MARK: - Quick Add Note Sheet

struct QuickAddNoteSheet: View {
    let propertyID: UUID
    let availableTags: [NoteTag]
    @Binding var content: String
    @Binding var selectedTagIDs: Set<UUID>
    let onAdd: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isContentFocused: Bool
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Quick templates
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick Notes")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(QuickNoteTemplate.templates.prefix(8)) { template in
                                Button {
                                    content = template.content
                                } label: {
                                    Text(template.title)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.primary.opacity(0.08))
                                        .foregroundStyle(.primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Tags section
                if !availableTags.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tags")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(availableTags) { tag in
                                    Button {
                                        if selectedTagIDs.contains(tag.id) {
                                            selectedTagIDs.remove(tag.id)
                                        } else {
                                            selectedTagIDs.insert(tag.id)
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(tag.color)
                                                .frame(width: 6, height: 6)
                                            
                                            Text(tag.name)
                                                .font(.caption)
                                                .fontWeight(selectedTagIDs.contains(tag.id) ? .semibold : .regular)
                                            
                                            if selectedTagIDs.contains(tag.id) {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 9, weight: .bold))
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(selectedTagIDs.contains(tag.id) ? tag.color.opacity(0.15) : Color.clear)
                                        .foregroundStyle(.primary)
                                        .clipShape(Capsule())
                                        .overlay {
                                            Capsule()
                                                .stroke(selectedTagIDs.contains(tag.id) ? tag.color : Color.primary.opacity(0.15), lineWidth: 1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Note content
                VStack(alignment: .leading, spacing: 10) {
                    Text("Note")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    TextEditor(text: $content)
                        .focused($isContentFocused)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100)
                        .padding(12)
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 20)
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Quick Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd()
                    }
                    .fontWeight(.semibold)
                    .disabled(content.isEmpty)
                }
            }
            .onAppear {
                isContentFocused = true
            }
        }
    }
}

// MARK: - Date Extension

extension Date {
    var compactFormat: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(self) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else if calendar.isDate(self, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEE"
        } else {
            formatter.dateFormat = "MMM d"
        }
        
        return formatter.string(from: self)
    }
}

// MARK: - Preview

#Preview {
    SwipeablePropertyCard(
        property: .preview,
        cardBackground: Color(white: 0.97),
        colorScheme: .light,
        onPin: {},
        onDelete: {},
        onTap: {}
    )
    .padding()
}
