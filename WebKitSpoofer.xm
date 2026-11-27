#import <WebKit/WebKit.h>
#import <substrate.h>

static NSString *jsSpoof = @"\
Object.defineProperty(navigator, 'hardwareConcurrency', { get: function() { return 4; } });\
const getParameter = WebGLRenderingContext.prototype.getParameter;\
WebGLRenderingContext.prototype.getParameter = function(parameter) {\
    if (parameter === 37445) return 'Apple Inc.';\
    if (parameter === 37446) return 'Apple GPU';\
    return getParameter.apply(this, [parameter]);\
};\
HTMLCanvasElement.prototype.toDataURL = function() { return 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='; };\
";

%hook WKWebView
- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler {
    NSString *newJS = [jsSpoof stringByAppendingString:javaScriptString ?: @""];
    %orig(newJS, completionHandler);
}
%end
