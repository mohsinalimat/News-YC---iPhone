//
//  CommentsViewController.m
//  HackerNews
//
//  Created by Ben Gordon on 10/22/13.
//  Copyright (c) 2013 Benjamin Gordon. All rights reserved.
//

#import "CommentsViewController.h"
#import "LinksViewController.h"
#import "SubmitHNViewController.h"
#import "HNSingleton.h"
#import "KGStatusBar.h"
#import "Helpers.h"

@interface CommentsViewController ()

@property (nonatomic, retain) NSArray *Comments;
@property (nonatomic, retain) HNPost *Post;
@property (strong, nonatomic) IBOutlet UIView *LoadingCommentsView;
@property (weak, nonatomic) IBOutlet UITableView *CommentsTableView;
@property (nonatomic, retain) UIRefreshControl *refreshControl;
@property (nonatomic, retain) NSNumber *AuxiliaryClickIndex;

@end

@implementation CommentsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil post:(HNPost *)post
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.Post = post;
        self.Comments = @[];
        self.AuxiliaryClickIndex = nil;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.AuxiliaryClickIndex = nil;
    
    [self buildUI];
    [self loadComments];
    
    // Set Up NotificationCenter
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeTheme) name:@"DidChangeTheme" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadComments) name:@"DidSubmitNewComment" object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    //[self loadComments];
}

- (void)viewDidDisappear:(BOOL)animated {
    self.Comments = nil;
}

#pragma mark - UI
- (void)buildUI {
    // Build Nav
    BOOL userIsLoggedIn = [[HNManager sharedManager] userIsLoggedIn];
    [Helpers buildNavigationController:self leftImage:NO rightImages:(userIsLoggedIn ? @[[UIImage imageNamed:@"comment_button-01"]] : nil) rightActions:(userIsLoggedIn ? @[@"didClickSubmitComment"] : nil)];
    
    // Set TableView and LoadingView
    self.CommentsTableView.alpha = 0;
    
    // Color
    [self colorUI];
    
    // Refresh Control
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(pullToRefreshTable) forControlEvents:UIControlEventValueChanged];
    self.refreshControl.tintColor = [UIColor blackColor];
    self.refreshControl.alpha = 0.65;
    [self.CommentsTableView addSubview:self.refreshControl];
}

- (void)colorUI {
    // Color
    self.CommentsTableView.backgroundColor = [[HNSingleton sharedHNSingleton].themeDict objectForKey:@"CellBG"];
    self.view.backgroundColor = [[HNSingleton sharedHNSingleton].themeDict objectForKey:@"CellBG"];
}


