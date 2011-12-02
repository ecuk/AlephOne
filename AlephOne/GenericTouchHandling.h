//
//  GenericTouchHandling.h
//  AlephOne
//
//  Created by Robert Fielding on 12/2/11.
//  Copyright 2011 Check Point Software. All rights reserved.
//

void GenericTouchHandling_touchesInit();
void GenericTouchHandling_touchesUp(void* touch);
void GenericTouchHandling_touchesDown(void* touch,int isMoving,float x,float y);
void GenericTouchHandling_touchesFlush();