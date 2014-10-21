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
#import "Constants.h"

#define kKnownCardsCount 549
#define kImageViewWidth 320
#define kImageViewHeight 396
#define kPickerWidth 240
#define kPickerHeight 162
#define kStatusLabelWidth 60
#define kStatusLabelHeight 60
#define kBottomPadding 10
#define kSidePadding 10

@interface ViewController () <UIPickerViewDataSource, UIPickerViewDelegate, NSURLSessionDownloadDelegate, OpenEarsSpeechEngineDelegate>

@property (strong, nonatomic) NSArray *displayCardNames;
@property (strong, nonatomic) NSArray *uppercaseSpacedCardNames;

@property (strong, nonatomic) UIImageView *imageView;
@property (strong, nonatomic) UIPickerView *cardPicker;
@property (strong, nonatomic) UIImageView *statusView;

@property (strong, nonatomic) UIAlertController *sessionAlertController;
@property (strong, nonatomic) UIAlertController *micAlertController;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicator;

@property (strong, nonatomic) NSURLSession *dataSession;
@property (strong, nonatomic) NSURLSession *downloadSession;

@property (strong, nonatomic) SpeechEngine *speechEngine;

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
  
  _statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
  
  _screenShort = self.view.bounds.size.width;
  _screenLong = self.view.bounds.size.height;
  
  if (_screenShort > _screenLong) {
    CGFloat higherValue = _screenShort;
    _screenShort = _screenLong;
    _screenLong = higherValue;
  }

  self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"wood_background.jpg"]];

  [self instantiateStatusView];
  [self instantiatePicker];
  [self instantiateImageView];
  [self instantiateActivityIndicator];
  [self populateCardNames];
  [self instantiateSessions];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestMicPermission) name:UIApplicationWillEnterForegroundNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestMicPermission) name:UIApplicationDidFinishLaunchingNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resizeAndRepositionBasedOnOrientation:) name:UIDeviceOrientationDidChangeNotification object:nil];
  
    // first card is shown either when mic permission is proven granted
    // or else after mic alert controller is presented and dismissed
}

-(void)viewWillAppear:(BOOL)animated {
  [self resizeAndRepositionBasedOnOrientation:nil];
}

