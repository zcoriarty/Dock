//
//  LoadingView.swift
//  Dock
//
//  Loading states and skeleton views
//

import SwiftUI

// MARK: - Loading View

struct LoadingView: View {
    let message: String
    
    init(_ message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay<Content: View>: View {
    let isLoading: Bool
    let message: String
    let content: Content
    
    init(
        isLoading: Bool,
        message: String = "Loading...",
        @ViewBuilder content: () -> Content
    ) {
        self.isLoading = isLoading
        self.message = message
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)
            
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Skeleton View

struct SkeletonView: View {
    let height: CGFloat
    
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(.systemGray5))
            .frame(height: height)
            .overlay {
                GeometryReader { geo in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.white.opacity(0.5), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: isAnimating ? geo.size.width : -geo.size.width * 0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Skeleton Card

struct SkeletonPropertyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonView(height: 120)
            
            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(height: 20)
                SkeletonView(height: 14)
                    .frame(width: 200)
                
                HStack {
                    SkeletonView(height: 24)
                        .frame(width: 80)
                    Spacer()
                    SkeletonView(height: 24)
                        .frame(width: 60)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Pull to Refresh

struct RefreshableScrollView<Content: View>: View {
    let onRefresh: () async -> Void
    let content: Content
    
    init(
        onRefresh: @escaping () async -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.onRefresh = onRefresh
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            content
        }
        .refreshable {
            await onRefresh()
        }
    }
}

// MARK: - Previews

#Preview("Loading States") {
    VStack(spacing: 20) {
        LoadingView("Fetching property data...")
        
        SkeletonPropertyCard()
            .padding()
    }
}
