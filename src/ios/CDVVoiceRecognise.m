#import "CDVVoiceRecognise.h"

@interface CDVVoiceRecognise (PrivateMethods)

// Registriert die Listener für die (sleep/resume) Events
- (void) observeLifeCycle:(CDVInvokedUrlCommand *)command;
// Aktiviert den Hintergrundmodus
- (void) enableMode;
// Deaktiviert den Hintergrundmodus
- (void) disableMode;

@end
@implementation CDVVoiceRecognise

@synthesize audio_session_manager;
@synthesize pocket_sphinx_controller;
@synthesize VoiceRecognise_events_observer;
@synthesize language_model_generator;
@synthesize flite_controller;
@synthesize slt;
@synthesize started_listening;
@synthesize acoustic_model;
@synthesize current_language_model;
@synthesize current_dictionary;
@synthesize path_to_dynamic_language_model;
@synthesize path_to_dynamic_grammar;

// Lazy Allocations
-(AudioSessionManager *) audio_session_manager{
    if (audio_session_manager == nil){
        audio_session_manager = [[AudioSessionManager alloc] init];
    }
    return audio_session_manager;
}
-(PocketsphinxController *) pocket_sphinx_controller{
    if (pocket_sphinx_controller == nil){
        pocket_sphinx_controller = [[PocketsphinxController alloc] init];
    }
    return pocket_sphinx_controller;
}
-(OpenEarsEventsObserver *) VoiceRecognise_events_observer{
    if (VoiceRecognise_events_observer == nil){
        VoiceRecognise_events_observer = [[OpenEarsEventsObserver alloc] init];
    }
    return VoiceRecognise_events_observer;
}
-(LanguageModelGenerator *) language_model_generator{
    if (language_model_generator == nil){
        language_model_generator = [[LanguageModelGenerator alloc] init];
    }
    return language_model_generator;
}
-(FliteController *) flite_controller{
    if (flite_controller == nil){
        flite_controller = [[FliteController alloc] init];
    }
    return flite_controller;
}
- (Slt *)slt {
	if (slt == nil) {
		slt = [[Slt alloc] init];
	}
	return slt;
}



/*
 *  AudioSessionManager methods
	Start
		args: "AcousticModelEnglish" or "AcousticModelSpanish"
		returns status OK
 */
-(void)startAudioSession:(CDVInvokedUrlCommand*)command{
    // Default to "AcousticModelEnglish", will also accept "AcousticModelSpanish" or any others that may be added.
    NSString *acoustic_model_name;
    if(command.arguments && command.arguments.count){
        acoustic_model_name = [command.arguments objectAtIndex:0];
    }
    if(acoustic_model_name == nil){
        acoustic_model_name = @"AcousticModelEnglish";
    }
	
    [self.audio_session_manager startAudioSession];
    [self.VoiceRecognise_events_observer setDelegate:self];
    self.acoustic_model = [AcousticModel pathToModel:acoustic_model_name];
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}



/*
 *  LanguageModelGenerator methods	
	generateLanguageModel
		args: languageName, languageCSV
			languageName: a reference to the language set, eg: "HomeScreenController", "SettingsPage"
				  If using different language sets for different sections, you'll need to be able to switch between them.
			languageCSV: a dictionary of words to recognise, eg: "OPEN PAGE,GOTO STEP ONE" 

		returns Error, or dict with Language & Dictionary file details.

		In your host app, you shoudl keep track of these for switching between sets later, eg:

			var languages = {
				"languageName_1": {
					"LMFile": "languageName_1.DMP",
					"dictionaryFile": "languageName_1.dic",
					"lmPath": "/path/to/Library/Caches/languageName_1.DMP",
					"dictionaryPath": "/path/to/Library/Caches/languageName_1.dic"
				},
				"languageName_2": {
					"LMFile": "languageName_2.DMP",
					"dictionaryFile": "languageName_2.dic",
					"lmPath": "/path/to/Library/Caches/languageName_2.DMP",
					"dictionaryPath": "/path/to/Library/Caches/languageName_2.dic"
				}
			};
 */
