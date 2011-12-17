//
//  GenericRendering.c
//  AlephOne
//
//  Created by Robert Fielding on 12/3/11.
//  Copyright 2011 Check Point Software. All rights reserved.
//

#include "GenericRendering.h"
#include "PitchHandler.h"
#include "Fretless.h"
#include "VertexObjectBuilder.h"
#include "Transforms.h"
#include <OpenGLES/ES1/gl.h>
#include <stdlib.h>
#include <math.h>

//#include <stdio.h>

struct VertexObjectBuilder* voCtxStatic;
struct VertexObjectBuilder* voCtxDynamic;
struct PitchHandlerContext* phctx;
struct Fretless_context* fctx;

#define NOTEADDEDMAX 32
static float noteAddedPitches[NOTEADDEDMAX];
static float noteAddedVolumes[NOTEADDEDMAX];
static int noteAddedHead=0;

void addedANoteHandler(float pitch, float volume);

static float lightPosition[] = {0, 0, -1,0};
static float specularAmount[] = {0.0,0.0,0.0,1.0};
static float diffuseAmount[] = {1.0,0.8,1.0,1.0};
static float ambientAmount[] = {1.0,1.0,1.0,1.0};

static float scale[16] = {
    1.0f, 0.0f, 0.0f, 0.0f,
    0.0f, 1.0f, 0.0f, 0.0f,
    0.0f, 0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 0.0f, 1.0f
};

void GenericRendering_init(struct PitchHandlerContext* phctxArg,struct Fretless_context* fctxArg)
{
    phctx = phctxArg;
    fctx  = fctxArg;
    
    PitchHandler_registerAddedANote(phctx, addedANoteHandler);
}

void GenericRendering_updateLightOrientation(float x,float y, float z)
{
    lightPosition[0] = x;
    lightPosition[1] = y;
    lightPosition[2] = z;
}

void GenericRendering_camera()
{
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    
    Transforms_getOrientation(scale);
    
    glMultMatrixf(scale);
    glScalef(2,2,1);
    glTranslatef(-0.5,-0.5,0);
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    ///*
    //glEnable(GL_LIGHTING);
    
    glEnable(GL_LIGHT0);
    glLightfv(GL_LIGHT0, GL_POSITION, lightPosition);
    glLightfv(GL_LIGHT0, GL_DIFFUSE, diffuseAmount);
    glLightfv(GL_LIGHT0, GL_AMBIENT, ambientAmount);
    glLightfv(GL_LIGHT0, GL_SPECULAR, specularAmount);
    
     //*/ 
    
//    glClearColor(0.9,0.8,0.3,1.0);
} 

void GenericRendering_drawBackground()
{
    //int rows = PitchHandler_getRowCount(phctx);
    //int cols = PitchHandler_getColCount(phctx);
    
    //float xscale = 1.0/cols;
    //float yscale = 1.0/rows;
    //float halfXscale = 0.5*xscale;
    //float halfYscale = 0.5*yscale;
    
    float lx=0;//lightPosition[0]+64;
    float ly=0;//lightPosition[1]+64;
    float lz=0;//lightPosition[2]+64;
    
    VertexObjectBuilder_startObject(voCtxStatic,GL_TRIANGLE_STRIP);
    
    VertexObjectBuilder_addVertex(voCtxStatic,0,0,0, 
                                  lx, ly, lz,
                                  255,0,0,1);
    VertexObjectBuilder_addVertex(voCtxStatic,1,0,0, 
                                  lz, lx, ly,
                                  255,0,0,1);
    VertexObjectBuilder_addVertex(voCtxStatic,0,1,0, 
                                  ly, lz, lx,
                                  255,0,0,1);
    VertexObjectBuilder_addVertex(voCtxStatic,1,1,0, 
                                  lx, lz, ly,
                                  255,0,0,1);
}

void drawOccupancyHandle(float cx, float cy, float diameter,float z)
{
    z = z/16 * 2*M_PI;
    
    //Draw the endpoints of the channel cycle
    float rA = (diameter*0.25+0.02);
    float rB = (diameter*0.25);
    float cosA = cosf(z+0.1);
    float sinA = sinf(z+0.1);
    float cosB = cosf(z-0.1);
    float sinB = sinf(z-0.1);
    float cosC = cosf(z);
    float sinC = sinf(z);
    VertexObjectBuilder_addVertex(voCtxStatic,cx+rB*cosC,cy+rB*sinC,0, 
                                  255, 255,255,127,0,0,1);        
    VertexObjectBuilder_addVertex(voCtxStatic,cx+rA*cosA,cy+rA*sinA,0, 
                                  200, 200,  0,100,0,0,1);        
    VertexObjectBuilder_addVertex(voCtxStatic,cx+rA*cosB,cy+rA*sinB,0, 
                                  200, 200,  0,100,0,0,1);        
}

