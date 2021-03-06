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
#import "Fret.h"

#import "Fretless.h"
#import "GenericRendering.h"
#include "CoreMIDIRenderer.h"
#include "WidgetTree.h"
#include "RawEngine.h"


// 5MB max per item in iPhone OS clipboard
#define BM_CLIPBOARD_CHUNK_SIZE (5 * 1024 * 1024)


static BOOL isInitialized = FALSE;
static struct PitchHandler_context* phctx;
static struct Fretless_context* fctx;
static struct Fret_context* frctx;

static float scaleFactor = 2;

@interface EAGLView (PrivateMethods)
- (void)createFramebuffer;
- (void)deleteFramebuffer;
@end

@implementation EAGLView

@synthesize eaglcontext;

// You must implement this method
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (void)loadImage:(NSString*)imagePath ofType:(NSString*)imageType wasWidth:(float*)w wasHeight:(float*)h withReRender:(BOOL)reRender toTexture:(unsigned int*)textures
{    
    glEnable(GL_TEXTURE_2D);

    //Cause our call to glTexImage2D to bind to the result in textures[0]
    if(reRender == FALSE)
    {
        glGenTextures(1, textures);
    }
    glBindTexture(GL_TEXTURE_2D, textures[0]);
    
    void* imageData = NULL;
    unsigned int width=0;
    unsigned int height=0;

    NSString *path = [[NSBundle mainBundle] pathForResource:imagePath ofType:imageType];  
    NSData *texData = [[NSData alloc] initWithContentsOfFile:path];
    UIImage *image = [[UIImage alloc] initWithData:texData];
    if (image == nil)
        NSLog(@"Do real error checking here");
    
    width = CGImageGetWidth(image.CGImage);
    height = CGImageGetHeight(image.CGImage);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    imageData = malloc( height * width * 4 );
    
    CGContextRef context = CGBitmapContextCreate( imageData, width, height, 8, 4 * width, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big );
    CGColorSpaceRelease( colorSpace );

    switch(width) {
        case 2: case 4: case 8: case 16: case 32: case 64: case 128: case 256: case 512: case 1024: break;
        default: NSLog(@"width %d is not a power of 2!",width);
    }
    switch(height) {
        case 2: case 4: case 8: case 16: case 32: case 64: case 128: case 256: case 512: case 1024: break;
        default: NSLog(@"height %d is not a power of 2!",height);
    }
    CGContextClearRect( context, CGRectMake( 0, 0, width, height ) );
    
    CGContextSaveGState(context);
    CGAffineTransform flipVertical = CGAffineTransformMake
    (1, 0, 0, -1, 0, height); //set the flip
    CGContextConcatCTM(context, flipVertical); //apply it to context
    
    CGContextTranslateCTM( context, 0, height - height );

    CGContextDrawImage( context, CGRectMake( 0, 0, width, height ), image.CGImage );   
        
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    
    //Put it in the OpenGL world coordinates of ((0,0),(1,1)) with (0,0) in the bottom
    //TODO: may be wrong still
    *w = width;
    *h = height;
    
    CGContextRelease(context);
    
    free(imageData);
    [image release];
    [texData release];
}

- (void)loadString:(NSString*)str wasWidth:(float*)w wasHeight:(float*)h withReRender:(BOOL)reRender toTexture:(unsigned int*)textures
{
    
    glEnable(GL_TEXTURE_2D);
    
    if(reRender == FALSE)
    {
        glGenTextures(1, textures);
    }
    glBindTexture(GL_TEXTURE_2D, textures[0]);
    
    void* imageData = NULL;
    int iPadScale = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 2 : 1;
    unsigned int width=256 * scaleFactor * iPadScale;
    unsigned int height=32 * scaleFactor * iPadScale;
    
 
    // Create the color space.
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Make the image data array.
    imageData = malloc(width * height * 4);
    
    // Make the bitmap context.
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, 4 * width, colorSpace, 
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    // Release the color space.
    CGColorSpaceRelease(colorSpace);
    
    // Clear the background.
    CGContextClearRect(context, CGRectMake(0, 0, width, height));
    
    // Get the font.
    UIFont *font = [UIFont fontWithName:@"Helvetica" size:iPadScale*20*scaleFactor];
    
    
    CGContextSetGrayFillColor(context, 1.0, 1.0);
	UIGraphicsPushContext(context);
    [str drawInRect:CGRectMake(0, 0, width, height) withFont:font lineBreakMode:UILineBreakModeTailTruncation alignment:UITextAlignmentLeft];
	UIGraphicsPopContext();
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    
    CGContextRelease(context);
    
    // Free the image data array.
    free(imageData);
    
    *w = width;
    *h = height;
}

- (void)configureSurface
{
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        PitchHandler_setColCount(phctx,12);
        PitchHandler_setRowCount(phctx,6.5);                
    }
    else
    {
        PitchHandler_setColCount(phctx,5);
        PitchHandler_setRowCount(phctx,3.5);        
    }

    PitchHandler_setNoteDiff(phctx,45); //A is bottom corner
    PitchHandler_setTuneSpeed(phctx,0.25);
    Fretless_setMidiHintChannelSpan(fctx, 16);
    Fretless_setMidiHintChannelBendSemis(fctx,2);
}


void imageRender(void* ctx,char* imagePath,unsigned int* textureName,float* width,float* height,int reRender)
{
    NSString* currentImageStr = [ NSString stringWithUTF8String:imagePath ];
    [(EAGLView*)ctx loadImage:currentImageStr  ofType:@"png" wasWidth:width wasHeight:height withReRender:(BOOL)reRender toTexture:textureName]; 
}


