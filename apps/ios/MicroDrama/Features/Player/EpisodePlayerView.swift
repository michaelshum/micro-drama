import AVFoundation
import StoreKit
import SwiftUI
import UIKit

struct EpisodePlayerView: View {
    let show: ShowDetail
    let onEpisodeChanged: (Episode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var dragOffset: CGFloat = 0
    @State private var isEpisodeListPresented = false
    @State private var isSpeedSheetPresented = false
    @State private var isNotificationSoftAskPresented = false
    @State private var isReviewSoftAskPresented = false
    @State private var unlockedEpisodeIDs: Set<String> = []
    @State private var playbackRate: Float = 1.0
    @ObservedObject private var followedShowStore = FollowedShowStore.shared
    @ObservedObject private var notificationStore = NotificationPermissionStore.shared
    @ObservedObject private var reviewPromptStore = AppReviewPromptStore.shared
    @StateObject private var screenCaptureProtection = ScreenCaptureProtectionStore()

    init(
        show: ShowDetail,
        initialEpisodeID: String? = nil,
        onEpisodeChanged: @escaping (Episode) -> Void = { _ in }
    ) {
        self.show = show
        self.onEpisodeChanged = onEpisodeChanged

        let initialIndex = initialEpisodeID
            .flatMap { episodeID in show.episodes.firstIndex { $0.id == episodeID } } ?? 0
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        GeometryReader { proxy in
            let pageHeight = proxy.size.height
            let headerTopPadding = max(proxy.safeAreaInsets.top + 8, 24)

            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                ZStack {
                    ForEach(visibleEpisodeIndices, id: \.self) { index in
                        if let episode = show.episodes[safe: index] {
                            EpisodePage(
                                showTitle: show.title,
                                episode: episode,
                                isActive: index == currentIndex && !isReviewSoftAskPresented,
                                isUnlocked: unlockedEpisodeIDs.contains(episode.id),
                                isFollowing: followedShowStore.isFollowing(show),
                                isScreenCaptured: screenCaptureProtection.isScreenCaptured,
                                playbackRate: playbackRate,
                                onFollow: { toggleFollow(for: episode) },
                                onEpisodesTapped: { isEpisodeListPresented = true },
                                onRewardedUnlock: { unlockedEpisodeIDs.insert(episode.id) },
                                onVideoFinished: finishCurrentEpisode
                            )
                            .frame(width: proxy.size.width, height: pageHeight)
                            .offset(y: CGFloat(index - currentIndex) * pageHeight + dragOffset)
                        }
                    }
                }
                .clipped()

                PlayerHeader(
                    episodeNumber: show.episodes[safe: currentIndex]?.episodeNumber,
                    onBack: { dismiss() },
                    onSpeed: { isSpeedSheetPresented = true }
                )
                .padding(.horizontal, 14)
                .padding(.top, headerTopPadding)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 16)
                    .onChanged { value in
                        guard isVerticalDrag(value.translation) else { return }
                        updateDragOffset(value.translation.height)
                    }
                    .onEnded { value in
                        guard isVerticalDrag(value.translation) else {
                            withAnimation(pageAnimation) {
                                dragOffset = 0
                            }
                            return
                        }
                        settleDrag(value, pageHeight: pageHeight)
                    }
            )
        }
        .ignoresSafeArea()
        .sheet(isPresented: $isEpisodeListPresented) {
            EpisodeListSheet(
                showTitle: show.title,
                episodes: show.episodes,
                currentEpisodeID: show.episodes[safe: currentIndex]?.id,
                onSelect: { index in
                    withAnimation(pageAnimation) {
                        currentIndex = index
                        dragOffset = 0
                    }
                    isEpisodeListPresented = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isSpeedSheetPresented) {
            SpeedSelectionSheet(selectedRate: $playbackRate) {
                isSpeedSheetPresented = false
            }
            .presentationDetents([.height(270)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isNotificationSoftAskPresented) {
            NotificationSoftAskSheet(
                showTitle: show.title,
                onNotify: {
                    isNotificationSoftAskPresented = false
                    Task {
                        await notificationStore.requestAuthorization()
                    }
                },
                onNotNow: {
                    notificationStore.markSoftAskShown()
                    isNotificationSoftAskPresented = false
                }
            )
            .presentationDetents([.height(270)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isReviewSoftAskPresented) {
            ReviewSoftAskSheet(
                appName: AppReviewPromptStore.appName,
                onLeaveRating: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        AppReviewRequester.requestReview()
                    }
                },
                onRated: {
                    isReviewSoftAskPresented = false
                    reviewPromptStore.markReviewRequested()
                }
            )
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            recordCurrentEpisode()
            Task {
                await notificationStore.refreshAuthorizationStatus()
            }
        }
        .onChange(of: currentIndex) { _, _ in
            recordCurrentEpisode()
        }
        .statusBarHidden()
    }

    private var visibleEpisodeIndices: [Int] {
        guard !show.episodes.isEmpty else { return [] }
        let lowerBound = max(show.episodes.startIndex, currentIndex - 1)
        let upperBound = min(show.episodes.index(before: show.episodes.endIndex), currentIndex + 1)
        return Array(lowerBound...upperBound)
    }

    private var pageAnimation: Animation {
        .interactiveSpring(response: 0.32, dampingFraction: 0.9)
    }

    private func toggleFollow(for episode: Episode) {
        let didFollow = followedShowStore.toggle(show: show, episode: episode)
        guard didFollow, notificationStore.canShowSoftAsk else { return }
        isNotificationSoftAskPresented = true
    }

    private func recordCurrentEpisode() {
        guard let episode = show.episodes[safe: currentIndex] else { return }
        onEpisodeChanged(episode)
    }

    private func updateDragOffset(_ verticalTranslation: CGFloat) {
        let isPullingPastFirstEpisode = currentIndex == 0 && verticalTranslation > 0
        let isPullingPastLastEpisode = currentIndex == show.episodes.count - 1 && verticalTranslation < 0

        if isPullingPastFirstEpisode || isPullingPastLastEpisode {
            dragOffset = verticalTranslation * 0.25
        } else {
            dragOffset = verticalTranslation
        }
    }

    private func moveToNextEpisode() {
        guard currentIndex < show.episodes.count - 1 else { return }
        withAnimation(pageAnimation) {
            currentIndex += 1
            dragOffset = 0
        }
    }

    private func finishCurrentEpisode() {
        guard let episode = show.episodes[safe: currentIndex] else { return }
        let shouldPromptForReview = reviewPromptStore.recordCompletedEpisode(
            episode,
            isFollowingShow: followedShowStore.isFollowing(show)
        )

        moveToNextEpisode()

        guard shouldPromptForReview else { return }
        isReviewSoftAskPresented = true
    }

    private func moveToPreviousEpisode() {
        guard currentIndex > 0 else { return }
        withAnimation(pageAnimation) {
            currentIndex -= 1
            dragOffset = 0
        }
    }

    private func settleDrag(_ value: DragGesture.Value, pageHeight: CGFloat) {
        let threshold = pageHeight * 0.5

        if value.translation.height < -threshold {
            moveToNextEpisode()
        } else if value.translation.height > threshold {
            moveToPreviousEpisode()
        } else {
            withAnimation(pageAnimation) {
                dragOffset = 0
            }
        }
    }

    private func isVerticalDrag(_ translation: CGSize) -> Bool {
        abs(translation.height) > abs(translation.width)
    }
}

@MainActor
final class AppReviewPromptStore: ObservableObject {
    static let shared = AppReviewPromptStore()

    private let defaults: UserDefaults
    private let completedEpisodeIDsKey = "reviewPromptCompletedEpisodeIDs"
    private let activeDayIDsKey = "reviewPromptActiveDayIDs"
    private let lastDeferredAtKey = "reviewPromptLastDeferredAt"
    private let lastPresentedAtKey = "reviewPromptLastPresentedAt"
    private let didRequestReviewKey = "reviewPromptDidRequestReview"
    private let lastPromptedAppVersionKey = "reviewPromptLastPromptedAppVersion"
    private let minimumCompletedEpisodes = 5
    private let minimumActiveDays = 2
    private let deferCooldown: TimeInterval = 14 * 24 * 60 * 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func recordCompletedEpisode(
        _ episode: Episode,
        isFollowingShow: Bool,
        now: Date = Date()
    ) -> Bool {
        var completedEpisodeIDs = Set(defaults.stringArray(forKey: completedEpisodeIDsKey) ?? [])
        completedEpisodeIDs.insert(episode.id)
        defaults.set(Array(completedEpisodeIDs), forKey: completedEpisodeIDsKey)

        var activeDayIDs = Set(defaults.stringArray(forKey: activeDayIDsKey) ?? [])
        activeDayIDs.insert(Self.dayID(for: now))
        defaults.set(Array(activeDayIDs), forKey: activeDayIDsKey)

        guard isFollowingShow,
              completedEpisodeIDs.count >= minimumCompletedEpisodes,
              activeDayIDs.count >= minimumActiveDays,
              canPresentPrompt(now: now) else {
            return false
        }

        markPromptPresented(now: now)
        return true
    }

    func markReviewRequested() {
        defaults.set(true, forKey: didRequestReviewKey)
    }

    func deferPrompt(now: Date = Date()) {
        defaults.set(now, forKey: lastDeferredAtKey)
    }

    private func canPresentPrompt(now: Date) -> Bool {
        guard !defaults.bool(forKey: didRequestReviewKey),
              defaults.string(forKey: lastPromptedAppVersionKey) != Self.appVersion else {
            return false
        }

        guard let lastDeferredAt = defaults.object(forKey: lastDeferredAtKey) as? Date else {
            return true
        }

        return now.timeIntervalSince(lastDeferredAt) >= deferCooldown
    }

    private func markPromptPresented(now: Date) {
        defaults.set(now, forKey: lastPresentedAtKey)
        defaults.set(Self.appVersion, forKey: lastPromptedAppVersionKey)
    }

    private static func dayID(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "\(year)-\(month)-\(day)"
    }

    static var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "MicroDrama"
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}

private enum AppReviewRequester {
    @MainActor
    static func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        SKStoreReviewController.requestReview(in: scene)
    }
}

@MainActor
private final class ScreenCaptureProtectionStore: ObservableObject {
    @Published private(set) var isScreenCaptured = UIScreen.main.isCaptured

    private var observer: NSObjectProtocol?

    init(notificationCenter: NotificationCenter = .default) {
        observer = notificationCenter.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func refresh() {
        isScreenCaptured = UIScreen.main.isCaptured
    }
}

private struct ReviewSoftAskSheet: View {
    let appName: String
    let onLeaveRating: () -> Void
    let onRated: () -> Void

    @State private var hasStartedRating = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "star.bubble.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.yellow, .blue)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Enjoying \(appName)?")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                Text("Leave a rating! We're a small team, so a rating goes a really long way.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                Button {
                    hasStartedRating = true
                    onLeaveRating()
                } label: {
                    Text("Leave a rating")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                if hasStartedRating {
                    Button(action: onRated) {
                        Text("I rated")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }
}

private struct EpisodePage: View {
    let showTitle: String
    let episode: Episode
    let isActive: Bool
    let isUnlocked: Bool
    let isFollowing: Bool
    let isScreenCaptured: Bool
    let playbackRate: Float
    let onFollow: () -> Void
    let onEpisodesTapped: () -> Void
    let onRewardedUnlock: () -> Void
    let onVideoFinished: () -> Void

    @ObservedObject private var rewardedAd = RewardedEpisodeUnlockAd.shared
    @State private var playbackProgress: Double = 0
    @State private var playbackDuration: Double = 0
    @State private var isScrubbing = false
    @State private var seekRequest: PlaybackSeekRequest?
    @State private var toggleRequest: PlaybackToggleRequest?
    @State private var lockedOfferAlert: LockedOffer?
    @State private var isAdErrorPresented = false
    @State private var isUnlockDrawerPresented = false
    @State private var unlockDrawerDragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            if isEpisodeLocked {
                LockedEpisodeBackgroundView(episode: episode)
            } else {
                PlayerSurface(
                    episode: episode,
                    thumbnailUrl: episode.thumbnailUrl,
                    isActive: isActive,
                    isPlaybackBlocked: isScreenCaptured,
                    playbackRate: playbackRate,
                    progress: $playbackProgress,
                    duration: $playbackDuration,
                    isScrubbing: $isScrubbing,
                    seekRequest: seekRequest,
                    toggleRequest: toggleRequest,
                    onFinished: onVideoFinished
                )
            }

            if isScreenCaptured && !isEpisodeLocked {
                ScreenCaptureProtectionOverlay()
                    .zIndex(3)
            }

            if !isEpisodeLocked {
                PlaybackWatermarkView(text: PlaybackWatermark.value)
                    .padding(.top, 118)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .zIndex(2)
                    .allowsHitTesting(false)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            if isActive && !isEpisodeLocked {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleRequest = PlaybackToggleRequest()
                    }
            }

            if isEpisodeLocked {
                if !isUnlockDrawerPresented {
                    LockedEpisodeOverlay(
                        episode: episode,
                        onUnlockNow: { presentUnlockDrawer() },
                        isAdLoading: rewardedAd.isLoading,
                        onWatchAd: showRewardedAdUnlock
                    )
                    .padding(.horizontal, 18)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .transition(.opacity)
                }

                HStack(alignment: .bottom, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(showTitle)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text(episode.description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ActionRail(
                        isFollowing: isFollowing,
                        onFollow: onFollow,
                        onEpisodesTapped: onEpisodesTapped
                    )
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 34)
                .frame(maxHeight: .infinity, alignment: .bottom)

                if isUnlockDrawerPresented {
                    Color.black.opacity(0.26)
                        .ignoresSafeArea()
                        .onTapGesture(perform: dismissUnlockDrawer)
                        .transition(.opacity)

                    LockedPaywallDrawer(
                        episode: episode,
                        onOfferTapped: { offer in
                            dismissUnlockDrawer()
                            lockedOfferAlert = offer
                        }
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 22)
                    .offset(y: unlockDrawerDragOffset)
                    .gesture(unlockDrawerDragGesture)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
                }
            } else {
                VStack(spacing: 10) {
                    HStack(alignment: .bottom, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(showTitle)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            Text(episode.description)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.86))
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ActionRail(
                            isFollowing: isFollowing,
                            onFollow: onFollow,
                            onEpisodesTapped: onEpisodesTapped
                        )
                    }

                    if isActive {
                        PlaybackProgressBar(progress: $playbackProgress, isScrubbing: $isScrubbing) { progress in
                            seekRequest = PlaybackSeekRequest(progress: progress)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 34)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .ignoresSafeArea()
        .alert(item: $lockedOfferAlert) { offer in
            Alert(
                title: Text("Coming Soon"),
                message: Text(offer.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Unable to show ad", isPresented: $isAdErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(rewardedAd.lastErrorMessage ?? "The rewarded ad is still loading. Please try again in a moment.")
        }
        .onAppear {
            if isActive && isEpisodeLocked {
                presentUnlockDrawer(animated: false)
                Task {
                    await rewardedAd.loadIfNeeded()
                }
            }
        }
        .onChange(of: isActive) { _, isActive in
            guard isEpisodeLocked else { return }

            if isActive {
                presentUnlockDrawer()
                Task {
                    await rewardedAd.loadIfNeeded()
                }
            } else {
                dismissUnlockDrawer()
            }
        }
    }

    private var isEpisodeLocked: Bool {
        episode.isLocked && !isUnlocked
    }

    private var unlockDrawerDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                unlockDrawerDragOffset = max(value.translation.height, 0)
            }
            .onEnded { value in
                if value.translation.height > 90 || value.predictedEndTranslation.height > 170 {
                    dismissUnlockDrawer()
                } else {
                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                        unlockDrawerDragOffset = 0
                    }
                }
            }
    }

    private func presentUnlockDrawer(animated: Bool = true) {
        let changes = {
            unlockDrawerDragOffset = 0
            isUnlockDrawerPresented = true
        }

        if animated {
            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.9), changes)
        } else {
            changes()
        }
    }

    private func dismissUnlockDrawer() {
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.9)) {
            unlockDrawerDragOffset = 0
            isUnlockDrawerPresented = false
        }
    }

