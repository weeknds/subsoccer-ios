import SwiftUI
import UIKit

/// Service for managing adaptive layouts across different device sizes
@MainActor
class AdaptiveLayoutService: ObservableObject {
    static let shared = AdaptiveLayoutService()
    
    @Published var currentDevice: DeviceType = .phone
    @Published var currentOrientation: UIDeviceOrientation = .portrait
    @Published var isLandscape: Bool = false
    
    private init() {
        updateDeviceInfo()
        
        // Listen for orientation changes
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateDeviceInfo()
            }
        }
    }
    
    private func updateDeviceInfo() {
        currentOrientation = UIDevice.current.orientation
        isLandscape = currentOrientation.isLandscape
        
        let idiom = UIDevice.current.userInterfaceIdiom
        switch idiom {
        case .phone:
            currentDevice = .phone
        case .pad:
            currentDevice = .pad
        case .mac:
            currentDevice = .mac
        default:
            currentDevice = .phone
        }
    }
    
    // MARK: - Layout Properties
    
    var shouldUseCompactLayout: Bool {
        return currentDevice == .phone || (currentDevice == .pad && !isLandscape)
    }
    
    var shouldUseSplitView: Bool {
        return currentDevice == .pad && isLandscape
    }
    
    var columnCount: Int {
        switch (currentDevice, isLandscape) {
        case (.phone, false): return 1
        case (.phone, true): return 2
        case (.pad, false): return 2
        case (.pad, true): return 3
        case (.mac, _): return 3
        }
    }
    
    var gridColumns: [GridItem] {
        return Array(repeating: GridItem(.flexible(), spacing: AppTheme.standardPadding), count: columnCount)
    }
    
    var cardSpacing: CGFloat {
        switch currentDevice {
        case .phone: return AppTheme.standardPadding
        case .pad: return AppTheme.largePadding
        case .mac: return AppTheme.largePadding
        }
    }
    
    var sidebarWidth: CGFloat {
        switch currentDevice {
        case .phone: return 0
        case .pad: return 320
        case .mac: return 280
        }
    }
    
    var detailViewWidth: CGFloat {
        switch currentDevice {
        case .phone: return UIScreen.main.bounds.width
        case .pad: return 400
        case .mac: return 450
        }
    }
}

enum DeviceType {
    case phone
    case pad
    case mac
    
    var name: String {
        switch self {
        case .phone: return "iPhone"
        case .pad: return "iPad"
        case .mac: return "Mac"
        }
    }
}

// MARK: - Adaptive Layout Views

struct AdaptiveGrid<Content: View>: View {
    let content: Content
    let minItemWidth: CGFloat
    let spacing: CGFloat
    
    @StateObject private var layoutService = AdaptiveLayoutService.shared
    
    init(minItemWidth: CGFloat = 300, spacing: CGFloat = AppTheme.standardPadding, @ViewBuilder content: () -> Content) {
        self.minItemWidth = minItemWidth
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        LazyVGrid(columns: layoutService.gridColumns, spacing: spacing) {
            content
        }
    }
}

struct AdaptiveStack<Content: View>: View {
    let content: Content
    let axis: Axis
    
    @StateObject private var layoutService = AdaptiveLayoutService.shared
    
    init(axis: Axis = .vertical, @ViewBuilder content: () -> Content) {
        self.axis = axis
        self.content = content()
    }
    
    var body: some View {
        if layoutService.shouldUseCompactLayout || axis == .vertical {
            VStack(spacing: AppTheme.standardPadding) {
                content
            }
        } else {
            HStack(spacing: AppTheme.largePadding) {
                content
            }
        }
    }
}

struct SplitViewContainer<Sidebar: View, Detail: View>: View {
    let sidebar: Sidebar
    let detail: Detail
    
    @StateObject private var layoutService = AdaptiveLayoutService.shared
    
    init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) {
        self.sidebar = sidebar()
        self.detail = detail()
    }
    
    var body: some View {
        if layoutService.shouldUseSplitView {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: layoutService.sidebarWidth)
                    .background(AppTheme.secondaryBackground)
                
                Divider()
                    .background(AppTheme.secondaryText.opacity(0.3))
                
                detail
                    .frame(maxWidth: .infinity)
            }
        } else {
            NavigationStack {
                sidebar
            }
        }
    }
}

// MARK: - Keyboard Shortcuts Support

struct KeyboardShortcutModifier: ViewModifier {
    let key: KeyEquivalent
    let modifiers: EventModifiers
    let action: () -> Void
    
    @StateObject private var layoutService = AdaptiveLayoutService.shared
    
    func body(content: Content) -> some View {
        if layoutService.currentDevice == .pad || layoutService.currentDevice == .mac {
            content
                .keyboardShortcut(key, modifiers: modifiers)
        } else {
            content
        }
    }
}

extension View {
    func keyboardShortcut(key: KeyEquivalent, modifiers: EventModifiers = .command, action: @escaping () -> Void) -> some View {
        self.modifier(KeyboardShortcutModifier(key: key, modifiers: modifiers, action: action))
    }
    
    func adaptiveGrid(minItemWidth: CGFloat = 300, spacing: CGFloat = AppTheme.standardPadding) -> some View {
        AdaptiveGrid(minItemWidth: minItemWidth, spacing: spacing) {
            self
        }
    }
    
    func adaptiveStack(axis: Axis = .vertical) -> some View {
        AdaptiveStack(axis: axis) {
            self
        }
    }
}

// MARK: - Responsive Modifiers

struct ResponsivePadding: ViewModifier {
    @StateObject private var layoutService = AdaptiveLayoutService.shared
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, layoutService.currentDevice == .phone ? AppTheme.largePadding : AppTheme.largePadding * 2)
            .padding(.vertical, AppTheme.largePadding)
    }
}

struct ResponsiveCornerRadius: ViewModifier {
    @StateObject private var layoutService = AdaptiveLayoutService.shared
    
    func body(content: Content) -> some View {
        content
            .cornerRadius(layoutService.currentDevice == .phone ? AppTheme.cornerRadius : AppTheme.cornerRadius * 1.5)
    }
}

extension View {
    func responsivePadding() -> some View {
        self.modifier(ResponsivePadding())
    }
    
    func responsiveCornerRadius() -> some View {
        self.modifier(ResponsiveCornerRadius())
    }
}

// MARK: - iPad-Specific Enhancements

struct iPadToolbar<Content: ToolbarContent>: ToolbarContent {
    let content: Content
    
    @StateObject private var layoutService = AdaptiveLayoutService.shared
    
    init(@ToolbarContentBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some ToolbarContent {
        if layoutService.currentDevice == .pad {
            content
        }
    }
}