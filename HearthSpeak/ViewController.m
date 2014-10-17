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

@end

@implementation ViewController

-(void)viewDidLoad {
  [super viewDidLoad];
  
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
  NSString *filePath = [[NSBundle mainBundle] pathForResource:@"hearthstoneCards" ofType:@"json"];
  NSData *fileData = [NSData dataWithContentsOfFile:filePath];
  NSError *error;
  
  NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:fileData options:kNilOptions error:&error];
  NSMutableArray *tempCardNamesArray = [NSMutableArray arrayWithCapacity:800];
  
  for (id key in jsonDictionary) {
      //    NSLog(@"key is %@, value is %@", key, [jsonDictionary objectForKey:key]);
    NSArray *cardSetArray = [jsonDictionary objectForKey:key];
    for (NSDictionary *card in cardSetArray) {
      [tempCardNamesArray addObject:card[@"name"]];
    }
  }
  
  self.cardNames = [tempCardNamesArray sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
  /*
  for (NSString *cardName in self.cardNames) {
    NSLog(@"%@", cardName);
  }
  */
    //  NSLog(@"count is %i", tempCardNamesArray.count);
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

-(NSAttributedString *)pickerView:(UIPickerView *)pickerView attributedTitleForRow:(NSInteger)row forComponent:(NSInteger)component
{
  NSString *title = self.cardNames[row];
  NSAttributedString *attString = [[NSAttributedString alloc] initWithString:title attributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}];
  
  return attString;
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
    
    NSString *lowercaseFormattedString = [formattedName lowercaseString];
    
    for (NSDictionary *dictionary in allImagesArray) {
      NSString *lowercaseDictionaryString = [dictionary[@"name"] lowercaseString];
      
      NSRange textRange = [lowercaseDictionaryString rangeOfString:lowercaseFormattedString];
      
      if (textRange.location != NSNotFound) {
        
        NSLog(@"imageUrl is %@", dictionary[@"url"]);
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
  NSString *capitalisedString = [unformattedName capitalizedString];
  NSString *underscoredString = [capitalisedString stringByReplacingOccurrencesOfString:@" " withString:@"_"];
  return underscoredString;
}

@end
