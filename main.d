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
import Query;

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

/// Options that can be provided through the command line.
enum Options
{
  Alternating = 1, /// Print verses in alternating order.
  References = 2,  /// Print references as the result of a search.
  Random = 4,      /// Print a random verse.
  MatchAny = 8     /// Match any word in the query.
}

/++
  Print verses from the Qur'an matching the query.
  Params:
    query = a list of words with optional special characters
            for regular expressions and fuzzy word-matching
    referenceList = restrict the search to this list of references
    authors = a list of authors to search in
    options = some flags from the enum Options
+/
void search(char[] query, char[] referenceList, char[][] authors, int options)
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

  if (options & Options.References)
  {
    void prettyPrintReferences(int[][int] foundRefs)
    {
      // Pretty format found references.
      char[][] refStrings;
      foreach (cidx; foundRefs.keys.sort)
      {
        char[] verselist;
        int[2][] ranges = transformToRanges(foundRefs[cidx]);

        // Leave out the range if it matches the number of verses
        // in the current chapter.
        // E.g. "1:1-7" becomes "1"
        if (ranges.length == 1 &&
            ranges[0][0]  == 1 && ranges[0][1] == verses_table[cidx-1])
        {
          refStrings ~= format(cidx);
          continue;
        }

        foreach (range; ranges)
          if (range[1])
            verselist ~= format(range[0], '-', range[1], ',');
          else
            verselist ~= format(range[0], ',');
        verselist.length = verselist.length -1;

        refStrings ~= format(cidx, ':', verselist);
      }

      if (refStrings.length)
      {
        foreach(str; refStrings[0..$-1])
          writef(str, "; ");
        writefln(refStrings[$-1], ";");
      }
    }

    Query[] queries = parseQuery(query);
    auto predicate = options & Options.MatchAny ? &Query.findAny : &Query.findAll;

    foreach (quran; qurans)
    {
      writefln("["~C("\33[32m")~"%s"~C("\33[0m")~"]", quran.getAuthor);
      int[][int] foundRefs;
      uint matches;
      foreach (aref; refs)
      {
        foreach (cidx; aref.getChapterIndices())
        {
          char[][] chapter = quran.chapter(cidx);

          foreach (vidx; aref.getVerseIndices(cidx))
          {
//             if (ifind(chapter[vidx], query) != -1)
            if (predicate(queries, chapter[vidx]))
            {
              foundRefs[cidx+1] ~= vidx+1;
              ++matches;
            }
          }
        }
      }
      prettyPrintReferences(foundRefs);
      writefln("Found %d match%s!", matches, matches == 1 ? "" : "es");
    }
  }
  else
  {
    Query[] queries = parseQuery(query);
    auto predicate = options & Options.MatchAny ? &Query.findAny2 : &Query.findAll2;

    foreach (quran; qurans)
    {
      writefln("["~C("\33[32m")~"%s"~C("\33[0m")~"]", quran.getAuthor);
      uint matches;
      foreach (aref; refs)
      {
        foreach (cidx; aref.getChapterIndices())
        {
          char[][] chapter = quran.chapter(cidx);

          foreach (vidx; aref.getVerseIndices(cidx))
          {
//             if (predicate(queries, chapter[vidx]))
            int[2][] matchIndices;
            if (predicate(queries, chapter[vidx], matchIndices))
            {
              writefln(C("\33[34m")~"%03d:%03d"~C("\33[0m")~": ", cidx+1, vidx+1,
                      highlightMatches(chapter[vidx], matchIndices)
              );
              ++matches;
            }
          }
        }
      }
      writefln("Found %d match%s!", matches, matches == 1 ? "" : "es");
    }
  }
}

/++
  Print verses from the Qur'an.
  Params:
   referenceList = the list of numerical references
   authors       = the list of authors to fetch verses from
   options       = some flags from the enum Options
   randomNUM     = the number of verses to fetch randomly
