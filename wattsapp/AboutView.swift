import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // App Icon
            if let appIcon = NSApplication.shared.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }
            
            // App Name & Version
            VStack(spacing: 4) {
                Text(verbatim: "WattsApp")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Version \(appVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .padding(.horizontal, 30)
            
            // Links
            VStack(spacing: 8) {
                // Buy Me a Coffee
                Link(destination: URL(string: "https://buymeacoffee.com/panburger")!) {
                    HStack(spacing: 6) {
                        Text(verbatim: "☕")
                        Text("Buy the Developer a Coffee")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                
                // GitHub
                Link(destination: URL(string: "https://github.com/P4Nburger/WattsApp")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                        Text("View Source on GitHub")
                    }
                    .font(.caption)
                }
            }
            
            Divider()
                .padding(.horizontal, 30)
            
            // Copyright
            VStack(spacing: 4) {
                Text(verbatim: "© 2025 PANburger")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Shows power usage in the macOS menu bar.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(30)
        .frame(width: 340, height: 420)
    }
}

#Preview {
    AboutView()
}
