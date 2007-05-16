/**
  Author: Aziz Köksal
  License: GPL2
*/
module CmdLine;

import std.c.stdlib : calloc, realloc, free, malloc;
import std.c.string : memcpy;

version(Windows)
{
extern(Windows) uint GetModuleFileNameW(void*, wchar*, uint);
extern(Windows) wchar* GetCommandLineW();

/++
  Get the fully qualified path of this executable.
  Returns:
  Wide string allocated with calloc(). Release with free().
+/
wchar[] GetExecutableFileName()
{
  uint destsize = 256;
  uint strlen;
  wchar* dest = cast(wchar*) calloc(wchar.sizeof, destsize * wchar.sizeof);
  if (!dest)
    goto Lerr;

  while(1)
  {
    strlen = GetModuleFileNameW(null, dest, destsize);
    if (!strlen)
      goto Lerr_free_dest;
    if ( (destsize-strlen) != 0 && dest[strlen] == 0)
      break;
    // Increase size of buffer
    destsize *= 2;
    dest = cast(wchar*) realloc(dest, destsize * (wchar).sizeof);
    if (!dest)
      goto Lerr;
  }

  // Reduce buffer to the actual length of the string (excluding '\0'.)
//   if (strlen < destsize)
//     dest = cast(wchar*) realloc(dest, strlen * (wchar).sizeof);

  return dest[0..strlen];
Lerr_free_dest:
  if(!dest)
    free(dest);
Lerr:
  return null;
}

/++
  Get argument vector in UTF-16. Garbage collected.
+/
wchar[][] GetUnicodeArgvW()
{
  wchar[][] result;
  wchar[][] argv = GetArgvW(GetCommandLineW());
  scope(exit) free(argv.ptr);
  foreach (arg; argv)
  {
    result ~= arg.dup;
  }
  return result;
}
import std.utf;
/++
  Get argument vector in UTF-8. Garbage collected.
+/
char[][] GetUnicodeArgv()
{
  char[][] result;
  wchar[][] argv = GetArgvW(GetCommandLineW());
  scope(exit) free(argv.ptr);
  foreach (arg; argv)
  {
    result ~= toUTF8(arg);
  }
  return result;
}

} //version(Windows)

int countArguments(wchar* cmdLine)
{
  int count;
  alias cmdLine p;

  while(*p == ' ' || *p == '\t') ++p; 
  if (!*p)
    return 0;

  int inQuote, bsCount;
  while(*p)
  {
    switch(*p)
    {
      case '\\':
        bsCount = 0;
        do
          ++bsCount;
        while (*++p == '\\')

        if (*p == '"' && bsCount & 1)
          ++p;
        break;
      case '"':
        inQuote ^= 1;
        ++p;
        break;
      case ' ','\t':
        if (!inQuote)
          ++count;
        do ++p; while(*p == ' ' || *p == '\t')
        break;
      default:
        ++p;
    }
  }

  return count + 1;
}

