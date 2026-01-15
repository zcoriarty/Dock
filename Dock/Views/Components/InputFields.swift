//
//  InputFields.swift
//  Dock
//
//  Custom input field components
//

import SwiftUI

// MARK: - Shared Input Style

private struct InputFieldStyle: ViewModifier {
    let isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isFocused ? Color.accentColor : Color(.separator), lineWidth: isFocused ? 1.5 : 0.5)
            }
    }
}

extension View {
    func inputFieldStyle(isFocused: Bool) -> some View {
        modifier(InputFieldStyle(isFocused: isFocused))
    }
}

// MARK: - Currency Field

struct CurrencyField: View {
    let title: String
    @Binding var value: Double
    var placeholder: String = "0"
    
    @FocusState private var isFocused: Bool
    @State private var textValue: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Text("$")
                    .foregroundStyle(.tertiary)
                
                TextField(placeholder, text: $textValue)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .onChange(of: textValue) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        textValue = filtered
                        value = Double(filtered) ?? 0
                    }
                    .onChange(of: isFocused) { _, focused in
                        if focused {
                            Task { @MainActor in
                                HapticManager.shared.editField()
                            }
                        }
                    }
            }
            .inputFieldStyle(isFocused: isFocused)
        }
        .onAppear {
            textValue = value > 0 ? String(Int(value)) : ""
        }
        .onChange(of: value) { _, newValue in
            guard !isFocused else { return }
            let formatted = newValue > 0 ? String(Int(newValue.rounded())) : ""
            if textValue != formatted {
                textValue = formatted
            }
        }
    }
}

// MARK: - Percent Field

struct PercentField: View {
    let title: String
    @Binding var value: Double // Stored as decimal (0.07 = 7%)
    var decimalPlaces: Int = 2
    
    @FocusState private var isFocused: Bool
    @State private var textValue: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                TextField("0", text: $textValue)
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: textValue) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber || $0 == "." }
                        textValue = filtered
                        if let doubleValue = Double(filtered) {
                            value = doubleValue / 100
                        }
                    }
                    .onChange(of: isFocused) { _, focused in
                        if focused {
                            Task { @MainActor in
                                HapticManager.shared.editField()
                            }
                        }
                    }
                
                Text("%")
                    .foregroundStyle(.tertiary)
            }
            .inputFieldStyle(isFocused: isFocused)
        }
        .onAppear {
            textValue = value > 0 ? String(format: "%.\(decimalPlaces)f", value * 100) : ""
        }
        .onChange(of: value) { _, newValue in
            guard !isFocused else { return }
            let formatted = newValue > 0 ? String(format: "%.\(decimalPlaces)f", newValue * 100) : ""
            if textValue != formatted {
                textValue = formatted
            }
        }
    }
}

// MARK: - Number Field

struct NumberField: View {
    let title: String
    @Binding var value: Int
    var suffix: String? = nil
    
    @FocusState private var isFocused: Bool
    @State private var textValue: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                TextField("0", text: $textValue)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .onChange(of: textValue) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        textValue = filtered
                        value = Int(filtered) ?? 0
                    }
                    .onChange(of: isFocused) { _, focused in
                        if focused {
                            Task { @MainActor in
                                HapticManager.shared.editField()
                            }
                        }
                    }
                
                if let suffix = suffix {
                    Text(suffix)
                        .foregroundStyle(.tertiary)
                }
            }
            .inputFieldStyle(isFocused: isFocused)
        }
        .onAppear {
            textValue = value > 0 ? String(value) : ""
        }
        .onChange(of: value) { _, newValue in
            guard !isFocused else { return }
            let formatted = newValue > 0 ? String(newValue) : ""
            if textValue != formatted {
                textValue = formatted
            }
        }
    }
}

// MARK: - Text Input Field

struct TextInputField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var icon: String? = nil
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundStyle(.tertiary)
                }
                
                TextField(placeholder, text: $text)
                    .focused($isFocused)
                    .onChange(of: isFocused) { _, focused in
                        if focused {
                            Task { @MainActor in
                                HapticManager.shared.editField()
                            }
                        }
                    }
            }
            .inputFieldStyle(isFocused: isFocused)
        }
    }
}

// MARK: - URL Input Field

struct URLInputField: View {
    let title: String
    @Binding var url: String
    var placeholder: String = "https://zillow.com, redfin.com, or realtor.com..."
    let isValid: Bool
    
    @FocusState private var isFocused: Bool
    
    private var borderColor: Color {
        if isFocused {
            return .accentColor
        } else if url.isEmpty {
            return Color(.separator)
        } else {
            return isValid ? Color.green.opacity(0.6) : Color.red.opacity(0.6)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.tertiary)
                
                TextField(placeholder, text: $url)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                
                if !url.isEmpty {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(isValid ? .green : .red)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: isFocused || (!url.isEmpty && !isValid) ? 1.5 : 0.5)
            }
        }
    }
}

// MARK: - Stepper Field

struct StepperField: View {
    let title: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...99
    var step: Int = 1
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Button {
                    if value - step >= range.lowerBound {
                        value -= step
                        Task { @MainActor in
                            HapticManager.shared.impact(.light)
                        }
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value > range.lowerBound ? .accentColor : Color(.tertiaryLabel))
                }
                .disabled(value <= range.lowerBound)
                
                Spacer()
                
                Text("\(value)")
                    .font(.system(.title2, design: .rounded, weight: .medium))
                    .frame(minWidth: 40)
                
                Spacer()
                
                Button {
                    if value + step <= range.upperBound {
                        value += step
                        Task { @MainActor in
                            HapticManager.shared.impact(.light)
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value < range.upperBound ? .accentColor : Color(.tertiaryLabel))
                }
                .disabled(value >= range.upperBound)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Slider Field

struct SliderField: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double = 0.01
    var format: SliderFormat = .percent
    
    enum SliderFormat {
        case percent
        case currency
        case years
        case decimal
    }
    
    var displayValue: String {
        switch format {
        case .percent:
            return (value * 100).asDecimal + "%"
        case .currency:
            return value.asCurrency
        case .years:
            return "\(Int(value)) years"
        case .decimal:
            return value.asDecimal
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(displayValue)
                    .font(.system(.body, design: .rounded, weight: .medium))
            }
            
            Slider(value: $value, in: range, step: step) { editing in
                if editing {
                    Task { @MainActor in
                        HapticManager.shared.slider()
                    }
                }
            }
            .tint(.accentColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        }
    }
}

// MARK: - Previews

#Preview("Input Fields") {
    ScrollView {
        VStack(spacing: 16) {
            CurrencyField(title: "Purchase Price", value: .constant(450000))
            PercentField(title: "Interest Rate", value: .constant(0.07))
            NumberField(title: "Square Feet", value: .constant(1800), suffix: "sq ft")
            TextInputField(title: "Address", text: .constant("123 Main St"), icon: "mappin")
            URLInputField(title: "Property URL", url: .constant("https://zillow.com/..."), isValid: true)
            StepperField(title: "Bedrooms", value: .constant(3))
            SliderField(title: "LTV", value: .constant(0.75), range: 0.5...0.95)
        }
        .padding()
    }
}
