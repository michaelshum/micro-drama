import AVFoundation
import SwiftUI

struct EpisodePlayerView: View {
    let show: ShowDetail

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isEpisodeListPresented = false
    @State private var isSpeedSheetPresented = false
    @State private var likedEpisodes: Set<String> = []
    @State private var playbackRate: Float = 1.0

    var body: some View {
        GeometryReader { proxy in
            let pageHeight = proxy.size.height

            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                ZStack {
                    ForEach(visibleEpisodeIndices, id: \.self) { index in
                        if let episode = show.episodes[safe: index] {
                            EpisodePage(
                                showTitle: show.title,
                                episode: episode,
                                isActive: index == currentIndex,
                                isLiked: likedEpisodes.contains(episode.id),
                                playbackRate: playbackRate,
                                onLike: { toggleLike(for: episode) },
                                onEpisodesTapped: { isEpisodeListPresented = true },
                                onVideoFinished: moveToNextEpisode
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
                .padding(.top, 8)
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

    private func toggleLike(for episode: Episode) {
        if likedEpisodes.contains(episode.id) {
            likedEpisodes.remove(episode.id)
        } else {
            likedEpisodes.insert(episode.id)
        }
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

private struct EpisodePage: View {
    let showTitle: String
    let episode: Episode
    let isActive: Bool
    let isLiked: Bool
    let playbackRate: Float
    let onLike: () -> Void
    let onEpisodesTapped: () -> Void
    let onVideoFinished: () -> Void

    @State private var playbackProgress: Double = 0
    @State private var playbackDuration: Double = 0
    @State private var isScrubbing = false
    @State private var seekRequest: PlaybackSeekRequest?
    @State private var toggleRequest: PlaybackToggleRequest?

    var body: some View {
        ZStack {
            if episode.isLocked {
                LockedEpisodeView(episode: episode)
            } else if isActive {
                PlayerSurface(
                    url: episode.playbackUrl,
                    playbackRate: playbackRate,
                    progress: $playbackProgress,
                    duration: $playbackDuration,
                    isScrubbing: $isScrubbing,
                    seekRequest: seekRequest,
                    toggleRequest: toggleRequest,
                    onFinished: onVideoFinished
                )
            } else {
                EpisodeThumbnailView(episode: episode)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            if isActive && !episode.isLocked {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleRequest = PlaybackToggleRequest()
                    }
            }

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
                        isLiked: isLiked,
                        onLike: onLike,
                        onEpisodesTapped: onEpisodesTapped
                    )
                }

                if isActive && !episode.isLocked {
                    PlaybackProgressBar(progress: $playbackProgress, isScrubbing: $isScrubbing) { progress in
                        seekRequest = PlaybackSeekRequest(progress: progress)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 34)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
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
    let url: URL
    let playbackRate: Float
    @Binding var progress: Double
    @Binding var duration: Double
    @Binding var isScrubbing: Bool
    let seekRequest: PlaybackSeekRequest?
    let toggleRequest: PlaybackToggleRequest?
    let onFinished: () -> Void

    @State private var player: AVPlayer?
    @State private var endObserver: NSObjectProtocol?
    @State private var timeObserver: Any?
    @State private var isPaused = false

    var body: some View {
        Group {
            if let player {
                ZStack {
                    PlayerLayerView(player: player)
                        .ignoresSafeArea()

                    if isPaused {
                        Image(systemName: "play.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 74, height: 74)
                            .background(.black.opacity(0.34), in: Circle())
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .onAppear {
                    playIfNeeded()
                }
                .onDisappear {
                    player.pause()
                }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .task(id: url) {
            removeTimeObserver()
            removeEndObserver()

            let item = AVPlayerItem(url: url)
            let newPlayer = AVPlayer(playerItem: item)
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
            newPlayer.playImmediately(atRate: playbackRate)
        }
        .onChange(of: playbackRate) { _, _ in
            playIfNeeded()
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
            player = nil
            removeEndObserver()
        }
    }

    private func removeEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
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
        guard let player else { return }

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
        guard let player, !isPaused else { return }
        player.playImmediately(atRate: playbackRate)
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

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.videoGravity = .resizeAspect
        uiView.playerLayer.player = player
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

private struct LockedEpisodeView: View {
    let episode: Episode

    var body: some View {
        ZStack {
            AsyncImage(url: episode.thumbnailUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Color.black
                }
            }
            .ignoresSafeArea()

            Color.black.opacity(0.48).ignoresSafeArea()

            Text("Locked")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

private struct EpisodeThumbnailView: View {
    let episode: Episode

    var body: some View {
        AsyncImage(url: episode.thumbnailUrl) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            default:
                Color.black
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

private struct ActionRail: View {
    let isLiked: Bool
    let onLike: () -> Void
    let onEpisodesTapped: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Button(action: onLike) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(isLiked ? .red : .white)
            }
            .accessibilityLabel(isLiked ? "Unlike" : "Like")

            Button(action: onEpisodesTapped) {
                Image(systemName: "list.bullet")
            }
            .accessibilityLabel("Episodes")

            ShareLink(item: "https://micro-drama.onrender.com") {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Share")
        }
        .font(.system(size: 29, weight: .semibold))
        .foregroundStyle(.white)
        .shadow(radius: 5)
        .frame(width: 48)
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
