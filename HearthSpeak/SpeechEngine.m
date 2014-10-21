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
  
  NSMutableArray *uppercaseWords = [self returnStrippedUppercaseArray:cardNames];
  [uppercaseWords addObject:@"MANNA"];
  [uppercaseWords addObject:@"SUNFYURY"]; // GOOD
  [uppercaseWords removeObject:@"SUNFURY"];
  [uppercaseWords addObject:@"WINDFYURY"]; // GOOD
  [uppercaseWords removeObject:@"WINDFURY"];
  [uppercaseWords addObject:@"FURRINAI"]; // OKAY, DONE
  [uppercaseWords addObject:@"FANNIFFNAIVS"]; // OKAY, DONE
  [uppercaseWords addObject:@"SENAREEYUS"]; // DONE
  [uppercaseWords removeObject:@"CENARIUS"];
  [uppercaseWords addObject:@"FYOOGGEN"]; // DONE
  [uppercaseWords removeObject:@"FEUGEN"];
  [uppercaseWords addObject:@"FLAYMAVASINOTH"]; // DONE
  [uppercaseWords removeObject:@"AZZINOTH"];
  [uppercaseWords addObject:@"FLAYMTUNG"]; // DONE
  [uppercaseWords removeObject:@"FLAMETONGUE"];
  [uppercaseWords addObject:@"RAYNUFF"]; // DONE
  [uppercaseWords addObject:@"RAYZERFEN"]; // DONE
  [uppercaseWords removeObject:@"RAZORFEN"];
  [uppercaseWords addObject:@"THIHKOYN"]; // OKAY, DONE
  [uppercaseWords addObject:@"THRALLMARFARSEER"]; // DONE
  [uppercaseWords removeObject:@"THRALLMAR"];
  [uppercaseWords addObject:@"TREEYENT"]; // DONE
  [uppercaseWords removeObject:@"TREANT"];
  [uppercaseWords addObject:@"CALLER"]; // DONE
  
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

  /*
   problems: Al'Akir the Windlord, Aldor Peacekeeper, Arathi Weaponsmith, Archmage, Archmage Antonidas, Avatar of the Coin, Baine Bloodhoof, Bane of Doom, Bear Form, Bestial Wrath, Blade Flurry, Blood Imp, Blood Knight, Booty Bay Bodyguard, Cabal Shadow Priest, Cenarius, Cone of Cold, Cult Master, Dalaran Mage, Deathlord, Defender of Argus, Demonfire, Dream, Emperor Cobra, Eye for an Eye, Fan of Knives, Feugen, Fireblast, Flame of Azzinoth, Flametongue Totem, Forked Lightning, Gruul, Hammer of Wrath, Hand of Protection, Imp Master, Kobold Geomancer, Lay on Hands, Leeroy Jenkins, Lord Jaraxxus, Lord of the Arena, Mad Scientist, anything with Mana, Mana Wraith, Mana Wyrm, Mark of the Horsemen, Mark of the Wild, Mortal Coil, Nerubian Egg, NOOO, Old Murkeye, Pint-Sized Summoner, Power of the Wild, Rain of Fire, Razorfen Hunter, Shade of Naxxramas, Shadow of Nothing, Shadow Word Death and Pain, SI7 Agent, Snipe, Stormpike Commando, Succubus, Sunfury Protector, Sword of Justice, The Black Knight, The Coin, Thrallmar Farseer, Treant, Voidcaller, anything with Windfury, Wrath of Air Totem
   */
  
    // ark mage or archer mage
    // blood
    // cenarius
    // eye for an eye
    // fan of knives
    // feugen
    // flame of azzinoth
    // flametongue totem
    // MANA
    // WORM
    // NO
    // RAINOF FIRE
    // RAZORFEN
    // SUNFURRY
    // THECOIN
    // THRALLMAR
    // TREANT
    // VOID CALLER
    // WINDFURRY
  
  NSArray *hypothesisedWordsArray = [hypothesisedString componentsSeparatedByString:@" "];
  
  if ([hypothesisedWordsArray containsObject:@"MANNA"] ||
      [hypothesisedWordsArray containsObject:@"SUNFYURY"] ||
      [hypothesisedWordsArray containsObject:@"WINDFYURY"]) {
    
    NSMutableArray *tempArray = [NSMutableArray new];
    
    for (int i = 0; i < hypothesisedWordsArray.count; i++) {
      if ([hypothesisedWordsArray[i] isEqualToString:@"MANNA"]) {
        [tempArray addObject:@"MANA"];
      } else if ([hypothesisedWordsArray[i] isEqualToString:@"SUNFYURY"]) {
        [tempArray addObject:@"SUNFURY"];
      } else if ([hypothesisedWordsArray[i] isEqualToString:@"WINDFYURY"]) {
        [tempArray addObject:@"WINDFURY"];
      } else {
        [tempArray addObject:hypothesisedWordsArray[i]];
      }
    }
    
    hypothesisedWordsArray = [NSArray arrayWithArray:tempArray];
  }
  
  NSLog(@"hypothesisedWordsArray is now %@", hypothesisedWordsArray);
  
  NSString *firstWord;
  NSString *secondWord;
  NSString *thirdWord;
  NSString *lastWord;
  
  if (hypothesisedWordsArray.count > 0) {
    firstWord = hypothesisedWordsArray[0];
    lastWord = [hypothesisedWordsArray lastObject];
  }
  
  if (hypothesisedWordsArray.count > 1) {
    secondWord = hypothesisedWordsArray[1];
  }

  if (hypothesisedWordsArray.count > 2) {
    thirdWord = hypothesisedWordsArray[2];
  }
  
  if ([hypothesisedWordsArray containsObject:@"WINDLORD"]) {
    hypothesisedWordsArray = @[@"ALAKIR", @"THE", @"WINDLORD"];
  } else if ([hypothesisedWordsArray containsObject:@"PEACEKEEPER"]) {
    hypothesisedWordsArray = @[@"ALDOR", @"PEACEKEEPER"];
  } else if ([firstWord isEqualToString:@"BANE"] && [secondWord isEqualToString:@"BLOODHOOF"]) {
    hypothesisedWordsArray = @[@"BAINE", @"BLOODHOOF"];
  } else if ([secondWord isEqualToString:@"DOOM"] || [thirdWord isEqualToString:@"DOOM"]) {
    hypothesisedWordsArray = @[@"BANE", @"OF", @"DOOM"];
  } else if (([firstWord isEqualToString:@"KOBOLD"] || [secondWord isEqualToString:@"SHADOW"]) && [thirdWord isEqualToString:@"PRIEST"]) {
    hypothesisedWordsArray = @[@"CABAL", @"SHADOW", @"PRIEST"];
  } else if ([firstWord isEqualToString:@"KODO"] && [secondWord isEqualToString:@"COLD"]) {
    hypothesisedWordsArray = @[@"CONE", @"OF", @"COLD"];
  } else if ([firstWord isEqualToString:@"COLD"] && [secondWord isEqualToString:@"MASTER"]) {
    hypothesisedWordsArray = @[@"CULT", @"MASTER"];
  } else if (([firstWord isEqualToString:@"DEATH"] || [firstWord isEqualToString:@"DEATHS"]) && [secondWord isEqualToString:@"LORD"]) {
    hypothesisedWordsArray = @[@"DEATHLORD"];
  } else if ([hypothesisedWordsArray containsObject:@"ARGUS"]) {
    hypothesisedWordsArray = @[@"DEFENDER", @"OF", @"ARGUS"];
  } else if ([firstWord isEqualToString:@"DEMONS"] && [secondWord isEqualToString:@"FIRE"]) {
    hypothesisedWordsArray = @[@"DEMONFIRE"];
  } else if (hypothesisedWordsArray.count == 1 && [firstWord isEqualToString:@"DRAIN"]) {
    hypothesisedWordsArray = @[@"DREAM"];
  } else if ([secondWord isEqualToString:@"LIGHTNING"]) {
    hypothesisedWordsArray = @[@"FORKED", @"LIGHTNING"];
  } else if (hypothesisedWordsArray.count == 1 && [firstWord isEqualToString:@"CRUEL"]) {
    hypothesisedWordsArray = @[@"GRUUL"];
  } else if ([hypothesisedWordsArray containsObject:@"PROTECTION"]) {
    hypothesisedWordsArray = @[@"HAND", @"OF", @"PROTECTION"];
  } else if (hypothesisedWordsArray.count == 1 && [firstWord isEqualToString:@"TINKMASTER"]) {
    hypothesisedWordsArray = @[@"IMP", @"MASTER"];
  } else if ([hypothesisedWordsArray containsObject:@"GEOMANCER"]) {
    hypothesisedWordsArray = @[@"KOBOLD", @"GEOMANCER"];
  } else if ([hypothesisedWordsArray containsObject:@"HANDS"]) {
    hypothesisedWordsArray = @[@"LAY", @"ON", @"HANDS"];
  } else if ([lastWord isEqualToString:@"ARENA"]) {
    hypothesisedWordsArray = @[@"LORD", @"OF", @"THE", @"ARENA"];
  } else if ([secondWord isEqualToString:@"SCIENTIST"]) {
    hypothesisedWordsArray = @[@"MAD", @"SCIENTIST"];
  } else if ([firstWord isEqualToString:@"MANA"] && [secondWord isEqualToString:@"RAISE"]) {
    hypothesisedWordsArray = @[@"MANA", @"WRAITH"];
  } else if ([firstWord isEqualToString:@"MANA"] && [secondWord isEqualToString:@"LORE"]) {
    hypothesisedWordsArray = @[@"MANA", @"WYRM"];
  } else if ([hypothesisedWordsArray containsObject:@"HORSEMEN"]) {
    hypothesisedWordsArray = @[@"MARK", @"OF", @"THE", @"HORSEMEN"];
  } else if ([firstWord isEqualToString:@"NERUBIAN"] && hypothesisedWordsArray.count == 2) {
    hypothesisedWordsArray = @[@"NERUBIAN", @"EGG"];
  } else if ([secondWord isEqualToString:@"MURKEYE"]) {
    hypothesisedWordsArray = @[@"OLD", @"MURKEYE"];
  } else if ([secondWord isEqualToString:@"SUMMONER"] && ![firstWord isEqualToString:@"DARK"]) {
    hypothesisedWordsArray = @[@"PINTSIZED", @"SUMMONER"];
  } else if ([firstWord isEqualToString:@"POWER"] && [lastWord isEqualToString:@"WILD"]) {
    hypothesisedWordsArray = @[@"POWER", @"OF", @"THE", @"WILD"];
  } else if ([secondWord isEqualToString:@"NAXXRAMAS"] || [thirdWord isEqualToString:@"NAXXRAMAS"]) {
    hypothesisedWordsArray = @[@"SHADE", @"OF", @"NAXXRAMAS"];
  } else if ([hypothesisedWordsArray containsObject:@"NOTHING"]) {
    hypothesisedWordsArray = @[@"SHADOW", @"OF", @"NOTHING"];
  } else if ([firstWord isEqualToString:@"SHADOW"] && [lastWord isEqualToString:@"DEATH"]) {
    hypothesisedWordsArray = @[@"SHADOW", @"WORD", @"DEATH"];
  } else if ([firstWord isEqualToString:@"SHADOW"] && (([secondWord isEqualToString:@"WORD"] && ![lastWord isEqualToString:@"DEATH"])|| [lastWord isEqualToString:@"PAIN"])) {
    hypothesisedWordsArray = @[@"SHADOW", @"WORD", @"PAIN"];
  } else if ([lastWord isEqualToString:@"AGENT"]) {
    hypothesisedWordsArray = @[@"SI7", @"AGENT"];
  } else if ([firstWord isEqualToString:@"SUN"] && [secondWord isEqualToString:@"FURY"] && [thirdWord isEqualToString:@"PROTECTOR"]) {
    hypothesisedWordsArray = @[@"SUNFURY", @"PROTECTOR"];
  } else if ([secondWord isEqualToString:@"JUSTICE"] && ![firstWord isEqualToString:@"LIGHTS"]) {
    hypothesisedWordsArray = @[@"SWORD", @"OF", @"JUSTICE"];
  } else if ([hypothesisedWordsArray containsObject:@"BLACK"] && [hypothesisedWordsArray containsObject:@"KNIGHT"]) {
    hypothesisedWordsArray = @[@"THE", @"BLACK", @"KNIGHT"];
  } else if ([firstWord isEqualToString:@"WRATH"] && [lastWord isEqualToString:@"TOTEM"]) {
    hypothesisedWordsArray = @[@"WRATH", @"OF", @"AIR", @"TOTEM"];
  } else if ([firstWord isEqualToString:@"SENAREEYUS"]) {
    hypothesisedWordsArray = @[@"CENARIUS"];
  } else if ([firstWord isEqualToString:@"FYOOGGEN"]) {
    hypothesisedWordsArray = @[@"FEUGEN"];
  } else if ([firstWord isEqualToString:@"FLAYMAVASINOTH"]) {
    hypothesisedWordsArray = @[@"FLAME", @"OF", @"AZZINOTH"];
  } else if ([firstWord isEqualToString:@"RAYZERFEN"]) {
    hypothesisedWordsArray = @[@"RAZORFEN"];
  } else if ([firstWord isEqualToString:@"TREEYENT"]) {
    hypothesisedWordsArray = @[@"TREANT"];
  } else if ([firstWord isEqualToString:@"THRALLMARFARSEER"]) {
    hypothesisedWordsArray = @[@"THRALLMAR", @"FARSEER"];
  } else if ([firstWord isEqualToString:@"FLAYMTUNG"]) {
    hypothesisedWordsArray = @[@"FLAMETONGUE", @"TOTEM"];
  } else if ([firstWord isEqualToString:@"RAYNUFF"]) {
    hypothesisedWordsArray = @[@"RAIN", @"OF", @"FIRE"];
  } else if ([hypothesisedWordsArray containsObject:@"FURRINAI"]) {
    hypothesisedWordsArray = @[@"EYE", @"FOR", @"AN", @"EYE"];
  } else if ([hypothesisedWordsArray containsObject:@"FANNIFFNAIVS"]) {
    hypothesisedWordsArray = @[@"FAN", @"OF", @"KNIVES"];
  } else if ([hypothesisedWordsArray containsObject:@"CALLER"]) {
    hypothesisedWordsArray = @[@"VOIDCALLER"];
  } else if ([hypothesisedWordsArray containsObject:@"THIHKOYN"] || ([hypothesisedWordsArray containsObject:@"COIN"] && ![firstWord isEqualToString:@"AVATAR"]) || (hypothesisedWordsArray.count == 1 && [firstWord isEqualToString:@"UNHOLY"])) {
    hypothesisedWordsArray = @[@"THE", @"COIN"];
  }
  
  NSLog(@"and now hypothesisedWordsArray is now %@", hypothesisedWordsArray);
  
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

-(NSMutableArray *)returnStrippedUppercaseArray:(NSArray *)arrayOfStrings {
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
  return tempArray;
}

@end
