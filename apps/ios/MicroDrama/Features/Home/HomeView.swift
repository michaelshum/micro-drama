import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var shows: [Show] = []
    @Published var selectedShowDetail: ShowDetail?
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
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
}

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.shows.isEmpty {
                    ProgressView()
                } else {
                    ScrollView {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 10) {
                                ForEach(viewModel.shows) { show in
                                    Button {
                                        Task {
                                            await viewModel.open(show)
                                        }
                                    } label: {
                                        ShowPosterCard(show: show)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    .refreshable {
                        await viewModel.loadShows()
                    }
                }
            }
            .navigationTitle("Shows")
            .task {
                await viewModel.loadShows()
            }
            .alert("Unable to load", isPresented: errorAlertBinding) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .fullScreenCover(item: $viewModel.selectedShowDetail) { showDetail in
                EpisodePlayerView(show: showDetail)
            }
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                viewModel.errorMessage = nil
            }
        }
    }
}

private struct ShowPosterCard: View {
    let show: Show

    private let posterWidth: CGFloat = 108
    private let posterHeight: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: show.posterUrl) { phase in
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
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                @unknown default:
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: posterWidth, height: posterHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(show.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: posterWidth, alignment: .leading)
        }
        .frame(width: posterWidth, alignment: .leading)
    }
}
