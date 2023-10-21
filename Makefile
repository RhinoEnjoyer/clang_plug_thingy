# clang-as-lib/Makefile
# Attempt to link with clang as a library.

# Originally based on:
# https://stackoverflow.com/questions/59888374/using-clang-as-a-library-in-c-project

# Default target.
all:
.PHONY: all


# ---- Configuration ----
# Installation directory from a binary distribution.
# Has five subdirectories: bin include lib libexec share.
# Downloaded from: https://github.com/llvm/llvm-project/releases/download/llvmorg-14.0.0/clang+llvm-14.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz
CLANG_LLVM_INSTALL_DIR = $(HOME)/opt/clang+llvm-14.0.0-x86_64-linux-gnu-ubuntu-18.04

# Link with clang statically?
#
# If 1, then both clang and llvm are linked statically.  Linking takes
# about 3 seconds, and the resulting binary is 48 MB.
#
# If 0, then both are obtained dynamically from libclang-cpp.so.
# Linking takes about 0.7s, and the binary is about 2.7 MB.  But the .so
# file (which is about 176 MB) must be available at run time.
LINK_CLANG_STATICALLY = 1


# ---- llvm-config query results ----
# Due to using the ':=' operator (rather than '='), these queries are
# done exactly once for each 'make' invocation.

# Program to query the various LLVM configuration options.
LLVM_CONFIG := $(CLANG_LLVM_INSTALL_DIR)/bin/llvm-config

# C++ compiler options to ensure ABI compatibility.
LLVM_CXXFLAGS := $(shell $(LLVM_CONFIG) --cxxflags)

# Set of LLVM libraries to link with, as -l flags, when linking
# statically.  There are 163 of them in clang+llvm-14.0.0.
LLVM_LIBS := $(shell $(LLVM_CONFIG) --libs)

# Directory containing the clang library files, both static and dynamic.
LLVM_LIBDIR := $(shell $(LLVM_CONFIG) --libdir)

# Other flags needed for linking, whether statically or dynamically.
LLVM_LDFLAGS_AND_SYSTEM_LIBS := $(shell $(LLVM_CONFIG) --ldflags --system-libs)


# ---- Compiler options ----
# C++ compiler.
CXX = g++

# Compiler options, including preprocessor options.
CXXFLAGS =

# Without optimization, adding -g increases compile time by ~20%.
#CXXFLAGS += -g

# Without -g, this increases compile time by ~10%.  With -g -O2, the
# increase is ~50% over not having either.
#CXXFLAGS += -O2

CXXFLAGS += -Wall

# Silence a warning about a multi-line comment in DeclOpenMP.h.
CXXFLAGS += -Wno-comment

# Get llvm compilation flags.
CXXFLAGS += $(LLVM_CXXFLAGS)

# Linker options.
LDFLAGS =


ifeq ($(LINK_CLANG_STATICALLY),1)

# Set of clang libraries to link with.  This list was obtained through
# trial and error.
LDFLAGS += -lclangTooling
LDFLAGS += -lclangFrontendTool
LDFLAGS += -lclangFrontend
LDFLAGS += -lclangDriver
LDFLAGS += -lclangSerialization
LDFLAGS += -lclangCodeGen
LDFLAGS += -lclangParse
LDFLAGS += -lclangSema
LDFLAGS += -lclangStaticAnalyzerFrontend
LDFLAGS += -lclangStaticAnalyzerCheckers
LDFLAGS += -lclangStaticAnalyzerCore
LDFLAGS += -lclangAnalysis
LDFLAGS += -lclangARCMigrate
LDFLAGS += -lclangRewrite
LDFLAGS += -lclangRewriteFrontend
LDFLAGS += -lclangEdit
LDFLAGS += -lclangAST
LDFLAGS += -lclangLex
LDFLAGS += -lclangBasic
LDFLAGS += -lclang

# *After* clang libs, the llvm libs.
LDFLAGS += $(LLVM_LIBS)

else # LINK_CLANG_STATICALLY==0

# Pull in clang+llvm via libclang-cpp.so, which has everything, but is
# only available as a dynamic library.
LDFLAGS += -lclang-cpp

# Arrange for the compiled binary to search the libdir for that library.
# Otherwise, one can set the LD_LIBRARY_PATH envvar before running it.
# Note: the -rpath switch does not work on Windows.
LDFLAGS += -Wl,-rpath=$(LLVM_LIBDIR)

endif


# Get the needed -L search path, plus things like -ldl.
LDFLAGS += $(LLVM_LDFLAGS_AND_SYSTEM_LIBS)


# ---- Recipes ----
# Compile a C++ source file.
%.o: %.cpp
	$(CXX) -c -o $@ $(CXXFLAGS) $<

# Executable.
all: FindClassDecls.out
FindClassDecls.out: FindClassDecls.o
	$(CXX) -g -Wall -o $@ $^ $(LDFLAGS)

# Run it.
.PHONY: run
run: FindClassDecls.out
	./FindClassDecls.out "namespace n { namespace m { class C {}; } }"

.PHONY: clean
clean:
	$(RM) *.o *.out


# EOF