void GenericRendering_drawChannelOccupancy(float cx,float cy,float diameter)
{
    //Draw the main radius of the channel cycle
    VertexObjectBuilder_startObject(voCtxStatic,GL_LINE_STRIP);    
    float r = (diameter*0.25);
    for(int channel=0; channel<16; channel++)
    {
        float a = channel/16.0 * 2*M_PI;
        float cosA = cosf(a);
        float sinA = sinf(a);
        VertexObjectBuilder_addVertex(voCtxStatic,cx+r*cosA,cy+r*sinA,0, 
                                      0, 255, 0,64,0,0,1);                
    }
    VertexObjectBuilder_addVertex(voCtxStatic,cx+r,cy,0, 
                                  0, 255, 0,64,0,0,1);  
    
    VertexObjectBuilder_startObject(voCtxStatic,GL_TRIANGLES);
    int bottom = Fretless_getMidiHintChannelBase(fctx);
    int top  = (bottom + Fretless_getMidiHintChannelSpan(fctx) + 15)%16;
    drawOccupancyHandle(cx,cy,diameter,bottom);
    drawOccupancyHandle(cx,cy,diameter,top);
        
    //Draw activity in the channel cycle
    for(int channel=0; channel<16; channel++)
    {
        float r = (diameter*0.5) * Fretless_getChannelOccupancy(fctx, channel);
        float a = channel/16.0 * 2*M_PI;
        float cosA = cosf(a-0.15);
        float sinA = sinf(a-0.15);
        float cosB = cosf(a+0.15);
        float sinB = sinf(a+0.15);
        float cosC = cosf(a);
        float sinC = sinf(a);
        
        //Represent the current bend setting for each channel
        float rC = (diameter*0.5)/4;
        float b = Fretless_getChannelBend(fctx, channel);
        float rD = rC + (diameter*0.5/4)*b;
        
        int red   = b>0 ? 255 : 0;
        int green = 0;
        int blue  = b>0 ? 0 : 255;
        
        //Draw the channel cycling
        VertexObjectBuilder_addVertex(voCtxStatic,cx,cy,0, 
                                      0, 255, 0,127,0,0,1);        
        VertexObjectBuilder_addVertex(voCtxStatic,cx+r*cosA,cy+r*sinA,0, 
                                      0, 200, 0,  0,0,0,1);        
        VertexObjectBuilder_addVertex(voCtxStatic,cx+r*cosB,cy+r*sinB,0, 
                                      0, 255, 0,  0,0,0,1); 
        
        //Draw what the bend manipulation is doing
        VertexObjectBuilder_addVertex(voCtxStatic,cx+rC*cosA,cy+rC*sinA,0, 
                                      red, green, blue,200,0,0,1);        
        VertexObjectBuilder_addVertex(voCtxStatic,cx+rC*cosB,cy+rC*sinB,0, 
                                      red*0.5, green*0.5, blue*0.5,200,0,0,1);        
        VertexObjectBuilder_addVertex(voCtxStatic,cx+rD*cosC,cy+rD*sinC,0, 
                                      red*0.5, green*0.5, blue*0.5,200,0,0,1);  
        
    }
}

void GenericRendering_setup()
{
    voCtxDynamic = VertexObjectBuilder_init(malloc);    
    voCtxStatic = VertexObjectBuilder_init(malloc);
    //GenericRendering_drawBackground();
}

void addedANoteHandler(float pitch, float volume)
{
    //Simply write them in reverse order such that
    //head points to the first one.  The unused ones
    //will have volume zero.
    noteAddedHead += (NOTEADDEDMAX-1);
    noteAddedHead %= NOTEADDEDMAX;
    noteAddedPitches[noteAddedHead] = pitch;
    noteAddedVolumes[noteAddedHead] = volume;
}


