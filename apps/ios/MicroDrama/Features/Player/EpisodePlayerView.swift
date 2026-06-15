import AVFoundation
import StoreKit
import SwiftUI
import UIKit

struct EpisodePlayerView: View {
    let onEpisodeChanged: (Episode, ShowDetail) -> Void
    let onShowCompleted: (ShowDetail) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var activeShow: ShowDetail
    @State private var currentIndex: Int
    @State private var dragOffset: CGFloat = 0
    @State private var upNextState: UpNextState?
    @State private var isUpNextPresented = false
    @State private var isStartingUpNext = false
    @State private var completedShowIDsInSession: Set<String> = []
    @State private var isShowInfoPresented = false
    @State private var showInfoInitialTab: ShowInfoTab = .synopsis
    @State private var isSpeedSheetPresented = false
    @State private var isNotificationSoftAskPresented = false
    @State private var isReviewSoftAskPresented = false
    @State private var unlockedEpisodeIDs: Set<String> = []
    @State private var playbackRate: Float = 1.0
    @ObservedObject private var followedShowStore = FollowedShowStore.shared
    @ObservedObject private var notificationStore = NotificationPermissionStore.shared
    @ObservedObject private var reviewPromptStore = AppReviewPromptStore.shared
    @StateObject private var screenCaptureProtection = ScreenCaptureProtectionStore()
    private let apiClient = APIClient.shared
    private let progressStore = ShowEpisodeProgressStore.shared
    private let tasteOnboardingStore = TasteOnboardingStore.shared

    init(
        show: ShowDetail,
        initialEpisodeID: String? = nil,
        onEpisodeChanged: @escaping (Episode, ShowDetail) -> Void = { _, _ in },
        onShowCompleted: @escaping (ShowDetail) -> Void = { _ in }
    ) {
        self.onEpisodeChanged = onEpisodeChanged
        self.onShowCompleted = onShowCompleted
        _activeShow = State(initialValue: show)

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
                        if let episode = activeShow.episodes[safe: index] {
                            EpisodePage(
                                showTitle: activeShow.title,
                                episode: episode,
                                isActive: index == currentIndex && !isReviewSoftAskPresented && !isUpNextPresented,
                                isUnlocked: unlockedEpisodeIDs.contains(episode.id),
                                isFollowing: followedShowStore.isFollowing(activeShow),
                                isScreenCaptured: screenCaptureProtection.isScreenCaptured,
                                playbackRate: playbackRate,
                                shareURL: shareURL(for: activeShow),
                                onFollow: { toggleFollow(for: episode) },
                                onShowInfoTapped: { presentShowInfo(tab: .synopsis) },
                                onEpisodesTapped: { presentShowInfo(tab: .episodes) },
                                onRewardedUnlock: { unlockedEpisodeIDs.insert(episode.id) },
                                onVideoFinished: finishCurrentEpisode
                            )
                            .frame(width: proxy.size.width, height: pageHeight)
                            .offset(y: CGFloat(index - currentIndex) * pageHeight + dragOffset + episodeStackOffset(pageHeight: pageHeight))
                        }
                    }

