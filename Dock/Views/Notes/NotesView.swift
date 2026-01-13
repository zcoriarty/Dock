//
//  NotesView.swift
//  Dock
//
//  Property notes with areas and media support
//

import SwiftUI
import PhotosUI

struct NotesView: View {
    @State private var viewModel: NotesViewModel
    @State private var showingAddNote = false
    @State private var newNoteContent = ""
    @State private var selectedNoteArea: PropertyArea?
    
    init(propertyID: UUID) {
        _viewModel = State(initialValue: NotesViewModel(propertyID: propertyID))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Area filter
            areaFilter
            
            // Notes list or empty state
            if viewModel.filteredNotes.isEmpty {
                emptyState
            } else {
                notesList
            }
            
            // Add button
            addNoteButton
        }
        .sheet(isPresented: $showingAddNote) {
            AddNoteSheet(
                viewModel: viewModel,
                selectedArea: $selectedNoteArea,
                content: $newNoteContent,
                onAdd: {
                    Task {
                        await viewModel.addNote(area: selectedNoteArea, content: newNoteContent)
                        newNoteContent = ""
                        showingAddNote = false
                    }
                }
            )
        }
    }
    
    // MARK: - Area Filter
    
    private var areaFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All
                AreaChip(
                    name: "All",
                    icon: "note.text",
                    count: viewModel.notes.count,
                    isSelected: viewModel.selectedArea == nil
                ) {
                    viewModel.selectedArea = nil
                }
                
                // Areas with notes
                ForEach(viewModel.areasWithNotes) { area in
                    AreaChip(
                        name: area.rawValue,
                        icon: area.icon,
                        count: viewModel.notesByArea[area]?.count ?? 0,
                        isSelected: viewModel.selectedArea == area
                    ) {
                        viewModel.selectedArea = area
                    }
                }
            }
        }
    }
    
    // MARK: - Notes List
    
    private var notesList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.filteredNotes) { note in
                NoteCard(
                    note: note,
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
            Image(systemName: "note.text")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            
            Text("No notes yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Add notes while visiting this property")
                .font(.caption)
                .foregroundStyle(.tertiary)
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
            Label("Add Note", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Area Chip

struct AreaChip: View {
    let name: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(name)
                    .font(.caption)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Note Card

struct NoteCard: View {
    let note: PropertyNote
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onAddMedia: () -> Void
    
    @State private var showingMedia = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                if !note.areaName.isEmpty,
                   let area = PropertyArea(rawValue: note.areaName) {
                    HStack(spacing: 4) {
                        Image(systemName: area.icon)
                            .font(.caption)
                        
                        Text(area.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.tint)
                }
                
                Spacer()
                
                Text(note.createdAt.relativeFormat)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Menu {
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
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Content
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.subheadline)
            }
            
            // Media
            if !note.media.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(note.media) { media in
                            MediaThumbnail(media: media) {
                                showingMedia = true
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Media Thumbnail

struct MediaThumbnail: View {
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
                        .fill(Color(.systemGray5))
                }
                
                if media.mediaType == .video {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.caption)
                        }
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

// MARK: - Add Note Sheet

struct AddNoteSheet: View {
    var viewModel: NotesViewModel
    @Binding var selectedArea: PropertyArea?
    @Binding var content: String
    let onAdd: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isContentFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Area picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Area")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
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
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.caption2)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray5))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    if let area = selectedArea {
                        HStack {
                            Image(systemName: area.icon)
                            Text(area.rawValue)
                        }
                        .font(.subheadline)
                        .padding(8)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(.tint)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.horizontal)
                
                // Quick templates
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(QuickNoteTemplate.templates) { template in
                                Button {
                                    content = template.content
                                } label: {
                                    Text(template.title)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(template.category.color.opacity(0.2))
                                        .foregroundStyle(template.category.color)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextEditor(text: $content)
                        .focused($isContentFocused)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd()
                    }
                    .disabled(content.isEmpty)
                }
            }
            .onAppear {
                isContentFocused = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NotesView(propertyID: UUID())
        .padding()
        .background(Color(.systemGroupedBackground))
}
