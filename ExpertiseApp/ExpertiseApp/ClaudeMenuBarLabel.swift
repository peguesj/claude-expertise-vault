import SwiftUI
import AppKit

// MARK: - Claude SVG icon (loaded from bundle resources)

struct ClaudeIcon: View {
    var size: CGFloat = 16

    var body: some View {
        Group {
            if let img = ClaudeIconCache.image {
                Image(nsImage: img)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                // Fallback: SF Symbol
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
        }
    }
}

/// Cached NSImage for the Claude SVG, loaded once at startup.
@MainActor
private enum ClaudeIconCache {
    static let image: NSImage? = {
        // Try Bundle.module (SPM resource bundle) then Bundle.main
        let candidates: [Bundle] = [Bundle.module, Bundle.main]
        for bundle in candidates {
            if let url = bundle.url(forResource: "claude", withExtension: "svg"),
               let img = NSImage(contentsOf: url) {
                img.isTemplate = true   // honours dark/light mode & accent colour
                return img
            }
        }
        return nil
    }()
}

// MARK: - Menubar label composite view

/// Renders the menubar item:
///
///   [● red/green]  [Claude icon]  [badge?]
///
/// - Left dot: server connectivity (green = online, red = offline)
/// - Claude icon: the Anthropic Claude SVG mark
/// - Superscript badge (top-right): count of new AI insights since last open
struct MenuBarLabel: View {
    let serverOnline: Bool
    let insightsBadge: Int

    var body: some View {
        HStack(spacing: 3) {
            // Connectivity indicator
            Circle()
                .fill(serverOnline ? Color.green : Color.red)
                .frame(width: 5, height: 5)

            // Claude icon + optional superscript badge
            claudeWithBadge
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var claudeWithBadge: some View {
        if insightsBadge > 0 {
            // Give the ZStack extra top/trailing space so the badge is not clipped
            ZStack(alignment: .topTrailing) {
                ClaudeIcon(size: 14)
                    .padding(.top, 5)
                    .padding(.trailing, 6)

                badgeLabel
            }
        } else {
            ClaudeIcon(size: 16)
        }
    }

    private var badgeLabel: some View {
        Text(insightsBadge < 100 ? "\(insightsBadge)" : "99+")
            .font(.system(size: 7, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 3)
            .padding(.vertical, 1.5)
            .background(Color.purple)
            .clipShape(Capsule())
    }
}
