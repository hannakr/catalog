//
//  ProjectViewController.m
//  Catalog
//

#import "ProjectViewController.h"
#import "CachedImageLoader.h"
#import <QuartzCore/QuartzCore.h>

typedef enum {
    TransitionStateNone,
    TransitionStatePrepPrev,
    TransitionStatePrepNext,
    TransitionStateDoingPrev,
    TransitionStateDoingNext,
    TransitionStateResetting
} TransitionState;

@interface ProjectViewController ()

@property (strong, nonatomic) IBOutlet UIScrollView* scrollView;
@property (strong, nonatomic) IBOutlet UIButton* backButton;
@property (strong, nonatomic) IBOutlet UIImageView* pageControl;
@property (strong, nonatomic) IBOutlet UIView* detailContainer;

@property (strong, nonatomic) IBOutlet UIImageView* curtainImage;
@property (strong, nonatomic) IBOutlet UIImageView* curtainBackground;
@property (strong, nonatomic) IBOutlet UIView* curtain;
@property (strong, nonatomic) UIImageView* curtainFade;
@property (strong, nonatomic) UIImage* curtainFadeImage;
@property (nonatomic) BOOL curtainIsVideo;

@property (nonatomic) TransitionState transitionState;

@property (strong, nonatomic) NSArray* projects;
@property (strong, nonatomic) NSDictionary* project;
@property (nonatomic) int currentIndex;

@property (nonatomic) int numPages;
@property (nonatomic) int currentPage;

@property (nonatomic) BOOL haveShowHidePositions;
@property (nonatomic) BOOL showingDetails;
@property (nonatomic) CGRect showDetailsFrame;
@property (nonatomic) CGRect hideDetailsFrame;
@property (nonatomic) CGRect showDetailsBackFrame;
@property (nonatomic) CGRect hideDetailsBackFrame;

@property (strong, nonatomic) IBOutlet UILabel* name;
@property (strong, nonatomic) IBOutlet UILabel* author;
@property (strong, nonatomic) IBOutlet UILabel* medium;
@property (strong, nonatomic) IBOutlet UILabel* measurements;
@property (strong, nonatomic) IBOutlet UILabel* website;

@property (strong, nonatomic) CachedImageLoader* imageLoader;

@property (strong, nonatomic) UIPanGestureRecognizer* panRecognizer;
@property (nonatomic) float panStartPosition;

@end

@implementation ProjectViewController

+ (UIImage*)imageWithView:(UIView *)view {
	UIGraphicsBeginImageContext(view.frame.size);
	[view.layer renderInContext:UIGraphicsGetCurrentContext()];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

-(id)initWithProjects:(NSArray*)projects startIndex:(int)index {
    self = [super init];
    if (self) {
        self.projects = projects;
        self.currentIndex = index;
        self.project = projects[index];
        self.imageLoader = [CachedImageLoader new];
    }
    return self;
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.scrollView.delegate = self;
        
    self.showingDetails = YES;

    // Load in the images for the initially selected project
    [self setupCurrentProjectStartingAtEnd:NO];

    // Build up view for curtain (the thing that gets pulled over when tranitioning to the next project, with the key image
    // for the project to transition to on it)
    self.curtainBackground = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 1024, 768)];
    self.curtainBackground.image = [UIImage imageNamed:@"Background.png"];
    self.curtainBackground.contentMode = UIViewContentModeScaleAspectFit;
    self.curtainBackground.opaque = NO;
    
    self.curtainImage = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 1024, 768)];
    self.curtainImage.backgroundColor = [UIColor clearColor];
    self.curtainImage.contentMode = UIViewContentModeScaleAspectFit;
    self.curtainImage.opaque = NO;
    
    self.curtain = [[UIView alloc] initWithFrame:CGRectMake(1024, 0, 1024, 768)];
    self.curtain.opaque = NO;
    [self.curtain addSubview:self.curtainBackground];
    [self.curtain addSubview:self.curtainImage];

    [self.view addSubview:self.curtain];

    // Pan recognizer to catch the getures at the edge of the scroll view to the the curtain pull
    self.panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleHorizontalDrag:)];
    self.panRecognizer.cancelsTouchesInView = NO;
    self.panRecognizer.delaysTouchesBegan = YES;
    self.panRecognizer.delegate = self;
    
    [self.scrollView addGestureRecognizer:self.panRecognizer];
    
    self.scrollView.bounces = YES;
    self.scrollView.alwaysBounceHorizontal = YES;
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if(!self.haveShowHidePositions) {
        self.haveShowHidePositions = YES;
        
        // Figure out the two possible frames for the detail view and the back button (for animated show/hide of the details)
        self.showDetailsFrame = self.detailContainer.frame;
        self.showDetailsBackFrame = self.backButton.frame;
        
        CGRect hide = self.showDetailsFrame;
        hide.origin.y = -self.showDetailsFrame.size.height;
        self.hideDetailsFrame = hide;
        
        hide = self.showDetailsBackFrame;
        hide.origin.y = hide.origin.y - self.showDetailsFrame.size.height + 20;
        self.hideDetailsBackFrame = hide;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self.imageLoader flush];
}

