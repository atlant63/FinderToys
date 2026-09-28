//
//  FinderSync.m
//  FinderToysExtension
//
//  Created by Louie Yin on 2026-01-25.
//

#import "FinderSync.h"
#import <ImageIO/ImageIO.h>
#import <PDFKit/PDFKit.h>
#import <Quartz/Quartz.h>
#import <AVFoundation/AVFoundation.h>

static inline BOOL FTIsPreferenceEnabled(NSString *key, BOOL defaultVal) {
    CFPreferencesAppSynchronize(CFSTR("com.atlant63.FinderToys"));
    Boolean keyExists = false;
    Boolean val = CFPreferencesGetAppBooleanValue((__bridge CFStringRef)key, CFSTR("com.atlant63.FinderToys"), &keyExists);
    return keyExists ? (BOOL)val : defaultVal;
}

static inline NSSet<NSString *> *FTImageExtensions(void) {
    static NSSet *set = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        set = [NSSet setWithObjects:@"png", @"jpg", @"jpeg", @"webp", @"heic", @"heif", @"tiff", @"tif", @"bmp", @"gif", nil];
    });
    return set;
}

static inline NSSet<NSString *> *FTVideoExtensions(void) {
    static NSSet *set = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        set = [NSSet setWithObjects:@"mp4", @"mov", @"m4v", @"avi", @"mkv", @"wmv", @"webm", @"flv", nil];
    });
    return set;
}

static NSImage *FTSymbolImage(NSString *name) {
    BOOL isDark = NO;
    CFStringRef style = (CFStringRef)CFPreferencesCopyAppValue((CFStringRef)@"AppleInterfaceStyle", kCFPreferencesAnyApplication);
    if (style) {
        if ([(__bridge NSString *)style isEqualToString:@"Dark"]) {
            isDark = YES;
        }
        CFRelease(style);
    } else if (@available(macOS 10.14, *)) {
        NSAppearanceName match = [[NSApp effectiveAppearance] bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
        if ([match isEqualToString:NSAppearanceNameDarkAqua]) {
            isDark = YES;
        }
    }

    NSColor *tintColor = isDark ? [NSColor whiteColor] : [NSColor colorWithWhite:0.15 alpha:1.0];

    NSImage *sym = nil;
    if (@available(macOS 11.0, *)) {
        NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightMedium];
        if (@available(macOS 12.0, *)) {
            NSImageSymbolConfiguration *colorConfig = [NSImageSymbolConfiguration configurationWithHierarchicalColor:tintColor];
            config = [config configurationByApplyingConfiguration:colorConfig];
        }
        sym = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
        if (sym) {
            sym = [sym imageWithSymbolConfiguration:config];
        }
    }
    if (!sym) return nil;

    NSImage *result = [NSImage imageWithSize:NSMakeSize(18, 18) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        CGFloat w = sym.size.width;
        CGFloat h = sym.size.height;
        if (w > 18) { h = h * (18.0 / w); w = 18; }
        if (h > 18) { h = h * (18.0 / h); h = 18; }
        NSRect r = NSMakeRect((18.0 - w) / 2.0, (18.0 - h) / 2.0, w, h);
        [tintColor set];
        [sym drawInRect:r fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
        return YES;
    }];

    CGImageRef cg = [result CGImageForProposedRect:NULL context:nil hints:nil];
    if (cg) {
        return [[NSImage alloc] initWithCGImage:cg size:NSMakeSize(18, 18)];
    }
    return result;
}

static inline NSString *FTLocalizedString(NSString *key) {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *classBundle = [NSBundle bundleForClass:[FinderSync class]];
        NSArray *preferred = [NSBundle preferredLocalizationsFromArray:[classBundle localizations] forPreferences:[NSLocale preferredLanguages]];
        NSString *lang = preferred.firstObject ?: @"en";
        NSString *path = [classBundle pathForResource:lang ofType:@"lproj"];
        if (path) {
            bundle = [NSBundle bundleWithPath:path];
        }
        if (!bundle) {
            bundle = classBundle;
        }
    });
    return [bundle localizedStringForKey:key value:key table:nil];
}
#undef NSLocalizedString
#define NSLocalizedString(key, comment) FTLocalizedString(key)

@implementation FinderSync

- (instancetype)init {
    self = [super init];

    // Monitor root filesystem and all mounted volumes (including USB drives)
    // Finder Sync extensions don't cross volume mount points, so we need to
    // explicitly add each mounted volume to directoryURLs
    // Note: iCloud Drive is not supported due to macOS Sonoma+ limitations
    [self updateDirectoryURLs];

    // Poll for volume changes every 3 seconds
    // Neither NSWorkspace notifications nor GCD vnode watchers reliably
    // detect volume mounts in Finder Sync extensions
    _volumeTimerSource = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());

    if (_volumeTimerSource) {
        dispatch_source_set_timer(_volumeTimerSource,
            dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
            3 * NSEC_PER_SEC, 1 * NSEC_PER_SEC);

        __weak typeof(self) weakSelf = self;
        dispatch_source_set_event_handler(_volumeTimerSource, ^{
            [weakSelf updateDirectoryURLs];
        });
        dispatch_resume(_volumeTimerSource);
    }

    return self;
}

- (void)dealloc {
    if (_volumeTimerSource) {
        dispatch_source_cancel(_volumeTimerSource);
        _volumeTimerSource = nil;
    }
}

- (void)updateDirectoryURLs {
    NSMutableSet *urls = [NSMutableSet setWithObject:[NSURL fileURLWithPath:@"/"]];

    // Add all mounted volumes (covers USB drives, external drives, etc.)
    NSArray *volumeURLs = [[NSFileManager defaultManager]
        mountedVolumeURLsIncludingResourceValuesForKeys:nil
                                                options:NSVolumeEnumerationSkipHiddenVolumes];
    for (NSURL *volumeURL in volumeURLs) {
        [urls addObject:volumeURL];
    }

    // Add CloudStorage directory for cloud providers (OneDrive, Google Drive, Dropbox, etc.)
    NSString *cloudStoragePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/CloudStorage"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cloudStoragePath]) {
        [urls addObject:[NSURL fileURLWithPath:cloudStoragePath]];
    }

    [FIFinderSyncController defaultController].directoryURLs = urls;
}

#pragma mark - Primary Finder Sync protocol methods

- (void)beginObservingDirectoryAtURL:(NSURL *)url {
    // Called when user opens a directory in Finder
}


- (void)endObservingDirectoryAtURL:(NSURL *)url {
    // Called when user closes a directory in Finder
}

- (void)requestBadgeIdentifierForURL:(NSURL *)url {
    // Not used - no badge icons needed
}

#pragma mark - Menu and toolbar item support

- (NSString *)toolbarItemName {
    return NSLocalizedString(@"New File", nil);
}

- (NSString *)toolbarItemToolTip {
    return NSLocalizedString(@"FinderToysExtension: Click the toolbar item for a menu.", nil);
}

- (NSImage *)toolbarItemImage {
    return [NSImage imageNamed:NSImageNameAddTemplate];
}

