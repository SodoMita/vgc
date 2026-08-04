set(VGC_CORE_THIRD_DEPENDENCIES
    ${VGC_FMT}
    range-v3
)
set(VGC_CORE_CPP_HEADER_FILES
    algorithms.h
    animtime.h
    api.h
    arithmetic.h
    array.h
    assert.h
    boolguard.h
    color.h
    colors.h
    datetime.h
    defs.h
    dll.h
    enum.h
    exceptions.h
    flags.h
    format.h
    history.h
    id.h
    innercore.h
    io.h
    logcategories.h
    logging.h
    object.h
    objecttype.h
    objectarray.h
    parse.h
    paths.h
    performancelog.h
    preprocessor.h
    profile.h
    random.h
    ranges.h
    sharedconst.h
    span.h
    stopwatch.h
    stringid.h
    stringutil.h
    templateutil.h
    typeid.h
    xml.h

    detail/parsebits.h
    detail/signal.h
)
set(VGC_CORE_CPP_SOURCE_FILES
    algorithms.cpp
    animtime.cpp
    arithmetic.cpp
    boolguard.cpp
    color.cpp
    datetime.cpp
    enum.cpp
    exceptions.cpp
    format.cpp
    history.cpp
    id.cpp
    io.cpp
    logcategories.cpp
    logging.cpp
    object.cpp
    parse.cpp
    paths.cpp
    performancelog.cpp
    profile.cpp
    random.cpp
    stopwatch.cpp
    stringid.cpp
    stringutil.cpp
    typeid.cpp
    xml.cpp

    detail/signal.cpp
)
if(NOT ANDROID)
    list(APPEND VGC_CORE_THIRD_DEPENDENCIES Python::Python pybind11::headers)
    list(APPEND VGC_CORE_CPP_HEADER_FILES python.h)
    list(APPEND VGC_CORE_CPP_SOURCE_FILES python.cpp)
endif()

vgc_add_library(core
    THIRD_DEPENDENCIES
        ${VGC_CORE_THIRD_DEPENDENCIES}

    VGC_DEPENDENCIES

    CPP_HEADER_FILES
        ${VGC_CORE_CPP_HEADER_FILES}

    CPP_SOURCE_FILES
        ${VGC_CORE_CPP_SOURCE_FILES}

    NATVIS_FILES
        tools/vgccore.natvis

    COMPILE_DEFINITIONS
)

vgc_optional_compile_definition(core PUBLIC VGC_CORE_USE_32BIT_INT "Define vgc::Int/UInt as 32-bit integers (default is 64-bit)")
vgc_optional_compile_definition(core PRIVATE VGC_CORE_OBJECT_DEBUG "Enable debug mode for vgc::core::Object")

add_dependencies(vgc_core_lib vgc_version)

if(NOT ANDROID)
    add_subdirectory(wraps)
    add_subdirectory(tests)
endif()
