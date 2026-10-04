//
//  VideoCallService.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  Which video-call service a link belongs to. The URL shapes that
//  recognise each one live in `Support/VideoCallCatalogue.swift`; this
//  file is only the identity and the name a person would recognise.
//

import Foundation

/// A video-call service recognised in an event's text.
///
/// The raw value is a stable, lowercase identifier for JSON and for matching in code;
/// ``displayName`` is what a person reads. Cases are declared alphabetically — the order
/// detection tries them in is a separate, deliberate list in the catalogue, because
/// precedence is a rule about which link wins, not about how the enum reads.
public enum VideoCallService: String, Codable, Sendable, Equatable, CaseIterable {

    case eightByEight = "8x8"
    case amazonChime = "amazon-chime"
    case around
    case blueJeans = "bluejeans"
    case calCom = "cal-com"
    case chorus
    case coScreen = "coscreen"
    case demio
    case demodesk
    case dialpad
    case doxyMe = "doxy-me"
    case faceTime = "facetime"
    case gather
    case gong
    case googleMeet = "google-meet"
    case goToMeeting = "gotomeeting"
    case goToWebinar = "gotowebinar"
    case huddle01
    case jam
    case jitsiMeet = "jitsi-meet"
    case lark
    case liveKitMeet = "livekit-meet"
    case livestorm
    case luma
    case meetecho
    case microsoftTeams = "microsoft-teams"
    case oVice = "ovice"
    case pop
    case preply
    case pumble
    case reclaim
    case relayed
    case ringCentral = "ringcentral"
    case sessions
    case signal
    case skype
    case slack
    case streamYard = "streamyard"
    case teamViewer = "teamviewer"
    case teemyco
    case tuple
    case userZoom = "userzoom"
    case venue
    case vimeo
    case vonage
    case vooV = "voov"
    case vowel
    case webex
    case whereby
    case workplaceChat = "workplace-chat"
    case zhumu
    case zohoCliq = "zoho-cliq"
    case zoom

    /// A link the event explicitly marks as its video call, on a service the catalogue
    /// does not know.
    ///
    /// Only ever produced from the `----( Video Call )----` notes block — an ordinary
    /// unrecognised link is not assumed to be a call, since most links in notes are
    /// agendas and documents.
    case other

    /// The service's name as its makers write it.
    public var displayName: String {
        switch self {
        case .eightByEight:   return "8x8"
        case .amazonChime:    return "Amazon Chime"
        case .around:         return "Around"
        case .blueJeans:      return "BlueJeans"
        case .calCom:         return "Cal.com"
        case .chorus:         return "Chorus"
        case .coScreen:       return "CoScreen"
        case .demio:          return "Demio"
        case .demodesk:       return "Demodesk"
        case .dialpad:        return "Dialpad"
        case .doxyMe:         return "Doxy.me"
        case .faceTime:       return "FaceTime"
        case .gather:         return "Gather"
        case .gong:           return "Gong"
        case .googleMeet:     return "Google Meet"
        case .goToMeeting:    return "GoToMeeting"
        case .goToWebinar:    return "GoToWebinar"
        case .huddle01:       return "Huddle01"
        case .jam:            return "Jam"
        case .jitsiMeet:      return "Jitsi Meet"
        case .lark:           return "Lark"
        case .liveKitMeet:    return "LiveKit Meet"
        case .livestorm:      return "Livestorm"
        case .luma:           return "Luma"
        case .meetecho:       return "Meetecho"
        case .microsoftTeams: return "Microsoft Teams"
        case .oVice:          return "oVice"
        case .pop:            return "Pop"
        case .preply:         return "Preply"
        case .pumble:         return "Pumble"
        case .reclaim:        return "Reclaim"
        case .relayed:        return "Relayed"
        case .ringCentral:    return "RingCentral"
        case .sessions:       return "Sessions"
        case .signal:         return "Signal"
        case .skype:          return "Skype"
        case .slack:          return "Slack"
        case .streamYard:     return "StreamYard"
        case .teamViewer:     return "TeamViewer"
        case .teemyco:        return "Teemyco"
        case .tuple:          return "Tuple"
        case .userZoom:       return "UserZoom"
        case .venue:          return "Venue"
        case .vimeo:          return "Vimeo"
        case .vonage:         return "Vonage"
        case .vooV:           return "VooV Meeting"
        case .vowel:          return "Vowel"
        case .webex:          return "Webex"
        case .whereby:        return "Whereby"
        case .workplaceChat:  return "Workplace Chat"
        case .zhumu:          return "Zhumu"
        case .zohoCliq:       return "Zoho Cliq"
        case .zoom:           return "Zoom"
        case .other:          return "Video call"
        }
    }
}