    private func showRewardedAdUnlock() {
        guard rewardedAd.isReady else {
            isAdErrorPresented = true
            Task {
                await rewardedAd.loadIfNeeded()
            }
            return
        }

        rewardedAd.show {
            onRewardedUnlock()
            dismissUnlockDrawer()
        }
    }
}

private struct PlayerHeader: View {
    let episodeNumber: Int?
    let onBack: () -> Void
    let onSpeed: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))

                    Text(episodeNumber.map { "Episode \($0)" } ?? "Episode")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel("Back")

            Spacer()

            Button(action: onSpeed) {
                HStack(spacing: 7) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 16, weight: .semibold))

                    Text("Speed")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel("Speed")
        }
    }
}

private enum PlaybackWatermark {
    private static let storageKey = "playbackWatermarkID"

    static var value: String {
        let defaults = UserDefaults.standard
        let rawID: String

        if let existing = defaults.string(forKey: storageKey) {
            rawID = existing
        } else {
            rawID = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            defaults.set(rawID, forKey: storageKey)
        }

        return "MD-\(rawID.prefix(8).uppercased())"
    }
}

private struct PlaybackWatermarkView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.42))
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}

private struct ScreenCaptureProtectionOverlay: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .accessibilityHidden(true)

                Text("Playback paused")
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text("Turn off screen recording, mirroring, or AirPlay to continue watching.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
        }
    }
}