- (NSMenu *)menuForMenuKind:(FIMenuKind)whichMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];

    // Create submenu for New File options
    NSMenu *submenu = [[NSMenu alloc] initWithTitle:@""];

    // Add "New Text File" to submenu
    NSMenuItem *newTextItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Text File", nil) action:@selector(createNewTextFile:) keyEquivalent:@""];
    NSImage *textIcon = [NSImage imageNamed:@"edit"];
    textIcon.template = YES;
    newTextItem.image = textIcon;
    [submenu addItem:newTextItem];

    // Add "New Markdown File" to submenu
    NSMenuItem *newMarkdownItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Markdown File", nil) action:@selector(createNewMarkdownFile:) keyEquivalent:@""];
    NSImage *markdownIcon = [NSImage imageNamed:@"document"];
    markdownIcon.template = YES;
    newMarkdownItem.image = markdownIcon;
    [submenu addItem:newMarkdownItem];

    // Add "New JSON File" to submenu
    NSMenuItem *newJSONItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"JSON File", nil) action:@selector(createNewJSONFile:) keyEquivalent:@""];
    newJSONItem.image = [self jsonIcon];
    [submenu addItem:newJSONItem];

    // Add "New Microsoft Word Document" to submenu
    NSMenuItem *newWordItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Microsoft Word Document", nil) action:@selector(createNewWordDocument:) keyEquivalent:@""];
    NSImage *wordIcon = [NSImage imageNamed:@"word"];
    wordIcon.template = YES;
    newWordItem.image = wordIcon;
    [submenu addItem:newWordItem];

    // Add "New Microsoft Excel Spreadsheet" to submenu
    NSMenuItem *newExcelItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Microsoft Excel Spreadsheet", nil) action:@selector(createNewExcelDocument:) keyEquivalent:@""];
    NSImage *excelIcon = [NSImage imageNamed:@"excel"];
    excelIcon.template = YES;
    newExcelItem.image = excelIcon;
    [submenu addItem:newExcelItem];

    // Add "New Microsoft PowerPoint Presentation" to submenu
    NSMenuItem *newPowerPointItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Microsoft PowerPoint Presentation", nil) action:@selector(createNewPowerPointDocument:) keyEquivalent:@""];
    NSImage *powerPointIcon = [NSImage imageNamed:@"powerpoint"];
    powerPointIcon.template = YES;
    newPowerPointItem.image = powerPointIcon;
    [submenu addItem:newPowerPointItem];

    // 1. Add "New File" submenu
    NSMenuItem *mainItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"New File", nil) action:nil keyEquivalent:@""];
    NSImage *mainIcon = [NSImage imageNamed:@"add"];
    mainItem.image = mainIcon;
    mainItem.submenu = submenu;
    [menu addItem:mainItem];

    // Check selected items: ONLY show Convert and PDF actions when right-clicking on specific files!
    NSArray<NSURL *> *selectedURLs = [[FIFinderSyncController defaultController] selectedItemURLs];
    if (whichMenu == FIMenuKindContextualMenuForItems && selectedURLs.count > 0) {
        NSMutableArray<NSURL *> *imageURLs = [NSMutableArray array];
        NSMutableArray<NSURL *> *pdfURLs = [NSMutableArray array];
        NSMutableArray<NSURL *> *videoURLs = [NSMutableArray array];
        for (NSURL *url in selectedURLs) {
            NSString *ext = url.pathExtension.lowercaseString;
            if ([FTImageExtensions() containsObject:ext]) {
                [imageURLs addObject:url];
            } else if ([ext isEqualToString:@"pdf"]) {
                [pdfURLs addObject:url];
            } else if ([FTVideoExtensions() containsObject:ext]) {
                [videoURLs addObject:url];
            }
        }

        BOOL isImageConvEnabled = FTIsPreferenceEnabled(@"ImageConversionInFinder", YES);
        BOOL isPDFToolsEnabled = FTIsPreferenceEnabled(@"PDFToolsInFinder", YES);
        BOOL isVideoConvEnabled = FTIsPreferenceEnabled(@"VideoConversionInFinder", YES);

        // A. Image Conversion Submenu (with Smart Format Filtering)
        if (isImageConvEnabled && imageURLs.count > 0) {
            BOOL allArePNG = YES;
            BOOL allAreJPEG = YES;
            BOOL allAreHEIC = YES;

            for (NSURL *url in imageURLs) {
                NSString *ext = url.pathExtension.lowercaseString;
                if (![ext isEqualToString:@"png"]) {
                    allArePNG = NO;
                }
                if (![ext isEqualToString:@"jpg"] && ![ext isEqualToString:@"jpeg"]) {
                    allAreJPEG = NO;
                }
                if (![ext isEqualToString:@"heic"] && ![ext isEqualToString:@"heif"]) {
                    allAreHEIC = NO;
                }
            }

            NSMenu *convSubmenu = [[NSMenu alloc] initWithTitle:@""];

            if (!allArePNG) {
                NSMenuItem *pngItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"to PNG", nil) action:@selector(convertSelectedImagesToPNG:) keyEquivalent:@""];
                pngItem.image = FTSymbolImage(@"photo");
                [convSubmenu addItem:pngItem];
            }

            if (!allAreJPEG) {
                NSMenuItem *jpegItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"to JPEG", nil) action:@selector(convertSelectedImagesToJPEG:) keyEquivalent:@""];
                jpegItem.image = FTSymbolImage(@"photo");
                [convSubmenu addItem:jpegItem];
            }

            if (!allAreHEIC) {
                NSMenuItem *heicItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"to HEIC", nil) action:@selector(convertSelectedImagesToHEIC:) keyEquivalent:@""];
                heicItem.image = FTSymbolImage(@"photo");
                [convSubmenu addItem:heicItem];
            }

            if (convSubmenu.numberOfItems > 0) {
                NSMenuItem *convMainItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Convert", nil) action:nil keyEquivalent:@""];
                convMainItem.image = FTSymbolImage(@"arrow.triangle.2.circlepath");
                convMainItem.submenu = convSubmenu;
                [menu addItem:convMainItem];
            }
        }

        // B. PDF Actions (Only show when 2 or more files are selected!)
        if (isPDFToolsEnabled) {
            NSUInteger totalCount = imageURLs.count + pdfURLs.count;
            if (totalCount >= 2) {
                NSString *title = (pdfURLs.count == totalCount) ?
                    NSLocalizedString(@"Merge PDFs", nil) :
                    NSLocalizedString(@"Combine into PDF", nil);

                NSMenuItem *combinePDFItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(combineSelectedIntoPDF:) keyEquivalent:@""];
                combinePDFItem.image = FTSymbolImage(@"doc.on.doc");
                [menu addItem:combinePDFItem];
            }
        }

        // C. Video Actions (shown when video files selected, no mix with other types)
        if (isVideoConvEnabled && videoURLs.count > 0 && imageURLs.count == 0 && pdfURLs.count == 0) {
            BOOL allAreMP4 = YES;
            BOOL allAreMOV = YES;
            for (NSURL *url in videoURLs) {
                NSString *ext = url.pathExtension.lowercaseString;
                if (![ext isEqualToString:@"mp4"]) allAreMP4 = NO;
                if (![ext isEqualToString:@"mov"]) allAreMOV = NO;
            }

            NSMenu *videoSubmenu = [[NSMenu alloc] initWithTitle:@""];

            // Compress: always shown (H.264 1080p — equivalent of your ffmpeg CRF 22)
            NSMenuItem *compressItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Compress Video (H.264)", nil) action:@selector(compressSelectedVideos:) keyEquivalent:@""];
            compressItem.image = FTSymbolImage(@"arrow.down.doc");
            [videoSubmenu addItem:compressItem];

            // Convert to MP4 — shown only if not already all MP4
            if (!allAreMP4) {
                NSMenuItem *mp4Item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"to MP4", nil) action:@selector(convertSelectedVideosToMP4:) keyEquivalent:@""];
                mp4Item.image = FTSymbolImage(@"film");
                [videoSubmenu addItem:mp4Item];
            }

            // Convert to MOV — shown only if not already all MOV
            if (!allAreMOV) {
                NSMenuItem *movItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"to MOV", nil) action:@selector(convertSelectedVideosToMOV:) keyEquivalent:@""];
                movItem.image = FTSymbolImage(@"film");
                [videoSubmenu addItem:movItem];
            }

            if (videoSubmenu.numberOfItems > 0) {
                NSMenuItem *videoMainItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Video", nil) action:nil keyEquivalent:@""];
                videoMainItem.image = FTSymbolImage(@"video");
                videoMainItem.submenu = videoSubmenu;
                [menu addItem:videoMainItem];
            }
        }
    }

    // 2. Add "Copy Path" menu item
    NSMenuItem *copyPathItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy Path", nil) action:@selector(copyPathToClipboard:) keyEquivalent:@""];
    NSImage *copyIcon = [NSImage imageNamed:@"copy"];
    copyIcon.template = YES;
    copyPathItem.image = copyIcon;
    [menu addItem:copyPathItem];

    // 3. Add "Open Terminal" menu item
    NSMenuItem *openTerminalItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open New Terminal", nil) action:@selector(openTerminalAtPath:) keyEquivalent:@""];
    NSImage *terminalIcon = [NSImage imageNamed:@"terminal"];
    terminalIcon.template = YES;
    openTerminalItem.image = terminalIcon;
    [menu addItem:openTerminalItem];

    return menu;
}

