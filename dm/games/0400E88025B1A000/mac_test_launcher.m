// The optional Star Fox experiment selector. All modes share the app's data, shaders and save.
#import <Cocoa/Cocoa.h>
#include <unistd.h>

int main(int argc, char **argv) {
    @autoreleasepool {
        NSArray<NSString *> *keys = @[@"1080p-uncapped", @"4k-uncapped", @"1080p-120"];
        NSArray<NSString *> *labels = @[@"1080p — Uncapped", @"4K — Uncapped", @"1080p — 120 fps"];
        NSUserDefaults *prefs = NSUserDefaults.standardUserDefaults;
        NSString *mode = [prefs stringForKey:@"test.mode"] ?: keys[0];
        BOOL show = YES;
        for (int i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--mode") && i + 1 < argc) { mode = @(argv[++i]); show = NO; }
            else if (!strcmp(argv[i], "--no-launcher")) show = NO;
            else { fprintf(stderr, "usage: nxnative [--mode 1080p-uncapped|4k-uncapped|1080p-120]\n"); return 2; }
        }
        if (![keys containsObject:mode]) { fprintf(stderr, "Unknown Star Fox test mode\n"); return 2; }
        if (show) {
            [NSApplication sharedApplication];
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
            NSAlert *alert = [NSAlert new];
            alert.messageText = @"Star Fox test settings";
            alert.informativeText = @"Choose a rendering mode. 4K renders at 3840 × 2160 and scales to your screen.\n\nFrame timing is experimental; game speed and audio sync still need checking.";
            [alert addButtonWithTitle:@"Play"]; [alert addButtonWithTitle:@"Cancel"];
            NSPopUpButton *choice = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 320, 32) pullsDown:NO];
            [choice addItemsWithTitles:labels]; [choice selectItemAtIndex:[keys indexOfObject:mode]];
            choice.accessibilityLabel = @"Rendering mode";
            alert.accessoryView = choice;
            [NSApp activateIgnoringOtherApps:YES];
            if ([alert runModal] != NSAlertFirstButtonReturn) return 0;
            mode = keys[choice.indexOfSelectedItem]; [prefs setObject:mode forKey:@"test.mode"];
        }
        BOOL fourK = [mode isEqualToString:@"4k-uncapped"], uncapped = ![mode isEqualToString:@"1080p-120"];
        setenv("DM_STARFOX_RENDER_HZ", uncapped ? "0" : "120", 1);
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
