//
//  NotesView.swift
//  Dock
//
//  Property notes with areas, tags, and media support
//

import SwiftUI
import PhotosUI

struct NotesView: View {
    @State private var viewModel: NotesViewModel
    @State private var showingAddNote = false
    @State private var showingTagManager = false
    @State private var newNoteContent = ""
    @State private var selectedNoteArea: PropertyArea?
    @State private var selectedTagIDs: Set<UUID> = []
    @Environment(\.colorScheme) private var colorScheme
    
    init(propertyID: UUID) {
        _viewModel = State(initialValue: NotesViewModel(propertyID: propertyID))
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Filter section
            VStack(spacing: 12) {
                // Area filter
                areaFilter
                
                // Tag filter
                if !viewModel.availableTags.isEmpty {
                    tagFilter
                }
            }
            
            // Notes list or empty state
            if viewModel.filteredNotes.isEmpty {
                emptyState
            } else {
                notesList
            }
            
            // Bottom buttons
            HStack(spacing: 12) {
                Button {
                    showingTagManager = true
                } label: {
                    Image(systemName: "tag")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(width: 48, height: 48)
                        .background(cardBackground)
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                
                addNoteButton
            }
        }
        .sheet(isPresented: $showingAddNote) {
            AddNoteSheet(
                viewModel: viewModel,
                selectedArea: $selectedNoteArea,
                selectedTagIDs: $selectedTagIDs,
                content: $newNoteContent,
                onAdd: {
                    Task {
                        await viewModel.addNote(
                            area: selectedNoteArea,
                            content: newNoteContent,
                            tagIDs: Array(selectedTagIDs)
                        )
                        newNoteContent = ""
                        selectedTagIDs = []
                        showingAddNote = false
                    }
                }
            )
        }
        .sheet(isPresented: $showingTagManager) {
            TagManagerSheet(viewModel: viewModel)
        }
    }
    
    // MARK: - Area Filter
    
    private var areaFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All
                FilterChip(
                    name: "All",
                    icon: "note.text",
                    count: viewModel.notes.count,
                    isSelected: viewModel.selectedArea == nil,
                    colorScheme: colorScheme
                ) {
                    viewModel.selectedArea = nil
                }
                
