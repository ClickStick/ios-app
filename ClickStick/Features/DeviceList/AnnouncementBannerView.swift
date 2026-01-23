//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct AnnouncementBannerView: View {
    let title: String?
    let message: String?
    let image: Image
    let actionTitle: String?
    let onAction: (() -> Void)?
    let onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            image
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                if let title {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let actionTitle, let onAction {
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
        AnnouncementBannerView(
            title: "Title",
            message: "Message",
            image: Image(.bluetooth),
            actionTitle: "Click me",
            onAction: nil,
            onDismiss: nil
        )
        .padding(24)
        Spacer()
    }
}