- (NSImage *)jsonIcon {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    BOOL isDark = NO;
    CFStringRef style = (CFStringRef)CFPreferencesCopyAppValue((CFStringRef)@"AppleInterfaceStyle", kCFPreferencesAnyApplication);
    if (style) {
        if ([(__bridge NSString *)style isEqualToString:@"Dark"]) {
            isDark = YES;
        }
        CFRelease(style);
    } else if (@available(macOS 10.14, *)) {
        NSAppearanceName match = [[NSApp effectiveAppearance] bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
        if ([match isEqualToString:NSAppearanceNameDarkAqua]) {
            isDark = YES;
        }
    }

    NSString *iconName = isDark ? @"json-dark" : @"json";
    NSString *path = [bundle pathForResource:iconName ofType:@"png"];
    if (path) {
        NSImage *img = [[NSImage alloc] initWithContentsOfFile:path];
        [img setSize:NSMakeSize(18, 18)];
        img.template = YES;
        return img;
    }

    NSImage *fallback = [NSImage imageNamed:@"document"];
    fallback.template = YES;
    return fallback;
}

// Helper to get target directory URL (prioritizes current folder, with fallback to selected item container)
- (NSURL *)targetDirectoryURL {
    NSURL *targetURL = [[FIFinderSyncController defaultController] targetedURL];
    if (targetURL && targetURL.path.length > 0) {
        return targetURL;
    }
    NSArray<NSURL *> *selectedURLs = [[FIFinderSyncController defaultController] selectedItemURLs];
    if (selectedURLs.count > 0) {
        NSURL *firstSelected = selectedURLs.firstObject;
        NSNumber *isDirectory = nil;
        [firstSelected getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        if ([isDirectory boolValue]) {
            return firstSelected;
        } else {
            return [firstSelected URLByDeletingLastPathComponent];
        }
    }
    return [NSURL fileURLWithPath:NSHomeDirectory()];
}

// Function to copy current directory or selected item path(s) to clipboard
- (void)copyPathToClipboard:(id)sender {
    NSArray<NSURL *> *selectedURLs = [[FIFinderSyncController defaultController] selectedItemURLs];
    NSURL *targetURL = [[FIFinderSyncController defaultController] targetedURL];

    NSMutableArray<NSString *> *paths = [NSMutableArray array];

    if (selectedURLs.count > 0) {
        for (NSURL *url in selectedURLs) {
            NSString *path = url.path;
            if (path.length > 0) {
                [paths addObject:path];
            }
        }
    } else if (targetURL.path.length > 0) {
        [paths addObject:targetURL.path];
    }

    if (paths.count > 0) {
        NSString *result = [paths componentsJoinedByString:@"\n"];
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        [pasteboard setString:result forType:NSPasteboardTypeString];

        NSLog(@"Copied path(s) to clipboard: %@", result);
    }
}

// Function to open Terminal at current directory or directory of selected item
- (void)openTerminalAtPath:(id)sender {
    NSURL *dirURL = [self targetDirectoryURL];

    if (!dirURL || !dirURL.path) {
        NSLog(@"No target URL for Terminal");
        return;
    }

    NSString *path = dirURL.path;
    NSString *escapedPath = [path stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];

    NSString *scriptSource = [NSString stringWithFormat:
        @"do shell script \"open -a Terminal '%@'\"", escapedPath];

    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptSource];
    NSDictionary *errorDict = nil;
    [script executeAndReturnError:&errorDict];

    if (errorDict) {
        NSLog(@"Failed to open Terminal: %@", errorDict);
    } else {
        NSLog(@"Opened Terminal at: %@", path);
    }
}

// Function to create new Word document
- (void)createNewWordDocument:(id)sender {
    NSURL *targetURL = [self targetDirectoryURL];

    if (!targetURL) {
        NSLog(@"No target URL");\
        return;
    }

    // Build unique filename
    NSString *baseName = NSLocalizedString(@"Untitled", nil);
    NSString *extension = @"docx";
    NSString *filePath = [targetURL.path stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@.%@", baseName, extension]];

    NSFileManager *fm = [NSFileManager defaultManager];
    int counter = 1;
    while ([fm fileExistsAtPath:filePath]) {
        NSString *fileName = [NSString stringWithFormat:@"%@ (%d).%@", baseName, counter, extension];
        filePath = [targetURL.path stringByAppendingPathComponent:fileName];
        counter++;
    }

    // Create blank .docx using shell script
    // .docx is a zip file containing XML files
    // Includes styles.xml for Calibri 11pt default font
    NSString *escapedPath = [filePath stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];

    NSString *scriptSource = [NSString stringWithFormat:
        @"do shell script \""
        "TMPDIR=$(mktemp -d) && "
        "mkdir -p \\\"$TMPDIR/_rels\\\" \\\"$TMPDIR/word/_rels\\\" && "
        "echo '<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?><Types xmlns=\\\"http://schemas.openxmlformats.org/package/2006/content-types\\\"><Default Extension=\\\"rels\\\" ContentType=\\\"application/vnd.openxmlformats-package.relationships+xml\\\"/><Default Extension=\\\"xml\\\" ContentType=\\\"application/xml\\\"/><Override PartName=\\\"/word/document.xml\\\" ContentType=\\\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\\\"/><Override PartName=\\\"/word/styles.xml\\\" ContentType=\\\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\\\"/></Types>' > \\\"$TMPDIR/[Content_Types].xml\\\" && "
        "echo '<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?><Relationships xmlns=\\\"http://schemas.openxmlformats.org/package/2006/relationships\\\"><Relationship Id=\\\"rId1\\\" Type=\\\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\\\" Target=\\\"word/document.xml\\\"/></Relationships>' > \\\"$TMPDIR/_rels/.rels\\\" && "
        "echo '<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?><Relationships xmlns=\\\"http://schemas.openxmlformats.org/package/2006/relationships\\\"><Relationship Id=\\\"rId1\\\" Type=\\\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\\\" Target=\\\"styles.xml\\\"/></Relationships>' > \\\"$TMPDIR/word/_rels/document.xml.rels\\\" && "
        "echo '<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?><w:styles xmlns:w=\\\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\\\"><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii=\\\"Calibri\\\" w:hAnsi=\\\"Calibri\\\" w:cs=\\\"Calibri\\\"/><w:sz w:val=\\\"22\\\"/><w:szCs w:val=\\\"22\\\"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after=\\\"0\\\" w:line=\\\"276\\\" w:lineRule=\\\"auto\\\"/></w:pPr></w:pPrDefault></w:docDefaults><w:style w:type=\\\"paragraph\\\" w:default=\\\"1\\\" w:styleId=\\\"Normal\\\"><w:name w:val=\\\"Normal\\\"/><w:rPr><w:rFonts w:ascii=\\\"Calibri\\\" w:hAnsi=\\\"Calibri\\\" w:cs=\\\"Calibri\\\"/><w:sz w:val=\\\"22\\\"/><w:szCs w:val=\\\"22\\\"/></w:rPr></w:style></w:styles>' > \\\"$TMPDIR/word/styles.xml\\\" && "
        "echo '<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?><w:document xmlns:w=\\\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\\\"><w:body><w:p><w:r><w:t></w:t></w:r></w:p></w:body></w:document>' > \\\"$TMPDIR/word/document.xml\\\" && "
        "cd \\\"$TMPDIR\\\" && zip -r '%@' . && "
        "rm -rf \\\"$TMPDIR\\\""
        "\"", escapedPath];

    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptSource];
    NSDictionary *errorDict = nil;
    [script executeAndReturnError:&errorDict];

    if (errorDict) {
        NSLog(@"Failed to create Word document: %@", errorDict);
    } else {
        NSLog(@"Created: %@", filePath);
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[fileURL]];
    }
}