/++
  Parses the command line string returned by GetCommandLineW().
  Escape rules:
  <ol>
  <li>'"' [^"]* '"'   -> [^"]* contents of the quote</li>
  <li>'\'{2N} + '"'   -> '\'{N} half the number of bs + argument delimiting '"'</li>
  <li>'\'{2N-1} + '"' -> '\'{N} + '"' half the number of bs + literal '"'</li>
  <li>'\'{N} + [^"]   -> '\'{N} add N literal '\'</li>
  </ol>
  Returns:
    A string - allocated with malloc() - containing the zero-terminated arguments.
    The parameter argc is set to the number of arguments found in cmdLine.<br>
  See_Also: Parsing C Command-Line Arguments: http://msdn2.microsoft.com/en-us/library/ms880421.aspx
+/
wchar[] GetParsedCmdLine(wchar* cmdLine, out int argc)
out(result)
{
  if (result !is null)
    assert(result[$-1] == 0);
}
body
{
  if (!cmdLine || *cmdLine == 0)
    goto Lerr;

  // Determine length of cmdLine
  int cmdLineLength;
  wchar* p = cmdLine;
  while(*p++) ++cmdLineLength;

  p = cmdLine;

  // Skip leading spaces
  while(*p == ' ' || *p == '\t') ++p;
  if (!*p)
    goto Lerr;

  // Allocate memory for the parsed cmd line.
  wchar* line = cast(wchar*) malloc((cmdLineLength + 1) * wchar.sizeof);
  if (!line)
    goto Lerr;

  alias cmdLine lineBegin; // reuse variable
  lineBegin = line;
  alias cmdLineLength bsCount; // reuse
  argc = 0;
  int inQuote;
  while(*p)
  {
    switch(*p)
    {
      case '\\':
        bsCount = 0;
        do // Count back slashes.
        {
          ++bsCount;
          *line++ = *p++;
        } while (*p == '\\')

        if (*p == '"')
        {
          line -= bsCount / 2;
          if (bsCount & 1)
          { // Replace previous back slash with a literal '"'.
            *(line-1) = '"';
            ++p;
          }
        }
        break;
      case '"':
        inQuote ^= 1;
        ++p;
        break;
      case ' ','\t':
        if (!inQuote)
        {
          do ++p; while(*p == ' ' || *p == '\t')
          // Only increment if we didn't skip trailing spaces.
          if(*p)
          {
            ++argc;
            *line = 0;
            ++line;
          }
          break;
        }
        // We are in a quote, so fall through to default and copy the space char.
      default:
        *line++ = *p++;
    }
  }
  ++argc;
  *line = 0;
  ++line;

  return lineBegin[0..line-lineBegin];
Lerr:
  return null;
}

/++
  Get the argument vector in UTF-16.<br>
  argv[0] is replaced by the fully qualified file name of the executable.
  Returns:
    Array of wide strings allocated with malloc().
  ---
  wchar[][] argv = GetArgvW(GetCommandLineW());
  // ...
  free(argv.ptr); // free the vector when done.
  ---
+/
wchar[][] GetArgvW(wchar* cmdLine)
{
  int argc;
  wchar[] parsedLine = GetParsedCmdLine(cmdLine, argc);
  if (!parsedLine || !argc)
    goto Lerr;

  wchar[] execName = GetExecutableFileName();
  if (!execName)
    goto Lerr_mem_free1;

  // Allocate a single block of memory for all 3 parts.
  wchar[][] argv = (cast(wchar[]*) malloc(
    argc * (wchar[]).sizeof) + // for argv
    parsedLine.length * wchar.sizeof + // arguments
    execName.length * wchar.sizeof // executable name
  )[0..argc];

  if (!argv.ptr)
    goto Lerr_mem_free2;

  // Copy parsed cmd-line.
  wchar* p = cast(wchar*) memcpy(argv.ptr + argv.length * (wchar[]).sizeof,
    parsedLine.ptr,
    parsedLine.length * wchar.sizeof
  );
  // Copy executable name.
  wchar[] eName = (cast(wchar*) memcpy(p + parsedLine.length * wchar.sizeof,
    execName.ptr,
    execName.length * wchar.sizeof
  ))[0..execName.length];
  // Free parsed cmd-line and executable name.
  free(parsedLine.ptr);
  free(execName.ptr);

  // Assign arguments to the vector.
  for(int i; i < argc; ++i)
  {
    wchar* arg = p;
    while(*p++) {}
    argv[i] = arg[0..p - arg -1];
  }

  // Replace first argument with the fully qualified path to the executable.
  argv[0] = eName;

  free(execName.ptr);

  return argv;
Lerr_mem_free2:
  free(execName.ptr);
Lerr_mem_free1:
  free(parsedLine.ptr);
Lerr:
  return null;
}

import std.stdio;
unittest
{
  writefln("GetParsedCmdLine unittest.");
  // Test command-lines
  wchar[][] cmdLines = [
    ""w,
    " \t ",
    "main.exe",
    "  \tC:\\bla   ",
    `bla "arg1 `,
    `"abc """ def"`,
    `abc "`,
    `bla """"" asd asd"`,
    `bla """abc"""`,
    `bla ""abc""`,
    `"binary"" ""with"" ""spaces.exe"`,
    `C:\blubb.exe arg1 arg2`,
    `hello.exe ".\ha\\" arg2`,
    `C:\bla.exe arg\1 arg\\2`,
    `C:\dmd"\bin"""\\"dmd.exe" a\"rg1 arg2\"\\ \"ar\\\"\g3\"`
  ];
  // Array of argument vectors.
  wchar[][][] cmdArgvs= [
    cast(wchar[][])[],
    [],
    ["main.exe"w],
    [`C:\bla`w],
    ["bla"w, "arg1 "],
    ["abc "w, "def"],
    ["abc"w, ""],
    ["bla"w, " asd asd"],
    ["bla"w, "abc"],
    ["bla"w, "abc"],
    ["binary with spaces.exe"w],
    [`C:\blubb.exe`w, "arg1", "arg2"],
    ["hello.exe"w, `.\ha\`, "arg2"],
    [`C:\bla.exe`w, `arg\1`, `arg\\2`],
    [`C:\dmd\bin\dmd.exe`w, "a\"rg1", `arg2"\\`, `"ar\"\g3"`]
  ];
  assert(cmdLines.length == cmdArgvs.length);

  foreach(i, cmdLine; cmdLines)
  {
    wchar[][] cmpArgv = cmdArgvs[i];
    int argc;
    wchar[] parsedLine = GetParsedCmdLine(cmdLine.ptr, argc);
    scope(exit) free(parsedLine.ptr);

    if (cmpArgv.length != argc)
      throw new Exception("Number of arguments do not match!");
    wchar* p = parsedLine.ptr;
    if (p)
      for(int j; j < argc; ++j)
      {
        wchar* arg = p;
        while(*p++) {} // Move to the end of the argument
        if (cmpArgv[j] != arg[0..p - arg -1])
        {
          char[] err = std.string.format(
            "Cmd-line:>%s<\n", cmdLine,
            "Parsed:>%s< != Expected:>%s<\n", arg[0..p - arg -1], cmpArgv[j]
          );
          throw new Exception("Mismatch between parsed argument and expected argument:\n" ~ err);
        }
      }
  }
}