//
//  MGRSHelperSpec.m
//  GEOTRANS
//
//  Created by Robert St. John on 9/25/18.
//  Copyright 2018 restjohn. All rights reserved.
//

#import "MSPMGRSHelper.h"
#import "YLFileReader.h"

#define COL_TEST_ID 0
#define COL_GEO_MGRS_LAT 7
#define COL_GEO_MGRS_LON 8
#define COL_GEO_MGRS_EXPECTED_MGRS 13
#define COL_MGRS_GEO_MGRS 7
#define COL_MGRS_GEO_EXPECTED_LAT 13
#define COL_MGRS_GEO_EXPECTED_LON 14

@interface MSPMGRSHelperTestUtil : NSObject

- (void)loadGeoToMgrsTestRecords:(void (^)(NSString *testId, CLLocationCoordinate2D wgs84Coord, NSString *expectedMgrs))consumer;
- (void)loadMgrsToGeoTestRecords:(void (^)(NSString *testId, NSString *mgrsCoord, CLLocationCoordinate2D expectedLocation))consumer;

@end

@implementation MSPMGRSHelperTestUtil {
    NSBundle *testDataBundle;
}

- (instancetype)init
{
    self = [super init];
    NSBundle *bundle = [NSBundle bundleWithIdentifier:@"org.cocoapods.GEOTRANS"];
    NSString *testDataBundlePath = [bundle.resourcePath stringByAppendingPathComponent:@"GEOTRANS-TestData.bundle"];
    testDataBundle = [[NSBundle alloc] initWithPath:testDataBundlePath];
    return self;
}

- (void)loadGeoToMgrsTestRecords:(void (^)(NSString *testId, CLLocationCoordinate2D wgs84Coord, NSString *expectedMgrs))consumer
{
    NSString *testDataPath = [testDataBundle pathForResource:@"geoToMgrs_WE" ofType:@"txt"];
    if (!testDataPath) {
        failure(@"failed to load geoToMgrs_WE");
    }
    YLFileReader *testDataReader = [[YLFileReader alloc] initWithFilePath:testDataPath encoding:NSUTF8StringEncoding];
    // skip header
    [testDataReader readLine];
    [testDataReader readLine];
    while (!testDataReader.lastError) {
        NSString *testLine = [testDataReader readLine];
        NSArray *testValues = [testLine componentsSeparatedByString:@"\t"];
        if (testValues.count < COL_GEO_MGRS_EXPECTED_MGRS) {
            continue;
        }
        NSString *testId = testValues[COL_TEST_ID];
        NSString *lat = testValues[COL_GEO_MGRS_LAT];
        NSString *lon = testValues[COL_GEO_MGRS_LON];
        NSString *expectedMgrs = testValues[COL_GEO_MGRS_EXPECTED_MGRS];
        CLLocationCoordinate2D loc = CLLocationCoordinate2DMake(lat.doubleValue, lon.doubleValue);
        consumer(testId, loc, expectedMgrs);
    }
}

- (void)loadMgrsToGeoTestRecords:(void (^)(NSString *testId, NSString *mgrsCoord, CLLocationCoordinate2D expectedLocation))consumer
{
    NSString *testDataPath = [testDataBundle pathForResource:@"mgrsToGeo_WE" ofType:@"txt"];
    if (!testDataPath) {
        failure(@"failed to load mgrsToGeo_WE");
    }
    YLFileReader *testDataReader = [[YLFileReader alloc] initWithFilePath:testDataPath encoding:NSUTF8StringEncoding];
    // skip header
    [testDataReader readLine];
    [testDataReader readLine];
    while (!testDataReader.lastError) {
        NSString *testLine = [testDataReader readLine];
        NSArray *testValues = [testLine componentsSeparatedByString:@"\t"];
        if (testValues.count < COL_MGRS_GEO_EXPECTED_LON) {
            continue;
        }
        NSString *testId = testValues[COL_TEST_ID];
        NSString *mgrs = testValues[COL_MGRS_GEO_MGRS];
        NSString *lat = testValues[COL_MGRS_GEO_EXPECTED_LAT];
        NSString *lon = testValues[COL_MGRS_GEO_EXPECTED_LON];
        CLLocationCoordinate2D loc = CLLocationCoordinate2DMake(lat.doubleValue, lon.doubleValue);
        consumer(testId, mgrs, loc);
    }
}

@end

SpecBegin(MSPMGRSHelper)

