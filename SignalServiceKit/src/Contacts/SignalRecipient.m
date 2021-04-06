//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "SignalRecipient.h"
#import "OWSDevice.h"
#import "ProfileManagerProtocol.h"
#import "SSKEnvironment.h"
#import "TSAccountManager.h"
#import "TSSocketManager.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

const NSUInteger SignalRecipientSchemaVersion = 1;

@interface SignalRecipient ()

@property (nonatomic) NSOrderedSet<NSNumber *> *devices;
@property (nonatomic) NSUInteger recipientSchemaVersion;

@end

#pragma mark -

@implementation SignalRecipient

- (instancetype)initWithUUIDString:(NSString *)uuidString
{
    self = [super init];

    if (!self) {
        return self;
    }

    _recipientUUID = uuidString;
    _recipientPhoneNumber = nil;
    _recipientSchemaVersion = SignalRecipientSchemaVersion;

    _devices = [NSOrderedSet orderedSetWithObject:@(OWSDevicePrimaryDeviceId)];

    return self;
}

- (instancetype)initWithAddress:(SignalServiceAddress *)address
{
    self = [super init];

    if (!self) {
        return self;
    }

    _recipientUUID = address.uuidString;
    _recipientPhoneNumber = address.phoneNumber;
    _recipientSchemaVersion = SignalRecipientSchemaVersion;

    _devices = [NSOrderedSet orderedSetWithObject:@(OWSDevicePrimaryDeviceId)];

    return self;
}

#if TESTABLE_BUILD
- (instancetype)initWithPhoneNumber:(nullable NSString *)phoneNumber
                               uuid:(nullable NSUUID *)uuid
                            devices:(NSArray<NSNumber *> *)devices
{
    OWSAssertDebug(phoneNumber.length > 0 || uuid.UUIDString.length > 0);

    self = [super init];

    if (!self) {
        return self;
    }

    _recipientUUID = uuid.UUIDString;
    _recipientPhoneNumber = phoneNumber;
    _recipientSchemaVersion = SignalRecipientSchemaVersion;
    _devices = [NSOrderedSet orderedSetWithArray:devices];

    return self;
}
#endif

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return self;
    }

    if (_devices == nil) {
        _devices = [NSOrderedSet new];
    }

    // Migrating from an everyone has a phone number world to a
    // world in which we have UUIDs
    if (_recipientSchemaVersion < 1) {
        // Copy uniqueId to recipientPhoneNumber
        _recipientPhoneNumber = [coder decodeObjectForKey:@"uniqueId"];

        OWSAssert(_recipientPhoneNumber != nil);
    }

    // Since we use device count to determine whether a user is registered or not,
    // ensure the local user always has at least *this* device.
    if (![_devices containsObject:@(OWSDevicePrimaryDeviceId)]) {
        if (self.address.isLocalAddress) {
            DDLogInfo(@"Adding primary device to self recipient.");
            [self addDevices:[NSSet setWithObject:@(OWSDevicePrimaryDeviceId)]];
        }
    }

    _recipientSchemaVersion = SignalRecipientSchemaVersion;

    return self;
}

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
                         devices:(NSOrderedSet<NSNumber *> *)devices
            recipientPhoneNumber:(nullable NSString *)recipientPhoneNumber
                   recipientUUID:(nullable NSString *)recipientUUID
{
    self = [super initWithGrdbId:grdbId
                        uniqueId:uniqueId];

    if (!self) {
        return self;
    }

    _devices = devices;
    _recipientPhoneNumber = recipientPhoneNumber;
    _recipientUUID = recipientUUID;

    return self;
}

// clang-format on

// --- CODE GENERATION MARKER

+ (AnySignalRecipientFinder *)recipientFinder
{
    return [AnySignalRecipientFinder new];
}

