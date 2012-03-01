//
//  RawEngine.m
//  AlephOne
//
//  Created by Robert Fielding on 2/2/12.
//  Copyright (c) 2012 Check Point Software. All rights reserved.
//
// Only using ObjC internally to use internal classes...trying not to leak this requirement everywhere.

#import <Foundation/Foundation.h>
#import <AudioUnit/AUComponent.h>
#import <AudioUnit/AudioUnitProperties.h>
#import <AudioUnit/AudioOutputUnit.h>
#import <AudioToolbox/AudioServices.h>
#import <AVFoundation/AVFoundation.h>


#import "RawEngine.h"
#include "FretlessCommon.h"

AudioComponentInstance audioUnit;
AudioStreamBasicDescription audioFormat;
static const float kSampleRate = 44100.0;
static const unsigned int kOutputBus = 0;

#define WAVEMAX (1024*2)
#define UNISONMAX 2

struct ramp {
    float stopValue;
    float slope;
    float value;
};

struct fingerData {
    struct ramp pitchRamp;
    struct ramp volRamp;
    struct ramp exprRamp;
    float phases[UNISONMAX];
};

#define NTSTATE_NO 0
#define NTSTATE_NEED_OFF 1
#define NTSTATE_FINISH_ON 2

struct fingersData {
    struct fingerData finger[FINGERMAX];
    float  totalL[UNISONMAX][WAVEMAX];
    float  totalR[UNISONMAX][WAVEMAX];
    long  sampleCount;
    int   noteTieState;
    int   otherChannel;
};


float totalNoteVolume=0;


#define HARMONICSMAX 32
float waveMix[2][2][WAVEMAX];
float waveFundamental[WAVEMAX];
float harmonicsTotal[2][2];
float harmonics[2][2][128] =
{
    {
        {16, 8, 4, 2, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        },  
        {0, 0, 0, 0, 0, 0, 0,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        }
    },
    {
        {8, 4, 1, 2, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,            
        },  
        {0, 0, 0, 0, 0, 0, 0,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        }
    },
};


static struct fingersData allFingers;

static void copyRamp(struct ramp* dst, struct ramp* src)
{
    dst->stopValue = src->stopValue;
    dst->slope = src->stopValue;
    dst->value = src->value;
}

static void moveRamps(int dstFinger, int srcFinger)
{
    if(srcFinger != dstFinger)
    {
        copyRamp(&allFingers.finger[dstFinger].volRamp, &allFingers.finger[srcFinger].volRamp);
        copyRamp(&allFingers.finger[dstFinger].pitchRamp, &allFingers.finger[srcFinger].pitchRamp);
        copyRamp(&allFingers.finger[dstFinger].exprRamp, &allFingers.finger[srcFinger].exprRamp);
        for(int i=0; i<UNISONMAX; i++)
        {
            allFingers.finger[dstFinger].phases[i] = allFingers.finger[srcFinger].phases[i];
        }
        allFingers.finger[srcFinger].volRamp.value = 0;
        allFingers.finger[srcFinger].volRamp.stopValue = 0;        
    }
}


static inline void setRamp(struct ramp* r, float slope, float stopValue)
{
    r->stopValue = stopValue;
    r->slope = slope;
}

static inline void doRamp(struct ramp* r,long sample)
{
    r->value = r->value * (1-r->slope) + r->slope * r->stopValue;
}



/**
   Create four waves:
 
   Their harmonics:
 
     harmonics[0][0] = A ; arbitrary harmonics
     harmonics[0][1] = B ; arbitrary harmonics
 
     harmonics[1][0] = A x Sq ; A convoluted with early odd harmonics
     harmonics[1][1] = B x Sq ; B convoluted with early odd harmonics
 
   And convoluted into waveMix, where the intent is to
   use weighted sums of the 4 possible waves.
 */
