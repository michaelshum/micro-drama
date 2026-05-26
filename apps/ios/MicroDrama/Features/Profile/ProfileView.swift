import SwiftUI

@MainActor
final class MockNotificationStore: ObservableObject {
    static let shared = MockNotificationStore()

    @Published var notificationsEnabled = true
    @Published private(set) var notifications: [ProfileNotification] = [
        ProfileNotification(
            title: "New episodes waiting",
            message: "Love in the Clouds has fresh episodes ready to watch.",
            sentAt: Calendar.current.date(byAdding: .hour, value: -5, to: Date()) ?? Date(),
            systemImage: "play.rectangle.fill"
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

    func enableNotifications() {
        notificationsEnabled = true
    }
}

struct ProfileNotification: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let message: String
    let sentAt: Date
    let systemImage: String
}

struct ProfileView: View {
    @StateObject private var notificationStore = MockNotificationStore.shared
    @StateObject private var episodeOpener = EpisodeOpeningViewModel()
    @ObservedObject private var myListStore = MyListEpisodeStore.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        NotificationsTrayView(store: notificationStore)
                    } label: {
                        NotificationHeaderRow(
                            notificationsEnabled: notificationStore.notificationsEnabled,
                            notificationCount: notificationStore.notifications.count
                        )
                    }
                    .listRowSeparator(.hidden)

                    if notificationStore.notificationsEnabled,
                       let latestNotification = notificationStore.sortedNotifications.first {
                        LatestNotificationPreviewRow(notification: latestNotification)
                            .listRowSeparator(.hidden)
                    }
                }

                Section {
                    if myListStore.savedEpisodes.isEmpty {
                        EmptyMyListRow()
                    } else {
                        NavigationLink {
                            MyListView()
                        } label: {
                            MySavedListHeaderRow(savedCount: myListStore.savedEpisodes.count)
                        }
                        .listRowSeparator(.hidden)

                        MySavedListShelf(
                            savedEpisodes: myListStore.savedEpisodes,
                            onSelect: { savedEpisode in
                                Task {
                                    await episodeOpener.open(savedEpisode)
                                }
                            }
                        )
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
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
                    onEpisodeChanged: { episode in
                        episodeOpener.recordLastWatchedEpisode(episode, for: showDetail)
                    }
                )
            }
        }
    }
}

private struct MySavedListHeaderRow: View {
    let savedCount: Int

