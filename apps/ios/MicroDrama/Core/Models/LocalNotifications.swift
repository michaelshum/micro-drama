import Combine
import Foundation
import UserNotifications

struct ProfileNotification: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let message: String
    let sentAt: Date
    let systemImage: String
    let thumbnailUrl: URL?
    let showID: String?
    let episodeID: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        message: String,
        sentAt: Date,
        systemImage: String,
        thumbnailUrl: URL? = nil,
        showID: String? = nil,
        episodeID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.sentAt = sentAt
        self.systemImage = systemImage
        self.thumbnailUrl = thumbnailUrl
        self.showID = showID
        self.episodeID = episodeID
    }
}

@MainActor
final class NotificationInboxStore: ObservableObject {
    static let shared = NotificationInboxStore()

    @Published private(set) var notifications: [ProfileNotification]

    private let defaults: UserDefaults
    private let storageKey = "profileNotifications"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        notifications = Self.loadNotifications(from: defaults, key: storageKey)
    }

    var sortedNotifications: [ProfileNotification] {
        notifications.sorted { $0.sentAt > $1.sentAt }
    }

    func upsert(_ notification: ProfileNotification) {
        notifications.removeAll { $0.id == notification.id }
        notifications.insert(notification, at: 0)
        persist()
    }

    func remove(notificationIDs: Set<String>) {
        guard !notificationIDs.isEmpty else { return }
        notifications.removeAll { notificationIDs.contains($0.id) }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(notifications) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func loadNotifications(from defaults: UserDefaults, key: String) -> [ProfileNotification] {
        guard let data = defaults.data(forKey: key),
              let notifications = try? JSONDecoder().decode([ProfileNotification].self, from: data) else {
            return []
        }

        return notifications.sorted { $0.sentAt > $1.sentAt }
    }
}

struct LocalNotificationRoute: Equatable {
    let notificationID: String?
    let showID: String
    let episodeID: String?

    init?(userInfo: [AnyHashable: Any]) {
        guard userInfo[Self.routeKey] as? String == Self.showRoute,
              let showID = userInfo[Self.showIDKey] as? String else {
            return nil
        }

        notificationID = userInfo[Self.notificationIDKey] as? String
        self.showID = showID
        episodeID = userInfo[Self.episodeIDKey] as? String
    }

    init(notificationID: String, showID: String, episodeID: String?) {
        self.notificationID = notificationID
        self.showID = showID
        self.episodeID = episodeID
    }

    var userInfo: [String: String] {
        var userInfo = [
            Self.routeKey: Self.showRoute,
            Self.notificationIDKey: notificationID ?? "",
            Self.showIDKey: showID
        ]

        if let episodeID {
            userInfo[Self.episodeIDKey] = episodeID
        }

        return userInfo
    }

    private static let routeKey = "route"
    private static let showRoute = "show"
    private static let notificationIDKey = "notificationID"
    private static let showIDKey = "showID"
    private static let episodeIDKey = "episodeID"
}

@MainActor
final class LocalNotificationScheduler {
    static let shared = LocalNotificationScheduler()

    private let notificationCenter: UNUserNotificationCenter
    private let inboxStore: NotificationInboxStore
    private let followReminderDelay: TimeInterval = 20 * 60 * 60
    private let continueWatchingDelay: TimeInterval = 24 * 60 * 60

    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        inboxStore: NotificationInboxStore? = nil
    ) {
        self.notificationCenter = notificationCenter
        self.inboxStore = inboxStore ?? .shared
    }

    func scheduleFollowedShowReminder(show: ShowDetail, episode: Episode) async {
        await scheduleReminder(
            notificationID: "followed.\(show.id)",
            title: show.title,
            message: "Episode \(episode.episodeNumber) is ready when you are.",
            systemImage: "bell.fill",
            show: show,
            episode: episode,
            delay: followReminderDelay
        )
    }

    func scheduleContinueWatchingReminder(show: ShowDetail, episode: Episode) async {
        await scheduleReminder(
            notificationID: "continue.\(show.id)",
            title: "Keep watching \(show.title)",
            message: "Episode \(episode.episodeNumber) is waiting.",
            systemImage: "play.rectangle.fill",
            show: show,
            episode: episode,
            delay: continueWatchingDelay
        )
    }

    func cancelReminders(for showID: String) {
        let notificationIDs: Set<String> = [
            "followed.\(showID)",
            "continue.\(showID)"
        ]
        debugLog("cancel showID=\(showID) ids=\(notificationIDs.sorted().joined(separator: ","))")
        notificationCenter.removePendingNotificationRequests(withIdentifiers: Array(notificationIDs))
        notificationCenter.removeDeliveredNotifications(withIdentifiers: Array(notificationIDs))
        inboxStore.remove(notificationIDs: notificationIDs)
    }

    private func scheduleReminder(
        notificationID: String,
        title: String,
        message: String,
        systemImage: String,
        show: ShowDetail,
        episode: Episode,
        delay: TimeInterval
    ) async {
        let settings = await notificationCenter.notificationSettings()
        debugLog("attempt id=\(notificationID) status=\(settings.authorizationStatus.rawValue) delay=\(Int(delay))")
        guard settings.authorizationStatus.canScheduleLocalNotifications else {
            debugLog("skip id=\(notificationID) status=\(settings.authorizationStatus.rawValue)")
            return
        }

        let scheduledAt = Date().addingTimeInterval(delay)
        let route = LocalNotificationRoute(notificationID: notificationID, showID: show.id, episodeID: episode.id)
        let notification = ProfileNotification(
            id: notificationID,
            title: title,
            message: message,
            sentAt: scheduledAt,
            systemImage: systemImage,
            thumbnailUrl: episode.thumbnailUrl,
            showID: show.id,
            episodeID: episode.id
        )

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        content.userInfo = route.userInfo

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            inboxStore.upsert(notification)
            debugLog("scheduled id=\(notificationID) title=\"\(title)\" body=\"\(message)\"")
        } catch {
            debugLog("failed id=\(notificationID) error=\(error.localizedDescription)")
            return
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[LocalNotificationScheduler] \(message)")
        #endif
    }
}

final class LocalNotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = LocalNotificationRouter()

    @Published private(set) var pendingRoute: LocalNotificationRoute?

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    @MainActor
    func consumePendingRoute() -> LocalNotificationRoute? {
        defer { pendingRoute = nil }
        return pendingRoute
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let route = LocalNotificationRoute(userInfo: response.notification.request.content.userInfo) else {
            return
        }

        await MainActor.run {
            pendingRoute = route
        }
    }
}

private extension UNAuthorizationStatus {
    var canScheduleLocalNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }
}
