//
//  NotesViewModel.swift
//  Dock
//
//  ViewModel for property notes management
//

import Foundation
import SwiftUI
import PhotosUI
import CoreData

@MainActor
@Observable
final class NotesViewModel {
    // MARK: - Properties
    
    var notes: [PropertyNote] = []
    var selectedArea: PropertyArea?
    var isLoading: Bool = false
    var errorMessage: String?
    var showingCamera: Bool = false
    var showingPhotoPicker: Bool = false
    var showingAreaPicker: Bool = false
    var editingNote: PropertyNote?
    var selectedPhotos: [PhotosPickerItem] = []
    
    let propertyID: UUID
    
    // MARK: - Computed
    
    var notesByArea: [PropertyArea: [PropertyNote]] {
        var result: [PropertyArea: [PropertyNote]] = [:]
        
        for note in notes {
            if !note.areaName.isEmpty,
               let area = PropertyArea(rawValue: note.areaName) {
                result[area, default: []].append(note)
            }
        }
        
        return result
    }
    
    var areasWithNotes: [PropertyArea] {
        Array(notesByArea.keys).sorted { $0.rawValue < $1.rawValue }
    }
    
    var filteredNotes: [PropertyNote] {
        if let area = selectedArea {
            return notes.filter { $0.areaName == area.rawValue }
        }
        return notes.sorted { $0.createdAt > $1.createdAt }
    }
    
    var totalMediaCount: Int {
        notes.reduce(0) { $0 + $1.media.count }
    }
    
    // MARK: - Dependencies
    
    private let viewContext: NSManagedObjectContext
    
    // MARK: - Init
    
    init(propertyID: UUID, context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.propertyID = propertyID
        self.viewContext = context
        Task {
            await loadNotes()
        }
    }
    
    // MARK: - Data Loading
    
    func loadNotes() async {
        isLoading = true
        defer { isLoading = false }
        
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "property.id == %@", propertyID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NoteEntity.sortOrder, ascending: true)]
        
        do {
            let entities = try viewContext.fetch(request)
            notes = entities.map { mapEntityToNote($0) }
        } catch {
            errorMessage = "Failed to load notes: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Note CRUD
    
    func addNote(area: PropertyArea?, content: String) async {
        let note = PropertyNote(
            areaName: area?.rawValue ?? "",
            content: content,
            sortOrder: notes.count
        )
        
        let entity = NoteEntity(context: viewContext)
        mapNoteToEntity(note, entity: entity)
        
        // Link to property
        let propertyRequest: NSFetchRequest<PropertyEntity> = PropertyEntity.fetchRequest()
        propertyRequest.predicate = NSPredicate(format: "id == %@", propertyID as CVarArg)
        
        do {
            if let propertyEntity = try viewContext.fetch(propertyRequest).first {
                entity.property = propertyEntity
            }
            try viewContext.save()
            notes.append(note)
            HapticManager.shared.success()
        } catch {
            errorMessage = "Failed to save note: \(error.localizedDescription)"
        }
    }
    
    func updateNote(_ note: PropertyNote) async {
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                mapNoteToEntity(note, entity: entity)
                try viewContext.save()
                
                if let index = notes.firstIndex(where: { $0.id == note.id }) {
                    notes[index] = note
                }
            }
        } catch {
            errorMessage = "Failed to update note: \(error.localizedDescription)"
        }
    }
    
    func deleteNote(_ note: PropertyNote) async {
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                try viewContext.save()
                notes.removeAll { $0.id == note.id }
                HapticManager.shared.notification(.success)
            }
        } catch {
            errorMessage = "Failed to delete note: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Media
    
    func addMedia(to note: PropertyNote, type: MediaType, data: Data) async {
        var updatedNote = note
        let media = NoteMedia(
            mediaType: type,
            thumbnailData: type == .photo ? data : nil,
            sortOrder: note.media.count
        )
        
        // Save media to documents
        let filename = "\(media.id.uuidString).\(type == .photo ? "jpg" : "mov")"
        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            var mediaWithPath = media
            mediaWithPath.localPath = fileURL.path
            updatedNote.media.append(mediaWithPath)
            await updateNote(updatedNote)
            HapticManager.shared.success()
        } catch {
            errorMessage = "Failed to save media: \(error.localizedDescription)"
        }
    }
    
    func processSelectedPhotos() async {
        guard let note = editingNote else { return }
        
        for item in selectedPhotos {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await addMedia(to: note, type: .photo, data: data)
            }
        }
        
        selectedPhotos = []
    }
    
    func deleteMedia(_ media: NoteMedia, from note: PropertyNote) async {
        var updatedNote = note
        updatedNote.media.removeAll { $0.id == media.id }
        
        // Delete file
        if let path = media.localPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        
        await updateNote(updatedNote)
    }
    
    // MARK: - Quick Notes
    
    func addQuickNote(_ template: QuickNoteTemplate, area: PropertyArea?) async {
        await addNote(area: area, content: template.content)
    }
    
    // MARK: - Helpers
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func mapEntityToNote(_ entity: NoteEntity) -> PropertyNote {
        PropertyNote(
            id: entity.id ?? UUID(),
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            areaName: entity.areaName ?? "",
            content: entity.content ?? "",
            sortOrder: Int(entity.sortOrder),
            media: mapMediaEntities(entity.media as? Set<MediaEntity>)
        )
    }
    
    private func mapNoteToEntity(_ note: PropertyNote, entity: NoteEntity) {
        entity.id = note.id
        entity.createdAt = note.createdAt
        entity.updatedAt = Date()
        entity.areaName = note.areaName
        entity.content = note.content
        entity.sortOrder = Int16(note.sortOrder)
    }
    
    private func mapMediaEntities(_ entities: Set<MediaEntity>?) -> [NoteMedia] {
        guard let entities = entities else { return [] }
        
        return entities.compactMap { entity in
            NoteMedia(
                id: entity.id ?? UUID(),
                createdAt: entity.createdAt ?? Date(),
                mediaType: MediaType(rawValue: entity.mediaType ?? "photo") ?? .photo,
                localPath: entity.localPath,
                cloudKitRecordID: entity.cloudKitRecordID,
                thumbnailData: entity.thumbnailData,
                caption: entity.caption ?? "",
                sortOrder: Int(entity.sortOrder)
            )
        }.sorted { $0.sortOrder < $1.sortOrder }
    }
}
