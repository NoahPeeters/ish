//
//  ViewController.m
//  iSH
//
//  Created by Theodore Dubois on 10/17/17.
//

#import "TerminalViewController.h"
#import "AppDelegate.h"
#import "TerminalView.h"
#import "BarButton.h"
#import "ArrowBarButton.h"
#import "UserPreferences.h"
#import "AboutViewController.h"
#import "ExternalFolder.h"
#include "fs/devices.h"
#include "kernel/fs.h"

@interface TerminalViewController () <UIGestureRecognizerDelegate, UIDocumentPickerDelegate>

@property UITapGestureRecognizer *tapRecognizer;
@property (weak, nonatomic) IBOutlet TerminalView *termView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomConstraint;

@property (weak, nonatomic) IBOutlet UIButton *tabKey;
@property (weak, nonatomic) IBOutlet UIButton *controlKey;
@property (weak, nonatomic) IBOutlet UIButton *escapeKey;
@property (strong, nonatomic) IBOutletCollection(id) NSArray *barButtons;
@property (strong, nonatomic) IBOutletCollection(id) NSArray *barControls;

@property (weak, nonatomic) IBOutlet UIInputView *barView;
@property (weak, nonatomic) IBOutlet UIStackView *bar;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barBottom;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barLeading;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barTrailing;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barButtonWidth;

@property (weak, nonatomic) IBOutlet UIButton *addMountButton;
@property (weak, nonatomic) IBOutlet UIButton *pasteButton;
@property (weak, nonatomic) IBOutlet UIButton *hideKeyboardButton;

@end

@implementation TerminalViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.terminal = [Terminal terminalWithType:TTY_CONSOLE_MAJOR number:7];
    [self.termView becomeFirstResponder];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(keyboardDidSomething:)
                   name:UIKeyboardWillShowNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(keyboardDidSomething:)
                   name:UIKeyboardWillHideNotification
                 object:nil];

    [self _updateStyleFromPreferences:NO];
    [[UserPreferences shared] addObserver:self forKeyPath:@"theme" options:NSKeyValueObservingOptionNew context:nil];
    
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        [self.bar removeArrangedSubview:self.hideKeyboardButton];
        [self.hideKeyboardButton removeFromSuperview];
    }
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        self.barView.frame = CGRectMake(0, 0, 100, 48);
    } else {
        self.barView.frame = CGRectMake(0, 0, 100, 55);
    }
    
    // SF Symbols is cool
    if (@available(iOS 13, *)) {
        [self.addMountButton setImage:[UIImage systemImageNamed:@"folder.badge.plus"] forState:UIControlStateNormal];
        [self.pasteButton setImage:[UIImage systemImageNamed:@"doc.on.clipboard"] forState:UIControlStateNormal];
        [self.hideKeyboardButton setImage:[UIImage systemImageNamed:@"keyboard.chevron.compact.down"] forState:UIControlStateNormal];
        
        [self.tabKey setTitle:nil forState:UIControlStateNormal];
        [self.tabKey setImage:[UIImage systemImageNamed:@"arrow.right.to.line.alt"] forState:UIControlStateNormal];
        [self.controlKey setTitle:nil forState:UIControlStateNormal];
        [self.controlKey setImage:[UIImage systemImageNamed:@"control"] forState:UIControlStateNormal];
        [self.escapeKey setTitle:nil forState:UIControlStateNormal];
        [self.escapeKey setImage:[UIImage systemImageNamed:@"escape"] forState:UIControlStateNormal];
    }
}