#pragma mark - Change Theme from Left Menue
- (void)didChangeTheme {
    self.CommentsTableView.alpha = 0;
    [UIView animateWithDuration:0.2 animations:^{
        [self colorUI];
    } completion:^(BOOL fin){
        [self.CommentsTableView reloadData];
        [UIView animateWithDuration:0.2 animations:^{
            self.CommentsTableView.alpha = 1;
        }];
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Submit Comment
- (void)didClickSubmitComment {
    SubmitHNViewController *vc = [[SubmitHNViewController alloc] initWithNibName:@"SubmitHNViewController" bundle:nil type:SubmitHNTypeComment hnObject:self.Post];
    [self.navigationController pushViewController:vc animated:YES];
}


#pragma mark - WebService
- (void)loadComments {
    if (self.Post) {
        // Add Activity Indicator View
        UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] init];
        [Helpers navigationController:self addActivityIndicator:&indicator];
        
        // Load Comments
        [[HNManager sharedManager] loadCommentsFromPost:self.Post completion:^(NSArray *comments) {
            if (comments) {
                self.Comments = comments;
            }
            
            [self refreshTable:self.CommentsTableView indicator:indicator];
        }];
    }
}


#pragma mark - Refresh Table
- (void)refreshTable:(UITableView *)tableView indicator:(UIActivityIndicatorView *)indicator {
    [tableView reloadData];
    [indicator removeFromSuperview];
    [self.refreshControl endRefreshing];
    self.LoadingCommentsView.alpha = 0;
    self.CommentsTableView.alpha = 1;
}


- (void)pullToRefreshTable {
    [self.refreshControl beginRefreshing];
    [self loadComments];
}

#pragma mark - TableView
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return a "No Comments Exist" cell
    return self.Comments.count > 0 ? self.Comments.count : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *CellIdentifier = [NSString stringWithFormat:@"Cell %d", indexPath.row];
    CommentsCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        NSArray* views = [[NSBundle mainBundle] loadNibNamed:@"CommentsCell" owner:nil options:nil];
        for (UIView *view in views) {
            if([view isKindOfClass:[UITableViewCell class]]) {
                cell = (CommentsCell *)view;
            }
        }
    }
    
    // Set Content
    
    cell = [cell cellForComment:(self.Comments.count > 0 ? self.Comments[indexPath.row] : nil) atIndex:indexPath fromController:self showAuxiliary:(self.AuxiliaryClickIndex && (indexPath.row == [self.AuxiliaryClickIndex intValue]) ? YES : NO)];
    [cell.comment setDelegate:self];
    
    return cell;
}

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *CellIdentifier = [NSString stringWithFormat:@"Cell %d", indexPath.row];
    CommentsCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        NSArray* views = [[NSBundle mainBundle] loadNibNamed:@"CommentsCell" owner:nil options:nil];
        for (UIView *view in views) {
            if([view isKindOfClass:[UITableViewCell class]]) {
                cell = (CommentsCell *)view;
            }
        }
    }
    
    return [cell heightForComment:(self.Comments.count > 0 ? self.Comments[indexPath.row] : nil) isAuxiliary:(self.AuxiliaryClickIndex && (indexPath.row == [self.AuxiliaryClickIndex intValue]) ? YES : NO)];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([[HNManager sharedManager] userIsLoggedIn]) {
        /*
        if (self.AuxiliaryClickIndex) {
            if (self.AuxiliaryClickIndex.intValue == indexPath.row) {
                self.AuxiliaryClickIndex = nil;
            }
            else {
                self.AuxiliaryClickIndex = @(indexPath.row);
            }
        }
        else {
            self.AuxiliaryClickIndex = @(indexPath.row);
        }
        [self.CommentsTableView reloadData];
        */
        
        NSIndexPath *oldIndexPath;
        if (self.AuxiliaryClickIndex) {
            int oldIndex = self.AuxiliaryClickIndex.intValue;
            oldIndexPath = [NSIndexPath indexPathForRow:oldIndex inSection:0];
            if (indexPath.row == oldIndex) {
                self.AuxiliaryClickIndex = nil;
            }
            else {
                self.AuxiliaryClickIndex = @(indexPath.row);
            }
        }
        else {
            self.AuxiliaryClickIndex = @(indexPath.row);
        }
        
        NSArray *indexPathsToReload = (oldIndexPath && (oldIndexPath.row != indexPath.row)) ? @[indexPath,oldIndexPath] : @[indexPath];
        [self.CommentsTableView reloadRowsAtIndexPaths:indexPathsToReload withRowAnimation:UITableViewRowAnimationFade];
    }
}


#pragma mark - TTTAttributedLabelDelegate
- (void)attributedLabel:(TTTAttributedLabel *)label didSelectLinkWithURL:(NSURL *)url {
    LinksViewController *vc = [[LinksViewController alloc] initWithNibName:@"LinksViewController" bundle:nil url:url post:nil];
    [self.navigationController pushViewController:vc animated:YES];
}


#pragma mark - Comment Cell Delegate
- (void)didClickReplyToCommentAtIndex:(int)index {
    SubmitHNViewController *vc = [[SubmitHNViewController alloc] initWithNibName:@"SubmitHNViewController" bundle:nil type:SubmitHNTypeComment hnObject:self.Comments[index]];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)didClickShareCommentAtIndex:(int)index {
    NSArray *activityItems = @[[self.Comments[index] Text]];
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    [self presentViewController:activityController animated:YES completion:nil];
}

- (void)didClickUpvoteCommentAtIndex:(int)index {
    [self voteOnComment:self.Comments[index] direction:VoteDirectionUp];
}

- (void)didClickDownvoteCommentAtIndex:(int)index {
    [self voteOnComment:self.Comments[index] direction:VoteDirectionDown];
}

- (void)voteOnComment:(HNComment *)comment direction:(VoteDirection)direction {
    [[HNManager sharedManager] voteOnPostOrComment:comment direction:direction completion:^(BOOL success) {
        if (success) {
            [KGStatusBar showWithStatus:@"Voting Success"];
            [[HNManager sharedManager] addHNObjectToVotedOnDictionary:comment direction:direction];
        }
        else {
            [KGStatusBar showWithStatus:@"Failed Voting"];
        }
    }];
}

@end