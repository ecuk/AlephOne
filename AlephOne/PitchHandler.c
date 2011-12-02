//
//  PitchHandler.c
//  AlephOne
//
//  Created by Robert Fielding on 12/1/11.
//  Copyright 2011 Check Point Software. All rights reserved.
//

#include "PitchHandler.h"
#include <math.h>

#define FINGERMAX 16
#define NOBODY -1
static float tuneInterval = 5; ////12*log2f(4.0/3) is Just intonation btw
static float tuneSpeed = 0.1;
static float rowCount = 3;
static float colCount = 5;
static int   noteDiff = 48;

float PitchHandler_getTuneInterval()
{
    return tuneInterval;
}

void PitchHandler_setTuneInterval(float tuning)
{
    tuneInterval = tuning;
}

float PitchHandler_getTuneSpeed()
{
    return tuneSpeed;
}

void PitchHandler_setTuneSpeed(float tuneSpeedArg)
{
    tuneSpeed = tuneSpeedArg;
}

float PitchHandler_getRowCount()
{
    return rowCount;
}

void PitchHandler_setRowCount(float rowCountArg)
{
    rowCount = rowCountArg;
}
        
float PitchHandler_getColCount()
{
    return colCount;
}

void PitchHandler_setColCount(float colCountArg)
{
    colCount = colCountArg;
}

float PitchHandler_getNoteDiff()
{
    return noteDiff;
}

void PitchHandler_setNoteDiff(float noteDiffArg)
{
    noteDiff = noteDiffArg;
}


float PitchHandler_pickPitchRaw(int finger,float x,float y,int* stringP,float* exprP)
{
    *stringP = (rowCount * x);
    *exprP = (rowCount*x) - *stringP;
    float fret = colCount*y;
    float thisPitch = (fret + (*stringP)*tuneInterval); 
    return thisPitch;
}

//Quick oct rounding hack
float PitchHandler_pickPitch(int finger,int isMoving,float thisPitch,float* beginPitchP, float* endPitchP)
{
 
    
    static int   lastFingerDown = NOBODY;
    static float lastNoteDown = 0;
    static int   noteDiffOurs = 0;
    static int   noteDiffByFinger[FINGERMAX];
    static float   yDiffByFinger[FINGERMAX];
    
    if( isMoving )
    {
        noteDiffOurs = noteDiffByFinger[finger];
    }
    else
    {
        lastFingerDown = finger;
        noteDiffOurs = noteDiff;
        noteDiffByFinger[finger] = noteDiff;
    }

    thisPitch += noteDiffOurs;
    *beginPitchP = thisPitch;
    *endPitchP = (int)thisPitch;
    
    float targetDrift = (*endPitchP - thisPitch);
    if( isMoving )
    {
        yDiffByFinger[finger] = (1 - tuneSpeed) * yDiffByFinger[finger] + tuneSpeed * targetDrift;                
    }
    else
    {
        yDiffByFinger[finger] = targetDrift;        
    }
    thisPitch += yDiffByFinger[finger];
    
    if(finger == lastFingerDown)
    {
        float diff = (thisPitch - lastNoteDown);
        if(diff > 6.5)
        {
            thisPitch -= 12;
            noteDiff -= 12;
            noteDiffOurs -= 12;
        }
        if(diff <= -6.5)
        {
            thisPitch += 12;
            noteDiff += 12;
            noteDiffOurs += 12;
        }
        while(thisPitch < -0.5)
        {
            thisPitch += 12;
            noteDiff += 12;
            noteDiffOurs += 12;
        }
        while(thisPitch >= 127.5)
        {
            thisPitch -= 12;
            noteDiff -= 12;
            noteDiffOurs -= 12;
        }
        lastNoteDown = thisPitch;
    }
    noteDiffByFinger[finger] = noteDiffOurs;        
    return thisPitch;
}
