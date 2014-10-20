//
//  ViewController.m
//  HearthSpeak
//
//  Created by Bennett Lin on 10/12/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

// for API information: http://hearthstone.gamepedia.com/api.php

#import "ViewController.h"
#import "SpeechEngine.h"
#import <AVFoundation/AVFoundation.h>

#define kKnownCardsCount 549
#define kImageViewWidth 320
#define kImageViewHeight 396
#define kPickerWidth 240
#define kPickerHeight 162
#define kBottomPadding 10
#define kSidePadding 10

@interface ViewController () <UIPickerViewDataSource, UIPickerViewDelegate, NSURLSessionDownloadDelegate, OpenEarsSpeechEngineDelegate>

@property (strong, nonatomic) UIImageView *imageView;
@property (strong, nonatomic) UIPickerView *cardPicker;

@property (strong, nonatomic) NSArray *cardNames;

@property (strong, nonatomic) NSURLSession *dataSession;
@property (strong, nonatomic) NSURLSession *downloadSession;

@property (strong, nonatomic) UIAlertController *sessionAlertController;
@property (strong, nonatomic) UIAlertController *micAlertController;

@property (strong, nonatomic) SpeechEngine *speechEngine;

@property (strong, nonatomic) UIActivityIndicatorView *activityIndicator;

@end

@implementation ViewController {
  CGFloat _screenShort;
  CGFloat _screenLong;
  CGFloat _statusBarHeight;
}

@synthesize sessionAlertController = _sessionAlertController;
@synthesize micAlertController = _micAlertController;

-(void)viewDidLoad {
  [super viewDidLoad];
  
  _screenShort = self.view.bounds.size.width;
  _screenLong = self.view.bounds.size.height;
  _statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
  
  if (_screenShort > _screenLong) {
    CGFloat higherValue = _screenShort;
    _screenShort = _screenLong;
    _screenLong = higherValue;
  }

  self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"wood_background.jpg"]];
  
  [self instantiatePicker];
  [self instantiateImageView];
  [self instantiateActivityIndicator];
  [self populateCardNames];
  [self instantiateSessions];
  
  [self showFirstCard];
//  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestMicPermission) name:UIApplicationWillEnterForegroundNotification object:nil];
//  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestMicPermission) name:UIApplicationDidFinishLaunchingNotification object:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resizeAndRepositionBasedOnOrientation:) name:UIDeviceOrientationDidChangeNotification object:nil];
  
    // first card is shown either when mic permission is proven granted
    // or else after mic alert controller is presented and dismissed
}

-(void)viewWillAppear:(BOOL)animated {
  [self resizeAndRepositionBasedOnOrientation:nil];
}

-(void)resizeAndRepositionBasedOnOrientation:(NSNotification *)notification {
  
  NSLog(@"status bar height is %.2f", _statusBarHeight);
  const CGFloat minimumScreenHeight = _statusBarHeight + kImageViewHeight + kPickerHeight + kBottomPadding;
  const CGFloat minimumScreenWidth = kImageViewWidth + kPickerWidth + (kSidePadding * 2);
  
  CGFloat imageViewHeight;
  CGFloat imageViewWidth;
  CGFloat verticalMargin;
  CGFloat horizontalMargin;
  
  UIDevice *device = [UIDevice currentDevice];
  UIDeviceOrientation orientation = device.orientation;
  
  switch (orientation) {
      
    case UIDeviceOrientationPortraitUpsideDown:
      
      NSLog(@"portrait upside down");
      imageViewHeight = _screenLong > minimumScreenHeight ?
          kImageViewHeight : _screenLong - _statusBarHeight - kPickerHeight - kBottomPadding;
      verticalMargin = (_screenLong - _statusBarHeight - imageViewHeight - kPickerHeight - kBottomPadding) / 3;
      
      self.imageView.frame = CGRectMake((_screenShort - kImageViewWidth) / 2, _screenLong - imageViewHeight - kBottomPadding - verticalMargin, kImageViewWidth, imageViewHeight);
      self.cardPicker.frame = CGRectMake((_screenShort - kPickerWidth) / 2, _statusBarHeight + verticalMargin, kPickerWidth, kPickerHeight);
      
      break;
      
    case UIDeviceOrientationLandscapeLeft:
      
      NSLog(@"landscape left");
      imageViewWidth = _screenLong > minimumScreenWidth ?
          kImageViewWidth : _screenLong - kPickerWidth - (kSidePadding * 2);
      imageViewHeight = _screenShort > kImageViewHeight ? kImageViewHeight : _screenShort;
      horizontalMargin = (_screenLong - imageViewWidth - kPickerWidth) / 3;
      
      self.imageView.frame = CGRectMake(horizontalMargin, (_screenShort - imageViewHeight) / 2, imageViewWidth, imageViewHeight);
      self.cardPicker.frame = CGRectMake(_screenLong - kPickerWidth - horizontalMargin, (_screenShort - kPickerHeight) / 2, kPickerWidth, kPickerHeight);
      
      break;
      
    case UIDeviceOrientationLandscapeRight:
      
      NSLog(@"landscape right");

      imageViewWidth = _screenLong > minimumScreenWidth ?
          kImageViewWidth : _screenLong - kPickerWidth - (kSidePadding * 2);
      imageViewHeight = _screenShort > kImageViewHeight ? kImageViewHeight : _screenShort;
      horizontalMargin = (_screenLong - imageViewWidth - kPickerWidth) / 3;
      
      self.imageView.frame = CGRectMake(_screenLong - imageViewWidth - horizontalMargin, (_screenShort - imageViewHeight) / 2, imageViewWidth, imageViewHeight);
      self.cardPicker.frame = CGRectMake(horizontalMargin, (_screenShort - kPickerHeight) / 2, kPickerWidth, kPickerHeight);
      
      break;

    case UIDeviceOrientationPortrait:
    default:
      
      NSLog(@"portrait");
      imageViewHeight = _screenLong > minimumScreenHeight ?
          kImageViewHeight : _screenLong - _statusBarHeight - kPickerHeight - kBottomPadding;
      verticalMargin = (_screenLong - _statusBarHeight - imageViewHeight - kPickerHeight - kBottomPadding) / 3;
      NSLog(@"vertical margin is %.2f", verticalMargin);
      
      self.imageView.frame = CGRectMake((_screenShort - kImageViewWidth) / 2, _statusBarHeight + verticalMargin, kImageViewWidth, imageViewHeight);
      self.cardPicker.frame = CGRectMake((_screenShort - kPickerWidth) / 2, _screenLong - kPickerHeight - kBottomPadding - verticalMargin, kPickerWidth, kPickerHeight);
      
      break;
  }
  
  self.activityIndicator.center = self.imageView.center;
}

