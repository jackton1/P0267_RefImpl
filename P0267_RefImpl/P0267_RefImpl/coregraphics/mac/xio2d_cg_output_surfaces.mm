#include "xio2d_cg_output_surfaces.h"
#include <Cocoa/Cocoa.h>
#include <iostream>

static const auto g_WindowTitle = @"IO2D/CoreGraphics managed output surface"; 

@interface _IO2DOutputView : NSView

@property (nonatomic, readwrite) std::experimental::io2d::_CoreGraphics::_GS::surfaces::_OutputSurfaceCocoa *data;

@end

namespace std::experimental::io2d { inline namespace v1 { namespace _CoreGraphics {

struct _GS::surfaces::_OutputSurfaceCocoa
{
    using context_t = remove_pointer_t<CGContextRef>;
    
    NSWindow *window = nullptr;
    unique_ptr<context_t, decltype(&CGContextRelease)> draw_buffer{ nullptr, &CGContextRelease };
    basic_display_point<GraphicsMath> buffer_size;
    _IO2DOutputView *output_view = nullptr;
    function<void(basic_output_surface<_GS>&)> draw_callback;
    function<void(basic_output_surface<_GS>&)> size_change_callback;
    basic_output_surface<_GS> *frontend;

    bool auto_clear = false;
    io2d::format preferred_format;
    io2d::refresh_style refresh_style;
    float fps;
};
    
static void RebuildBackBuffer(_GS::surfaces::_OutputSurfaceCocoa &context, basic_display_point<GraphicsMath> new_dimensions );

_GS::surfaces::output_surface_data_type _GS::surfaces::create_output_surface(int preferredWidth, int preferredHeight, io2d::format preferredFormat, io2d::scaling scl, io2d::refresh_style rr, float fps)
{
    error_code ec;
    auto data = create_output_surface(preferredWidth, preferredHeight, preferredFormat, ec, scl, rr, fps);
    if( ec )
        throw system_error(ec);
    return data;
}
    
_GS::surfaces::output_surface_data_type _GS::surfaces::create_output_surface(int preferredWidth, int preferredHeight, io2d::format preferredFormat, error_code& ec, io2d::scaling scl, io2d::refresh_style rr, float fps) noexcept
{
    return create_output_surface(preferredWidth, preferredHeight, preferredFormat, -1, -1, ec, scl, rr, fps);
}
    
_GS::surfaces::output_surface_data_type _GS::surfaces::create_output_surface(int preferredWidth, int preferredHeight, io2d::format preferredFormat, int preferredDisplayWidth, int preferredDisplayHeight, io2d::scaling scl, io2d::refresh_style rr, float fps)
{
    error_code ec;
    auto data = create_output_surface(preferredWidth, preferredHeight, preferredFormat, preferredDisplayWidth, preferredDisplayHeight, ec, scl, rr, fps);
    if( ec )
        throw system_error(ec);
    return data;
}

_GS::surfaces::output_surface_data_type _GS::surfaces::create_output_surface(int preferredWidth, int preferredHeight, io2d::format preferredFormat, int preferredDisplayWidth, int preferredDisplayHeight, error_code& ec, io2d::scaling scl, io2d::refresh_style rr, float fps) noexcept
{
    auto ctx = make_unique<_OutputSurfaceCocoa>();
    auto style = NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable;
    ctx->window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, preferredWidth, preferredHeight)
                                              styleMask:style
                                                backing:NSBackingStoreBuffered
                                                  defer:false];
    ctx->window.title = g_WindowTitle;
    ctx->output_view = [[_IO2DOutputView alloc] initWithFrame:ctx->window.contentView.bounds];
    ctx->output_view.data = ctx.get();
    ctx->window.contentView = ctx->output_view;
    ctx->preferred_format = preferredFormat;
    ctx->refresh_style = rr;
    ctx->fps = fps;
    RebuildBackBuffer(*ctx, {preferredWidth, preferredHeight});
    
