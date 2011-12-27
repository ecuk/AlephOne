//
//  ButtonControl.h
//  AlephOne
//
//  Created by Robert Fielding on 12/26/11.
//  Copyright 2011 Check Point Software. All rights reserved.
//

struct VertexObjectBuilder;
struct PitchHandler_context;


struct Button_data
{
    struct WidgetTree_rect* rect;
    int val;
    int label;
    int stateCount;
    void (*setter)(void* ctx,int val);
    int (*getter)(void* ctx);
};

void ButtonControl_init(
                        struct VertexObjectBuilder* voCtxDynamicArg,
                        struct PitchHandler_context* phctxArg,
                        int trianglesArg,
                        int trianglestripArg
                        );


struct Button_data* CreateButton(
                                     unsigned int label,
                                     float x1,float y1,float x2,float y2,
                                     void (*setter)(void* ctx,int val), 
                                     int (*getter)(void* ctx),
                                     void (*render)(void* ctx),
                                     int stateCount
                                     );

void Button_render(void* ctx);