-(void)resizeAndRepositionBasedOnOrientation:(NSNotification *)notification {
  
//  NSLog(@"status bar height is %.2f", _statusBarHeight);
  const CGFloat minimumScreenHeight = _statusBarHeight + kImageViewHeight + kPickerHeight + kBottomPadding;
  const CGFloat minimumScreenWidth = kImageViewWidth + kPickerWidth + (kSidePadding * 2);
  
  CGFloat imageViewHeight;
  CGFloat imageViewWidth;
  CGFloat verticalMargin;
  CGFloat horizontalMargin;
  
  CGFloat pickerAndStatusHorizontalMargin;
  CGFloat pickerAndStatusVerticalMargin;
  
  CGFloat verticalMarginMultiplier = 0.9f;
  
  UIDevice *device = [UIDevice currentDevice];
  UIDeviceOrientation orientation = device.orientation;
  
  switch (orientation) {
      
    case UIDeviceOrientationPortrait:
      imageViewHeight = _screenLong > minimumScreenHeight ?
      kImageViewHeight : _screenLong - _statusBarHeight - kPickerHeight - kBottomPadding;
      verticalMargin = (_screenLong - _statusBarHeight - imageViewHeight - kPickerHeight - kBottomPadding) / 3;
      
      pickerAndStatusHorizontalMargin = (_screenShort - kPickerWidth - kStatusLabelWidth) / 3;
      
      self.imageView.frame = CGRectMake((_screenShort - kImageViewWidth) / 2, _statusBarHeight + verticalMargin, kImageViewWidth, imageViewHeight);
      self.cardPicker.frame = CGRectMake(_screenShort - kPickerWidth - pickerAndStatusHorizontalMargin, _screenLong - kPickerHeight - kBottomPadding - verticalMargin, kPickerWidth, kPickerHeight);
      self.statusView.frame = CGRectMake(pickerAndStatusHorizontalMargin, 0, kStatusLabelWidth, kStatusLabelHeight);
      self.statusView.center = CGPointMake(self.statusView.center.x, self.cardPicker.center.y);
      break;
      
    case UIDeviceOrientationPortraitUpsideDown:
      imageViewHeight = _screenLong > minimumScreenHeight ?
          kImageViewHeight : _screenLong - _statusBarHeight - kPickerHeight - kBottomPadding;
      verticalMargin = (_screenLong - _statusBarHeight - imageViewHeight - kPickerHeight - kBottomPadding) / 3;
      
      pickerAndStatusHorizontalMargin = (_screenShort - kPickerWidth - kStatusLabelWidth) / 3;
      
      self.imageView.frame = CGRectMake((_screenShort - kImageViewWidth) / 2, _screenLong - imageViewHeight - kBottomPadding - verticalMargin, kImageViewWidth, imageViewHeight);
      self.cardPicker.frame = CGRectMake(pickerAndStatusHorizontalMargin, _statusBarHeight + verticalMargin, kPickerWidth, kPickerHeight);
      self.statusView.frame = CGRectMake(_screenShort - kStatusLabelWidth - pickerAndStatusHorizontalMargin, 0, kStatusLabelWidth, kStatusLabelHeight);
      self.statusView.center = CGPointMake(self.statusView.center.x, self.cardPicker.center.y);
      break;
      
    case UIDeviceOrientationLandscapeLeft:
      imageViewWidth = _screenLong > minimumScreenWidth ?
          kImageViewWidth : _screenLong - kPickerWidth - (kSidePadding * 2);
      imageViewHeight = _screenShort > kImageViewHeight ? kImageViewHeight : _screenShort;
      horizontalMargin = (_screenLong - imageViewWidth - kPickerWidth) / 3;
      
      pickerAndStatusVerticalMargin = (_screenShort - kPickerHeight - kStatusLabelHeight) / 3;
      
      self.imageView.frame = CGRectMake(horizontalMargin, (_screenShort - imageViewHeight) / 2, imageViewWidth, imageViewHeight);
      self.cardPicker.frame = CGRectMake(_screenLong - kPickerWidth - horizontalMargin, _screenShort - kPickerHeight - pickerAndStatusVerticalMargin * verticalMarginMultiplier, kPickerWidth, kPickerHeight);
      self.statusView.frame = CGRectMake(0, pickerAndStatusVerticalMargin / verticalMarginMultiplier, kStatusLabelWidth, kStatusLabelHeight);
      self.statusView.center = CGPointMake(self.cardPicker.center.x, self.statusView.center.y);
      break;
      
    case UIDeviceOrientationLandscapeRight:
      imageViewWidth = _screenLong > minimumScreenWidth ?
          kImageViewWidth : _screenLong - kPickerWidth - (kSidePadding * 2);
      imageViewHeight = _screenShort > kImageViewHeight ? kImageViewHeight : _screenShort;
      horizontalMargin = (_screenLong - imageViewWidth - kPickerWidth) / 3;
      
      pickerAndStatusVerticalMargin = (_screenShort - kPickerHeight - kStatusLabelHeight) / 3;
      
      self.imageView.frame = CGRectMake(_screenLong - imageViewWidth - horizontalMargin, (_screenShort - imageViewHeight) / 2, imageViewWidth, imageViewHeight);
      self.cardPicker.frame = CGRectMake(horizontalMargin, _screenShort - kPickerHeight - pickerAndStatusVerticalMargin * verticalMarginMultiplier, kPickerWidth, kPickerHeight);
      self.statusView.frame = CGRectMake(0, pickerAndStatusVerticalMargin / verticalMarginMultiplier, kStatusLabelWidth, kStatusLabelHeight);
      self.statusView.center = CGPointMake(self.cardPicker.center.x, self.statusView.center.y);
      break;

      default:
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
    _micAlertController = [UIAlertController alertControllerWithTitle:@"Can't hear you!" message:@"Go to Settings\u00a0> Privacy\u00a0> Microphone to grant access." preferredStyle:UIAlertControllerStyleAlert];
    [_micAlertController addAction:[UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      [self pickerView:self.cardPicker didSelectRow:[self.cardPicker selectedRowInComponent:0] inComponent:0];
    }]];
  }
  return _micAlertController;
}

