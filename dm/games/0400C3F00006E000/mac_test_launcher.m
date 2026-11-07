// Mario Kart World's optional Mac selector. Modes share one game, shader set and save.
#import <Cocoa/Cocoa.h>
#include <unistd.h>

int main(int argc, char **argv) {
    @autoreleasepool {
        NSArray<NSString *> *resolutions = @[@"1080p", @"4k"];
        NSArray<NSString *> *rates = @[@"60", @"120", @"uncapped"];
        NSArray<NSString *> *displays = @[@"off", @"fps", @"full"];
        NSUserDefaults *prefs = NSUserDefaults.standardUserDefaults;
        NSString *resolution = [prefs stringForKey:@"test.resolution"] ?: @"1080p";
        NSString *rate = [prefs stringForKey:@"test.frameRate"] ?: @"60";
        NSString *display = [prefs stringForKey:@"test.debugDisplay"] ?: @"off";
        if (![resolutions containsObject:resolution]) resolution = @"1080p";
        if (![rates containsObject:rate]) rate = @"60";
        if (![displays containsObject:display]) display = @"off";
        BOOL show = YES;
        for (int i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--mode") && i + 1 < argc) {
                NSArray<NSString *> *parts = [@(argv[++i]) componentsSeparatedByString:@"-"];
                if (parts.count != 2 || ![resolutions containsObject:parts[0]] || ![rates containsObject:parts[1]]) {
                    fprintf(stderr, "Unknown Mario Kart World test mode\n"); return 2;
                }
                resolution = parts[0]; rate = parts[1]; show = NO;
            } else if (!strcmp(argv[i], "--debug-display") && i + 1 < argc) {
                display = @(argv[++i]);
                if (![displays containsObject:display]) { fprintf(stderr, "Unknown debug display\n"); return 2; }
            } else if (!strcmp(argv[i], "--no-launcher")) show = NO;
            else {
                fprintf(stderr, "usage: nxnative [--mode <1080p|4k>-<60|120|uncapped>] [--debug-display <off|fps|full>] [--no-launcher]\n"); return 2;
            }
        }
        if (show) {
            [NSApplication sharedApplication];
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
            [NSApp finishLaunching];
            NSAlert *alert = [NSAlert new];
            alert.messageText = @"Mario Kart World settings";
            alert.informativeText = @"Choose the output resolution and frame rate. 120 fps and Unlocked are experimental; game speed must be checked.";
            [alert addButtonWithTitle:@"Play"]; [alert addButtonWithTitle:@"Cancel"];
            NSView *controls = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 124)];
            NSTextField *resLabel = [NSTextField labelWithString:@"Resolution"];
            resLabel.frame = NSMakeRect(0, 92, 120, 22); [controls addSubview:resLabel];
            NSPopUpButton *res = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, 88, 190, 32) pullsDown:NO];
            [res addItemsWithTitles:@[@"1080p", @"4K"]]; [res selectItemAtIndex:[resolutions indexOfObject:resolution]];
            res.accessibilityLabel = @"Resolution";
            res.toolTip = @"1080p uses handheld mode; 4K uses docked mode. The game chooses its internal scene resolution within the requested output size.";
            [controls addSubview:res];
            NSTextField *fpsLabel = [NSTextField labelWithString:@"Frame rate"];
            fpsLabel.frame = NSMakeRect(0, 52, 120, 22); [controls addSubview:fpsLabel];
            NSPopUpButton *fps = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, 48, 190, 32) pullsDown:NO];
            [fps addItemsWithTitles:@[@"60 fps", @"120 fps (experimental)", @"Unlocked (experimental)"]];
            [fps selectItemAtIndex:[rates indexOfObject:rate]];
            fps.accessibilityLabel = @"Frame rate"; [controls addSubview:fps];
            NSTextField *debugLabel = [NSTextField labelWithString:@"Debug display"];
            debugLabel.frame = NSMakeRect(0, 12, 120, 22); [controls addSubview:debugLabel];
            NSPopUpButton *debug = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, 8, 190, 32) pullsDown:NO];
            [debug addItemsWithTitles:@[@"Off", @"Compact FPS", @"Full debug"]]; [debug selectItemAtIndex:[displays indexOfObject:display]];
            debug.accessibilityLabel = @"Debug display"; [controls addSubview:debug];
            alert.accessoryView = controls;
            [NSApp activateIgnoringOtherApps:YES];
            if ([alert runModal] != NSAlertFirstButtonReturn) return 0;
            resolution = resolutions[res.indexOfSelectedItem]; rate = rates[fps.indexOfSelectedItem]; display = displays[debug.indexOfSelectedItem];
            [prefs setObject:resolution forKey:@"test.resolution"];
            [prefs setObject:rate forKey:@"test.frameRate"];
            [prefs setObject:display forKey:@"test.debugDisplay"];
            [prefs synchronize];
            [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        }
        BOOL fourK = [resolution isEqualToString:@"4k"], uncapped = [rate isEqualToString:@"uncapped"];
        // These are host pacing requests. No Star Fox timing stub applies to this game.
        setenv("DM_PRESENT_HZ", uncapped ? "0" : rate.UTF8String, 1);
        setenv("DM_PRESENT_LINK", "0", 1);
        setenv("DM_PRESENT_VSYNC", [rate isEqualToString:@"60"] ? "1" : "0", 1);
        setenv("DM_PRESENT_INTERVAL", "game", 1);
        setenv("DM_VI_BUFFER_MAX", fourK ? "3" : "1", 1);
        setenv("DM_OPMODE", fourK ? "1" : "0", 1);
        setenv("DM_LAUNCHER", "0", 1); setenv("DM_SAVED_CHOICES", "0", 1);
        BOOL hud = ![display isEqualToString:@"off"];
        setenv("DM_METAL_HUD", hud ? "1" : "0", 1); setenv("MTL_HUD_ENABLED", hud ? "1" : "0", 1);
        setenv("MTL_HUD_ELEMENTS", [display isEqualToString:@"fps"] ? "fps" :
               "device,layersize,memory,thermal,fps,gputime,frameinterval,frameintervalgraph,framenumber,metalcpu,shaders", 1);
        NSString *core = [NSBundle.mainBundle.executablePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"nxnative-core"];
        execl(core.fileSystemRepresentation, core.fileSystemRepresentation, "--no-launcher", NULL);
        perror("Starting Mario Kart World"); return 1;
    }
}