-(void)showFirstCard {
  [self pickerView:self.cardPicker didSelectRow:0 inComponent:0];
}

#pragma mark - custom getters

-(UIAlertController *)sessionAlertController {
  if (!_sessionAlertController) {
    _sessionAlertController = [UIAlertController alertControllerWithTitle:@"Whoops..." message:@"There was a problem connecting to the server." preferredStyle:UIAlertControllerStyleAlert];
    [_sessionAlertController addAction:[UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:nil]];
  }
  return _sessionAlertController;
}

-(UIAlertController *)micAlertController {
  if (!_micAlertController) {
    _micAlertController = [UIAlertController alertControllerWithTitle:@"Can't hear you grunt!" message:@"Go to Settings\u00a0> Privacy\u00a0> Microphone to grant access." preferredStyle:UIAlertControllerStyleAlert];
    [_micAlertController addAction:[UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      [self pickerView:self.cardPicker didSelectRow:[self.cardPicker selectedRowInComponent:0] inComponent:0];
    }]];
  }
  return _micAlertController;
}

#pragma mark - setup methods

-(void)instantiatePicker {
  self.cardPicker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 0, 290, 162)];
  [self.view addSubview:self.cardPicker];
  self.cardPicker.dataSource = self;
  self.cardPicker.delegate = self;
}

-(void)instantiateActivityIndicator {
  self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
  [self.view addSubview:self.activityIndicator];
  self.activityIndicator.hidesWhenStopped = YES;
}

-(void)requestMicPermission {
  [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
    if (granted) {
      NSLog(@"permission granted in requestMicPermission");
      if (!self.speechEngine) {
        self.speechEngine = [SpeechEngine new];
        self.speechEngine.delegate = self;
        [self.speechEngine setupOpenEarsWithCardNames:self.cardNames];
//        [self.speechEngine startLogging];
        [self showFirstCard];
      }
    } else {
      NSLog(@"permission not granted in requestMicPermission");
      [self handleMicError];
    }
  }];
}

-(void)instantiateImageView {
  self.imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 290, 396)];
  [self.view addSubview:self.imageView];
  self.imageView.contentMode = UIViewContentModeScaleAspectFit;
}

