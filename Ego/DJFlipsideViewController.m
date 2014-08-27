//
//  DJFlipsideViewController.m
//  Ego
//
//  Created by David Joerg on 8/27/14.
//  Copyright (c) 2014 David Joerg. All rights reserved.
//

#import "DJFlipsideViewController.h"

@interface DJFlipsideViewController ()

@end

@implementation DJFlipsideViewController

- (void)awakeFromNib
{
	self.preferredContentSize = CGSizeMake(320.0, 480.0);
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

- (IBAction)done:(id)sender
{
    [self.delegate flipsideViewControllerDidFinish:self];
}

@end