// Function to create new Excel document
- (void)createNewExcelDocument:(id)sender {
    NSURL *targetURL = [self targetDirectoryURL];

    if (!targetURL) {
        NSLog(@"No target URL");
        return;
    }

    // Build unique filename
    NSString *baseName = NSLocalizedString(@"Untitled", nil);
    NSString *extension = @"xlsx";
    NSString *filePath = [targetURL.path stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@.%@", baseName, extension]];

    NSFileManager *fm = [NSFileManager defaultManager];
    int counter = 1;
    while ([fm fileExistsAtPath:filePath]) {
        NSString *fileName = [NSString stringWithFormat:@"%@ (%d).%@", baseName, counter, extension];
        filePath = [targetURL.path stringByAppendingPathComponent:fileName];
        counter++;
    }

    // Create blank .xlsx using shell script
    // .xlsx is a zip file containing XML files
    // Includes styles.xml for Calibri 11pt default font
    NSString *escapedPath = [filePath stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];

    NSString *scriptSource = [NSString stringWithFormat:
        @"do shell script \""
        "TMPDIR=$(mktemp -d) && "
        "mkdir -p \\\"$TMPDIR/_rels\\\" \\\"$TMPDIR/xl/_rels\\\" \\\"$TMPDIR/xl/worksheets\\\" && "
        "echo '<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?><Types xmlns=\\\"http://schemas.openxmlformats.org/package/2006/content-types\\\"><Default Extension=\\\"rels\\\" ContentType=\\\"application/vnd.openxmlformats-package.relationships+xml\\\"/><Default Extension=\\\"xml\\\" ContentType=\\\"application/xml\\\"/><Override PartName=\\\"/xl/workbook.xml\\\" ContentType=\\\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\\\"/><Override PartName=\\\"/xl/worksheets/sheet1.xml\\\" ContentType=\\\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\\\"/><Override PartName=\\\"/xl/styles.xml\\\" ContentType=\\\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\\\"/></Types>' > \\\"$TMPDIR/[Content_Types].xml\\\" && "
        "echo '<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?><Relationships xmlns=\\\"http://schemas.openxmlformats.org/package/2006/relationships\\\"><Relationship Id=\\\"rId1\\\" Type=\\\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\\\" Target=\\\"xl/workbook.xml\\\"/></Relationships>' > \\\"$TMPDIR/_rels/.rels\\\" && "
        "echo '<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?><workbook xmlns=\\\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\\\" xmlns:r=\\\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\\\"><sheets><sheet name=\\\"Sheet1\\\" sheetId=\\\"1\\\" r:id=\\\"rId1\\\"/></sheets></workbook>' > \\\"$TMPDIR/xl/workbook.xml\\\" && "
        "echo '<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?><Relationships xmlns=\\\"http://schemas.openxmlformats.org/package/2006/relationships\\\"><Relationship Id=\\\"rId1\\\" Type=\\\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\\\" Target=\\\"worksheets/sheet1.xml\\\"/><Relationship Id=\\\"rId2\\\" Type=\\\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\\\" Target=\\\"styles.xml\\\"/></Relationships>' > \\\"$TMPDIR/xl/_rels/workbook.xml.rels\\\" && "
        "echo '<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?><styleSheet xmlns=\\\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\\\"><fonts count=\\\"1\\\"><font><sz val=\\\"11\\\"/><name val=\\\"Calibri\\\"/><family val=\\\"2\\\"/></font></fonts><fills count=\\\"2\\\"><fill><patternFill patternType=\\\"none\\\"/></fill><fill><patternFill patternType=\\\"gray125\\\"/></fill></fills><borders count=\\\"1\\\"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count=\\\"1\\\"><xf numFmtId=\\\"0\\\" fontId=\\\"0\\\" fillId=\\\"0\\\" borderId=\\\"0\\\"/></cellStyleXfs><cellXfs count=\\\"1\\\"><xf numFmtId=\\\"0\\\" fontId=\\\"0\\\" fillId=\\\"0\\\" borderId=\\\"0\\\" xfId=\\\"0\\\"/></cellXfs></styleSheet>' > \\\"$TMPDIR/xl/styles.xml\\\" && "
        "echo '<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?><worksheet xmlns=\\\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\\\"><sheetData/></worksheet>' > \\\"$TMPDIR/xl/worksheets/sheet1.xml\\\" && "
        "cd \\\"$TMPDIR\\\" && zip -r '%@' . && "
        "rm -rf \\\"$TMPDIR\\\""
        "\"", escapedPath];

    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptSource];
    NSDictionary *errorDict = nil;
    [script executeAndReturnError:&errorDict];

    if (errorDict) {
        NSLog(@"Failed to create Excel document: %@", errorDict);
    } else {
        NSLog(@"Created: %@", filePath);
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[fileURL]];
    }
}

