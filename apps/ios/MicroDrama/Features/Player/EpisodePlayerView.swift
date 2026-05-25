import AVFoundation
import SwiftUI

struct EpisodePlayerView: View {
    let show: ShowDetail

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var likedEpisodes: Set<String> = []

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let episode = show.episodes[safe: currentIndex] {
                EpisodePage(
                    showTitle: show.title,
                    episode: episode,
                    isLiked: likedEpisodes.contains(episode.id),
                    onLike: { toggleLike(for: episode) }
                )
                .id(episode.id)
                .transition(.opacity)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.35), in: Circle())
            }
            .padding(.leading, 14)
            .padding(.top, 8)
        }
        .gesture(
            DragGesture(minimumDistance: 32)
                .onEnded { value in
                    handleSwipe(value.translation.height)
                }
        )
        .statusBarHidden()
    }

    private func toggleLike(for episode: Episode) {
        if likedEpisodes.contains(episode.id) {
            likedEpisodes.remove(episode.id)
        } else {
            likedEpisodes.insert(episode.id)
        }
    }

    private func handleSwipe(_ verticalTranslation: CGFloat) {
        let threshold: CGFloat = 72

        if verticalTranslation > threshold {
            moveToPreviousEpisode()
        } else if verticalTranslation < -threshold {
            moveToNextEpisode()
        }
    }

    private func moveToNextEpisode() {
        guard currentIndex < show.episodes.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex += 1
        }
    }

    private func moveToPreviousEpisode() {
        guard currentIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex -= 1
        }
    }
}

private struct EpisodePage: View {
    let showTitle: String
    let episode: Episode
    let isLiked: Bool
    let onLike: () -> Void

    var body: some View {
        ZStack {
            if episode.isLocked {
                LockedEpisodeView(episode: episode)
            } else {
                PlayerSurface(url: episode.playbackUrl)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()

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

                ActionRail(isLiked: isLiked, onLike: onLike)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 34)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
    }
}

private struct PlayerSurface: View {
    let url: URL

    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                PlayerLayerView(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        player.play()
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
            let newPlayer = AVPlayer(url: url)
            player = newPlayer
            newPlayer.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
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

private struct ActionRail: View {
    let isLiked: Bool
    let onLike: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Button(action: onLike) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(isLiked ? .red : .white)
            }
            .accessibilityLabel(isLiked ? "Unlike" : "Like")

            Button {} label: {
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

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
