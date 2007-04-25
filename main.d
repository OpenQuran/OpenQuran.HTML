/**
  Author: Aziz Köksal
  License: GPL2
*/
module openquran;
import std.stdio;
import std.file;
import std.string;
import std.random;
import Quran;
import ReferenceParser;

/++
  Transform a list of integers into a list of ranges.
  Example:
  ---
  [1,2,3,8,9,15] -> [[1,3],[8,9],[15,0]]
  ---
  Params:
    list = sorted list of integers.
  Returns: list of ranges.
+/
int[2][] transformToRanges(int[] list)
{
  int[2][] result;
  int l = list[0], r;

  foreach(val; list[1..$])
  {
    if (val - l == 1 || val - r == 1)
    {
      r = val;
    }
    else
    {
      result ~= [l,r];
      l = val;
      r = 0;
    }
  }
  result ~= [l,r];
  return result;
}

/++
  Replace occurences of from with to in source.
  In order to preserve the casing of the matched string
  you can provide a format string "%s" in "to" which will
  be replaced with the found string.
  NB.: This could be generalized with a callback delegate function.
+/
char[] ireplace(char[] source, char[] from, char[] to)
{
  alias source s;
  char[] result;
  int i;

  while( (i = ifind(s, from)) != -1 )
  {
    result ~= s[0 .. i] ~ replace(to, "%s", s[i .. i + from.length]);
    s = s[i + from.length .. $];
  }
  result ~= s;
  return result;
}

void search(char[] query, char[] referenceList, char[][] authors, bool printRefs)
{
  // Parse reference list
  auto parser = new ReferenceListParser(referenceList);
  Reference[] refs;
  refs = parser.parseReferences();

  // Load files
  Quran[] qurans;
  foreach(author; authors)
    try
      qurans ~= new Quran(author);
    catch(Exception e)
      writefln(e);

  auto printVerses = delegate(int cidx, int vidx, char[] verse)
  {
    if( ifind(verse, query) != -1 )
    {
      writefln("\33[34m%03d:%03d\33[0m: ", cidx+1, vidx+1,
               ireplace(verse, query, "\33[31m%s\33[0m")
      );
    }
  };

  int[][int] foundRefs;
  auto printReferences = delegate(int cidx, int vidx, char[] verse)
  {
    if( ifind(verse, query) != -1 )
      foundRefs[cidx+1] ~= vidx+1;
  };

  // The actual function that will be called in the foreach loop.
  auto operation = printRefs ? printReferences : printVerses;

  foreach(quran; qurans)
  {
    writefln("[\33[32m%s\33[0m]", quran.getAuthor);
    foreach(aref; refs)
    {
      foreach(cidx; aref.getChapterIndices())
      {
        char[][] chapter = quran.chapter(cidx);

        foreach(vidx; aref.getVerseIndices(cidx))
        {
          operation(cidx, vidx, chapter[vidx]);
        }
      }
    }
  }

  if (foundRefs)
  {
    // Pretty format found references.
    char[][] refStrings;
    foreach(cidx; foundRefs.keys.sort)
    {
      int[] vidcs = foundRefs[cidx];
      char[] verselist;
      int[2][] ranges = transformToRanges(vidcs);

      // Leave out the range if it matches the number of verses
      // in the current chapter.
      if(ranges.length == 1 &&
         ranges[0][0]  == 1 && ranges[0][1] == verses_table[cidx-1])
      {
        refStrings ~= format(cidx);
        continue;
      }

      foreach(range; ranges)
        if (range[1])
          verselist ~= format(range[0], '-', range[1], ',');
        else
          verselist ~= format(range[0], ',');
      verselist.length = verselist.length -1;

      refStrings ~= format(cidx, ':', verselist);
    }
    writef(refStrings[0]);
    foreach(str; refStrings[1..$])
      writef("; ", str);
    writef(\n);
  }
}

