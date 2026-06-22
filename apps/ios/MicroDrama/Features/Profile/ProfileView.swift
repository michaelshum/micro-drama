import SwiftUI

private enum InitialNotificationShow {
    static let fruitLoveIslandID = "show_demo_fruit_love_island"
    static let fruitLoveIslandThumbnailPath = "/shows/\(fruitLoveIslandID)/poster"
}

@MainActor
final class MockNotificationStore: ObservableObject {
    static let shared = MockNotificationStore()

    @Published private(set) var notifications: [ProfileNotification] = [
        ProfileNotification(
            title: "New episodes waiting",
            message: "Fruit Love Island has fresh episodes ready to watch.",
            sentAt: Calendar.current.date(byAdding: .hour, value: -5, to: Date()) ?? Date(),
            systemImage: "play.rectangle.fill",
            thumbnailUrl: APIClient.shared.url(for: InitialNotificationShow.fruitLoveIslandThumbnailPath),
            showID: InitialNotificationShow.fruitLoveIslandID
        ),
        ProfileNotification(
            title: "Because you watched romance",
            message: "Try a new short drama picked for your next break.",
            sentAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            systemImage: "sparkles"
        )
    ]

    var sortedNotifications: [ProfileNotification] {
        notifications.sorted { $0.sentAt > $1.sentAt }
    }
}

struct ProfileNotification: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let message: String
    let sentAt: Date
    let systemImage: String
    let thumbnailUrl: URL?
    let showID: String?

    init(
        title: String,
        message: String,
        sentAt: Date,
        systemImage: String,
        thumbnailUrl: URL? = nil,
        showID: String? = nil
    ) {
        self.title = title
        self.message = message
        self.sentAt = sentAt
        self.systemImage = systemImage
        self.thumbnailUrl = thumbnailUrl
        self.showID = showID
    }
}

struct ProfileView: View {
    let onBrowseShows: () -> Void

    @StateObject private var notificationContentStore = MockNotificationStore.shared
    @StateObject private var notificationPermissionStore = NotificationPermissionStore.shared
    @StateObject private var adConsentManager = AdConsentManager.shared
    @StateObject private var episodeOpener = EpisodeOpeningViewModel()
    @ObservedObject private var followedShowStore = FollowedShowStore.shared

    init(onBrowseShows: @escaping () -> Void = {}) {
        self.onBrowseShows = onBrowseShows
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        NotificationsTrayView(store: notificationContentStore)
                    } label: {
                        NotificationHeaderRow(
                            notificationsEnabled: !notificationPermissionStore.shouldShowCTA,
                            notificationCount: notificationContentStore.notifications.count
                        )
                    }
                    .listRowSeparator(.hidden)

