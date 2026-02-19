//go:build darwin

package notifier

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework ApplicationServices -framework AppKit
#include <stdlib.h>
#include <string.h>
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

static int findPID(const char *bundleID) {
	@autoreleasepool {
		NSString *bid = [NSString stringWithUTF8String:bundleID];
		NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:bid];
		if (!apps || apps.count == 0) return -1;
		return (int)((NSRunningApplication *)apps[0]).processIdentifier;
	}
}

static void activateByPID(int pid) {
	@autoreleasepool {
		NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:(pid_t)pid];
		if (app) [app activateWithOptions:0];
	}
}

// raiseWindowByTitle enumerates AXWindows for the given PID and raises the
// first window whose AXTitle contains folderName. Returns 1 on success.
// NOTE: AXWindows only populates after the app has been activated; callers
// must call activateByPID and wait before calling this function.
static int raiseWindowByTitle(int pid, const char *folderName) {
	AXUIElementRef appEl = AXUIElementCreateApplication((pid_t)pid);
	if (!appEl) return 0;

	CFTypeRef windowsRef = NULL;
	if (AXUIElementCopyAttributeValue(appEl, CFSTR("AXWindows"), &windowsRef) != kAXErrorSuccess || !windowsRef) {
		CFRelease(appEl);
		return 0;
	}

	CFArrayRef windows = (CFArrayRef)windowsRef;
	CFIndex count = CFArrayGetCount(windows);
	int found = 0;

	for (CFIndex i = 0; i < count; i++) {
		AXUIElementRef w = (AXUIElementRef)CFArrayGetValueAtIndex(windows, i);
		CFTypeRef titleRef = NULL;
		if (AXUIElementCopyAttributeValue(w, CFSTR("AXTitle"), &titleRef) != kAXErrorSuccess) continue;

		char buf[2048] = {0};
		CFStringGetCString((CFStringRef)titleRef, buf, sizeof(buf), kCFStringEncodingUTF8);
		CFRelease(titleRef);

		if (strstr(buf, folderName) != NULL) {
			AXUIElementPerformAction(w, CFSTR("AXRaise"));
			AXUIElementSetAttributeValue(appEl, CFSTR("AXFrontmost"), kCFBooleanTrue);
			found = 1;
			break;
		}
	}

	CFRelease(windowsRef);
	CFRelease(appEl);
	return found;
}
*/
import "C"

import (
	"fmt"
	"path/filepath"
	"time"
	"unsafe"
)

// FocusAppWindow activates the bundleID app and raises the first window whose
// AXTitle contains the base name of cwd. macOS only.
func FocusAppWindow(bundleID, cwd string) error {
	cBundleID := C.CString(bundleID)
	defer C.free(unsafe.Pointer(cBundleID))

	pid := int(C.findPID(cBundleID))
	if pid < 0 {
		return fmt.Errorf("app not running: %s", bundleID)
	}

	C.activateByPID(C.int(pid))
	time.Sleep(800 * time.Millisecond)

	folderName := filepath.Base(cwd)
	if folderName == "" || folderName == "." || folderName == string(filepath.Separator) {
		return fmt.Errorf("invalid cwd: %s", cwd)
	}
	cFolder := C.CString(folderName)
	defer C.free(unsafe.Pointer(cFolder))
	C.raiseWindowByTitle(C.int(pid), cFolder)
	return nil
}
