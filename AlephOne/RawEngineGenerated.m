//
//  RawEngineGenerated.c
//  AlephOne
//
//  Created by Robert Fielding on 3/4/12.
//  Copyright (c) 2012 Check Point Software. All rights reserved.
//
#import <Accelerate/Accelerate.h>
#import "RawEngineGenerated.h"

#define SAMPLEINPARALLEL(samples,statement) for(int i=0; i<samples; i++) { statement; }

static inline void xDSP_vcp(float* src,float* dst,int count)
{
    memcpy(dst,src,count*sizeof(float));
}


unsigned int jLocation[SAMPLESMAX];
float vArray[SAMPLESMAX];
float eArray[SAMPLESMAX];
float eNotArray[SAMPLESMAX];
float dArray[SAMPLESMAX];
float dNotArray[SAMPLESMAX];
float registerLeft[SAMPLESMAX];
float registerRight[SAMPLESMAX];

float waveIndexArray[SAMPLESMAX];
float waveMixArray[SAMPLESMAX];
float wavemax=WAVEMAX;

static inline void renderNoiseComputeWaveIndexJ(float phase,float cyclesPerSample,unsigned long samples)
{
    //
    //cycles[i]         = i * cyclesPerSample + phase
    //
    
    xDSP_vcp(sampleIndexArray,registerLeft,samples); 
    vDSP_vsmul(registerLeft,1,&cyclesPerSample,registerLeft,1,samples);
    vDSP_vsadd(registerLeft,1,&phase,registerLeft,1,samples);
    
    //
    //waveIndexArray[i]      = (frac(cycles[i]) * WAVEMAX)
    //
    
    vDSP_vfrac(registerLeft,1,registerLeft,1,samples);
    vDSP_vsmul(registerLeft,1,&wavemax,waveIndexArray,1,samples);    
}

static inline void renderNoiseComputeV(float currentVolume, float deltaVolume, unsigned long samples)
{
    //
    // deltaVolume = invSamples * diffVolume
    // v[i] = (i * (invSamples * diffVolume)) + currentVolume
    //
    
    xDSP_vcp(sampleIndexArray,vArray,samples);    
    vDSP_vsmul(vArray,1,&deltaVolume,vArray,1,samples);
    vDSP_vsadd(vArray,1,&currentVolume,vArray,1,samples);        
}

static inline void renderNoiseComputeE(float currentExpr, float deltaExpr, unsigned long samples)
{
    float one=1;
    
    //
    // deltaExpr = invSamples * diffExpr
    // e[i] = (i * (invSamples * diffExpr)) + currentExpr
    // eNot[i] = (1-e[i])
    //
    
    xDSP_vcp(sampleIndexArray,eArray,samples);    
    vDSP_vsmul(eArray,1,&deltaExpr,eArray,1,samples);
    vDSP_vsadd(eArray,1,&currentExpr,eArray,1,samples);      
    vDSP_vfill(&one,eNotArray,1,samples);
    vDSP_vsub(eNotArray,1,eArray,1,eNotArray,1,samples);    
    
    //
    // d[i]    = eNot[i] * v[i] 
    // dNot[i] = (1-d[i])
    //
    xDSP_vcp(eNotArray,dArray,samples);
    vDSP_vmul(dArray,1, vArray,1, dArray,1, samples);
    vDSP_vfill(&one,dNotArray,1,samples);
    vDSP_vsub(dNotArray,1, dArray,1, dNotArray,1, samples);    
}

static inline void renderNoiseSampleMix(float* output,float pitchLocation,unsigned long samples)
{
    //pitchLocation = pitchLocation*pitchLocation;
    float pitchLocationNot=(1-pitchLocation);
    
    // unSquishedTotal[i] = 
    //  (d[i] * waveMix[0][1][j[i]] + dNot[i] * waveMix[0][0][j[i]]) * eNot[i]  +
    //  (d[i] * waveMix[1][1][j[i]] + dNot[i] * waveMix[1][0][j[i]]) * e[i] 
    //   
    //
    xDSP_vcp(dArray,registerLeft,samples);    
    vDSP_vindex(waveMix[0][1],waveIndexArray,1,waveMixArray,1,samples);
    vDSP_vmul(waveMixArray,1,registerLeft,1,registerLeft,1,samples);
    
    xDSP_vcp(dNotArray,registerRight,samples);    
    vDSP_vindex(waveMix[0][0],waveIndexArray,1,waveMixArray,1,samples);
    vDSP_vmul(waveMixArray,1,registerRight,1,registerRight,1,samples);
    
    vDSP_vadd(registerLeft,1, registerRight,1, registerLeft,1, samples);
    vDSP_vmul(eNotArray,1, registerLeft,1, eNotArray,1, samples);
    
    xDSP_vcp(dArray,registerLeft,samples);
    vDSP_vindex(waveMix[1][1],waveIndexArray,1,waveMixArray,1,samples);
    vDSP_vmul(waveMixArray,1,registerLeft,1,registerLeft,1,samples);
    
    xDSP_vcp(dNotArray, registerRight, samples);    
    vDSP_vindex(waveMix[1][0],waveIndexArray,1,waveMixArray,1,samples);
    vDSP_vmul(waveMixArray,1,registerRight,1,registerRight,1,samples);
    
    vDSP_vadd(registerLeft,1, registerRight,1, registerLeft,1, samples);    
    vDSP_vmul(eArray,1, registerLeft,1, eArray,1, samples);
    vDSP_vadd(eArray,1, eNotArray,1, registerLeft,1, samples);
        
    //
    //  output += v *
    //    (plNot * unSquishedTotal + waveFundamental * pl * pl)
    
    vDSP_vsmul(registerLeft,1,&pitchLocationNot,registerLeft,1,samples);    
    vDSP_vindex(_waveFundamental,waveIndexArray,1,waveMixArray,1,samples);
    vDSP_vsmul(registerRight,1,&pitchLocation,registerRight,1,samples);    
    vDSP_vsmul(registerRight,1,&pitchLocation,registerRight,1,samples);    
    vDSP_vadd(registerLeft,1, registerRight,1, registerLeft,1, samples);
    
    vDSP_vmul(registerLeft,1, vArray,1, registerLeft,1, samples);    
    vDSP_vadd(output,1, registerLeft,1, output,1, samples);
    
}

/**
 Good God!  This is assembly language.
 */
float renderNoiseInnerLoopInParallel(
                                     float* output,
                                     float notep,float detune,
                                     float pitchLocation,float phase,
                                     unsigned long samples,float invSamples,
                                     float currentVolume,float deltaVolume,
                                     float currentExpr,float deltaExpr)
{
    float cyclesPerSample = powf(2,(notep-33+(1-currentExpr)*detune*(1-pitchLocation))/12) * (440/(44100.0 * 32));
    
    renderNoiseComputeWaveIndexJ(phase,cyclesPerSample, samples);
    renderNoiseComputeV(currentVolume, deltaVolume, samples);    
    renderNoiseComputeE(currentExpr, deltaExpr, samples);    
    renderNoiseSampleMix(output,pitchLocation,samples);
    return (cyclesPerSample*samples) + phase;
}

