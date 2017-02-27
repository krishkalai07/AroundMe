//
//  ViewController.m
//  AroundMe
//
//  Created by Krish Kalai on 2/18/17.
//  Copyright © 2017 Krish Kalai. All rights reserved.
//

#import "ViewController.h"
#import <GoogleMaps/GoogleMaps.h>
#import "UNIRest/UNIRest.h"

@interface ViewController ()

@end

@implementation ViewController {
    GMSMapView *_mapView;
    BOOL _firstLocationUpdate;
    UILabel *info;
    WKWebView *webView;
    NSString *structuresEtag;
    UNIJsonNode *structuresData;
    UNIJsonNode *lastKnownLocationData;
    double latitude, longitude, elevation;
    double prev_lat, prev_long;
}

/*!
 * Creates the view with the map panel and information panel
 */
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    latitude = 0.0;
    longitude = 0.0;
    prev_lat = 0.0;
    prev_long = 0.0;
    
    //Create the views
    [self showMapView];
    [self createInformationView];
    [self showInformation];
    
    //Check last location buffer. Since last location buffer is empty, make the call.
    [self makeStructuresRequest];
    
    /*
    double delayInSeconds = 5.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
       //NSLog(@"Second call...");
        [self makeStructuresRequest];
    });
     
    
    [self makeLocateRequest:@"b3b7bffa77ad51fee6d3d3ed62c648f2"
                   latitude:@"37.38642893"
                  longitude:@"-122.10951252"];
    
    [self showInformation:@"Got some info that you will never see."];
     */
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*!
 * Creates the map view with Google Maps taking 2/3 of the screen.
 */
- (void)showMapView {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    
    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:-33.868
                                                            longitude:151.2086
                                                                 zoom:12];
    
    _mapView = [GMSMapView mapWithFrame:CGRectMake(0, 0, screenWidth, screenHeight - screenHeight/3) camera:camera];
    _mapView.settings.compassButton = YES;
    _mapView.settings.myLocationButton = YES;
    
    // Listen to the myLocation property of GMSMapView.
    [_mapView addObserver:self
               forKeyPath:@"myLocation"
                  options:NSKeyValueObservingOptionNew
                  context:NULL];
    
    //self.view = _mapView;
    self.view.backgroundColor = [UIColor colorWithRed:0.0/255 green:128.0/255 blue:128.0/255 alpha:1.0];
    [self.view addSubview:_mapView];
    
    // Ask for My Location data after the map has already been added to the UI.
    dispatch_async(dispatch_get_main_queue(), ^{
        _mapView.myLocationEnabled = YES;
    });
}

/*!
 * Creates the information panel taking the bottom 1/3 of the screen
 */
- (void)createInformationView {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    
    webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, screenHeight - screenHeight/3, screenWidth, screenHeight/3)];
    webView.opaque = false;
    
    [self.view addSubview:webView];
}

/*!
 * Displays a message of the nodes the user is in. The message is displayed in the webView.
 */
- (void)showInformation {
    NSString *message = @"Not inside any known structures.";
    if ([lastKnownLocationData.JSONArray count] > 0) {
        NSString *temp_message = [[NSString alloc] init];
        for (NSDictionary *item in lastKnownLocationData.JSONArray) {
            temp_message = [temp_message stringByAppendingString:[item objectForKey:@"Information"]];
            temp_message = [temp_message stringByAppendingString:@"<br>"];
        }
        message = temp_message;
    }
    
    //NSString *html = [NSString stringWithFormat:@"<font size=\"18\"><center><bold>%@ <br> %f %f</bold></center></font>", message, latitude, longitude];
    NSString *html = [NSString stringWithFormat:@"<font size=\"18\"><center><bold>%@</bold></center></font>", message];
    [webView loadHTMLString:html baseURL:nil];
}

/*!
 * Debug function to show the latitude, longitude and elevation of the user.
 */
- (void)showCoordinates {
    NSString *html = [NSString stringWithFormat:@"<font size=\"18\"><center><bold>%.15f, %.15f <br> %.15f</bold></center></font>", latitude, longitude, elevation];
    [webView loadHTMLString:html baseURL:nil];
}

