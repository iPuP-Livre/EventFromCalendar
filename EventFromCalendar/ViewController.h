//
//  ViewController.h
//  EventFromCalendar
//
//  Created by Marian PAUL on 22/03/12.
//  Copyright (c) 2012 IPuP SARL. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <EventKit/EventKit.h>
#import <EventKitUI/EventKitUI.h>

@interface ViewController : UITableViewController <EKEventEditViewDelegate>
{
    EKEventStore *_eventStore;
}
@property (strong, nonatomic) NSMutableArray *eventsToDisplay;
- (NSMutableArray*) getEventsTodisplay;
@end