#pragma mark - setup methods

-(void)instantiatePicker {
  self.cardPicker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 0, kPickerWidth, kPickerHeight)];
  [self.view addSubview:self.cardPicker];
  self.cardPicker.dataSource = self;
  self.cardPicker.delegate = self;
}

-(void)instantiateActivityIndicator {
  self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
  [self.view addSubview:self.activityIndicator];
  self.activityIndicator.hidesWhenStopped = YES;
}

-(void)instantiateStatusView {
  self.statusView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, kStatusLabelWidth, kStatusLabelHeight)];
  [self.view addSubview:self.statusView];
}

-(void)updateStatusViewForOpenEarsStatus:(OpenEarsStatus)status {
  
  UIImage *imageZero = [UIImage imageNamed:@"ear_loading0"];
  UIImage *imageOne = [UIImage imageNamed:@"ear_loading1"];
  UIImage *imageTwo = [UIImage imageNamed:@"ear_loading2"];
  UIImage *imageThree = [UIImage imageNamed:@"ear_loading3"];
  
  NSArray *imagesArray = @[imageZero, imageOne, imageTwo, imageThree];
  
  switch (status) {
    case kOpenEarsNotAvailable:
//      self.statusView.text = @"mic not available";
      [self.statusView stopAnimating];
      self.statusView.image = [UIImage imageNamed:@"ear_unavailable"];
      break;
    case kOpenEarsLoading:
//      self.statusView.text = @"loading...";
      self.statusView.animationImages = imagesArray;
      self.statusView.animationDuration = 1.5f;
      self.statusView.animationRepeatCount = 0;
      [self.statusView startAnimating];
      break;
    case kOpenEarsStartedListening:
//      self.statusView.text = @"listening";
      [self.statusView stopAnimating];
      self.statusView.image = [UIImage imageNamed:@"ear_listening"];
      break;
    default:
      break;
  }
}

-(void)requestMicPermission {
  [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
    if (granted) {
      
//      NSLog(@"permission granted in requestMicPermission");
      if (!self.speechEngine) {
        [self updateStatusViewForOpenEarsStatus:kOpenEarsLoading];
        self.speechEngine = [SpeechEngine new];
        self.speechEngine.delegate = self;
        
        __weak typeof(self) weakSelf = self;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          [weakSelf.speechEngine setupOpenEarsWithCardNames:self.uppercaseSpacedCardNames];
        });

//        [self.speechEngine startLogging];
        [self showFirstCard];
      }
    } else {
//      NSLog(@"permission not granted in requestMicPermission");
      [self handleMicError];
      [self updateStatusViewForOpenEarsStatus:kOpenEarsNotAvailable];
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
  
  self.displayCardNames = [arrayWithNoDuplicatesAndFilesRemoved sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

  NSMutableArray *tempUppercaseArray = [NSMutableArray new];
  for (NSString *displayString in self.displayCardNames) {
    NSString *uppercaseString = [self uppercaseStringWithPunctuationReplacedByWhitespace:displayString];
    [tempUppercaseArray addObject:uppercaseString];
  }
  self.uppercaseSpacedCardNames = [NSArray arrayWithArray:tempUppercaseArray];
  
//  NSLog(@"self.displayCardNames is %@", self.displayCardNames);
//  NSLog(@"self.uppercaseSpacedCardNames is %@", self.uppercaseSpacedCardNames);
  
  /*
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
  NSLog(@"count is %lu", (unsigned long)self.cardNames.count);
   */
}

-(void)instantiateSessions {
  NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
  
  self.dataSession = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
  
  NSURLSessionConfiguration *backgroundConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.bennettslin.hearthSpeak"];
  
  self.downloadSession = [NSURLSession sessionWithConfiguration:backgroundConfiguration delegate:self delegateQueue:nil];
}

#pragma mark - picker methods

-(void)movePickerToClosestCardForHypothesisedString:(NSString *)hypothesisedString {
  
  NSUInteger index = [self.speechEngine closestIndexForString:hypothesisedString inArray:self.uppercaseSpacedCardNames];
  
  if (index != NSUIntegerMax) {
    [self.cardPicker selectRow:index inComponent:0 animated:YES];
    
      // weird to call this, but it seems like it doesn't get called otherwise by selectRow: method
    [self pickerView:self.cardPicker didSelectRow:index inComponent:0];
  }
}

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
  return 1;
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
  return self.displayCardNames.count;
}