-(void)populateCardNames {
  
  NSArray *jsonFileNames = @[@"Basic.enUS", @"Expert.enUS", @"Reward.enUS", @"Promotion.enUS", @"Naxxramas.enUS"];
  
  NSMutableArray *tempCardNamesArray = [NSMutableArray arrayWithCapacity:kKnownCardsCount];
  
  for (NSString *jsonFileName in jsonFileNames) {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:jsonFileName ofType:@"json"];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    NSError *error;
    
    NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:fileData options:kNilOptions error:&error];

    for (NSDictionary *card in jsonArray) {
      [tempCardNamesArray addObject:card[@"name"]];
    }
  }
  
  NSMutableSet *setToRemoveDuplicates = [NSMutableSet setWithArray:tempCardNamesArray];
  
    // retired cards, heroes, and Naxx bosses that are not cards
  NSArray *arrayOfFileNamesToRemove = @[@"'Inspired'", @"AFK", @"Alexstrasza's Fire", @"Ancestral Infusion", @"Berserk", @"Berserking", @"Blarghghl", @"Blood Pact", @"Bloodrage", @"Bolstered", @"Cabal Control", @"Cannibalize", @"Claws", @"Cleric's Blessing", @"Coin's Vengeance", @"Coin's Vengence", @"Commanding", @"Concealed", @"Consume", @"Dark Command", @"Darkness Calls", @"Demoralizing Roar", @"Elune's Grace", @"Emboldened!", @"Empowered", @"Enhanced", @"Equipped", @"Experiments!", @"Extra Teeth", @"Eye In The Sky", @"Flametongue", @"Frostwolf Banner", @"Full Belly", @"Full Strength", @"Fungal Growth", @"Furious Howl", @"Greenskin's Command", @"Growth", @"Hand of Argus", @"Hexxed", @"Hour of Twilight", @"Infusion", @"Interloper!", @"Justice Served", @"Keeping Secrets", @"Kill Millhouse!", @"Level Up!", @"Luck of the Coin", @"Mana Gorged", @"Master's Presence", @"Might of Stormwind", @"Mind Controlling", @"Mlarggragllabl!", @"Mrgglaargl!", @"Mrghlglhal", @"Needs Sharpening", @"Overloading", @"Plague", @"Polarity", @"Power of the Kirin Tor", @"Power of the Ziggurat", @"Raw Power!", @"Shadows of M'uru", @"Sharp!", @"Sharpened", @"Slave of Kel'Thuzad", @"Stand Down!", @"Strength of the Pack", @"Supercharged", @"Teachings of the Kirin Tor", @"Tempered", @"Templar's Verdict", @"Transformed", @"Trapped", @"Treasure Crazed", @"Upgraded", @"Uprooted", @"VanCleef's Vengeance", @"Vengeance", @"Warded", @"Well Fed", @"Whipped Into Shape", @"Yarrr!",
                                        
      @"Anduin Wrynn", @"Garrosh Hellscream", @"Gul'dan", @"Jaina Proudmoore", @"Malfurion Stormrage", @"Rexxar", @"Thrall", @"Uther Lightbringer", @"Valeera Sanguinar",
                                        
      @"Anub'Rekhan", @"Grand Widow Faerlina", @"Noth the Plaguebringer", @"Heigan the Unclean", @"Instructor Razuvious", @"Gothik the Harvester", @"Patchwerk", @"Grobbulus", @"Gluth", @"Sapphiron"
      ];
  
  NSSet *setOfFileNamesToRemove = [NSSet setWithArray:arrayOfFileNamesToRemove];
  [setToRemoveDuplicates minusSet:setOfFileNamesToRemove];
  NSArray *arrayWithNoDuplicatesAndFilesRemoved = [NSArray arrayWithArray:[setToRemoveDuplicates allObjects]];
  
  self.cardNames = [arrayWithNoDuplicatesAndFilesRemoved sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

  NSUInteger longestCardNameLength = 0;
  NSString *longestCardName;
  for (NSString *cardName in self.cardNames) {
    NSLog(@"%@", cardName);
    if (cardName.length > longestCardNameLength) {
      longestCardNameLength = cardName.length;
      longestCardName = cardName;
    }
  }
  
  NSLog(@"longestCardName is %i, %@", longestCardNameLength, longestCardName);
  
//
//  NSLog(@"count is %lu", (unsigned long)self.cardNames.count);
}

-(void)instantiateSessions {
  NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
  
  self.dataSession = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
  
  NSURLSessionConfiguration *backgroundConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.bennettslin.hearthSpeak"];
  
  self.downloadSession = [NSURLSession sessionWithConfiguration:backgroundConfiguration delegate:self delegateQueue:nil];
}

#pragma mark - picker methods

-(void)movePickerToClosestCardForHypothesisedString:(NSString *)hypothesisedString {
  
  NSUInteger index = [self.speechEngine closestIndexForString:hypothesisedString inArray:self.cardNames];
  [self.cardPicker selectRow:index inComponent:0 animated:YES];
  
    // weird to call this, but it seems like it doesn't get called otherwise by selectRow: method
  [self pickerView:self.cardPicker didSelectRow:index inComponent:0];
}

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
  return 1;
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
  return self.cardNames.count;
}

