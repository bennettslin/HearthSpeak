//
//  ViewController.m
//  HearthSpeak
//
//  Created by Bennett Lin on 10/12/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

// for API information: http://hearthstone.gamepedia.com/api.php

#import "ViewController.h"

@interface ViewController () <UIPickerViewDataSource, UIPickerViewDelegate, NSURLSessionDownloadDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIPickerView *cardPicker;

@property (strong, nonatomic) NSArray *cardNames;

@property (strong, nonatomic) NSURLSession *dataSession;
@property (strong, nonatomic) NSURLSession *downloadSession;

  // FIXME: these properties are for getting rid of retired cards
  // they should be commented out before distribution
@property (assign, nonatomic) NSUInteger debugCounter;
@property (strong, nonatomic) NSMutableArray *cardNamesToRemove;

@end

@implementation ViewController

-(void)viewDidLoad {
  [super viewDidLoad];

  for (NSString* family in [UIFont familyNames]) {
    NSLog(@"%@", family);
    
    for (NSString* name in [UIFont fontNamesForFamilyName: family])
      {
      NSLog(@"  %@", name);
      }
    }
  
  self.cardNamesToRemove = [NSMutableArray new];
  
  self.cardPicker.dataSource = self;
  self.cardPicker.delegate = self;
  
  [self declareImageViewProperties];
  [self populateCardNames];
  [self instantiateSessions];
}

-(void)declareImageViewProperties {
  self.imageView.layer.borderColor = [UIColor colorWithRed:0xff/255.f green:0x00/255.f blue:0x00/255.f alpha:0xff/255.f].CGColor;
  self.imageView.layer.borderWidth = 1.f;
  self.imageView.contentMode = UIViewContentModeScaleAspectFit;
}

-(void)populateCardNames {
  
  NSArray *jsonFileNames = @[@"Basic.enUS", @"Expert.enUS", @"Reward.enUS", @"Promotion.enUS", @"Naxxramas.enUS"];
  
  NSMutableArray *tempCardNamesArray = [NSMutableArray arrayWithCapacity:568];
  
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
  
    // retired cards
  NSArray *arrayOfFileNamesToRemove = @[@"'Inspired'", @"AFK", @"Alexstrasza's Fire", @"Ancestral Infusion", @"Berserk", @"Berserking", @"Blarghghl", @"Blood Pact", @"Bloodrage", @"Bolstered", @"Cabal Control", @"Cannibalize", @"Claws", @"Cleric's Blessing", @"Coin's Vengeance", @"Coin's Vengence", @"Commanding", @"Concealed", @"Consume", @"Dark Command", @"Darkness Calls", @"Demoralizing Roar", @"Elune's Grace", @"Emboldened!", @"Empowered", @"Enhanced", @"Equipped", @"Experiments!", @"Extra Teeth", @"Eye In The Sky", @"Flametongue", @"Frostwolf Banner", @"Full Belly", @"Full Strength", @"Fungal Growth", @"Furious Howl", @"Greenskin's Command", @"Growth", @"Hand of Argus", @"Hexxed", @"Hour of Twilight", @"Infusion", @"Interloper!", @"Justice Served", @"Keeping Secrets", @"Kill Millhouse!", @"Leader of the Pack", @"Level Up!", @"Luck of the Coin", @"Mana Gorged", @"Master's Presence", @"Might of Stormwind", @"Mind Controlling", @"Mlarggragllabl!", @"Mrgglaargl!", @"Mrghlglhal", @"Needs Sharpening", @"Overloading", @"Plague", @"Polarity", @"Power of the Kirin Tor", @"Power of the Ziggurat", @"Raw Power!", @"Shadows of M'uru", @"Sharp!", @"Sharpened", @"Slave of Kel'Thuzad", @"Stand Down!", @"Strength of the Pack", @"Supercharged", @"Teachings of the Kirin Tor", @"Tempered", @"Templar's Verdict", @"Transformed", @"Trapped", @"Treasure Crazed", @"Upgraded", @"Uprooted", @"VanCleef's Vengeance", @"Vengeance", @"Warded", @"Well Fed", @"Whipped Into Shape", @"Yarrr!"];
  
  NSSet *setOfFileNamesToRemove = [NSSet setWithArray:arrayOfFileNamesToRemove];
  [setToRemoveDuplicates minusSet:setOfFileNamesToRemove];
  NSArray *arrayWithNoDuplicatesAndFilesRemoved = [NSArray arrayWithArray:[setToRemoveDuplicates allObjects]];
  
  self.cardNames = [arrayWithNoDuplicatesAndFilesRemoved sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

  for (NSString *cardName in self.cardNames) {
    NSLog(@"%@", cardName);
  }

  NSLog(@"count is %lu", (unsigned long)self.cardNames.count);
}

-(void)instantiateSessions {
  NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
  
  self.dataSession = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
  
  NSURLSessionConfiguration *backgroundConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.bennettslin.hearthSpeak"];
  
  self.downloadSession = [NSURLSession sessionWithConfiguration:backgroundConfiguration delegate:self delegateQueue:nil];
}

#pragma mark - picker methods

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
  NSString *urlString = [NSString stringWithFormat:@"http://hearthstone.gamepedia.com/api.php?action=query&list=allimages&format=json&aimime=image/png&ailimit=1&aifrom=%@", formattedName];
  
  NSURL *dataUrl = [NSURL URLWithString:urlString];
  
  NSLog(@"dataUrl is %@", dataUrl);
  
  NSURLRequest *dataRequest = [NSURLRequest requestWithURL:dataUrl];
  
  NSURLSessionDataTask *dataTask = [self.dataSession dataTaskWithRequest:dataRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    
    NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    
    NSDictionary *queryDictionary = jsonDictionary[@"query"];
    NSArray *allImagesArray = queryDictionary[@"allimages"];
    
    for (NSDictionary *dictionary in allImagesArray) {
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
}

#pragma mark - card helper methods

-(NSString *)formatCardName:(NSString *)unformattedName {
  NSString *underscoredString = [unformattedName stringByReplacingOccurrencesOfString:@" " withString:@"_"];
  NSString *apostrophedString = [underscoredString stringByReplacingOccurrencesOfString:@"'" withString:@"%27"];
  NSString *colonedString = [apostrophedString stringByReplacingOccurrencesOfString:@":" withString:@"-"];
  return colonedString;
}

#pragma mark - debug methods

-(void)checkIfCardIsRetiredAtIndex {
  
  NSString *pickedCardName = self.cardNames[self.debugCounter];
  NSString *formattedPickedCardName = [self formatCardName:pickedCardName];
  [self fetchURLDataForFormattedCardName:formattedPickedCardName];
  
}

@end
