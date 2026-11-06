// The optional Star Fox experiment selector. All modes share the app's data, shaders and save.
#import <Cocoa/Cocoa.h>
#include <unistd.h>

int main(int argc, char **argv) {
    @autoreleasepool {
        NSArray<NSString *> *resolutions = @[@"1080p", @"4k"];
        NSArray<NSString *> *rates = @[@"60", @"120", @"uncapped"];
        NSUserDefaults *prefs = NSUserDefaults.standardUserDefaults;
        NSString *mode = [prefs stringForKey:@"test.mode"] ?: @"1080p-uncapped";
        BOOL show = YES;
        for (int i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--mode") && i + 1 < argc) { mode = @(argv[++i]); show = NO; }
            else if (!strcmp(argv[i], "--no-launcher")) show = NO;
            else { fprintf(stderr, "usage: nxnative [--mode <1080p|4k>-<60|120|uncapped>]\n"); return 2; }
        }
        NSArray<NSString *> *parts = [mode componentsSeparatedByString:@"-"];
        if (parts.count != 2 || ![resolutions containsObject:parts[0]] || ![rates containsObject:parts[1]]) { fprintf(stderr, "Unknown Star Fox test mode\n"); return 2; }
        if (show) {
            [NSApplication sharedApplication];
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
            [NSApp finishLaunching];
            NSAlert *alert = [NSAlert new];
            alert.messageText = @"Star Fox test settings";
            alert.informativeText = @"Choose the resolution and frame rate. 4K renders at 3840 × 2160 and scales to your screen.";
            [alert addButtonWithTitle:@"Play"]; [alert addButtonWithTitle:@"Cancel"];
            NSView *controls = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 84)];
            NSTextField *resLabel = [NSTextField labelWithString:@"Resolution"];
            resLabel.frame = NSMakeRect(0, 52, 120, 22); [controls addSubview:resLabel];
            NSPopUpButton *res = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, 48, 190, 32) pullsDown:NO];
            [res addItemsWithTitles:@[@"1080p", @"4K"]]; [res selectItemAtIndex:[resolutions indexOfObject:parts[0]]];
            res.accessibilityLabel = @"Resolution"; [controls addSubview:res];
            NSTextField *fpsLabel = [NSTextField labelWithString:@"Frame rate"];
            fpsLabel.frame = NSMakeRect(0, 12, 120, 22); [controls addSubview:fpsLabel];
            NSPopUpButton *fps = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, 8, 190, 32) pullsDown:NO];
            [fps addItemsWithTitles:@[@"60 fps", @"120 fps", @"Unlocked"]]; [fps selectItemAtIndex:[rates indexOfObject:parts[1]]];
            fps.accessibilityLabel = @"Frame rate"; [controls addSubview:fps];
            alert.accessoryView = controls;
            [NSApp activateIgnoringOtherApps:YES];
            if ([alert runModal] != NSAlertFirstButtonReturn) return 0;
            mode = [NSString stringWithFormat:@"%@-%@", resolutions[res.indexOfSelectedItem], rates[fps.indexOfSelectedItem]];
            [prefs setObject:mode forKey:@"test.mode"];
            [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];   // the host owns the game's windows, as in Launcher.swift
        }
        parts = [mode componentsSeparatedByString:@"-"];
        BOOL fourK = [parts[0] isEqualToString:@"4k"], uncapped = [parts[1] isEqualToString:@"uncapped"];
        setenv("DM_STARFOX_RENDER_HZ", uncapped ? "0" : parts[1].UTF8String, 1);
        setenv("DM_PRESENT_VSYNC", uncapped ? "0" : "1", 1);
        setenv("DM_VI_BUFFER_MAX", fourK ? "3" : "1", 1);
        setenv("DM_OPMODE", fourK ? "1" : "0", 1);
        setenv("DM_RESOLUTION_SCALE", "1", 1);
        setenv("DM_PRESENT_HZ", "0", 1); setenv("DM_PRESENT_LINK", "0", 1);
        setenv("DM_PRESENT_INTERVAL", "game", 1);
        setenv("DM_LAUNCHER", "0", 1); setenv("DM_SAVED_CHOICES", "0", 1);
        setenv("DM_METAL_HUD", "1", 1);
        NSString *core = [NSBundle.mainBundle.executablePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"nxnative-core"];
        execl(core.fileSystemRepresentation, core.fileSystemRepresentation, "--no-launcher", NULL);
        perror("Starting Star Fox"); return 1;
    }
}