private struct PlaybackProgressBar: View {
    @Binding var progress: Double
    @Binding var isScrubbing: Bool
    let onScrub: (Double) -> Void

    var body: some View {
        Slider(
            value: Binding(
                get: { min(max(progress, 0), 1) },
                set: { progress = min(max($0, 0), 1) }
            ),
            in: 0...1,
            onEditingChanged: { editing in
                isScrubbing = editing
                if !editing {
                    onScrub(progress)
                }
            }
        )
        .tint(.white)
        .frame(height: 24)
        .accessibilityLabel("Playback progress")
    }
}

private struct PlayerSurface: View {
    let episode: Episode
    let thumbnailUrl: URL
    let isActive: Bool
    let isPlaybackBlocked: Bool
    let playbackRate: Float
    @Binding var progress: Double
    @Binding var duration: Double
    @Binding var isScrubbing: Bool
    let seekRequest: PlaybackSeekRequest?
    let toggleRequest: PlaybackToggleRequest?
    let onFinished: () -> Void

    @State private var player: AVPlayer?
    @State private var endObserver: NSObjectProtocol?
    @State private var itemStatusObserver: NSKeyValueObservation?
    @State private var timeObserver: Any?
    @State private var isPaused = false
    @State private var isReadyForDisplay = false
    @State private var loadErrorMessage: String?

