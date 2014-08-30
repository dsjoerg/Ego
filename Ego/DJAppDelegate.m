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

@implementation DJAppDelegate

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_DEBUG;

//static UIBackgroundTaskIdentifier backgroundTaskID;

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
	
	[[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
	
	[self wakeUpAndLookAround];
	
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

	
//	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(wakeUpAndLookAround) userInfo:nil repeats:YES];
//    [timer fire];

    return YES;
}

-(void)updateLocation {
    NSLog(@"updateLocation");
    
    [self.locationTracker updateLocationToServer];
	[self wakeUpAndLookAround];
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
	NSLog(@"FETCH");
	[self wakeUpAndLookAroundWithCompletionHandler: completionHandler];
//	completionHandler(UIBackgroundFetchResultNewData);
}

//-(void)bgTask {
//    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"ApplicationURLScheme"]];
//}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	NSLog(@"DID ENTER BACKGROUND");
//	[[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
//	[application beginBackgroundTaskWithExpirationHandler:^{
//		[self bgTask];
//	}];
}

//- (void) backgroundForever {
//	UIApplication *application = [UIApplication sharedApplication];
//	backgroundTaskID = [application beginBackgroundTaskWithExpirationHandler:^{
//		[self backgroundForever];
//	}];
//}
//
//- (void) stopBackgroundTask {
//	UIApplication *application = [UIApplication sharedApplication];
//	if(backgroundTaskID != -1)
//		[application endBackgroundTask:backgroundTaskID];
//}


- (void)applicationWillResignActive:(UIApplication *)application
{
	NSLog(@"APP WILL RESIGN ACTIVE");
	
//	BOOL result = [[UIApplication sharedApplication] setKeepAliveTimeout:600.0f handler:^{
//		NSLog(@"VOIP FOREVER");
//	}];
//	
//	NSLog(@"handler installed result = %i", result);

	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}


- (void)applicationWillEnterForeground:(UIApplication *)application
{
	NSLog(@"APP WILL ENTER FOREGROUND");
	
//	[self backgroundForever];
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	NSLog(@"APP DID BECOME ACTIVE");
	

	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	NSLog(@"APP WILL TERMINATE");

	// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