-(void)generateLanguageModel:(CDVInvokedUrlCommand*)command{	
    NSString *languageName = [command.arguments objectAtIndex:0];	
    NSString *languageCSV = [command.arguments objectAtIndex:1];
    NSArray *languageArray = [languageCSV componentsSeparatedByString:@","];
    
    NSError *error = [self.language_model_generator generateLanguageModelFromArray:languageArray withFilesNamed:languageName forAcousticModelAtPath:self.acoustic_model];
    

    NSDictionary *dynamicLanguageGenerationResultsDictionary = nil;
    
    if([error code] != noErr) {
        NSString* errorMessage = [NSString stringWithFormat:@"Dynamic language generator reported error: %@", [error description]];
        NSLog(@"%@",errorMessage);
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
    } else {
		dynamicLanguageGenerationResultsDictionary = [error userInfo];
        
        NSString *lmFile = [dynamicLanguageGenerationResultsDictionary objectForKey:@"LMFile"];
		NSString *dictionaryFile = [dynamicLanguageGenerationResultsDictionary objectForKey:@"DictionaryFile"];
		NSString *lmPath = [dynamicLanguageGenerationResultsDictionary objectForKey:@"LMPath"];
		NSString *dictionaryPath = [dynamicLanguageGenerationResultsDictionary objectForKey:@"DictionaryPath"];
		
		NSLog(@"Dynamic language generator completed successfully, you can find your new files %@\n and \n%@\n at the paths \n%@ \nand \n%@", lmFile,dictionaryFile,lmPath,dictionaryPath);        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dynamicLanguageGenerationResultsDictionary];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
        self.path_to_dynamic_language_model = lmPath;
        self.path_to_dynamic_grammar = dictionaryPath;
        
        switch ([self.started_listening intValue]) {
                // Pocketsphinx is listening, switch to new language model
            case 1:
                NSLog(@"***Switching to new lm.");
                [self.pocket_sphinx_controller changeLanguageModelToFile:self.path_to_dynamic_language_model withDictionary:self.path_to_dynamic_grammar];
                break;
                // Otherwise, start listening with language model
            default:
                NSLog(@"***Starting with new lm.");                
                [self.pocket_sphinx_controller startListeningWithLanguageModelAtPath:self.path_to_dynamic_language_model dictionaryAtPath:self.path_to_dynamic_grammar acousticModelAtPath:self.acoustic_model languageModelIsJSGF:FALSE];
                break;
        }
    }
}

-(void)setMatchWord:(CDVInvokedUrlCommand*)command{
    NSString *languageName = [command.arguments objectAtIndex:0];
    strMatchWord = [command.arguments objectAtIndex:1];
    NSString *tempstrMatchWord =[command.arguments objectAtIndex:1];
    tempstrMatchWord=[NSString stringWithFormat:@"%@,null",tempstrMatchWord];
     NSArray *languageArray = [tempstrMatchWord componentsSeparatedByString:@","];
    //    NSError *error = [self.language_model_generator generateLanguageModelFromArray:languageArray withFilesNamed:languageName forAcousticModelAtPath:self.acoustic_model];
    //
    NSError *error = nil;
    if([error code] != noErr) {
        NSString* errorMessage = [NSString stringWithFormat:@"setMatchWord reported error: %@", [error description]];
        NSLog(@"%@",errorMessage);
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
    } else {

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:strMatchWord];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
   // NSArray *languageArray = [languageCSV componentsSeparatedByString:@","];
   
}

/*
 *  PocketsphinxController methods
	Start & Stop.
	In the simple case, you'd only generate one language, and auto-start listening with that.
	Then just need the argumentless stop & resume methods.
 */
-(void)resumeListening:(CDVInvokedUrlCommand*)command{
    [self.pocket_sphinx_controller startListeningWithLanguageModelAtPath:self.path_to_dynamic_language_model dictionaryAtPath:self.path_to_dynamic_grammar acousticModelAtPath:self.acoustic_model languageModelIsJSGF:FALSE];
}

-(void)stopListening:(CDVInvokedUrlCommand*)command{
    [self.pocket_sphinx_controller stopListening];
}

-(void)suspendRecognition:(CDVInvokedUrlCommand*)command{
    [self.pocket_sphinx_controller suspendRecognition];
}

-(void)resumeRecognition:(CDVInvokedUrlCommand*)command{
    [self.pocket_sphinx_controller resumeRecognition];
}