    var body: some View {
        Group {
            if let player {
                ZStack {
                    PlayerLayerView(player: player, isReadyForDisplay: $isReadyForDisplay)
                        .ignoresSafeArea()

                    if !isReadyForDisplay {
                        EpisodeThumbnailView(thumbnailUrl: thumbnailUrl)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }

                    if isActive && isPaused {
                        Image(systemName: "play.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 74, height: 74)
                            .background(.black.opacity(0.34), in: Circle())
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .onAppear {
                    syncPlaybackState()
                }
                .onDisappear {
                    player.pause()
                }
            } else {
                ZStack {
                    EpisodeThumbnailView(thumbnailUrl: thumbnailUrl)

                    if let loadErrorMessage {
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                                .accessibilityHidden(true)

                            Text(loadErrorMessage)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(18)
                        .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
        .task(id: episode.id) {
            loadErrorMessage = nil
            removeTimeObserver()
            removeItemStatusObserver()
            removeEndObserver()
            isReadyForDisplay = false
            player?.pause()
            player = nil

            do {
                let ticket = try await APIClient.shared.fetchPlaybackTicket(for: episode)
                preparePlayer(url: ticket.playbackUrl)
            } catch {
                loadErrorMessage = "Unable to load playback."
            }
        }
        .onChange(of: isActive) { _, _ in
            syncPlaybackState()
        }
        .onChange(of: isPlaybackBlocked) { _, _ in
            syncPlaybackState()
        }
        .onChange(of: playbackRate) { _, _ in
            syncPlaybackState()
        }
        .onChange(of: seekRequest) { _, request in
            guard let request else { return }
            seek(to: request.progress)
        }
        .onChange(of: toggleRequest) { _, request in
            guard request != nil else { return }
            togglePlayback()
        }
        .onDisappear {
            player?.pause()
            removeTimeObserver()
            removeItemStatusObserver()
            player = nil
            removeEndObserver()
        }
    }

    private func preparePlayer(url: URL) {
        removeTimeObserver()
        removeItemStatusObserver()
        removeEndObserver()
        isReadyForDisplay = false

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 4
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true

        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = false
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            onFinished()
        }
        player = newPlayer
        progress = 0
        duration = 0
        isPaused = false
        addTimeObserver(to: newPlayer)
        observeItemReadiness(item, player: newPlayer)
        syncPlaybackState(for: newPlayer)
    }

    private func removeEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    private func observeItemReadiness(_ item: AVPlayerItem, player: AVPlayer) {
        itemStatusObserver = item.observe(\.status, options: [.initial, .new]) { item, _ in
            guard item.status == .readyToPlay else { return }
            Task { @MainActor in
                syncPlaybackState(for: player)
            }
        }
    }

    private func removeItemStatusObserver() {
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
    }

    private func addTimeObserver(to player: AVPlayer) {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 60),
            queue: .main
        ) { time in
            let itemDuration = player.currentItem?.duration.seconds ?? 0
            guard itemDuration.isFinite, itemDuration > 0 else { return }

            duration = itemDuration
            if !isScrubbing {
                progress = min(max(time.seconds / itemDuration, 0), 1)
            }
        }
    }

    private func removeTimeObserver() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    private func togglePlayback() {
        guard let player, isActive, !isPlaybackBlocked else { return }

        withAnimation(.easeInOut(duration: 0.16)) {
            isPaused.toggle()
        }

        if isPaused {
            player.pause()
        } else {
            player.playImmediately(atRate: playbackRate)
        }
    }

    private func playIfNeeded() {
        guard let player, isActive, !isPaused, !isPlaybackBlocked else { return }
        player.playImmediately(atRate: playbackRate)
    }

    private func syncPlaybackState(for targetPlayer: AVPlayer? = nil) {
        guard let currentPlayer = self.player else { return }
        let player = targetPlayer ?? currentPlayer
        guard player === currentPlayer else { return }

        if isActive && !isPlaybackBlocked {
            guard !isPaused else { return }
            player.playImmediately(atRate: playbackRate)
        } else {
            player.pause()
            if player.status == .readyToPlay {
                player.preroll(atRate: playbackRate) { _ in }
            }
        }
    }

    private func seek(to progress: Double) {
        guard let player else { return }

        let itemDuration = player.currentItem?.duration.seconds ?? duration
        guard itemDuration.isFinite, itemDuration > 0 else { return }

        let clampedProgress = min(max(progress, 0), 1)
        let target = CMTime(seconds: itemDuration * clampedProgress, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            playIfNeeded()
        }
    }
}

private struct PlaybackSeekRequest: Equatable {
    let id: UUID
    let progress: Double

    init(progress: Double) {
        id = UUID()
        self.progress = progress
    }
}

private struct PlaybackToggleRequest: Equatable {
    let id = UUID()
}

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    @Binding var isReadyForDisplay: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        context.coordinator.observeReadyForDisplay(on: view.playerLayer)
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        context.coordinator.parent = self
        uiView.playerLayer.videoGravity = .resizeAspect

        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
            context.coordinator.observeReadyForDisplay(on: uiView.playerLayer)
        } else {
            context.coordinator.updateReadyForDisplay(uiView.playerLayer.isReadyForDisplay)
        }
    }

    final class Coordinator {
        var parent: PlayerLayerView
        private var readyForDisplayObservation: NSKeyValueObservation?

        init(_ parent: PlayerLayerView) {
            self.parent = parent
        }

        func observeReadyForDisplay(on playerLayer: AVPlayerLayer) {
            readyForDisplayObservation = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
                self?.updateReadyForDisplay(layer.isReadyForDisplay)
            }
        }

        func updateReadyForDisplay(_ isReadyForDisplay: Bool) {
            DispatchQueue.main.async {
                self.parent.isReadyForDisplay = isReadyForDisplay
            }
        }
    }
}