void show(char[] referenceList, char[][] authors, int options, int randomNUM)
{
  Reference[] refs;

  if (options & 0x02)
  {
    if (randomNUM < 1)
      randomNUM = 1;
    do
    {
      uint cidx = rand() % 114;
      uint vidx = rand() % verses_table[cidx];
      refs ~= new Reference([new Range(Range.Type.Number, cidx+1)], [new Range(Range.Type.Number, vidx+1)]);
    } while(--randomNUM)
  }
  else
  {
    // Parse reference list
    auto parser = new ReferenceListParser(referenceList);
    try
      refs = parser.parseReferences();
    catch(ParseError e)
    {
      writefln(e);
      return;
    }
  }

  // Load files
  Quran[] qurans;
  foreach(author; authors)
    try
      qurans ~= new Quran(author);
    catch(Exception e)
      writefln(e);

  if (options & 0x01 && qurans.length > 1)
  { // Output verses of each author in alternating order.
    char[] formatString = "\33[32m%%%ds\33[0m: ";
    uint padding;
    foreach(quran; qurans)
      if (padding < quran.getAuthor.length)
        padding = quran.getAuthor.length;
    formatString = format(formatString, padding);

    foreach(aref; refs)
    {
      foreach(cidx; aref.getChapterIndices())
      {
        foreach(vidx; aref.getVerseIndices(cidx))
        {
          writefln("[\33[34m%03d:%03d\33[0m]", cidx+1, vidx+1);
          foreach(quran; qurans)
          {
            char[][] chapter = quran.chapter(cidx);
            writefln(formatString, quran.getAuthor, chapter[vidx]);
          }
        }
      }
    }
  }
  else
  { // Output verses of each author in sequential order.
    foreach(quran; qurans)
    {
      writefln("[\33[32m%s\33[0m]", quran.getAuthor);
      foreach(aref; refs)
      {
        foreach(cidx; aref.getChapterIndices())
        {
          char[][] chapter = quran.chapter(cidx);

          foreach(vidx; aref.getVerseIndices(cidx))
          {
            writefln("\33[34m%03d:%03d\33[0m: ", cidx+1, vidx+1, chapter[vidx]);
          }
        }
      }
    }
  }
}

const char[] VERSION = "0.14";
const char[] helpMessage =
`openquran v`~VERSION~`
Copyright (c) 2007 by Aziz Köksal

Usage:
  quran show [options] <references> <authors>
  quran search [options] <query> <references> <authors>

Type 'quran help <sub-command>' for more help on a particular sub-command.
`;

const char[] showMessage =
`Show verses from the Qur'an.
Usage:
  quran show [options] <references> <authors>

Options:
  -r           : print a random verse.
  -rNUM        : print NUM random verses.
  -a           : when printing verses alternate between authors.

References:
  A reference is composed of a chapter part and a verse part
  separated by a colon (CP:VP). In both parts you can specify
  a list of numbers and ranges separated by a comma.
  Separate multiple references with a semicolon or a space.
  E.g.:
  1:3 2:286          # Chapter 1, Verse 3. Chapter 2, Verse 286.
  1,8:19,2,9,5,7     # Chapter 1 and 8, Verses 19,2,9,5,7.
  38-98,100:5-10,18  # Chapter 38 to 98 and 100, Verses 5 to 10 and 18.
  2-10:4-*           # Chapter 2 to 10, Verses 4 to end of each chapter.
  *:1,2              # First two verses of all chapters (equiv. to 1-114:1,2).

Authors:
  A list of authors separated by a comma (no spaces allowed.)

Examples:
  quran show 113-114 yusufali
  quran show -a "*:1" pickthal,shakir
`;

const char[] searchMessage =
`Search for a string in the Qur'an.
Usage:
  quran search [options] <query> <references> <authors>

Options:
  -p            : print numerical references instead of the actual verses.

Examples:
  quran search Moses "*" pickthal,shakir
  quran search -p Allah "42-93" yusufali
`;

void printHelp(char[] about)
{
  if (about == "show")
    writefln(showMessage);
  else if (about == "search")
    writefln(searchMessage);
  else
    writefln(helpMessage);
}

void main(char[][] args)
{
  if (args.length <= 1)
    return printHelp("");

  switch (args[1])
  {
    case "search":
      if (args.length < 5 || args[2] == "--help")
        return printHelp("search");
      args = args[2..$];

      bool printRefs = false;
      if (args[0] == "-p")
      {
        printRefs = true;
        args = args[1..$];
      }
      try
        search(args[0], args[1], split(args[2], ","), printRefs);
      catch(Exception e)
        writefln(e);
      return;
    case "show":
      if (args.length < 4 || args[2] == "--help")
        return printHelp("show");
      args = args[2..$];

      int options;
      int randomNUM;

      while (args.length)
      {
        if (args[0] == "-a")
          options |= 0x01;
        else if(find(args[0], "-r") == 0)
        {
          options |= 0x02;
          if (args[0].length > 2)
            randomNUM = atoi(args[0][2..$]);
        }
        else
          break;
        args = args[1..$];
      }

      show(args[0], split(args[1], ","), options, randomNUM);
      return;
    case "help":
      if (args.length > 2)
        return printHelp(args[2]);
    default:
      printHelp("");
      return;
  }
}
