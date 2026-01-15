//
//  StackedFolderView.swift
//  Dock
//
//  Wallet-style stacked folder view for properties
//

import SwiftUI

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
        .padding(.top, 4)
        .clipped()
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
        Button {
            if isExpanded {
                onTap()
                HapticManager.shared.impact(.light)
            } else {
                // When collapsed, tapping expands the folder
                withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.5)) {
                    onExpand()
                }
                HapticManager.shared.impact(.light)
            }
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
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
        .shadow(color: .black.opacity(isExpanded ? 0.08 : 0.12), radius: isExpanded ? 4 : 8, y: isExpanded ? 2 : 4)
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
