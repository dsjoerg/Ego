//
//  DJMainViewController.h
//  Ego
//
//  Created by David Joerg on 8/27/14.
//  Copyright (c) 2014 David Joerg. All rights reserved.
//

#import "DJFlipsideViewController.h"

@interface DJMainViewController : UIViewController <DJFlipsideViewControllerDelegate, UIPopoverControllerDelegate>

@property (strong, nonatomic) UIPopoverController *flipsidePopoverController;

@end
