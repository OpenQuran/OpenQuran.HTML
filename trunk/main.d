/**
  Author: Aziz Köksal
  License: GPL2
*/
module openquran;
import std.stdio;
import std.file;
import std.string;
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
               replace(verse, query, "\33[31m" ~ query ~ "\33[0m")
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
const char[] VERSION = "0.11";
const char[] helpMessage =
`openquran v`~VERSION~`
Copyright (c) 2007 by Aziz Köksal

Usage:

  quran <reference[[;] ...]> <translator[,...]>
  quran search [options] <query> <reference-list> <translators>
`;

const char[] searchMessage =
`Search for a string in the Qur'an.
Usage:
  quran search [options] <query> <reference-list> <translators>

Options:
  -p            : print numerical references instead of the actual verses.

Examples:
  quran search Moses "*" pickthal,shakir
  quran search -p Allah "42-93" yusufali
`;

void main(char[][] args)
{
  if ( args.length <= 1 ||
      (args.length == 2 && (args[1] == "--help" || args[1] == "-h"))
     )
  {
    writefln(helpMessage);
    return;
  }

  if (args[1] == "search")
  {
    if (args[2] == "--help")
    {
      writefln(searchMessage);
      return;
    }

    bool printRefs = false;
    if (args[2] == "-p")
    {
      printRefs = true;
      args[2..$-1] = args[3..$].dup;
      args.length = args.length -1;
    }
    try
      search(args[2], args[3], split(args[4], ","), printRefs);
    catch(Exception e)
      writefln(e);
    return;
  }

  char[] referenceList = args[1];
  char[][] authors = (args.length == 3) ? split(args[2], ",") : null;

  // Parse reference list
  auto parser = new ReferenceListParser(referenceList);

  Reference[] refs;
  try
    refs = parser.parseReferences();
  catch(ParseError e)
  {
    writefln(e);
    return;
  }

  // Load files
  Quran[] qurans;
  foreach(author; authors)
    try
      qurans ~= new Quran(author);
    catch(Exception e)
      writefln(e);

  // Output verses of each author in sequential order.
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