private final class PlayerUIView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

private struct LockedEpisodeBackgroundView: View {
    let episode: Episode

    var body: some View {
        ZStack {
            RemoteImage(url: episode.thumbnailUrl)
                .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .ignoresSafeArea()

            Color.black.opacity(0.64).ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.2), .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

private struct LockedEpisodeOverlay: View {
    let episode: Episode
    let onUnlockNow: () -> Void
    let isAdLoading: Bool
    let onWatchAd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 10) {
                Button(action: onUnlockNow) {
                    Label("Unlock Now", systemImage: "lock.open.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Unlock Now")

                Button(action: onWatchAd) {
                    Label(
                        isAdLoading ? "Loading ad..." : "Watch an ad to unlock for free",
                        systemImage: "play.rectangle.fill"
                    )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(0.16), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isAdLoading)
                .accessibilityLabel("Watch an ad to unlock for free")
            }
        }
        .padding(16)
        .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
    }
}

private struct LockedPaywallDrawer: View {
    let episode: Episode
    let onOfferTapped: (LockedOffer) -> Void

    private let offers: [LockedOffer] = [
        .oneTimeUnlock,
        .weeklyUnlimited,
        .yearlyUnlimited
    ]

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.black.opacity(0.18))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 14)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 10) {
                    ForEach(offers) { offer in
                        LockedOfferRow(offer: offer) {
                            onOfferTapped(offer)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 24, y: 14)
    }
}