-(NSURL*)startImageForIndex:(int)index {
    if((index < 0) || (index >= self.projects.count)) {
        return nil;
    }
    
    NSDictionary* project = self.projects[index];
    NSArray* assets = project[@"assets"];
    
    if(assets.count == 0) {
        return nil;
    }
    
    for(NSDictionary* asset in assets) {
        if([asset[@"type"] isEqualToString:@"image"]) {
            return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", SERVER_ADDRESS, asset[@"url"]]];
        }
    }
    
    return nil;
}

-(BOOL)endImageIsVideoForIndex:(int)index {
    if((index < 0) || (index >= self.projects.count)) {
        return NO;
    }
    
    NSDictionary* project = self.projects[index];
    NSArray* assets = project[@"assets"];
    
    if(assets.count == 0) {
        return NO;
    }
    
    NSDictionary* asset = assets[0];
    
    if([asset[@"type"] isEqualToString:@"video"]) {
        return YES;
    }
    
    return NO;
}

-(NSURL*)endImageForIndex:(int)index {
    if((index < 0) || (index >= self.projects.count)) {
        return nil;
    }
    
    NSDictionary* project = self.projects[index];
    NSArray* assets = project[@"assets"];
    
    if(assets.count == 0) {
        return nil;
    }
    
    NSDictionary* asset = assets[0];
    
    if([asset[@"type"] isEqualToString:@"video"]) {
        return nil;
    }
    
    asset = [assets lastObject];

    if([asset[@"type"] isEqualToString:@"image"]) {
        return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", SERVER_ADDRESS, asset[@"url"]]];
    }
    
    return nil;
}

