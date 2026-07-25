import SwiftUI

struct ShareCardView: View {
    let image: Image
    let fact: PlaceFact

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            image.resizable().scaledToFill().frame(width: 1080, height: 1350).clipped()
            LinearGradient(
                colors: [.clear, .black.opacity(0.35), .black.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 24) {
                Text(fact.lieu.uppercased())
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.yellow)
                Text(fact.faitVerifie)
                    .font(.system(size: 52, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(7)
                    .minimumScaleFactor(0.72)
                Divider().overlay(.white.opacity(0.5))
                Text("Le récit courant")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Text(fact.faitOfficiel)
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(3)
                Text("REVERSE WIKI  •  SOURCES VÉRIFIÉES")
                    .font(.system(size: 19, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(64)
        }
        .frame(width: 1080, height: 1350)
    }
}