                    if let upNextState {
                        UpNextOverlayView(
                            state: upNextState,
                            isStarting: isStartingUpNext,
                            isPresented: isUpNextPresented,
                            onBack: { dismiss() }
                        )
                        .frame(width: proxy.size.width, height: pageHeight)
                        .offset(y: upNextPageOffset(pageHeight: pageHeight))
                    }
                }
                .clipped()

                if !isUpNextPresented {
                    PlayerHeader(
                        episodeNumber: activeShow.episodes[safe: currentIndex]?.episodeNumber,
                        onBack: { dismiss() },
                        onSpeed: { isSpeedSheetPresented = true }
                    )
                    .padding(.horizontal, 14)
                    .padding(.top, headerTopPadding)
                }
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
        .sheet(isPresented: $isShowInfoPresented) {
            ShowInfoSheet(
                show: activeShow,
                currentEpisodeID: activeShow.episodes[safe: currentIndex]?.id,
                initialTab: showInfoInitialTab,
                isInMyList: followedShowStore.isFollowing(activeShow),
                moreLikeThisRequest: moreLikeThisRequest,
                onToggleMyList: {
                    if let episode = activeShow.episodes[safe: currentIndex] {
                        toggleFollow(for: episode)
                    }
                },
                onSelect: { index in
                    withAnimation(pageAnimation) {
                        currentIndex = index
                        dragOffset = 0
                    }
                    isShowInfoPresented = false
                },
                onSelectShow: { recommendation in
                    isShowInfoPresented = false
                    Task {
                        await startShowFromInfo(recommendation)
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.black)
            .preferredColorScheme(.dark)
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
                showTitle: activeShow.title,
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
        guard !activeShow.episodes.isEmpty else { return [] }
        let lowerBound = max(activeShow.episodes.startIndex, currentIndex - 1)
        let upperBound = min(activeShow.episodes.index(before: activeShow.episodes.endIndex), currentIndex + 1)
        return Array(lowerBound...upperBound)
    }

    private var pageAnimation: Animation {
        .interactiveSpring(response: 0.32, dampingFraction: 0.9)
    }

    private var moreLikeThisRequest: MoreLikeThisRequest {
        MoreLikeThisRequest(
            completedShowIds: progressStore.completedShowIDs(),
            activeShowIds: progressStore.activeShowIDs(),
            onboarding: tasteOnboardingStore.profile.map { profile in
                HomeOnboardingProfile(
                    selectedAnchorIds: profile.selectedAnchorIDs,
                    selectedDealbreakerIds: profile.selectedDealbreakerIDs,
                    matchedShowId: profile.matchedShowID,
                    alternateShowIds: profile.alternateShowIDs
                )
            }
        )
    }

    private func episodeStackOffset(pageHeight: CGFloat) -> CGFloat {
        isUpNextPresented ? -pageHeight : 0
    }

    private func upNextPageOffset(pageHeight: CGFloat) -> CGFloat {
        (isUpNextPresented ? 0 : pageHeight) + dragOffset
    }

    private func presentShowInfo(tab: ShowInfoTab) {
        showInfoInitialTab = tab
        isShowInfoPresented = true
    }

    private func shareURL(for show: ShowDetail) -> URL {
        URL(string: "https://micro-drama.onrender.com/shows/\(show.id)")!
    }

    private func toggleFollow(for episode: Episode) {
        let didFollow = followedShowStore.toggle(show: activeShow, episode: episode)
        guard didFollow, notificationStore.canShowSoftAsk else { return }
        isNotificationSoftAskPresented = true
    }

    private func recordCurrentEpisode() {
        guard let episode = activeShow.episodes[safe: currentIndex] else { return }
        onEpisodeChanged(episode, activeShow)
    }

    private func updateDragOffset(_ verticalTranslation: CGFloat) {
        let isPullingPastFirstEpisode = currentIndex == 0 && verticalTranslation > 0
        let isPullingPastLastEpisode = currentIndex == activeShow.episodes.count - 1 && verticalTranslation < 0

        if isUpNextPresented {
            dragOffset = verticalTranslation
        } else if isPullingPastLastEpisode {
            prepareUpNextPage(for: activeShow)
            dragOffset = verticalTranslation
        } else if isPullingPastFirstEpisode {
            dragOffset = verticalTranslation * 0.25
        } else {
            dragOffset = verticalTranslation
        }
    }

    private func moveToNextEpisode() {
        guard currentIndex < activeShow.episodes.count - 1 else { return }
        withAnimation(pageAnimation) {
            currentIndex += 1
            dragOffset = 0
        }
    }

    private func finishCurrentEpisode() {
        guard let episode = activeShow.episodes[safe: currentIndex] else { return }
        let isFinalEpisode = currentIndex == activeShow.episodes.count - 1
        guard !isFinalEpisode else {
            markShowCompletedIfNeeded(activeShow)
            prepareUpNextPage(for: activeShow)
            withAnimation(pageAnimation) {
                isUpNextPresented = true
                dragOffset = 0
            }
            return
        }

        let shouldPromptForReview = reviewPromptStore.recordCompletedEpisode(
            episode,
            isFollowingShow: followedShowStore.isFollowing(activeShow)
        )

        moveToNextEpisode()

        guard shouldPromptForReview else { return }
        isReviewSoftAskPresented = true
    }

    private func prepareUpNextPage(for show: ShowDetail) {
        guard upNextState == nil else { return }

        upNextState = .loading(sourceShowTitle: show.title)

        Task {
            await loadUpNextRecommendation(for: show)
        }
    }

    private func markShowCompletedIfNeeded(_ show: ShowDetail) {
        guard completedShowIDsInSession.insert(show.id).inserted else { return }
        onShowCompleted(show)
    }

    private func loadUpNextRecommendation(for completedShow: ShowDetail) async {
        let request = EndOfShowRecommendationRequest(
            sourceShowId: completedShow.id,
            completedShowIds: progressStore.completedShowIDs(),
            activeShowIds: progressStore.activeShowIDs(),
            onboarding: tasteOnboardingStore.profile.map { profile in
                HomeOnboardingProfile(
                    selectedAnchorIds: profile.selectedAnchorIDs,
                    selectedDealbreakerIds: profile.selectedDealbreakerIDs,
                    matchedShowId: profile.matchedShowID,
                    alternateShowIds: profile.alternateShowIDs
                )
            }
        )

        do {
            let recommendation = try await apiClient.fetchEndOfShowRecommendation(request: request)
            guard activeShow.id == completedShow.id else { return }
            await RemoteImage.prefetch(urls: [recommendation.show.thumbnailUrl ?? recommendation.show.posterUrl])
            upNextState = .ready(sourceShowTitle: completedShow.title, recommendation: recommendation)
        } catch {
            guard activeShow.id == completedShow.id else { return }
            upNextState = .unavailable(sourceShowTitle: completedShow.title)
        }
    }

    private func startUpNextIfReady() {
        guard case let .ready(_, recommendation) = upNextState else { return }
        guard !isStartingUpNext else { return }
        isStartingUpNext = true
        withAnimation(pageAnimation) {
            dragOffset = 0
        }

        Task {
            await startUpNext(recommendation)
        }
    }

    private func startUpNext(_ recommendation: EndOfShowRecommendationResponse) async {
        do {
            let showDetail = try await apiClient.fetchShow(id: recommendation.show.id)
            let recommendedIndex = showDetail.episodes.firstIndex { $0.id == recommendation.episodeId } ?? 0

            activeShow = showDetail
            currentIndex = recommendedIndex
            dragOffset = 0
            upNextState = nil
            isUpNextPresented = false
            isStartingUpNext = false
            recordCurrentEpisode()
        } catch {
            isStartingUpNext = false
            upNextState = .unavailable(sourceShowTitle: activeShow.title)
        }
    }

    private func startShowFromInfo(_ recommendation: MoreLikeThisShow) async {
        do {
            let showDetail = try await apiClient.fetchShow(id: recommendation.show.id)
            let recommendedIndex = showDetail.episodes.firstIndex { $0.id == recommendation.episodeId } ?? 0

            activeShow = showDetail
            currentIndex = recommendedIndex
            dragOffset = 0
            upNextState = nil
            isUpNextPresented = false
            isStartingUpNext = false
            recordCurrentEpisode()
        } catch {
            return
        }
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

        if isUpNextPresented {
            settleUpNextDrag(value, threshold: threshold)
            return
        }

        if value.translation.height < -threshold {
            if currentIndex == activeShow.episodes.count - 1 {
                prepareUpNextPage(for: activeShow)
                markShowCompletedIfNeeded(activeShow)
                withAnimation(pageAnimation) {
                    isUpNextPresented = true
                    dragOffset = 0
                }
            } else {
                moveToNextEpisode()
            }
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

    private func settleUpNextDrag(_ value: DragGesture.Value, threshold: CGFloat) {
        if value.translation.height < -threshold {
            if case .ready = upNextState {
                startUpNextIfReady()
            } else {
                withAnimation(pageAnimation) {
                    dragOffset = 0
                }
            }
        } else if value.translation.height > threshold {
            withAnimation(pageAnimation) {
                isStartingUpNext = false
                isUpNextPresented = false
                dragOffset = 0
            }
        } else {
            withAnimation(pageAnimation) {
                dragOffset = 0
            }
        }
    }
}

private enum UpNextState {
    case loading(sourceShowTitle: String)
    case ready(sourceShowTitle: String, recommendation: EndOfShowRecommendationResponse)
    case unavailable(sourceShowTitle: String)
}

private struct UpNextOverlayView: View {
    let state: UpNextState
    let isStarting: Bool
    let isPresented: Bool
    let onBack: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            switch state {
            case let .loading(sourceShowTitle):
                UpNextLoadingView(sourceShowTitle: sourceShowTitle)
            case let .ready(_, recommendation):
                UpNextReadyView(
                    recommendation: recommendation,
                    isStarting: isStarting,
                    isPresented: isPresented
                )
            case let .unavailable(sourceShowTitle):
                UpNextUnavailableView(sourceShowTitle: sourceShowTitle, onBack: onBack)
            }

            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(.black.opacity(0.42), in: Circle())
                }
                .accessibilityLabel("Back to Home")

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 24)
        }
    }
}