-(void)setupCurrentProjectStartingAtEnd:(BOOL)end {
    self.numPages = [self.project[@"assets"] count];
    self.scrollView.contentSize = CGSizeMake(1024 * self.numPages, 768);
    
    int page = 0;
    
    NSDictionary* video;
    
    for(NSDictionary* asset in self.project[@"assets"]) {
        if([asset[@"type"] isEqualToString:@"image"]) {
            NSString* imageURL = [NSString stringWithFormat:@"%@%@", SERVER_ADDRESS, asset[@"url"]];
            
            UIImageView* imageView = [[UIImageView alloc] initWithFrame:CGRectMake(1024 * page, 0, 1024, 768)];
            imageView.contentMode = UIViewContentModeScaleAspectFit;
            UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            [imageView addSubview:spinner];
            spinner.center = CGPointMake(1024 / 2, 768 / 2);
            [spinner startAnimating];
            
            
            [self.imageLoader loadImage:[NSURL URLWithString:imageURL] onLoad:^(UIImage* image, BOOL wasCached) {
                [spinner removeFromSuperview];
                imageView.image = image;
            }];
            
            [self.scrollView addSubview:imageView];
            
            page++;
        }
        else {
            video = asset;
        }
    }
    
    if (video) {
        static int inset = 0 ;
        UIWebView* webView = [[UIWebView alloc] initWithFrame:CGRectMake((1024 * page) + inset, 20 + inset, 1024 - (inset * 2), 768 - (inset * 2))];
        webView.scrollView.scrollEnabled = NO;
        
        NSString* videoId = [[((NSString*)video[@"url"]) componentsSeparatedByString:@"/"] lastObject];
        [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://player.vimeo.com/video/%@", videoId]]]];
        webView.delegate = self;
        [self.scrollView addSubview:webView];
    }
        
    self.name.text = self.project[@"title"];
    self.author.text = self.project[@"author"];
    self.medium.text = self.project[@"medium"];
    self.measurements.text = self.project[@"measurements"];
    self.website.text = self.project[@"website"];
    
    self.transitionState = TransitionStateNone;
    
    int newPage = end ? (self.numPages - 1) : 0;
    [self.scrollView setContentOffset:CGPointMake(1024 * newPage, 0.0f) animated:NO];
    [self setPage:newPage];

    self.curtainIsVideo = video && end;
    
    // cache next and previous key images, so that they will be ready if we need them for the curtain
    [self.imageLoader precacheImage:[self startImageForIndex:self.currentIndex + 1]];
    [self.imageLoader precacheImage:[self endImageForIndex:self.currentIndex - 1]];
    
    [self showDetails:YES];
}

-(IBAction)dismiss:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)setPage:(int)newPage {
    self.pageControl.hidden = (self.numPages == 1);
    self.currentPage = newPage;
    
    NSString* filename = [NSString stringWithFormat:@"page%d%d.png",self.currentPage+1, self.numPages];
    self.pageControl.image = [UIImage imageNamed:filename];
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // Check if current page has changed, to update page control, and hide details view if needed
    int newPage = floor((float)(scrollView.contentOffset.x + 512) / 1024.0f);
    if (newPage != self.currentPage) {
        [self setPage:newPage];
        [self showDetails:NO];
    }

    if(((self.transitionState != TransitionStateNone) && (self.currentPage == 0)) ||
      ((self.scrollView.contentOffset.x < 0) && (self.currentIndex > 0))) {
        [self.scrollView setContentOffset:CGPointMake(0.0f, 0.0f) animated:NO];
    }

    if(((self.transitionState != TransitionStateNone) && (self.currentPage == (self.numPages -1))) ||
      ((self.scrollView.contentOffset.x > (self.scrollView.contentSize.width - self.scrollView.frame.size.width)) && (self.currentIndex < (self.projects.count - 1)))) {
        [self.scrollView setContentOffset:CGPointMake(self.scrollView.contentSize.width - self.scrollView.frame.size.width,0.0f) animated:NO];
    }
}

-(void)fadeOutCurtain {
    if(!self.curtainFadeImage) {
        return;
    }
    
    self.curtainFadeImage = nil;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.curtainFade.alpha = 0.0f;
    } completion:^(BOOL finished) {
        self.curtainFade.hidden = YES;
    }];
}

