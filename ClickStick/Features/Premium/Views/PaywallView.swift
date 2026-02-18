//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import DesignSystem
import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.premiumService) private var premiumService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID: String?
    @State private var isPurchasing: Bool = false
    @State private var isLoadingProducts: Bool = false
    @State private var purchaseError: String?
    @State private var purchaseSucceeded: Bool = false

    private var subscriptionProducts: [Product] {
        premiumService.products.filter { $0.type == .autoRenewable }
    }

    private var consumableProducts: [Product] {
        premiumService.products.filter { $0.type == .consumable }
    }

    private var selectedProduct: Product? {
        guard let id = selectedProductID else { return nil }
        return subscriptionProducts.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: Spacing.sm) {
                        headerSection
                        benefitsSection
                        if isLoadingProducts {
                            ProgressView()
                                .padding(Spacing.lg)
                        } else if premiumService.products.isEmpty {
                            Text("Plans temporarily unavailable.", comment: "Paywall empty state")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(Spacing.md)
                        } else {
                            subscriptionSection
                            consumableSection
                        }
                        quotaStatusSection
                        footerSection
                    }
                    .padding(Spacing.md)
                }

                if !subscriptionProducts.isEmpty {
                    ctaSection
                }
            }
            .navigationTitle(String(localized: "Upgrade", comment: "Paywall navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done", comment: "Dismiss paywall")) {
                        dismiss()
                    }
                }
            }
            .task {
                if premiumService.products.isEmpty {
                    isLoadingProducts = true
                    await premiumService.loadProducts()
                    isLoadingProducts = false
                }
                ensureSelectedSubscriptionIfNeeded()
            }
            .onChange(of: premiumService.products.map(\.id)) { _, _ in
                ensureSelectedSubscriptionIfNeeded()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 32))
                .foregroundStyle(LinearGradient.clickStickGradient)
                .accessibilityHidden(true)

            Text("Type at Full Speed", comment: "Paywall headline")
                .font(.title3.weight(.bold))

            Text("Free users type character-by-character at human speed. Upgrade to send text instantly.", comment: "Paywall subtitle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            benefitRow(icon: "checkmark", color: .clickStickOrange,
                       text: String(localized: "Send entire text in one shot, not character-by-character", comment: "Paywall benefit"))
            benefitRow(icon: "checkmark", color: .clickStickBlue,
                       text: String(localized: "Minutes of typing delivered in seconds", comment: "Paywall benefit"))
            benefitRow(icon: "checkmark", color: .clickStickGreen,
                       text: String(localized: "Works in main app, Share extension and deep links", comment: "Paywall benefit"))
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.secondary.opacity(0.06))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Benefits: instant typing, saves time, works everywhere", comment: "Paywall benefits summary"))
    }

    private func benefitRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Subscription Plans

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Choose a plan", comment: "Paywall section header")
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            ForEach(subscriptionProducts, id: \.id) { product in
                planCard(product)
            }
        }
    }

    private func planCard(_ product: Product) -> some View {
        let isSelected = selectedProductID == product.id
        let isRecommended = product.id == PremiumService.subMonthlyUnlimited

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedProductID = product.id
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isSelected ? Color.clickStickBlue : .secondary.opacity(0.4))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(product.displayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        if isRecommended {
                            Text("Best", comment: "Recommended plan badge")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.clickStickBlue))
                        }
                    }
                    Text(subscriptionSubtitle(for: product))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(pricePerPeriod(for: product))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(isSelected ? Color.clickStickBlue.opacity(0.08) : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isSelected ? Color.clickStickBlue : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(String(localized: "\(product.displayName), \(subscriptionSubtitle(for: product)), \(pricePerPeriod(for: product))", comment: "Plan card accessibility"))
        .accessibilityHint(String(localized: "Double-tap to select this plan", comment: "Plan card hint"))
    }

    private func pricePerPeriod(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else {
            return product.displayPrice
        }
        switch period.unit {
        case .day:
            return String(localized: "\(product.displayPrice)/day", comment: "Daily price label")
        case .week:
            return String(localized: "\(product.displayPrice)/week", comment: "Weekly price label")
        case .month:
            return String(localized: "\(product.displayPrice)/month", comment: "Monthly price label")
        case .year:
            return String(localized: "\(product.displayPrice)/year", comment: "Yearly price label")
        @unknown default:
            return product.displayPrice
        }
    }

    private func subscriptionSubtitle(for product: Product) -> String {
        switch product.id {
        case PremiumService.subMonthlySmall:
            return String(localized: "For occasional use", comment: "Subscription tier description")
        case PremiumService.subMonthlyLarge:
            return String(localized: "For regular use", comment: "Subscription tier description")
        case PremiumService.subMonthlyUnlimited:
            return String(localized: "Unlimited instant typing", comment: "Subscription tier description")
        default:
            return product.description
        }
    }

    // MARK: - One-Time Pack

    @ViewBuilder
    private var consumableSection: some View {
        if let product = consumableProducts.first {
            VStack(spacing: Spacing.xs) {
                HStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 0.5)
                    Text("or", comment: "Separator between subscription and one-time options")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 0.5)
                }
                .accessibilityHidden(true)

                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Just need a little?", comment: "One-time pack heading")
                            .font(.caption.weight(.medium))
                        Text("1 KB of instant typing, no subscription", comment: "One-time pack description")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        Task { await purchase(product) }
                    } label: {
                        Text(product.displayPrice)
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.secondary)
                    .disabled(isPurchasing)
                }
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.secondary.opacity(0.04))
                )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "One-time pack: 1 KB of instant typing for \(product.displayPrice)", comment: "One-time pack accessibility"))
            .accessibilityHint(String(localized: "Double-tap to purchase", comment: "Purchase hint"))
        }
    }

    // MARK: - Sticky CTA

    private var ctaSection: some View {
        VStack(spacing: Spacing.xs) {
            if let error = purchaseError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(String(localized: "Purchase error: \(error)", comment: "Purchase error accessibility"))
            }

            if purchaseSucceeded {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("You're all set!", comment: "Purchase success confirmation")
                }
                .frame(maxWidth: .infinity)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.clickStickGreen)
                )
                .accessibilityLabel(String(localized: "Purchase successful", comment: "Purchase success accessibility"))
            } else {
                Button {
                    guard let product = selectedProduct else { return }
                    Task { await purchase(product) }
                } label: {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        if let product = selectedProduct {
                            Text("Subscribe for \(pricePerPeriod(for: product))", comment: "Subscribe CTA button")
                        } else {
                            Text("Select a plan", comment: "CTA placeholder when no plan selected")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                .disabled(selectedProduct == nil || isPurchasing)
                .accessibilityLabel(
                    isPurchasing
                        ? String(localized: "Processing purchase", comment: "CTA accessibility during purchase")
                        : selectedProduct.map {
                            String(localized: "Subscribe for \(pricePerPeriod(for: $0))", comment: "CTA accessibility")
                        } ?? String(localized: "Select a plan first", comment: "CTA accessibility when no plan selected")
                )
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        .background(.bar)
    }

    // MARK: - Quota Status

    private var quotaStatusSection: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: premiumService.hasActiveSubscription
                ? "checkmark.circle.fill"
                : "gauge.with.dots.needle.33percent")
                .font(.caption)
                .foregroundStyle(premiumService.hasActiveSubscription ? Color.clickStickGreen : .secondary)
                .accessibilityHidden(true)

            Group {
                if premiumService.isUnlimitedSubscription {
                    Text("Unlimited subscription active", comment: "Quota status")
                } else if premiumService.hasActiveSubscription {
                    if premiumService.remainingBytes > 0 {
                        Text("\(premiumService.remainingSubscriptionBytesThisMonth) monthly bytes + \(premiumService.remainingBytes) bonus bytes left", comment: "Quota status for limited subscription with bonus quota")
                    } else {
                        Text("\(premiumService.remainingSubscriptionBytesThisMonth) monthly bytes left on your plan", comment: "Quota status for limited subscription")
                    }
                } else if premiumService.remainingBytes > 0 {
                    Text("\(premiumService.remainingBytes) bytes of free quota remaining", comment: "Quota status with remaining bytes")
                } else {
                    Text("Free quota used up — purchase to type at full speed", comment: "Quota status when depleted")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.secondary.opacity(0.04))
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: Spacing.xs) {
            Button {
                Task {
                    isPurchasing = true
                    await premiumService.restorePurchases()
                    isPurchasing = false
                }
            } label: {
                Text("Restore Purchases", comment: "Restore purchases button")
                    .font(.caption)
                    .foregroundStyle(Color.clickStickBlue)
            }
            .disabled(isPurchasing)
            .accessibilityLabel(String(localized: "Restore previous purchases", comment: "Restore button accessibility"))

            Text("Subscriptions renew monthly. Cancel anytime in Settings.", comment: "Subscription terms disclaimer")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Purchase

    private func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        do {
            let success = try await premiumService.purchase(product)
            if success {
                isPurchasing = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    purchaseSucceeded = true
                }
                try? await Task.sleep(for: .seconds(1.5))
                dismiss()
                return
            }
        } catch {
            purchaseError = error.localizedDescription
        }
        isPurchasing = false
    }

    private func ensureSelectedSubscriptionIfNeeded() {
        let hasValidSelection = selectedProductID.map { selectedID in
            subscriptionProducts.contains { $0.id == selectedID }
        } ?? false
        guard !hasValidSelection else { return }

        selectedProductID = subscriptionProducts.first(where: {
            $0.id == PremiumService.subMonthlyUnlimited
        })?.id ?? subscriptionProducts.first?.id
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}