-(UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {
  
  UILabel *textView = (UILabel *)view;
  if (!textView) {
    textView = [[UILabel alloc] init];
    textView.font = [UIFont fontWithName:@"BelweBT-Bold" size:20];
    textView.textColor = [UIColor whiteColor];
    textView.textAlignment = NSTextAlignmentCenter;
  }
    // Fill the label text here
  textView.text = self.cardNames[row];
  return textView;
}

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
  
  NSString *pickedCardName = self.cardNames[row];
  NSString *formattedPickedCardName = [self formatCardName:pickedCardName];
  [self fetchURLDataForFormattedCardName:formattedPickedCardName];
}

#pragma mark - NSURLSession methods

-(void)fetchURLDataForFormattedCardName:(NSString *)formattedName {
  
    // fetches the first card that starts with the name
    // this works for now, but it may break in the future
  
  NSUInteger cardLimit = 1;
  
    // kludge workaround for now
  if ([formattedName isEqualToString:@"Equality"]) {
    cardLimit = 2;
  } else if ([formattedName isEqualToString:@"Leader_of_the_Pack"]) {
    cardLimit = 2;
  } else if ([formattedName isEqualToString:@"Lord_Jaraxxus"]) {
    cardLimit = 2;
  } else if ([formattedName isEqualToString:@"Sen%27jin_Shieldmasta"]) {
    cardLimit = 2;
  }
  
  NSString *urlString = [NSString stringWithFormat:@"http://hearthstone.gamepedia.com/api.php?action=query&list=allimages&format=json&aimime=image/png&ailimit=%i&aifrom=%@", cardLimit, formattedName];
  
  NSURL *dataUrl = [NSURL URLWithString:urlString];
  NSLog(@"dataUrl is %@", dataUrl);
  
  NSURLRequest *dataRequest = [NSURLRequest requestWithURL:dataUrl];
  
  NSURLSessionDataTask *dataTask = [self.dataSession dataTaskWithRequest:dataRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    
    if (error) {
      [self handleSessionError:error];
      
    } else {
      
      [self startActivityIndicator];
      
      NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
      
      NSDictionary *queryDictionary = jsonDictionary[@"query"];
      NSArray *allImagesArray = queryDictionary[@"allimages"];
      
      NSDictionary *dictionary = allImagesArray[cardLimit - 1];
      NSString *dictionaryString = dictionary[@"name"];
      NSString *formattedDictionaryString = [self formatCardName:dictionaryString];
      
      NSRange textRange = [formattedDictionaryString rangeOfString:formattedName];
      
      if (textRange.location != NSNotFound) {
        
        NSURL *newURL = [NSURL URLWithString:dictionary[@"url"]];
        [self fetchDownloadForURL:newURL];
      }
    }
  }];
  
  [dataTask resume];
}

-(void)fetchDownloadForURL:(NSURL *)url {
  
  NSURLRequest *request = [NSURLRequest requestWithURL:url];
  NSURLSessionDownloadTask *downloadTask = [self.downloadSession downloadTaskWithRequest:request];
  
  [downloadTask resume];
}

-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
  
  UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:location]];
  
  if (image) {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      weakSelf.imageView.image = image;
    });
  }
  
  [self stopActivityIndicator];
}

-(void)handleSessionError:(NSError *)error {
  [self stopActivityIndicator];
  [self presentViewController:self.sessionAlertController animated:YES completion:nil];
}

-(void)handleMicError {
  [self presentViewController:self.micAlertController animated:YES completion:nil];
}

#pragma mark - activity indicator

-(void)startActivityIndicator {
//  NSLog(@"activity start");
  if (!self.activityIndicator.isAnimating) {
    [NSThread detachNewThreadSelector:@selector(startActivityIndicatorInNewThread) toTarget:self withObject:nil];
  }
}

-(void)startActivityIndicatorInNewThread {
//  NSLog(@"activity start in new thread");
  [self.activityIndicator startAnimating];
}

-(void)stopActivityIndicator {
//  NSLog(@"activity stop");
  if (self.activityIndicator.isAnimating) {
    [NSThread detachNewThreadSelector:@selector(stopActivityIndicatorInNewThread) toTarget:self withObject:nil];
  }
}

-(void)stopActivityIndicatorInNewThread {
//  NSLog(@"activity stop in new thread");
  [self.activityIndicator stopAnimating];
}

#pragma mark - card helper methods

-(NSString *)formatCardName:(NSString *)unformattedName {
  NSString *underscoredString = [unformattedName stringByReplacingOccurrencesOfString:@" " withString:@"_"];
  NSString *apostrophedString = [underscoredString stringByReplacingOccurrencesOfString:@"'" withString:@"%27"];
  NSString *colonedString = [apostrophedString stringByReplacingOccurrencesOfString:@":" withString:@"-"];
  return colonedString;
}

#pragma mark - system methods

-(UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

-(NSUInteger)supportedInterfaceOrientations {
  return UIInterfaceOrientationMaskAll;
}

@end
