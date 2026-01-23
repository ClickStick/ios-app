//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct AnnouncementBannerView: View {
    struct Configuration {
        let title: String?
        let message: String?
        let image: Image
        let actionTitle: String?
    }
    let configuration: Configuration
    let onAction: (() -> Void)?
    let onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            configuration.image
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                if let title = configuration.title {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                if let message = configuration.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let actionTitle = configuration.actionTitle, let onAction {
                    Button {
                        onAction()
                    } label: {
                        Text(actionTitle)
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)

            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

#Preview {
    VStack {
        ForEach([AnnouncementBannerView.Configuration.welcome, .demo], id: \.title ) { config in
            AnnouncementBannerView(
                configuration: .welcome,
                onAction: nil,
                onDismiss: nil
            )
            .padding(24)
        }
        Spacer()
    }
}
