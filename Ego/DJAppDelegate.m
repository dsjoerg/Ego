//
//  DJAppDelegate.m
//  Ego
//
//  Created by David Joerg on 8/27/14.
//  Copyright (c) 2014 David Joerg. All rights reserved.
//

#import "DJAppDelegate.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#include <sys/sysctl.h>
#import "AFHTTPClient.h"
#import <dlfcn.h>
#import <AudioToolbox/AudioToolbox.h>


#define SBSERVPATH "/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices"

@implementation DJAppDelegate

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_DEBUG;

-(NSString *)getfrontmost
{
	mach_port_t *port;
	void *lib = dlopen(SBSERVPATH, RTLD_LAZY);

	int (*SBSSpringBoardServerPort)() = dlsym(lib, "SBSSpringBoardServerPort");
	port = (mach_port_t *)SBSSpringBoardServerPort();
	
	void *(*SBFrontmostApplicationDisplayIdentifier)(mach_port_t *port, char *result) = dlsym(lib, "SBFrontmostApplicationDisplayIdentifier");
	
	// reserve memory for name
	char appId[256];
	memset(appId, 0, sizeof(appId));
	
	// retrieve front app name
	SBFrontmostApplicationDisplayIdentifier(port, appId);
	
	// close dynlib
	dlclose(lib);
	
	NSString *frontmost = [NSString stringWithCString:appId encoding:NSASCIIStringEncoding];

	NSLog(@"WHOA IT IS %@", frontmost);

	return frontmost;
}

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

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	DDLogDebug(@"HI there!");
	
	self.locationTracker = [[LocationTracker alloc]init];
    [self.locationTracker startLocationTracking];
    
    NSTimeInterval time = 10.0;
	self.locationUpdateTimer =
    [NSTimer scheduledTimerWithTimeInterval:time
                                     target:self
                                   selector:@selector(complainIfRunningAnAppLateAtNight)
                                   userInfo:nil
                                    repeats:YES];
	
    return YES;
}

-(void)complainIfRunningAnApp
{
	NSString *frontmost = [self getfrontmost];
	NSArray *games = @[@"tv.twitch", @"com.supercell.magic", @"com.idle-games.eldorado", @"com.blizzard.wtcg.hearthstone", @"se.imageform.anthill", @"com.nakedsky.MaxAxe", @"com.andreasilliger.tinywings"];
	NSArray *timewasters = @[@"com.designshed.alienblue", @"com.facebook.Facebook"];

	if ([frontmost length] > 0) {
		UILocalNotification* localNotification = [[UILocalNotification alloc] init];
		localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:1];
		localNotification.timeZone = [NSTimeZone defaultTimeZone];

		if ([games containsObject:frontmost]) {
			localNotification.alertBody = @"LEAST OF ALL A GAME";
			localNotification.soundName = @"Klaxon_horn_64kb.mp3";
		} else if ([timewasters containsObject:frontmost]) {
			localNotification.alertBody = @"STOP READING";
			localNotification.soundName = @"minerals.mp3";
		} else {
			localNotification.alertBody = @"GO TO SLEEP ITS LATE";
			localNotification.soundName = @"supply.mp3";
		}

		[[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
	}

}

-(NSString *)curfewActivePath
{
	NSString *email = @"dsjoerg@gmail.com";
    return [NSString stringWithFormat:@"/api/v1/curfew/is_active?email=%@", email];
}


-(void)complainIfRunningAnAppLateAtNight {

	AFHTTPClient *client = [AFHTTPClient clientWithBaseURL:[NSURL URLWithString:[self baseServerURL]]];
	[client getPath:[self curfewActivePath] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
		NSString *responseString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
		if ([responseString isEqualToString:@"true"]) {
			[self complainIfRunningAnApp];
		}
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		DDLogDebug(@"Failed! With error %@", error);
	}];
}


@end
