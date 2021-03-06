//
//  ObjectRendering.h
//  AlephOne
//
//  Created by Robert Fielding on 12/18/11.
//  Copyright 2011 Rob Fielding Software.
//
struct VertexObjectBuilder;
struct PitchHandler_context;
struct Fretless_context;


void ObjectRendering_init(
                           struct VertexObjectBuilder* voCtxDynamicArg,
                           //struct VertexObjectBuilder* voCtxStaticArg,
                           struct PitchHandler_context* phctxArg,
                           struct Fretless_context* fctxArg,
                           void* ObjectRendering_imageContextArg,
                           void (*ObjectRendering_imageRenderArg)(void*,char*,unsigned int*,float*,float*,int),
                           void (*ObjectRendering_stringRenderArg)(void*,char*,unsigned int*,float*,float*,int),
                           void (*ObjectRendering_drawVOArg)()
                           );


void ObjectRendering_loadImages();

int ObjectRendering_getTexture(int idx);

void ObjectRendering_updateLightOrientation(float x,float y, float z);

