MyAPI
=====

A more fluent FFI for Win32API/DL::CFunc


_,x1,y1,x2,y2 = API.new("user32", "GetWindowRect", hwnd, [API::L, API::L,API::L,API::L])
