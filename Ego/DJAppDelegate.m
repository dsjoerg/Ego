//
//  DJAppDelegate.m
//  Ego
//
//  Created by David Joerg on 8/27/14.
//  Copyright (c) 2014 David Joerg. All rights reserved.
//

#import "DJAppDelegate.h"
#include <sys/sysctl.h>
#import "AFHTTPClient.h"
#import <dlfcn.h>
#import <AudioToolbox/AudioToolbox.h>
#include <notify.h>

#define SBSERVPATH "/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices"

@implementation DJAppDelegate

// global state is really evil.  for example:
static BOOL locked = NO;

static NSDate *timeOfLastPost = nil;
static const int POST_INTERVAL_SECONDS = 59.0;
static const int CURFEW_CHECK_INTERVAL_SECONDS = 10.0;
static NSDateFormatter *_dateFormatter;

// EVIL MAGIC TO FIND OUT WHICH APP IS IN FRONT
// http://stackoverflow.com/questions/8252396/how-to-determine-which-apps-are-background-and-which-app-is-foreground-on-ios-by
-(NSString *)getFrontmostApp
{
	mach_port_t *port;
	void *lib = dlopen(SBSERVPATH, RTLD_LAZY);

	mach_port_t *(*SBSSpringBoardServerPort)() = dlsym(lib, "SBSSpringBoardServerPort");
	port = (mach_port_t *)SBSSpringBoardServerPort();
	
	void *(*SBFrontmostApplicationDisplayIdentifier)(mach_port_t *port, char *result) = dlsym(lib, "SBFrontmostApplicationDisplayIdentifier");
	
	// reserve memory for name
	char appId[256];
	memset(appId, 0, sizeof(appId));
	
	// retrieve front app name
	SBFrontmostApplicationDisplayIdentifier(port, appId);
	
	NSString *frontmost = [NSString stringWithCString:appId encoding:NSASCIIStringEncoding];
	NSString *frontmostLocalized = [self localizedNameForDisplayIdentifier:frontmost];
	
	// close dynlib
	dlclose(lib);

	NSLog(@"WHOA IT IS %@ (%@)", frontmostLocalized, frontmost);

	return frontmostLocalized;
}

// from http://stackoverflow.com/questions/16366701/is-it-possible-to-get-the-launch-time-of-pid
- (NSString *) localizedNameForDisplayIdentifier:(NSString *)displayIdentifier {
	if ([displayIdentifier length] == 0) {
		return @"";
	}
	
	NSString *localizedName;
	
	mach_port_t *port;
	void *lib = dlopen(SBSERVPATH, RTLD_LAZY);
	
	mach_port_t *(*SBSSpringBoardServerPort)() = dlsym(lib, "SBSSpringBoardServerPort");
	port = (mach_port_t *)SBSSpringBoardServerPort();

	void* (*SBDisplayIdentifierForPID)(mach_port_t* port, int pid,char * result) =
	dlsym(lib, "SBDisplayIdentifierForPID");

	//CTL_KERN，KERN_PROC,KERN_PROC_ALL
	int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL ,0};
	int status;
	struct kinfo_proc *process = NULL;
	size_t size;
	
	status  = sysctl(mib, 4, NULL, &size, NULL, 0);
	process   = malloc(size);
	status  = sysctl(mib, 4, process, &size, NULL, 0);
	
	if (status == 0) {
		if (size % sizeof(struct kinfo_proc) == 0) {
			int nprocess = (int)(size / sizeof(struct kinfo_proc));
			if (nprocess) {
				for (int i = nprocess - 1; i >= 0; i--) {
					
					char * appid[256];
					memset(appid,sizeof(appid),0);
					int pid = process[i].kp_proc.p_pid;
					SBDisplayIdentifierForPID(port, pid, (char *)appid);
					NSString *appIDString = [NSString stringWithCString:(char *)appid encoding:NSASCIIStringEncoding];
					
					if ([appIDString isEqualToString:displayIdentifier]) {
						localizedName = [[NSString alloc] initWithFormat:@"%s", process[i].kp_proc.p_comm];
					}
					
				}
				free(process);
				process = NULL;
				
				return localizedName;
			}
		}
	}
	return nil;
}



// DETERMINING LOCK STATE

// http://stackoverflow.com/a/24927507/593053
/* Register app for detecting lock state */
-(void)registerAppforDetectLockState {
	
	int notify_token;
	notify_register_dispatch("com.apple.springboard.lockstate", &notify_token, dispatch_get_main_queue(), ^(int token) {
		uint64_t state = UINT64_MAX;
		notify_get_state(token, &state);
		if(state == 0) {
			locked = NO;
			NSLog(@"unlock device");
		} else {
			locked = YES;
			NSLog(@"lock device");
		}
	});
}

// NETWORKING