+ (nullable instancetype)getRecipientForAddress:(SignalServiceAddress *)address
                                mustHaveDevices:(BOOL)mustHaveDevices
                                    transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(transaction);
    OWSAssertDebug(address.isValid);
    SignalRecipient *_Nullable signalRecipient =
        [self.modelReadCaches.signalRecipientReadCache getSignalRecipientForAddress:address transaction:transaction];
    if (mustHaveDevices && signalRecipient.devices.count < 1) {
        return nil;
    }
    return signalRecipient;
}

#pragma mark -

- (void)addDevices:(NSSet<NSNumber *> *)devices
{
    OWSAssertDebug(devices.count > 0);

    NSMutableOrderedSet<NSNumber *> *updatedDevices = [self.devices mutableCopy];
    [updatedDevices unionSet:devices];
    self.devices = [updatedDevices copy];
}

- (void)removeDevices:(NSSet<NSNumber *> *)devices
{
    OWSAssertDebug(devices.count > 0);

    NSMutableOrderedSet<NSNumber *> *updatedDevices = [self.devices mutableCopy];
    [updatedDevices minusSet:devices];
    self.devices = [updatedDevices copy];
}

+ (void)updateWithAddress:(SignalServiceAddress *)address
             devicesToAdd:(nullable NSArray<NSNumber *> *)devicesToAdd
          devicesToRemove:(nullable NSArray<NSNumber *> *)devicesToRemove
              transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(transaction);
    OWSAssertDebug(devicesToAdd.count > 0 || devicesToRemove.count > 0);

    SignalRecipient *recipient = [self getOrCreateLowTrustRecipientWithAdddress:address transaction:transaction];
    [recipient updateWithDevicesToAdd:devicesToAdd devicesToRemove:devicesToRemove transaction:transaction];
}

- (void)updateWithDevicesToAdd:(nullable NSArray<NSNumber *> *)devicesToAdd
               devicesToRemove:(nullable NSArray<NSNumber *> *)devicesToRemove
                   transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(transaction);
    OWSAssertDebug(devicesToAdd.count > 0 || devicesToRemove.count > 0);

    // Add before we remove, since removeDevicesFromRecipient:...
    // can markRecipientAsUnregistered:... if the recipient has
    // no devices left.
    if (devicesToAdd.count > 0) {
        OWSLogInfo(@"devicesToAdd: %@ for %@", devicesToAdd, self.address);
        [self updateWithDevicesToAdd:[NSSet setWithArray:devicesToAdd] transaction:transaction];
    }
    if (devicesToRemove.count > 0) {
        OWSLogInfo(@"devicesToRemove: %@ for %@", devicesToRemove, self.address);
        [self updateWithDevicesToRemove:[NSSet setWithArray:devicesToRemove] transaction:transaction];
    }

    // Device changes
    dispatch_async(dispatch_get_main_queue(), ^{
        // Device changes can affect the UD access mode for a recipient,
        // so we need to fetch the profile for this user to update UD access mode.
        [self.profileManager fetchProfileForAddress:self.address];

        if (self.address.isLocalAddress) {
            [self.socketManager cycleSocket];
        }
    });
}

- (void)updateWithDevicesToAdd:(NSSet<NSNumber *> *)devices transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(transaction);
    OWSAssertDebug(devices.count > 0);
    OWSLogDebug(@"adding devices: %@, to recipient: %@", devices, self);

    [self anyReloadWithTransaction:transaction];
    [self anyUpdateWithTransaction:transaction
                             block:^(SignalRecipient *signalRecipient) {
                                 [signalRecipient addDevices:devices];
                             }];
}

- (void)updateWithDevicesToRemove:(NSSet<NSNumber *> *)devices transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(transaction);
    OWSAssertDebug(devices.count > 0);

    OWSLogDebug(@"removing devices: %@, from registered recipient: %@", devices, self);
    [self anyReloadWithTransaction:transaction ignoreMissing:YES];
    [self anyUpdateWithTransaction:transaction
                             block:^(SignalRecipient *signalRecipient) {
                                 [signalRecipient removeDevices:devices];
                             }];
}

