//
//  ChecklistSectionView.swift
//  Dock
//
//  Created by Dock AI on 2026-01-15.
//

import SwiftUI

struct ChecklistSectionView: View {
    @Bindable var viewModel: PropertyDetailViewModel
    @State private var expandedSections: Set<UUID> = []
    
    // Automatically expand the "During" section if it hasn't been completed yet
    private func setupInitialExpansion() {
        if expandedSections.isEmpty {
            for section in viewModel.property.checklist.sections {
                if section.type == .during {
                    expandedSections.insert(section.id)
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Overall Progress
            VStack(spacing: 8) {
                HStack {
                    Text("Tour Checklist")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(viewModel.property.checklist.totalProgress.asPercent())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(viewModel.property.checklist.totalProgress == 1.0 ? .green : .secondary)
                }
                
                ProgressView(value: viewModel.property.checklist.totalProgress)
                    .tint(viewModel.property.checklist.totalProgress == 1.0 ? .green : .blue)
            }
            .padding(20)
            .background(Color(white: 0.97)) // Light gray background
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
            .colorScheme(.light) // Force light mode appearance for consistency if desired, or remove
            
            // Sections
            LazyVStack(spacing: 16) {
                ForEach(viewModel.property.checklist.sections) { section in
                    ChecklistSectionCard(
                        section: section,
                        isExpanded: binding(for: section.id),
                        viewModel: viewModel
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            setupInitialExpansion()
        }
    }
    
    private func binding(for sectionId: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(sectionId) },
            set: { isExpanded in
                if isExpanded {
                    expandedSections.insert(sectionId)
                } else {
                    expandedSections.remove(sectionId)
                }
            }
        )
    }
}

struct ChecklistSectionCard: View {
    let section: ChecklistSection
    @Binding var isExpanded: Bool
    var viewModel: PropertyDetailViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: section.type.icon)
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text("\(Int(section.progress * 100))% Complete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
                .background(colorScheme == .dark ? Color(white: 0.1) : Color.white)
            }
            .buttonStyle(.plain)
            
            // Items
            if isExpanded {
                Divider()
                
                VStack(spacing: 0) {
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        ChecklistItemRow(
                            item: item,
                            sectionId: section.id,
                            viewModel: viewModel
                        )
                        
                        if index < section.items.count - 1 {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(colorScheme == .dark ? Color(white: 0.1) : Color.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct ChecklistItemRow: View {
    let item: ChecklistItem
    let sectionId: UUID
    var viewModel: PropertyDetailViewModel
    
    @State private var showingDetails: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Checkbox
                Button {
                    viewModel.toggleChecklistItem(item.id, in: sectionId)
                } label: {
                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(item.isChecked ? .green : .secondary.opacity(0.8))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title and toggle details
                    Button {
                        withAnimation {
                            showingDetails.toggle()
                        }
                    } label: {
                        HStack(alignment: .top) {
                            Text(item.title)
                                .font(.subheadline)
                                .strikethrough(item.isChecked)
                                .foregroundStyle(item.isChecked ? .secondary : .primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            if item.isFlagged {
                                Image(systemName: "flag.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Preview of answer/note if collapsed
                    if !showingDetails {
                        if let answer = item.answer, !answer.isEmpty {
                            Text(answer)
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .lineLimit(1)
                        } else if let note = item.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(12)
            
            // Expanded Details (Answer/Notes)
            if showingDetails {
                VStack(spacing: 12) {
                    // Answer Field (if applicable)
                    if item.answer != nil {
                        TextField("Enter answer...", text: Binding(
                            get: { item.answer ?? "" },
                            set: { viewModel.updateChecklistAnswer($0, for: item.id, in: sectionId) }
                        ))
                        .font(.subheadline)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Notes Field
                    TextField("Add notes...", text: Binding(
                        get: { item.note ?? "" },
                        set: { viewModel.updateChecklistNote($0, for: item.id, in: sectionId) }
                    ))
                    .font(.subheadline)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Actions
                    HStack {
                        Button {
                            viewModel.toggleChecklistFlag(item.id, in: sectionId)
                        } label: {
                            Label(
                                item.isFlagged ? "Unflag" : "Flag as Concern",
                                systemImage: item.isFlagged ? "flag.slash" : "flag"
                            )
                            .font(.caption)
                            .foregroundStyle(item.isFlagged ? Color.secondary : Color.red)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.leading, 34) // Indent to align with text
            }
        }
    }
}
