import MapKit
import SwiftUI

struct ResultView: View {
    let result: CaptureResult
    let onRestart: () -> Void
    var showsRestart = true
    @State private var shareItem: ShareImage?
    @State private var exportError: String?

    private var uiImage: UIImage? { UIImage(data: result.imageData) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(radius: 12, y: 8)
                        .accessibilityLabel(Text(String(
                            format: String(localized: "Photo analysée de %@"),
                            locale: .current,
                            result.fact.lieu
                        )))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(result.fact.lieu)
                        .font(.title.bold())
                    Text(result.fact.faitVerifie)
                        .font(.title3.weight(.semibold))
                    Divider()
                    Text("Le récit courant")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(result.fact.faitOfficiel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))

                if let model = result.modelDisplayName {
                    Label(model, systemImage: "sparkles")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(Text(String(
                            format: String(localized: "Modèle utilisé : %@"),
                            locale: .current,
                            model
                        )))
                }

                if let coordinate = result.coordinate {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                    ))) {
                        Marker(result.fact.lieu, coordinate: coordinate)
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .accessibilityLabel("Carte du lieu identifié")
                } else {
                    ContentUnavailableView(
                        "Position non confirmée",
                        systemImage: "map",
                        description: Text("La carte est masquée plutôt que d’afficher une position approximative.")
                    )
                    .frame(height: 180)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Sources", systemImage: "checkmark.seal.fill").font(.headline)
                    ForEach(result.fact.sources, id: \.self) { source in
                        if let url = URL(string: source) {
                            Link(source, destination: url).font(.footnote).lineLimit(2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    export()
                } label: {
                    Label("Partager la carte", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                if showsRestart {
                    Button("Analyser un autre lieu", action: onRestart)
                }
            }
            .padding()
        }
        .sheet(item: $shareItem) { ActivityView(items: [$0.image]) }
        .alert("Export impossible", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    @MainActor
    private func export() {
        guard let uiImage else {
            exportError = AppError.exportFailed.localizedDescription
            return
        }
        let renderer = ImageRenderer(content: ShareCardView(
            image: Image(uiImage: uiImage),
            fact: result.fact
        ))
        renderer.scale = 1
        guard let image = renderer.uiImage else {
            exportError = AppError.exportFailed.localizedDescription
            return
        }
        shareItem = ShareImage(image: image)
    }
}

private struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
