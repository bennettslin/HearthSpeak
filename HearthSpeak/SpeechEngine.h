//
//  SpeechEngine.h
//  HearthSpeak
//
//  Created by Bennett Lin on 10/18/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol OpenEarsSpeechEngineDelegate;

@interface SpeechEngine : NSObject

@property (weak, nonatomic) id<OpenEarsSpeechEngineDelegate> delegate;

-(void)startLogging;
-(void)setupOpenEarsWithCardNames:(NSArray *)cardNames;
-(NSUInteger)closestIndexForString:(NSString *)hypothesisedString inArray:(NSArray *)cardNames;

@end

@protocol OpenEarsSpeechEngineDelegate <NSObject>

-(void)handleMicError;
-(void)movePickerToClosestCardForHypothesisedString:(NSString *)hypothesis;
-(void)startActivityIndicator;

@end