#pragma mark -

- (SignalServiceAddress *)address
{
    return [[SignalServiceAddress alloc] initWithUuidString:self.recipientUUID phoneNumber:self.recipientPhoneNumber];
}

#pragma mark -

- (NSComparisonResult)compare:(SignalRecipient *)other
{
    return [self.address compare:other.address];
}

- (void)anyWillInsertWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyWillInsertWithTransaction:transaction];

    OWSLogVerbose(@"Inserted signal recipient: %@ (%lu)", self.address, (unsigned long)self.devices.count);
}

- (void)anyWillUpdateWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyWillUpdateWithTransaction:transaction];

    OWSLogVerbose(@"Updated signal recipient: %@ (%lu)", self.address, (unsigned long)self.devices.count);
}

+ (BOOL)isRegisteredRecipient:(SignalServiceAddress *)address transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(transaction);
    OWSAssertDebug(address.isValid);
    return nil != [self getRecipientForAddress:address mustHaveDevices:YES transaction:transaction];
}

+ (SignalRecipient *)markRecipientAsRegisteredAndGet:(SignalServiceAddress *)address
                                          trustLevel:(SignalRecipientTrustLevel)trustLevel
                                         transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(address.isValid);
    OWSAssertDebug(transaction);

    switch (trustLevel) {
        case SignalRecipientTrustLevelLow:
            return [self getOrCreateLowTrustRecipientWithAdddress:address transaction:transaction];
        case SignalRecipientTrustLevelHigh:
            return [self getOrCreateHighTrustRecipientWithAddress:address markAsRegistered:YES transaction:transaction];
    }
}

+ (SignalRecipient *)getOrCreateLowTrustRecipientWithAdddress:(SignalServiceAddress *)address
                                                  transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(address.isValid);
    OWSAssertDebug(transaction);

    SignalRecipient *_Nullable phoneNumberInstance = nil;
    SignalRecipient *_Nullable uuidInstance = nil;
    if (address.phoneNumber != nil) {
        phoneNumberInstance = [self.recipientFinder signalRecipientForPhoneNumber:address.phoneNumber
                                                                      transaction:transaction];
    }
    if (address.uuid != nil) {
        uuidInstance = [self.recipientFinder signalRecipientForUUID:address.uuid transaction:transaction];
    }

    // Low trust updates should never update the database, unless
    // there is no matching record for the UUID, in which case we
    // can create a new UUID only record (we don't want to associate
    // it with the phone number) or there is no UUID, in which case
    // we will record the phone number alone.
    if (uuidInstance) {
        return uuidInstance;
    } else if (address.uuidString) {
        OWSLogDebug(@"creating new low trust recipient with UUID: %@", address.uuidString);

        SignalRecipient *newInstance = [[self alloc] initWithUUIDString:address.uuidString];
        [newInstance anyInsertWithTransaction:transaction];

        // Record with the new contact in the social graph
        [self.storageServiceManager recordPendingUpdatesWithUpdatedAccountIds:@[ newInstance.accountId ]];

        return newInstance;
    } else if (phoneNumberInstance) {
        return phoneNumberInstance;
    } else {
        OWSAssertDebug(address.phoneNumber);
        OWSLogDebug(@"creating new low trust recipient with phoneNumber: %@", address.phoneNumber);

        SignalRecipient *newInstance = [[self alloc] initWithAddress:address];
        [newInstance anyInsertWithTransaction:transaction];

        // Record with the new contact in the social graph
        [self.storageServiceManager recordPendingUpdatesWithUpdatedAccountIds:@[ newInstance.accountId ]];

        return newInstance;
    }
}