-(NSString *)baseServerURL
{
    BOOL developmentServer = NO;
    NSString *protocol;
    NSString *apiHost;
    
    if (developmentServer) {
        protocol = @"http";
        apiHost = @"localhost:3000";
    } else {
        protocol = @"https";
        apiHost = @"superego.herokuapp.com";
    }
    return [NSString stringWithFormat:@"%@://%@", protocol, apiHost];
}

-(NSString *)curfewActivePath
{
	NSString *email = @"dsjoerg@gmail.com";
    return [NSString stringWithFormat:@"/api/v1/curfew/is_active?email=%@", email];
}

-(NSString *)textObservationPath
{
    return @"/api/v1/text_observation";
}


-(void)checkCurfewAndIfLateDo:(void (^)(void))completionHandler
{
	AFHTTPClient *client = [AFHTTPClient clientWithBaseURL:[NSURL URLWithString:[self baseServerURL]]];
	[client getPath:[self curfewActivePath] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
		NSString *responseString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
		if ([responseString isEqualToString:@"true"]) {
			completionHandler();
		}
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		NSLog(@"Failed! With error %@", error);
	}];
	
}

-(void)postToServerApp: (NSString *)frontmostApp
{
	NSDate *now = [NSDate date];
	NSString *nowString = [_dateFormatter stringFromDate:now];
	NSString *deviceIDString = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
	NSString *stringToPost = [NSString stringWithFormat:@"Device %@, locked %i, frontmost %@",
							  deviceIDString, locked, frontmostApp];
							  
	NSDictionary *params = @{@"text": stringToPost,
							 @"device": deviceIDString,
							 @"when": nowString,
							 @"frontmostApp": frontmostApp,
							 @"locked": @(locked)};
				
	AFHTTPClient *client = [AFHTTPClient clientWithBaseURL:[NSURL URLWithString:[self baseServerURL]]];
	[client postPath:[self textObservationPath] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
			NSLog(@"POST SUCCEEDED");
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		NSLog(@"Failed! With error %@", error);
	}];
}

// COMPLAINING

-(void)complainForApp:(NSString *)frontmostApp
{
	NSArray *games = @[@"Twitch", @"Clash of Clans", @"eldorado", @"hearthstone", @"Anthill", @"MaxAxe", @"Tiny Wings"];
	NSArray *timewasters = @[@"AlienBlue", @"Facebook"];
	
	UILocalNotification* localNotification = [[UILocalNotification alloc] init];
	localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:1];
	localNotification.timeZone = [NSTimeZone defaultTimeZone];
	
	if ([games containsObject:frontmostApp]) {
		localNotification.alertBody = @"LEAST OF ALL A GAME";
		localNotification.soundName = @"Klaxon_horn_64kb.mp3";
	} else if ([timewasters containsObject:frontmostApp]) {
		localNotification.alertBody = @"STOP READING";
		localNotification.soundName = @"minerals.mp3";
	} else {
		localNotification.alertBody = @"GO TO SLEEP ITS LATE";
		localNotification.soundName = @"supply.mp3";
	}
	
	[[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
}

-(BOOL)longEnoughSinceLastPost
{
	if (!timeOfLastPost) {
		timeOfLastPost = [NSDate date];
		return YES;
	}
	NSTimeInterval timeSinceLastPost = -1 * [timeOfLastPost timeIntervalSinceNow];
	if (timeSinceLastPost >= POST_INTERVAL_SECONDS) {
		timeOfLastPost = [NSDate date];
		return YES;
	}
	return NO;
}

-(void)periodicTask
{
	NSString *frontmostApp = [self getFrontmostApp];
	
	if ([self longEnoughSinceLastPost]) {
		[self postToServerApp:frontmostApp];
	}
	
	if ([frontmostApp length] > 0) {
		[self checkCurfewAndIfLateDo: ^{
			[self complainForApp:frontmostApp];
		}];
	}
}

-(void)initializeDateFormatter
{
	// http://www.flexicoder.com/blog/index.php/2013/10/ios-24-hour-date-format/
	_dateFormatter = [[NSDateFormatter alloc] init];
	NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
	[_dateFormatter setLocale:enUSPOSIXLocale];
	[_dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
	[_dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
}


// MAIN ENTRY POINT

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[self initializeDateFormatter];

	// vampire magic to keep us alive forever
	self.locationTracker = [[LocationTracker alloc]init];
    [self.locationTracker startLocationTracking];

	[self registerAppforDetectLockState];
	
	// the actual thing we want to do
    NSTimeInterval time = CURFEW_CHECK_INTERVAL_SECONDS;
	self.locationUpdateTimer =
    [NSTimer scheduledTimerWithTimeInterval:time
                                     target:self
                                   selector:@selector(periodicTask)
                                   userInfo:nil
                                    repeats:YES];
	
    return YES;
}


@end