int noteToStaff(float note,int* isSharp)
{
    int scaleNoOct;
    int qnote = (int)(note+0.5);
    int oct = qnote/12;
    int qnoteNoOct = qnote % 12;
    switch(qnoteNoOct)
    {
        case 0: *isSharp=0; scaleNoOct=0; break;//C
        case 1: *isSharp=1; scaleNoOct=0; break;//C#
        case 2: *isSharp=0; scaleNoOct=1; break;//D
        case 3: *isSharp=1; scaleNoOct=1; break;//D#
        case 4: *isSharp=0; scaleNoOct=2; break;//E
        case 5: *isSharp=0; scaleNoOct=3; break;//F
        case 6: *isSharp=1; scaleNoOct=3; break;//F#
        case 7: *isSharp=0; scaleNoOct=4; break;//G
        case 8: *isSharp=1; scaleNoOct=4; break;//G#
        case 9: *isSharp=0; scaleNoOct=5; break;//A
        case 10: *isSharp=1; scaleNoOct=5;break;//A#
        case 11: *isSharp=0; scaleNoOct=6;break;//B
    }
    return 7*oct + scaleNoOct;
}
                 
void drawStaff(float cx,float cy,float width, float height)
{
    VertexObjectBuilder_startObject(voCtxDynamic, GL_LINES);
    for(int i=0; i<(70); i++)
    {
        float x = cx;
        float y = cy - height/2 + height/127 * i;
        float red = 0;
        float green = 0;
        float blue = 255;
        float trans=127;
        
        VertexObjectBuilder_addVertex(voCtxDynamic,
                                      x - width/2,     y   ,0,
                                      red,green,blue,trans,
                                      0,0,1);                        
        VertexObjectBuilder_addVertex(voCtxDynamic,
                                      x + width/2,     y   ,0,
                                      red,green,blue,trans,
                                      0,0,1);        
    }
        
    VertexObjectBuilder_startObject(voCtxDynamic, GL_TRIANGLES);
    for(int i=0; i<NOTEADDEDMAX; i++)
    {
        int cursor = (noteAddedHead+i)%NOTEADDEDMAX;
        if(noteAddedVolumes[cursor] > 0)
        {
            float x = cx + width/2 - width/NOTEADDEDMAX * i;
            int isSharp=0;
            float y = cy - height/2 + height/(70) * noteToStaff(noteAddedPitches[cursor],&isSharp);
            float red = 0;
            float green = 0;
            float blue = 255;
            float trans=127;
            float dx = 0.005;
            float dy = 0.005;
            VertexObjectBuilder_addVertex(voCtxDynamic,
                                          x,     y+dy   ,0,
                                          red,green,blue,trans,
                                          0,0,1);                        
            VertexObjectBuilder_addVertex(voCtxDynamic,
                                          x-dx,     y   ,0,
                                          red,green,blue,trans,
                                          0,0,1);                        
            VertexObjectBuilder_addVertex(voCtxDynamic,
                                          x+dx,     y   ,0,
                                          red,green,blue,trans,
                                          0,0,1);       
            
            VertexObjectBuilder_addVertex(voCtxDynamic,
                                          x,     y-dy   ,0,
                                          red,green,blue,trans,
                                          0,0,1);                        
            VertexObjectBuilder_addVertex(voCtxDynamic,
                                          x-dx,     y   ,0,
                                          red,green,blue,trans,
                                          0,0,1);                        
            VertexObjectBuilder_addVertex(voCtxDynamic,
                                          x+dx,     y   ,0,
                                          red,green,blue,trans,
                                          0,0,1);        
            if(isSharp)
            {
                VertexObjectBuilder_startObject(voCtxDynamic, GL_LINES);  
                
                VertexObjectBuilder_addVertex(voCtxDynamic,
                                              x + dx,     y+dy   ,0,
                                              red,green,blue,trans,
                                              0,0,1);                        
                VertexObjectBuilder_addVertex(voCtxDynamic,
                                              x + dx,     y-dy   ,0,
                                              red,green,blue,trans,
                                              0,0,1);                       
                
                VertexObjectBuilder_addVertex(voCtxDynamic,
                                              x + 1.75*dx,     y+dy   ,0,
                                              red,green,blue,trans,
                                              0,0,1);                        
                VertexObjectBuilder_addVertex(voCtxDynamic,
                                              x + 1.75*dx,     y-dy   ,0,
                                              red,green,blue,trans,
                                              0,0,1);
                
                VertexObjectBuilder_addVertex(voCtxDynamic,
                                              x + 0.5*dx,     y+0.4*dy   ,0,
                                              red,green,blue,trans,
                                              0,0,1);  
            
                VertexObjectBuilder_addVertex(voCtxDynamic,
                                              x + 2*dx,     y+0.5*dy   ,0,
                                              red,green,blue,trans,
                                              0,0,1);
                
                VertexObjectBuilder_addVertex(voCtxDynamic,
                                              x + 0.5*dx,     y-0.6*dy   ,0,
                                              red,green,blue,trans,
                                              0,0,1);  
                
                VertexObjectBuilder_addVertex(voCtxDynamic,
                                              x + 2*dx,     y-0.5*dy   ,0,
                                              red,green,blue,trans,
                                              0,0,1);
                VertexObjectBuilder_startObject(voCtxDynamic, GL_TRIANGLES);  
            }
        }
    }
}