                    if !notificationPermissionStore.shouldShowCTA,
                       let latestNotification = notificationContentStore.sortedNotifications.first {
                        NotificationActionRow(notification: latestNotification) { notification in
                            Task {
                                await episodeOpener.open(notification)
                            }
                        } label: {
                            LatestNotificationPreviewRow(notification: latestNotification)
                        }
                        .listRowInsets(ProfileLayout.contentRowInsets)
                        .listRowSeparator(.hidden)
                    }
                }

                Section {
                    if followedShowStore.followedShows.isEmpty {
                        EmptyFollowingRow(onBrowseShows: onBrowseShows)
                    } else {
                        NavigationLink {
                            FollowedShowsView()
                        } label: {
                            FollowedShowsHeaderRow(followedCount: followedShowStore.followedShows.count)
                        }
                        .listRowSeparator(.hidden)

                        FollowedShowsShelf(
                            followedShows: followedShowStore.followedShows,
                            onSelect: { followedShow in
                                Task {
                                    await episodeOpener.open(followedShow)
                                }
                            }
                        )
                        .listRowInsets(ProfileLayout.contentRowInsets)
                        .listRowSeparator(.hidden)

                        if notificationPermissionStore.shouldShowCTA {
                            NotificationPermissionCTA()
                                .listRowInsets(ProfileLayout.contentRowInsets)
                                .listRowSeparator(.hidden)
                        }
                    }
                }

                Section {
                    if adConsentManager.isPrivacyOptionsRequired {
                        Button {
                            Task {
                                await adConsentManager.presentPrivacyOptions()
                            }
                        } label: {
                            ProfileSectionHeaderRow(
                                systemImage: "hand.raised.fill",
                                title: "Privacy Choices",
                                trailingText: "Manage"
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                    }

                    AppVersionFooter()
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .contentMargins(.top, 8, for: .scrollContent)
            .profileDarkChrome()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ShowSearchView()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search")
                }
            }
            .overlay {
                if episodeOpener.isLoading {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .alert("Unable to open episode", isPresented: episodeOpener.errorAlertBinding) {
                Button("OK") {
                    episodeOpener.errorMessage = nil
                }
            } message: {
                Text(episodeOpener.errorMessage ?? "")
            }
            .fullScreenCover(item: $episodeOpener.selectedShowDetail) { showDetail in
                EpisodePlayerView(
                    show: showDetail,
                    initialEpisodeID: episodeOpener.initialEpisodeID,
                    onEpisodeChanged: { episode, show in
                        episodeOpener.recordLastWatchedEpisode(episode, for: show)
                    },
                    onShowCompleted: { show in
                        episodeOpener.markShowCompleted(show)
                    }
                )
            }
            .task {
                await notificationPermissionStore.refreshAuthorizationStatus()
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct AppVersionFooter: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }

    var body: some View {
        Text("\(version) (\(build))")
            .font(ProfileTypography.rowMetadata)
            .foregroundStyle(ProfilePalette.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .textSelection(.enabled)
            .accessibilityLabel("Version \(version), build \(build)")
    }
}

private struct FollowedShowsHeaderRow: View {
    let followedCount: Int

    var body: some View {
        ProfileSectionHeaderRow(
            systemImage: "checkmark.circle.fill",
            title: "Following",
            trailingText: "\(followedCount) \(followedCount == 1 ? "show" : "shows")"
        )
    }
}

private struct NotificationHeaderRow: View {
    let notificationsEnabled: Bool
    let notificationCount: Int

    var body: some View {
        ProfileSectionHeaderRow(
            systemImage: notificationsEnabled ? "bell.fill" : "bell.slash.fill",
            title: "Notifications",
            trailingText: trailingText
        )
    }

    private var trailingText: String {
        if !notificationsEnabled {
            return "Off"
        }

        guard notificationCount > 0 else { return "No new" }
        return "\(notificationCount) new"
    }
}

private struct EmptyFollowingRow: View {
    let onBrowseShows: () -> Void
    @StateObject private var notificationPermissionStore = NotificationPermissionStore.shared

    var body: some View {
        HStack(spacing: 12) {
            ProfileRowIcon(
                systemImage: "plus.circle",
                width: 32
            )

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Follow shows you love")
                        .font(ProfileTypography.sectionTitle)
                        .foregroundStyle(ProfilePalette.primaryText)

                    Text("Get updates when new episodes drop.")
                        .font(ProfileTypography.rowSubtitle)
                        .foregroundStyle(ProfilePalette.secondaryText)
                        .lineLimit(2)
                }

                VStack(spacing: 8) {
                    Button {
                        onBrowseShows()
                    } label: {
                        Text("Browse Shows")
                            .font(ProfileTypography.rowAction)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(.blue, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if notificationPermissionStore.shouldShowCTA {
                        Button {
                            Task {
                                await notificationPermissionStore.requestAuthorization()
                            }
                        } label: {
                            Text("Turn On Notifications")
                                .font(ProfileTypography.rowAction)
                                .foregroundStyle(ProfilePalette.primaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(.white.opacity(0.14), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(notificationPermissionStore.isRequesting)
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .task {
            await notificationPermissionStore.refreshAuthorizationStatus()
        }
    }
}

private struct FollowedShowsShelf: View {
    let followedShows: [FollowedShow]
    let onSelect: (FollowedShow) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(followedShows) { followedShow in
                        Button {
                            onSelect(followedShow)
                        } label: {
                            FollowedShowShelfCard(followedShow: followedShow)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct FollowedShowShelfCard: View {
    let followedShow: FollowedShow

    private let cardWidth: CGFloat = ProfileLayout.homePosterWidth
    private var restartEpisodeNumber: Int {
        ShowEpisodeProgressStore.shared.activeLastWatchedEpisodeNumber(for: followedShow.showID)
            ?? (ShowEpisodeProgressStore.shared.hasCompletedShow(followedShow.showID) ? 1 : followedShow.latestEpisodeNumber)
    }
    private var categoryText: String {
        guard let showGenre = followedShow.showGenre, !showGenre.isEmpty else {
            return "Show"
        }
        return showGenre
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            PosterThumbnail(url: followedShow.posterUrl, width: cardWidth, height: ProfileLayout.homePosterHeight)

            Text(followedShow.showTitle)
                .font(ProfileTypography.shelfTitle)
                .foregroundStyle(ProfilePalette.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: cardWidth, alignment: .leading)

            Text("Episode \(restartEpisodeNumber)")
                .font(ProfileTypography.shelfAction)
                .foregroundStyle(ProfilePalette.secondaryText)
                .lineLimit(1)
                .frame(width: cardWidth, alignment: .leading)

            Text(categoryText)
                .font(ProfileTypography.shelfMetadata)
                .foregroundStyle(ProfilePalette.tertiaryText)
                .lineLimit(1)
                .frame(width: cardWidth, alignment: .leading)
        }
        .frame(width: cardWidth, alignment: .leading)
    }
}

private struct LatestNotificationPreviewRow: View {
    let notification: ProfileNotification

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            NotificationArtwork(
                notification: notification,
                width: ProfileLayout.homePosterWidth,
                height: ProfileLayout.homePosterHeight
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(notification.title)
                    .font(ProfileTypography.previewTitle)
                    .foregroundStyle(ProfilePalette.primaryText)
                    .lineLimit(2)

                Text(notification.message)
                    .font(ProfileTypography.rowSubtitle)
                    .foregroundStyle(ProfilePalette.secondaryText)
                    .lineLimit(2)

                Text(notification.sentAt.formatted(.relative(presentation: .named)))
                    .font(ProfileTypography.rowMetadata)
                    .foregroundStyle(ProfilePalette.tertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct NotificationsTrayView: View {
    @ObservedObject var store: MockNotificationStore
    @StateObject private var notificationPermissionStore = NotificationPermissionStore.shared
    @StateObject private var episodeOpener = EpisodeOpeningViewModel()

    var body: some View {
        List {
            if !notificationPermissionStore.shouldShowCTA {
                if store.notifications.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Notifications Yet",
                            systemImage: "bell",
                            description: Text("New episode drops, show reminders, and recommendations will appear here.")
                        )
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(store.sortedNotifications) { notification in
                            NotificationActionRow(notification: notification) { notification in
                                Task {
                                    await episodeOpener.open(notification)
                                }
                            } label: {
                                NotificationDetailRow(notification: notification)
                            }
                            .listRowInsets(ProfileLayout.contentRowInsets)
                        }
                    }
                }
            } else {
                Section {
                    VStack(spacing: 14) {
                        ContentUnavailableView(
                            "Notifications Are Off",
                            systemImage: "bell.slash",
                            description: Text("Enable notifications to see episode drops, show reminders, and recommendations.")
                        )

                        Button {
                            Task {
                                await notificationPermissionStore.requestAuthorization()
                            }
                        } label: {
                            Text("Enable Notifications")
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .disabled(notificationPermissionStore.isRequesting)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .profileDarkChrome()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notificationPermissionStore.refreshAuthorizationStatus()
        }
        .overlay {
            if episodeOpener.isLoading {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .alert("Unable to open episode", isPresented: episodeOpener.errorAlertBinding) {
            Button("OK") {
                episodeOpener.errorMessage = nil
            }
        } message: {
            Text(episodeOpener.errorMessage ?? "")
        }
        .fullScreenCover(item: $episodeOpener.selectedShowDetail) { showDetail in
            EpisodePlayerView(
                show: showDetail,
                initialEpisodeID: episodeOpener.initialEpisodeID,
                onEpisodeChanged: { episode, show in
                    episodeOpener.recordLastWatchedEpisode(episode, for: show)
                },
                onShowCompleted: { show in
                    episodeOpener.markShowCompleted(show)
                }
            )
        }
    }
}

private struct NotificationActionRow<Label: View>: View {
    let notification: ProfileNotification
    let onSelect: (ProfileNotification) -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        if notification.showID == nil {
            label()
        } else {
            Button {
                onSelect(notification)
            } label: {
                label()
            }
            .buttonStyle(.plain)
        }
    }
}

private struct NotificationDetailRow: View {
    let notification: ProfileNotification

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            NotificationArtwork(
                notification: notification,
                width: ProfileLayout.homePosterWidth,
                height: ProfileLayout.homePosterHeight
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(notification.title)
                    .font(ProfileTypography.rowTitle)
                    .foregroundStyle(ProfilePalette.primaryText)
                    .lineLimit(2)

                Text(notification.message)
                    .font(ProfileTypography.rowSubtitle)
                    .foregroundStyle(ProfilePalette.secondaryText)
                    .lineLimit(3)

                Text(notification.sentAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(ProfileTypography.rowMetadata)
                    .foregroundStyle(ProfilePalette.tertiaryText)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct FollowedShowsView: View {
    @ObservedObject private var followedShowStore = FollowedShowStore.shared
    @StateObject private var notificationPermissionStore = NotificationPermissionStore.shared
    @StateObject private var viewModel = EpisodeOpeningViewModel()

    var body: some View {
        List {
            if followedShowStore.followedShows.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Followed Shows",
                        systemImage: "plus.circle",
                        description: Text("Follow shows from the player to keep up with new episodes.")
                    )
                }
                .listRowBackground(Color.clear)

                if notificationPermissionStore.shouldShowCTA {
                    Section {
                        NotificationPermissionCTA()
                            .listRowInsets(ProfileLayout.contentRowInsets)
                    }
                    .listRowBackground(Color.clear)
                }
            } else {
                if notificationPermissionStore.shouldShowCTA {
                    Section {
                        NotificationPermissionCTA()
                            .listRowInsets(ProfileLayout.contentRowInsets)
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(followedShowStore.followedShows) { followedShow in
                        Button {
                            Task {
                                await viewModel.open(followedShow)
                            }
                        } label: {
                            FollowedShowRow(followedShow: followedShow)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                followedShowStore.remove(showID: followedShow.showID)
                            } label: {
                                Label("Unfollow", systemImage: "minus.circle")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .profileDarkChrome()
        .navigationTitle("Following")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notificationPermissionStore.refreshAuthorizationStatus()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .alert("Unable to open episode", isPresented: viewModel.errorAlertBinding) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .fullScreenCover(item: $viewModel.selectedShowDetail) { showDetail in
            EpisodePlayerView(
                show: showDetail,
                initialEpisodeID: viewModel.initialEpisodeID,
                onEpisodeChanged: { episode, show in
                    viewModel.recordLastWatchedEpisode(episode, for: show)
                },
                onShowCompleted: { show in
                    viewModel.markShowCompleted(show)
                }
            )
        }
    }
}

private struct NotificationPermissionCTA: View {
    @StateObject private var notificationPermissionStore = NotificationPermissionStore.shared

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ProfileRowIcon(systemImage: "bell.badge.fill", width: 32)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Never miss a new episode")
                        .font(ProfileTypography.rowTitle)
                        .foregroundStyle(ProfilePalette.primaryText)

                    Text("Turn on notifications for new episodes and free unlock windows.")
                        .font(ProfileTypography.rowSubtitle)
                        .foregroundStyle(ProfilePalette.secondaryText)
                        .lineLimit(3)
                }

                Button {
                    Task {
                        await notificationPermissionStore.requestAuthorization()
                    }
                } label: {
                    Text("Enable Notifications")
                        .foregroundStyle(.black)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .controlSize(.small)
                .disabled(notificationPermissionStore.isRequesting)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .task {
            await notificationPermissionStore.refreshAuthorizationStatus()
        }
    }
}

private struct FollowedShowRow: View {
    let followedShow: FollowedShow
    private var restartEpisodeNumber: Int {
        ShowEpisodeProgressStore.shared.activeLastWatchedEpisodeNumber(for: followedShow.showID)
            ?? (ShowEpisodeProgressStore.shared.hasCompletedShow(followedShow.showID) ? 1 : followedShow.latestEpisodeNumber)
    }
    private var categoryText: String {
        guard let showGenre = followedShow.showGenre, !showGenre.isEmpty else {
            return "Show"
        }
        return showGenre
    }

    var body: some View {
        HStack(spacing: 12) {
            PosterThumbnail(url: followedShow.posterUrl, width: 84, height: 112)

            VStack(alignment: .leading, spacing: 6) {
                Text(followedShow.showTitle)
                    .font(ProfileTypography.rowTitle)
                    .foregroundStyle(ProfilePalette.primaryText)
                    .lineLimit(2)

                Text("Episode \(restartEpisodeNumber)")
                    .font(ProfileTypography.rowAction)
                    .foregroundStyle(ProfilePalette.secondaryText)

                Text(categoryText)
                    .font(ProfileTypography.rowMetadata)
                    .foregroundStyle(ProfilePalette.tertiaryText)
            }
        }
        .padding(.vertical, 6)
    }
}

struct ShowSearchView: View {
    @StateObject private var viewModel = ShowSearchViewModel()

    var body: some View {
        List {
            ForEach(viewModel.filteredShows) { show in
                Button {
                    Task {
                        await viewModel.open(show)
                    }
                } label: {
                    SearchShowRow(show: show)
                }
                .buttonStyle(.plain)
                .listRowBackground(ProfilePalette.screenBackground)
                .listRowSeparatorTint(ProfilePalette.separator)
            }
        }
        .listStyle(.plain)
        .profileDarkChrome()
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search shows")
        .overlay {
            if viewModel.isLoading && viewModel.shows.isEmpty {
                ProgressView()
                    .controlSize(.large)
            } else if !viewModel.query.isEmpty && viewModel.filteredShows.isEmpty {
                ContentUnavailableView.search(text: viewModel.query)
            }
        }
        .task {
            await viewModel.loadShows()
        }
        .alert("Unable to load shows", isPresented: viewModel.errorAlertBinding) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .fullScreenCover(item: $viewModel.selectedShowDetail) { showDetail in
            EpisodePlayerView(
                show: showDetail,
                initialEpisodeID: viewModel.activeLastWatchedEpisodeID(for: showDetail.id),
                onEpisodeChanged: { episode, show in
                    viewModel.recordLastWatchedEpisode(episode, for: show)
                },
                onShowCompleted: { show in
                    viewModel.markShowCompleted(show)
                }
            )
        }
    }
}

private struct SearchShowRow: View {
    let show: Show

    var body: some View {
        HStack(spacing: 12) {
            PosterThumbnail(url: show.posterUrl, width: 62, height: 86)

            VStack(alignment: .leading, spacing: 5) {
                Text(show.title)
                    .font(ProfileTypography.rowTitle)
                    .foregroundStyle(ProfilePalette.primaryText)
                    .lineLimit(2)

                Text(show.genre)
                    .font(ProfileTypography.rowSubtitle)
                    .foregroundStyle(ProfilePalette.secondaryText)

                Text("\(show.episodeCount) episodes")
                    .font(ProfileTypography.rowMetadata)
                    .foregroundStyle(ProfilePalette.tertiaryText)
            }
        }
        .padding(.vertical, 5)
    }
}

@MainActor
private final class EpisodeOpeningViewModel: ObservableObject {
    @Published var selectedShowDetail: ShowDetail?
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let apiClient: APIClient
    private let progressStore: ShowEpisodeProgressStore

    var initialEpisodeID: String?

    init(apiClient: APIClient = .shared, progressStore: ShowEpisodeProgressStore = .shared) {
        self.apiClient = apiClient
        self.progressStore = progressStore
    }

    var errorAlertBinding: Binding<Bool> {
        Binding {
            self.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                self.errorMessage = nil
            }
        }
    }

    func open(_ followedShow: FollowedShow) async {
        isLoading = true
        defer { isLoading = false }

        do {
            initialEpisodeID = progressStore.activeLastWatchedEpisodeID(for: followedShow.showID)
                ?? (progressStore.hasCompletedShow(followedShow.showID) ? nil : followedShow.latestEpisodeID)
            selectedShowDetail = try await apiClient.fetchShow(id: followedShow.showID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func open(_ notification: ProfileNotification) async {
        guard let showID = notification.showID else { return }
        await open(showID: showID)
    }

    func open(showID: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            initialEpisodeID = progressStore.activeLastWatchedEpisodeID(for: showID)
            selectedShowDetail = try await apiClient.fetchShow(id: showID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recordLastWatchedEpisode(_ episode: Episode, for show: ShowDetail) {
        progressStore.setLastWatchedEpisode(episode, for: show.id)
    }

    func markShowCompleted(_ show: ShowDetail) {
        progressStore.markShowCompleted(showID: show.id)
    }
}

@MainActor
private final class ShowSearchViewModel: ObservableObject {
    @Published var shows: [Show] = []
    @Published var selectedShowDetail: ShowDetail?
    @Published var query = ""
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let apiClient: APIClient
    private let progressStore: ShowEpisodeProgressStore

    init(apiClient: APIClient = .shared, progressStore: ShowEpisodeProgressStore = .shared) {
        self.apiClient = apiClient
        self.progressStore = progressStore
    }

    var filteredShows: [Show] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return shows }

        return shows.filter { show in
            show.title.localizedCaseInsensitiveContains(trimmedQuery)
                || show.genre.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var errorAlertBinding: Binding<Bool> {
        Binding {
            self.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                self.errorMessage = nil
            }
        }
    }

    func loadShows() async {
        guard shows.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            shows = try await apiClient.fetchShows()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func open(_ show: Show) async {
        isLoading = true
        defer { isLoading = false }

        do {
            selectedShowDetail = try await apiClient.fetchShow(id: show.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func activeLastWatchedEpisodeID(for showID: String) -> String? {
        progressStore.activeLastWatchedEpisodeID(for: showID)
    }

    func recordLastWatchedEpisode(_ episode: Episode, for show: ShowDetail) {
        progressStore.setLastWatchedEpisode(episode, for: show.id)
    }

    func markShowCompleted(_ show: ShowDetail) {
        progressStore.markShowCompleted(showID: show.id)
    }
}

private enum ProfileTypography {
    static let sectionTitle = Font.title3.weight(.semibold)
    static let rowTitle = Font.body.weight(.semibold)
    static let previewTitle = Font.subheadline.weight(.semibold)
    static let rowSubtitle = Font.subheadline
    static let rowAction = Font.subheadline.weight(.medium)
    static let rowMetadata = Font.caption
    static let shelfTitle = Font.caption.weight(.semibold)
    static let shelfAction = Font.caption.weight(.medium)
    static let shelfMetadata = Font.caption2
}

private enum ProfileLayout {
    static let homePosterWidth: CGFloat = 108
    static let homePosterHeight: CGFloat = 150
    static let contentRowInsets = EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16)
}

private enum ProfilePalette {
    static let screenBackground = Color.black
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.68)
    static let tertiaryText = Color.white.opacity(0.42)
    static let iconTileBackground = Color.white.opacity(0.10)
    static let separator = Color.white.opacity(0.10)
}

private extension View {
    func profileDarkChrome() -> some View {
        scrollContentBackground(.hidden)
            .background(ProfilePalette.screenBackground.ignoresSafeArea())
            .toolbarBackground(ProfilePalette.screenBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
    }
}

private struct ProfileSectionHeaderRow: View {
    let systemImage: String
    let title: String
    let trailingText: String

    var body: some View {
        HStack(spacing: 12) {
            ProfileRowIcon(
                systemImage: systemImage,
                width: 32
            )

            Text(title)
                .font(ProfileTypography.sectionTitle)
                .foregroundStyle(ProfilePalette.primaryText)

            Spacer()

            Text(trailingText)
                .font(ProfileTypography.rowSubtitle)
                .foregroundStyle(ProfilePalette.secondaryText)
        }
        .padding(.vertical, 6)
    }
}

private struct ProfileRowIcon: View {
    let systemImage: String
    let width: CGFloat

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(ProfilePalette.secondaryText)
            .frame(width: width, alignment: .center)
    }
}

private struct NotificationIconTile: View {
    let systemImage: String
    let size: CGFloat

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(ProfilePalette.secondaryText)
            .frame(width: size, height: size)
            .background(ProfilePalette.iconTileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct NotificationArtwork: View {
    let notification: ProfileNotification
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        if let thumbnailUrl = notification.thumbnailUrl {
            PosterThumbnail(url: thumbnailUrl, width: width, height: height)
        } else {
            NotificationIconTile(systemImage: notification.systemImage, size: 44)
        }
    }
}

private struct PosterThumbnail: View {
    let url: URL
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RemoteImage(url: url)
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
