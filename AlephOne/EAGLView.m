//
//  EAGLView.m
//  OpenGLES_iPhone
//
//  Created by mmalc Crawford on 11/18/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "EAGLView.h"
#import "GenericTouchHandling.h"
#import "PitchHandler.h"
#import "Fretless.h"
#import "Transforms.h"
#import "GenericRendering.h"

BOOL isInitialized = FALSE;

@interface EAGLView (PrivateMethods)
- (void)createFramebuffer;
- (void)deleteFramebuffer;
@end

@implementation EAGLView

@synthesize context;

// You must implement this method
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

//The EAGL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:.
- (id)initWithCoder:(NSCoder*)coder
{
    self = [super initWithCoder:coder];
	if (self) {
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        
        eaglLayer.opaque = TRUE;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                        nil];
    }
    [self setMultipleTouchEnabled:TRUE];
    if(isInitialized==FALSE)
    {
        Transforms_clockwiseOrientation();
        
        //PitchHandler_setNoteDiff(48);
        
        PitchHandler_setTuneInterval(0,5);
        PitchHandler_setTuneInterval(1,5+5);
        PitchHandler_setTuneInterval(2,5+5+5);
        
        //0.0 is C
        PitchHandler_clearFrets();
        PitchHandler_placeFret(0.0);
        PitchHandler_placeFret(1.0);
        PitchHandler_placeFret(2.0);
        PitchHandler_placeFret(3.0);
        PitchHandler_placeFret(3.5);
        PitchHandler_placeFret(4.0);
        PitchHandler_placeFret(5.0);
        PitchHandler_placeFret(6.0);
        PitchHandler_placeFret(7.0);
        PitchHandler_placeFret(8.0);
        PitchHandler_placeFret(8.5);
        PitchHandler_placeFret(9.0);
        PitchHandler_placeFret(10.0);
        PitchHandler_placeFret(10.5);
        PitchHandler_placeFret(11.0);
        
        PitchHandler_setColCount(5);
        PitchHandler_setRowCount(3);
        PitchHandler_setNoteDiff(45); //make B the bottom corner.. C is 0 in MIDI
        //PitchHandler_setTuneInterval(7);
        PitchHandler_setTuneSpeed(0.25);
        
        GenericTouchHandling_touchesInit();
        GenericTouchHandling_setChorusLevel(0.25);
        
        isInitialized=TRUE;
    }
    return self;
}

- (void)dealloc
{
    [self deleteFramebuffer];    
    [context release];
    
    [super dealloc];
}

- (void)setup:(EAGLContext*)newContext
{
    [self setContext:newContext];
    [self setFramebuffer];    
    
    GenericRendering_setup();    
    
}

- (void)drawFrame
{
    [self setFramebuffer];
    [self tick];
    
    GenericRendering_camera();
    GenericRendering_draw();
    
    [self presentFramebuffer];
}

- (void)setContext:(EAGLContext *)newContext
{
    if (context != newContext) {
        [self deleteFramebuffer];
        
        [context release];
        context = [newContext retain];
        
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)createFramebuffer
{
    if (context && !defaultFramebuffer) {
        [EAGLContext setCurrentContext:context];
        
        // Create default framebuffer object.
        glGenFramebuffers(1, &defaultFramebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
        
        // Create color render buffer and allocate backing store.
        glGenRenderbuffers(1, &colorRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &framebufferWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &framebufferHeight);
        
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);
        
        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
            NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
    }
}

- (void)deleteFramebuffer
{
    if (context) {
        [EAGLContext setCurrentContext:context];
        
        if (defaultFramebuffer) {
            glDeleteFramebuffers(1, &defaultFramebuffer);
            defaultFramebuffer = 0;
        }
        
        if (colorRenderbuffer) {
            glDeleteRenderbuffers(1, &colorRenderbuffer);
            colorRenderbuffer = 0;
        }
    }
}

- (void)setFramebuffer
{
    if (context) {
        [EAGLContext setCurrentContext:context];
        
        if (!defaultFramebuffer)
            [self createFramebuffer];
        
        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
        
        glViewport(0, 0, framebufferWidth, framebufferHeight);
    }
}

- (BOOL)presentFramebuffer
{
    BOOL success = FALSE;
    
    if (context) {
        [EAGLContext setCurrentContext:context];
        
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        
        success = [context presentRenderbuffer:GL_RENDERBUFFER];
    }
    
    return success;
}

- (void)layoutSubviews
{
    // The framebuffer will be re-created at the beginning of the next setFramebuffer method call.
    [self deleteFramebuffer];
}

- (void)tick
{
    tickClock++;
    tickClock%=4;
    if(tickClock==0)
    {
        GenericTouchHandling_tick();                    
    }
}


- (void)handleTouchDown:(UITouch*)touch inPhase:(UITouchPhase) phase
{
    float x = [touch locationInView:self].x/framebufferWidth;
    float y = 1 - [touch locationInView:self].y/framebufferHeight;
    Transforms_translate(&x, &y);
    GenericTouchHandling_touchesDown(touch,phase == UITouchPhaseMoved,x,y);    
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    NSArray* touchArray = [touches allObjects];
    int touchCount = [touches count];
    for(int t=0; t < touchCount; t++)
    {
        UITouch* touch = [touchArray objectAtIndex:t];
        UITouchPhase phase = [touch phase];
        if(phase == UITouchPhaseBegan)
        {            
            [self handleTouchDown:touch inPhase: phase];
        }
    }
    GenericTouchHandling_touchesFlush();
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    NSArray* touchArray = [touches allObjects];
    int touchCount = [touches count];
    for(int t=0; t < touchCount; t++)
    {
        UITouch* touch = [touchArray objectAtIndex:t];
        UITouchPhase phase = [touch phase];
        if(phase == UITouchPhaseMoved)
        {
            [self handleTouchDown:touch inPhase: phase];
        }
    }
    GenericTouchHandling_touchesFlush();
}



- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSArray* touchArray = [touches allObjects];
    int touchCount = [touchArray count];
    for(int t=0; t < touchCount; t++)
    {
        UITouch* touch = [touchArray objectAtIndex:t];
        UITouchPhase phase = [touch phase];
        if(phase==UITouchPhaseEnded)
        {
            GenericTouchHandling_touchesUp(touch);
        }
    }
    GenericTouchHandling_touchesFlush();
}
    
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSArray* touchArray = [touches allObjects];
    int touchCount = [touchArray count];
    for(int t=0; t < touchCount; t++)
    {
        UITouch* touch = [touchArray objectAtIndex:t];
        UITouchPhase phase = [touch phase];
        if(phase==UITouchPhaseCancelled)
        {
            GenericTouchHandling_touchesUp(touch);
        }
    }
    GenericTouchHandling_touchesFlush();
}

@end
