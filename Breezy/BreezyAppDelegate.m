
#import "BreezyAppDelegate.h"

#define kBgQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) //1
#define kDarkSkyForecastURL [NSURL URLWithString:@"https://api.darkskyapp.com/v1/forecast/"]
#define API_KEY [NSString stringWithFormat:@"<INSERT API KEY>"]

@implementation BreezyAppDelegate

@synthesize geocoder = _geocoder;

- (IBAction)findLocation:(id)sender {

    locationManager = [[CLLocationManager alloc] init];
	locationManager.delegate = self;
	[locationManager startUpdatingLocation];
}

- (void)awakeFromNib
{
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                           selector: @selector(receivedWakeNote:)
                                                               name: NSWorkspaceDidWakeNotification
                                                             object: nil];
    notificationPending = false;

    prefs = [NSUserDefaults standardUserDefaults];
    if(![prefs stringForKey:@"address"])
        [_cityText setStringValue:@"Athens, OH"];
    else
        [_cityText setStringValue:[prefs stringForKey:@"address"]];
    
    [self updateCoordinates:self];
        
    [statusItem setMenu:statusMenu];
    [statusItem setHighlightMode:YES];
    
    [_findLocationButton setImage:[NSImage imageNamed:@"geoloc-arrow"]];
    
    [preferencesItem setAction:@selector(openPreferences:)];
    
    [NSTimer scheduledTimerWithTimeInterval:3600 target:self selector:@selector(fetchData) userInfo:nil repeats:YES ];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    if (!self.geocoder)
        self.geocoder = [[CLGeocoder alloc] init];
        
    [self.geocoder reverseGeocodeLocation:newLocation completionHandler:^(NSArray *placemarks, NSError *error)
    {
        NSLog(@"Reverse geocoding finished");
        currentPlacemark = [placemarks objectAtIndex:0];
        address = [NSString stringWithFormat:@"%@, %@", currentPlacemark.locality, currentPlacemark.administrativeArea];
        [_cityText setStringValue:address];
    }];

    [locationManager stopUpdatingLocation];
    
    prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:address forKey:@"address"];
    
    [self updateCoordinates:self];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"%@",[error localizedDescription]);
}

- (void)fetchData
{
    kLatestDarkSkyForecastURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%f,%f",kDarkSkyForecastURL,API_KEY,latitude,longitude]];
    
    dispatch_async(kBgQueue, ^{
        NSData* data = [NSData dataWithContentsOfURL:
                        kLatestDarkSkyForecastURL];
        [self performSelectorOnMainThread:@selector(fetchForecast:)
                               withObject:data waitUntilDone:YES];
    });
}

- (void)fetchForecast:(NSData *)responseData
{
    NSError* error;
    NSDictionary* json = [NSJSONSerialization
                          JSONObjectWithData:responseData
                          options:kNilOptions
                          error:&error];
    
    NSNumber *tempInt = [json objectForKey:@"currentTemp"];
    tempDouble = [tempInt doubleValue];
    
    prefs = [NSUserDefaults standardUserDefaults];
    type = [prefs integerForKey:@"degreeType"];
    
    if(type == 0) {
        tempDouble = (tempDouble - 32.0) * 5.0/9.0;
        typeString = @"°C";
        [_tempType setSelectedSegment:0];
    }
    else {
        typeString = @"°F";
        [_tempType setSelectedSegment:1];
    }
    
    current = [json objectForKey:@"currentSummary"];
    hour = [json objectForKey:@"hourSummary"];
    day = [json objectForKey:@"daySummary"];
    checkTimeout = [[json objectForKey:@"checkTimeout"] doubleValue];
    
    [currentTemp setTitle: [NSString stringWithFormat:@"Now: %@, %.0f%@", current, tempDouble, typeString]];
    [hourSummary setTitle:[NSString stringWithFormat:@"Next hour: %@",hour]];
    [daySummary setTitle:[NSString stringWithFormat:@"Next day: %@",day]];
    
    [statusItem setToolTip:[NSString stringWithFormat:@"Now: %@, %.0f%@", current, tempDouble, typeString]];
    
    [statusItem setTitle:[NSString stringWithFormat:@"%.0f%@", tempDouble,typeString]];
    
    [center removeScheduledNotification:notification];

    [self updateNotification];
}

- (void)updateNotification
{
    if(!notificationPending)
    {
        NSLog(@"setting a new notification with checkTimeout: %f", checkTimeout);

        notification = [[NSUserNotification alloc] init];
        [notification setTitle:[NSString stringWithFormat:@"Current conditions: %@, %.0f%@", current, tempDouble, typeString]];
        [notification setInformativeText:[NSString stringWithFormat:@"Next hour: %@",hour]];

        [notification setDeliveryDate:[NSDate date]];
        [notification setSoundName:NSUserNotificationDefaultSoundName];
        center = [NSUserNotificationCenter defaultUserNotificationCenter];
        [center setDelegate:self];
        [center scheduleNotification:notification];
        notificationPending = true;
    }
}

-(void)userNotificationCenter:(NSUserNotificationCenter *)c didActivateNotification:(NSUserNotification *)n {
    //Remove the notification
    [c removeDeliveredNotification:n];
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification
{
    notificationPending = false;
}

- (IBAction)openPreferences:(id)sender
{
    if(![preferences isVisible])
    {
        NSApplication *thisApp = [NSApplication sharedApplication];
        [thisApp activateIgnoringOtherApps:YES];
        [preferences makeKeyAndOrderFront: sender];
    }
}

- (IBAction)changeTempType:(id)sender {
    switch([[_tempType cell] selectedSegment])
    {
        case 0:
            type = 0;
            break;
        case 1:
            type = 1;
            break;
        default:
            break;
    }
    
    prefs = [NSUserDefaults standardUserDefaults];
    [prefs setInteger:type forKey:@"degreeType"];

    [center removeScheduledNotification:notification];
    [self fetchData];
}

- (IBAction)updateCoordinates:(id)sender
{    
    if (!self.geocoder)
        self.geocoder = [[CLGeocoder alloc] init];
    
    address = [_cityText stringValue];
    prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:address forKey:@"address"];
        
    [self.geocoder geocodeAddressString:address completionHandler:^(NSArray *placemarks, NSError *error) {
        if ([placemarks count] > 0) {
            CLPlacemark *placemark = [placemarks objectAtIndex:0];
            CLLocation *location = placemark.location;
            CLLocationCoordinate2D coordinate = location.coordinate;
            
            latitude = coordinate.latitude;
            longitude = coordinate.longitude;            
        }
        [center removeScheduledNotification:notification];
        [self fetchData];
    }];
    
    if([preferences isVisible])
        [preferences orderOut:nil];
}

- (IBAction)refreshData:(id)sender {
    [center removeScheduledNotification:notification];
    [self fetchData];
}

- (void)applicationWillTerminate:(NSNotification *)n
{
    NSLog(@"%@",[center scheduledNotifications]);
    [center removeScheduledNotification:notification];
}

- (void)receivedWakeNote: (NSNotification *)n {
    [center removeScheduledNotification:notification];
    [self fetchData];
}

@end
