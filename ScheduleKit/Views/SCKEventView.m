//
//  SCKEventView.m
//  ScheduleKit
//
//  Created by Guillem on 24/12/14.
//  Copyright (c) 2014 Guillem Servera. All rights reserved.
//

#import "SCKEventView.h"
#import "SCKGridView.h"
#import "SCKEventManager.h"

SCKActionContext SCKActionContextZero() {
    SCKActionContext cx;
    cx.status = SCKDraggingStatusIlde;
    cx.doubleClick = NO;
    cx.oldDuration = 0; cx.newDuration = 0;
    cx.oldRelativeStart = 0.0; cx.newRelativeStart = 0.0;
    cx.internalDelta = 0.0;
    return cx;
}

@implementation SCKEventView

+ (NSColor*)colorForEventType:(SCKEventType)type {
    switch (type) {
        case SCKEventTypeDefault:
            return [NSColor colorWithCalibratedRed:0.60 green:0.90 blue:0.60 alpha:1.0]; break;
        case SCKEventTypeSession:
            return [NSColor colorWithCalibratedRed:1.00 green:0.86 blue:0.29 alpha:1.0]; break;
        case SCKEventTypeSurgery:
            return [NSColor colorWithCalibratedRed:0.66 green:0.82 blue:1.00 alpha:1.0]; break;
        case SCKEventTypeSpecial:
            return [NSColor colorWithCalibratedRed:1.00 green:0.40 blue:0.10 alpha:1.0]; break;
    }
}

+ (NSColor*)strokeColorForEventType:(SCKEventType)type {
    switch (type) {
        case SCKEventTypeDefault:
            return [NSColor colorWithCalibratedRed:0.50 green:0.80 blue:0.50 alpha:1.0]; break;
        case SCKEventTypeSession:
            return [NSColor colorWithCalibratedRed:0.90 green:0.76 blue:0.19 alpha:1.0]; break;
        case SCKEventTypeSurgery:
            return [NSColor colorWithCalibratedRed:0.56 green:0.72 blue:0.90 alpha:1.0]; break;
        case SCKEventTypeSpecial:
            return [NSColor colorWithCalibratedRed:0.90 green:0.30 blue:0.00 alpha:1.0]; break;
    }
}

- (instancetype)initWithFrame:(NSRect)f {
    self = [super initWithFrame:f];
    if (self) {
        _actionContext = SCKActionContextZero();
        _innerLabel = [[SCKTextField alloc] initWithFrame:NSMakeRect(0, 0, f.size.width, f.size.height)];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    SCKGridView *view = (SCKGridView*)self.superview;
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:2.0 yRadius:2.0];
    NSColor *fillColor, *strokeColor;
    
    if (view.selectedEventView != nil && view.selectedEventView != self) {
        // Si hi ha una vista seleccionada i no és aquesta, es colors seran grisos
        fillColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.0];
        strokeColor = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
    } else {
        if (view.colorMode == SCKEventColorModeByEventType) {
            SCKEventType type = [_eventHolder.representedObject eventType];
            fillColor = [self.class colorForEventType:type];
            strokeColor = [self.class strokeColorForEventType:type];
        } else {
            fillColor = _eventHolder.cachedUserLabelColor?:[NSColor colorWithCalibratedRed:0.5 green:0.5 blue:0.5 alpha:1.0];
            double red = fillColor.redComponent, green = fillColor.greenComponent, blue = fillColor.blueComponent;
            strokeColor = [NSColor colorWithCalibratedRed:red-0.1 green:green-0.1 blue:blue-0.1 alpha:1.0];
        }
        if (view.selectedEventView != nil &&
            view.selectedEventView == self &&
            _actionContext.status == SCKDraggingStatusDraggingContent) {
            fillColor = [fillColor colorWithAlphaComponent:0.2];
        }
    }
    [fillColor setFill];
    [strokeColor setStroke];
    
    if (NSMinY(view.contentRect) > [view convertPoint:self.frame.origin fromView:self].y ||
        NSMaxY(view.contentRect) < NSMaxY(self.frame)) {
        CGFloat lineDash[] = {2.0,1.0};
        [[fillColor colorWithAlphaComponent:0.1] setFill];
        [path setLineDash:lineDash count:2 phase:1];
    }
    [path fill];
    [path setLineWidth:(view.selectedEventView == self)? 3.0 : 0.65];
    [path stroke];
}

