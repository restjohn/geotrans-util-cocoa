//
//  MGRSHelper.h
//  GEOTRANS-CocoaPods
//
//  Created by Robert St. John on 9/24/18.
//  Copyright © 2018 GEOINT Services Mobile Apps. All rights reserved.
//

#ifndef MGRSHelper_h
#define MGRSHelper_h
    

#import "CoreLocation/CoreLocation.h"


FOUNDATION_EXPORT NSErrorDomain const MSPMGRSErrorDomain;
FOUNDATION_EXPORT NSInteger const MSPMGRSError;

/**
 * MGRSHelper is a simple interface to the GEOTRANS C++ library to convert MGRS coordinates
 * to and from WGS84 geodetic latitude and longitude degrees.  While you can create as many
 * instances of this class as you please, there's really only a need to have one if you are
 * going to be performing frequent conversions in your app.
 */
@interface MSPMGRSHelper : NSObject

/**
 * Convert the given WGS84 geodetic longitude/latitude coordinate to an MGRS coordinate.
 * The utmZone parameter can be 0, to use the default-calculated UTM zone for the result
 * MGRS coordinate, or a valid UTM zone 1-60 to force the result MGRS coordinate to the
 * coordinates of the given zone.  Currently, GEOTRANS only allows overriding the UTM
 * zone +/- one zone to the east or west of the default calculated zone.
 */
- (NSString *) mgrsFromWgs84Degrees:(CLLocationCoordinate2D)coord utmZone:(int32_t)zone error:(NSError * __autoreleasing *)error;

/**
 * Convert the given MGRS coordinate string to WGS84 geodetic latitude and longitude.
 */
- (CLLocationCoordinate2D) wgs84DegreesFromMgrs:(NSString *)coord error:(NSError * __autoreleasing *)error;

@end


#endif /* MGRSHelper_h */
