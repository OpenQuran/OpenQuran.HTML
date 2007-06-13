/**
  Author: Aziz Köksal
  License: GPL2
*/
module Console;

version(Windows)
{
import std.format;
import std.utf : encode;
static import std.stdio;

extern(Windows) void* GetStdHandle(uint);
extern(Windows) int WriteConsoleW(void*,void*,uint,uint*,void*);
extern(Windows) uint GetFileType(void*);
extern(Windows) int GetConsoleMode(void*,uint*);

const uint STD_OUTPUT_HANDLE = cast(uint)-11;
const uint STD_ERROR_HANDLE = cast(uint)-12;
const uint FILE_TYPE_CHAR = 2;

const void* stdoutHandle;
const void* stderrHandle;

void function(...) outf = &std.stdio.writef;
void function(...) outfln = &std.stdio.writefln;
alias outfln writefln;
alias outf writef;

void outf_(...)
{ writefx(stdoutHandle, _arguments, _argptr, 0); }
void outfln_(...)
{ writefx(stdoutHandle, _arguments, _argptr, 1); }

auto outerrf = cast(void function(void*, ...)) &std.stdio.fwritef;
auto outerrfln = cast(void function(void*, ...)) &std.stdio.fwritefln;
void werrf(T...)(T args)
{
  outerrf(stderrHandle, args);
}
void werrfln(T...)(T args)
{
  outerrfln(stderrHandle, args);
}

void outerrf_(void* handle, ...)
{ writefx(handle, _arguments, _argptr, 0); }
void outerrfln_(void* handle, ...)
{ writefx(handle, _arguments, _argptr, 1); }

static this()
{
  stdoutHandle = GetStdHandle(STD_OUTPUT_HANDLE);
  stderrHandle = GetStdHandle(STD_ERROR_HANDLE);
  // If stdout points to console buffer use WriteConsoleW() to output text.
  if (isConsole(stdoutHandle))
  {
    outf = &outf_;
    outfln = &outfln_;
  }
  // Ditto for stderr.
  if (isConsole(stderrHandle))
  {
    outerrf = &outerrf_;
    outerrfln = &outerrfln_;
  }
  else
    stderrHandle = std.stdio.stderr;
}

bool isConsole(void* handle)
{
  uint unused;
  if (GetFileType(handle) == FILE_TYPE_CHAR &&
      GetConsoleMode(handle, &unused) // Additional check
     )
    return true;
  return false;
}

void writefx(void* handle, TypeInfo[] arguments, void* argptr, int newline = false)
{
  wchar[] data;
  void putc(dchar c)
  {
    encode(data, c);
  }
  doFormat(&putc, arguments, argptr);
  if (newline)
  data ~= '\n';
  uint written;
  // Todo: WriteConsoleW can maximally output 64k.
  // Though it's unusual that a line will be that long,
  // maybe that case should be handled and the string split into 64k chunks.
  WriteConsoleW(handle, cast(void*)data.ptr, data.length, &written, null);
  debug assert(written == data.length);
}
} // version(Windows)
else
{
public import std.stdio;
void werrf(T...)(T args)
{
  fwritef(stderr, args);
}
void werrfln(T...)(T args)
{
  fwritefln(stderr, args);
}
}