static void setExprMix()
{
    //Compute the squared off versions of our waves (not yet normalized)
    for(int expr=0; expr<2; expr++)
    {
        for(int harmonic=0; harmonic<HARMONICSMAX; harmonic++)
        {
            harmonics[1][expr][harmonic] = 0;                        
        }
        //Convolute non distorted harmonics with square wave harmonics
        for(int harmonic=0; harmonic<HARMONICSMAX; harmonic++)
        {            
            for(int squareHarmonic=0; squareHarmonic<HARMONICSMAX; squareHarmonic++)
            {
                int s = squareHarmonic*2+1;
                if(s<HARMONICSMAX)
                {
                    harmonics[1][expr][s] += harmonics[0][expr][harmonic] / s;                                                                    
                }
            }
        }
    }
    
    
    //Normalize the harmonics
    for(int dist=0; dist<2; dist++)
    {
        for(int expr=0; expr<2; expr++)
        {
            harmonicsTotal[dist][expr] = 0;
            for(int harmonic=0; harmonic<HARMONICSMAX; harmonic++)
            {
                harmonicsTotal[dist][expr] += harmonics[dist][expr][harmonic];                
            }
            for(int harmonic=0; harmonic<HARMONICSMAX; harmonic++)
            {
                harmonics[dist][expr][harmonic] /= harmonicsTotal[dist][expr];                
            }
        }
    }  
    
    //Convolute into the wave buffers
    for(int dist=0; dist<2; dist++)
    {
        for(int expr=0; expr<2; expr++)
        {
            for(int sample=0; sample<WAVEMAX; sample++)
            {
                waveMix[dist][expr][sample] = 0;                
                waveFundamental[sample] = sinf( sample * 2.0 * M_PI / WAVEMAX );
            }
            for(int harmonic=0; harmonic<HARMONICSMAX; harmonic++)
            {
                float h = harmonic+1;
                float v = harmonics[dist][expr][harmonic];
                for(int sample=0; sample<WAVEMAX; sample++)
                {
                    waveMix[dist][expr][sample] += sinf(h * sample * 2.0 * M_PI / WAVEMAX) * v;
                }
            }
        }
    }
}


static void audioSessionInterruptionCallback(void *inUserData, UInt32 interruptionState) {
    if (interruptionState == kAudioSessionEndInterruption) {
        AudioSessionSetActive(YES);
        AudioOutputUnitStart(audioUnit);
    }
    
    if (interruptionState == kAudioSessionBeginInterruption) {
        AudioOutputUnitStop(audioUnit);
    }
}

static void initNoise()
{
    setExprMix();
}

//This loop changes no state other than accumulating values - independent for each i
static inline void renderNoiseInnerLoopSample(int f,int phaseIdx,int i,float cyclesPerSample,float pitchLocation,float p,unsigned long samples,float currentVolume,float targetVolume, float currentExpr, float targetExpr)
{
    float e = 
        currentExpr + 
        ((1.0*i)/samples) * (targetExpr - currentExpr);
    float v = 
        currentVolume + 
        ((1.0*i)/samples) * (targetVolume - currentVolume);
    
    float cycles = i*cyclesPerSample + p;
    float cycleLocation = (cycles - (int)cycles); // 0 .. 1
    int j = (int)(cycleLocation*WAVEMAX);
    float s2 = (1-e*e);
    float unSquished = (waveMix[1][0][j]*(1-s2) + waveMix[0][0][j]*(s2))*e + (waveMix[1][1][j]*(1-s2) + waveMix[0][1][j]*(s2))*(1-e);
    float unAliased = unSquished*(1-pitchLocation) + waveFundamental[j]*(pitchLocation);
    allFingers.totalL[phaseIdx][i] += v * unAliased;
    allFingers.totalR[phaseIdx][i] += v * unAliased;    
}

static inline void renderNoiseInnerLoop(int f,int phaseIdx,float detune,unsigned long samples,
                                            float currentVolume,float targetVolume, float currentExpr, float targetExpr)
{
    float notep = allFingers.finger[f].pitchRamp.value;
    float pitchLocation = notep/127.0;
    float p = allFingers.finger[f].phases[phaseIdx];
    //note 33 is our center pitch, and it's 440hz
    float cyclesPerSample = powf(2,(notep-33+detune*(1-pitchLocation))/12) * (440/(44100.0 * 32));
    for(int i=0; i<samples; i++)
    {
        renderNoiseInnerLoopSample(f,phaseIdx,i,cyclesPerSample,pitchLocation,p,samples,currentVolume,targetVolume,currentExpr,targetExpr);
    }         
    allFingers.finger[f].phases[phaseIdx] = (cyclesPerSample*samples) + p;
}

static inline void renderNoisePrepare(int f)
{
    if(allFingers.finger[f].volRamp.value == 0)
    {
        for(int i=0; i<UNISONMAX; i++)
        {
            allFingers.finger[f].phases[i] = 0;
        }
        allFingers.finger[f].pitchRamp.value = allFingers.finger[f].pitchRamp.stopValue;
        allFingers.finger[f].exprRamp.value = allFingers.finger[f].exprRamp.stopValue;
    }
    doRamp(&allFingers.finger[f].pitchRamp,allFingers.sampleCount);    
}