private struct UpNextLoadingView: View {
    let sourceShowTitle: String

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.white)

            Text("Finding what to watch next")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Because you watched \(sourceShowTitle)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct UpNextReadyView: View {
    let recommendation: EndOfShowRecommendationResponse
    let isStarting: Bool
    let isPresented: Bool
    @State private var countdownSeconds = 3

    var body: some View {
        GeometryReader { proxy in
            let posterWidth = min(proxy.size.width * 0.82, 342, proxy.size.height * 0.53 * 0.7176)

            ZStack(alignment: .bottom) {
                VStack(spacing: 16) {
                    Spacer(minLength: 60)

                    Text("Up Next")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .textCase(.uppercase)

                    Text(recommendation.show.title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    posterImage(width: posterWidth)

                    Spacer(minLength: max(proxy.safeAreaInsets.bottom + 92, 108))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                countdownAffordance
                    .padding(.horizontal, 34)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 22, 46))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RemoteImage(url: recommendation.show.coverUrl)
                .blur(radius: 28)
                .opacity(0.22)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.72).ignoresSafeArea())
        }
        .task(id: countdownTaskID) {
            countdownSeconds = 3
            guard isPresented else { return }

            for second in [2, 1] {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                countdownSeconds = second
            }
        }
    }

    private var countdownTaskID: String {
        "\(recommendation.show.id)-\(isPresented)"
    }

    private var countdownAffordance: some View {
        VStack(spacing: 9) {
            if isStarting {
                ProgressView()
                    .tint(.white)
            } else {
                Image(systemName: "chevron.up")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(isStarting ? "Starting..." : "Starting in \(countdownSeconds)")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }

    private func posterImage(width: CGFloat) -> some View {
        RemoteImage(url: recommendation.show.thumbnailUrl ?? recommendation.show.posterUrl)
            .frame(width: width, height: width / 0.7176)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .bottom) {
                Text(heroTraitText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .lineSpacing(2)
                    .minimumScaleFactor(0.86)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.top, 44)
                    .padding(.bottom, 12)
                    .background(alignment: .bottom) {
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0), location: 0),
                                .init(color: .black.opacity(0.24), location: 0.48),
                                .init(color: .black.opacity(0.78), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.white.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 10)
    }

    private var heroTraitText: String {
        let traits = recommendation.show.heroTraits.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !traits.isEmpty else { return recommendation.show.genre }
        return traits.prefix(4).joined(separator: " • ")
    }
}