/*!
 * Check if the user is inside any of the structures
 */
- (NSString *)checkInsideStructures {
    for (NSDictionary *data in structuresData.JSONArray) {
        if([self isInsidePolygon:[data objectForKey:@"Polygon"]]) {
            return [data objectForKey:@"ID"];
        }
    }
    return @"";
}

/*!
 * Determines if the point is inside the polygon.
 *
 * \param[in] polygon The polygon of coordinates, where values in odd indecies are latitudes and even indecies are longitudes.
 */
- (BOOL)isInsidePolygon:(NSString *)polygon {
    NSArray *StringPolygonAsArray = [polygon componentsSeparatedByString:@","];
    double doubleArray[[StringPolygonAsArray count]];
    
    for (int i = 0; i < [StringPolygonAsArray count]; i++) {
        doubleArray[i] = [StringPolygonAsArray[i] doubleValue];
    }

    long length = [StringPolygonAsArray count];
    int counter = 0;
    double lat1, lon1, lat2, lon2, x_intercept;
    lat1 = doubleArray[0];
    lon1 = doubleArray[1];
    for (int i = 2; i < length; i+=2) {
        int index = i % (length - 1);
        lat2 = doubleArray[index];
        lon2 = doubleArray[index+1];
        if (longitude >= MIN(lon1, lon2)) {
            if (longitude <= MAX(lon1, lon2)) {
                if (latitude <= MAX(lat1, lat2)) {
                    if (lon1 != lon2) {
                        x_intercept = (longitude - lon1) * (lat2 - lat1) / (lon2 - lon1) + lat1;
                        if (lat1 == lat2 || latitude <= x_intercept) {
                            counter++;
                        }
                    }
                }
            }
        }
        lat1 = lat2;
        lon1 = lon2;
    }
    return counter % 2 != 0;
}

/*!
 * \brief Updates the location and etag if neccessary. If the app has a valid lastKnownData, then test if the user is still inside any node.
 * If the app has no lastKnownData, then test for if the app has a valid etag. If there is a valid etag, call locate. If not, then call
 * /v1/structures and refresh all data.
 *
 *
 * \pre "Significant" (0.000001 arcdegrees) change in location.
 * \post Updates structuresData and lastLocationData as necessary.
 */
- (void)checkLocationChange {
    // Check if last known location data exists
    if ([lastKnownLocationData.JSONArray count] > 0) {
        // If it exists, then check if the user is still inside the last node.
        NSDictionary *currentNode = [lastKnownLocationData.JSONArray lastObject];
        if ([self isInsidePolygon:[currentNode objectForKey:@"Polgon"]]) {
            // If the user is inside, the no change is needed: return
            return;
        }
        else {
            // If the user is not inside the last node, check if inside the fist node (must be a structure).
            currentNode = [lastKnownLocationData.JSONArray firstObject];
            if ([self isInsidePolygon:[currentNode objectForKey:@"Polgon"]]) {
                // If the user is still inside the structre, call locate
                [self makeLocateRequest:[currentNode objectForKey:@"ID"]
                               latitude:[NSString stringWithFormat:@"%f", latitude]
                              longitude:[NSString stringWithFormat:@"%f", longitude]
                              elevation:[NSString stringWithFormat:@"%f", elevation]];
            }
            else {
                // If the user is not inside the structure, check if inside any structure.
                NSString *ID = [self checkInsideStructures];
                if (!([ID  isEqual: @""])) {
                    // If there is a valid etag, call locate
                    [self makeLocateRequest:ID
                                   latitude:[NSString stringWithFormat:@"%f", latitude]
                                  longitude:[NSString stringWithFormat:@"%f", longitude]
                                  elevation:[NSString stringWithFormat:@"%f", elevation]];
                }
                else {
                    // If the etag is invalid, call structures
                    [self makeStructuresRequest];
                }
            }
        }
    }
    else {
        // No data is found; make a request to refresh everything
        [self makeStructuresRequest];
    }
}

/*!
 * Method that checks if the user's location has changed. If the app detects a change of more than 0.000001 arcdegrees,
 * then set prev_lat and prev_long with the new values and return true.
 */