describe(@"MSPMGRSHelper", ^{

    MSPMGRSHelperTestUtil *util = [[MSPMGRSHelperTestUtil alloc] init];

    beforeAll(^{

    });
    
    beforeEach(^{

    });

    it(@"converts wgs84 to mgrs", ^{

        MSPMGRSHelper *helper = [[MSPMGRSHelper alloc] init];
        NSMutableArray<NSString *> *failures = [NSMutableArray array];
        [util loadGeoToMgrsTestRecords:^(NSString *testId, CLLocationCoordinate2D wgs84Coord, NSString *expectedMgrs) {
            NSString *mgrs = [helper mgrsFromWgs84Degrees:wgs84Coord utmZone:0 error:NULL];
            if (![mgrs isEqualToString:expectedMgrs]) {
                [failures addObject:[NSString stringWithFormat:@"%@ %f %f expected %@ but was %@", testId, wgs84Coord.longitude, wgs84Coord.latitude, expectedMgrs, mgrs]];
            }
        }];
        if (failures.count > 0) {
            [failures insertObject:[NSString stringWithFormat:@"%ld test cases failed:", failures.count] atIndex:0];
            failure([failures componentsJoinedByString:@"\n  "]);
        }
    });

    it(@"converts mgrs to wgs84", ^{

        MSPMGRSHelper *helper = [[MSPMGRSHelper alloc] init];
        NSMutableArray<NSString *> *failures = [NSMutableArray array];
        [util loadMgrsToGeoTestRecords:^(NSString *testId, NSString *mgrs, CLLocationCoordinate2D expectedLoc) {
            CLLocationCoordinate2D loc = [helper wgs84DegreesFromMgrs:mgrs error:NULL];
            double latDiff = fabs(loc.latitude - expectedLoc.latitude);
            double lonDiff = fabs(loc.longitude - expectedLoc.longitude);
            if (latDiff > 1.0e-6 || lonDiff > 1.0e-6) {
                [failures addObject:[NSString stringWithFormat:@"%@ %@ expected %f %f but was %f %f", testId, mgrs,
                    expectedLoc.longitude, expectedLoc.latitude, loc.longitude, loc.latitude]];
            }
        }];
        if (failures.count > 0) {
            [failures insertObject:[NSString stringWithFormat:@"%ld test cases failed:", failures.count] atIndex:0];
            failure([failures componentsJoinedByString:@"\n  "]);
        }
    });

    it(@"handles bad mgrs string", ^{

        MSPMGRSHelper *helper = [[MSPMGRSHelper alloc] init];
        NSError *error;
        @try {
            [helper wgs84DegreesFromMgrs:@"12345" error:&error];
        }
        @catch (...) {
            failure([NSString stringWithFormat:@"caught exception"]);
        }

        expect(error).toNot.beNil();
        expect(error.localizedDescription.length).to.beGreaterThan(@0);
        expect(error.domain).to.equal(MSPMGRSErrorDomain);
        expect(error.code).to.equal(MSPMGRSError);
    });

    it(@"handles bad latitude", ^{

        MSPMGRSHelper *helper = [[MSPMGRSHelper alloc] init];
        NSError *error;
        @try {
            [helper mgrsFromWgs84Degrees:CLLocationCoordinate2DMake(91.0, 0.0) utmZone:0 error:&error];
        }
        @catch (...) {
            failure([NSString stringWithFormat:@"caught exception"]);
        }

        expect(error).toNot.beNil();
        expect(error.localizedDescription.length).to.beGreaterThan(@0);
        expect(error.domain).to.equal(MSPMGRSErrorDomain);
        expect(error.code).to.equal(MSPMGRSError);
    });

    it(@"handles bad longitude", ^{

        MSPMGRSHelper *helper = [[MSPMGRSHelper alloc] init];
        NSError *error;
        @try {
            [helper mgrsFromWgs84Degrees:CLLocationCoordinate2DMake(0.0, 361.0) utmZone:0 error:&error];
        }
        @catch (...) {
            failure([NSString stringWithFormat:@"caught exception"]);
        }

        expect(error).toNot.beNil();
        expect(error.localizedDescription.length).to.beGreaterThan(@0);
        expect(error.domain).to.equal(MSPMGRSErrorDomain);
        expect(error.code).to.equal(MSPMGRSError);
    });

    it(@"handles bad utm zone", ^{

        MSPMGRSHelper *helper = [[MSPMGRSHelper alloc] init];
        NSError *error;
        @try {
            [helper mgrsFromWgs84Degrees:CLLocationCoordinate2DMake(0.0, 0.0) utmZone:-1 error:&error];
        }
        @catch (...) {
            failure([NSString stringWithFormat:@"caught exception"]);
        }

        expect(error).toNot.beNil();
        expect(error.localizedDescription.length).to.beGreaterThan(@0);
        expect(error.domain).to.equal(MSPMGRSErrorDomain);
        expect(error.code).to.equal(MSPMGRSError);

        @try {
            [helper mgrsFromWgs84Degrees:CLLocationCoordinate2DMake(0.0, 0.0) utmZone:61 error:&error];
        }
        @catch (...) {
            failure([NSString stringWithFormat:@"caught exception"]);
        }

        expect(error).toNot.beNil();
        expect(error.localizedDescription.length).to.beGreaterThan(@0);
        expect(error.domain).to.equal(MSPMGRSErrorDomain);
        expect(error.code).to.equal(MSPMGRSError);
    });

    afterEach(^{

    });
    
    afterAll(^{

    });
});

SpecEnd
