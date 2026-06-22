import SwiftUI

struct TasteOnboardingResult {
    let selectedLanguages: [TasteLanguage]
    let selectedAnchors: [TasteAnchor]
    let selectedDealbreakers: [TasteDealbreaker]
    let matchedShowID: String
    let alternateShowIDs: [String]
    var posterURLsByShowID: [String: URL] = [:]
}

enum TasteLanguage: String, CaseIterable, Identifiable, Codable {
    case english
    case spanish
    case chinese
    case korean
    case japanese
    case hindi
    case filipino
    case portuguese

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english:
            return "English"
        case .spanish:
            return "Spanish"
        case .chinese:
            return "Chinese"
        case .korean:
            return "Korean"
        case .japanese:
            return "Japanese"
        case .hindi:
            return "Hindi"
        case .filipino:
            return "Filipino"
        case .portuguese:
            return "Portuguese"
        }
    }
}

struct TasteAnchor: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let posterUrl: URL?
    let preferredShowIDs: [String]

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case posterUrl
        case preferredShowIDs = "preferredShowIds"
    }

    init(
        id: String,
        title: String,
        posterUrl: URL? = nil,
        preferredShowIDs: [String]
    ) {
        self.id = id
        self.title = title
        self.posterUrl = posterUrl
        self.preferredShowIDs = preferredShowIDs
    }

    static func == (lhs: TasteAnchor, rhs: TasteAnchor) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var colors: [Color] {
        switch id {
        case "loveIsland":
            return [Color(red: 1.0, green: 0.31, blue: 0.47), Color(red: 1.0, green: 0.67, blue: 0.29)]
        case "theBachelor":
            return [Color(red: 0.89, green: 0.08, blue: 0.24), Color(red: 0.34, green: 0.02, blue: 0.08)]
        case "desperateHousewives":
            return [Color(red: 0.72, green: 0.05, blue: 0.12), Color(red: 0.18, green: 0.02, blue: 0.06)]
        case "goneGirl":
            return [Color(red: 0.12, green: 0.15, blue: 0.2), Color(red: 0.38, green: 0.45, blue: 0.56)]
        case "crazyRichAsians":
            return [Color(red: 0.95, green: 0.71, blue: 0.29), Color(red: 0.06, green: 0.34, blue: 0.31)]
        case "fiftyShades":
            return [Color(red: 0.05, green: 0.05, blue: 0.07), Color(red: 0.38, green: 0.33, blue: 0.39)]
        case "prettyLittleLiars":
            return [Color(red: 0.49, green: 0.08, blue: 0.45), Color(red: 0.1, green: 0.08, blue: 0.18)]
        case "suits":
            return [Color(red: 0.04, green: 0.18, blue: 0.32), Color(red: 0.53, green: 0.61, blue: 0.69)]
        case "succession":
            return [Color(red: 0.1, green: 0.11, blue: 0.12), Color(red: 0.56, green: 0.48, blue: 0.36)]
        case "gameOfThrones":
            return [Color(red: 0.17, green: 0.22, blue: 0.29), Color(red: 0.55, green: 0.44, blue: 0.28)]
        case "beautyAndTheBeast":
            return [Color(red: 0.11, green: 0.13, blue: 0.38), Color(red: 0.8, green: 0.53, blue: 0.22)]
        case "bridgerton":
            return [Color(red: 0.54, green: 0.2, blue: 0.45), Color(red: 0.86, green: 0.62, blue: 0.76)]
        case "devilWearsPrada":
            return [Color(red: 0.72, green: 0.03, blue: 0.18), Color(red: 0.08, green: 0.08, blue: 0.1)]
        case "twilight":
            return [Color(red: 0.09, green: 0.14, blue: 0.2), Color(red: 0.24, green: 0.39, blue: 0.48)]
        default:
            return [
                Color(red: 0.12, green: 0.12, blue: 0.14),
                Color(red: 0.34, green: 0.34, blue: 0.38)
            ]
        }
    }
}