// Function to create new PowerPoint document
- (void)createNewPowerPointDocument:(id)sender {
    NSURL *targetURL = [self targetDirectoryURL];

    if (!targetURL) {
        NSLog(@"No target URL");
        return;
    }

    // Build unique filename
    NSString *baseName = NSLocalizedString(@"Untitled", nil);
    NSString *extension = @"pptx";
    NSString *filePath = [targetURL.path stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@.%@", baseName, extension]];

    NSFileManager *fm = [NSFileManager defaultManager];
    int counter = 1;
    while ([fm fileExistsAtPath:filePath]) {
        NSString *fileName = [NSString stringWithFormat:@"%@ (%d).%@", baseName, counter, extension];
        filePath = [targetURL.path stringByAppendingPathComponent:fileName];
        counter++;
    }

    // Create blank .pptx using shell script
    // .pptx is a zip file containing XML files
    NSString *escapedPath = [filePath stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];

    NSString *scriptSource = [NSString stringWithFormat:
        @"do shell script \""
        "TMPDIR=$(mktemp -d) && "
        "mkdir -p \\\"$TMPDIR/_rels\\\" \\\"$TMPDIR/ppt/_rels\\\" \\\"$TMPDIR/ppt/slides\\\" \\\"$TMPDIR/ppt/slideLayouts\\\" \\\"$TMPDIR/ppt/slideMasters\\\" && "
        "echo '<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?><Types xmlns=\\\"http://schemas.openxmlformats.org/package/2006/content-types\\\"><Default Extension=\\\"rels\\\" ContentType=\\\"application/vnd.openxmlformats-package.relationships+xml\\\"/><Default Extension=\\\"xml\\\" ContentType=\\\"application/xml\\\"/><Override PartName=\\\"/ppt/presentation.xml\\\" ContentType=\\\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\\\"/><Override PartName=\\\"/ppt/slides/slide1.xml\\\" ContentType=\\\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\\\"/></Types>' > \\\"$TMPDIR/[Content_Types].xml\\\" && "
        "echo '<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?><Relationships xmlns=\\\"http://schemas.openxmlformats.org/package/2006/relationships\\\"><Relationship Id=\\\"rId1\\\" Type=\\\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\\\" Target=\\\"ppt/presentation.xml\\\"/></Relationships>' > \\\"$TMPDIR/_rels/.rels\\\" && "
        "echo '<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?><p:presentation xmlns:p=\\\"http://schemas.openxmlformats.org/presentationml/2006/main\\\" xmlns:r=\\\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\\\"><p:sldIdLst><p:sldId id=\\\"256\\\" r:id=\\\"rId1\\\"/></p:sldIdLst></p:presentation>' > \\\"$TMPDIR/ppt/presentation.xml\\\" && "
        "echo '<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?><Relationships xmlns=\\\"http://schemas.openxmlformats.org/package/2006/relationships\\\"><Relationship Id=\\\"rId1\\\" Type=\\\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\\\" Target=\\\"slides/slide1.xml\\\"/></Relationships>' > \\\"$TMPDIR/ppt/_rels/presentation.xml.rels\\\" && "
        "echo '<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?><p:sld xmlns:p=\\\"http://schemas.openxmlformats.org/presentationml/2006/main\\\"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id=\\\"1\\\" name=\\\"\\\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/></p:spTree></p:cSld></p:sld>' > \\\"$TMPDIR/ppt/slides/slide1.xml\\\" && "
        "cd \\\"$TMPDIR\\\" && zip -r '%@' . && "
        "rm -rf \\\"$TMPDIR\\\""
        "\"", escapedPath];

    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptSource];
    NSDictionary *errorDict = nil;
    [script executeAndReturnError:&errorDict];

    if (errorDict) {
        NSLog(@"Failed to create PowerPoint document: %@", errorDict);
    } else {
        NSLog(@"Created: %@", filePath);
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[fileURL]];
    }
}

// Function to create new Pages document
- (void)createNewPagesDocument:(id)sender {
    NSURL *targetURL = [self targetDirectoryURL];

    if (!targetURL) {
        NSLog(@"No target URL");
        return;
    }

    // Build unique filename
    NSString *baseName = NSLocalizedString(@"Untitled", nil);
    NSString *extension = @"pages";
    NSString *filePath = [targetURL.path stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@.%@", baseName, extension]];

    NSFileManager *fm = [NSFileManager defaultManager];
    int counter = 1;
    while ([fm fileExistsAtPath:filePath]) {
        NSString *fileName = [NSString stringWithFormat:@"%@ (%d).%@", baseName, counter, extension];
        filePath = [targetURL.path stringByAppendingPathComponent:fileName];
        counter++;
    }

    // Get the blank template from the bundle
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *templatePath = [bundle pathForResource:@"Blank" ofType:@"pages"];

    if (!templatePath) {
        NSLog(@"Failed to find Blank.pages template in bundle");
        return;
    }

    // Copy template to destination using AppleScript (to bypass sandbox)
    NSString *escapedTemplate = [templatePath stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
    NSString *escapedDest = [filePath stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];

    NSString *scriptSource = [NSString stringWithFormat:
        @"do shell script \"cp -R '%@' '%@'\"", escapedTemplate, escapedDest];

    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptSource];
    NSDictionary *errorDict = nil;
    [script executeAndReturnError:&errorDict];

    if (errorDict) {
        NSLog(@"Failed to create Pages document: %@", errorDict);
    } else {
        NSLog(@"Created: %@", filePath);
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[fileURL]];
    }
}

// Function to create new Numbers document
- (void)createNewNumbersDocument:(id)sender {
    NSURL *targetURL = [self targetDirectoryURL];

    if (!targetURL) {
        NSLog(@"No target URL");
        return;
    }

    // Build unique filename
    NSString *baseName = NSLocalizedString(@"Untitled", nil);
    NSString *extension = @"numbers";
    NSString *filePath = [targetURL.path stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@.%@", baseName, extension]];

    NSFileManager *fm = [NSFileManager defaultManager];
    int counter = 1;
    while ([fm fileExistsAtPath:filePath]) {
        NSString *fileName = [NSString stringWithFormat:@"%@ (%d).%@", baseName, counter, extension];
        filePath = [targetURL.path stringByAppendingPathComponent:fileName];
        counter++;
    }

    // Get the blank template from the bundle
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *templatePath = [bundle pathForResource:@"Blank" ofType:@"numbers"];

    if (!templatePath) {
        NSLog(@"Failed to find Blank.numbers template in bundle");
        return;
    }

    // Copy template to destination using AppleScript (to bypass sandbox)
    NSString *escapedTemplate = [templatePath stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
    NSString *escapedDest = [filePath stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];

    NSString *scriptSource = [NSString stringWithFormat:
        @"do shell script \"cp -R '%@' '%@'\"", escapedTemplate, escapedDest];

    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptSource];
    NSDictionary *errorDict = nil;
    [script executeAndReturnError:&errorDict];

    if (errorDict) {
        NSLog(@"Failed to create Numbers document: %@", errorDict);
    } else {
        NSLog(@"Created: %@", filePath);
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[fileURL]];
    }
}

// Function to create new Keynote document
- (void)createNewKeynoteDocument:(id)sender {
    NSURL *targetURL = [self targetDirectoryURL];

    if (!targetURL) {
        NSLog(@"No target URL");
        return;
    }

    // Build unique filename
    NSString *baseName = NSLocalizedString(@"Untitled", nil);
    NSString *extension = @"key";
    NSString *filePath = [targetURL.path stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@.%@", baseName, extension]];

    NSFileManager *fm = [NSFileManager defaultManager];
    int counter = 1;
    while ([fm fileExistsAtPath:filePath]) {
        NSString *fileName = [NSString stringWithFormat:@"%@ (%d).%@", baseName, counter, extension];
        filePath = [targetURL.path stringByAppendingPathComponent:fileName];
        counter++;
    }

    // Get the blank template from the bundle
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *templatePath = [bundle pathForResource:@"Blank" ofType:@"key"];

    if (!templatePath) {
        NSLog(@"Failed to find Blank.key template in bundle");
        return;
    }

    // Copy template to destination using AppleScript (to bypass sandbox)
    NSString *escapedTemplate = [templatePath stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
    NSString *escapedDest = [filePath stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];

    NSString *scriptSource = [NSString stringWithFormat:
        @"do shell script \"cp -R '%@' '%@'\"", escapedTemplate, escapedDest];

    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptSource];
    NSDictionary *errorDict = nil;
    [script executeAndReturnError:&errorDict];

    if (errorDict) {
        NSLog(@"Failed to create Keynote document: %@", errorDict);
    } else {
        NSLog(@"Created: %@", filePath);
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[fileURL]];
    }
}

// Function to create new JSON file
- (void)createNewJSONFile:(id)sender {
    [self createFileWithExtension:@"json" initialContent:@"{\n  \n}\n"];
}