+ (SignalRecipient *)getOrCreateHighTrustRecipientWithAddress:(SignalServiceAddress *)address
                                             markAsRegistered:(BOOL)markAsRegistered
                                                  transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(address.isValid);
    OWSAssertDebug(transaction);

    SignalRecipient *_Nullable phoneNumberInstance = nil;
    SignalRecipient *_Nullable uuidInstance = nil;
    if (address.phoneNumber != nil) {
        phoneNumberInstance = [self.recipientFinder signalRecipientForPhoneNumber:address.phoneNumber
                                                                      transaction:transaction];
    }
    if (address.uuid != nil) {
        uuidInstance = [self.recipientFinder signalRecipientForUUID:address.uuid transaction:transaction];
    }

    // High trust updates will fully update the database to reflect
    // the new mapping in a given address, if any changes are present.
    //
    // In general, the rules we follow when applying changes are:
    // * UUIDs are immutable and representative of an account. If the UUID
    //   has changed we must treat it as an entirely new contact.
    // * Phone numbers are transient and can move freely between UUIDs. When
    //   they do, we must backfill the database to reflect the change.
    BOOL shouldUpdate = NO;
    SignalRecipient *_Nullable existingInstance = nil;

    if (uuidInstance && phoneNumberInstance) {
        // These are the same and both fully complete, we have no extra work to do.
        if ([uuidInstance.uniqueId isEqualToString:phoneNumberInstance.uniqueId]) {
            existingInstance = phoneNumberInstance;

            // These are the same, but not fully complete. We need to merge them.
        } else if (phoneNumberInstance.recipientUUID == nil && uuidInstance.recipientPhoneNumber == nil) {
            existingInstance = [self mergeUUIDInstance:uuidInstance
                                andPhoneNumberInstance:phoneNumberInstance
                                           transaction:transaction];
            shouldUpdate = YES;

            // Update the SignalServiceAddressCache mappings with the now fully-qualified recipient.
            [SSKEnvironment.shared.signalServiceAddressCache updateMappingWithUuid:address.uuid
                                                                       phoneNumber:address.phoneNumber];

            // The UUID differs between the two records, we need to migrate the phone
            // number to the UUID instance.
        } else {
            OWSLogWarn(@"Learned phoneNumber (%@) now belongs to uuid (%@).", address.phoneNumber, address.uuid);

            // Ordering is critical here. We must remove the phone number
            // from the old recipient *before* we assign the phone number
            // to the new recipient, in case there are any legacy phone
            // number only records in the database.

            shouldUpdate = YES;

            OWSAssertDebug(phoneNumberInstance.recipientUUID != nil);
            [phoneNumberInstance changePhoneNumber:nil transaction:transaction.unwrapGrdbWrite];
            [phoneNumberInstance anyOverwritingUpdateWithTransaction:transaction];
            [uuidInstance changePhoneNumber:address.phoneNumber transaction:transaction.unwrapGrdbWrite];

            existingInstance = uuidInstance;
        }
    } else if (phoneNumberInstance) {
        if (address.uuidString && phoneNumberInstance.recipientUUID != nil) {
            OWSLogWarn(@"Learned phoneNumber (%@) now belongs to uuid (%@).", address.phoneNumber, address.uuid);

            // The UUID associated with this phone number has changed, we must
            // clear the phone number from this instance and create a new instance.
            [phoneNumberInstance changePhoneNumber:nil transaction:transaction.unwrapGrdbWrite];
            [phoneNumberInstance anyOverwritingUpdateWithTransaction:transaction];
        } else {
            if (address.uuidString) {
                OWSLogWarn(
                    @"Learned uuid (%@) is associated with phoneNumber (%@).", address.uuidString, address.phoneNumber);

                shouldUpdate = YES;
                phoneNumberInstance.recipientUUID = address.uuidString;

                // Update the SignalServiceAddressCache mappings with the now fully-qualified recipient.
                [SSKEnvironment.shared.signalServiceAddressCache updateMappingWithUuid:address.uuid
                                                                           phoneNumber:address.phoneNumber];
            }

            existingInstance = phoneNumberInstance;
        }
    } else if (uuidInstance) {
        if (address.phoneNumber) {
            if (uuidInstance.recipientPhoneNumber == nil) {
                OWSLogWarn(
                    @"Learned uuid (%@) is associated with phoneNumber (%@).", address.uuidString, address.phoneNumber);
            } else {
                OWSLogWarn(@"Learned uuid (%@) changed from old phoneNumber (%@) to new phoneNumber (%@)",
                    address.uuidString,
                    existingInstance.recipientPhoneNumber,
                    address.phoneNumber);
            }

            shouldUpdate = YES;
            [uuidInstance changePhoneNumber:address.phoneNumber transaction:transaction.unwrapGrdbWrite];
        }

        existingInstance = uuidInstance;
    }

    if (existingInstance == nil) {
        OWSLogDebug(@"creating new high trust recipient with address: %@", address);

        SignalRecipient *newInstance = [[self alloc] initWithAddress:address];
        [newInstance anyInsertWithTransaction:transaction];

        // Update the SignalServiceAddressCache mappings with the new recipient.
        if (address.uuid) {
            [SSKEnvironment.shared.signalServiceAddressCache updateMappingWithUuid:address.uuid
                                                                       phoneNumber:address.phoneNumber];
        }

        // Record with the new contact in the social graph
        [self.storageServiceManager recordPendingUpdatesWithUpdatedAccountIds:@[ newInstance.accountId ]];

        return newInstance;
    }

    if (markAsRegistered && existingInstance.devices.count == 0) {
        shouldUpdate = YES;

        // We know they're registered, so make sure they have at least one device.
        // We assume it's the default device. If we're wrong, the service will correct us when we
        // try to send a message to them
        existingInstance.devices = [NSOrderedSet orderedSetWithObject:@(OWSDevicePrimaryDeviceId)];
    }

    // Record the updated contact in the social graph
    if (shouldUpdate) {
        OWSAssertDebug([existingInstance.devices containsObject:@(OWSDevicePrimaryDeviceId)]);
        [existingInstance anyOverwritingUpdateWithTransaction:transaction];
        [self.storageServiceManager recordPendingUpdatesWithUpdatedAccountIds:@[ existingInstance.accountId ]];
    }

    return existingInstance;
}

