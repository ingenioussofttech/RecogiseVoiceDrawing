

#import <Cordova/CDV.h>

#import <OpenEars/AudioSessionManager.h>
#import <OpenEars/PocketsphinxController.h>
#import <OpenEars/OpenEarsEventsObserver.h>
#import <OpenEars/FliteController.h>
#import <OpenEars/LanguageModelGenerator.h>
#import <OpenEars/OpenEarsLogging.h>
#import <OpenEars/AcousticModel.h>
#import <AVFoundation/AVFoundation.h>
#import <Slt/Slt.h>

////#import "BackgroundTask.h"

@interface CDVVoiceRecognise : CDVPlugin<OpenEarsEventsObserverDelegate> {
	AudioSessionManager *audio_session_manager;
	PocketsphinxController *pocket_sphinx_controller;
	OpenEarsEventsObserver *VoiceRecognise_events_observer;
	FliteController *flite_controller;
    Slt *slt;
	LanguageModelGenerator *language_model_generator;
    
	NSNumber *started_listening; // 1, 0 (yes, no)
    NSString *acoustic_model;
	NSString *current_language_model;
	NSString *current_dictionary;
	NSString *path_to_dynamic_language_model;
	NSString *path_to_dynamic_grammar;
    NSString *strMatchWord;
    
    ////BackgroundTask * bgTask;
    
      AVAudioPlayer * avPlayer;

    BOOL _enabled;
    BOOL inBG;
    NSTimer* bgtimer;
    
    __block AVAudioPlayer *player;
  
    AVAudioRecorder *soundRecorder;
    NSInteger timerInterval;
    NSURL *soundFileURL;
}


@property (nonatomic, strong) AudioSessionManager *audio_session_manager;
@property (nonatomic, strong) PocketsphinxController *pocket_sphinx_controller;
@property (nonatomic, strong) OpenEarsEventsObserver *VoiceRecognise_events_observer;
@property (nonatomic, strong) LanguageModelGenerator *language_model_generator;
@property (nonatomic, strong) FliteController *flite_controller;
@property (nonatomic, strong) Slt *slt;

@property (nonatomic, strong) NSNumber *started_listening;
@property (nonatomic, strong) NSString *acoustic_model;
@property (nonatomic, strong) NSString *current_language_model;
@property (nonatomic, strong) NSString *current_dictionary;
@property (nonatomic, strong) NSString *path_to_dynamic_language_model;
@property (nonatomic, strong) NSString *path_to_dynamic_grammar;


- (void)startAudioSession:(CDVInvokedUrlCommand*)command;

// Language Model Generator
- (void)generateLanguageModel:(CDVInvokedUrlCommand*)command;


// Set MAtch Word
- (void)setMatchWord:(CDVInvokedUrlCommand*)command;

// PocketSphinx Controller
- (void)stopListening:(CDVInvokedUrlCommand*)command;
- (void)resumeListening:(CDVInvokedUrlCommand*)command;
- (void)suspendRecognition:(CDVInvokedUrlCommand*)command;
- (void)resumeRecognition:(CDVInvokedUrlCommand*)command;
- (void)startListeningWithLanguageModelAtPath:(CDVInvokedUrlCommand*)command;
- (void)changeLanguageModelToFile:(CDVInvokedUrlCommand*)command;

// Flite
- (void)say:(CDVInvokedUrlCommand*)command;


// Aktiviert den Hintergrundmodus
- (void) enable:(CDVInvokedUrlCommand *)command;
// Deaktiviert den Hintergrundmodus
- (void) disable:(CDVInvokedUrlCommand *)command;
-(void) callinbackground;

-(void)PlayBackgroundFile:(CDVInvokedUrlCommand*)command;
-(void)startRecord:(CDVInvokedUrlCommand*)command;
-(void)stopRecord:(CDVInvokedUrlCommand*)command;
-(void)playRecord:(CDVInvokedUrlCommand*)command;
@end
