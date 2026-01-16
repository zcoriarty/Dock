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
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            // Overall Progress
            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: checklistIconName)
                            .font(.title3)
                            .foregroundStyle(progressColor)
                        
                        Text("Tour Checklist")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Text(viewModel.property.checklist.totalProgress.asPercent())
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(progressColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(progressColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                // Custom progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor)
                            .frame(width: geometry.size.width * viewModel.property.checklist.totalProgress, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .dark ? Color(white: 0.12) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 12, x: 0, y: 4)
            .padding(.horizontal, 20)
            
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
    
    private var checklistIconName: String {
        let progress = viewModel.property.checklist.totalProgress
        if progress == 0 {
            return "checklist.unchecked"
        } else if progress == 1.0 {
            return "checklist.checked"
        } else {
            return "checklist"
        }
    }
    
    private var progressColor: Color {
        let progress = viewModel.property.checklist.totalProgress
        if progress == 1.0 {
            return .green
        } else if progress > 0 {
            return .blue
        } else {
            return .secondary
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
    
    private var sectionProgress: Double { section.progress }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            
                            Text(section.type.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // Progress percentage
                        Text("\(Int(sectionProgress * 100))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    
                    // Mini progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.12))
                                .frame(height: 3)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(sectionProgress == 1.0 ? Color.green : Color.blue)
                                .frame(width: geometry.size.width * sectionProgress, height: 3)
                        }
                    }
                    .frame(height: 3)
                }
                .padding(16)
                .background(colorScheme == .dark ? Color(white: 0.12) : Color.white)
            }
            .buttonStyle(.plain)
            
            // Items
            if isExpanded {
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 1)
                
                VStack(spacing: 0) {
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        ChecklistItemRow(
                            item: item,
                            sectionId: section.id,
                            viewModel: viewModel
                        )
                        
                        if index < section.items.count - 1 {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 1)
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(colorScheme == .dark ? Color(white: 0.12) : Color.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 12, x: 0, y: 4)
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
