#import <Cocoa/Cocoa.h>
#import <CoreLocation/CoreLocation.h>

@interface BreezyAppDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate, CLLocationManagerDelegate> {
    IBOutlet NSMenu *statusMenu;
    NSStatusItem *statusItem;
    
    NSURL *kLatestDarkSkyForecastURL;
    
    CLLocationManager *locationManager;
    CLGeocoder *_geocoder;
    
    CLPlacemark *currentPlacemark;
    
    IBOutlet NSMenuItem *daySummary;
    IBOutlet NSMenuItem *hourSummary;
    IBOutlet NSMenuItem *currentTemp;
    IBOutlet NSMenuItem *preferencesItem;
        
    IBOutlet NSWindow *preferences;

    __weak NSTextField *_cityText;
    
    NSString* current;
    NSString* hour;
    NSString* day;
    NSString *typeString;
    double checkTimeout;
    NSString *address;
    
    BOOL notificationPending;
    NSUserNotification *notification;
    NSUserNotificationCenter *center;
    
    double latitude;
    double longitude;
    
    __weak NSSegmentedControl *_tempType;
    int type;
    double tempDouble;
    
    NSUserDefaults *prefs;
    
    __weak NSButton *_findLocationButton;
}

@property (nonatomic, strong) CLGeocoder *geocoder;
@property (weak) IBOutlet NSTextField *cityText;
@property (weak) IBOutlet NSSegmentedControl *tempType;
@property (weak) IBOutlet NSButton *findLocationButton;
@end