void GenericRendering_drawMoveableFrets()
{
    float pitch=0;
    float x=0;
    float y=0;
    float dx = 0.01;
    float dy = 1.0/PitchHandler_getRowCount(phctx);
    int importance=1;
    float usage;
    //float lx=127*lightPosition[0]+127;
    //float ly=127*lightPosition[1]+127;
    //float lz=127*lightPosition[2]+127;
     
    VertexObjectBuilder_startObject(voCtxDynamic, GL_TRIANGLES);
    
    PitchHandler_getFretsBegin(phctx);
    while(PitchHandler_getFret(phctx,&pitch, &x, &y, &importance, &usage))
    {
        float dxi = dx*importance*(1+usage);
        float bCol = importance * 255.0 / 4.0;
        
        int red = 0;
        int green = usage*50;
        int blue = 255;
        int trans = bCol;
        
        int rede = 127;
        int greene = 127;
        int bluee = 255;
        int transe = 0;
        
        if(importance == 3)
        {
            red = 200;
        }
        else
        {
            if(importance == 1)
            {
                green = 255;  
                trans = 64+usage*64;
            }            
        }
        
        
        VertexObjectBuilder_addVertex(voCtxDynamic,x,     y   ,0,red,green,blue,trans,0,0,1);            
        VertexObjectBuilder_addVertex(voCtxDynamic,x-dxi, y   ,0,rede,greene,bluee,transe,0,0,1);            
        VertexObjectBuilder_addVertex(voCtxDynamic,x    , y-dy,0,rede,greene,bluee,transe,0,0,1);            
        
        VertexObjectBuilder_addVertex(voCtxDynamic,x,     y   ,0,red,green,blue,trans,0,0,1);            
        VertexObjectBuilder_addVertex(voCtxDynamic,x    , y+dy,0,rede,greene,bluee,transe,0,0,1);            
        VertexObjectBuilder_addVertex(voCtxDynamic,x+dxi, y   ,0,rede,greene,bluee,transe,0,0,1);            
        
        VertexObjectBuilder_addVertex(voCtxDynamic,x,     y   ,0,red,green,blue,trans,0,0,1);            
        VertexObjectBuilder_addVertex(voCtxDynamic,x    , y+dy,0,rede,greene,bluee,transe,0,0,1);            
        VertexObjectBuilder_addVertex(voCtxDynamic,x-dxi, y   ,0,rede,greene,bluee,transe,0,0,1);            
        
        VertexObjectBuilder_addVertex(voCtxDynamic,x,     y   ,0,red,green,blue,trans,0,0,1);            
        VertexObjectBuilder_addVertex(voCtxDynamic,x+dxi, y   ,0,rede,greene,bluee,transe,0,0,1);            
        VertexObjectBuilder_addVertex(voCtxDynamic,x    , y-dy,0,rede,greene,bluee,transe,0,0,1);            
    }   
    
   
}