static inline void renderNoiseCleanAll(long* dataL, long* dataR,unsigned long samples)
{
    for(int phaseIdx=0; phaseIdx<UNISONMAX; phaseIdx++)
    {
        for(int i=0; i<samples; i++)
        {
            allFingers.totalL[phaseIdx][i] *= 0.1;
            allFingers.totalR[phaseIdx][i] *= 0.1;            
        }
    }    
    for(int i=0; i<samples; i++)
    {
        dataL[i] = 0;
        dataR[i] = 0;
    }
}

static inline void renderNoiseToBuffer(long* dataL,long* dataR,unsigned long samples)
{
    for(int phaseIdx=0; phaseIdx<UNISONMAX; phaseIdx++)
    {
        for(int i=0; i<samples; i++)
        {
            dataL[i] += INT_MAX * 0.06 * 0.0125 * atanf(allFingers.totalL[phaseIdx][i] * M_PI);
            dataR[i] += INT_MAX * 0.06 * 0.0125 * atanf(allFingers.totalR[phaseIdx][i] * M_PI);
        }
    }            
}

static void renderNoise(long* dataL, long* dataR, unsigned long samples)
{
    renderNoiseCleanAll(dataL,dataR,samples);
    int activeFingers=0;
    //Go in channel major order because we skip by volume
    for(int f=0; f<FINGERMAX; f++)
    {
        float currentVolume = allFingers.finger[f].volRamp.value;
        float targetVolume = allFingers.finger[f].volRamp.stopValue;
        float currentExpr = allFingers.finger[f].exprRamp.value;
        float targetExpr = allFingers.finger[f].exprRamp.stopValue;
        int isActive = (currentVolume > 0) || (targetVolume > 0);
        
        if(isActive)
        {
            activeFingers++;
            renderNoisePrepare(f);
            renderNoiseInnerLoop(f,0,0,samples, currentVolume,targetVolume,currentExpr,targetExpr);
            renderNoiseInnerLoop(f,1, 0.1,samples, currentVolume,targetVolume,currentExpr,targetExpr);
            //renderNoiseInnerLoop(f,2,-0.1,samples, currentVolume,targetVolume,currentExpr,targetExpr);
            allFingers.finger[f].volRamp.value = targetVolume;
            allFingers.finger[f].exprRamp.value = targetExpr;
        }
    }
    renderNoiseToBuffer(dataL,dataR,samples);
    allFingers.sampleCount += samples;
}

void rawEngine(int midiChannel,int doNoteAttack,float pitch,float volVal,int midiExprParm,int midiExpr)
{
    //printf("%d %d %f %f %d %d\n",midiChannel, doNoteAttack, pitch, volVal, midiExprParm, midiExpr);
    int channel = midiChannel;
    //Handle the note-tie state machine.  We expect the note-off to come before note-on in the note-tie,
    //which could be the opposite decision of other implementers.
    int doVol = 1;
    if(doNoteAttack)
    {
        //We got signalled to expect a note tie next time!
        allFingers.noteTieState = NTSTATE_NEED_OFF;
    }
    else
    {
        if(allFingers.noteTieState == NTSTATE_NEED_OFF)
        {
            if(volVal == 0)
            {
                allFingers.noteTieState = NTSTATE_FINISH_ON;
                allFingers.otherChannel = channel;
                doVol = 0;
            }
        }
        else
        {
            if(allFingers.noteTieState == NTSTATE_FINISH_ON)
            {
                if(volVal > 0)
                {
                    allFingers.noteTieState = NTSTATE_NO;
                    moveRamps(channel,allFingers.otherChannel);
                }
            }
        }
        if(doVol) //If we are in legato, then this might need to be stopped
        {
            setRamp(&allFingers.finger[channel].volRamp, 0.008 * pitch/127.0 * ((volVal==0)?0.25:1), volVal);            
        }
        if(volVal!=0) //Don't bother with ramping these on release
        {
            setRamp(&allFingers.finger[channel].pitchRamp, 0.9, pitch);
            setRamp(&allFingers.finger[channel].exprRamp, 0.1, midiExpr/127.0);                                            
        }
    }
}

static OSStatus fixGDLatency()
{
    float latency = 0.005;
    
    OSStatus
    status = AudioSessionSetProperty(
                                     kAudioSessionProperty_PreferredHardwareIOBufferDuration,
                                     sizeof(latency),&latency
                                     );
    if(status != 0)
    {
    }
    UInt32 allowMixing = true;
    status = AudioSessionSetProperty(
                                     kAudioSessionProperty_OverrideCategoryMixWithOthers,
                                     sizeof(allowMixing),&allowMixing
                                     );
    
    AudioStreamBasicDescription auFmt;
    UInt32 auFmtSize = sizeof(AudioStreamBasicDescription);
    
    AudioUnitGetProperty(audioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         kOutputBus,
                         &auFmt,
                         &auFmtSize);
    return status;
}



