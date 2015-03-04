//
//  AGDemoScreenViewController.m
//  AGLocationDispatcher
//
//  Created by Vermillion on 09.02.15.
//  Copyright (c) 2015 Agilie. All rights reserved.
//

#import <MapKit/MapKit.h>
#import <MapKit/MKGeodesicPolyline.h>
#import "AGDemoScreenViewController.h"

static NSString *const kMapAnnotationIdentifier = @"mapAnnotationIdentifier";

#define RGB255(R, G, B) [UIColor colorWithRed:R/255.f green:G/255.f blue:B/255.f alpha:1.0f]

@interface AGDemoScreenViewController ()<MKMapViewDelegate>

@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UILabel *currentSpeedLabel;
@property (weak, nonatomic) IBOutlet UILabel *averageSpeedLabel;
@property (strong, nonatomic) AGLocation *lastPoint;
@property (strong, nonatomic) AGRouteDispatcher *routeDispatch;
@property (strong, nonatomic) AGAnnotation *currentPositionAnnotation;
@property (assign, nonatomic) BOOL isTrackingNow;
@property (strong, nonatomic) AGRoute *currentRoute;
@property (strong, nonatomic) AGRouteDispatcher *routeManager;

@end

@implementation AGDemoScreenViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mapView.delegate = self;
    self.currentRoute = [AGRoute new];
    [self.currentRoute setSessionId:@"route00001"];
    [self.currentRoute setRefreshTimeout:kAGLocationUpdateIntervalOneSec];
    [self.currentRoute setMoveType:0];
    self.routeDispatch = [[AGRouteDispatcher alloc] initWithUpdatingInterval:kAGLocationUpdateIntervalOneSec andDesiredAccuracy:kAGHorizontalAccuracyNeighborhood];
    self.isTrackingNow = NO;
    [self.stopButton setEnabled:NO];

    self.routeManager = [AGRouteDispatcher new];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startTracking];
}

- (void)startTracking {
    [self.routeDispatch startUpdatingLocationAndSpeedWithBlock:^(CLLocationManager *manager, AGLocation *newLocation, AGLocation *oldLocation, NSNumber *speed) {
        if (!self.currentPositionAnnotation) {
            self.currentPositionAnnotation = [[AGAnnotation alloc] initWithType:AGAnnotationTypeStart location:newLocation];
            [self.mapView addAnnotation:self.currentPositionAnnotation];
        } else {
            [self.currentPositionAnnotation setCoordinate:newLocation.coordinate];
        }
        [self centerMapWithUserCoordinate:newLocation.coordinate];
        if (self.isTrackingNow) {

            [self.currentRoute addRoutePoint:newLocation];

            if (self.lastPoint) {
                CLLocationCoordinate2D coordinates[2];
                coordinates[0] = self.lastPoint.coordinate;
                coordinates[1] = newLocation.coordinate;
                MKGeodesicPolyline *geoPolyline = [MKGeodesicPolyline polylineWithCoordinates:coordinates count:2];
                if (geoPolyline) {
                    [self.mapView addOverlay:geoPolyline];
                }
            }

            //speed
            int calculatedSpeed = [speed intValue];
            if (calculatedSpeed > -1) {
                [self.currentRoute addSpeed:calculatedSpeed];
                [self.currentSpeedLabel setText:[NSString stringWithFormat:@"cur speed: %i km/h", calculatedSpeed]];
            }

            int avgSpeed = (int)[self.currentRoute averageSpeed];
            if (avgSpeed > 0) {
                [self.averageSpeedLabel setText:[NSString stringWithFormat:@"avg speed: %i km/h", avgSpeed]];
            }
        }

        self.lastPoint = newLocation;
    }                                               errorBlock:^(CLLocationManager *manager, NSError *error) {
        NSLog(@"Fail");
    }];
}

- (void)didChangeRegionAuthorizationStatus:(CLAuthorizationStatus)status {
    [self startTracking];
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        MKPolyline *route = overlay;
        MKPolylineRenderer *routeRenderer = [[MKPolylineRenderer alloc] initWithPolyline:route];
        routeRenderer.strokeColor = [UIColor greenColor];
        routeRenderer.lineWidth = 4;
        return routeRenderer;
    }
    else {return nil;}
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[AGAnnotation class]]) {
        NSString *imageName = [(AGAnnotation *)annotation annotationImageName];
        if (imageName) {
            MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:kMapAnnotationIdentifier];
            if (!annotationView) {
                annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:kMapAnnotationIdentifier];
            } else {
                annotationView.annotation = annotation;
            }
            annotationView.image = [UIImage imageNamed:imageName];
            return annotationView;
        }
    }
    return nil;
}

- (void)centerMapWithUserCoordinate:(CLLocationCoordinate2D)coordinate {

    [self.mapView setCenterCoordinate:coordinate animated:YES];
    MKCoordinateRegion region = MKCoordinateRegionMake(coordinate, MKCoordinateSpanMake(0.004f, 0.004f));
    region = [self.mapView regionThatFits:region];
    [self.mapView setRegion:region animated:YES];
}

- (IBAction)startButtonPressed:(id)sender {
    self.isTrackingNow = YES;
    [self.startButton setEnabled:NO];
    [self.stopButton setEnabled:YES];
    self.lastPoint = nil;
}

- (IBAction)stopButtonPressed:(id)sender {
    self.isTrackingNow = NO;
    [self.stopButton setEnabled:NO];
    [self.startButton setEnabled:YES];
    self.lastPoint = nil;
    [self.currentSpeedLabel setText:@"cur speed:"];
    [self.averageSpeedLabel setText:@"avg speed:"];
    [self.currentRoute finishRoute];
    [self.routeManager saveRoute:self.currentRoute name:[self.currentRoute sessionId]];
}

@end