    return ctx.release();
}
    
_GS::surfaces::output_surface_data_type _GS::surfaces::move_output_surface(output_surface_data_type&& data) noexcept
{
    auto moved_data = data;
    data = nullptr;
    return moved_data;
}
    
void _GS::surfaces::destroy(output_surface_data_type& data) noexcept
{
    if( data ) {
        delete data;
        data = nullptr;
    }
}
    
basic_display_point<GraphicsMath> _GS::surfaces::dimensions(const output_surface_data_type& data) noexcept
{
    return data->buffer_size;
}

void _GS::surfaces::dimensions(output_surface_data_type& data, const basic_display_point<GraphicsMath>& val)
{
    RebuildBackBuffer(*data, val);                
}
    
basic_display_point<GraphicsMath> _GS::surfaces::display_dimensions(const output_surface_data_type& data) noexcept
{
    auto bounds = data->window.contentView.bounds;
    return {int(bounds.size.width), int(bounds.size.height)};
}
    
void _GS::surfaces::draw_callback(output_surface_data_type& data, function<void(basic_output_surface<_GS>&)> callback)
{
    data->draw_callback = std::move(callback);
}
    
void _GS::surfaces::size_change_callback(output_surface_data_type& data, function<void(basic_output_surface<_GS>&)> callback)
{
    data->size_change_callback = std::move(callback);
}
    
bool _GS::surfaces::auto_clear(const output_surface_data_type& data) noexcept
{
    return data->auto_clear;
}
    
void _GS::surfaces::auto_clear(output_surface_data_type& data, bool val) noexcept
{
    data->auto_clear = val;
}
    
void _GS::surfaces::clear(output_surface_data_type& data)
{
    _Clear( data->draw_buffer.get(), _ClearColor(), CGRectMake(0, 0, data->buffer_size.x(), data->buffer_size.y()) );
}
    
void _GS::surfaces::stroke(output_surface_data_type& data, const basic_brush<_GS>& b, const basic_interpreted_path<_GS>& ip, const basic_brush_props<_GS>& bp, const basic_stroke_props<_GS>& sp, const basic_dashes<_GS>& d, const basic_render_props<_GS>& rp, const basic_clip_props<_GS>& cl)
{
    _Stroke(data->draw_buffer.get(), b, ip, bp, sp, d, rp, cl);
}
    
void _GS::surfaces::paint(output_surface_data_type& data, const basic_brush<_GS>& b, const basic_brush_props<_GS>& bp, const basic_render_props<_GS>& rp, const basic_clip_props<_GS>& cl)
{
    _Paint(data->draw_buffer.get(), b, bp, rp, cl);
}
    
void _GS::surfaces::fill(output_surface_data_type& data, const basic_brush<_GS>& b, const basic_interpreted_path<_GS>& ip, const basic_brush_props<_GS>& bp, const basic_render_props<_GS>& rp, const basic_clip_props<_GS>& cl)
{
    _Fill(data->draw_buffer.get(), b, ip, bp, rp, cl);
}
    
void _GS::surfaces::mask(output_surface_data_type& data, const basic_brush<_GS>& b, const basic_brush<_GS>& mb, const basic_brush_props<_GS>& bp, const basic_mask_props<_GS>& mp, const basic_render_props<_GS>& rp, const basic_clip_props<_GS>& cl)
{
    _Mask(data->draw_buffer.get(), b, mb, bp, mp, rp, cl);
}
    
static void _NSAppBootstrap()
{
    static once_flag once;
    call_once(once, []{
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp setPresentationOptions:NSApplicationPresentationDefault];
        [NSApp activateIgnoringOtherApps:YES];
        [NSApp finishLaunching];
    });
}
    
static void _FireDisplay( _GS::surfaces::_OutputSurfaceCocoa *data )
{
    data->output_view.needsDisplay = true;
    [NSApp updateWindows];
}

struct FakeEvent {
    static constexpr short subtype = 9076;
    static constexpr long data1 = 2875342;
    static constexpr long data2 = 8976345;
    