- (void)prepareForRelayout {
    self.layoutDone = NO;
}

- (void)mouseDown:(NSEvent *)theEvent {
    _actionContext = SCKActionContextZero();
    if ([(SCKGridView*)self.superview selectedEventView] != self) {
        [(SCKGridView*)self.superview setSelectedEventView:self];
    }
    if (theEvent.clickCount == 2) {
        _actionContext.doubleClick = YES;
    }
}

- (void)mouseDragged:(NSEvent *)theEvent {
    SCKGridView *view = (SCKGridView*)self.superview;
    if ((_actionContext.status == SCKDraggingStatusDraggingDuration) ||
        (_actionContext.status == SCKDraggingStatusIlde && [[NSCursor currentCursor] isEqual:[NSCursor resizeUpDownCursor]])) {
        NSPoint loc = [self convertPoint:theEvent.locationInWindow fromView:nil];
        if (_actionContext.status == SCKDraggingStatusIlde) {
            _actionContext.status = SCKDraggingStatusDraggingDuration;
            _actionContext.oldDuration = [self.eventHolder.cachedDuration integerValue];
        }
        NSRect newFrame = self.frame;
        newFrame.size.height = loc.y;
        
        NSDate *sDate = _eventHolder.cachedScheduleDate;
        NSDate *eDate = [view calculateDateForRelativeTimeLocation:[view relativeTimeLocationForPoint:[view convertPoint:theEvent.locationInWindow fromView:nil]]];
        _actionContext.newDuration = (NSInteger)([eDate timeIntervalSinceDate:sDate] / 60.0);
        if (_actionContext.newDuration >= 5) {
            self.frame = newFrame;
        } else {
            _actionContext.newDuration = 5;
        }
        _innerLabel.stringValue = [NSString stringWithFormat:@"%ld min",_actionContext.newDuration];
    } else {
        NSPoint loc = [self convertPoint:theEvent.locationInWindow fromView:nil];
        if (_actionContext.status == SCKDraggingStatusIlde) {
            _actionContext.status = SCKDraggingStatusDraggingContent;
            _actionContext.oldRelativeStart = [_eventHolder cachedRelativeStart];
            _actionContext.oldDateRef = [[_eventHolder cachedScheduleDate] timeIntervalSinceReferenceDate];
            _actionContext.internalDelta = loc.y;
            [view beginDraggingEventView:self];
        }
        NSPoint tPoint = [view convertPoint:theEvent.locationInWindow fromView:nil];
        tPoint.y -= _actionContext.internalDelta;
        
        SCKRelativeTimeLocation newStartLoc = [view relativeTimeLocationForPoint:tPoint];
        if (newStartLoc == SCKRelativeTimeLocationNotFound && (tPoint.y < NSMidY(view.frame))) { // May be too close to an edge. Check if too low
            tPoint.y = NSMinY([view contentRect]);
            newStartLoc = [view relativeTimeLocationForPoint:tPoint];
        }
        if (newStartLoc != SCKRelativeTimeLocationNotFound) {
            tPoint.y += NSHeight(self.frame);
            SCKRelativeTimeLocation newEndLoc =[view relativeTimeLocationForPoint:tPoint];
            if (newEndLoc != SCKRelativeTimeLocationNotFound) {
                _eventHolder.cachedRelativeStart = newStartLoc;
                _eventHolder.cachedRelativeEnd = newEndLoc;
                _eventHolder.cachedScheduleDate = [view calculateDateForRelativeTimeLocation:newStartLoc];
                _actionContext.newRelativeStart = newStartLoc;
                [view relayoutEventView:self animated:NO];
                [view continueDraggingEventView:self];
                [view markContentViewAsNeedingDisplay];
            }
        }
    }
}