    var body: some View {
        ProfileSectionHeaderRow(
            systemImage: "bookmark.fill",
            title: "My Saved List",
            trailingText: "\(savedCount) saved"
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

private struct EmptyMyListRow: View {
    var body: some View {
        HStack(spacing: 12) {
            ProfileRowIcon(
                systemImage: "bookmark.fill",
                width: 32
            )

            VStack(alignment: .leading, spacing: 3) {
                Text("My Saved List")
                    .font(ProfileTypography.sectionTitle)
                    .foregroundStyle(.primary)

                Text("Save episodes to watch next")
                    .font(ProfileTypography.rowSubtitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }
}

private struct MySavedListShelf: View {
    let savedEpisodes: [SavedEpisode]
    let onSelect: (SavedEpisode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(savedEpisodes) { savedEpisode in
                        Button {
                            onSelect(savedEpisode)
                        } label: {
                            SavedEpisodeShelfCard(savedEpisode: savedEpisode)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct SavedEpisodeShelfCard: View {
    let savedEpisode: SavedEpisode

    private let cardWidth: CGFloat = 104

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PosterThumbnail(url: savedEpisode.thumbnailUrl, width: cardWidth, height: 146)

            Text(savedEpisode.showTitle)
                .font(ProfileTypography.shelfTitle)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: cardWidth, alignment: .leading)

            Text("Episode \(savedEpisode.episodeNumber)")
                .font(ProfileTypography.rowMetadata)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: cardWidth, alignment: .leading)
        }
        .frame(width: cardWidth, alignment: .leading)
    }
}

private struct LatestNotificationPreviewRow: View {
    let notification: ProfileNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NotificationIconTile(systemImage: notification.systemImage, size: 44)

            VStack(alignment: .leading, spacing: 6) {
                Text(notification.title)
                    .font(ProfileTypography.previewTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(notification.message)
                    .font(ProfileTypography.rowSubtitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(notification.sentAt.formatted(.relative(presentation: .named)))
                    .font(ProfileTypography.rowMetadata)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct NotificationsTrayView: View {
    @ObservedObject var store: MockNotificationStore

    var body: some View {
        List {
            if store.notificationsEnabled {
                if store.notifications.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Notifications Yet",
                            systemImage: "bell",
                            description: Text("New episode drops, saved-show reminders, and recommendations will appear here.")
                        )
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(store.sortedNotifications) { notification in
                            NotificationDetailRow(notification: notification)
                        }
                    }
                }
            } else {
                Section {
                    VStack(spacing: 14) {
                        ContentUnavailableView(
                            "Notifications Are Off",
                            systemImage: "bell.slash",
                            description: Text("Enable notifications to see episode drops, saved-show reminders, and recommendations.")
                        )

                        Button("Enable Notifications") {
                            store.enableNotifications()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NotificationDetailRow: View {
    let notification: ProfileNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NotificationIconTile(systemImage: notification.systemImage, size: 44)

            VStack(alignment: .leading, spacing: 6) {
                Text(notification.title)
                    .font(ProfileTypography.rowTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(notification.message)
                    .font(ProfileTypography.rowSubtitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Text(notification.sentAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(ProfileTypography.rowMetadata)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct MyListView: View {
    @ObservedObject private var myListStore = MyListEpisodeStore.shared
    @StateObject private var viewModel = EpisodeOpeningViewModel()

    var body: some View {
        List {
            if myListStore.savedEpisodes.isEmpty {
                Section {
                    ContentUnavailableView(
                        "My Saved List Is Empty",
                        systemImage: "bookmark",
                        description: Text("Saved episodes from the player will appear here with show and episode details.")
                    )
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(myListStore.savedEpisodes) { savedEpisode in
                        Button {
                            Task {
                                await viewModel.open(savedEpisode)
                            }
                        } label: {
                            SavedEpisodeRow(savedEpisode: savedEpisode)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                myListStore.remove(episodeID: savedEpisode.episodeID)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("My Saved List")
        .navigationBarTitleDisplayMode(.inline)
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
                onEpisodeChanged: { episode in
                    viewModel.recordLastWatchedEpisode(episode, for: showDetail)
                }
            )
        }
    }
}

private struct SavedEpisodeRow: View {
    let savedEpisode: SavedEpisode

    var body: some View {
        HStack(spacing: 12) {
            PosterThumbnail(url: savedEpisode.thumbnailUrl, width: 84, height: 112)

            VStack(alignment: .leading, spacing: 6) {
                Text(savedEpisode.showTitle)
                    .font(ProfileTypography.rowTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("Episode \(savedEpisode.episodeNumber)")
                    .font(ProfileTypography.rowSubtitle)
                    .foregroundStyle(.secondary)

                Text("Saved \(savedEpisode.savedAt.formatted(.relative(presentation: .named)))")
                    .font(ProfileTypography.rowMetadata)
                    .foregroundStyle(.tertiary)
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
            }
        }
        .listStyle(.plain)
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
                initialEpisodeID: viewModel.lastWatchedEpisodeID(for: showDetail.id),
                onEpisodeChanged: { episode in
                    viewModel.recordLastWatchedEpisode(episode, for: showDetail)
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
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(show.genre)
                    .font(ProfileTypography.rowSubtitle)
                    .foregroundStyle(.secondary)

                Text("\(show.episodeCount) episodes")
                    .font(ProfileTypography.rowMetadata)
                    .foregroundStyle(.tertiary)
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

    func open(_ savedEpisode: SavedEpisode) async {
        isLoading = true
        defer { isLoading = false }

        do {
            initialEpisodeID = savedEpisode.episodeID
            selectedShowDetail = try await apiClient.fetchShow(id: savedEpisode.showID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recordLastWatchedEpisode(_ episode: Episode, for show: ShowDetail) {
        progressStore.setLastWatchedEpisodeID(episode.id, for: show.id)
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

    func lastWatchedEpisodeID(for showID: String) -> String? {
        progressStore.lastWatchedEpisodeID(for: showID)
    }

    func recordLastWatchedEpisode(_ episode: Episode, for show: ShowDetail) {
        progressStore.setLastWatchedEpisodeID(episode.id, for: show.id)
    }
}

private enum ProfileTypography {
    static let sectionTitle = Font.title3.weight(.semibold)
    static let rowTitle = Font.body.weight(.semibold)
    static let previewTitle = Font.subheadline.weight(.semibold)
    static let rowSubtitle = Font.subheadline
    static let rowMetadata = Font.caption
    static let shelfTitle = Font.caption.weight(.semibold)
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
                .foregroundStyle(.primary)

            Spacer()

            Text(trailingText)
                .font(ProfileTypography.rowSubtitle)
                .foregroundStyle(.secondary)
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
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: .center)
    }
}

private struct NotificationIconTile: View {
    let systemImage: String
    let size: CGFloat

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PosterThumbnail: View {
    let url: URL
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ZStack {
                    Rectangle().fill(.quaternary)
                    ProgressView()
                }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                ZStack {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            @unknown default:
                Rectangle().fill(.quaternary)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
