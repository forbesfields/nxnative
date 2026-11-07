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
        // Older selectors saved rates that accelerate this game's fixed 60 Hz step.
        if (![rate isEqualToString:@"60"]) rate = @"60";
        if (![displays containsObject:display]) display = @"off";
        BOOL show = YES;
        for (int i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--mode") && i + 1 < argc) {
                NSArray<NSString *> *parts = [@(argv[++i]) componentsSeparatedByString:@"-"];
                if (parts.count != 2 || ![resolutions containsObject:parts[0]] || ![rates containsObject:parts[1]]) {
                    fprintf(stderr, "Unknown Mario Kart World test mode\n"); return 2;
                }
                if (![parts[1] isEqualToString:@"60"]) {
                    fprintf(stderr, "Mario Kart World requires 60 fps for normal game speed; 120 fps and Unlocked are unavailable until a simulation timing patch is verified.\n"); return 2;
                }
                resolution = parts[0]; rate = parts[1]; show = NO;
            } else if (!strcmp(argv[i], "--debug-display") && i + 1 < argc) {
                display = @(argv[++i]);
                if (![displays containsObject:display]) { fprintf(stderr, "Unknown debug display\n"); return 2; }
            } else if (!strcmp(argv[i], "--no-launcher")) show = NO;
            else {
                fprintf(stderr, "usage: nxnative [--mode <1080p|4k>-60] [--debug-display <off|fps|full>] [--no-launcher]\n"); return 2;
            }
        }
        if (show) {
            [NSApplication sharedApplication];
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
            [NSApp finishLaunching];
            NSAlert *alert = [NSAlert new];
            alert.messageText = @"Mario Kart World settings";
            alert.informativeText = @"Choose the output resolution and debug display. Mario Kart World runs at normal speed at 60 fps. Higher frame rates are unavailable because they speed up the game.";
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
            [fps addItemsWithTitles:@[@"60 fps", @"120 fps (unavailable)", @"Unlocked (unavailable)"]];
            fps.menu.autoenablesItems = NO;
            [fps itemAtIndex:1].enabled = NO;
            [fps itemAtIndex:2].enabled = NO;
            [fps selectItemAtIndex:0];
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
        BOOL fourK = [resolution isEqualToString:@"4k"];
        // The game advances at least one 1/60 s step per frame. Faster presents
        // accelerate its simulation; keep 60 until a complete timing patch exists.
        setenv("DM_PRESENT_HZ", "60", 1);
        setenv("DM_PRESENT_LINK", "0", 1);
        setenv("DM_PRESENT_VSYNC", "1", 1);
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
