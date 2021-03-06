//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc(OWSThreadDetailsInteraction)
public class ThreadDetailsInteraction: TSInteraction {

    @objc
    public override func isDynamicInteraction() -> Bool {
        return true
    }

    @objc
    public override func interactionType() -> OWSInteractionType {
        return .threadDetails
    }

    @available(*, unavailable, message: "use other constructor instead.")
    @objc
    public required init(coder aDecoder: NSCoder) {
        notImplemented()
    }

    @available(*, unavailable, message: "use other constructor instead.")
    @objc
    public required init(dictionary dictionaryValue: [String: Any]!) throws {
        notImplemented()
    }

    @objc
    public init(thread: TSThread, timestamp: UInt64) {
        // Include timestamp in uniqueId to ensure invariant that
        // interactions don't move in the chat history ordering.
        super.init(uniqueId: "ThreadDetails_\(timestamp)",
                   timestamp: timestamp,
                   thread: thread)
    }

    public override var shouldBeSaved: Bool {
        return false
    }

    @objc
    public override func anyWillInsert(with transaction: SDSAnyWriteTransaction) {
        owsFailDebug("The transient interaction should not be saved in the database.")
    }
}