    static NSEvent *Get()
    {
        static auto fake = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                              location:NSMakePoint(0, 0)
                                         modifierFlags:0
                                             timestamp:0
                                          windowNumber:0
                                               context:nil
                                               subtype:subtype
                                                 data1:data1
                                                 data2:data2];
        return fake;
    }
    
    static void Enqueue()
    {
        [NSApp postEvent:Get() atStart:false];
    }

    static bool IsFake( NSEvent *event )
    {
        return event.type == NSEventTypeApplicationDefined && short(event.subtype) == subtype && event.data1 == data1 && event.data2 == data2;
    }
};
    
static NSEvent *_NextEvent()
{
    static auto distant_future = [NSDate distantFuture];
    return [NSApp nextEventMatchingMask:NSEventMaskAny
                              untilDate:distant_future
                                 inMode:NSDefaultRunLoopMode
                                dequeue:true];
}
    
int _GS::surfaces::begin_show(output_surface_data_type& data, basic_output_surface<_GS>* instance, basic_output_surface<_GS>& sfc)
{
    _NSAppBootstrap();
    data->frontend = &sfc;
    [data->window makeKeyAndOrderFront:nil];
    

    if( data->refresh_style == refresh_style::fixed ) {
        auto fixed_timer = [NSTimer scheduledTimerWithTimeInterval:1. / data->fps
                                                           repeats:true
                                                             block:^(NSTimer*){
                                                                 _FireDisplay(data);
                                                             }];
        while( true ) {
            @autoreleasepool {
                auto event = _NextEvent();
                if( event == nil )
                    break;
                [NSApp sendEvent:event];
            }
        }
        [fixed_timer invalidate];
    }
    else if( data->refresh_style == refresh_style::as_fast_as_possible ) {
        FakeEvent::Enqueue();
        while( true ) {
            @autoreleasepool {
                auto event = _NextEvent();
                if( event == nil )
                    break;
                [NSApp sendEvent:event];
                if( FakeEvent::IsFake(event) ) {
                    _FireDisplay(data);
                    FakeEvent::Enqueue();
                }
            }
        }
    }
    
    return 0;
}
    
static void RebuildBackBuffer(_GS::surfaces::_OutputSurfaceCocoa &context, basic_display_point<GraphicsMath> new_dimensions )
{
    context.draw_buffer.reset( _CreateBitmap(context.preferred_format, new_dimensions.x(), new_dimensions.y()) );
    context.buffer_size = new_dimensions;
}
    
} // namespace _CoreGraphics
} // inline namespace v1
} // std::experimental::io2d

using namespace std::experimental::io2d;
using namespace std::experimental::io2d::_CoreGraphics;

@implementation _IO2DOutputView

- (void)viewDidMoveToWindow
{
    if( self.window ) {
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];
    }
    else {
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:NSViewFrameDidChangeNotification
                                                    object:self];

    }
}

- (void)frameDidChange
{
    auto dimensions = basic_display_point<GraphicsMath>(self.bounds.size.width, self.bounds.size.height);
    RebuildBackBuffer(*_data, dimensions);
    if( _data->size_change_callback )
        _data->size_change_callback(*_data->frontend);
}

- (void)drawRect:(NSRect)dirtyRect
{
//    auto was = std::chrono:: high_resolution_clock::now();
    
    if( _data->auto_clear )
        _GS::surfaces::clear(_data);
    
    if( !_data->draw_callback )
        return;
        
    _data->draw_callback(*_data->frontend);
    
    // this is a really naive and slow approach, need to switch to CGLayer for display surface drawing
    auto ctx = [[NSGraphicsContext currentContext] CGContext];
    auto image = CGBitmapContextCreateImage(_data->draw_buffer.get());
    _AutoRelease release_image{image};
    
    CGContextTranslateCTM(ctx, 0, CGImageGetHeight(image));
    CGContextScaleCTM(ctx, 1.0, -1.0);
    CGContextSetBlendMode(ctx, kCGBlendModeCopy);
    
    // TODO: proper scaling regarding current settings
    auto rc = CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image));
    CGContextDrawImage(ctx, rc, image);

//    auto now = std::chrono:: high_resolution_clock::now();
//    auto interval = std::chrono::duration_cast<std::chrono::microseconds>(now - was).count();
//    std::cout << "frame time: " << interval << "us" << std::endl;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)keyDown:(NSEvent *)event
{
}

@end