enum TasteDealbreaker: String, CaseIterable, Identifiable, Codable {
    case scary
    case cheating
    case fantasyWorlds
    case datingShows
    case mafia
    case violence

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scary:
            return "Scary"
        case .cheating:
            return "Cheating"
        case .fantasyWorlds:
            return "Fantasy or magic"
        case .datingShows:
            return "Dating shows"
        case .mafia:
            return "Mafia"
        case .violence:
            return "Violence"
        }
    }

    var emoji: String {
        switch self {
        case .scary:
            return "😱"
        case .cheating:
            return "💔"
        case .fantasyWorlds:
            return "🪄"
        case .datingShows:
            return "🌹"
        case .mafia:
            return "🕴️"
        case .violence:
            return "⚠️"
        }
    }

    var downrankedShowIDs: [String] {
        switch self {
        case .scary:
            return [
                "show_demo_screen_time",
                "show_demo_the_beast_queens_canvas"
            ]
        case .cheating:
            return [
                "show_demo_the_eye_of_betrayal",
                "show_demo_double_shelf_life_marks_greed",
                "show_demo_screen_time"
            ]
        case .fantasyWorlds:
            return [
                "show_demo_the_beast_queens_canvas"
            ]
        case .datingShows:
            return [
                "show_demo_fruit_love_island",
                "show_demo_candy_love_island"
            ]
        case .mafia:
            return [
                "show_demo_i_married_my_exs_mafia_boss"
            ]
        case .violence:
            return [
                "show_demo_i_married_my_exs_mafia_boss",
                "show_demo_the_beast_queens_canvas"
            ]
        }
    }
}

struct TasteProfile: Codable {
    let selectedLanguageIDs: [TasteLanguage.ID]
    let selectedAnchorIDs: [TasteAnchor.ID]
    let selectedDealbreakerIDs: [TasteDealbreaker.ID]
    let matchedShowID: String
    let alternateShowIDs: [String]
    let selectedAt: Date
}

final class TasteOnboardingStore {
    static let shared = TasteOnboardingStore()

    private let defaults: UserDefaults
    private let profileKey = "tasteOnboardingProfile"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var profile: TasteProfile? {
        guard let data = defaults.data(forKey: profileKey) else { return nil }
        return try? JSONDecoder().decode(TasteProfile.self, from: data)
    }

    var hasCompleted: Bool {
        profile != nil
    }

    func save(_ result: TasteOnboardingResult, selectedAt: Date = Date()) {
        let profile = TasteProfile(
            selectedLanguageIDs: result.selectedLanguages.map(\.id),
            selectedAnchorIDs: result.selectedAnchors.map(\.id),
            selectedDealbreakerIDs: result.selectedDealbreakers.map(\.id),
            matchedShowID: result.matchedShowID,
            alternateShowIDs: result.alternateShowIDs,
            selectedAt: selectedAt
        )

        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: profileKey)
    }
}

enum TasteShowMatch {
    static let candidateShowIDs = [
        "show_demo_candy_love_island",
        "show_demo_fruit_love_island",
        "show_demo_double_shelf_life_marks_greed",
        "show_demo_one_night_in_fruitopia",
        "show_demo_the_eye_of_betrayal",
        "show_demo_i_married_my_exs_mafia_boss",
        "show_demo_secrets_in_the_juice",
        "show_demo_screen_time",
        "show_demo_the_beast_queens_canvas"
    ]

    static func title(for showID: String) -> String {
        switch showID {
        case "show_demo_candy_love_island":
            return "Candy Love Island"
        case "show_demo_fruit_love_island":
            return "Fruit Love Island"
        case "show_demo_double_shelf_life_marks_greed":
            return "Double Shelf Life: Mark's Greed"
        case "show_demo_one_night_in_fruitopia":
            return "One Night in Fruitopia"
        case "show_demo_the_eye_of_betrayal":
            return "The Eye of Betrayal"
        case "show_demo_i_married_my_exs_mafia_boss":
            return "I Married My Ex's Mafia Boss"
        case "show_demo_secrets_in_the_juice":
            return "Secrets in the Juice"
        case "show_demo_screen_time":
            return "Screen Time"
        case "show_demo_the_beast_queens_canvas":
            return "The Beast Queen's Canvas"
        default:
            return "your first drama"
        }
    }