void GenericRendering_drawFingerLocation()
{
    float dx = 0.05;
    float dy = 0.3;
    //float lx=127*lightPosition[0]+127;
    //float ly=127*lightPosition[1]+127;
    //float lz=127*lightPosition[2]+127;
    VertexObjectBuilder_startObject(voCtxDynamic, GL_TRIANGLES);
    for(int f=0; f<16; f++)
    {
        struct FingerInfo* fInfo = PitchHandler_fingerState(phctx,f);
        if(fInfo->isActive)
        {
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->fingerX,    fInfo->fingerY   ,0,255,  0,  0,255,0,0,1);            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->fingerX-dx, fInfo->fingerY   ,0,255,127,127,  0,0,0,1);            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->fingerX   , fInfo->fingerY-dy,0,255,127,127,  0,0,0,1);            
            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->fingerX,    fInfo->fingerY   ,0,255,  0,  0,255,0,0,1);            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->fingerX   , fInfo->fingerY+dy,0,255,127,127,  0,0,0,1);            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->fingerX+dx, fInfo->fingerY   ,0,255,127,127,  0,0,0,1);            
            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->fingerX,    fInfo->fingerY   ,0,255,  0,  0,255,0,0,1);            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->fingerX   , fInfo->fingerY+dy,0,255,127,127,  0,0,0,1);            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->fingerX-dx, fInfo->fingerY   ,0,255,127,127,  0,0,0,1);            
            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->fingerX,    fInfo->fingerY   ,0,255,  0,  0,255,0,0,1);            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->fingerX+dx, fInfo->fingerY   ,0,255,127,127,  0,0,0,1);            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->fingerX   , fInfo->fingerY-dy,0,255,127,127,  0,0,0,1);            
            
        }
    }     
}

void GenericRendering_drawPitchLocation()
{
    float dx = 0.05;
    float dy = 0.3;
    //float lx=127*lightPosition[0]+127;
    //float ly=127*lightPosition[1]+127;
    //float lz=127*lightPosition[2]+127;
    VertexObjectBuilder_startObject(voCtxDynamic, GL_TRIANGLES);
    for(int f=0; f<16; f++)
    {
        struct FingerInfo* fInfo = PitchHandler_fingerState(phctx,f);
        if(fInfo->isActive)
        {
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->pitchX,    fInfo->pitchY   ,0,  0,255,  0,255,0,0,1);            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->pitchX-dx, fInfo->pitchY   ,0,127,255,127,  0,0,0,1);            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->pitchX   , fInfo->pitchY-dy,0,127,255,127,  0,0,0,1);            

            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->pitchX,    fInfo->pitchY   ,0,  0,255,  0,255,0,0,1);            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->pitchX   , fInfo->pitchY+dy,0,127,255,127,  0,0,0,1);            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->pitchX+dx, fInfo->pitchY   ,0,127,255,127,  0,0,0,1);            
            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->pitchX,    fInfo->pitchY   ,0,  0,255,  0,255,0,0,1);            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->pitchX   , fInfo->pitchY+dy,0,127,255,127,  0,0,0,1);            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->pitchX-dx, fInfo->pitchY   ,0,127,255,127,  0,0,0,1);            
            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->pitchX,    fInfo->pitchY   ,0,  0,255,  0,255,0,0,1);            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->pitchX+dx, fInfo->pitchY   ,0,127,255,127,  0,0,0,1);            
            VertexObjectBuilder_addVertex(voCtxDynamic,fInfo->pitchX   , fInfo->pitchY-dy,0,127,255,127,  0,0,0,1);            
            
        }
    }    
}

void GenericRendering_dynamic()
{
    VertexObjectBuilder_reset(voCtxStatic);
    GenericRendering_drawBackground();
    
    VertexObjectBuilder_reset(voCtxDynamic);    
    GenericRendering_drawMoveableFrets();
    GenericRendering_drawFingerLocation();
    GenericRendering_drawPitchLocation();
    
    GenericRendering_drawChannelOccupancy(0.8, 0.8, 0.4);
    //drawStaff(0.3,0.8,0.6,0.4);
}

void GenericRendering_drawVO(struct VertexObjectBuilder* vobj)
{
    int voCount = VertexObjectBuilder_getVertexObjectsCount(vobj);
    glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, specularAmount );
    glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, diffuseAmount );
    glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, ambientAmount );
    for(int o=0; o<voCount;o++)
    {
        struct VertexObject* vo = VertexObjectBuilder_getVertexObject(vobj,o);
        
        glEnableClientState(GL_VERTEX_ARRAY);
        glEnableClientState(GL_COLOR_ARRAY);
        glEnableClientState(GL_NORMAL_ARRAY);

        glVertexPointer(3, GL_FLOAT, 0, vo->vertices);        
        glColorPointer(4, GL_UNSIGNED_BYTE, 0, vo->colors);
        glNormalPointer(GL_FLOAT,0, vo->normals);
        
        glDrawArrays(vo->type, 0, vo->count);            
    }
}

void GenericRendering_draw()
{
    GenericRendering_dynamic();
    GenericRendering_drawVO(voCtxStatic);
    GenericRendering_drawVO(voCtxDynamic);
}