/*
	If using multiple langauge sets, you can start listening/switch to new model with the following two:
	In both cases, args: languagePath, dictionaryPath (as retrieved from your language generation)
*/
-(void)startListeningWithLanguageModelAtPath:(CDVInvokedUrlCommand*)command{
    self.current_language_model = [NSString stringWithFormat:@"%@/%@",[[NSBundle mainBundle] resourcePath], [command.arguments objectAtIndex:0]];
    self.current_dictionary = [NSString stringWithFormat:@"%@/%@",[[NSBundle mainBundle] resourcePath], [command.arguments objectAtIndex:1]];
    [self.pocket_sphinx_controller startListeningWithLanguageModelAtPath:self.current_language_model dictionaryAtPath:self.current_dictionary acousticModelAtPath:self.acoustic_model languageModelIsJSGF:FALSE];
}


-(void)changeLanguageModelToFile:(CDVInvokedUrlCommand*)command{
    self.current_language_model = [NSString stringWithFormat:@"%@/%@",[[NSBundle mainBundle] resourcePath], [command.arguments objectAtIndex:0]];
    self.current_dictionary = [NSString stringWithFormat:@"%@/%@",[[NSBundle mainBundle] resourcePath], [command.arguments objectAtIndex:1]];
    [self.pocket_sphinx_controller changeLanguageModelToFile:self.current_language_model withDictionary:self.current_dictionary];
}


/*
 *  FliteController methods
	Say a phrase.
		args: phrase (srting), sends it to the Tex-to-Speech module
 */
-(void)say:(CDVInvokedUrlCommand*)command{
    NSString *phrase = [command.arguments objectAtIndex:0];
    NSString *phrase_out = [[NSString alloc] initWithFormat:@"%@",phrase];
    NSLog(@"fliteControllerSay: %@",phrase_out);
    [self.flite_controller say:phrase_out withVoice:self.slt];
}



/*
 *  VoiceRecogniseEventsObserver delegate methods
 */
- (void) pocketsphinxDidStartListening {
    self.started_listening = [[NSNumber alloc] initWithInteger:1];
    
    NSLog(@"Pocketsphinx did start listening");
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.startedListening()"];
}

- (void) pocketsphinxDidStopListening {
    self.started_listening = [[NSNumber alloc] initWithInteger:0];
    NSLog(@"Pocketsphinx did stop listening");
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.stoppedListening()"];
}

- (void) pocketsphinxDidSuspendRecognition {
    NSLog(@"Pockesphinx did suspend recognition");
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.suspendedRecognition()"];
}

- (void) pocketsphinxDidResumeRecognition {
    NSLog(@"Pockesphinx did resume recognition");
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.resumedRecognition()"];
}

- (void) pocketsphinxDidDetectSpeech {
   
        NSLog(@"Pockesphinx did detect speech");
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.detectedSpeech()"];
}
- (void) pocketsphinxDidDetectFinishedSpeech {
  //  [self stopAudio];
 
    NSLog(@"Pocketsphinx did detect finished speech");
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.finishedDetectingSpeech()"];
}

- (void) pocketsphinxDidStartCalibration {
	NSLog(@"Pocketsphinx calibration has started.");
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.startedCalibration()"];

}

- (void) pocketsphinxDidCompleteCalibration {
	NSLog(@"Pocketsphinx calibration is complete.");
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.finishedCalibration()"];

}


- (void) pocketsphinxDidReceiveHypothesis:(NSString *)hypothesis recognitionScore:(NSString *)recognitionScore utteranceID:(NSString *)utteranceID {
    NSLog(@"Pocketsphinx received a hypothesis is %@ with a score of %@ and an ID of %@", hypothesis, recognitionScore, utteranceID);
    NSString* jsString = [[NSString alloc] initWithFormat:@"cordova.plugins.VoiceRecognise.events.receivedHypothesis(\"%@\",%@,%@);",hypothesis,recognitionScore,utteranceID];
    [self.commandDelegate evalJs:jsString];
}

