/**
  Author: Aziz Köksal
  License: GPL2
*/
module WinConsole;

import std.format;
import std.utf : encode;
static import std.stdio;

extern(Windows) void* GetStdHandle(uint);
extern(Windows) int WriteConsoleW(void*,void*,uint,uint*,void*);
extern(Windows) uint GetFileType(void*);
extern(Windows) int GetConsoleMode(void*,uint*);

const uint STD_OUTPUT_HANDLE = cast(uint)-11;
const uint FILE_TYPE_CHAR = 2;

void* stdoutHandle;

static this()
{
  stdoutHandle = GetStdHandle(STD_OUTPUT_HANDLE);
  // If this is a console use WriteConsoleW() to output text.
  uint unused;
  if (GetFileType(stdoutHandle) == FILE_TYPE_CHAR &&
      GetConsoleMode(stdoutHandle, &unused) // Additional check
     )
  {
    outfln = &WCW_outfln;
    outfln = &WCW_outfln;
  }
}

void function(...) outfln = &std.stdio.writefln;
void function(...) outf = &std.stdio.writef;
alias outfln writefln;
alias outf writef;

void writefx(TypeInfo[] arguments, void* argptr, int newline = false)
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
  WriteConsoleW(stdoutHandle, cast(void*)data.ptr, data.length, &written, null);
  debug assert(written == data.length);
}
void WCW_outfln(...)
{
  writefx(_arguments, _argptr, 1);
}
void WCW_outf(...)
{
  writefx(_arguments, _argptr, 0);
}