// Function to create new text file
- (void)createNewTextFile:(id)sender {
    [self createFileWithExtension:@"txt" initialContent:@""];
}

// Function to create new Markdown file
- (void)createNewMarkdownFile:(id)sender {
    [self createFileWithExtension:@"md" initialContent:@""];
}

// Helper function to create empty files or files with initial content
- (void)createFileWithExtension:(NSString *)extension initialContent:(NSString *)content {
    NSURL *targetURL = [self targetDirectoryURL];

    if (!targetURL) {
        NSLog(@"No target URL");
        return;
    }

    // Create filename
    NSString *baseName = NSLocalizedString(@"Untitled", nil);
    NSString *filePath = [targetURL.path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", baseName, extension]];

    // If "Untitled" already exists, add a number to it
    NSFileManager *fm = [NSFileManager defaultManager];
    int counter = 1;

    while ([fm fileExistsAtPath:filePath]) {
        NSString *fileName = [NSString stringWithFormat:@"%@ (%d).%@", baseName, counter, extension];
        filePath = [targetURL.path stringByAppendingPathComponent:fileName];
        counter++;
    }

    // Use AppleScript to create a new file and bypass sandboxing permissions
    NSString *escapedPath = [filePath stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
    NSString *scriptSource;
    if (content && content.length > 0) {
        NSString *escapedContent = [content stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        escapedContent = [escapedContent stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        escapedContent = [escapedContent stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        scriptSource = [NSString stringWithFormat:@"do shell script \"printf '%%b' \\\"%@\\\" > '%@'\"", escapedContent, escapedPath];
    } else {
        scriptSource = [NSString stringWithFormat:@"do shell script \"touch '%@'\"", escapedPath];
    }

    // Run AppleScript
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptSource];
    NSDictionary *errorDict = nil;
    [script executeAndReturnError:&errorDict];

    if (errorDict) {
        NSLog(@"Failed: %@", errorDict);
    } else {
        NSLog(@"Created: %@", filePath);
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[fileURL]];
    }
}


#pragma mark - Image & PDF Operations

+ (BOOL)convertImageAtURL:(NSURL *)sourceURL toType:(CFStringRef)destType outputExtension:(NSString *)newExt createdURL:(NSURL **)outURL quality:(NSNumber *)quality {
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)sourceURL, NULL);
    if (!source) return NO;

    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    CFRelease(source);
    if (!imageRef) return NO;

    NSString *origDir = sourceURL.URLByDeletingLastPathComponent.path;
    NSString *baseName = [sourceURL.lastPathComponent stringByDeletingPathExtension];
    if (quality && [newExt isEqualToString:sourceURL.pathExtension.lowercaseString]) {
        baseName = [baseName stringByAppendingString:@"_compressed"];
    }

    NSString *destPath = [origDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", baseName, newExt]];
    NSFileManager *fm = [NSFileManager defaultManager];
    int counter = 1;
    while ([fm fileExistsAtPath:destPath]) {
        destPath = [origDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ (%d).%@", baseName, counter, newExt]];
        counter++;
    }

    NSURL *destURL = [NSURL fileURLWithPath:destPath];
    CGImageDestinationRef dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)destURL, destType, 1, NULL);
    if (!dest) {
        CGImageRelease(imageRef);
        return NO;
    }

    NSDictionary *props = nil;
    if (quality) {
        props = @{ (__bridge NSString *)kCGImageDestinationLossyCompressionQuality: quality };
    }
    CGImageDestinationAddImage(dest, imageRef, (__bridge CFDictionaryRef)props);
    BOOL success = CGImageDestinationFinalize(dest);
    CFRelease(dest);
    CGImageRelease(imageRef);

    if (success && outURL) {
        *outURL = destURL;
    }
    return success;
}

+ (NSURL *)createPDFFromItems:(NSArray<NSURL *> *)urls inDirectory:(NSString *)dir {
    PDFDocument *pdfDoc = [[PDFDocument alloc] init];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *baseName = NSLocalizedString(@"Images", nil);
    BOOL hasOnlyPDFs = YES;
    for (NSURL *u in urls) {
        if (![u.pathExtension.lowercaseString isEqualToString:@"pdf"]) {
            hasOnlyPDFs = NO;
            break;
        }
    }
    if (hasOnlyPDFs) {
        baseName = NSLocalizedString(@"Combined", nil);
    } else if (urls.count == 1) {
        baseName = [urls.firstObject.lastPathComponent stringByDeletingPathExtension];
    }

    NSString *destPath = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.pdf", baseName]];
    int counter = 1;
    while ([fm fileExistsAtPath:destPath]) {
        destPath = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ (%d).pdf", baseName, counter]];
        counter++;
    }

    NSUInteger pageIdx = 0;
    for (NSURL *url in urls) {
        NSString *ext = url.pathExtension.lowercaseString;
        if ([ext isEqualToString:@"pdf"]) {
            PDFDocument *srcDoc = [[PDFDocument alloc] initWithURL:url];
            if (srcDoc) {
                for (NSUInteger i = 0; i < srcDoc.pageCount; i++) {
                    PDFPage *p = [srcDoc pageAtIndex:i];
                    if (p) {
                        [pdfDoc insertPage:p atIndex:pageIdx++];
                    }
                }
            }
        } else if ([FTImageExtensions() containsObject:ext]) {
            NSImage *img = [[NSImage alloc] initWithContentsOfURL:url];
            if (img) {
                PDFPage *page = [[PDFPage alloc] initWithImage:img];
                if (page) {
                    [pdfDoc insertPage:page atIndex:pageIdx++];
                }
            }
        }
    }

    if (pdfDoc.pageCount > 0) {
        NSURL *destURL = [NSURL fileURLWithPath:destPath];
        if ([pdfDoc writeToURL:destURL]) {
            return destURL;
        }
    }
    return nil;
}

+ (NSURL *)compressPDFAtURL:(NSURL *)pdfURL {
    PDFDocument *srcDoc = [[PDFDocument alloc] initWithURL:pdfURL];
    if (!srcDoc || srcDoc.pageCount == 0) return nil;

    NSString *dir = pdfURL.URLByDeletingLastPathComponent.path;
    NSString *base = [pdfURL.lastPathComponent stringByDeletingPathExtension];
    NSString *newName = [base stringByAppendingString:@"_compressed"];

    NSString *destPath = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.pdf", newName]];
    NSFileManager *fm = [NSFileManager defaultManager];
    int counter = 1;
    while ([fm fileExistsAtPath:destPath]) {
        destPath = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ (%d).pdf", newName, counter]];
        counter++;
    }

    NSURL *filterURL = [NSURL fileURLWithPath:@"/System/Library/Filters/Reduce File Size.qfilter"];
    QuartzFilter *filter = [QuartzFilter quartzFilterWithURL:filterURL];
    NSDictionary *options = filter ? @{ @"QuartzFilter": filter } : @{};

    if ([srcDoc writeToFile:destPath withOptions:options]) {
        return [NSURL fileURLWithPath:destPath];
    }
    return nil;
}

- (void)convertSelectedImagesToPNG:(id)sender {
    [self convertSelectedImagesToType:CFSTR("public.png") extension:@"png" quality:nil];
}

- (void)convertSelectedImagesToJPEG:(id)sender {
    [self convertSelectedImagesToType:CFSTR("public.jpeg") extension:@"jpg" quality:nil];
}

- (void)convertSelectedImagesToHEIC:(id)sender {
    [self convertSelectedImagesToType:CFSTR("public.heic") extension:@"heic" quality:nil];
}

- (void)compressSelectedImages:(id)sender {
    [self convertSelectedImagesToType:CFSTR("public.jpeg") extension:@"jpg" quality:@(0.75)];
}

- (void)convertSelectedImagesToType:(CFStringRef)destType extension:(NSString *)ext quality:(NSNumber *)quality {
    NSArray<NSURL *> *selectedURLs = [[FIFinderSyncController defaultController] selectedItemURLs];
    if (selectedURLs.count == 0) return;

    BOOL trashOriginals = FTIsPreferenceEnabled(@"TrashOriginalsAfterConversionInFinder", YES);
    NSMutableArray<NSURL *> *createdURLs = [NSMutableArray array];
    NSMutableArray<NSURL *> *trashedURLs = [NSMutableArray array];

    for (NSURL *sourceURL in selectedURLs) {
        NSString *sourceExt = sourceURL.pathExtension.lowercaseString;
        if (![FTImageExtensions() containsObject:sourceExt]) continue;

        NSURL *outURL = nil;
        if ([FinderSync convertImageAtURL:sourceURL toType:destType outputExtension:ext createdURL:&outURL quality:quality]) {
            if (outURL) {
                [createdURLs addObject:outURL];
                if (trashOriginals && ![sourceURL.path isEqualToString:outURL.path]) {
                    [trashedURLs addObject:sourceURL];
                }
            }
        }
    }

    // Move successfully converted originals to Trash
    if (trashedURLs.count > 0) {
        for (NSURL *u in trashedURLs) {
            [[NSFileManager defaultManager] trashItemAtURL:u resultingItemURL:nil error:nil];
        }
    }

    // converted files created silently — no Finder activation
    (void)createdURLs;
}

- (void)combineSelectedIntoPDF:(id)sender {
    NSArray<NSURL *> *selectedURLs = [[FIFinderSyncController defaultController] selectedItemURLs];
    if (selectedURLs.count == 0) return;

    NSURL *targetDir = [self targetDirectoryURL];
    if (!targetDir) {
        targetDir = selectedURLs.firstObject.URLByDeletingLastPathComponent;
    }

    NSURL *createdPDF = [FinderSync createPDFFromItems:selectedURLs inDirectory:targetDir.path];
    // PDF created silently — no Finder activation
    (void)createdPDF;
}

- (void)compressSelectedPDF:(id)sender {
    NSArray<NSURL *> *selectedURLs = [[FIFinderSyncController defaultController] selectedItemURLs];
    if (selectedURLs.count == 0) return;

    NSMutableArray<NSURL *> *createdURLs = [NSMutableArray array];
    for (NSURL *url in selectedURLs) {
        if (![url.pathExtension.lowercaseString isEqualToString:@"pdf"]) continue;
        NSURL *compressed = [FinderSync compressPDFAtURL:url];
        if (compressed) {
            [createdURLs addObject:compressed];
        }
    }
    // compressed silently — no Finder activation
    (void)createdURLs;
}


#pragma mark - Video Operations

+ (NSString *)uniqueVideoPathInDirectory:(NSString *)dir baseName:(NSString *)base extension:(NSString *)ext {
    NSString *path = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", base, ext]];
    NSFileManager *fm = [NSFileManager defaultManager];
    int counter = 1;
    while ([fm fileExistsAtPath:path]) {
        path = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ (%d).%@", base, counter, ext]];
        counter++;
    }
    return path;
}

+ (void)exportVideoAtURL:(NSURL *)sourceURL
              presetName:(NSString *)presetName
              outputType:(AVFileType)fileType
            outputExtension:(NSString *)outExt
                  suffix:(NSString *)suffix
       completionHandler:(void (^)(NSURL *outURL, NSError *error))completion {

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:sourceURL options:nil];
    NSString *dir = sourceURL.URLByDeletingLastPathComponent.path;
    NSString *base = [sourceURL.lastPathComponent stringByDeletingPathExtension];
    NSString *outPath = [FinderSync uniqueVideoPathInDirectory:dir baseName:[base stringByAppendingString:suffix] extension:outExt];
    NSURL *outURL = [NSURL fileURLWithPath:outPath];

    AVAssetExportSession *session = [AVAssetExportSession exportSessionWithAsset:asset presetName:presetName];
    if (!session) {
        NSError *err = [NSError errorWithDomain:@"FinderToys" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Cannot create export session for this file"}];
        completion(nil, err);
        return;
    }
    session.outputURL = outURL;
    session.outputFileType = fileType;
    session.shouldOptimizeForNetworkUse = YES; // equivalent to -movflags +faststart

    [session exportAsynchronouslyWithCompletionHandler:^{
        if (session.status == AVAssetExportSessionStatusCompleted) {
            completion(outURL, nil);
        } else {
            [[NSFileManager defaultManager] removeItemAtURL:outURL error:nil];
            completion(nil, session.error);
        }
    }];
}

// Real compression via AVAssetWriter — explicit H.264 bitrate control
// Equivalent to: ffmpeg -c:v libx264 -preset fast -crf 22 -c:a aac -b:a 128k
+ (void)compressVideoWithAssetWriter:(NSURL *)sourceURL
                    completionHandler:(void (^)(NSURL *outURL, NSError *error))completion {

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:sourceURL options:nil];
    NSString *dir = sourceURL.URLByDeletingLastPathComponent.path;
    NSString *base = [sourceURL.lastPathComponent stringByDeletingPathExtension];
    NSString *outPath = [FinderSync uniqueVideoPathInDirectory:dir baseName:[base stringByAppendingString:@"_compressed"] extension:@"mp4"];
    NSURL *outURL = [NSURL fileURLWithPath:outPath];

    // Load tracks
    // Use loadValuesAsynchronouslyForKeys to avoid deprecated synchronous track loading on macOS 15+
    dispatch_semaphore_t loadSem = dispatch_semaphore_create(0);
    [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{ dispatch_semaphore_signal(loadSem); }];
    dispatch_semaphore_wait(loadSem, DISPATCH_TIME_FOREVER);

    NSError *trackError = nil;
    AVKeyValueStatus status = [asset statusOfValueForKey:@"tracks" error:&trackError];
    if (status != AVKeyValueStatusLoaded) {
        completion(nil, trackError ?: [NSError errorWithDomain:@"FinderToys" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Failed to load asset tracks"}]);
        return;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    AVAssetTrack *audioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
#pragma clang diagnostic pop

    if (!videoTrack) {
        completion(nil, [NSError errorWithDomain:@"FinderToys" code:2 userInfo:@{NSLocalizedDescriptionKey: @"No video track found"}]);
        return;
    }

    // ---- Determine target bitrate ----
    // Adaptive: ~6 Mbps for 1080p, scales with pixel count (mirrors CRF 22 libx264)
    CGSize naturalSize = videoTrack.naturalSize;
    CGAffineTransform t = videoTrack.preferredTransform;
    CGSize displaySize = CGSizeApplyAffineTransform(naturalSize, t);
    CGFloat w = ABS(displaySize.width);
    CGFloat h = ABS(displaySize.height);
    if (w == 0 || h == 0) { w = naturalSize.width; h = naturalSize.height; }

    CGFloat megapixels = (w * h) / 1000000.0;
    // 6 Mbps @ 2.07 MP (1080p), linear scale clamped to 2–40 Mbps
    NSInteger videoBitrate = (NSInteger)MAX(2000000, MIN(40000000, megapixels * 2896000));

    NSDictionary *videoSettings = @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(naturalSize.width),
        AVVideoHeightKey: @(naturalSize.height),
        AVVideoCompressionPropertiesKey: @{
            AVVideoAverageBitRateKey: @(videoBitrate),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
            AVVideoMaxKeyFrameIntervalKey: @60,
            AVVideoAllowFrameReorderingKey: @YES,
        }
    };

    NSDictionary *audioSettings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @44100,
        AVNumberOfChannelsKey: @2,
        AVEncoderBitRateKey: @128000,
    };

    // ---- Setup reader ----
    NSError *readerError = nil;
    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:&readerError];
    if (!reader) { completion(nil, readerError); return; }

    AVAssetReaderTrackOutput *videoOutput = [AVAssetReaderTrackOutput
        assetReaderTrackOutputWithTrack:videoTrack
        outputSettings:@{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)}];
    videoOutput.alwaysCopiesSampleData = NO;
    [reader addOutput:videoOutput];

    AVAssetReaderTrackOutput *audioOutput = nil;
    if (audioTrack) {
        audioOutput = [AVAssetReaderTrackOutput
            assetReaderTrackOutputWithTrack:audioTrack
            outputSettings:@{AVFormatIDKey: @(kAudioFormatLinearPCM)}];
        audioOutput.alwaysCopiesSampleData = NO;
        [reader addOutput:audioOutput];
    }

    // ---- Setup writer ----
    NSError *writerError = nil;
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:outURL fileType:AVFileTypeMPEG4 error:&writerError];
    if (!writer) { completion(nil, writerError); return; }
    writer.shouldOptimizeForNetworkUse = YES; // -movflags +faststart

    AVAssetWriterInput *videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    videoInput.transform = videoTrack.preferredTransform;
    videoInput.expectsMediaDataInRealTime = NO;
    [writer addInput:videoInput];

    AVAssetWriterInput *audioInput = nil;
    if (audioTrack) {
        audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
        audioInput.expectsMediaDataInRealTime = NO;
        [writer addInput:audioInput];
    }

    [reader startReading];
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];

    dispatch_queue_t videoQ = dispatch_queue_create("com.findertoys.video.compress.video", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t audioQ = dispatch_queue_create("com.findertoys.video.compress.audio", DISPATCH_QUEUE_SERIAL);
    dispatch_group_t group = dispatch_group_create();

    // Write video
    dispatch_group_enter(group);
    [videoInput requestMediaDataWhenReadyOnQueue:videoQ usingBlock:^{
        while (videoInput.isReadyForMoreMediaData) {
            CMSampleBufferRef sample = [videoOutput copyNextSampleBuffer];
            if (sample) {
                [videoInput appendSampleBuffer:sample];
                CFRelease(sample);
            } else {
                [videoInput markAsFinished];
                dispatch_group_leave(group);
                return;
            }
        }
    }];

    // Write audio
    if (audioInput && audioOutput) {
        dispatch_group_enter(group);
        [audioInput requestMediaDataWhenReadyOnQueue:audioQ usingBlock:^{
            while (audioInput.isReadyForMoreMediaData) {
                CMSampleBufferRef sample = [audioOutput copyNextSampleBuffer];
                if (sample) {
                    [audioInput appendSampleBuffer:sample];
                    CFRelease(sample);
                } else {
                    [audioInput markAsFinished];
                    dispatch_group_leave(group);
                    return;
                }
            }
        }];
    }

    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [writer finishWritingWithCompletionHandler:^{
            if (writer.status == AVAssetWriterStatusCompleted) {
                completion(outURL, nil);
            } else {
                [[NSFileManager defaultManager] removeItemAtURL:outURL error:nil];
                completion(nil, writer.error);
            }
        }];
    });
}