- (void)doTransitionWithVelocity:(float)velocity {
    if((self.transitionState == TransitionStatePrepNext) || (self.transitionState == TransitionStatePrepPrev)) {
        CGRect frame = self.curtain.frame;
        float end = frame.origin.x + velocity / 3;

        // Figure out whihc transition to do, or if we need to reset if we haven't pulled far enough
        if(self.transitionState == TransitionStatePrepNext) {
            if(end < 512) {
                self.transitionState = TransitionStateDoingNext;
                frame.origin.x = 0;
            }
            else {
                self.transitionState = TransitionStateResetting;
                frame.origin.x = 1024;
            }
        }
        if(self.transitionState == TransitionStatePrepPrev) {
            if(end > -512) {
                self.transitionState = TransitionStateDoingPrev;
                frame.origin.x = 0;
            }
            else {
                self.transitionState = TransitionStateResetting;
                frame.origin.x = -1024;
            }
        }
    
        // Run the animation to slide on the curtain the rest of the way
        [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.curtain.frame = frame;
        } completion:^(BOOL finished) {
            if(self.transitionState != TransitionStateResetting) {
                // Load the next project into the scroll view
                if (self.transitionState == TransitionStateDoingNext) {
                    self.currentIndex++;
                }
                else {
                    self.currentIndex--;
                }
                
                self.project = self.projects[self.currentIndex];
                
                for(UIView* view in self.scrollView.subviews) {
                    [view removeFromSuperview];
                }
                
                [self setupCurrentProjectStartingAtEnd:(self.transitionState == TransitionStateDoingPrev)];

                // Run the fade, need to render down the view, or we will fade both background image and
                // key image, and it'll look funny
                if(!self.curtainFade) {
                    self.curtainFade = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 1024, 768)];
                    [self.view addSubview:self.curtainFade];
                }

                self.curtainFadeImage = [ProjectViewController imageWithView:self.curtain];
                self.curtainFade.image = self.curtainFadeImage;
                self.curtainFade.hidden = NO;
                self.curtainFade.alpha = 1.0f;

                self.curtain.frame = CGRectMake(1024, 0, 1024, 768);
                self.curtainImage.image = nil;
                
                if(self.curtainIsVideo) {
                    double delayInSeconds = 2.0;
                    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                        [self fadeOutCurtain];
                    });
                }
                else {
                    [self fadeOutCurtain];
                }
            }
            
            self.transitionState = TransitionStateNone;
        }];
    }
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)handleHorizontalDrag:(UIGestureRecognizer*)gesture {
    float position = [gesture locationInView:self.scrollView.superview].x;

    if((gesture.state == UIGestureRecognizerStateEnded) || (gesture.state == UIGestureRecognizerStateCancelled)) {
        [self doTransitionWithVelocity:[(UIPanGestureRecognizer*)gesture velocityInView:self.view].x];
    }
    else if ((gesture.state == UIGestureRecognizerStateBegan) || (gesture.state == UIGestureRecognizerStateChanged)){
        if(gesture.state == UIGestureRecognizerStateBegan) {
            self.panStartPosition = position;
        }
        
        if((self.transitionState != TransitionStateDoingNext) && (self.transitionState != TransitionStateDoingPrev) && (self.transitionState != TransitionStateResetting)) {
            BOOL pulling = NO;
            
            float offset = self.panStartPosition - position;
            
            if((offset > 0) && ((self.transitionState == TransitionStatePrepNext) || (((self.scrollView.contentOffset.x + self.scrollView.frame.size.width) >= self.scrollView.contentSize.width) && (self.currentIndex < (self.projects.count - 1))))) {
                CGRect frame = self.curtain.frame;
                frame.origin.x = 1024.0f - offset;
                
                if(self.curtainImage.image == nil) {
                    self.curtainImage.image = [self.imageLoader cachedImageForURL:[self startImageForIndex:self.currentIndex + 1]];
                }
                self.curtain.frame = frame;
                self.transitionState = TransitionStatePrepNext;
                
                pulling = YES;
            }
            
            if((offset < 0) && ((self.transitionState == TransitionStatePrepPrev) || ((self.scrollView.contentOffset.x <= 0) && (self.currentIndex > 0)) )) {
                CGRect frame = self.curtain.frame;
                frame.origin.x = -1024.0f - offset;
                
                if(self.curtainImage.image == nil) {
                    if([self endImageIsVideoForIndex:self.currentIndex - 1]) {
                        self.curtainImage.image = [UIImage imageNamed:@"video-curtain.png"];
                    }
                    else {
                        self.curtainImage.image = [self.imageLoader cachedImageForURL:[self endImageForIndex:self.currentIndex - 1]];
                    }
                }
                self.curtain.frame = frame;
                self.transitionState = TransitionStatePrepPrev;
                
                pulling = YES;
            }
            
            if (!pulling) {
                if(offset == 0) {
                    self.transitionState = TransitionStateNone;
                }
                self.curtainImage.image = nil;
                self.curtain.frame = CGRectMake(1024, 0, 1024, 768);
            }
        }
    }
}

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if(navigationType == UIWebViewNavigationTypeOther) {
        // Initial load, let it go
        return YES;
    }
    else
    {
        // Anything else, send it to Safari
        [[UIApplication sharedApplication] openURL:request.URL];
    }
    return NO;
}

-(void)webViewDidFinishLoad:(UIWebView *)webView {
    if(self.curtainFade && self.curtainIsVideo) {
        [self fadeOutCurtain];
    }
}

-(void)showDetails:(BOOL)show {
    if(show == self.showingDetails) {
        return;
    }
    
    // Figure out if we are showing or hiding
    CGRect destDetails = show ? self.showDetailsFrame : self.hideDetailsFrame;
    CGRect destBack = show ? self.showDetailsBackFrame : self.hideDetailsBackFrame;
    float destAlpha = show ? 1.0f : 0.0f;
    
    self.showingDetails = show;
        
    // Run show/hide animation
    [UIView animateWithDuration:0.5 animations:^{
        self.backButton.frame = destBack;
        self.detailContainer.frame = destDetails;
        self.detailContainer.alpha = destAlpha;
    }];

}
-(IBAction)detailButtonPressed:(id)sender {
    [self showDetails:!self.showingDetails];
}

-(IBAction)websiteClicked:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.project[@"website"]]];
}

@end
