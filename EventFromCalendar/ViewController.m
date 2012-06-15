//
//  ViewController.m
//  EventFromCalendar
//
//  Created by Marian PAUL on 22/03/12.
//  Copyright (c) 2012 IPuP SARL. All rights reserved.
//

#import "ViewController.h"

#define kCalendarName @"Calendar name"
#define kArrayOfEvents @"Array of events"

@interface ViewController ()

@end

@implementation ViewController
@synthesize eventsToDisplay = _eventsToDisplay;

- (void)viewDidLoad
{
    [super viewDidLoad];

    // titre du controlleur
    self.title = @"Calendrier";
    
    // initialisation de l'event store 
    _eventStore = [[EKEventStore alloc] init];
    
    // initialisation du tableau avec les événements deux mois avant et un mois après la date actuelle 
    self.eventsToDisplay = [self getEventsTodisplay];
    
    // ajout du bouton ajouter un nouvel événement
    UIBarButtonItem *plusButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addEvent:)];
    self.navigationItem.leftBarButtonItem = plusButton;
    
    // ajout de l'observation du changement de la base de données
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storeChanged:) name:EKEventStoreChangedNotification object:nil];
    
    // ajout du bouton modifier
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // autoriser la selection en mode édition
    self.tableView.allowsSelectionDuringEditing = YES;
}

- (NSMutableArray*) getEventsTodisplay 
{
    // on créé les dates limites pour le tri 
    CFGregorianDate gregorianStartDate, gregorianEndDate;
    // deux mois avant aujourd'hui
    CFGregorianUnits startUnits = {0, -2, 0, 0, 0, 0}; // années, mois, jours, heures, minutes, secondes
    // un mois après aujourd'hui
    CFGregorianUnits endUnits = {0, 0, 30, 0, 0, 0};
    // récupérer l'heure actuelle dans la zone où vous êtes placés
    CFTimeZoneRef timeZone = CFTimeZoneCopySystem();
    
    gregorianStartDate = CFAbsoluteTimeGetGregorianDate(CFAbsoluteTimeAddGregorianUnits(CFAbsoluteTimeGetCurrent(), timeZone, startUnits), timeZone);
    
    gregorianEndDate = CFAbsoluteTimeGetGregorianDate(CFAbsoluteTimeAddGregorianUnits(CFAbsoluteTimeGetCurrent(), timeZone, endUnits), timeZone);
    
    NSDate* startDate = [NSDate dateWithTimeIntervalSinceReferenceDate:CFGregorianDateGetAbsoluteTime(gregorianStartDate, timeZone)];
    NSDate* endDate = [NSDate dateWithTimeIntervalSinceReferenceDate:CFGregorianDateGetAbsoluteTime(gregorianEndDate, timeZone)];
    
    CFRelease(timeZone);
    
    // On crée le prédicat
    NSPredicate *predicate = [_eventStore predicateForEventsWithStartDate:startDate endDate:endDate calendars:nil];
    
    // On récupère tous les événements qui correspondent
    NSArray *events = [_eventStore eventsMatchingPredicate:predicate];
    
    // on récupère les différents type de calendrier
    NSArray *arrayOfCalendarsWithPotentialDuplication = [events valueForKeyPath:@"calendar.title"];
    
    // comme il y a un risque de duplication des noms de calendriers, on utilise NSSet qui va automatiquement enlever les doublons
    NSSet *setCalendars = [NSSet setWithArray:arrayOfCalendarsWithPotentialDuplication];
    // on récupère le bon tableau sans doublons
    NSArray *arrayOfCalendars = [setCalendars allObjects];
    
    
    // on construit un tableau de dictionnaires contenant le nom du calendrier et un tableau d'événements correspondants à ce calendrier
    NSMutableArray *arrayToReturn = [[NSMutableArray alloc] init];
    // on parcourt tous les calendriers
    for (NSString *calendar in arrayOfCalendars)
    {
        // on cherche les événements qui ont pour titre le calendrier en cours
        NSPredicate *predicateCalendar = [NSPredicate predicateWithFormat:@"calendar.title == %@", calendar];
        // on crée un nouveau tableau en utilisant ce filtre
        NSMutableArray *arrayOfEvents = [NSMutableArray arrayWithArray:[events filteredArrayUsingPredicate:predicateCalendar]];
        // on crée le dictionnaire associé
        NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:calendar, arrayOfEvents, nil]                         
                                                                      forKeys:[NSArray arrayWithObjects:kCalendarName, kArrayOfEvents, nil]];
        // on l'ajoute dans le tableau
        [arrayToReturn addObject:dic];
    }
    
    
    
    return arrayToReturn;
}

- (void)addEvent:(id)sender 
{
    EKEventEditViewController* controller = [[EKEventEditViewController alloc] init];
    controller.eventStore = _eventStore;
    controller.editViewDelegate = self;
    [self presentModalViewController: controller animated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return [_eventsToDisplay count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    return [[[_eventsToDisplay objectAtIndex:section] objectForKey:kArrayOfEvents] count];
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section 
{
    return [[_eventsToDisplay objectAtIndex:section] objectForKey:kCalendarName];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    EKEvent *event = (EKEvent*)[[[_eventsToDisplay objectAtIndex:indexPath.section] objectForKey:kArrayOfEvents] objectAtIndex:indexPath.row];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init]; 
    dateFormatter.dateFormat = @"dd MMMM YY / HH:mm";
    NSString *startDate = [dateFormatter stringFromDate:event.startDate];
    
    NSString *endDate = [dateFormatter stringFromDate:event.endDate];
    
    cell.textLabel.text = event.title;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ —> %@", startDate, endDate];

    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath 
{
    if (editingStyle == UITableViewCellEditingStyleDelete) 
    {
        // on récupère l'événement à supprimer
        EKEvent *eventToRemove = [[[_eventsToDisplay objectAtIndex:indexPath.section] objectForKey:kArrayOfEvents] objectAtIndex:indexPath.row];
        // on l'enlève de la base de données
        [_eventStore removeEvent:eventToRemove span:EKSpanThisEvent error:nil]; // [1]
        // -> storeChanged sera automatiquement appelé
        
        // on l'enlève du tableau (pour éviter que ça ne plante à la ligne suivante)
        [[[_eventsToDisplay objectAtIndex:indexPath.section] objectForKey:kArrayOfEvents] removeObjectAtIndex:indexPath.row];
        // on supprime la vue avec animation
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }      
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
    EKEventViewController *eventViewController = [[EKEventViewController alloc] init];
    // on passe l'événement à visualiser ou éditer
    eventViewController.event = [[[_eventsToDisplay objectAtIndex:indexPath.section] objectForKey:kArrayOfEvents] objectAtIndex:indexPath.row];
    // on n'autorise l'édition seulement lorsque la table view est en mode d'édition
    eventViewController.allowsEditing = self.tableView.editing;
    // on présente le contrôleur
    [self.navigationController pushViewController:eventViewController animated:YES];
}


#pragma mark - Store management
- (void)storeChanged:(NSNotification*)notification
{
    self.eventsToDisplay = [self getEventsTodisplay];
    [self.tableView reloadData];
}

#pragma mark - EKEvent delegate

- (void)eventEditViewController:(EKEventEditViewController *)controller didCompleteWithAction:(EKEventEditViewAction)action
{
    [self dismissModalViewControllerAnimated:YES];
}

- (EKCalendar *)eventEditViewControllerDefaultCalendarForNewEvents:(EKEventEditViewController *)controller
{
    return _eventStore.defaultCalendarForNewEvents;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void) dealloc 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EKEventStoreChangedNotification object:nil];
}

@end
