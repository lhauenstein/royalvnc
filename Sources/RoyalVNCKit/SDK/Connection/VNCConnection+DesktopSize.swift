#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Why the server sent an ExtendedDesktopSize message.
public enum VNCDesktopSizeChange: Hashable, Sendable {
	/// The server changed the size or screens on its own, or reports them after connecting.
	case server
	/// Another client asked for the change and the server made it.
	case otherClient
	/// The server's answer to ``VNCConnection/requestDesktopSize(width:height:)``.
	case answer(status: UInt16)
}

public extension VNCDesktopSizeChange {
	/// Whether an answer says the server made the change or passed it on.
	var isAccepted: Bool {
		guard case .answer(let status) = self else { return false }

		switch VNCProtocol.ExtendedDesktopSizeEncoding.UserRequestedChangeStatus(rawValue: status) {
		case .noError, .requestForwardedMightCompleteAsyncronously: return true
		case .resizeIsAdministrativelyProhibited, .outOfResources, .invalidScreenLayout, nil: return false
		}
	}
}

public protocol VNCDesktopSizeDelegate: AnyObject {
	/// Called on the connection's receive queue for each ExtendedDesktopSize message, once the
	/// framebuffer took on the size and screens the message brought.
	func connection(_ connection: VNCConnection,
					didReceiveDesktopSizeChange change: VNCDesktopSizeChange)
}

extension VNCConnection {
	func desktopSizeDidChange(_ change: VNCDesktopSizeChange) {
		state.supportsDesktopSizeChanges = true

		desktopSizeDelegate?.connection(self,
										didReceiveDesktopSizeChange: change)
	}
}

public extension VNCConnection {
	/// Whether the server sent an ExtendedDesktopSize message, which servers do right after
	/// connecting when they accept ``requestDesktopSize(width:height:)``.
	var supportsDesktopSizeChanges: Bool {
		state.supportsDesktopSizeChanges
	}

	/// Asks the server for a framebuffer of this size with one screen filling it. The server
	/// answers through ``desktopSizeDelegate``; servers without ExtendedDesktopSize ignore it.
	func requestDesktopSize(width: UInt16,
							height: UInt16) {
		let screen = VNCProtocol.Screen(id: framebuffer?.screens.first?.id ?? 0,
										xPosition: 0,
										yPosition: 0,
										width: width,
										height: height,
										flags: 0)

		enqueueClientToServerMessage(VNCProtocol.SetDesktopSize(width: width,
																height: height,
																screens: [screen]))
	}
}