- (BOOL)hasLocationChanged {
    if (fabs(prev_lat - latitude) > 0.000001 || fabs(prev_long - longitude) > 0.000001) {
        prev_lat = latitude;
        prev_long = longitude;
        return true;
    }
    return false;
}


#pragma mark - KVO updates

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (!_firstLocationUpdate) {
        // If the first location update has not yet been recieved, then jump to that location.
        _firstLocationUpdate = YES;
        CLLocation *location = [change objectForKey:NSKeyValueChangeNewKey];
        
        latitude = location.coordinate.latitude;
        longitude = location.coordinate.longitude;
        
        _mapView.camera = [GMSCameraPosition cameraWithTarget:location.coordinate
                                                         zoom:14];
    }
    else {
        CLLocation *location = [change objectForKey:NSKeyValueChangeNewKey];
        [self showInformation];
        latitude = location.coordinate.latitude;
        longitude = location.coordinate.longitude;
        elevation = location.altitude;
        
        if ([self hasLocationChanged]) {
            [self checkLocationChange];
        }
    }
}

/*!
 * Makes an asyncronous request to .../v1/locate and updates lastKnownLocationData.
 *
 * \param[in] structureId The id of the structure that the user is in.
 * \param[in] lat The user's current latitude.
 * \param[in] lon The user's current longitude.
 * \param[in] ele The user's current elevation.
 */
- (void)makeLocateRequest:(NSString *)structureId
                 latitude:(NSString *)lat
                longitude:(NSString *)lon
                elevation:(NSString *)ele {
    NSDictionary *headers = @{@"accept": @"application/json"};
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    [parameters setObject:lat forKey:@"lati"];
    [parameters setObject:lon forKey:@"long"];
    [parameters setObject:ele forKey:@"elev"];
 
    [[UNIRest get:^(UNISimpleRequest *request) {
        NSString *url = [NSString stringWithFormat:@"https://morning-castle-21357.herokuapp.com/v1/locate/%@", structureId];
        [request setUrl:url];
        [request setHeaders:headers];
        [request setParameters:parameters];
    }] asJsonAsync:^(UNIHTTPJsonResponse* response, NSError *error) {
        // This is the asyncronous callback block
        NSInteger code = response.code;
        //NSDictionary *responseHeaders = response.headers;
        UNIJsonNode *body = response.body;
        //NSData *rawBody = response.rawBody;
        
        if (code == 200 && [body.JSONArray count] > 0) {
            lastKnownLocationData = body;
        }
        else {
            lastKnownLocationData = nil;
        }
        [self showInformation];
    }];
}

/*!
 * Makes an asyncronous request to .../v1/structures and updates the structuresEtag and structuresData.
 */
- (void)makeStructuresRequest {
    NSDictionary *headers = @{@"accept": @"application/json"};
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    if (structuresEtag == nil) {
        [parameters setObject:@"etag" forKey:@"etag"];
    }
    else {
        [parameters setObject:structuresEtag forKey:@"etag"];
    }
    
    [[UNIRest get:^(UNISimpleRequest *request) {
        [request setUrl:@"https://morning-castle-21357.herokuapp.com/v1/structures/"];
        [request setHeaders:headers];
        [request setParameters:parameters];
    }] asJsonAsync:^(UNIHTTPJsonResponse* response, NSError *error) {
        // This is the asyncronous callback block
        NSInteger code = response.code;
        NSDictionary *responseHeaders = response.headers;
        UNIJsonNode *body = response.body;
        //NSData *rawBody = response.rawBody;
    
        if (code == 200) {
            if (body.array != nil) {
                structuresData = body;
                structuresEtag = [responseHeaders objectForKey:@"ETag"];
            }
            NSString *ID;
            if(![(ID = [self checkInsideStructures])  isEqual: @""]) {
                [self makeLocateRequest:ID latitude:[NSString stringWithFormat:@"%f", latitude]
                                          longitude:[NSString stringWithFormat:@"%f", longitude]
                                          elevation:[NSString stringWithFormat:@"%f", elevation]];
            }
        }
    }];
}
@end