void stringRender(void* ctx,char* str,unsigned int* textureName,float* width,float* height, int reRender)
{
    NSString* currentStr = [ NSString stringWithUTF8String:str ];
    [(EAGLView*)ctx loadString:currentStr  wasWidth:width wasHeight:height withReRender:(BOOL)reRender toTexture:textureName];     
}

float guessScaleFactor()
{
    UIScreen* screen = [UIScreen mainScreen]; 
    int w = screen.currentMode.size.width;
    int h = screen.currentMode.size.height;
    NSLog(@"dimensions: %d %d",w,h);
    if((w==640 && h==960) || (w==2048 && h==1536))
    {
        return 2;
    }
    else 
    {
        return 1;
    }
}

//The EAGL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:.
- (id)initWithCoder:(NSCoder*)coder
{
    self = [super initWithCoder:coder];
    scaleFactor = guessScaleFactor();
    self.contentScaleFactor = scaleFactor;
	if (self) {
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        eaglLayer.contentsScale = self.contentScaleFactor;
        eaglLayer.opaque = TRUE;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                        nil];
    }
    [self setMultipleTouchEnabled:TRUE];
    if(isInitialized==FALSE)
    {        
        //Transforms_clockwiseOrientation();
        frctx = Fret_init(malloc);
        phctx = PitchHandler_init(frctx,malloc,printf,printf);
        fctx = Fretless_init(
            CoreMIDIRenderer_midiPutch,
            CoreMIDIRenderer_midiFlush,
            malloc,free,
            CoreMIDIRenderer_midiFail,
            CoreMIDIRenderer_midiPassed,
            printf
        );
        
        WidgetTree_init(printf,printf);
        GenericRendering_init(phctx,fctx,self,imageRender,stringRender);
        
        GenericTouchHandling_touchesInit(phctx,fctx,printf,printf);
        CoreMIDIRenderer_midiInit(fctx);
        [self configureSurface];
        
        isInitialized=TRUE;
    }
    return self;
}

- (void)dealloc
{
    [self deleteFramebuffer];    
    [eaglcontext release];
    
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
    if (eaglcontext != newContext) {
        [self deleteFramebuffer];
        
        [eaglcontext release];
        eaglcontext = [newContext retain];
        
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)createFramebuffer
{
    if (eaglcontext && !defaultFramebuffer) {
        [EAGLContext setCurrentContext:eaglcontext];
        
        // Create default framebuffer object.
        glGenFramebuffers(1, &defaultFramebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
        
        // Create color render buffer and allocate backing store.
        glGenRenderbuffers(1, &colorRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        [eaglcontext renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &framebufferWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &framebufferHeight);
        
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);
        
        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
            NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
    }
}

- (void)deleteFramebuffer
{
    if (eaglcontext) {
        [EAGLContext setCurrentContext:eaglcontext];
        
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
    if (eaglcontext) {
        [EAGLContext setCurrentContext:eaglcontext];
        
        if (!defaultFramebuffer)
            [self createFramebuffer];
        
        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
        
        glViewport(0, 0, framebufferWidth, framebufferHeight);
    }
}

- (BOOL)presentFramebuffer
{
    BOOL success = FALSE;
    
    if (eaglcontext) {
        [EAGLContext setCurrentContext:eaglcontext];
        
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        
        success = [eaglcontext presentRenderbuffer:GL_RENDERBUFFER];
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


- (void)handleTouchDown:(NSSet*)touches inPhase:(UITouchPhase)expectPhase
{
    NSArray* touchArray = [touches allObjects];
    int touchCount = [touches count];
    for(int t=0; t < touchCount; t++)
    {
        UITouch* touch = [touchArray objectAtIndex:t];
        UITouchPhase phase = [touch phase];
        if(phase == expectPhase)
        {            
            float x = ([touch locationInView:self].x * scaleFactor)/framebufferWidth;
            float y = 1 - ([touch locationInView:self].y * scaleFactor)/framebufferHeight;
            
            //Yes, the forbidden finger area touch is back! (For now anyways)
            float area = 1.0;
            ///*
            id valFloat = [touch valueForKey:@"pathMajorRadius"];
            if(valFloat != nil)
            {
                area = ([valFloat floatValue]-4)/7.0;
            }
             //*/
            //NSLog(@"p %f",PressureSensor_pressure);
            //NSLog(@"a %f",area);
            GenericTouchHandling_touchesDown(touch,phase == UITouchPhaseMoved,x,y,area); 
        }
    }
    GenericTouchHandling_touchesFlush();    
}

- (void)handleTouchUp:(NSSet*)touches inPhase:(UITouchPhase)expectPhase
{
    NSArray* touchArray = [touches allObjects];
    int touchCount = [touchArray count];
    for(int t=0; t < touchCount; t++)
    {
        UITouch* touch = [touchArray objectAtIndex:t];
        UITouchPhase phase = [touch phase];
        if(phase==expectPhase)
        {
            GenericTouchHandling_touchesUp(touch);
        }
    }
    GenericTouchHandling_touchesFlush();    
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self handleTouchDown:touches inPhase:UITouchPhaseBegan];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self handleTouchDown:touches inPhase:UITouchPhaseMoved];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self handleTouchUp:touches inPhase:UITouchPhaseEnded];
}
    
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self handleTouchUp:touches inPhase:UITouchPhaseCancelled];
}

@end