- (void)dealloc {
    @try {
        [[UserPreferences shared] removeObserver:self forKeyPath:@"theme"];
    } @catch (NSException * __unused exception) {}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == [UserPreferences shared]) {
        [self _updateStyleFromPreferences:YES];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)_updateStyleFromPreferences:(BOOL)animated {
    NSTimeInterval duration = animated ? 0.1 : 0;
    [UIView animateWithDuration:duration animations:^{
        self.view.backgroundColor = UserPreferences.shared.theme.backgroundColor;
        UIKeyboardAppearance keyAppearance = UserPreferences.shared.theme.keyboardAppearance;
        self.termView.keyboardAppearance = keyAppearance;
        for (BarButton *button in self.barButtons) {
            button.keyAppearance = keyAppearance;
        }
        UIColor *tintColor = keyAppearance == UIKeyboardAppearanceLight ? UIColor.blackColor : UIColor.whiteColor;
        for (UIControl *control in self.barControls) {
            control.tintColor = tintColor;
        }
    }];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UserPreferences.shared.theme.statusBarStyle;
}

- (BOOL)prefersStatusBarHidden {
    BOOL isIPhoneX = UIApplication.sharedApplication.delegate.window.safeAreaInsets.top > 20;
    return !isIPhoneX;
}

- (void)keyboardDidSomething:(NSNotification *)notification {
    BOOL initialLayout = self.termView.needsUpdateConstraints;
    
    CGFloat pad = 0;
    if ([notification.name isEqualToString:UIKeyboardWillShowNotification]) {
        NSValue *frame = notification.userInfo[UIKeyboardFrameEndUserInfoKey];
        pad = frame.CGRectValue.size.height;
    }
    if (pad == 0) {
        pad = self.view.safeAreaInsets.bottom;
    }
    self.bottomConstraint.constant = -pad;
    [self.view setNeedsUpdateConstraints];
    
    if (!initialLayout) {
        // if initial layout hasn't happened yet, the terminal view is going to be at a really weird place, so animating it is going to look really bad
        NSNumber *interval = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey];
        NSNumber *curve = notification.userInfo[UIKeyboardAnimationCurveUserInfoKey];
        [UIView animateWithDuration:interval.doubleValue
                              delay:0
                            options:curve.integerValue << 16
                         animations:^{
                             [self.view layoutIfNeeded];
                         }
                         completion:nil];
    }
}

- (void)ishExited:(NSNotification *)notification {
    [self performSelectorOnMainThread:@selector(displayExitThing) withObject:nil waitUntilDone:YES];
}

- (void)displayExitThing {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"attempted to kill init" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"exit" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        id delegate = [UIApplication sharedApplication].delegate;
        [delegate exitApp];
    }]];
    if ([UserPreferences.shared hasChangedLaunchCommand])
        [alert addAction:[UIAlertAction actionWithTitle:@"i typed the init command wrong, let me fix it" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark Bar

- (IBAction)showAbout:(id)sender {
    UINavigationController *navigationController = [[UIStoryboard storyboardWithName:@"About" bundle:nil] instantiateInitialViewController];
    if ([sender isKindOfClass:[UIGestureRecognizer class]]) {
        UIGestureRecognizer *recognizer = sender;
        if (recognizer.state == UIGestureRecognizerStateBegan) {
            AboutViewController *aboutViewController = (AboutViewController *) navigationController.topViewController;
            aboutViewController.includeDebugPanel = YES;
        } else {
            return;
        }
    }
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)resizeBar {
    CGSize screen = UIScreen.mainScreen.bounds.size;
    CGSize bar = self.barView.bounds.size;
    // set sizing parameters on bar
    // numbers stolen from iVim and modified somewhat
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        // phone
        [self setBarHorizontalPadding:6 verticalPadding:6 buttonWidth:32];
    } else if (bar.width == screen.width || bar.width == screen.height) {
        // full-screen ipad
        [self setBarHorizontalPadding:15 verticalPadding:8 buttonWidth:43];
    } else if (bar.width <= 320) {
        // slide over
        [self setBarHorizontalPadding:8 verticalPadding:8 buttonWidth:26];
    } else {
        // split view
        [self setBarHorizontalPadding:10 verticalPadding:8 buttonWidth:36];
    }
    [UIView performWithoutAnimation:^{
        [self.barView layoutIfNeeded];
    }];
}

- (void)setBarHorizontalPadding:(CGFloat)horizontal verticalPadding:(CGFloat)vertical buttonWidth:(CGFloat)buttonWidth {
    self.barLeading.constant = self.barTrailing.constant = horizontal;
    self.barTop.constant = self.barBottom.constant = vertical;
    self.barButtonWidth.constant = buttonWidth;
}

- (IBAction)pressEscape:(id)sender {
    [self pressKey:@"\x1b"];
}
- (IBAction)pressTab:(id)sender {
    [self pressKey:@"\t"];
}
- (void)pressKey:(NSString *)key {
    [self.termView insertText:key];
}

- (IBAction)pressControl:(id)sender {
    self.controlKey.selected = !self.controlKey.selected;
}
    
- (IBAction)pressArrow:(ArrowBarButton *)sender {
    switch (sender.direction) {
        case ArrowUp: [self pressKey:[self.terminal arrow:'A']]; break;
        case ArrowDown: [self pressKey:[self.terminal arrow:'B']]; break;
        case ArrowLeft: [self pressKey:[self.terminal arrow:'D']]; break;
        case ArrowRight: [self pressKey:[self.terminal arrow:'C']]; break;
        case ArrowNone: break;
    }
}

- (IBAction)pressAddFolder:(id)sender {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[ @"public.folder"] inMode:UIDocumentPickerModeOpen];

    picker.delegate = self;

    [self presentViewController:picker animated:true completion:nil];
}

