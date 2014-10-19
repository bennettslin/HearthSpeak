//
//  SpeechEngine.m
//  HearthSpeak
//
//  Created by Bennett Lin on 10/18/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import "SpeechEngine.h"
#import <OpenEars/AcousticModel.h>
#import <OpenEars/LanguageModelGenerator.h>
#import <OpenEars/OpenEarsEventsObserver.h>
#import <OpenEars/PocketsphinxController.h>
#import <OpenEars/OpenEarsLogging.h>

#define kModelName @"HearthstoneWords"

@interface SpeechEngine () <OpenEarsEventsObserverDelegate>

@property (strong, nonatomic) LanguageModelGenerator *languageModelGenerator;
@property (strong, nonatomic) PocketsphinxController *pocketsphinxController;
@property (strong, nonatomic) OpenEarsEventsObserver *eventsObserver;

@end

@implementation SpeechEngine
@synthesize pocketsphinxController = _pocketsphinxController;
@synthesize eventsObserver = _eventsObserver;

-(void)setupOpenEarsWithCardNames:(NSArray *)cardNames {
  self.languageModelGenerator = [LanguageModelGenerator new];
  
//  NSArray *uppercaseWords = [self returnStrippedUppercaseArray:cardNames];
  NSArray *uppercaseWords = @[@"CONCEAL"];
  
  NSString *acousticModelPath = [AcousticModel pathToModel:@"AcousticModelEnglish"];
  
  NSError *error = [self.languageModelGenerator generateLanguageModelFromArray:uppercaseWords withFilesNamed:kModelName forAcousticModelAtPath:acousticModelPath];
  
  NSDictionary *languageGeneratorResults;
  NSString *languageModelPath;
  NSString *dictionaryPath;
  
  if ([error code] == noErr) {
    languageGeneratorResults = [error userInfo];
    languageModelPath = [languageGeneratorResults objectForKey:@"LMPath"];
    dictionaryPath = [languageGeneratorResults objectForKey:@"DictionaryPath"];
    
    [self.eventsObserver setDelegate:self];
    [self.pocketsphinxController startListeningWithLanguageModelAtPath:languageModelPath dictionaryAtPath:dictionaryPath acousticModelAtPath:acousticModelPath languageModelIsJSGF:NO];
  } else {
    NSLog(@"error: %@", [error localizedDescription]);
  }
}

-(void)startLogging {
  [OpenEarsLogging startOpenEarsLogging];
}

#pragma mark - custom getters

-(PocketsphinxController *)pocketsphinxController {
  
  if (!_pocketsphinxController) {
    _pocketsphinxController = [PocketsphinxController new];
    NSLog(@"instantiate pocketSphinxController");
  }
  return _pocketsphinxController;
}

-(OpenEarsEventsObserver *)eventsObserver {
  
  if (!_eventsObserver) {
    _eventsObserver = [OpenEarsEventsObserver new];
    NSLog(@"instantiate eventsObserver");
  }
  return _eventsObserver;
}

#pragma mark - openEars methods

-(void)pocketsphinxFailedNoMicPermissions {
  [self.delegate handleMicError];
}

-(void)pocketsphinxDidReceiveHypothesis:(NSString *)hypothesis recognitionScore:(NSString *)recognitionScore utteranceID:(NSString *)utteranceID {
  NSLog(@"The received hypothesis is %@ with a score of %@ and an ID of %@", hypothesis, recognitionScore, utteranceID);
  if (hypothesis) {
    [self.delegate startActivityIndicator];
    [self.delegate movePickerToClosestCardForHypothesisedString:hypothesis];
  }
}

-(void)pocketsphinxDidStartCalibration {
  NSLog(@"Calibration started.");
}

-(void)pocketsphinxDidStartListening {
  NSLog(@"Now listening.");
}

-(void)pocketsphinxDidDetectSpeech {
  NSLog(@"Detected speech.");
}

-(void)pocketsphinxDidDetectFinishedSpeech {
  NSLog(@"Period of silence means utterance concluded.");
}

-(void)pocketsphinxDidStopListening {
  NSLog(@"Stopped listening.");
}

-(void)pocketsphinxDidSuspendRecognition {
  NSLog(@"Suspended recognition");
}

-(void)pocketsphinxDidResumeRecognition {
  NSLog(@"Resumed recognition.");
}

-(void)pocketsphinxDidChangeLanguageModelToFile:(NSString *)newLanguageModelPathAsString andDictionary:(NSString *)newDictionaryPathAsString {
  NSLog(@"Continuous recognition loop failed for some reason.");
}

-(void)testRecognitionCompleted {
  NSLog(@"Test file submitted and complete.");
}

#pragma mark - string helper methods

-(NSUInteger)closestIndexForString:(NSString *)hypothesisedString inArray:(NSArray *)cardNames {
  
  NSArray *individualWords = [hypothesisedString componentsSeparatedByString:@" "];
  NSString *hypothesisedWord = [individualWords firstObject];
  
  NSUInteger secondBestIndex = 0;
  
  for (int i = 0; i < cardNames.count; i++) {
    NSString *strippedUppercaseCardString = [self returnStrippedUppercaseString:cardNames[i]];
    NSComparisonResult result = [strippedUppercaseCardString compare:hypothesisedWord];
    if (result == NSOrderedSame) {
      return i;
    } else if (result == NSOrderedDescending) {
      secondBestIndex = (i - 1 > 0) ? i - 1 : 0;
    }
  }
  
  return secondBestIndex;
}

-(NSArray *)returnStrippedUppercaseArray:(NSArray *)arrayOfStrings {
  NSMutableArray *tempArray = [NSMutableArray new];
  for (NSString *rawString in arrayOfStrings) {
    NSString *formattedString = [self returnStrippedUppercaseString:rawString];
    [tempArray addObject:formattedString];
  }
  return [NSArray arrayWithArray:tempArray];
}

-(NSString *)returnStrippedUppercaseString:(NSString *)rawString {
  NSString *uppercaseString = [rawString uppercaseString];
  NSString *noSpaceString = [uppercaseString stringByReplacingOccurrencesOfString:@" " withString:@""];
  NSString *noColonString = [noSpaceString stringByReplacingOccurrencesOfString:@":" withString:@""];
  NSString *noApostropheString = [noColonString stringByReplacingOccurrencesOfString:@"'" withString:@""];
  NSString *noPeriodString = [noApostropheString stringByReplacingOccurrencesOfString:@"." withString:@""];
  NSString *noExclamationString = [noPeriodString stringByReplacingOccurrencesOfString:@"!" withString:@""];
  return noExclamationString;
}

@end
