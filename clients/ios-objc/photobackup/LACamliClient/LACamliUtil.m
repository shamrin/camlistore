//
//  LACamliUtil.m
//  photobackup
//
//  Created by Nick O'Neill on 11/29/13.
//  Copyright (c) 2013 The Camlistore Authors. All rights reserved.
//

#import "LACamliUtil.h"
#import <CommonCrypto/CommonDigest.h>

@implementation LACamliUtil

static NSString *const serviceName = @"org.camlistore.credentials";

// h/t AFNetworking
+ (NSString *)base64EncodedStringFromString:(NSString *)string
{
    NSData *data = [NSData dataWithBytes:[string UTF8String] length:[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
    NSUInteger length = [data length];
    NSMutableData *mutableData = [NSMutableData dataWithLength:((length + 2) / 3) * 4];

    uint8_t *input = (uint8_t *)[data bytes];
    uint8_t *output = (uint8_t *)[mutableData mutableBytes];

    for (NSUInteger i = 0; i < length; i += 3) {
        NSUInteger value = 0;
        for (NSUInteger j = i; j < (i + 3); j++) {
            value <<= 8;
            if (j < length) {
                value |= (0xFF & input[j]);
            }
        }

        static uint8_t const kAFBase64EncodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

        NSUInteger idx = (i / 3) * 4;
        output[idx + 0] = kAFBase64EncodingTable[(value >> 18) & 0x3F];
        output[idx + 1] = kAFBase64EncodingTable[(value >> 12) & 0x3F];
        output[idx + 2] = (i + 1) < length ? kAFBase64EncodingTable[(value >> 6)  & 0x3F] : '=';
        output[idx + 3] = (i + 2) < length ? kAFBase64EncodingTable[(value >> 0)  & 0x3F] : '=';
    }

    return [[NSString alloc] initWithData:mutableData encoding:NSASCIIStringEncoding];
}

#pragma mark - keychain stuff

+ (NSString *)passwordForUsername:(NSString *)username
{
    if (!username) {
        LALog(@"no username");
        return nil;
    }

    // construct query
    NSDictionary *passwordQuery = @{(__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassGenericPassword,
                                    (__bridge NSString *)kSecAttrAccount: username,
                                    (__bridge NSString *)kSecAttrService: serviceName,
                                    (__bridge NSString *)kSecReturnData: (id)kCFBooleanTrue};


	NSData *results = nil;
    CFTypeRef resultRef = (__bridge CFTypeRef)results;

    // actually request password
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)passwordQuery, &resultRef);

    results = (__bridge NSData *)resultRef;

    if (status == noErr) {
        LALog(@"returning valid password");
        return [[NSString alloc] initWithData:results encoding:NSUTF8StringEncoding];
    }

    return nil;
}

+ (BOOL)savePassword:(NSString *)password forUsername:(NSString *)username
{
    if (!password || !username) {
        LALog(@"no password or username");
        return NO;
    }

    OSStatus status = noErr;

    if ([self passwordForUsername:username]) {
        LALog(@"update");
        // update keychain item

        NSDictionary *updateQuery = @{(__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassGenericPassword,
                                      (__bridge NSString *)kSecAttrAccount: username,
                                      (__bridge NSString *)kSecAttrService: serviceName
                                      };

        NSDictionary *updateAttribute = @{(__bridge NSString *)kSecValueData: [password dataUsingEncoding:NSUTF8StringEncoding]};

        status = SecItemUpdate((__bridge CFDictionaryRef)updateQuery, (__bridge CFDictionaryRef)updateAttribute);
    } else {
        LALog(@"new");
        // add a new keychain item

        NSDictionary *addQuery = @{(__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassGenericPassword,
                                   (__bridge NSString *)kSecAttrAccount: username,
                                   (__bridge NSString *)kSecAttrService: serviceName,
                                   (__bridge NSString *)kSecValueData: [password dataUsingEncoding:NSUTF8StringEncoding]
                                   };

        status =  SecItemAdd((__bridge CFDictionaryRef)addQuery, nil);
    }

    if (status != noErr) {
        return NO;
    }

    return YES;
}

#pragma mark - hashes

+ (NSString *)blobRef:(NSData *)data
{
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];

    CC_SHA1(data.bytes, data.length, digest);

    NSMutableString* output = [NSMutableString stringWithCapacity:(CC_SHA1_DIGEST_LENGTH * 2) + 5];
    [output appendString:@"sha1-"];

    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }

    return output;
}

#pragma mark - dates

+ (NSString *)rfc3339StringFromDate:(NSDate *)date
{
    NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init];

    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];

    [rfc3339DateFormatter setLocale:enUSPOSIXLocale];
    [rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
    [rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

    return [rfc3339DateFormatter stringFromDate:date];
}

#pragma mark - yucky logging hack

+ (void)logText:(NSArray *)logs
{
    NSMutableString *logString = [NSMutableString string];

    for (NSString *log in logs) {
        [logString appendString:log];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"logtext" object:@{@"text": logString}];
}

+ (void)statusText:(NSArray *)statuses
{
    NSMutableString *statusString = [NSMutableString string];

    for (NSString *status in statuses) {
        [statusString appendString:status];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"statusText" object:@{@"text": statusString}];
}

+ (void)errorText:(NSArray *)errors
{
    NSMutableString *errorString = [NSMutableString string];

    for (NSString *error in errors) {
        [errorString appendString:error];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"errorText" object:@{@"text": errorString}];
}

@end
