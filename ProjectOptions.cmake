include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(plugin_wizard_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(plugin_wizard_setup_options)
  option(plugin_wizard_ENABLE_HARDENING "Enable hardening" ON)
  option(plugin_wizard_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    plugin_wizard_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    plugin_wizard_ENABLE_HARDENING
    OFF)

  plugin_wizard_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR plugin_wizard_PACKAGING_MAINTAINER_MODE)
    option(plugin_wizard_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(plugin_wizard_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(plugin_wizard_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(plugin_wizard_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(plugin_wizard_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(plugin_wizard_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(plugin_wizard_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(plugin_wizard_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(plugin_wizard_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(plugin_wizard_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(plugin_wizard_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(plugin_wizard_ENABLE_PCH "Enable precompiled headers" OFF)
    option(plugin_wizard_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(plugin_wizard_ENABLE_IPO "Enable IPO/LTO" ON)
    option(plugin_wizard_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(plugin_wizard_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(plugin_wizard_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(plugin_wizard_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(plugin_wizard_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(plugin_wizard_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(plugin_wizard_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(plugin_wizard_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(plugin_wizard_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(plugin_wizard_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(plugin_wizard_ENABLE_PCH "Enable precompiled headers" OFF)
    option(plugin_wizard_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      plugin_wizard_ENABLE_IPO
      plugin_wizard_WARNINGS_AS_ERRORS
      plugin_wizard_ENABLE_USER_LINKER
      plugin_wizard_ENABLE_SANITIZER_ADDRESS
      plugin_wizard_ENABLE_SANITIZER_LEAK
      plugin_wizard_ENABLE_SANITIZER_UNDEFINED
      plugin_wizard_ENABLE_SANITIZER_THREAD
      plugin_wizard_ENABLE_SANITIZER_MEMORY
      plugin_wizard_ENABLE_UNITY_BUILD
      plugin_wizard_ENABLE_CLANG_TIDY
      plugin_wizard_ENABLE_CPPCHECK
      plugin_wizard_ENABLE_COVERAGE
      plugin_wizard_ENABLE_PCH
      plugin_wizard_ENABLE_CACHE)
  endif()

  plugin_wizard_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (plugin_wizard_ENABLE_SANITIZER_ADDRESS OR plugin_wizard_ENABLE_SANITIZER_THREAD OR plugin_wizard_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(plugin_wizard_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(plugin_wizard_global_options)
  if(plugin_wizard_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    plugin_wizard_enable_ipo()
  endif()

  plugin_wizard_supports_sanitizers()

  if(plugin_wizard_ENABLE_HARDENING AND plugin_wizard_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR plugin_wizard_ENABLE_SANITIZER_UNDEFINED
       OR plugin_wizard_ENABLE_SANITIZER_ADDRESS
       OR plugin_wizard_ENABLE_SANITIZER_THREAD
       OR plugin_wizard_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${plugin_wizard_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${plugin_wizard_ENABLE_SANITIZER_UNDEFINED}")
    plugin_wizard_enable_hardening(plugin_wizard_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(plugin_wizard_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(plugin_wizard_warnings INTERFACE)
  add_library(plugin_wizard_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  plugin_wizard_set_project_warnings(
    plugin_wizard_warnings
    ${plugin_wizard_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(plugin_wizard_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    plugin_wizard_configure_linker(plugin_wizard_options)
  endif()

  include(cmake/Sanitizers.cmake)
  plugin_wizard_enable_sanitizers(
    plugin_wizard_options
    ${plugin_wizard_ENABLE_SANITIZER_ADDRESS}
    ${plugin_wizard_ENABLE_SANITIZER_LEAK}
    ${plugin_wizard_ENABLE_SANITIZER_UNDEFINED}
    ${plugin_wizard_ENABLE_SANITIZER_THREAD}
    ${plugin_wizard_ENABLE_SANITIZER_MEMORY})

  set_target_properties(plugin_wizard_options PROPERTIES UNITY_BUILD ${plugin_wizard_ENABLE_UNITY_BUILD})

  if(plugin_wizard_ENABLE_PCH)
    target_precompile_headers(
      plugin_wizard_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(plugin_wizard_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    plugin_wizard_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(plugin_wizard_ENABLE_CLANG_TIDY)
    plugin_wizard_enable_clang_tidy(plugin_wizard_options ${plugin_wizard_WARNINGS_AS_ERRORS})
  endif()

  if(plugin_wizard_ENABLE_CPPCHECK)
    plugin_wizard_enable_cppcheck(${plugin_wizard_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(plugin_wizard_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    plugin_wizard_enable_coverage(plugin_wizard_options)
  endif()

  if(plugin_wizard_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(plugin_wizard_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(plugin_wizard_ENABLE_HARDENING AND NOT plugin_wizard_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR plugin_wizard_ENABLE_SANITIZER_UNDEFINED
       OR plugin_wizard_ENABLE_SANITIZER_ADDRESS
       OR plugin_wizard_ENABLE_SANITIZER_THREAD
       OR plugin_wizard_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    plugin_wizard_enable_hardening(plugin_wizard_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
