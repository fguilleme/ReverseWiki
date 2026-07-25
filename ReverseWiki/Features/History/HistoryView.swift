import Observation
import SwiftUI

@MainActor
@Observable
final class HistoryViewModel {
    var entries: [HistoryEntry] = []
    var errorMessage: String?
    private let cache: FactCaching

    init(cache: FactCaching) {
        self.cache = cache
    }

    func load() async {
        do {
            entries = try await cache.history()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(at offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            entries.indices.contains(index) ? entries[index].id : nil
        }
        entries.remove(atOffsets: offsets)

        Task {
            do {
                try await cache.deleteHistoryEntries(ids: ids)
            } catch {
                errorMessage = error.localizedDescription
                await load()
            }
        }
    }
}

struct HistoryView: View {
    @State var viewModel: HistoryViewModel

    var body: some View {
        NavigationStack {
            Group {
                if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Historique indisponible",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.entries.isEmpty {
                    ContentUnavailableView(
                        "Aucune découverte",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Vos prochaines analyses apparaîtront ici.")
                    )
                } else {
                    List {
                        ForEach(viewModel.entries) { entry in
                            NavigationLink {
                                ResultView(
                                    result: entry.captureResult,
                                    onRestart: {},
                                    showsRestart: false
                                )
                                .navigationTitle(entry.fact.lieu)
                                .navigationBarTitleDisplayMode(.inline)
                            } label: {
                                HistoryRow(entry: entry)
                            }
                        }
                        .onDelete(perform: viewModel.delete)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Historique")
            .toolbar {
                if !viewModel.entries.isEmpty {
                    EditButton()
                }
            }
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 14) {
            if let image = UIImage(data: entry.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.fact.lieu)
                    .font(.headline)
                    .lineLimit(2)
                Text(entry.fact.faitVerifie)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(entry.date, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
