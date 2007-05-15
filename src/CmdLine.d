/**
  Author: Aziz Köksal
  License: GPL2
*/
module CmdLine;

import std.c.stdlib : calloc, realloc, free;

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
}

/++
  Author: Aziz Köksal<br><br>
  Parses the command line string returned by GetCommandLineW().
  Escape rules:
  <pre>
  1. '"' [^"]* '"'   -> [^"]* contents of the quote
  2. '\'{2N} + '"'   -> '\'{N} half the number of bs + argument delimiting '"'
  3. '\'{2N-1} + '"' -> '\'{N} + '"' half the number of bs + literal '"'
  4. '\'{N} + [^"]   -> '\'{N} add N literal '\'
  </pre>
  Returns:
  Array of wide strings allocated with calloc().
  ---
  wchar[][] argv = ParseCommandLineArgs(GetCommandLineW());
  // ...
  free(argv[0].ptr); // free the parsed cmd-line first
  free(&argv); // then the array itself
  ---
  See also: Parsing C Command-Line Arguments: http://msdn2.microsoft.com/en-us/library/ms880421.aspx
  TODO: argv[0] should always contain the full path to the executable.
+/
wchar[][] ParseCommandLineArgs(wchar* cmdLine)
{
  if (!cmdLine || *cmdLine == 0)
    goto Lerr;

  int cmdLineLength;
  wchar* p = cmdLine;
  while(*p++) ++cmdLineLength;

  p = cmdLine;

  // Skip leading spaces
  while(*p == ' ' || *p == '\t') ++p;

  if (*p == 0)
    goto Lerr;

  // Allocate memory for the parsed cmd line.
  wchar* dest = cast(wchar*) calloc(wchar.sizeof, cmdLineLength * wchar.sizeof);
  if (!dest)
    goto Lerr;
  wchar* argBegin = dest; // Points to the beginning of an argument.
  int argvCapacity = 2; // Initial capacity of argv.
  // Allocate memory for the argument vector.
  wchar[]* argv = cast(wchar[]*) calloc((wchar[]).sizeof, argvCapacity * (wchar[]).sizeof);
  if (!argv)
    goto Lerr_free_dest;
  // Number of arguments in argv.
  int argc;

  int push_back_argv()
  {
    // Allocate more space if needed
    if (argc == argvCapacity)
    {
      argvCapacity *= 2;
      argv = cast(wchar[]*) realloc(argv, argvCapacity * (wchar[]).sizeof);
      if (!argv)
        return 0;
    }
    // Terminate argument?
//     *dest = 0;
//     ++dest;

    // Push new argument on the vector
    argv[argc] = argBegin[0..dest - argBegin];
    ++argc;
    return 1;
  }
  void parse_escape_sequence()
  {
    // Enter function if *p == '\\'
    int bsCount; // back slash count
    // Count the number of slashes and copy them to dest.
    do
    {
      ++bsCount;
      *dest++ = *p++;
    } while (*p == '\\')

    // If back slashes are followed by a dbl quote
    // special rules apply.
    if (*p == '"')
    {
      dest -= bsCount / 2;
      if (bsCount & 1)
      { // Add literal '"' if odd number of back slashes.
        dest -= 1;
        *dest = '"';
        ++p;
      }
    }
  }
  // Main parse loop
  while (*p)
  {
    switch (*p)
    {
      case '\\':
        parse_escape_sequence();
        break;
      case '"':
        while (*++p != '"')
        {
          wchar wc = *p;
          if (wc == '\\')
          { // p_e_s() sets p to the character next to the sequence.
            parse_escape_sequence();
            --p; // so we go back one
            continue;
          }
          else
          if (wc == 0)
            // no closing quote found, but argument still accepted
            goto Lend_main_loop;

          *dest = wc;
          ++dest;
        }
        assert(*p == '"');
        ++p;
        break;
      case ' ', '\t':
        if (!push_back_argv())
          goto Lerr_free_dest;
        // Skip any further spaces
        do ++p; while(*p == ' ' || *p == '\t')
        argBegin = dest;
        break;
      default:
        *dest++ = *p++;
    }
  }
Lend_main_loop:

  if (!push_back_argv())
    goto Lerr_free_dest;

  return argv[0..argc];

Lerr_free_dest:
  free(dest);
Lerr:
  return null;
}

unittest
{
  writefln("ParseCommandLineArgs unittest.");
  wchar[][] cmdLines = [
    ""w, // empty string -> null
    " \t ", // only spaces -> null
    "main.exe", // [main.exe]
    "  \tC:\\bla", // [C:\bla]
    "bla \"arg1 ", // unclosed quote
    "\"abc \"\"\" def\"", // "abc """ def" -> [abc ,def]
    "abc \"", // abc " -> [abc,]
    "bla \"\"\"\"\" asd asd\"", // bla """"" asd asd" -> [bla, asd asd]
    "bla \"\"\"abc\"\"\"", //bla """abc""" -> [bla,abc]
    "bla \"\"abc\"\"", // bla ""abc"" -> [bla,abc]
    "\"binary\"\" \"\"with\"\" \"\"spaces.exe\"", //"binary"" ""with"" ""spaces.exe" -> [binary with spaces.exe]
    "C:\\blubb.exe arg1 arg2", // C:\blubb.exe par1 par2 -> [C:\blubb.exe,arg1,arg2]
    "C:\\dmd\"\\bin\"\"\"\\\\\"dmd.exe\" arg1 arg2", // [C:\dmd\bin\dmd.exe arg1 arg2]
    "C:\\bla.exe arg\\1 arg\\\\2", // [C:\bla.exe arg\1 arg\2]
    "hello.exe \".\\ha\\\\\" arg2" // [hello.exe,.\ha\,arg2]
  ];
  // TODO: returned argv is not checked and not freed.
  foreach(line; cmdLines)
    std.stdio.writefln(ParseCommandLineArgs(line.ptr));
}