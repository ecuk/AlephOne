//
//  RawEngineGenerated.c
//  AlephOne
//
//  Created by Robert Fielding on 3/4/12.
//  Copyright (c) 2012 Check Point Software. All rights reserved.
//
#import <Accelerate/Accelerate.h>
#import "RawEngineGenerated.h"

static inline void xDSP_vcp(float* src,float* dst,int count)
{
    memcpy(dst,src,count*sizeof(float));
}


unsigned int jLocation[SAMPLESMAX] __attribute__ ((aligned));
float vArray[SAMPLESMAX] __attribute__ ((aligned));
float eArray[SAMPLESMAX] __attribute__ ((aligned));
float eNotArray[SAMPLESMAX] __attribute__ ((aligned));
float dArray[SAMPLESMAX] __attribute__ ((aligned));
float dNotArray[SAMPLESMAX] __attribute__ ((aligned));
float registerLeft[SAMPLESMAX] __attribute__ ((aligned));
float registerRight[SAMPLESMAX] __attribute__ ((aligned));

float waveIndexArray[SAMPLESMAX] __attribute__ ((aligned));
float waveMixArray[SAMPLESMAX] __attribute__ ((aligned));

float pitchLocationArray[SAMPLESMAX] __attribute__((aligned));

float wavemax=WAVEMAX;

static inline void renderNoiseComputeWaveIndexJ(float phase,float cyclesPerSample,unsigned long samples)
{
    //
    //cycles[i]         = i * cyclesPerSample + phase
    //
    
    //xDSP_vcp(sampleIndexArray,registerLeft,samples); 
    //vDSP_vsmul(registerLeft,1,&cyclesPerSample,registerLeft,1,samples);
    float zero = 0;
    //float fsamples = samples;
    vDSP_vramp(&zero,&cyclesPerSample,registerLeft,1,samples);
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
    vDSP_vramp(&currentVolume,&deltaVolume,vArray,1,samples);
    //printf("%f %f %f\n",vArray[0],vArray[samples-1],deltaVolume);
}

static inline void renderNoiseComputeE(float currentExpr, float deltaExpr, unsigned long samples)
{
    float one=1;
    //
    // deltaExpr = invSamples * diffExpr
    // e[i] = (i * (invSamples * diffExpr)) + currentExpr
    // //e[i] = bound{0,1}(2*(e[0] - 0.25))
    // eNot[i] = (1-e[i])
    //
    vDSP_vramp(&currentExpr,&deltaExpr,eArray,1,samples);
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

static inline void renderNoiseSampleMixInternal(float* waveLo, float* waveHi, float* eScaleArray,unsigned long samples)
{
    xDSP_vcp(dArray,registerLeft,samples);        
    vDSP_vindex(waveHi,waveIndexArray,1,waveMixArray,1,samples);
    vDSP_vmul(waveMixArray,1,registerLeft,1,registerLeft,1,samples);
    
    //registerRight = dNotArray * waveMix[0][0]
    xDSP_vcp(dNotArray,registerRight,samples);    
    vDSP_vindex(waveLo,waveIndexArray,1,waveMixArray,1,samples);
    vDSP_vmul(waveMixArray,1,registerRight,1,registerRight,1,samples);
    
    //eNotArray = eNotArray * (dArray * waveMix[0][1] + dNotArray * waveMix[0][0])   --verified
    vDSP_vadd(registerLeft,1, registerRight,1, registerLeft,1, samples);
    vDSP_vmul(eScaleArray,1, registerLeft,1, eScaleArray,1, samples);    
}

static inline void renderNoiseSampleMix(float* output,float pitchLocation,float pitchLocationDelta,unsigned long samples)
{
    float pitchLocationNot=(1-pitchLocation);
    float pitchLocationNotDelta=-pitchLocationDelta;
    
    // unSquishedTotal[i] = 
    //  (d[i] * waveMix[0][1][j[i]] + dNot[i] * waveMix[0][0][j[i]]) * eNot[i]  +
    //  (d[i] * waveMix[1][1][j[i]] + dNot[i] * waveMix[1][0][j[i]]) * e[i] 
    //   
    renderNoiseSampleMixInternal(waveMix[0][0], waveMix[0][1],eNotArray,samples);
    renderNoiseSampleMixInternal(waveMix[1][0], waveMix[1][1],eArray,samples);
    vDSP_vadd(eArray,1, eNotArray,1, registerLeft,1, samples);
    
    //
    //  output += v *
    //    (plNot * unSquishedTotal + waveFundamental * pl)
    
    // registerLeft = registerLeft * unSquishedTotal
    
    vDSP_vramp(&pitchLocationNot,&pitchLocationNotDelta,pitchLocationArray,1,samples);
    vDSP_vmul(registerLeft,1,pitchLocationArray,1,registerLeft,1,samples); 
    
    vDSP_vramp(&pitchLocation,&pitchLocationDelta,pitchLocationArray,1,samples);
    vDSP_vindex(_waveFundamental,waveIndexArray,1,waveMixArray,1,samples);
    vDSP_vmul(waveMixArray,1,pitchLocationArray,1,registerRight,1,samples);  
    
    // output = v * (registerLeft + registerRight)
    vDSP_vadd(registerLeft,1, registerRight,1, registerLeft,1, samples);    
    vDSP_vmul(registerLeft,1, vArray,1, registerLeft,1, samples);    
    vDSP_vadd(output,1, registerLeft,1, output,1, samples);
    
}

float renderNoiseInnerLoopInParallel(
                                     float* output,
                                     float notep,float detune,
                                     float pitchLocation,float pitchLocationDelta,float phase,
                                     unsigned long samples,float invSamples,
                                     float currentVolume,float deltaVolume,
                                     float currentExpr,float deltaExpr, float timbreVal)
{
    float cyclesPerSample = powf(2,(notep-33+(1-currentExpr)*detune*(1-pitchLocation))/12) * (440/(44100.0 * 32));
    //Scale this value per sample
    pitchLocationDelta = pitchLocationDelta/samples;
    
    renderNoiseComputeWaveIndexJ(phase,cyclesPerSample, samples);
    renderNoiseComputeV(currentVolume, deltaVolume, samples);    
    renderNoiseComputeE(currentExpr, deltaExpr, samples);    
    renderNoiseSampleMix(output,pitchLocation,pitchLocationDelta,samples);
    return (cyclesPerSample*samples) + phase;
}