- (void) pocketsphinxDidChangeLanguageModelToFile:(NSString *)newLanguageModelPathAsString andDictionary:(NSString *)newDictionaryPathAsString{
    NSLog(@"Pocketsphinx is now using the following language model: \n%@ and the following dictionary: %@",newLanguageModelPathAsString,newDictionaryPathAsString);
    NSString* jsString = [[NSString alloc] initWithFormat:@"cordova.plugins.VoiceRecognise.events.changedLanguageModelToFile(\"%@\",\"%@\")",newLanguageModelPathAsString,newDictionaryPathAsString];
    [self.commandDelegate evalJs:jsString];
}

- (void) pocketSphinxContinuousSetupDidFail {
 	NSLog(@"Setting up the continuous recognition loop has failed for some reason, please turn on VoiceRecogniseLogging to learn more.");
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.continuousSetupDidFaill()"];
}

- (void) testRecognitionCompleted {
	NSLog(@"A test file that was submitted for recognition is now complete.");
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.testRecognitionCompleted()"];
}


/*
 *  Flite Delegate Methods
 */
- (void) fliteDidStartSpeaking {
	NSLog(@"Flite has started speaking");
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.startedSpeaking()"];
}

- (void) fliteDidFinishSpeaking {
	NSLog(@"Flite has finished speaking");
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.finishedSpeaking()"];
}



/*
 *  Audio Delegate Methods
 */