- (void)mouseUp:(NSEvent *)theEvent {
    SCKGridView *view = (SCKGridView*)self.superview;
    switch (_actionContext.status) {
        case SCKDraggingStatusDraggingDuration: {
            _innerLabel.stringValue = _eventHolder.cachedTitle?:@"?";
            BOOL changeAllowed = YES;
            if ([view.eventManager.delegate respondsToSelector:@selector(eventManager:shouldChangeLengthOfEvent:fromValue:toValue:)]) {
                changeAllowed = [view.eventManager.delegate eventManager:view.eventManager shouldChangeLengthOfEvent:_eventHolder.representedObject fromValue:_actionContext.oldDuration toValue:_actionContext.newDuration];
            }
            if (changeAllowed) {
                [_eventHolder.representedObject setDuration:@(_actionContext.newDuration)];
                [_eventHolder setCachedDuration:@(_actionContext.newDuration)];
                [_eventHolder recalculateRelativeValues];
                [view triggerRelayoutForAllEventViews];
            } else {
                [view relayoutEventView:self animated:YES];
            }
        } break;
        case SCKDraggingStatusDraggingContent: {
            BOOL changeAllowed = YES;
            NSDate *scheduledDate = [view calculateDateForRelativeTimeLocation:_actionContext.newRelativeStart];
            if ([view.eventManager.delegate respondsToSelector:@selector(eventManager:shouldChangeDateOfEvent:fromValue:toValue:)]) {
                changeAllowed = [view.eventManager.delegate eventManager:view.eventManager shouldChangeDateOfEvent:_eventHolder.representedObject fromValue:[_eventHolder.representedObject scheduledDate] toValue:scheduledDate];
            }
            if (changeAllowed) {
                [_eventHolder.representedObject setScheduledDate:scheduledDate];
                [_eventHolder setCachedScheduleDate:scheduledDate];
                [_eventHolder recalculateRelativeValues];
                [view triggerRelayoutForAllEventViews];
            } else {
                [_eventHolder setCachedScheduleDate:[NSDate dateWithTimeIntervalSinceReferenceDate:_actionContext.oldDateRef]];
                [_eventHolder recalculateRelativeValues];
                [view relayoutEventView:self animated:YES];
            }
            [view endDraggingEventView:self];
        } break;
        case SCKDraggingStatusIlde: {
            if (_actionContext.doubleClick && [view.eventManager.delegate respondsToSelector:@selector(eventManager:didDoubleClickEvent:)]) {
                [view.eventManager.delegate eventManager:view.eventManager didDoubleClickEvent:_eventHolder.representedObject];
            }
        } break;
    }
    _actionContext = SCKActionContextZero();
    self.needsDisplay = YES;
}

- (void)viewDidMoveToWindow {
    if (self.superview != nil) {
        [_eventHolder recalculateRelativeValues];
        _innerLabel.drawsBackground = NO;
        _innerLabel.editable = NO;
        _innerLabel.bezeled = NO;
        _innerLabel.alignment = NSCenterTextAlignment;
        _innerLabel.font = [NSFont systemFontOfSize:12.0];
        [self addSubview:_innerLabel];
        _innerLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _innerLabel.stringValue = _eventHolder.cachedTitle;
        [_innerLabel setContentCompressionResistancePriority:250 forOrientation:NSLayoutConstraintOrientationHorizontal];
        [_innerLabel setContentCompressionResistancePriority:250 forOrientation:NSLayoutConstraintOrientationVertical];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-0-[_innerLabel]-0-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_innerLabel)]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[_innerLabel]-0-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_innerLabel)]];
    }
}

- (BOOL)isFlipped {
    return YES;
}

- (void)resetCursorRects {
    [self addCursorRect:NSMakeRect(0.0, NSHeight(self.frame)-2.0, NSWidth(self.frame), 4.0) cursor:[NSCursor resizeUpDownCursor]];
}

@end