//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation
import Observation
import os.log
import StoreKit
import SwiftUI

@Observable
@MainActor
final class PremiumService {
    private let log = Logger(subsystem: "io.clickstick", category: "PremiumService")

    // MARK: - Product Identifiers

    static let pack1KB = "io.clickstick.pack.1kb"
    static let subMonthlySmall = "io.clickstick.sub.monthly.small"
    static let subMonthlyLarge = "io.clickstick.sub.monthly.large"
    static let subMonthlyUnlimited = "io.clickstick.sub.monthly.unlimited"

    static let allProductIDs: Set<String> = [
        pack1KB,
        subMonthlySmall,
        subMonthlyLarge,
        subMonthlyUnlimited
    ]

    private static let subscriptionProductIDs: Set<String> = [
        subMonthlySmall,
        subMonthlyLarge,
        subMonthlyUnlimited
    ]

    // MARK: - Constants

    static let appGroupID = "group.io.clickstick"
    static let initialFreeQuotaBytes = 500
    private static let pack1KBBytes = 1024
    private static let monthlySmallQuotaBytes = 10 * 1024
    private static let monthlyLargeQuotaBytes = 50 * 1024

    // MARK: - UserDefaults Keys

    private static let bytesUsedKey = "premium.bytesUsedAtFullSpeed"
    private static let totalQuotaBytesKey = "premium.totalQuotaBytes"
    private static let hasActiveSubscriptionKey = "premium.hasActiveSubscription"
    private static let subscriptionTierKey = "premium.subscriptionTier"
    private static let freeQuotaGrantedKey = "premium.freeQuotaGranted"
    private static let subscriptionBytesUsedThisMonthKey = "premium.subscriptionBytesUsedThisMonth"
    private static let subscriptionUsageMonthKey = "premium.subscriptionUsageMonth"

    // MARK: - Dependencies

    private let defaults: UserDefaults

    // MARK: - Observable State

    private(set) var hasActiveSubscription: Bool = false
    private(set) var subscriptionTier: String?
    private(set) var totalQuotaBytes: Int = 0
    private(set) var bytesUsedAtFullSpeed: Int = 0
    private(set) var subscriptionBytesUsedThisMonth: Int = 0
    private(set) var subscriptionUsageMonth: String = ""
    private(set) var products: [Product] = []
    private(set) var purchaseInProgress: Bool = false

    // MARK: - Transaction Listener

    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Send Decision

    /// Encapsulates the result of a quota check. The `chargeSource` and `byteCount` are
    /// `fileprivate` so that only `recordCompletedSend` (in this file) can deduct quota.
    struct SendDecision {
        fileprivate enum ChargeSource {
            case none
            case oneTimeQuota
            case monthlySubscriptionQuota
        }

        let speed: TypingSpeed
        fileprivate let byteCount: Int
        fileprivate let chargeSource: ChargeSource
    }

    // MARK: - Computed Properties

    var remainingBytes: Int {
        max(0, totalQuotaBytes - bytesUsedAtFullSpeed)
    }

    var isPremium: Bool {
        hasActiveSubscription || remainingBytes > 0
    }

    var isUnlimitedSubscription: Bool {
        if case .unlimited = subscriptionTierLimit {
            return true
        }
        return false
    }

    var remainingSubscriptionBytesThisMonth: Int {
        guard case .limited(let limit) = subscriptionTierLimit else {
            return 0
        }
        return max(0, limit - subscriptionBytesUsedThisMonth)
    }

    var totalSubscriptionBytesThisMonth: Int {
        guard case .limited(let limit) = subscriptionTierLimit else {
            return 0
        }
        return limit
    }

    var remainingFullSpeedBytes: Int? {
        switch subscriptionTierLimit {
        case .unlimited:
            return nil
        case .limited:
            return remainingSubscriptionBytesThisMonth + remainingBytes
        case .none:
            return remainingBytes
        }
    }

    var totalFullSpeedBytes: Int? {
        switch subscriptionTierLimit {
        case .unlimited:
            return nil
        case .limited(let limit):
            return limit + totalQuotaBytes
        case .none:
            return totalQuotaBytes
        }
    }

    var hasAnyFullSpeedBytes: Bool {
        if case .unlimited = subscriptionTierLimit {
            return true
        }
        return (remainingFullSpeedBytes ?? 0) > 0
    }

    // MARK: - Initialization

    init(defaults: UserDefaults, autoSyncStoreKit: Bool = true) {
        self.defaults = defaults
        loadCachedState()
        resetSubscriptionUsageIfNeeded()
        grantFreeQuotaIfNeeded()

        guard autoSyncStoreKit else { return }

        startTransactionListener()
        Task {
            await syncPurchaseState()
            await loadProducts()
        }
    }

