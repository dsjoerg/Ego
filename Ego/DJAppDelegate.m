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
#import "AFNetworking.h"
#import <dlfcn.h>


#define SBSERVPATH "/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices"

@implementation DJAppDelegate

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_DEBUG;

//static UIBackgroundTaskIdentifier backgroundTaskID;


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

// http://stackoverflow.com/a/9020923/593053
-(NSString *)jsonForDict:(NSDictionary *)dict
{
	NSString *jsonString;
	NSError *error;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
													   options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
														 error:&error];

	if (! jsonData) {
		NSLog(@"Got an error: %@", error);
		jsonString = @"";
	} else {
		jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	}

	return jsonString;
}

-(void)postToServer: (NSDictionary *)dict withCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
	NSString *path = [NSString stringWithFormat:@"%@/%@", [self baseServerURL], @"api/v1/text_observation"];
	
	NSDictionary *params = @{@"text": [self jsonForDict:dict]};
	
	AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
	manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"application/json"];
	[manager POST:path parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
//		NSLog(@"JSON: %@", responseObject);
		NSLog(@"SUCKSESS");
		if (completionHandler) {
			completionHandler(UIBackgroundFetchResultNewData);
		}
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		NSLog(@"Error: %@", error);
		if (completionHandler) {
			completionHandler(UIBackgroundFetchResultFailed);
		}
	}];
	
//	NSURLSession *session = [NSURLSession sharedSession];
}


// from http://stackoverflow.com/questions/16366701/is-it-possible-to-get-the-launch-time-of-pid
- (NSArray *) runningProcesses {
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
                NSMutableArray * array = [[NSMutableArray alloc] init];
                for (int i = nprocess - 1; i >= 0; i--) {
                    NSString * processID = [[NSString alloc] initWithFormat:@"%d", process[i].kp_proc.p_pid];
                    NSString * processName = [[NSString alloc] initWithFormat:@"%s", process[i].kp_proc.p_comm];
                    NSString * proc_CPU = [[NSString alloc] initWithFormat:@"%d", process[i].kp_proc.p_estcpu];
                    double t = [[NSDate date] timeIntervalSince1970] - process[i].kp_proc.p_un.__p_starttime.tv_sec;
                    NSString * proc_useTiem = [[NSString alloc] initWithFormat:@"%f",t];
					//                    NSLog(@"process.kp_proc.p_stat = %c",process.kp_proc.p_stat);
                    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
                    [dic setValue:processID forKey:@"ProcessID"];
                    [dic setValue:processName forKey:@"ProcessName"];
                    [dic setValue:proc_CPU forKey:@"ProcessCPU"];
                    [dic setValue:proc_useTiem forKey:@"ProcessUseTime"];
                    [array addObject:dic];
                }
                free(process);
                process = NULL;

//				[self postToServer:array[0]];
//                NSLog(@"runningProcesses is === %@",array);

                return array;
            }
        }
    }
    return nil;
}

-(void) wakeUpAndLookAroundWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
	DDLogDebug(@"Hi! Woke up, looking around.");
	
	NSDictionary *result = @{};
	NSMutableArray * array = (NSMutableArray *)[self runningProcesses];
	for (NSMutableDictionary *dict in array) {
			if ([[dict valueForKey:@"ProcessName"] isEqualToString:@"Twitch"]) {
			result = dict;
		}
	}
	[self postToServer:result withCompletionHandler:completionHandler];
}

-(void) wakeUpAndLookAround
{
	[self wakeUpAndLookAroundWithCompletionHandler:nil];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	DDLogDebug(@"HI there!");
	
//	[[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
	
//	[self wakeUpAndLookAround];
	
	self.locationTracker = [[LocationTracker alloc]init];
    [self.locationTracker startLocationTracking];
    
    //Send the best location to server every 60 seconds
    //You may adjust the time interval depends on the need of your app.
    NSTimeInterval time = 60.0;
	self.locationUpdateTimer =
    [NSTimer scheduledTimerWithTimeInterval:time
                                     target:self
                                   selector:@selector(updateLocation)
                                   userInfo:nil
                                    repeats:YES];

    return YES;
}

-(void)updateLocation {
    NSLog(@"updateLocation");
    
	NSString *frontmost = [self getfrontmost];
	NSArray *killThese = @[@"tv.twitch", @"com.supercell.magic"];
	if ([killThese containsObject:frontmost]) {
		NSLog(@"STOP THAT RIGHT NOW: %@", frontmost);
	}

    [self.locationTracker updateLocationToServer];
//	[self wakeUpAndLookAround];
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
	NSLog(@"FETCH");
//	[self wakeUpAndLookAroundWithCompletionHandler: completionHandler];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	NSLog(@"DID ENTER BACKGROUND");
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	NSLog(@"APP WILL RESIGN ACTIVE");
}


- (void)applicationWillEnterForeground:(UIApplication *)application
{
	NSLog(@"APP WILL ENTER FOREGROUND");
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	NSLog(@"APP DID BECOME ACTIVE");
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	NSLog(@"APP WILL TERMINATE");
}

@end
