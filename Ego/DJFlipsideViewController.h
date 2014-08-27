//
//  DJFlipsideViewController.h
//  Ego
//
//  Created by David Joerg on 8/27/14.
//  Copyright (c) 2014 David Joerg. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DJFlipsideViewController;

@protocol DJFlipsideViewControllerDelegate
- (void)flipsideViewControllerDidFinish:(DJFlipsideViewController *)controller;
@end

@interface DJFlipsideViewController : UIViewController

@property (weak, nonatomic) id <DJFlipsideViewControllerDelegate> delegate;

- (IBAction)done:(id)sender;

@end