private struct UpNextUnavailableView: View {
    let sourceShowTitle: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.white)

            Text("You finished \(sourceShowTitle)")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Text("No more recommendations are ready right now.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Button(action: onBack) {
                Text("Back to Home")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 34)
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    let shareURL: URL
    let onFollow: () -> Void
    let onShowInfoTapped: () -> Void
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
                        showTitleButton

                        Text(episode.description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ActionRail(
                        isFollowing: isFollowing,
                        shareURL: shareURL,
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
                            showTitleButton

                            Text(episode.description)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.86))
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ActionRail(
                            isFollowing: isFollowing,
                            shareURL: shareURL,
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

    private var showTitleButton: some View {
        Button(action: onShowInfoTapped) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(showTitle)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show info")
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

private struct ScreenCaptureProtectionOverlay: View {
    var body: some View {
        Color.black
            .ignoresSafeArea()
            .accessibilityHidden(true)
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
    let shareURL: URL
    let onFollow: () -> Void
    let onEpisodesTapped: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ActionRailButton(
                systemName: isFollowing ? "checkmark.circle.fill" : "plus.circle",
                title: isFollowing ? "Saved" : "My List",
                tint: isFollowing ? .green : .white,
                action: onFollow
            )
            .accessibilityLabel(isFollowing ? "Remove from My List" : "Add to My List")

            ActionRailButton(
                systemName: "list.bullet",
                title: "Episodes",
                action: onEpisodesTapped
            )
            .accessibilityLabel("Episodes")

            ShareLink(item: shareURL) {
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

private enum ShowInfoTab: String, CaseIterable, Identifiable {
    case synopsis = "Synopsis"
    case episodes = "Episodes"
    case moreLikeThis = "More Like This"

    var id: String { rawValue }
}

private struct ShowInfoSheet: View {
    let show: ShowDetail
    let currentEpisodeID: String?
    let isInMyList: Bool
    let moreLikeThisRequest: MoreLikeThisRequest
    let onToggleMyList: () -> Void
    let onSelect: (Int) -> Void
    let onSelectShow: (MoreLikeThisShow) -> Void

    @State private var selectedTab: ShowInfoTab
    @State private var moreLikeThis: [MoreLikeThisShow] = []
    @State private var isLoadingMoreLikeThis = false
    @State private var didFailMoreLikeThis = false

    private let apiClient = APIClient.shared

    init(
        show: ShowDetail,
        currentEpisodeID: String?,
        initialTab: ShowInfoTab,
        isInMyList: Bool,
        moreLikeThisRequest: MoreLikeThisRequest,
        onToggleMyList: @escaping () -> Void,
        onSelect: @escaping (Int) -> Void,
        onSelectShow: @escaping (MoreLikeThisShow) -> Void
    ) {
        self.show = show
        self.currentEpisodeID = currentEpisodeID
        self.isInMyList = isInMyList
        self.moreLikeThisRequest = moreLikeThisRequest
        self.onToggleMyList = onToggleMyList
        self.onSelect = onSelect
        self.onSelectShow = onSelectShow
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 14)

            Picker("Show Info", selection: $selectedTab) {
                ForEach(ShowInfoTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.bottom, 12)

            Divider()
                .overlay(.white.opacity(0.14))

            tabContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                RemoteImage(url: show.posterUrl)
                    .frame(width: 82, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(show.title)
                        .font(.title3.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)

                    Text(headerMetadata)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(2)

                    if let currentEpisode {
                        Label("Episode \(currentEpisode.episodeNumber)", systemImage: "play.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .frame(height: 28)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 14) {
                Button(action: onToggleMyList) {
                    ShowInfoActionItem(
                        systemName: isInMyList ? "checkmark" : "plus",
                        title: isInMyList ? "Saved" : "My List"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isInMyList ? "Remove from My List" : "Add to My List")

                ShareLink(item: shareURL) {
                    ShowInfoActionItem(systemName: "square.and.arrow.up", title: "Share")
                }
                .accessibilityLabel("Share")

                Spacer()
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .synopsis:
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(show.description)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.88))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if !showTraits.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(showTraits, id: \.self) { trait in
                                Text(trait)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                                    .padding(.horizontal, 10)
                                    .frame(height: 30)
                                    .frame(maxWidth: .infinity)
                                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .episodes:
            ShowEpisodeGrid(
                episodes: show.episodes,
                currentEpisodeID: currentEpisodeID,
                onSelect: onSelect
            )

        case .moreLikeThis:
            MoreLikeThisGrid(
                recommendations: moreLikeThis,
                isLoading: isLoadingMoreLikeThis,
                didFail: didFailMoreLikeThis,
                onSelect: onSelectShow
            )
            .task(id: show.id) {
                await loadMoreLikeThis()
            }
        }
    }

    private var headerMetadata: String {
        var parts = [show.genre, "\(show.episodeCount) episodes"]
        if freePreviewCount > 0 {
            parts.append("\(freePreviewCount) free")
        }
        return parts.joined(separator: " • ")
    }

    private var showTraits: [String] {
        let traits = show.heroTraits
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Array(traits.prefix(6))
    }

    private var freePreviewCount: Int {
        show.episodes.filter(\.isFreePreview).count
    }

    private var currentEpisode: Episode? {
        guard let currentEpisodeID else { return nil }
        return show.episodes.first { $0.id == currentEpisodeID }
    }

    private var shareURL: URL {
        URL(string: "https://micro-drama.onrender.com/shows/\(show.id)")!
    }

    private func loadMoreLikeThis() async {
        guard moreLikeThis.isEmpty, !isLoadingMoreLikeThis else { return }
        isLoadingMoreLikeThis = true
        didFailMoreLikeThis = false

        do {
            let recommendations = try await apiClient.fetchMoreLikeThis(showId: show.id, request: moreLikeThisRequest)
            moreLikeThis = recommendations
            isLoadingMoreLikeThis = false
            await RemoteImage.prefetch(urls: recommendations.map { $0.show.thumbnailUrl ?? $0.show.posterUrl })
        } catch {
            isLoadingMoreLikeThis = false
            didFailMoreLikeThis = true
        }
    }
}

private struct ShowInfoActionItem: View {
    let systemName: String
    let title: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 34, height: 30)

            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(.white)
        .frame(width: 72)
        .contentShape(Rectangle())
    }
}

private struct ShowEpisodeGrid: View {
    let episodes: [Episode]
    let currentEpisodeID: String?
    let onSelect: (Int) -> Void

    @State private var selectedRangeIndex = 0

    private let rangeSize = 30
    private let columns = Array(repeating: GridItem(.flexible(minimum: 44), spacing: 8), count: 6)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if episodeRanges.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(episodeRanges.indices, id: \.self) { index in
                                Button {
                                    selectedRangeIndex = index
                                } label: {
                                    Text(rangeLabel(for: episodeRanges[index]))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(selectedRangeIndex == index ? .black : .white.opacity(0.76))
                                        .padding(.horizontal, 13)
                                        .frame(height: 34)
                                        .background(selectedRangeIndex == index ? .white : .white.opacity(0.12), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                }

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(visibleEpisodes, id: \.offset) { item in
                        EpisodeGridTile(
                            episode: item.element,
                            isCurrent: item.element.id == currentEpisodeID,
                            action: { onSelect(item.offset) }
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 22)
            }
            .padding(.top, 16)
        }
        .onAppear(perform: selectCurrentRange)
        .onChange(of: currentEpisodeID) { _, _ in
            selectCurrentRange()
        }
    }

    private var episodeRanges: [Range<Int>] {
        stride(from: 0, to: episodes.count, by: rangeSize).map { start in
            start..<min(start + rangeSize, episodes.count)
        }
    }

    private var selectedRange: Range<Int> {
        guard episodeRanges.indices.contains(selectedRangeIndex) else {
            return episodeRanges.first ?? 0..<0
        }
        return episodeRanges[selectedRangeIndex]
    }

    private var visibleEpisodes: [(offset: Int, element: Episode)] {
        Array(episodes.enumerated()).filter { selectedRange.contains($0.offset) }
    }

    private func rangeLabel(for range: Range<Int>) -> String {
        guard let firstEpisode = episodes[safe: range.lowerBound],
              let lastEpisode = episodes[safe: range.upperBound - 1] else {
            return ""
        }
        return "\(firstEpisode.episodeNumber)-\(lastEpisode.episodeNumber)"
    }

    private func selectCurrentRange() {
        guard let currentEpisodeID,
              let currentIndex = episodes.firstIndex(where: { $0.id == currentEpisodeID }),
              let rangeIndex = episodeRanges.firstIndex(where: { $0.contains(currentIndex) }) else {
            return
        }

        selectedRangeIndex = rangeIndex
    }
}

private struct EpisodeGridTile: View {
    let episode: Episode
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isCurrent ? .white : .white.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(isCurrent ? .white : .white.opacity(0.08), lineWidth: 1)
                    }

                Text("\(episode.episodeNumber)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isCurrent ? .black : .white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if episode.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isCurrent ? .black.opacity(0.62) : .white.opacity(0.68))
                        .padding(6)
                } else if isCurrent {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black.opacity(0.72))
                        .padding(6)
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Episode \(episode.episodeNumber)")
    }
}

private struct MoreLikeThisGrid: View {
    let recommendations: [MoreLikeThisShow]
    let isLoading: Bool
    let didFail: Bool
    let onSelect: (MoreLikeThisShow) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Finding similar shows")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 42)
            } else if didFail {
                Text("More shows are not available right now.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 42)
                    .padding(.horizontal, 18)
            } else if recommendations.isEmpty {
                Text("No similar shows are ready yet.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 42)
                    .padding(.horizontal, 18)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    ForEach(recommendations) { recommendation in
                        Button {
                            onSelect(recommendation)
                        } label: {
                            MoreLikeThisCard(recommendation: recommendation)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
            }
        }
    }
}

private struct MoreLikeThisCard: View {
    let recommendation: MoreLikeThisShow

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            RemoteImage(url: recommendation.show.thumbnailUrl ?? recommendation.show.posterUrl)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(recommendation.show.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .lineSpacing(1)

            Text(recommendation.show.genre)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.54))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