-(void)displayMountError {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Mount failed" message:@"Mounting the folder at the requested location failed." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:true completion:nil];

}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    for (int i = 0; i < urls.count; i++) {
        NSURL *url = urls[i];

        NSString *defaultMountName = [NSString stringWithFormat:@"/mnt/%@", url.lastPathComponent];

        UIAlertController *mountNameAlert = [UIAlertController alertControllerWithTitle:@"Mount location" message:@"Where do you want to mount the folder?" preferredStyle:UIAlertControllerStyleAlert];

        [mountNameAlert addTextFieldWithConfigurationHandler:^void (UITextField *textField) {
            textField.placeholder = defaultMountName;
        }];

        [mountNameAlert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [mountNameAlert addAction:[UIAlertAction actionWithTitle:@"Mount" style:UIAlertActionStyleDefault handler:^void (UIAlertAction *action) {
            UITextField *mountTextField = mountNameAlert.textFields.firstObject;
            NSString *mountName = mountTextField.text.length > 0 ? mountTextField.text : defaultMountName;

            createExternalfsIfRequired();
            int err = do_mount_with_data(externalfs, [url.path UTF8String], [mountName UTF8String], 0, (void *) CFBridgingRetain(url));
            if (err < 0)
                [self displayMountError];
        }]];

        [self presentViewController:mountNameAlert animated:true completion:nil];
    }
}

- (void)switchTerminal:(UIKeyCommand *)sender {
    unsigned i = (unsigned) sender.input.integerValue;
    self.terminal = [Terminal terminalWithType:TTY_CONSOLE_MAJOR number:i];
}

- (NSArray<UIKeyCommand *> *)keyCommands {
    static NSMutableArray<UIKeyCommand *> *commands = nil;
    if (commands == nil) {
        commands = [NSMutableArray new];
        for (unsigned i = 1; i <= 7; i++) {
            [commands addObject:
             [UIKeyCommand keyCommandWithInput:[NSString stringWithFormat:@"%d", i]
                                 modifierFlags:UIKeyModifierCommand|UIKeyModifierAlternate|UIKeyModifierShift
                                        action:@selector(switchTerminal:)]];
        }
    }
    return commands;
}

- (void)setTerminal:(Terminal *)terminal {
    _terminal = terminal;
    self.termView.terminal = self.terminal;
}

@end

@interface BarView : UIInputView
@property (weak) IBOutlet TerminalViewController *terminalViewController;
@end
@implementation BarView

- (void)layoutSubviews {
    [self.terminalViewController resizeBar];
}

@end