void SoundEngine_wake()
{
    NSError *categoryError = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&categoryError];
    fixGDLatency();
    initNoise();
}


static OSStatus SoundEngine_playCallback(void *inRefCon,
                                         AudioUnitRenderActionFlags *ioActionFlags,
                                         const AudioTimeStamp *inTimeStamp,
                                         UInt32 inBusNumber,
                                         UInt32 inNumberFrames,
                                         AudioBufferList *ioData)
{
    assert(inBusNumber == kOutputBus);
    
    AudioBuffer* outputBufferL = &ioData->mBuffers[0];
    SInt32* dataL = (SInt32*)outputBufferL->mData;
    AudioBuffer* outputBufferR = &ioData->mBuffers[1];
    SInt32* dataR = (SInt32*)outputBufferR->mData;
    
    renderNoise(dataL,dataR,inNumberFrames);
    return 0;
}

void SoundEngine_start()
{
    // Initialize the audio session.
    AudioSessionInitialize(NULL, NULL, audioSessionInterruptionCallback, NULL);
        
    OSStatus status;
    // Describe audio component
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    // Get component
    AudioComponent outputComponent = AudioComponentFindNext(NULL, &desc);
    
    // Get audio units
    status = AudioComponentInstanceNew(outputComponent, &audioUnit);
    if(status)
    {
        NSLog(@"AudioComponentInstanceNew failed: %ld",status);
    }
    else
    {
        // Enable playback
        UInt32 enableIO = 1;
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      kOutputBus,
                                      &enableIO,
                                      sizeof(UInt32));
        if(status)
        {
            NSLog(@"AudioUnitSetProperty enable io failed: %ld",status);
        }
        else
        {
            audioFormat.mSampleRate = 44100.0;
            audioFormat.mFormatID = kAudioFormatLinearPCM;
            audioFormat.mFormatFlags = kAudioFormatFlagsAudioUnitCanonical;
            audioFormat.mBytesPerPacket = sizeof(AudioUnitSampleType);
            audioFormat.mFramesPerPacket = 1;
            audioFormat.mBytesPerFrame = sizeof(AudioUnitSampleType);
            audioFormat.mChannelsPerFrame = 2;
            audioFormat.mBitsPerChannel = 8 * sizeof(AudioUnitSampleType);
            audioFormat.mReserved = 0;
            // Apply format
            status = AudioUnitSetProperty(audioUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          kAudioUnitScope_Input,
                                          kOutputBus,
                                          &audioFormat,
                                          sizeof(AudioStreamBasicDescription));
            if(status)
            {
                NSLog(@"AudioUnitSetProperty stream format failed: %ld",status);
            }
            else
            {
                UInt32 maxFrames = 1024*4;
                AudioUnitSetProperty(audioUnit,
                                     kAudioUnitProperty_MaximumFramesPerSlice,
                                     kAudioUnitScope_Input,
                                     kOutputBus,
                                     &maxFrames,
                                     sizeof(maxFrames));
                
                AURenderCallbackStruct callback;
                callback.inputProc = &SoundEngine_playCallback;
                
                // This is only required if you want the pointer to the object to be passed into the function.
                //callback.inputProcRefCon = self; ???? Is that required
                
                // Set output callback
                status = AudioUnitSetProperty(audioUnit,
                                              kAudioUnitProperty_SetRenderCallback,
                                              kAudioUnitScope_Global,
                                              kOutputBus,
                                              &callback,
                                              sizeof(AURenderCallbackStruct));
                if(status)
                {
                    NSLog(@"AudioUnitSetProperty render callback failed: %ld",status);
                }
                else
                {
                    status = AudioUnitInitialize(audioUnit);
                    if(status)
                    {
                        NSLog(@"AudioUnitSetProperty initialize failed: %ld",status);
                    }
                    else
                    {
                        status = AudioOutputUnitStart(audioUnit);
                        if(status)
                        {
                          NSLog(@"AudioUnitStart:%ld",status);
                        }
                        else
                        {
                            SoundEngine_wake();
                        }
                    }
                }
            }
        }
    }
}

void rawEngineStart()
{
    SoundEngine_start();
    NSLog(@"rawEngineStart");
}

void rawEngineStop()
{
    AudioOutputUnitStop(audioUnit);    
    NSLog(@"rawEngineStop");    
}


