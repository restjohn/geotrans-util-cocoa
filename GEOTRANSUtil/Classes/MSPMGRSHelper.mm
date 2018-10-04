//
//  MGRSHelper.m
//  GEOTRANS-CocoaPods
//
//  Created by Robert St. John on 9/24/18.
//  Copyright © 2018 GEOINT Services Mobile Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CoreLocation/CoreLocation.h"
#import <math.h>
#import "MSPMGRSHelper.h"
#import "UTM.h"
#import "UTMCoordinates.h"
#import "UPS.h"
#import "UPSCoordinates.h"
#import "MGRS.h"
#import "CoordinateType.h"
#import "GeodeticCoordinates.h"
#import "MGRSorUSNGCoordinates.h"
#import "CoordinateConversionException.h"

#define UTM_MIN_LAT (-80.0 * (M_PI / 180.0)) /* -80 deg in rad */
#define UTM_MAX_LAT (84.0 * (M_PI / 180.0)) /*  84 deg in rad */
#define UTM_LAT_EPSILON 1.75e-7   /* approx 1.0e-5 degrees (~1 meter) in radians */

NSErrorDomain const MSPMGRSErrorDomain = @"MGRS Conversion Error";
NSInteger const MSPMGRSError = 38571;

NSError * makeConversionError(MSP::CCS::CoordinateConversionException &e) {
    return [[NSError alloc] initWithDomain:MSPMGRSErrorDomain code:MSPMGRSError
        userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.getMessage()]}];
}

@interface MSPMGRSHelper () {
    MSP::CCS::MGRS *mgrsSystem;
    MSP::CCS::UTM *utmSystem;
    MSP::CCS::UPS *upsSystem;
}

@end

/**
 * NOTE: see https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Exceptions/Articles/Exceptions64Bit.html
 * for important material on handling C++ exceptions in 32 vs. 64-bit architectures.  For now, this code will assume 64-bit
 * architecture, which for the current state of Apple devices should always be the case.
 */
@implementation MSPMGRSHelper

- (instancetype)init
{
    if (!(self = [super init])) {
        return nil;
    }
    utmSystem = new MSP::CCS::UTM();
    double semiMajor = 0.0, flattening = 0.0;
    utmSystem->getEllipsoidParameters(&semiMajor, &flattening);
    upsSystem = new MSP::CCS::UPS(semiMajor, flattening);
    mgrsSystem = new MSP::CCS::MGRS(semiMajor, flattening, (char *) @"WE".UTF8String);
    return self;
}

- (void)dealloc
{
    delete utmSystem;
    delete upsSystem;
    delete mgrsSystem;
    utmSystem = NULL;
    upsSystem = NULL;
    mgrsSystem = NULL;
}

- (NSString *)mgrsFromWgs84Degrees:(CLLocationCoordinate2D)coord utmZone:(int32_t)zone error:(NSError * __autoreleasing *)error
{
    using namespace MSP::CCS;
    try {
        double latRad = coord.latitude * M_PI / 180.0;
        double lonRad = coord.longitude * M_PI / 180.0;
        GeodeticCoordinates geoCoords(CoordinateType::geodetic, lonRad, latRad, 0.0);
        MGRSorUSNGCoordinates *mgrsCoords = NULL;
        if ([MSPMGRSHelper utmContainsLatitudeInRadians:latRad]) {
            UTMCoordinates *utmCoords = utmSystem->convertFromGeodetic(&geoCoords, zone);
            mgrsCoords = mgrsSystem->convertFromUTM(utmCoords, 5);
            delete utmCoords;
        }
        else {
            UPSCoordinates *upsCoords = upsSystem->convertFromGeodetic(&geoCoords);
            mgrsCoords = mgrsSystem->convertFromUPS(upsCoords, 5);
            delete upsCoords;
        }
        NSString *result = [NSString stringWithUTF8String:mgrsCoords->MGRSString()];
        delete mgrsCoords;
        return result;
    }
    catch (CoordinateConversionException &e) {
        *error = makeConversionError(e);
    }
    return nil;
}

- (CLLocationCoordinate2D)wgs84DegreesFromMgrs:(NSString *)coord error:(NSError * __autoreleasing *)error
{
    using namespace MSP::CCS;
    try {
        MGRSorUSNGCoordinates mgrs(CoordinateType::militaryGridReferenceSystem, coord.UTF8String);
        GeodeticCoordinates *wgs84 = mgrsSystem->convertToGeodetic(&mgrs);
        double latDeg = wgs84->latitude() * 180.0 / M_PI;
        double lonDeg = wgs84->longitude() * 180.0 / M_PI;
        CLLocationCoordinate2D loc = CLLocationCoordinate2DMake(latDeg, lonDeg);
        delete wgs84;
        return loc;
    }
    catch (CoordinateConversionException &e) {
        *error = makeConversionError(e);
    }
    return CLLocationCoordinate2DMake(0.0, 0.0);
}

+ (BOOL) utmContainsLatitudeInRadians:(double)latitude
{
    return latitude >= UTM_MIN_LAT - UTM_LAT_EPSILON && latitude < UTM_MAX_LAT + UTM_LAT_EPSILON;
}

@end
