import SwiftUI

struct HelpView: View {
    let isFirstLaunch: Bool
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.indigo)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("Bienvenue dans Reverse Wiki")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text("Découvrez ce que les récits touristiques ne racontent pas.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 20) {
                        HelpRow(
                            icon: "camera.fill",
                            title: "Photographiez ou importez",
                            description: "L’image est l’indice principal utilisé pour identifier le lieu."
                        )
                        HelpRow(
                            icon: "location.fill",
                            title: "La position reste optionnelle",
                            description: "Le GPS peut aider l’analyse, mais il est ignoré s’il ne correspond pas à la photo."
                        )
                        HelpRow(
                            icon: "sparkles",
                            title: "Choisissez votre modèle",
                            description: "Sélectionnez un fournisseur et un modèle compatible avec les images. Les clés restent dans le Trousseau."
                        )
                        ModelChoiceAdvice()
                        HelpRow(
                            icon: "checkmark.seal.fill",
                            title: "Vérifiez les sources",
                            description: "Le résultat présente un fait vérifié, ses sources et une carte seulement lorsque la position est confirmée."
                        )
                        HelpRow(
                            icon: "clock.arrow.circlepath",
                            title: "Retrouvez vos découvertes",
                            description: "Les analyses sont conservées dans l’historique et peuvent être supprimées à tout moment."
                        )
                    }

                }
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: onClose) {
                    Text(isFirstLaunch ? "Commencer" : "Fermer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .navigationTitle("Aide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isFirstLaunch {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fermer", action: onClose)
                    }
                }
            }
        }
        .interactiveDismissDisabled(isFirstLaunch)
    }
}

private struct ModelChoiceAdvice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Quel modèle choisir ?", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundStyle(.indigo)
            Text("Gemini peut fonctionner gratuitement avec la clé partagée de l’app, mais le quota et les performances sont partagés entre les utilisateurs.")
            Text("Pour une utilisation plus fiable, ajoutez votre propre clé Gemini gratuite. Vous pouvez aussi choisir des modèles payants comme Claude ou GPT.")
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct HelpRow: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.indigo)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