- (void)compressSelectedVideos:(id)sender {
    NSArray<NSURL *> *selectedURLs = [[FIFinderSyncController defaultController] selectedItemURLs];
    if (selectedURLs.count == 0) return;

    BOOL trashOriginals = FTIsPreferenceEnabled(@"TrashOriginalsAfterConversionInFinder", YES);
    NSMutableArray<NSURL *> *videoURLs = [NSMutableArray array];
    for (NSURL *url in selectedURLs) {
        if ([FTVideoExtensions() containsObject:url.pathExtension.lowercaseString]) {
            [videoURLs addObject:url];
        }
    }
    if (videoURLs.count == 0) return;

    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<NSURL *> *toTrash = [NSMutableArray array];

    for (NSURL *sourceURL in videoURLs) {
        dispatch_group_enter(group);
        [FinderSync compressVideoWithAssetWriter:sourceURL completionHandler:^(NSURL *outURL, NSError *error) {
            if (outURL && trashOriginals) {
                @synchronized(toTrash) { [toTrash addObject:sourceURL]; }
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSURL *u in toTrash) {
            [[NSFileManager defaultManager] trashItemAtURL:u resultingItemURL:nil error:nil];
        }
    });
}

- (void)convertSelectedVideosToMP4:(id)sender {
    [self processSelectedVideosWithPreset:AVAssetExportPresetHighestQuality
                               fileType:AVFileTypeMPEG4
                              extension:@"mp4"
                                 suffix:@""];
}

- (void)convertSelectedVideosToMOV:(id)sender {
    [self processSelectedVideosWithPreset:AVAssetExportPresetHighestQuality
                               fileType:AVFileTypeQuickTimeMovie
                              extension:@"mov"
                                 suffix:@""];
}

- (void)processSelectedVideosWithPreset:(NSString *)preset
                               fileType:(AVFileType)fileType
                              extension:(NSString *)ext
                                 suffix:(NSString *)suffix {
    NSArray<NSURL *> *selectedURLs = [[FIFinderSyncController defaultController] selectedItemURLs];
    if (selectedURLs.count == 0) return;

    BOOL trashOriginals = FTIsPreferenceEnabled(@"TrashOriginalsAfterConversionInFinder", YES);

    NSMutableArray<NSURL *> *videoURLs = [NSMutableArray array];
    for (NSURL *url in selectedURLs) {
        if ([FTVideoExtensions() containsObject:url.pathExtension.lowercaseString]) {
            [videoURLs addObject:url];
        }
    }
    if (videoURLs.count == 0) return;

    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<NSURL *> *createdURLs = [NSMutableArray array];
    NSMutableArray<NSURL *> *toTrash = [NSMutableArray array];
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    for (NSURL *sourceURL in videoURLs) {
        dispatch_group_enter(group);
        NSString *sourceSuffix = suffix.length > 0 ? suffix : @"_conv";
        // For pure format conversion (no suffix), keep base name but change ext
        NSString *actualSuffix = suffix;
        if (suffix.length == 0) {
            // Same name, different extension — skip if source already matches output ext
            if ([sourceURL.pathExtension.lowercaseString isEqualToString:ext]) {
                dispatch_group_leave(group);
                continue;
            }
            actualSuffix = @"";
        }
        (void)sourceSuffix;

        [FinderSync exportVideoAtURL:sourceURL
                          presetName:preset
                          outputType:fileType
                    outputExtension:ext
                              suffix:actualSuffix
                   completionHandler:^(NSURL *outURL, NSError *error) {
            if (outURL) {
                @synchronized(createdURLs) {
                    [createdURLs addObject:outURL];
                    if (trashOriginals && ![sourceURL.path isEqualToString:outURL.path]) {
                        [toTrash addObject:sourceURL];
                    }
                }
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, q, ^{
        for (NSURL *u in toTrash) {
            [[NSFileManager defaultManager] trashItemAtURL:u resultingItemURL:nil error:nil];
        }
        if (createdURLs.count > 0) {
            // video converted silently — no Finder activation
        (void)createdURLs;
        }
    });
}

@end