    func cancelTransactionListener() {
        transactionListenerTask?.cancel()
    }

    // MARK: - Free Quota

    private func grantFreeQuotaIfNeeded() {
        guard !defaults.bool(forKey: Self.freeQuotaGrantedKey) else { return }
        defaults.set(true, forKey: Self.freeQuotaGrantedKey)
        totalQuotaBytes += Self.initialFreeQuotaBytes
        persistState()
        log.info("Granted initial free quota of \(Self.initialFreeQuotaBytes) bytes")
    }

    // MARK: - Quota Tracking

    func typingSpeed(for byteCount: Int) -> TypingSpeed {
        makeSendDecision(for: byteCount).speed
    }

    /// Returns the send speed and charge source for a message of the given byte count.
    ///
    /// - Note: There is a time-of-check/time-of-use gap between this call and
    ///   `recordCompletedSend`. Concurrent sends (e.g., main app + share extension)
    ///   could both see sufficient quota. This is acceptable because BLE sends are
    ///   effectively serialized through the device, and the worst case is minor
    ///   over-consumption of quota (not data loss or incorrect speed).
    func makeSendDecision(for byteCount: Int) -> SendDecision {
        guard byteCount > 0 else {
            return SendDecision(
                speed: .human(delayPerCharacter: TypingSpeed.defaultHumanDelay),
                byteCount: byteCount,
                chargeSource: .none
            )
        }

        resetSubscriptionUsageIfNeeded()

        switch subscriptionTierLimit {
        case .unlimited:
            return SendDecision(speed: .unlimited, byteCount: byteCount, chargeSource: .none)
        case .limited:
            if remainingSubscriptionBytesThisMonth >= byteCount {
                return SendDecision(
                    speed: .unlimited,
                    byteCount: byteCount,
                    chargeSource: .monthlySubscriptionQuota
                )
            }
        case .none:
            break
        }

        if remainingBytes >= byteCount {
            return SendDecision(
                speed: .unlimited,
                byteCount: byteCount,
                chargeSource: .oneTimeQuota
            )
        }

        return SendDecision(
            speed: .human(delayPerCharacter: TypingSpeed.defaultHumanDelay),
            byteCount: byteCount,
            chargeSource: .none
        )
    }

    func recordCompletedSend(_ decision: SendDecision) {
        guard decision.byteCount > 0 else { return }
        guard case .unlimited = decision.speed else { return }

        resetSubscriptionUsageIfNeeded()

        switch decision.chargeSource {
        case .none:
            return
        case .oneTimeQuota:
            bytesUsedAtFullSpeed += decision.byteCount
        case .monthlySubscriptionQuota:
            guard case .limited(let limit) = subscriptionTierLimit else {
                return
            }
            subscriptionBytesUsedThisMonth = min(limit, subscriptionBytesUsedThisMonth + decision.byteCount)
        }

        persistState()
        log.debug(
            "Recorded full-speed send of \(decision.byteCount) bytes; one-time remaining: \(self.remainingBytes), monthly remaining: \(self.remainingSubscriptionBytesThisMonth)"
        )
    }

    /// Convenience that makes a send decision and immediately records it.
    /// Primarily used in unit tests for concise quota manipulation.
    func recordBytesTyped(_ count: Int) {
        recordCompletedSend(makeSendDecision(for: count))
    }

