#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public protocol VNCClipboardDelegate: AnyObject {
	/// Called on the connection's receive queue with the text of each ServerCutText message.
	func connection(_ connection: VNCConnection,
					didReceiveClipboardText text: String)
}

extension VNCConnection {
	/// Whether the connection keeps the system pasteboard in step with the server's clipboard
	/// on its own. Off while a ``clipboardDelegate`` takes care of the text instead.
	var redirectsClipboard: Bool {
		settings.isClipboardRedirectionEnabled && clipboardDelegate == nil
	}
}

public extension VNCConnection {
	/// Sends `text` as the client's clipboard, in a ClientCutText message. Characters outside
	/// Latin-1, which the message can't carry, become question marks.
	func sendClipboardText(_ text: String) {
		enqueueClientCutTextMessage(text)
	}
}
