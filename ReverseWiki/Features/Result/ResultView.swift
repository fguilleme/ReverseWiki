import MapKit
import SwiftUI

struct ResultView: View {
    let result: CaptureResult
    let onRestart: () -> Void
    var showsRestart = true
    @State private var shareItem: SharePayload?
    @State private var exportError: String?
    @State private var isExportingPDF = false

    private var uiImage: UIImage? { UIImage(data: result.imageData) }

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = geometry.size.width > geometry.size.height ? 24 : 16
            let contentWidth = max(geometry.size.width - (horizontalPadding * 2), 1)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: contentWidth, height: 280)
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
                        .fixedSize(horizontal: false, vertical: true)
                    Text(result.fact.faitVerifie)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    Text("Le récit courant")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(result.fact.faitOfficiel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(width: contentWidth, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))

                if let model = result.modelDisplayName {
                    Label(model, systemImage: "sparkles")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: contentWidth, alignment: .leading)
                        .accessibilityLabel(Text(String(
                            format: String(localized: "Modèle utilisé : %@"),
                            locale: .current,
                            model
                        )))
                }

                if let coordinate = result.coordinate {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.085, longitudeDelta: 0.085)
                    ))) {
                        Marker(result.fact.lieu, coordinate: coordinate)
                    }
                    .frame(width: contentWidth, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .accessibilityLabel("Carte du lieu identifié")
                    .id("map")
                } else {
                    ContentUnavailableView(
                        "Position non confirmée",
                        systemImage: "map",
                        description: Text("La carte est masquée plutôt que d’afficher une position approximative.")
                    )
                    .frame(width: contentWidth, height: 180)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Sources", systemImage: "checkmark.seal.fill").font(.headline)
                    ForEach(result.fact.sources, id: \.self) { source in
                        if let url = URL(string: source) {
                            Link(source, destination: url)
                                .font(.footnote)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                Button {
                    exportPostcard()
                } label: {
                    Label("Partager la carte postale", systemImage: "rectangle.on.rectangle")
                        .frame(width: contentWidth)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button {
                    exportPDF()
                } label: {
                    if isExportingPDF {
                        ProgressView()
                            .frame(width: contentWidth)
                    } else {
                        Label("Partager le document PDF", systemImage: "doc.richtext")
                            .frame(width: contentWidth)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isExportingPDF)
                if showsRestart {
                    Button("Analyser un autre lieu", action: onRestart)
                }
                    }
                    .frame(width: contentWidth)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 16)
                }
                .task {
                    guard AppStoreScreenshotMode.current == .map else { return }
                    try? await Task.sleep(for: .milliseconds(400))
                    withAnimation(.none) {
                        proxy.scrollTo("map", anchor: .top)
                    }
                }
            }
        }
        .sheet(item: $shareItem) { payload in
            ActivityView(items: payload.items)
                .onDisappear {
                    if let url = payload.temporaryURL {
                        try? FileManager.default.removeItem(at: url)
                    }
                }
        }
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
    private func exportPostcard() {
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
        shareItem = SharePayload(items: [image])
    }

    private func exportPDF() {
        isExportingPDF = true
        Task {
            defer { isExportingPDF = false }
            do {
                let url = try await PDFExportService.makePDF(for: result)
                shareItem = SharePayload(items: [url], temporaryURL: url)
            } catch {
                exportError = error.localizedDescription
            }
        }
    }

}

private struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
    var temporaryURL: URL? = nil
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
