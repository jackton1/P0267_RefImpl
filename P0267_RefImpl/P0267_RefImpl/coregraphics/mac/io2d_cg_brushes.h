#ifndef _IO2D_CG_BRUSHES_
#define _IO2D_CG_BRUSHES_

#include "io2d_cg.h"
#include "io2d_cg_interop.h"

namespace std::experimental::io2d { inline namespace v1 { namespace _CoreGraphics {
            
inline _GS::brushes::brush_data_type
_GS::brushes::create_brush(const rgba_color& c) {
    auto color = CGColorCreateGenericRGB(c.r(), c.g(), c.b(), c.a());
    if( color == nullptr )
        throw ::std::runtime_error("error");
    
    _SolidColor solid_data;
    solid_data.color.reset(color);
    
    brush_data_type data;
    data.brush = std::make_shared<typename brush_data_type::brush_t>( ::std::move(solid_data) );
    data.brushType = brush_type::solid_color;
    return data;
}
            
inline _GS::brushes::brush_data_type
_GS::brushes::create_brush(basic_image_surface<_GS>&& img) {
    auto &source_data = img._Get_data();
    
    _Surface surface_data;
    surface_data.bitmap = ::std::move(source_data.context);
    surface_data.image.reset( CGBitmapContextCreateImage(surface_data.bitmap.get()) );
    surface_data.width = (int)CGImageGetWidth(surface_data.image.get());
    surface_data.height = (int)CGImageGetHeight(surface_data.image.get());
    
    brush_data_type data;
    data.brush = std::make_shared<typename brush_data_type::brush_t>( ::std::move(surface_data) );
    data.brushType = brush_type::surface;
    return data;
}

template <class InputIterator>
inline CGGradientRef _BuildGradient(InputIterator first, InputIterator last ) {
    auto colors = CFArrayCreateMutable(nullptr, 0, &kCFTypeArrayCallBacks);
    _AutoRelease colors_release{colors};
    std::vector<double> locations;
    
    for( ; first != last; first++ ) {
        auto &stop = *first;
        locations.emplace_back(stop.offset());
        
        auto stop_color = stop.color();
        auto color = CGColorCreateGenericRGB(stop_color.r(), stop_color.g(), stop_color.b(), stop_color.a());
        CFArrayAppendValue(colors, color);
        CGColorRelease(color);
    }
    
    return CGGradientCreateWithColors(nullptr, colors, locations.data());
}

template <class InputIterator>
inline _GS::brushes::brush_data_type
_GS::brushes::create_brush(const basic_point_2d<GraphicsMath>& begin, const basic_point_2d<GraphicsMath>& end, InputIterator first, InputIterator last) {
    _Linear linear_data;
    linear_data.start = begin;
    linear_data.end = end;
    linear_data.stops.assign(first, last);
    
    brush_data_type data;
    data.brush = std::make_shared<typename brush_data_type::brush_t>( ::std::move(linear_data) );
    data.brushType = brush_type::linear;
    return data;
}
    
inline _GS::brushes::brush_data_type
_GS::brushes::create_brush(const basic_point_2d<GraphicsMath>& begin, const basic_point_2d<GraphicsMath>& end, ::std::initializer_list<gradient_stop> il) {
    return create_brush(begin, end, il.begin(), il.end());
}
    
template <class InputIterator>
inline _GS::brushes::brush_data_type
_GS::brushes::create_brush(const basic_circle<GraphicsMath>& start, const basic_circle<GraphicsMath>& end, InputIterator first, InputIterator last) {
    _Radial radial_data;
    radial_data.gradient.reset( _BuildGradient(first, last) );
    radial_data.start = start;
    radial_data.end = end;
    
    brush_data_type data;
    data.brush = std::make_shared<typename brush_data_type::brush_t>( ::std::move(radial_data) );
    data.brushType = brush_type::radial;
    return data;
}
    
inline _GS::brushes::brush_data_type
_GS::brushes::create_brush(const basic_circle<GraphicsMath>& start, const basic_circle<GraphicsMath>& end, ::std::initializer_list<gradient_stop> il) {
    return create_brush(start, end, il.begin(), il.end());
}
    
inline _GS::brushes::brush_data_type
_GS::brushes::copy_brush(const brush_data_type& data) {
    return data;
}

inline _GS::brushes::brush_data_type
_GS::brushes::move_brush(brush_data_type&& data) noexcept {
    return ::std::move(data);
}

inline void
_GS::brushes::destroy(brush_data_type&/*data*/) noexcept {
    // Do nothing.
}

inline brush_type
_GS::brushes::get_brush_type(const brush_data_type& data) noexcept {
    return data.brushType;
}

} // namespace _CoreGraphics
} // inline namespace v1
} // std::experimental::io2d

#endif
