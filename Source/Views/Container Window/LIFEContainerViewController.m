//
//  LIFEContainerViewController.m
//  Copyright (C) 2018 Buglife, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//

#import "LIFEContainerViewController.h"
#import "LIFEAlertAnimator.h"
#import "LIFEAlertController.h"
#import "LIFEContainerAlertToImageEditorAnimator.h"
#import "LIFEContainerModalDismissAnimator.h"
#import "LIFEImageEditorViewController.h"
#import "LIFEContainerTransitionContext.h"
#import "LIFENavigationController.h"
#import "LIFEWindowBlindsAnimator.h"
#import "LIFEMacros.h"
#import "LIFEToastController.h"

@interface LIFEPassThroughView : UIView
@end

@interface LIFEContainerViewController ()

@property (nonnull, nonatomic) LIFEPassThroughView *passThroughView;

@end

@implementation LIFEContainerViewController

- (void)loadView
{
    self.view = [[LIFEPassThroughView alloc] init];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if ([self _visibleViewControllerCapturesStatusBarAppearance]) {
        return [self.visibleViewController preferredStatusBarStyle];
    }
    
    return _statusBarStyle;
}

- (BOOL)prefersStatusBarHidden
{
    if ([self _visibleViewControllerCapturesStatusBarAppearance]) {
        return [self.visibleViewController prefersStatusBarHidden];
    }
    
    return _statusBarHidden;
}

// If you'd like your child view controller to set the status
// bar appearance, implement -modalPresentationCapturesStatusBarAppearance
// in that child view controller, along with -preferredStatusBarStyle
// and -prefersStatusBarHidden. Otherwise, LIFEContainerViewController
// will simply use its own properties, which should match the host application
// (giving the appearance of being "transparent").
- (BOOL)_visibleViewControllerCapturesStatusBarAppearance
{
    if (self.visibleViewController) {
        return [self.visibleViewController modalPresentationCapturesStatusBarAppearance];
    }
    
    return NO;
}

- (nullable UIViewController *)visibleViewController
{
    return self.childViewControllers.lastObject;
}

// This will attempt to animate in the new child view controller,
// in whatever way makes sense w/ respect to the existing child view
// controller (if any).
- (void)life_setChildViewController:(UIViewController *)childViewController animated:(BOOL)animated completion:(void (^)(void))completion
{
    UIViewController *visibleViewController = self.visibleViewController;
    
    if ([visibleViewController isKindOfClass:[LIFENavigationController class]]) {
        let navVC = (LIFENavigationController *)visibleViewController;
        [navVC setViewControllers:@[childViewController] animated:animated];
        return;
    }
    
    if (visibleViewController == nil) {
        visibleViewController = self;
    }
    
    UIView *toView = childViewController.view;
    toView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    toView.frame = self.view.bounds;
    [self addChildViewController:childViewController];
    
    id<UIViewControllerAnimatedTransitioning> animator = [self _animatorFromViewController:visibleViewController toViewController:childViewController];
    
    if (animator == nil) {
        [self.view addSubview:toView];
        [childViewController didMoveToParentViewController:self];
        return;
    }
    
    UIView *containerView = self.view;
    LIFEContainerTransitionContext *transitionContext = [[LIFEContainerTransitionContext alloc] initWithFromViewController:visibleViewController toViewController:childViewController containerView:containerView];
    transitionContext.animated = YES;
    transitionContext.interactive = NO;
    transitionContext.completionBlock = ^(BOOL didComplete) {
        if (visibleViewController != self) {
            [visibleViewController.view removeFromSuperview];
            [visibleViewController removeFromParentViewController];
        }
        
        [childViewController didMoveToParentViewController:self];
        
        if ([animator respondsToSelector:@selector(animationEnded:)]) {
            [animator animationEnded:didComplete];
        }
        
        if (completion) {
            completion();
        }
    };
    
    [animator animateTransition:transitionContext];
}

