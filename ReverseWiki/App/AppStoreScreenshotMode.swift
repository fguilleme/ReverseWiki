import CoreLocation
import Foundation
import UIKit

enum AppStoreScreenshotMode: String {
    case home
    case help
    case settings
    case result
    case map

    static var current: Self? {
        guard let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-appStoreScreenshotMode"),
              ProcessInfo.processInfo.arguments.indices.contains(index + 1) else {
            return nil
        }
        return Self(rawValue: ProcessInfo.processInfo.arguments[index + 1])
    }

    static var usesFixture: Bool {
        current == .result || current == .map
    }

    @MainActor
    static func makeResult() -> CaptureResult? {
        guard let image = UIImage(named: "AppStoreDemo"),
              let imageData = image.jpegData(compressionQuality: 0.92) else {
            return nil
        }

        let copy = localizedCopy
        return CaptureResult(
            imageData: imageData,
            coordinate: CLLocationCoordinate2D(latitude: 48.374, longitude: -4.619),
            fact: PlaceFact(
                lieu: copy.place,
                faitOfficiel: copy.official,
                faitVerifie: copy.verified,
                sources: [
                    "https://www.britannica.com/technology/lighthouse",
                    "https://whc.unesco.org/"
                ],
                latitude: 48.374,
                longitude: -4.619
            ),
            modelIdentifier: "gemini:gemini-2.5-flash"
        )
    }

    private static var localizedCopy: (place: String, official: String, verified: String) {
        switch Locale.current.language.languageCode?.identifier {
        case "fr":
            return (
                "Phare de la pointe d’Armorique",
                "Les phares sont souvent présentés comme l’œuvre solitaire de gardiens héroïques.",
                "Leur efficacité reposait surtout sur un réseau collectif : opticiens, cartographes, ingénieurs et familles de gardiens entretenaient ensemble la lumière et ses routes maritimes."
            )
        case "de":
            return (
                "Leuchtturm an der Pointe d’Armorique",
                "Leuchttürme werden oft als Werk einzelner heldenhafter Wärter dargestellt.",
                "Tatsächlich beruhte ihr Erfolg auf einem Netzwerk aus Optikern, Kartografen, Ingenieuren und Wärterfamilien, die Licht und Seewege gemeinsam sicherten."
            )
        case "es":
            return (
                "Faro de la punta de Armorique",
                "Los faros suelen presentarse como la obra solitaria de guardianes heroicos.",
                "Su eficacia dependía en realidad de una red de ópticos, cartógrafos, ingenieros y familias de fareros que mantenían juntos la luz y las rutas marítimas."
            )
        case "pt":
            return (
                "Farol da ponta da Armórica",
                "Os faróis são muitas vezes apresentados como obra solitária de guardiões heroicos.",
                "Na verdade, dependiam de uma rede de óticos, cartógrafos, engenheiros e famílias de faroleiros que mantinham em conjunto a luz e as rotas marítimas."
            )
        case "ru":
            return (
                "Маяк на мысе Арморика",
                "Маяки часто представляют как результат одинокого труда героических смотрителей.",
                "На деле их работа зависела от целой сети оптиков, картографов, инженеров и семей смотрителей, вместе поддерживавших свет и морские маршруты."
            )
        case "ja":
            return (
                "アルモリック岬の灯台",
                "灯台は、英雄的な灯台守が一人で守ったものとして語られがちです。",
                "実際には、光学技師、地図製作者、技師、灯台守の家族からなる共同ネットワークが、灯火と航路を支えていました。"
            )
        case "zh":
            return (
                "阿摩里卡角灯塔",
                "灯塔常被描述为英雄守塔人独自坚守的成果。",
                "事实上，灯塔依靠的是光学师、制图师、工程师和守塔人家庭组成的协作网络，他们共同维护灯光与航线。"
            )
        case "ar":
            return (
                "منارة رأس أرموريكا",
                "غالبًا ما تُروى قصة المنارات بوصفها عملًا فرديًا لحراس أبطال.",
                "لكن نجاحها اعتمد على شبكة جماعية من خبراء البصريات ورسامي الخرائط والمهندسين وعائلات الحراس الذين حافظوا معًا على الضوء والمسارات البحرية."
            )
        default:
            return (
                "Lighthouse at Armorique Point",
                "Lighthouses are often portrayed as the solitary work of heroic keepers.",
                "Their success actually relied on a network of lens makers, cartographers, engineers and keeper families who maintained the light and its maritime routes together."
            )
        }
    }
}
