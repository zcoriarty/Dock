//
//  LoopingScrollView.swift
//  Dock
//
//  Auto-scrolling looping horizontal scroll view for rates/stats display
//

import SwiftUI
import Combine

struct LoopingScrollView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    var spacing: CGFloat = 10
    /// Min: 0 | Max: 1
    var scrollingSpeed: CGFloat = 0.7
    var itemWidth: CGFloat
    var data: Data
    @ViewBuilder var content: (_ item: Data.Element, _ isRepeated: Bool) -> Content
    
    /// View Properties
    @State private var scrollPosition: ScrollPosition = .init()
    @State private var containerWidth: CGFloat = 0
    @State private var currentOffset: CGFloat = 0
    @State private var repeatingCount: Int = 0
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: spacing) {
                /// Original Items
                HStack(spacing: spacing) {
                    ForEach(data) { item in
                        content(item, false)
                            .frame(width: itemWidth)
                    }
                }
                
                /// Repeated Items
                HStack(spacing: spacing) {
                    ForEach(0..<repeatingCount, id: \.self) { index in
                        let actualIndex = index % data.count
                        let itemIndex = data.index(data.startIndex, offsetBy: actualIndex)
                        
                        content(data[itemIndex], true)
                            .frame(width: itemWidth)
                    }
                }
            }
        }
        .scrollPosition($scrollPosition)
        .scrollIndicators(.hidden)
        /// Calculating how many repeating items needed for looping effect
        .onScrollGeometryChange(for: CGFloat.self) {
            $0.containerSize.width
        } action: { oldValue, newValue in
            let containerWidth = newValue
            let safeValue: Int = 1
            let neededCount = (containerWidth / (itemWidth + spacing)).rounded()
            self.repeatingCount = Int(neededCount) + safeValue
            self.containerWidth = containerWidth
        }
        .onScrollGeometryChange(for: CGFloat.self) {
            $0.contentOffset.x + $0.contentInsets.leading
        } action: { oldValue, newValue in
            currentOffset = newValue
            guard repeatingCount > 0 else { return }
            
            let contentWidth = CGFloat(data.count) * itemWidth
            let contentSpacing = CGFloat(data.count) * spacing
            let totalContentWidth = contentWidth + contentSpacing
            
            let resetOffset = min(totalContentWidth - newValue, 0)
            
            /// Resetting scroll without disrupting ongoing scroll interaction
            if resetOffset < 0 || newValue < 0 {
                var transaction = Transaction()
                transaction.scrollPositionUpdatePreservesVelocity = true
                
                withTransaction(transaction) {
                    if newValue < 0 {
                        /// Backward reset
                        scrollPosition.scrollTo(x: totalContentWidth)
                    } else {
                        /// Forward reset
                        scrollPosition.scrollTo(x: resetOffset)
                    }
                }
            }
        }
        /// Automatic Scrolling
        .onReceive(Timer.publish(every: 0.01, on: .main, in: .default).autoconnect()) { _ in
            scrollPosition.scrollTo(x: currentOffset + scrollingSpeed)
        }
    }
}