- (void)life_dismissEverythingAnimated:(BOOL)flag completion:(void (^ __nullable)(void))completion
{
    UIViewController *visibleViewController = self.childViewControllers.lastObject;
    id<UIViewControllerAnimatedTransitioning> animator = [self _animatorToDismissViewController:visibleViewController];
    
    if (animator) {
        LIFEContainerTransitionContext *transitionContext = [[LIFEContainerTransitionContext alloc] initWithFromViewController:visibleViewController toViewController:self containerView:self.view];
        transitionContext.animated = YES;
        transitionContext.interactive = NO;
        transitionContext.completionBlock = ^(BOOL didComplete) {
            [visibleViewController.view removeFromSuperview];
            [visibleViewController removeFromParentViewController];
            
            if ([animator respondsToSelector:@selector(animationEnded:)]) {
                [animator animationEnded:didComplete];
            }
            
            if (completion) {
                completion();
            }
        };
        
        [visibleViewController willMoveToParentViewController:nil];
        [animator animateTransition:transitionContext];
    } else {
        if (completion) {
            completion();
        }
    }
}

- (void)dismissWithWindowBlindsAnimation:(BOOL)animated showToast:(BOOL)showToast completion:(void (^ __nullable)(void))completion
{
    let fromVc = self.visibleViewController;
    LIFEToastController *toastViewController;
    
    if (showToast) {
        toastViewController = [[LIFEToastController alloc] init];
        toastViewController.dismissHandler = completion;
        UIView *toView = toastViewController.view;
        toView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        toView.frame = self.view.bounds;
        [self addChildViewController:toastViewController];
    }
    
    id<UIViewControllerAnimatedTransitioning> animator = [[LIFEWindowBlindsAnimator alloc] init];
    
    UIView *containerView = self.view;
    LIFEContainerTransitionContext *transitionContext = [[LIFEContainerTransitionContext alloc] initWithFromViewController:fromVc toViewController:toastViewController containerView:containerView];
    transitionContext.animated = YES;
    transitionContext.interactive = NO;
    transitionContext.completionBlock = ^(BOOL didComplete) {
        if (fromVc != self) {
            [fromVc.view removeFromSuperview];
            [fromVc removeFromParentViewController];
        }
        
        [toastViewController didMoveToParentViewController:self];
        
        if ([animator respondsToSelector:@selector(animationEnded:)]) {
            [animator animationEnded:didComplete];
        }
        
        if (!showToast) {
            completion();
        }
    };
    
    [animator animateTransition:transitionContext];
}

- (nullable id<UIViewControllerAnimatedTransitioning>)_animatorFromViewController:(nullable UIViewController *)fromVC toViewController:(nonnull UIViewController *)toVC
{
    if ([toVC isKindOfClass:[LIFEAlertController class]]) {
        return [LIFEAlertAnimator presentationAnimator];
    }
    
    if ([fromVC isKindOfClass:[LIFEAlertController class]] && [toVC isKindOfClass:[LIFENavigationController class]]) {
        let nav = (LIFENavigationController *)toVC;
        
        if ([nav.visibleViewController isKindOfClass:[LIFEImageEditorViewController class]]) {
            return [[LIFEContainerAlertToImageEditorAnimator alloc] init];
        }
    }
    
    return nil;
}

- (nullable id<UIViewControllerAnimatedTransitioning>)_animatorToDismissViewController:(UIViewController *)viewController
{
    if ([viewController isKindOfClass:[LIFEAlertController class]]) {
        return [LIFEAlertAnimator dismissAnimator];
    }
    
    return [[LIFEContainerModalDismissAnimator alloc] init];
}

@end

@implementation LIFEPassThroughView

// Unless a touch event hits an actual subview,
// let it pass through to whatever's behind. This allows things like
// LIFEToastView to remain onscreen while allowing the host app to
// receive touches.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *hitView = [super hitTest:point withEvent:event];
    
    if (hitView == self) {
        return nil;
    }
    
    return hitView;
}

@end