+ (SignalRecipient *)mergeUUIDInstance:(SignalRecipient *)uuidInstance
                andPhoneNumberInstance:(SignalRecipient *)phoneNumberInstance
                           transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(uuidInstance.recipientPhoneNumber == nil ||
        [NSObject isNullableObject:uuidInstance.recipientPhoneNumber equalTo:phoneNumberInstance.recipientPhoneNumber]);
    OWSAssertDebug(phoneNumberInstance.recipientUUID == nil ||
        [NSObject isNullableObject:phoneNumberInstance.recipientUUID equalTo:uuidInstance.recipientUUID]);

    // We have separate recipients in the db for the uuid and phone number.
    // There isn't an ideal way to do this, but we need to converge on one
    // recipient and discard the other.
    //
    // TODO: Should we clean up any state related to the discarded recipient?

    SignalRecipient *_Nullable winningInstance = nil;

    // We try to preserve the recipient that has a session.
    BOOL hasSessionForUuid = [self.sessionStore containsActiveSessionForAccountId:uuidInstance.accountId
                                                                         deviceId:OWSDevicePrimaryDeviceId
                                                                      transaction:transaction];
    BOOL hasSessionForPhoneNumber = [self.sessionStore containsActiveSessionForAccountId:phoneNumberInstance.accountId
                                                                                deviceId:OWSDevicePrimaryDeviceId
                                                                             transaction:transaction];

    if (SSKDebugFlags.verboseSignalRecipientLogging) {
        OWSLogInfo(@"phoneNumberInstance: %@", phoneNumberInstance);
        OWSLogInfo(@"uuidInstance: %@", uuidInstance);
        OWSLogInfo(@"hasSessionForUuid: %@", @(hasSessionForUuid));
        OWSLogInfo(@"hasSessionForPhoneNumber: %@", @(hasSessionForPhoneNumber));
    }

    // We want to retain the phone number recipient only if it has a session and the UUID recipient doesn't.
    // Historically, we tried to be clever and pick the session that had seen more use,
    // but merging sessions should only happen in exceptional circumstances these days.
    if (hasSessionForUuid) {
        OWSLogWarn(@"Discarding phone number recipient in favor of uuid recipient.");
        winningInstance = uuidInstance;
        [phoneNumberInstance anyRemoveWithTransaction:transaction];
    } else {
        OWSLogWarn(@"Discarding uuid recipient in favor of phone number recipient.");
        winningInstance = phoneNumberInstance;
        [uuidInstance anyRemoveWithTransaction:transaction];
    }

    // Make sure the winning instance is fully qualified.
    winningInstance.recipientPhoneNumber = phoneNumberInstance.recipientPhoneNumber;
    winningInstance.recipientUUID = uuidInstance.recipientUUID;

    [OWSUserProfile mergeUserProfilesIfNecessaryForAddress:winningInstance.address transaction:transaction];

    return winningInstance;
}