    static func posterURL(for showID: String, posterURLsByShowID: [String: URL] = [:]) -> URL {
        if let posterURL = posterURLsByShowID[showID] {
            return posterURL
        }

        return APIClient.shared.url(for: "/shows/\(showID)/poster")
    }

    static func fetchSignedPosterURLsByShowID() async -> [String: URL] {
        do {
            let shows = try await APIClient.shared.fetchShows()
            return Dictionary(uniqueKeysWithValues: shows.map { ($0.id, $0.posterUrl) })
        } catch {
            return [:]
        }
    }

    static func manualQualityLabel(for showID: String) -> Int {
        switch showID {
        case "show_demo_candy_love_island":
            return 4
        case "show_demo_fruit_love_island":
            return 3
        case "show_demo_double_shelf_life_marks_greed":
            return 3
        case "show_demo_one_night_in_fruitopia":
            return 2
        case "show_demo_the_eye_of_betrayal":
            return 3
        case "show_demo_i_married_my_exs_mafia_boss":
            return 4
        case "show_demo_secrets_in_the_juice":
            return 3
        case "show_demo_screen_time":
            return 4
        case "show_demo_the_beast_queens_canvas":
            return 3
        default:
            return 3
        }
    }

    static func manualQualityScoreAdjustment(for showID: String) -> Int {
        manualQualityLabel(for: showID) - 3
    }
}

private enum TasteOnboardingStep {
    case languages
    case anchors
    case dealbreakers
    case selecting
    case result(TasteOnboardingResult)
}

struct TasteOnboardingView: View {
    let onComplete: (TasteOnboardingResult) -> Void

    @State private var step: TasteOnboardingStep = .languages
    @State private var selectedLanguages: Set<TasteLanguage> = [.english]
    @State private var availableAnchors: [TasteAnchor] = []
    @State private var selectedAnchors: Set<TasteAnchor> = []
    @State private var selectedDealbreakers: Set<TasteDealbreaker> = []
    @State private var isLoadingAnchors = false
    @State private var didFailToLoadAnchors = false

