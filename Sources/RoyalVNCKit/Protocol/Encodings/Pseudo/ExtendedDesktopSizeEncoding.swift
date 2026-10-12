// swiftlint:disable line_length

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension VNCProtocol {
	struct ExtendedDesktopSizeEncoding: VNCReceivablePseudoEncoding {
		let encodingType = VNCPseudoEncodingType.extendedDesktopSize.rawValue

		/// Learns why the server sent each message. Not through the framebuffer: an update can
		/// resize it with one rectangle and answer a request with the next, which still gets the
		/// framebuffer the first one replaced.
		let didReceiveChange: (VNCDesktopSizeChange) -> Void
	}
}

extension VNCProtocol.ExtendedDesktopSizeEncoding {
	enum Reason: UInt16 {
		/// The screen layout was changed via non-RFB means on the server. For example the server may have provided means for server-side applications to manipulate the screen layout. This code is also used when the client sends a non-incremental FrameBufferUpdateRequest to learn the server's current state.
		case changedViaNonRFBMeans = 0

		/// The client receiving this message requested a change of the screen layout. The change may or may not have happened depending on server policy or available resources. The status code in the y-position field must be used to determine which.
		case changedBecauseClientRequestedIt = 1

		/// Another client requested a change of the screen layout and the server approved it. A rectangle with this code is never sent if the server denied the request.
		case changedBecauseAnotherClientRequestedIt = 2
	}

	enum UserRequestedChangeStatus: UInt16 {
		case noError = 0
		case resizeIsAdministrativelyProhibited = 1
		case outOfResources = 2
		case invalidScreenLayout = 3
		case requestForwardedMightCompleteAsyncronously = 4
	}
}

extension VNCProtocol.ExtendedDesktopSizeEncoding {
	func receive(_ rectangle: VNCProtocol.Rectangle,
				 framebuffer: VNCFramebuffer,
				 connection: NetworkConnectionReading,
				 logger: VNCLogger) async throws {
		let reasonNum = rectangle.xPosition
		let userRequestedChangeStatusNum = rectangle.yPosition

		let newSize = rectangle.region.size

		let numberOfScreens = try await connection.readUInt8()
		try await connection.readPadding(length: 3)

		var screens = [VNCProtocol.Screen]()

		for _ in 0..<numberOfScreens {
			let screen = try await VNCProtocol.Screen.receive(connection: connection)

			screens.append(screen)
		}

		let change: VNCDesktopSizeChange = switch Reason(rawValue: reasonNum) {
		case .changedBecauseClientRequestedIt: .answer(status: userRequestedChangeStatusNum)
		case .changedBecauseAnotherClientRequestedIt: .otherClient
		case .changedViaNonRFBMeans, nil: .server
		}

		framebuffer.resize(to: newSize,
						   screens: screens)

		didReceiveChange(change)
	}
}

// swiftlint:enable line_length
