//
//  SurfaceTouchHandling.h
//  AlephOne
//
//  Created by Robert Fielding on 12/22/11.
//  Copyright 2011 Rob Fielding Software.
//

struct PitchHandler_context;
struct Fretless_context;

void SurfaceTouchHandling_touchesInit(
                                      struct PitchHandler_context* phctxArg, 
                                      struct Fretless_context* fctxArg,
                                      int (*failArg)(const char*,...),
                                      int (*loggerArg)(const char*,...)
                                      );
void SurfaceTouchHandling_touchesFlush(void* ctx);
void SurfaceTouchHandling_touchesUp(void* ctx,int finger,void* touch);
void SurfaceTouchHandling_touchesDown(void* ctx,int finger,void* touch,int isMoving,float x,float y, float area);
void SurfaceTouchHandling_tick(void* ctx);
float SurfaceTouchHandling_getChorusLevel();
void SurfaceTouchHandling_setChorusLevel(float chorus);

float SurfaceTouchHandling_getBaseVolume();
void SurfaceTouchHandling_setBaseVolume(float vel);

void SurfaceTouchHandling_setLegato(int val);
int SurfaceTouchHandling_getLegato();

void SurfaceTouchHandling_setPoly(int val);
int SurfaceTouchHandling_getPoly();