private struct LockedOfferRow: View {
    let offer: LockedOffer
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: offer.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(offer.isRecommended ? .white : .blue)
                    .frame(width: 36, height: 36)
                    .background(offer.isRecommended ? Color.blue : Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(offer.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    if let badge = offer.badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(offer.isRecommended ? .blue : .secondary)
                            .padding(.horizontal, 6)
                            .frame(height: 18)
                            .background(offer.isRecommended ? Color.blue.opacity(0.12) : Color(uiColor: .tertiarySystemFill), in: Capsule())
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }

                    Text(offer.price)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(minHeight: 62)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(offer.isRecommended ? Color.blue.opacity(0.65) : Color.black.opacity(0.05), lineWidth: offer.isRecommended ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(offer.title), \(offer.price)")
    }
}

private enum LockedOffer: String, Identifiable {
    case watchAd
    case oneTimeUnlock
    case weeklyUnlimited
    case yearlyUnlimited

    var id: String { rawValue }

    var title: String {
        switch self {
        case .watchAd:
            "Watch Ad"
        case .oneTimeUnlock:
            "One-time Unlock"
        case .weeklyUnlimited:
            "Weekly Unlimited"
        case .yearlyUnlimited:
            "Yearly Unlimited"
        }
    }

    var subtitle: String {
        switch self {
        case .watchAd:
            "Unlock this episode after an ad"
        case .oneTimeUnlock:
            "Get access to this episode"
        case .weeklyUnlimited:
            "Unlimited for one week"
        case .yearlyUnlimited:
            "Unlimited episodes all year"
        }
    }

