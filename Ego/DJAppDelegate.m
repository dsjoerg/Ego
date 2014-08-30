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


#define SBSERVPATH "/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices"

@implementation DJAppDelegate


// EVIL MAGIC TO FIND OUT WHICH APP IS IN FRONT
// http://stackoverflow.com/questions/8252396/how-to-determine-which-apps-are-background-and-which-app-is-foreground-on-ios-by
-(NSString *)getFrontmostApp
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

-(void)postToServer: (NSString *)stringToPost
{
	AFHTTPClient *client = [AFHTTPClient clientWithBaseURL:[NSURL URLWithString:[self baseServerURL]]];
	[client postPath:[self textObservationPath] parameters:@{@"text": stringToPost} success:^(AFHTTPRequestOperation *operation, id responseObject) {
			NSLog(@"POST SUCCEEDED");
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		NSLog(@"Failed! With error %@", error);
	}];
}

// COMPLAINING

-(void)complainForApp:(NSString *)frontmostApp
{
	NSArray *games = @[@"tv.twitch", @"com.supercell.magic", @"com.idle-games.eldorado", @"com.blizzard.wtcg.hearthstone", @"se.imageform.anthill", @"com.nakedsky.MaxAxe", @"com.andreasilliger.tinywings"];
	NSArray *timewasters = @[@"com.designshed.alienblue", @"com.facebook.Facebook"];
	
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


-(void)periodicTask {
	NSString *frontmostApp = [self getFrontmostApp];
	NSUUID *deviceID = [[UIDevice currentDevice] identifierForVendor];
	[self postToServer: [NSString stringWithFormat:@"Device %@, frontmost %@", [deviceID UUIDString], frontmostApp]];
	
	if ([frontmostApp length] > 0) {
		[self checkCurfewAndIfLateDo: ^{
			[self complainForApp:frontmostApp];
		}];
	}
}



// MAIN ENTRY POINT

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// vampire magic to keep us alive forever
	self.locationTracker = [[LocationTracker alloc]init];
    [self.locationTracker startLocationTracking];

	// the actual thing we want to do
    NSTimeInterval time = 10.0;
	self.locationUpdateTimer =
    [NSTimer scheduledTimerWithTimeInterval:time
                                     target:self
                                   selector:@selector(periodicTask)
                                   userInfo:nil
                                    repeats:YES];
	
    return YES;
}


@end
