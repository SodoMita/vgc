set(VGC_DOM_CPP_HEADER_FILES
    api.h
    attribute.h
    document.h
    element.h
    exceptions.h
    io.h
    logcategories.h
    node.h
    noneor.h
    operation.h
    path.h
    schema.h
    strings.h
    value.h
    xmlformattingstyle.h

    detail/facecycles.h
    detail/pyvalue.h
)
set(VGC_DOM_CPP_SOURCE_FILES
    attribute.cpp
    document.cpp
    element.cpp
    exceptions.cpp
    io.cpp
    logcategories.cpp
    node.cpp
    operation.cpp
    path.cpp
    schema.cpp
    strings.cpp
    value.cpp
    xmlformattingstyle.cpp

    detail/facecycles.cpp
    detail/pyvalue.cpp
)
if(ANDROID)
    list(REMOVE_ITEM VGC_DOM_CPP_HEADER_FILES detail/pyvalue.h)
    list(REMOVE_ITEM VGC_DOM_CPP_SOURCE_FILES detail/pyvalue.cpp)
endif()

vgc_add_library(dom
    THIRD_DEPENDENCIES

    VGC_DEPENDENCIES
        geometry

    CPP_HEADER_FILES
        ${VGC_DOM_CPP_HEADER_FILES}

    CPP_SOURCE_FILES
        ${VGC_DOM_CPP_SOURCE_FILES}

    COMPILE_DEFINITIONS
)

if(NOT ANDROID)
    add_subdirectory(wraps)
    add_subdirectory(tests)
endif()
