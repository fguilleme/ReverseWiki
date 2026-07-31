import MapKit
import UIKit

@MainActor
enum PDFExportService {
    static func makePDF(for result: CaptureResult) async throws -> URL {
        guard let photo = UIImage(data: result.imageData) else {
            throw AppError.exportFailed
        }

        let mapImage = try? await mapSnapshot(for: result)
        let formatter = UISimpleTextPrintFormatter(attributedText: document(
            for: result,
            photo: photo,
            mapImage: mapImage
        ))
        let renderer = A4PageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: renderer.paperRect)
        let data = pdfRenderer.pdfData { context in
            let pageCount = renderer.numberOfPages
            for page in 0..<pageCount {
                context.beginPage()
                renderer.drawPage(at: page, in: renderer.paperRect)
            }
        }

        guard !data.isEmpty else { throw AppError.exportFailed }
        let fileName = sanitizedFileName(result.fact.lieu)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReverseWiki-\(fileName)-\(UUID().uuidString).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func mapSnapshot(for result: CaptureResult) async throws -> UIImage? {
        guard let coordinate = result.coordinate else { return nil }
        let options = MKMapSnapshotter.Options()
        if let radius = result.estimatedPhotoAccuracyMeters {
            let visibleDiameter = min(max(radius * 3, 4_000), 240_000)
            options.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: visibleDiameter,
                longitudinalMeters: visibleDiameter
            )
        } else {
            options.region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.085, longitudeDelta: 0.085)
            )
        }
        options.size = CGSize(width: 1_000, height: 520)
        options.scale = 2
        let snapshot = try await MKMapSnapshotter(options: options).start()
        let marker = UIImage(systemName: "mappin.circle.fill")?
            .withTintColor(.systemRed, renderingMode: .alwaysOriginal)
        let point = snapshot.point(for: coordinate)
        return UIGraphicsImageRenderer(size: snapshot.image.size).image { context in
            snapshot.image.draw(at: .zero)
            if let radius = result.estimatedPhotoAccuracyMeters {
                drawAccuracyCircle(
                    radiusMeters: radius,
                    coordinate: coordinate,
                    center: point,
                    snapshot: snapshot,
                    context: context.cgContext
                )
            }
            marker?.draw(in: CGRect(x: point.x - 18, y: point.y - 36, width: 36, height: 36))
        }
    }

    private static func drawAccuracyCircle(
        radiusMeters: Double,
        coordinate: CLLocationCoordinate2D,
        center: CGPoint,
        snapshot: MKMapSnapshotter.Snapshot,
        context: CGContext
    ) {
        let centerMapPoint = MKMapPoint(coordinate)
        let mapPointRadius = radiusMeters / MKMetersPerMapPointAtLatitude(coordinate.latitude)
        let edgeCoordinate = MKMapPoint(
            x: centerMapPoint.x + mapPointRadius,
            y: centerMapPoint.y
        ).coordinate
        let edge = snapshot.point(for: edgeCoordinate)
        let pixelRadius = abs(edge.x - center.x)
        guard pixelRadius.isFinite, pixelRadius > 0 else { return }

        let circle = CGRect(
            x: center.x - pixelRadius,
            y: center.y - pixelRadius,
            width: pixelRadius * 2,
            height: pixelRadius * 2
        )
        context.setFillColor(UIColor.systemBlue.withAlphaComponent(0.18).cgColor)
        context.fillEllipse(in: circle)
        context.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.75).cgColor)
        context.setLineWidth(3)
        context.strokeEllipse(in: circle)
    }

    private static func document(
        for result: CaptureResult,
        photo: UIImage,
        mapImage: UIImage?
    ) -> NSAttributedString {
        let document = NSMutableAttributedString()
        let indigo = UIColor(red: 0.29, green: 0.24, blue: 0.71, alpha: 1)

        append(
            "REVERSE WIKI\n",
            to: document,
            font: .boldSystemFont(ofSize: 11),
            color: indigo,
            spacingAfter: 12
        )
        appendImage(photo, to: document, maximumHeight: 330)
        append(
            "\(result.fact.lieu)\n",
            to: document,
            font: .boldSystemFont(ofSize: 28),
            spacingBefore: 18,
            spacingAfter: 8
        )

        if let model = result.modelDisplayName {
            append(
                "\(String(localized: "Modèle")) : \(model)\n",
                to: document,
                font: .systemFont(ofSize: 10),
                color: .darkGray,
                spacingAfter: 12
            )
        }

        appendHeading(String(localized: "Fait vérifié"), to: document, color: indigo)
        append(
            "\(result.fact.faitVerifie)\n",
            to: document,
            font: .systemFont(ofSize: 16, weight: .semibold),
            spacingAfter: 14
        )
        appendHeading(String(localized: "Le récit courant"), to: document, color: indigo)
        append(
            "\(result.fact.faitOfficiel)\n",
            to: document,
            font: .systemFont(ofSize: 13),
            spacingAfter: 14
        )

        if let mapImage {
            appendHeading(String(localized: "Carte"), to: document, color: indigo)
            if result.estimatedPhotoCoordinate != nil {
                append(
                    "\(String(localized: "Point de prise de vue estimé"))\n",
                    to: document,
                    font: .systemFont(ofSize: 11, weight: .semibold),
                    color: .darkGray,
                    spacingAfter: 3
                )
                if let accuracyLabel = result.estimatedPhotoAccuracyLabel {
                    append(
                        "\(accuracyLabel)\n",
                        to: document,
                        font: .systemFont(ofSize: 10),
                        color: .darkGray,
                        spacingAfter: 8
                    )
                }
            }
            appendImage(mapImage, to: document, maximumHeight: 265)
        }

        appendHeading(String(localized: "Sources"), to: document, color: indigo)
        for (index, source) in result.fact.sources.enumerated() {
            let line = NSMutableAttributedString(
                string: "\(index + 1). \(source)\n",
                attributes: textAttributes(
                    font: .systemFont(ofSize: 10),
                    color: indigo,
                    spacingAfter: 6
                )
            )
            if let url = URL(string: source) {
                line.addAttribute(.link, value: url, range: NSRange(location: 0, length: line.length))
            }
            document.append(line)
        }
        return document
    }

    private static func appendHeading(
        _ value: String,
        to document: NSMutableAttributedString,
        color: UIColor
    ) {
        append(
            "\(value)\n",
            to: document,
            font: .boldSystemFont(ofSize: 18),
            color: color,
            spacingBefore: 20,
            spacingAfter: 8
        )
    }

    private static func append(
        _ value: String,
        to document: NSMutableAttributedString,
        font: UIFont,
        color: UIColor = .black,
        spacingBefore: CGFloat = 0,
        spacingAfter: CGFloat = 0
    ) {
        document.append(NSAttributedString(
            string: value,
            attributes: textAttributes(
                font: font,
                color: color,
                spacingBefore: spacingBefore,
                spacingAfter: spacingAfter
            )
        ))
    }

    private static func appendImage(
        _ image: UIImage,
        to document: NSMutableAttributedString,
        maximumHeight: CGFloat
    ) {
        let availableWidth: CGFloat = 511
        let ratio = image.size.height / max(image.size.width, 1)
        let height = min(availableWidth * ratio, maximumHeight)
        let width = min(availableWidth, height / max(ratio, 0.01))
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        document.append(NSAttributedString(attachment: attachment))
        document.append(NSAttributedString(string: "\n"))
    }

    private static func textAttributes(
        font: UIFont,
        color: UIColor,
        spacingBefore: CGFloat = 0,
        spacingAfter: CGFloat = 0
    ) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = .natural
        paragraph.paragraphSpacingBefore = spacingBefore
        paragraph.paragraphSpacing = spacingAfter
        paragraph.lineSpacing = 3
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
    }

    private static func sanitizedFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let components = value.components(separatedBy: allowed.inverted).filter { !$0.isEmpty }
        return components.prefix(6).joined(separator: "-").isEmpty
            ? "Document"
            : components.prefix(6).joined(separator: "-")
    }
}

private final class A4PageRenderer: UIPrintPageRenderer {
    private let page = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)

    override var paperRect: CGRect { page }
    override var printableRect: CGRect { page.insetBy(dx: 42, dy: 42) }
}