+/
void show(char[] referenceList, char[][] authors, int options, int randomNUM)
{
  Reference[] refs;

  if (options & Options.Random)
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

  if (options & Options.Alternating && qurans.length > 1)
  { // Output verses of each author in alternating order.
/+
    char[] formatString = "\33[32m%%%ds\33[0m: ";
    uint padding;
    foreach(quran; qurans)
      if (padding < quran.getAuthor.length)
        padding = quran.getAuthor.length;
    formatString = format(formatString, padding);
+/
    foreach(aref; refs)
    {
      foreach(cidx; aref.getChapterIndices())
      {
        foreach(vidx; aref.getVerseIndices(cidx))
        {
          writefln("["~C("\33[34m")~"%03d:%03d"~C("\33[0m")~"]", cidx+1, vidx+1);
          foreach(quran; qurans)
          {
            char[][] chapter = quran.chapter(cidx);
            writefln(C("\33[32m")~"%s"~C("\33[0m")~":\n", quran.getAuthor, chapter[vidx]);
          }
        }
      }
    }
  }
  else
  { // Output verses of each author in sequential order.
    foreach(quran; qurans)
    {
      writefln("["~C("\33[32m")~"%s"~C("\33[0m")~"]", quran.getAuthor);
      foreach(aref; refs)
      {
        foreach(cidx; aref.getChapterIndices())
        {
          char[][] chapter = quran.chapter(cidx);

          foreach(vidx; aref.getVerseIndices(cidx))
          {
            writefln(C("\33[34m")~"%03d:%03d"~C("\33[0m")~": ", cidx+1, vidx+1, chapter[vidx]);
          }
        }
      }
    }
  }
}

/++
  Returns an empty string instead of the color code
  when compiled for Windows.
+/
char[] C(char[] code)
{
  version(Windows)
    return "";
  else
    return code;
}

const char[] VERSION = "0.19";
const char[] helpMessage =
`openquran v`~VERSION~`
Copyright (c) 2007 by Aziz Köksal

Usage:
  quran show <references> <authors> [options]
  quran search <query> <references> <authors> [options]

Type 'quran help <sub-command>' for more help on a particular sub-command.
`;

const char[] showMessage =
`Show verses from the Qur'an.
Usage:
  quran show <references> <authors> [options]

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
  quran search <query> [references] <authors> [options]

Options:
  -p            : print numerical references instead of text.
  -any          : do an OR-search instead of the default AND-search.

Query:
  A usual query consists of one or many words. There is support for
  powerful regular expressions and fuzzy word-matching.
  A slash starts a regular expression and a second one closes it:
    /M[ou]hamm[ae]d/  # Search for all 4 variants of spelling this word.
    /we|he|she/i      # The flag 'i' is for case-insensitive search.
  A tilde at the start of a word marks it for fuzzy searching:
    ~adhan

References:
  If not omitted you can restrict your query to a specific part of the Qur'an.

Examples:
  quran search Moses pickthal,shakir
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
      if (args.length < 4 || args[2] == "--help")
        return printHelp("search");
      args = args[2..$];

      int options;
      char[][] searchArgs;

      foreach (arg; args)
      {
        if (find(arg, "-") == 0)
        {
          if (arg == "-p")
            options |= Options.References;
          else if (arg == "-any")
            options |= Options.MatchAny;
        }
        else
          searchArgs ~= arg;
      }

      if (searchArgs.length < 3)
      {
        // Implicitly add "*" when references were omitted.
        searchArgs.length = searchArgs.length + 1;
        searchArgs[2..$] = searchArgs[1..$-1].dup;
        searchArgs[1] = "*";
      }

      if (searchArgs.length < 3)
        return printHelp("search");

      try
        search(searchArgs[0], searchArgs[1], split(searchArgs[2], ","), options);
      catch(Exception e)
        writefln(e);
      return;
    case "show":
      if (args.length < 4 || args[2] == "--help")
        return printHelp("show");
      args = args[2..$];

      int options;
      int randomNUM;

      char[][] showArgs;
      foreach (arg; args)
      {
        if (arg == "-a")
          options |= Options.Alternating;
        else if (find(arg, "-r") == 0)
        {
          options |= Options.Random;
          if (arg.length > 2)
            randomNUM = atoi(arg[2..$]);
        }
        else
        {
          showArgs ~= arg;
        }
      }

      if (showArgs.length < 2 && options & Options.Random)
      {
        // Insert "*" if <references> was omitted and -r was specified.
        showArgs.length = showArgs.length + 1;
        showArgs[1..$] = showArgs[0..$-1].dup;
        showArgs[0] = "*";
      }

      if (showArgs.length < 2)
        return printHelp("show");

      show(showArgs[0], split(showArgs[1], ","), options, randomNUM);
      return;
    case "help":
      if (args.length > 2)
        return printHelp(args[2]);
    default:
      printHelp("");
      return;
  }
}