+ (SignalRecipient *)markRecipientAsRegisteredAndGet:(SignalServiceAddress *)address
                                            deviceId:(UInt32)deviceId
                                          trustLevel:(SignalRecipientTrustLevel)trustLevel
                                         transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(address.isValid);
    OWSAssertDebug(deviceId > 0);
    OWSAssertDebug(transaction);

    SignalRecipient *recipient = [self markRecipientAsRegisteredAndGet:address
                                                            trustLevel:trustLevel
                                                           transaction:transaction];
    if (![recipient.devices containsObject:@(deviceId)]) {
        OWSLogDebug(@"Adding device %u to existing recipient.", (unsigned int)deviceId);

        [recipient anyReloadWithTransaction:transaction];
        [recipient anyUpdateWithTransaction:transaction
                                      block:^(SignalRecipient *signalRecipient) {
                                          [signalRecipient addDevices:[NSSet setWithObject:@(deviceId)]];
                                      }];
    }

    return recipient;
}

+ (void)markRecipientAsUnregistered:(SignalServiceAddress *)address transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(address.isValid);
    OWSAssertDebug(transaction);

    SignalRecipient *recipient = [self getOrCreateLowTrustRecipientWithAdddress:address transaction:transaction];

    if (recipient.devices.count > 0) {
        OWSLogDebug(@"Marking recipient as not registered: %@", address);
        [recipient anyUpdateWithTransaction:transaction
                                      block:^(SignalRecipient *signalRecipient) {
                                          signalRecipient.devices = [NSOrderedSet new];
                                      }];

        // Remove the contact from our social graph
        [self.storageServiceManager recordPendingDeletionsWithDeletedAccountIds:@[ recipient.accountId ]];
    }
}

- (void)anyDidInsertWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyDidInsertWithTransaction:transaction];

    [self.modelReadCaches.signalRecipientReadCache didInsertOrUpdateSignalRecipient:self transaction:transaction];
}

- (void)anyDidUpdateWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyDidUpdateWithTransaction:transaction];

    [self.modelReadCaches.signalRecipientReadCache didInsertOrUpdateSignalRecipient:self transaction:transaction];
}

- (void)anyDidRemoveWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyDidRemoveWithTransaction:transaction];

    [self.modelReadCaches.signalRecipientReadCache didRemoveSignalRecipient:self transaction:transaction];
    [self.storageServiceManager recordPendingDeletionsWithDeletedAccountIds:@[ self.accountId ]];
}

+ (BOOL)shouldBeIndexedForFTS
{
    return YES;
}

- (void)removePhoneNumberForDatabaseMigration
{
    OWSAssertDebug(self.recipientUUID != nil);
    OWSAssertDebug(self.recipientPhoneNumber != nil);

    _recipientPhoneNumber = nil;
}

@end

NS_ASSUME_NONNULL_END
