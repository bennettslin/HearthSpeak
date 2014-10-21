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
#import "Constants.h"

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
  
  NSArray *uppercaseWords = [self returnStrippedUppercaseArray:cardNames];
  NSSet *noDoublesSet = [NSSet setWithArray:uppercaseWords];
  NSArray *noDoublesUppercaseWords = [noDoublesSet allObjects];
  NSArray *finalSortedArray = [noDoublesUppercaseWords sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
//  NSLog(@"final sorted array is %@", finalSortedArray);
  
  NSString *acousticModelPath = [AcousticModel pathToModel:@"AcousticModelEnglish"];
  
  NSError *error = [self.languageModelGenerator generateLanguageModelFromArray:finalSortedArray withFilesNamed:kModelName forAcousticModelAtPath:acousticModelPath];
  
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
//    NSLog(@"error: %@", [error localizedDescription]);
  }
}

-(void)startLogging {
  [OpenEarsLogging startOpenEarsLogging];
}

#pragma mark - custom getters

-(PocketsphinxController *)pocketsphinxController {
  
  if (!_pocketsphinxController) {
    _pocketsphinxController = [PocketsphinxController new];
//    NSLog(@"instantiate pocketSphinxController");
  }
  return _pocketsphinxController;
}

-(OpenEarsEventsObserver *)eventsObserver {
  
  if (!_eventsObserver) {
    _eventsObserver = [OpenEarsEventsObserver new];
//    NSLog(@"instantiate eventsObserver");
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
//  NSLog(@"Calibration started.");
}

-(void)pocketsphinxDidStartListening {
    // gets called continuously
  NSLog(@"Now listening.");
  [self.delegate updateStatusViewForOpenEarsStatus:kOpenEarsStartedListening];
}

-(void)pocketsphinxDidDetectSpeech {
//  NSLog(@"Detected speech.");
}

-(void)pocketsphinxDidDetectFinishedSpeech {
//  NSLog(@"Period of silence means utterance concluded.");
}

-(void)pocketsphinxDidStopListening {
//  NSLog(@"Stopped listening.");
  [self.delegate updateStatusViewForOpenEarsStatus:kOpenEarsNotAvailable];
}

-(void)pocketsphinxDidSuspendRecognition {
//  NSLog(@"Suspended recognition");
}

-(void)pocketsphinxDidResumeRecognition {
//  NSLog(@"Resumed recognition.");
}

-(void)pocketsphinxDidChangeLanguageModelToFile:(NSString *)newLanguageModelPathAsString andDictionary:(NSString *)newDictionaryPathAsString {
//  NSLog(@"Continuous recognition loop failed for some reason.");
}

-(void)testRecognitionCompleted {
//  NSLog(@"Test file submitted and complete.");
}

#pragma mark - string helper methods

-(NSUInteger)closestIndexForString:(NSString *)hypothesisedString inArray:(NSArray *)cardNames {

  NSArray *hypothesisedWordsArray = [hypothesisedString componentsSeparatedByString:@" "];

  NSUInteger indexOfWordAfterSortingOrder = NSUIntegerMax;
  NSMutableDictionary *exactWordsDictionary = [NSMutableDictionary new];
  BOOL exactMatchRuledOutForThisCard = NO;

    // iterate through cards
  for (int cardNameIndex = 0; cardNameIndex < cardNames.count; cardNameIndex++) {
    
    exactMatchRuledOutForThisCard = NO;
    
//    NSLog(@"comparing %@ to %@", hypothesisedString, cardNames[cardNameIndex]);
    
    NSArray *comparedWordsArray = [cardNames[cardNameIndex] componentsSeparatedByString:@" "];
    
      // iterate through words
    
    NSUInteger loopTimes = hypothesisedWordsArray.count > comparedWordsArray.count ?
        comparedWordsArray.count : hypothesisedWordsArray.count;
    
    for (int wordIndex = 0; wordIndex < loopTimes; wordIndex++) {
      
      NSString *hypothesisedWord = hypothesisedWordsArray[wordIndex];
      NSString *comparedWord = comparedWordsArray[wordIndex];
      
//      NSLog(@"comparing %@ to %@", hypothesisedWord, comparedWord);
      
        // word matches
      if ([hypothesisedWord isEqualToString:comparedWord]) {
        
          // remember the first instance of a first perfect word
        if (!exactWordsDictionary[[NSNumber numberWithInteger:wordIndex]]) {
            //            NSLog(@"first instance of first perfect word");
          [exactWordsDictionary setObject:[NSNumber numberWithInteger:cardNameIndex] forKey:[NSNumber numberWithInteger:wordIndex]];
        }
        
          // not ruled out and last word means perfect match
        if (!exactMatchRuledOutForThisCard && hypothesisedWord == hypothesisedWordsArray.lastObject) {
//          NSLog(@"perfect match");
          return cardNameIndex;
        }
        
          // word does not match
      } else {
        
        exactMatchRuledOutForThisCard = YES;
        
          // check alphabetical order only for first word
        if (hypothesisedWord == hypothesisedWordsArray.firstObject) {
          NSComparisonResult result = [comparedWord compare:hypothesisedWord];
          
            // only remember the first instance of a word that comes after alphabetically
          if (result == NSOrderedDescending && indexOfWordAfterSortingOrder == NSUIntegerMax) {
            indexOfWordAfterSortingOrder = cardNameIndex;
          }
        }
      }
    }
  }
  
    // return first perfect word, then word before word after sorting order, then nothing (which will not process)
  if (exactWordsDictionary.count > 0) {

    for (int i = 0; i < hypothesisedWordsArray.count; i++) {
      if (exactWordsDictionary[[NSNumber numberWithInteger:i]]) {
        return [exactWordsDictionary[[NSNumber numberWithInteger:i]] integerValue];
      }
    }
    
  } else if (indexOfWordAfterSortingOrder != NSUIntegerMax) {
    return indexOfWordAfterSortingOrder - 1;
  }
  
  return NSUIntegerMax;
}

-(NSArray *)returnStrippedUppercaseArray:(NSArray *)arrayOfStrings {
  NSMutableArray *tempArray = [NSMutableArray new];
  
  NSCharacterSet *separatorSet = [NSCharacterSet characterSetWithCharactersInString:@" "];
  
  for (NSString *rawString in arrayOfStrings) {
    NSArray *rawStringsArray = [rawString componentsSeparatedByCharactersInSet:separatorSet];
    for (NSString *singleString in rawStringsArray) {
      NSString *uppercaseSingleString = [singleString uppercaseString];
      [tempArray addObject:uppercaseSingleString];
    }
  }
  
//  NSLog(@"array count is %i", tempArray.count);
  return [NSArray arrayWithArray:tempArray];
}

@end