    private let twoColumnGrid = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private let posterGrid = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch step {
            case .languages:
                languageSelectionView
                    .transition(.opacity)
            case .anchors:
                anchorSelectionView
                    .transition(.opacity)
            case .dealbreakers:
                dealbreakerSelectionView
                    .transition(.opacity)
            case .selecting:
                SelectingShowView()
                    .transition(.opacity)
            case .result(let result):
                TasteMatchResultView(result: result, onStart: onComplete)
                    .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            OnboardingLogoBar()
        }
    }

    private var languageSelectionView: some View {
        OnboardingStepScaffold(
            title: "Which languages do you like to watch shows and movies in?",
            subtitle: "We'll find shows in these languages.",
            buttonTitle: "Continue",
            isButtonDisabled: selectedLanguages.isEmpty,
            onContinue: { move(to: .anchors) }
        ) {
            LazyVGrid(columns: twoColumnGrid, spacing: 12) {
                ForEach(TasteLanguage.allCases) { language in
                    PillChoiceButton(
                        title: language.title,
                        isSelected: selectedLanguages.contains(language)
                    ) {
                        toggle(language)
                    }
                }
            }
        }
    }

    private var anchorSelectionView: some View {
        OnboardingStepScaffold(
            title: "What shows or movies do you like?",
            subtitle: "This helps us find new \(appDisplayName) shows you'll love.",
            buttonTitle: "Continue",
            isButtonDisabled: selectedAnchors.isEmpty,
            onContinue: { move(to: .dealbreakers) }
        ) {
            if isLoadingAnchors {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else if didFailToLoadAnchors && availableAnchors.isEmpty {
                Text("Unable to load choices. Check your connection and try again.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
                    .multilineTextAlignment(.center)
            } else {
                LazyVGrid(columns: posterGrid, spacing: 10) {
                    ForEach(availableAnchors) { anchor in
                        TasteAnchorCard(
                            anchor: anchor,
                            isSelected: selectedAnchors.contains(anchor)
                        ) {
                            toggle(anchor)
                        }
                    }
                }
            }
        }
        .task {
            await loadTasteAnchorsIfNeeded()
        }
    }

    private var appDisplayName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "Onda"
    }

    private var dealbreakerSelectionView: some View {
        OnboardingStepScaffold(
            title: "Anything you don't like?",
            subtitle: "We’ll recommend you less of these.",
            buttonTitle: selectedDealbreakers.isEmpty ? "Skip" : "Continue",
            isButtonDisabled: false,
            onContinue: showSelectingStep
        ) {
            LazyVGrid(columns: twoColumnGrid, spacing: 12) {
                ForEach(TasteDealbreaker.allCases) { dealbreaker in
                    TasteDealbreakerCard(
                        dealbreaker: dealbreaker,
                        isSelected: selectedDealbreakers.contains(dealbreaker)
                    ) {
                        toggle(dealbreaker)
                    }
                }
            }
        }
    }

    private func toggle(_ language: TasteLanguage) {
        if selectedLanguages.contains(language) {
            selectedLanguages.remove(language)
        } else {
            selectedLanguages.insert(language)
        }
    }

    private func toggle(_ anchor: TasteAnchor) {
        if selectedAnchors.contains(anchor) {
            selectedAnchors.remove(anchor)
        } else {
            selectedAnchors.insert(anchor)
        }
    }

    private func toggle(_ dealbreaker: TasteDealbreaker) {
        if selectedDealbreakers.contains(dealbreaker) {
            selectedDealbreakers.remove(dealbreaker)
        } else {
            selectedDealbreakers.insert(dealbreaker)
        }
    }

    private func move(to nextStep: TasteOnboardingStep) {
        withAnimation(.easeInOut(duration: 0.2)) {
            step = nextStep
        }
    }

    private func loadTasteAnchorsIfNeeded() async {
        guard availableAnchors.isEmpty, !isLoadingAnchors else { return }

        await MainActor.run {
            isLoadingAnchors = true
            didFailToLoadAnchors = false
        }
        do {
            let remoteAnchors = try await APIClient.shared.fetchTasteAnchors()
            guard !remoteAnchors.isEmpty else {
                await MainActor.run {
                    isLoadingAnchors = false
                    didFailToLoadAnchors = true
                }
                return
            }
            await MainActor.run {
                availableAnchors = remoteAnchors
                selectedAnchors = Set(selectedAnchors.compactMap { selectedAnchor in
                    remoteAnchors.first { $0.id == selectedAnchor.id } ?? selectedAnchor
                })
                isLoadingAnchors = false
            }
        } catch {
            await MainActor.run {
                isLoadingAnchors = false
                didFailToLoadAnchors = true
            }
        }
    }

    private func showSelectingStep() {
        move(to: .selecting)
        let result = buildResult()

        Task {
            async let minimumLoadingTime: Void = sleepForMinimumLoadingTime()
            let posterURLsByShowID = await TasteShowMatch.fetchSignedPosterURLsByShowID()
            var hydratedResult = result
            hydratedResult.posterURLsByShowID = posterURLsByShowID
            let posterURLs = ([hydratedResult.matchedShowID] + hydratedResult.alternateShowIDs)
                .map { TasteShowMatch.posterURL(for: $0, posterURLsByShowID: posterURLsByShowID) }

            async let prefetch: Void = prefetchWithTimeout(urls: posterURLs)
            await minimumLoadingTime
            await prefetch

            guard case .selecting = step else { return }
            move(to: .result(hydratedResult))
        }
    }

    private func sleepForMinimumLoadingTime() async {
        try? await Task.sleep(nanoseconds: 1_250_000_000)
    }

    private func prefetchWithTimeout(urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await RemoteImage.prefetch(urls: urls)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }

            await group.next()
            group.cancelAll()
        }
    }

    private func buildResult() -> TasteOnboardingResult {
        let languages = TasteLanguage.allCases.filter { selectedLanguages.contains($0) }
        let anchors = availableAnchors.filter { selectedAnchors.contains($0) }
        let dealbreakers = TasteDealbreaker.allCases.filter { selectedDealbreakers.contains($0) }
        let showIDs = rankedShowIDs(for: anchors, dealbreakers: dealbreakers)
        let matchedShowID = showIDs.first ?? "show_demo_the_eye_of_betrayal"

        return TasteOnboardingResult(
            selectedLanguages: languages,
            selectedAnchors: anchors,
            selectedDealbreakers: dealbreakers,
            matchedShowID: matchedShowID,
            alternateShowIDs: Array(showIDs.filter { $0 != matchedShowID }.prefix(2))
        )
    }
}