    var price: String {
        switch self {
        case .watchAd:
            "Free"
        case .oneTimeUnlock:
            "$0.99"
        case .weeklyUnlimited:
            "$4.99/wk"
        case .yearlyUnlimited:
            "$39.99/yr"
        }
    }

    var systemImage: String {
        switch self {
        case .watchAd:
            "play.rectangle"
        case .oneTimeUnlock:
            "lock.open"
        case .weeklyUnlimited:
            "calendar.badge.clock"
        case .yearlyUnlimited:
            "crown"
        }
    }

    var badge: String? {
        switch self {
        case .weeklyUnlimited:
            "Recommended"
        case .yearlyUnlimited:
            "Best value"
        default:
            nil
        }
    }

    var isRecommended: Bool {
        self == .weeklyUnlimited
    }

    var alertMessage: String {
        switch self {
        case .watchAd:
            "This will show an interstitial advertisement, unlocking the episode."
        case .oneTimeUnlock:
            "One-time episode unlock will implement iOS one-time purchase."
        case .weeklyUnlimited:
            "Weekly unlimited access will implement iOS in-app purchases."
        case .yearlyUnlimited:
            "Yearly unlimited access will implement iOS in-app purchases."
        }
    }
}

private struct EpisodeThumbnailView: View {
    let thumbnailUrl: URL