                // Areas with notes
                ForEach(viewModel.areasWithNotes) { area in
                    FilterChip(
                        name: area.rawValue,
                        icon: area.icon,
                        count: viewModel.notesByArea[area]?.count ?? 0,
                        isSelected: viewModel.selectedArea == area,
                        colorScheme: colorScheme
                    ) {
                        viewModel.selectedArea = area
                    }
                }
            }
        }
    }
    
    // MARK: - Tag Filter
    
    private var tagFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.availableTags) { tag in
                    TagChip(
                        tag: tag,
                        isSelected: viewModel.selectedTagFilter == tag.id,
                        colorScheme: colorScheme
                    ) {
                        if viewModel.selectedTagFilter == tag.id {
                            viewModel.selectedTagFilter = nil
                        } else {
                            viewModel.selectedTagFilter = tag.id
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Notes List
    
    private var notesList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.filteredNotes) { note in
                ModernNoteCard(
                    note: note,
                    tags: viewModel.tags(for: note),
                    cardBackground: cardBackground,
                    colorScheme: colorScheme,
                    onEdit: {
                        viewModel.editingNote = note
                    },
                    onDelete: {
                        Task {
                            await viewModel.deleteNote(note)
                        }
                    },
                    onAddMedia: {
                        viewModel.editingNote = note
                        viewModel.showingPhotoPicker = true
                    }
                )
            }
        }
        .photosPicker(
            isPresented: $viewModel.showingPhotoPicker,
            selection: $viewModel.selectedPhotos,
            maxSelectionCount: 10,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: viewModel.selectedPhotos) { _, _ in
            Task {
                await viewModel.processSelectedPhotos()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(cardBackground)
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: "note.text")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            
            VStack(spacing: 4) {
                Text("No notes yet")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Add notes while visiting this property")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Add Button
    
    private var addNoteButton: some View {
        Button {
            showingAddNote = true
            Task { @MainActor in
                HapticManager.shared.impact(.medium)
            }
        } label: {
            Text("Add Note")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.primary)
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let name: String
    let icon: String
    let count: Int
    let isSelected: Bool
    var colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? Color.primary.opacity(0.7) : Color.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primary : Color.clear)
            .foregroundStyle(isSelected ? (colorScheme == .dark ? Color.black : Color.white) : .primary)
            .clipShape(Capsule())
            .overlay {
                if !isSelected {
                    Capsule()
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let tag: NoteTag
    let isSelected: Bool
    var colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(tag.color)
                    .frame(width: 6, height: 6)
                
                Text(tag.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? tag.color.opacity(0.15) : Color.clear)
            .foregroundStyle(.primary)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? tag.color : Color.primary.opacity(0.15), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modern Note Card

struct ModernNoteCard: View {
    let note: PropertyNote
    let tags: [NoteTag]
    let cardBackground: Color
    let colorScheme: ColorScheme
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onAddMedia: () -> Void
    
    @State private var showingMedia = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Area badge
                if !note.areaName.isEmpty,
                   let area = PropertyArea(rawValue: note.areaName) {
                    HStack(spacing: 4) {
                        Image(systemName: area.icon)
                            .font(.caption2)
                        
                        Text(area.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                Text(note.createdAt.relativeFormat)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            // Content
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.subheadline)
                    .lineSpacing(4)
            }
            
            // Tags
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags) { tag in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(tag.color)
                                    .frame(width: 6, height: 6)
                                
                                Text(tag.name)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tag.color.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Media
            if !note.media.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(note.media) { media in
                            ModernMediaThumbnail(media: media) {
                                showingMedia = true
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu {
            Button {
                onAddMedia()
            } label: {
                Label("Add Photo/Video", systemImage: "photo")
            }
            
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Modern Media Thumbnail

struct ModernMediaThumbnail: View {
    let media: NoteMedia
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let thumbnailData = media.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.primary.opacity(0.05))
                }
                
                if media.mediaType == .video {
                    Circle()
                        .fill(.black.opacity(0.5))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                        }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

// MARK: - Add Note Sheet

struct AddNoteSheet: View {
    var viewModel: NotesViewModel
    @Binding var selectedArea: PropertyArea?
    @Binding var selectedTagIDs: Set<UUID>
    @Binding var content: String
    let onAdd: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isContentFocused: Bool
    @State private var showingNewTag = false
    @State private var newTagName = ""
    @State private var newTagColor = NoteTag.presetColors[0]
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Area picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Area")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(PropertyAreaCategory.allCases, id: \.self) { category in
                                    Menu {
                                        ForEach(category.areas) { area in
                                            Button {
                                                selectedArea = area
                                            } label: {
                                                Label(area.rawValue, systemImage: area.icon)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(category.rawValue)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                            
                                            Image(systemName: "chevron.down")
                                                .font(.caption2)
                                        }
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(cardBackground)
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        
                        if let area = selectedArea {
                            HStack(spacing: 6) {
                                Image(systemName: area.icon)
                                    .font(.caption)
                                Text(area.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Button {
                                    selectedArea = nil
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(10)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Tags
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Tags")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button {
                                showingNewTag = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.caption2)
                                    Text("New Tag")
                                        .font(.caption)
                                }
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            }
                        }
                        
                        if viewModel.availableTags.isEmpty && !showingNewTag {
                            Text("No tags yet. Create one to organize your notes.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 8)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(viewModel.availableTags) { tag in
                                    SelectableTagChip(
                                        tag: tag,
                                        isSelected: selectedTagIDs.contains(tag.id)
                                    ) {
                                        if selectedTagIDs.contains(tag.id) {
                                            selectedTagIDs.remove(tag.id)
                                        } else {
                                            selectedTagIDs.insert(tag.id)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // New tag input
                        if showingNewTag {
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    TextField("Tag name", text: $newTagName)
                                        .font(.subheadline)
                                        .padding(10)
                                        .background(cardBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    
                                    Button {
                                        if !newTagName.isEmpty {
                                            Task {
                                                await viewModel.createTag(name: newTagName, colorHex: newTagColor)
                                                newTagName = ""
                                                showingNewTag = false
                                            }
                                        }
                                    } label: {
                                        Text("Add")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(newTagName.isEmpty ? Color.primary.opacity(0.3) : Color.primary)
                                            .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                    .disabled(newTagName.isEmpty)
                                }
                                
                                // Color picker
                                HStack(spacing: 8) {
                                    ForEach(NoteTag.presetColors, id: \.self) { hex in
                                        Circle()
                                            .fill(Color(hex: hex) ?? .gray)
                                            .frame(width: 24, height: 24)
                                            .overlay {
                                                if newTagColor == hex {
                                                    Circle()
                                                        .stroke(Color.primary, lineWidth: 2)
                                                        .padding(-2)
                                                }
                                            }
                                            .onTapGesture {
                                                newTagColor = hex
                                            }
                                    }
                                }
                            }
                            .padding(12)
                            .background(cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Quick templates
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick Notes")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(QuickNoteTemplate.templates) { template in
                                    Button {
                                        content = template.content
                                    } label: {
                                        Text(template.title)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.primary.opacity(0.08))
                                            .foregroundStyle(.primary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Note")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextEditor(text: $content)
                            .focused($isContentFocused)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 140)
                            .padding(12)
                            .background(cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Add Note")
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

// MARK: - Selectable Tag Chip

struct SelectableTagChip: View {
    let tag: NoteTag
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(tag.color)
                    .frame(width: 6, height: 6)
                
                Text(tag.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? tag.color.opacity(0.15) : Color.clear)
            .foregroundStyle(.primary)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? tag.color : Color.primary.opacity(0.15), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Manager Sheet

struct TagManagerSheet: View {
    var viewModel: NotesViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var newTagName = ""
    @State private var newTagColor = NoteTag.presetColors[0]
    @State private var editingTag: NoteTag?
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Create new tag
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Create New Tag")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 12) {
                            TextField("Tag name", text: $newTagName)
                                .font(.subheadline)
                                .padding(12)
                                .background(cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            
                            Button {
                                if !newTagName.isEmpty {
                                    Task {
                                        await viewModel.createTag(name: newTagName, colorHex: newTagColor)
                                        newTagName = ""
                                    }
                                }
                            } label: {
                                Text("Add")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(newTagName.isEmpty ? Color.primary.opacity(0.3) : Color.primary)
                                    .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .disabled(newTagName.isEmpty)
                        }
                        
                        // Color picker
                        HStack(spacing: 10) {
                            ForEach(NoteTag.presetColors, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        if newTagColor == hex {
                                            Circle()
                                                .stroke(Color.primary, lineWidth: 2)
                                                .padding(-3)
                                        }
                                    }
                                    .onTapGesture {
                                        newTagColor = hex
                                    }
                            }
                        }
                    }
                    .padding(16)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 20)
                    
                    // Existing tags
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Tags")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 20)
                        
                        if viewModel.availableTags.isEmpty {
                            VStack(spacing: 8) {
                                Text("No tags yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Tags help you organize notes across all properties")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(viewModel.availableTags) { tag in
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(tag.color)
                                            .frame(width: 12, height: 12)
                                        
                                        Text(tag.name)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        Button(role: .destructive) {
                                            Task {
                                                await viewModel.deleteTag(tag)
                                            }
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    
                                    if tag.id != viewModel.availableTags.last?.id {
                                        Divider()
                                            .padding(.leading, 40)
                                    }
                                }
                            }
                            .background(cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 24)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Manage Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
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
            
            self.size = CGSize(width: width, height: y + rowHeight)
        }
    }
}

// MARK: - Legacy Support

struct ModernAreaChip: View {
    let name: String
    let icon: String
    let count: Int
    let isSelected: Bool
    var colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        FilterChip(name: name, icon: icon, count: count, isSelected: isSelected, colorScheme: colorScheme, action: action)
    }
}

// MARK: - Preview

#Preview {
    NotesView(propertyID: UUID())
        .padding()
}