- (void) audioSessionInterruptionDidBegin{
    NSLog(@"audio session interruption did begin");
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.audioSessionInterruptionDidBegin()"];
    
}
- (void) audioSessionInterruptionDidEnd{
    NSLog(@"audio session interruption did end");
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.audioSessionInterruptionDidEnd()"];
    
}
- (void) audioInputDidBecomeUnavailable{
    NSLog(@"audio did become unavailable");
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.audioInputDidBecomeUnavailable{()"];
}
- (void) audioInputDidBecomeAvailable{
    NSLog(@"audio input did become available");
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.audioInputDidBecomeAvailable()"];
}
- (void) audioRouteDidChangeToRoute:(NSString *)newRoute{
    NSLog(@"audio route did change to route: %@", newRoute);
    [self.commandDelegate evalJs:@"cordova.plugins.VoiceRecognise.events.audioRouteDidChangeToRoute()"];
}



/*
 *  Cleanup
 */
-(void) dealloc {
    VoiceRecognise_events_observer.delegate = nil;
}






/**
 * @js-interface
 *
 * Registriert die Listener für die (sleep/resume) Events.
 */
- (void) observeLifeCycle:(CDVInvokedUrlCommand *)command
{
    // Methode pluginInitialize wird aufgerufen, falls Instanz erstellt wurde
}

/**
 * @js-interface
 *
 * Aktiviert den Hintergrundmodus.
 */
- (void) enable:(CDVInvokedUrlCommand *)command
{
    [self enableMode];
}

/**
 * @js-interface
 *
 * Deaktiviert den Hintergrundmodus.
 */
- (void) disable:(CDVInvokedUrlCommand *)command
{
    [self disableMode];
}

/**
 * Aktiviert den Hintergrundmodus.
 */
- (void) enableMode
{
    _enabled = true;
}

/**
 * Deaktiviert den Hintergrundmodus.
 */
- (void) disableMode
{
    _enabled = false;
}

/**
 * Registriert die Listener für die (sleep/resume) Events und startet bzw. stoppt die Geo-Lokalisierung.
 */
- (void) pluginInitialize
{
   
    /*inBG=FALSE;
    [self enableMode];
    bgTask = [[BackgroundTask alloc] init];
    if (&UIApplicationDidEnterBackgroundNotification && &UIApplicationWillEnterForegroundNotification) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activateMode) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deactivateMode) name:UIApplicationWillEnterForegroundNotification object:nil];
    } else {
        [self activateMode];
    }*/
    
    
    
}

/*
- (void) activateMode
{
    inBG= TRUE;
    //  [self performSelector:@selector(callinbackground) withObject:nil afterDelay:.1];
    NSLog(@"active mode");
    
    //
    
    //    [self suspendRecognition];
    //
    //    [self stopListening];
    //
    [OpenEarsLogging startOpenEarsLogging];
    
    //    [self generateLanguageModel];
    //   // [self startAudioSession];
    //   [self resumeRecognition];
    //    [self resumeListening];
    
   // [bgTask startBackgroundTasks:7 target:self selector:@selector(backgroundCallback:)];
}

-(void) backgroundCallback:(id)info
{
    
    // NSLog(@"call in background :: %@",self.path_to_dynamic_language_model);
    NSLog(@"########");
    NSLog(@"###### BG TASK RUNNING %@",strMatchWord);
    
    
    //    [self generateLanguageModel];
    //
    //
    //    [self startAudioSession];
    //    [self resumeRecognition];
    //    [self resumeListening];
    //[self.flite_controller say:strMatchWord withVoice:self.slt];
}


- (void) deactivateMode
{
    inBG=FALSE;
    //    [bgtimer invalidate];
    //  [RecogniseBg stopBackgroundTask];
    [bgTask stopBackgroundTask];
    NSLog(@"deactive mode");
    
}
 */
-(void)PlayBackgroundFile:(CDVInvokedUrlCommand*)command{
    NSLog(@"Play Background file hhhhhhh");
    
    
    
    //    NSString *soundFilePath =
    //
    //    [[NSBundle mainBundle] pathForResource: @"sound"
    //
    //                                    ofType: @"wav"];
    //
    //
    //
    //    NSURL *fileURL = [[NSURL alloc] initFileURLWithPath: soundFilePath];
    //
    //
    //
    
    NSString *tempDir = NSTemporaryDirectory ();
    
    NSString *soundFilePath =
    
    [tempDir stringByAppendingString: @"sound.caf"];
    
    
    
    NSURL *newURL = [[NSURL alloc] initFileURLWithPath: soundFilePath];
    
    //    AVAudioPlayer *newPlayer =
    //
    //    [[AVAudioPlayer alloc] initWithContentsOfURL: newURL
    //
    //                                           error: nil];
    //
    //    [newPlayer prepareToPlay];
    //
    //    [newPlayer setDelegate: self];
    //
    //    [newPlayer play];
    
    NSError *error;
    avPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:newURL error:&error];
    
    if (!error)
    {
        [avPlayer prepareToPlay];
        [avPlayer play];
        
        NSLog(@"File is playing");
    }
    NSString *languageName = [command.arguments objectAtIndex:0];
    strMatchWord = [command.arguments objectAtIndex:1];
    
    // NSError *error = nil;
    
    
    if([error code] != noErr) {
        NSString* errorMessage = [NSString stringWithFormat:@"PlayBackgroundFile reported error: %@", [error description]];
        NSLog(@"%@",errorMessage);
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
    } else {
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Play"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void)StopBackgroundFile:(CDVInvokedUrlCommand*)command{
    NSLog(@"stop Background file hhhhhhh");
    
    
    [avPlayer stop];
    NSString *languageName = [command.arguments objectAtIndex:0];
    strMatchWord = [command.arguments objectAtIndex:1];
    
    NSError *error = nil;
    
    
    if([error code] != noErr) {
        NSString* errorMessage = [NSString stringWithFormat:@"PlayBackgroundFile reported error: %@", [error description]];
        NSLog(@"%@",errorMessage);
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
    } else {
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Play"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void)startRecord:(CDVInvokedUrlCommand*)command{
    [self RecordSpeech];
    
    NSError *error = nil;
    if([error code] != noErr) {
        NSString* errorMessage = [NSString stringWithFormat:@"start recording reported error: %@", [error description]];
        NSLog(@"%@",errorMessage);
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
    } else {
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:strMatchWord];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}
-(void)stopRecord:(CDVInvokedUrlCommand*)command{
    [self stopAudio];
    
    
    NSError *error = nil;
    if([error code] != noErr) {
        NSString* errorMessage = [NSString stringWithFormat:@"stop recording reported error: %@", [error description]];
        NSLog(@"%@",errorMessage);
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
    } else {
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:strMatchWord];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}
-(void)playRecord:(CDVInvokedUrlCommand*)command{
    [self playAudio];
    
    
    NSError *error = nil;
    if([error code] != noErr) {
        NSString* errorMessage = [NSString stringWithFormat:@"play recording reported error: %@", [error description]];
        NSLog(@"%@",errorMessage);
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
    } else {
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:strMatchWord];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}
-(void) RecordSpeech
{
    
    
    NSLog(@"start record");
}
-(void) stopAudio
{
   
}
-(void) playAudio
{
  
        
   
}

@end