    init(episode: Episode) {
        thumbnailUrl = episode.thumbnailUrl
    }

    init(thumbnailUrl: URL) {
        self.thumbnailUrl = thumbnailUrl
    }

    var body: some View {
        RemoteImage(url: thumbnailUrl)
            .scaledToFit()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

private struct ActionRail: View {
    let isFollowing: Bool
    let onFollow: () -> Void
    let onEpisodesTapped: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ActionRailButton(
                systemName: isFollowing ? "checkmark.circle.fill" : "plus.circle",
                title: isFollowing ? "Following" : "Follow",
                tint: isFollowing ? .green : .white,
                action: onFollow
            )
            .accessibilityLabel(isFollowing ? "Unfollow show" : "Follow show")

            ActionRailButton(
                systemName: "list.bullet",
                title: "Episodes",
                action: onEpisodesTapped
            )
            .accessibilityLabel("Episodes")

            ShareLink(item: "https://micro-drama.onrender.com") {
                ActionRailItem(systemName: "square.and.arrow.up", title: "Share")
            }
            .accessibilityLabel("Share")
        }
        .foregroundStyle(.white)
        .shadow(radius: 5)
        .frame(width: 64)
    }
}

private struct NotificationSoftAskSheet: View {
    let showTitle: String
    let onNotify: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 54, height: 54)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(spacing: 7) {
                Text("Get notified about new episodes?")
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("We'll let you know when more \(showTitle) is ready to watch.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                Button("Notify Me", action: onNotify)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                Button("Not Now", action: onNotNow)
                    .buttonStyle(.plain)
                    .controlSize(.large)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 18)
    }
}

private struct ActionRailButton: View {
    let systemName: String
    let title: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ActionRailItem(systemName: systemName, title: title, tint: tint)
        }
    }
}

private struct ActionRailItem: View {
    let systemName: String
    let title: String
    var tint: Color = .white

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 32)

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(width: 64)
        .contentShape(Rectangle())
    }
}

private struct EpisodeListSheet: View {
    let showTitle: String
    let episodes: [Episode]
    let currentEpisodeID: String?
    let onSelect: (Int) -> Void

    var body: some View {
        NavigationStack {
            List(Array(episodes.enumerated()), id: \.element.id) { index, episode in
                Button {
                    onSelect(index)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(episode.episodeNumber)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(width: 34, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(episode.title)
                                .font(.body)
                                .foregroundStyle(.primary)

                            Text(episode.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        if episode.isLocked {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                        } else if episode.id == currentEpisodeID {
                            Image(systemName: "checkmark")
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(showTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SpeedSelectionSheet: View {
    @Binding var selectedRate: Float
    let onSelect: () -> Void

    private let rates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Speed")
                .font(.headline)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(rates, id: \.self) { rate in
                    Button {
                        selectedRate = rate
                        onSelect()
                    } label: {
                        HStack(spacing: 12) {
                            Text(label(for: rate))
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            if selectedRate == rate {
                                Image(systemName: "checkmark")
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 42)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 18)
    }

    private func label(for rate: Float) -> String {
        switch rate {
        case 0.75:
            "0.75x"
        case 1.0:
            "1.0x"
        case 1.25:
            "1.25x"
        case 1.5:
            "1.5x"
        case 2.0:
            "2.0x"
        default:
            "\(rate)x"
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