-(UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {
  
  UILabel *textView = (UILabel *)view;
  if (!textView) {
    textView = [[UILabel alloc] init];
    textView.font = [UIFont fontWithName:kBelweFont size:20];
    textView.textColor = [UIColor whiteColor];
    textView.textAlignment = NSTextAlignmentCenter;
  }
    // Fill the label text here
  textView.text = self.displayCardNames[row];
  return textView;
}

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
  
  NSString *pickedCardName = self.displayCardNames[row];
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
  } else if ([formattedName isEqualToString:@"Millhouse_Manastorm"]) {
    cardLimit = 2;
  } else if ([formattedName isEqualToString:@"Sen%27jin_Shieldmasta"]) {
    cardLimit = 2;
  }
  
  NSString *urlString = [NSString stringWithFormat:@"http://hearthstone.gamepedia.com/api.php?action=query&list=allimages&format=json&aimime=image/png&ailimit=%lu&aifrom=%@", (unsigned long)cardLimit, formattedName];
  
  NSURL *dataUrl = [NSURL URLWithString:urlString];
//  NSLog(@"dataUrl is %@", dataUrl);
  
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
  if (!self.activityIndicator.isAnimating) {
    [NSThread detachNewThreadSelector:@selector(startActivityIndicatorInNewThread) toTarget:self withObject:nil];
  }
}

-(void)startActivityIndicatorInNewThread {
  [self.activityIndicator startAnimating];
}

-(void)stopActivityIndicator {
  if (self.activityIndicator.isAnimating) {
    [NSThread detachNewThreadSelector:@selector(stopActivityIndicatorInNewThread) toTarget:self withObject:nil];
  }
}

-(void)stopActivityIndicatorInNewThread {
  [self.activityIndicator stopAnimating];
}

#pragma mark - card helper methods

-(NSString *)formatCardName:(NSString *)unformattedName {
  NSString *underscoredString = [unformattedName stringByReplacingOccurrencesOfString:@" " withString:@"_"];
  NSString *apostrophedString = [underscoredString stringByReplacingOccurrencesOfString:@"'" withString:@"%27"];
  NSString *colonedString = [apostrophedString stringByReplacingOccurrencesOfString:@":" withString:@"-"];
  return colonedString;
}

-(NSString *)uppercaseStringWithPunctuationReplacedByWhitespace:(NSString *)rawString {
  NSString *uppercaseString = [rawString uppercaseString];
  NSString *noColonString = [uppercaseString stringByReplacingOccurrencesOfString:@":" withString:@""];
  NSString *noApostropheString = [noColonString stringByReplacingOccurrencesOfString:@"'" withString:@""];
  NSString *noPeriodString = [noApostropheString stringByReplacingOccurrencesOfString:@"." withString:@""];
  NSString *noExclamationString = [noPeriodString stringByReplacingOccurrencesOfString:@"!" withString:@""];
  NSString *noHyphenString = [noExclamationString stringByReplacingOccurrencesOfString:@"-" withString:@""];
  return noHyphenString;
}

#pragma mark - system methods

-(UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

-(NSUInteger)supportedInterfaceOrientations {
  return UIInterfaceOrientationMaskAll;
}

@end
