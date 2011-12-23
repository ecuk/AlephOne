//
//  GenericTouchHandling.c
//  AlephOne
//
//  Created by Robert Fielding on 12/2/11.
//  Copyright 2011 Check Point Software. All rights reserved.
//

#include "GenericTouchHandling.h"
#include "TouchMapping.h"
#include "WidgetTree.h"

#include "SurfaceTouchHandling.h"

#define FINGERMAX 16
#define NULL ((void*)0)

struct Fretless_context;
struct PitchHandler_context;

static struct Fretless_context* fretlessp = NULL;
static struct PitchHandler_context* phctx = NULL;
static int (*fail)(const char*,...);
static int (*logger)(const char*,...);
static int currentWidget[FINGERMAX];

void GenericTouchHandling_touchesFlush()
{
    SurfaceTouchHandling_touchesFlush(NULL);
}

void GenericTouchHandling_touchesInit(
    struct PitchHandler_context* phctxArg, 
    struct Fretless_context* fctxArg,
    int (*failArg)(const char*,...),
    int (*loggerArg)(const char*,...)
)
{
    phctx = phctxArg;
    fretlessp = fctxArg;
    fail = failArg;
    logger = loggerArg;
        
    SurfaceTouchHandling_touchesInit(phctxArg,fctxArg,failArg,loggerArg);
}

void GenericTouchHandling_touchesUp(void* touch)
{
    int finger  = TouchMapping_mapFinger(touch);
    int wid = currentWidget[finger];
    
    struct WidgetTree_rect* itemP = WidgetTree_get(wid);
    if(itemP && itemP->up)
    {
        itemP->up(NULL,finger,touch);        
    }
    TouchMapping_unmapFinger(touch);
}


void GenericTouchHandling_touchesDown(void* touch,int isMoving,float x,float y, float velocity, float area)
{
    int finger  = TouchMapping_mapFinger(touch);
    int wid;
    
    if(isMoving)
    {
        wid = currentWidget[finger];
    }
    else
    {
        wid = WidgetTree_hitTest(x,y);        
        currentWidget[finger] = wid;
    }

    struct WidgetTree_rect* itemP = WidgetTree_get(wid);
    if(itemP && itemP->down)
    {
        itemP->down(NULL,finger,touch,isMoving,x,y,velocity,area);                    
    }
}

void GenericTouchHandling_tick()
{
    SurfaceTouchHandling_tick(NULL);        
}