private struct OnboardingLogoBar: View {
    var body: some View {
        HStack {
            Spacer(minLength: 0)

            Image("OndaLogoMark")
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)
                .accessibilityLabel("Onda")

            Spacer(minLength: 0)
        }
        .frame(height: 72)
        .background(Color.black)
    }
}

private struct OnboardingStepScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let isButtonDisabled: Bool
    let onContinue: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }

                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: onContinue) {
                Text(buttonTitle)
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        isButtonDisabled ? Color.white.opacity(0.36) : Color.white,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isButtonDisabled)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(Color.black)
        }
    }
}

private struct PillChoiceButton: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(.white.opacity(isSelected ? 0.22 : 0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.14), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct TasteDealbreakerCard: View {
    let dealbreaker: TasteDealbreaker
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 12) {
                    Text(dealbreaker.emoji)
                        .font(.system(size: 38))
                        .accessibilityHidden(true)

                    Text(dealbreaker.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 116)
                .background(.white.opacity(isSelected ? 0.18 : 0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? Color.white : Color.white.opacity(0.14), lineWidth: isSelected ? 2 : 1)
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dealbreaker.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SelectingShowView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.15)

            Text("Selecting a show just for you...")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct TasteMatchResultView: View {
    let result: TasteOnboardingResult
    let onStart: (TasteOnboardingResult) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Button {
                    onStart(result)
                } label: {
                    FeaturedTasteMatchCard(
                        showID: result.matchedShowID,
                        posterURL: TasteShowMatch.posterURL(
                            for: result.matchedShowID,
                            posterURLsByShowID: result.posterURLsByShowID
                        ),
                        reason: matchReason
                    )
                }
                .buttonStyle(.plain)

                Button {
                    onStart(result)
                } label: {
                    Label("Start Episode 1", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                if !result.alternateShowIDs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Other Shows for You")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(result.alternateShowIDs, id: \.self) { showID in
                                    AlternateTasteMatchPoster(
                                        showID: showID,
                                        posterURL: TasteShowMatch.posterURL(
                                            for: showID,
                                            posterURLsByShowID: result.posterURLsByShowID
                                        )
                                    ) {
                                        onStart(result.replacingMatchedShow(with: showID))
                                    }
                                }
                            }
                            .padding(.trailing, 2)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 28)
            .padding(.bottom, 28)
        }
    }

    private var matchReason: String {
        let relevantAnchor = result.selectedAnchors
            .filter { $0.preferredShowIDs.contains(result.matchedShowID) }
            .sorted { first, second in
                let firstRank = first.preferredShowIDs.firstIndex(of: result.matchedShowID) ?? Int.max
                let secondRank = second.preferredShowIDs.firstIndex(of: result.matchedShowID) ?? Int.max
                if firstRank != secondRank {
                    return firstRank < secondRank
                }

                let firstOrder = result.selectedAnchors.firstIndex(of: first) ?? Int.max
                let secondOrder = result.selectedAnchors.firstIndex(of: second) ?? Int.max
                return firstOrder < secondOrder
            }
            .first

        guard let relevantAnchor else {
            return "Picked for you based on your taste quiz."
        }

        return "Picked because you liked \(relevantAnchor.title)."
    }
}

