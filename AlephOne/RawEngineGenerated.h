//
//  RawEngineGenerated.h
//  AlephOne
//
//  Created by Robert Fielding on 3/4/12.
//  Copyright (c) 2012 Rob Fielding Software.
//
//  If we generate RawEngineGenerated.m, then this is the header we need to follow

#define WAVEMAX (1024*2)
//#define SAMPLESMAX 1024*2
#define DIST 2
#define EXPR 2
#define OCTAVES 12

float  waveMix        [OCTAVES][EXPR][DIST][WAVEMAX];
float _waveFundamental            [WAVEMAX];
//float sampleIndexArray[SAMPLESMAX];

float renderNoiseInnerLoopInParallel(
                                     float* output,
                                     float notep,float notepTarget,float detune,
                                     float currentTimbre,float deltaTimbre,float phase,
                                     unsigned long samples,float invSamples,
                                     float currentVolume,float deltaVolume,
                                     float currentExpr,float deltaExpr);