    // MARK: - StoreKit Products

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: Self.allProductIDs)
            products = storeProducts.sorted { $0.price < $1.price }
            log.info("Loaded \(storeProducts.count) products")
        } catch {
            log.error("Failed to load products: \(error.localizedDescription)")
        }
    }

    // MARK: - Purchases

    func purchase(_ product: Product) async throws -> Bool {
        purchaseInProgress = true
        defer { purchaseInProgress = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await processTransaction(transaction)
            await transaction.finish()
            log.info("Purchase successful: \(product.id)")
            return true

        case .userCancelled:
            log.info("Purchase cancelled by user")
            return false

        case .pending:
            log.info("Purchase pending")
            return false

        @unknown default:
            log.warning("Unknown purchase result")
            return false
        }
    }

    func restorePurchases() async {
        log.info("Restoring purchases")
        try? await AppStore.sync()
        await syncPurchaseState()
    }

    // MARK: - Purchase State Sync

    /// Syncs subscription state from StoreKit's current transactions.
    ///
    /// Only updates subscription-related fields. One-time consumable quota is managed
    /// incrementally by `processTransaction` and persisted in UserDefaults, because
    /// finished consumable transactions do not appear in `Transaction.currentEntitlements`.
    func syncPurchaseState() async {
        var foundActiveSubscription = false
        var foundTier: String?

        for await result in StoreKit.Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }

            if Self.subscriptionProductIDs.contains(transaction.productID) {
                foundActiveSubscription = true
                foundTier = transaction.productID
            }
        }

        hasActiveSubscription = foundActiveSubscription
        subscriptionTier = foundTier
        resetSubscriptionUsageIfNeeded()

        persistState()
        log.info("Entitlements synced: subscription=\(foundActiveSubscription), quota=\(self.totalQuotaBytes)")
    }

    // MARK: - Transaction Listener

    private func startTransactionListener() {
        transactionListenerTask = Task.detached { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.checkVerified(result) {
                    await self.processTransaction(transaction)
                    await transaction.finish()
                }
            }
        }
    }

    private func processTransaction(_ transaction: StoreKit.Transaction) async {
        if Self.subscriptionProductIDs.contains(transaction.productID) {
            if transaction.revocationDate != nil {
                hasActiveSubscription = false
                subscriptionTier = nil
                log.info("Subscription revoked: \(transaction.productID)")
            } else {
                hasActiveSubscription = true
                subscriptionTier = transaction.productID
                resetSubscriptionUsageIfNeeded()
                log.info("Subscription active: \(transaction.productID)")
            }
        } else if transaction.productID == Self.pack1KB {
            totalQuotaBytes += Self.pack1KBBytes
            log.info("Added \(Self.pack1KBBytes) bytes from pack purchase")
        }

        persistState()
    }

    // MARK: - Verification

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    // MARK: - Persistence

    private func loadCachedState() {
        bytesUsedAtFullSpeed = defaults.integer(forKey: Self.bytesUsedKey)
        totalQuotaBytes = defaults.integer(forKey: Self.totalQuotaBytesKey)
        hasActiveSubscription = defaults.bool(forKey: Self.hasActiveSubscriptionKey)
        subscriptionTier = defaults.string(forKey: Self.subscriptionTierKey)
        subscriptionBytesUsedThisMonth = max(0, defaults.integer(forKey: Self.subscriptionBytesUsedThisMonthKey))
        subscriptionUsageMonth = defaults.string(forKey: Self.subscriptionUsageMonthKey) ?? Self.monthKey(for: .now)
    }

    private func persistState() {
        defaults.set(bytesUsedAtFullSpeed, forKey: Self.bytesUsedKey)
        defaults.set(totalQuotaBytes, forKey: Self.totalQuotaBytesKey)
        defaults.set(hasActiveSubscription, forKey: Self.hasActiveSubscriptionKey)
        defaults.set(subscriptionTier, forKey: Self.subscriptionTierKey)
        defaults.set(subscriptionBytesUsedThisMonth, forKey: Self.subscriptionBytesUsedThisMonthKey)
        defaults.set(subscriptionUsageMonth, forKey: Self.subscriptionUsageMonthKey)
    }

    // MARK: - Subscription Quota

    private enum SubscriptionTierLimit {
        case none
        case limited(Int)
        case unlimited
    }

    private var subscriptionTierLimit: SubscriptionTierLimit {
        guard hasActiveSubscription else { return .none }

        switch subscriptionTier {
        case Self.subMonthlySmall:
            return .limited(Self.monthlySmallQuotaBytes)
        case Self.subMonthlyLarge:
            return .limited(Self.monthlyLargeQuotaBytes)
        case Self.subMonthlyUnlimited:
            return .unlimited
        default:
            return .none
        }
    }

    private func resetSubscriptionUsageIfNeeded() {
        let currentMonth = Self.monthKey(for: .now)
        guard subscriptionUsageMonth != currentMonth else { return }

        subscriptionUsageMonth = currentMonth
        subscriptionBytesUsedThisMonth = 0
        persistState()
        log.info("Reset monthly subscription usage for \(currentMonth)")
    }

    static func monthKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 1
        return String(format: "%04d-%02d", year, month)
    }
}

// MARK: - Environment Key

private struct PremiumServiceKey: EnvironmentKey {
    /// Inert placeholder — no StoreKit sync, isolated UserDefaults suite.
    /// The real instance is injected at the WindowGroup level in ClickStickApp.
    @MainActor static let defaultValue = PremiumService(
        defaults: UserDefaults(suiteName: "io.clickstick.environment-placeholder") ?? .standard,
        autoSyncStoreKit: false
    )
}

extension EnvironmentValues {
    var premiumService: PremiumService {
        get { self[PremiumServiceKey.self] }
        set { self[PremiumServiceKey.self] = newValue }
    }
}