private struct FeaturedTasteMatchCard: View {
    let showID: String
    let posterURL: URL
    let reason: String

    var body: some View {
        VStack(spacing: 14) {
            RemoteImage(url: posterURL)
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .frame(maxWidth: 292)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 18)

            Text(reason)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.74))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 292)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(TasteShowMatch.title(for: showID))
    }
}

private struct AlternateTasteMatchPoster: View {
    let showID: String
    let posterURL: URL
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            RemoteImage(url: posterURL)
                .frame(width: 96, height: 134)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TasteShowMatch.title(for: showID))
    }
}

private extension TasteOnboardingResult {
    func replacingMatchedShow(with showID: String) -> TasteOnboardingResult {
        TasteOnboardingResult(
            selectedLanguages: selectedLanguages,
            selectedAnchors: selectedAnchors,
            selectedDealbreakers: selectedDealbreakers,
            matchedShowID: showID,
            alternateShowIDs: alternateShowIDs.filter { $0 != showID },
            posterURLsByShowID: posterURLsByShowID
        )
    }
}

private extension TasteOnboardingView {
    func rankedShowIDs(for anchors: [TasteAnchor], dealbreakers: [TasteDealbreaker]) -> [String] {
        var scores: [String: Int] = [:]
        var firstSeenOrder: [String: Int] = [:]
        var nextOrder = 0

        func includeShow(_ showID: String) {
            guard firstSeenOrder[showID] == nil else { return }
            firstSeenOrder[showID] = nextOrder
            nextOrder += 1
            scores[showID, default: 0] += TasteShowMatch.manualQualityScoreAdjustment(for: showID)
        }

        for showID in TasteShowMatch.candidateShowIDs {
            includeShow(showID)
            scores[showID, default: 0] += 1
        }

        for anchor in anchors {
            for (index, showID) in anchor.preferredShowIDs.enumerated() {
                includeShow(showID)
                scores[showID, default: 0] += quizMatchPoints(forRank: index)
            }
        }

        for dealbreaker in dealbreakers {
            for showID in dealbreaker.downrankedShowIDs {
                includeShow(showID)
                scores[showID, default: 0] -= 4
            }
        }

        return scores.keys.sorted { first, second in
            let firstScore = scores[first, default: 0]
            let secondScore = scores[second, default: 0]
            if firstScore != secondScore {
                return firstScore > secondScore
            }

            let firstQuality = TasteShowMatch.manualQualityLabel(for: first)
            let secondQuality = TasteShowMatch.manualQualityLabel(for: second)
            if firstQuality != secondQuality {
                return firstQuality > secondQuality
            }

            return firstSeenOrder[first, default: Int.max] < firstSeenOrder[second, default: Int.max]
        }
    }

    func quizMatchPoints(forRank rank: Int) -> Int {
        max(4, 6 - rank)
    }
}

private struct TasteAnchorCard: View {
    let anchor: TasteAnchor
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Group {
                    if let posterUrl = anchor.posterUrl {
                        RemoteImage(url: posterUrl)
                            .brightness(0.06)
                    } else {
                        LinearGradient(
                            colors: anchor.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay(alignment: .bottomLeading) {
                            Text(anchor.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(3)
                                .minimumScaleFactor(0.82)
                                .multilineTextAlignment(.leading)
                                .padding(10)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay {
                    if isSelected {
                        Color.black.opacity(0.42)
                    }
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.14), lineWidth: isSelected ? 3 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(anchor.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
