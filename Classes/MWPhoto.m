//
//  MWPhoto.m
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 17/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import "MWPhoto.h"
#import "UIImage+Decompress.h"

// Private
@interface MWPhoto ()

// Properties
@property () BOOL workingInBackground;

// Private Methods
- (void)doBackgroundWork:(id <MWPhotoDelegate>)delegate;

+ (void)setNetworkActivityIndicatorVisible:(BOOL)setVisible;

@end


// MWPhoto
@implementation MWPhoto

// Properties
@synthesize photoImage, loadingImage, workingInBackground, caption, ID;

#pragma mark Class Methods

+ (MWPhoto *)photoWithImage:(UIImage *)image {
	return [[MWPhoto alloc] initWithImage:image];
}

+ (MWPhoto *)photoWithFilePath:(NSString *)path {
	return [[MWPhoto alloc] initWithFilePath:path];
}

+ (MWPhoto *)photoWithURL:(NSURL *)url {
	return [[MWPhoto alloc] initWithURL:url];
}

#pragma mark NSObject

- (id)initWithImage:(UIImage *)image {
	if ((self = [super init])) {
		self.photoImage = image;
	}
	return self;
}

- (id)initWithFilePath:(NSString *)path {
	if ((self = [super init])) {
		photoPath = [path copy];
	}
	return self;
}

- (id)initWithURL:(NSURL *)url {
	if ((self = [super init])) {
		photoURL = [url copy];
	}
	return self;
}


#pragma mark Photo

+ (void)setNetworkActivityIndicatorVisible:(BOOL)setVisible {
    static NSInteger NumberOfCallsToSetVisible = 0;
    if (setVisible) 
        NumberOfCallsToSetVisible++;
    else 
        NumberOfCallsToSetVisible--;
    
    // The assertion helps to find programmer errors in activity indicator management.
    // Since a negative NumberOfCallsToSetVisible is not a fatal error, 
    // it should probably be removed from production code.
    NSAssert(NumberOfCallsToSetVisible >= 0, @"Network Activity Indicator was asked to hide more often than shown");
    
    // Display the indicator as long as our static counter is > 0.
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:(NumberOfCallsToSetVisible > 0)];
}

// Return whether the image available
// It is available if the UIImage has been loaded and
// loading from file or URL is not required
- (BOOL)isImageAvailable {
	return (self.photoImage != nil);
}

- (BOOL)loadingImageAvailable {
	return (self.loadingImage != nil);    
}

// Return image
- (UIImage *)image {
	return self.photoImage;
}

// Get and return the image from existing image, file path or url
- (UIImage *)obtainImage {
	if (!self.photoImage) {
		
		// Load
		UIImage *img = nil;
		if (photoPath) { 
			
			// Read image from file
			NSError *error = nil;
			NSData *data = [NSData dataWithContentsOfFile:photoPath options:NSDataReadingUncached error:&error];
			if (!error) {
				img = [[UIImage alloc] initWithData:data];
			} else {
				NSLog(@"Photo from file error: %@", error);
			}
			
		} else if (photoURL) { 
            
            SEL networkActivitySelector = NSSelectorFromString(@"setNetworkActivityIndicatorVisible:");
            
            NSInvocation *showInvocation = [NSInvocation invocationWithMethodSignature:[MWPhoto methodSignatureForSelector:networkActivitySelector]];
            NSInvocation *hideInvocation = [NSInvocation invocationWithMethodSignature:[MWPhoto methodSignatureForSelector:networkActivitySelector]];
            
            [showInvocation setSelector:networkActivitySelector];
            [showInvocation setTarget:MWPhoto.class];
            BOOL showInvocationVisible = YES;
            [showInvocation setArgument:&showInvocationVisible atIndex:2];
            
            [hideInvocation setSelector:networkActivitySelector];
            [hideInvocation setTarget:MWPhoto.class];
            BOOL hideInvocationVisible = NO;
            [hideInvocation setArgument:&hideInvocationVisible atIndex:2];
            
            [showInvocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:YES];
            
            // Read image from URL and return
			NSURLRequest *request = [[NSURLRequest alloc] initWithURL:photoURL];
			NSError *error = nil;
			NSURLResponse *response = nil;
            
			NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
			if (data) {
				img = [[UIImage alloc] initWithData:data];
			} else {
				NSLog(@"Photo from URL error: %@", error);
			}
            [hideInvocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:YES];
		}

		// Force the loading and caching of raw image data for speed
		[img decompress];		
		
		// Store
		self.photoImage = img;
		
	}
	return self.photoImage;
}

// Release if we can get it again from path or url
- (void)releasePhoto {
	if (self.photoImage && (photoPath || photoURL)) {
		self.photoImage = nil;
	}
}

// Obtain image in background and notify the browser when it has loaded
- (void)obtainImageInBackgroundAndNotify:(id <MWPhotoDelegate>)delegate {
	if (self.workingInBackground == YES) return; // Already fetching
	self.workingInBackground = YES;
	[self performSelectorInBackground:@selector(doBackgroundWork:) withObject:delegate];
}

// Run on background thread
// Download image and notify delegate
- (void)doBackgroundWork:(id <MWPhotoDelegate>)delegate {
	@autoreleasepool {

	// Load image
		UIImage *img = [self obtainImage];
		
		// Notify delegate of success or fail
		if (img) {
			[(NSObject *)delegate performSelectorOnMainThread:@selector(photoDidFinishLoading:) withObject:self waitUntilDone:NO];
		} else {
			[(NSObject *)delegate performSelectorOnMainThread:@selector(photoDidFailToLoad:) withObject:self waitUntilDone:NO];		
		}

		// Finish
		self.workingInBackground = NO;
	
	}
}

@end
