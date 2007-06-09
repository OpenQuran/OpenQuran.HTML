/**
  Author: Aziz Köksal
  License: GPL2
*/
module openquran;
import std.string;
import std.random;
import Quran;
import ReferenceParser;
import Query;
import Strings;
import CmdLine;

version(Windows)
{
  import WinConsole;
}
else
{
  import std.stdio;
}

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

/// Options that can be provided through the command line.
enum Options
{
  Alternating = 1,    /// Print verses in alternating order.
  References  = 1<<1, /// Print references as the result of a search.
  Random      = 1<<2, /// Print a random verse.
  MatchAny    = 1<<3  /// Match any word in the query.
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
      writefln(Strings.Author, quran.getAuthor);
      int[][int] foundRefs;
      uint matches;
      foreach (aref; refs)
      {
        foreach (cidx; aref.getChapterIndices())
        {
          char[][] chapter = quran.chapter(cidx);

          foreach (vidx; aref.getVerseIndices(cidx))
          {
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
      writefln(Strings.Author, quran.getAuthor);
      uint matches;
      foreach (aref; refs)
      {
        foreach (cidx; aref.getChapterIndices())
        {
          char[][] chapter = quran.chapter(cidx);

          foreach (vidx; aref.getVerseIndices(cidx))
          {
            int[2][] matchIndices;
            if (predicate(queries, chapter[vidx], matchIndices))
            {
              writefln(Strings.ChapterNrVerseNrVerse, cidx+1, vidx+1,
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
          writefln(Strings.ChapterNrVerseNr, cidx+1, vidx+1);
          foreach(quran; qurans)
          {
            char[][] chapter = quran.chapter(cidx);
            writefln(Strings.AuthorVerse, quran.getAuthor, chapter[vidx]);
          }
        }
      }
    }
  }
  else
  { // Output verses of each author in sequential order.
    foreach(quran; qurans)
    {
      writefln(Strings.Author, quran.getAuthor);
      foreach(aref; refs)
      {
        foreach(cidx; aref.getChapterIndices())
        {
          char[][] chapter = quran.chapter(cidx);

          foreach(vidx; aref.getVerseIndices(cidx))
          {
            writefln(Strings.ChapterNrVerseNrVerse, cidx+1, vidx+1, chapter[vidx]);
          }
        }
      }
    }
  }
}

const char[] VERSION = "0.22";

const char[] usageShow = "quran show <references> <authors> [options]";
const char[] usageSearch = "quran search <query> <authors> [options]";
const char[] usageToHTML = "quran tohtml <authors>";

const char[] helpMain =
`openquran v`~VERSION~`
Copyright (c) 2007 by Aziz Köksal

Usage:
  `~usageShow~`
  `~usageSearch~`
  `~usageToHTML~`

Type 'quran help <subcommand>' for more help on a particular subcommand.
`;

const char[] helpShow =
`Show verses from the Qur'an.
Usage:
  `~usageShow~`

Options:
  -rnd         : print a random verse.
  -rndNUM      : print NUM random verses.
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
  24+3:34+6          # Relative ranges. Equivalent to 24-27:34-40

Authors:
  Specify an author or a list of authors.

Examples:
  quran show 113-114 yusufali
  quran show -a "*:1" pickthall shakir
  quran show -rnd2 yusufali
`;

const char[] helpSearch =
`Search for a string in the Qur'an.
Usage:
  `~usageSearch~`

Options:
  -p           : print numerical references instead of text.
  -any         : do an OR-search instead of the default AND-search.
  -r reflist   : restrict your query to a specific part of the Qur'an.

Query:
  A usual query consists of one or many words. There is support for
  powerful regular expressions and fuzzy word-matching.
  A slash starts a regular expression and a second one closes it:
    /M[ou]hamm[ae]d/  # Search for all 4 variants of spelling this word.
    /we|he|she/i      # The flag 'i' is for case-insensitive search.
  A tilde at the start of a word marks it for fuzzy searching:
    ~adhan

Examples:
  quran search Moses pickthall shakir
  quran search Allah yusufali -p -r "42-93"
`;

const char[] helpToHTML =
`Use this command to generate an HTML file with dynamic features added by
JavaScript.

Usage:
  `~usageToHTML~`

Example:
  genhtml yusufali arabic khalifa > YusufAli_Arabic_RashadKhalifa.html
`;

void printHelp(char[] about)
{
  char[] help = helpMain;
  switch (about)
  {
    case "show":   help = helpShow;   break;
    case "search": help = helpSearch; break;
    case "tohtml": help = helpToHTML; break;
    default:
  }
  writefln(help);
}

void printUsage(char[] about)
{
  char[] usage;
  switch (about)
  {
    case "show":   usage = usageShow;   break;
    case "search": usage = usageSearch; break;
    case "tohtml": usage = usageToHTML; break;
    default:
      assert(0, "Unhandled switch case in printUsage().");
  }
  fwritefln(stderr, "Usage:  \n  ", usage);
}

version(linux)
{
  const int TCGETS = 0x5401;
  extern(C) {
    int errno;
    int ioctl(int fd, uint request, ...);
  }

  /++
    Return true if fd is a terminal.
  +/
  bool isatty(int fd)
  {
    ubyte[29] _struct;
    int result;
    int olderrno = errno;
    result = ioctl(fd, TCGETS, _struct.ptr);
    errno = olderrno;
    return result == 0;
  }
}

char[] readFile(char[] name)
{
  if (!std.file.exists("Quran.js"))
    throw new Exception("Error: the file \"" ~ name ~ "\" doesn't exist.");

  return cast(char[]) std.file.read(name);
}

char[] escapeQuotes(char[] str)
{
  return replace(str, "'", r"\'");
}

char[] toArrayLiteral(char[][] strArray)
{
  // Construct array literal
  char[] literal = "[\n";
  foreach(str; strArray)
    literal ~= "'" ~ escapeQuotes(str) ~ "',\n"; // escape single quotes
  literal.length = literal.length - 2; // Remove last ",\n"
  literal ~= "\n]";
  return literal;
}

char[] myreplace(char[] text, char[] from, char[] to)
{
  int start = find(text, from);
  if(start == -1)
    return text;
  return text[0..start] ~ to ~ text[start+from.length .. $];
}

void toHTML(char[][] authors)
{
  char[] Quran_js = readFile("Quran.js");
  char[] Query_js = readFile("Query.js");
  char[] ReferenceParser_js = readFile("ReferenceParser.js");
  char[] template_html = readFile("template.html");

  // Expand template macros
  template_html = myreplace(template_html, "{%Quran.js%}", Quran_js);
  template_html = myreplace(template_html, "{%Query.js%}", Query_js);
  template_html = myreplace(template_html, "{%ReferenceParser.js%}", ReferenceParser_js);

  // Load Qur'an files
  Quran[] qurans;
  foreach(author; authors)
    try
      qurans ~= new Quran(author);
    catch(Exception e)
      writefln(e);

  // Construct javascript array of author objects
  char[] authorsArray = "[\n";

  foreach(quran; qurans)
  {
    char[] titles = toArrayLiteral(quran.getTitles);
    char[] authorObject = std.string.format("new Quran(\n%s,\n%s,\n%s)", "'"~escapeQuotes(quran.getAuthor)~"'", titles, "'"~quran.getLanguage~"'");

    authorsArray ~= authorObject ~ ",\n";
  }
  authorsArray.length = authorsArray.length - 2;
  authorsArray ~= "\n]; // End of Authors array";

  char[] commentedVerses;
  foreach(quran; qurans)
  {
    char[][] verses = quran.getVerses;
    char* end = verses[$-1].ptr + verses[$-1].length;

    char[] allverses = verses[0].ptr[0 .. end - verses[0].ptr];
    commentedVerses ~= "<textarea>"~allverses~"</textarea>";
  }
  template_html = myreplace(template_html, "{%QuranObjects%}", authorsArray);
  template_html = myreplace(template_html, "{%Verses%}", commentedVerses);

  writefln("%s", template_html);
}

void main(char[][] args)
{
  if (args.length <= 1)
    return printHelp("");

  version(Windows)
  {
    int argc = args.length;
    args = GetUnicodeArgv();
    assert(args.length == argc);
  }

  version(linux)
    // Use color codes if stdout is a terminal.
    Strings.useColor = isatty(fileno(stdout));
  Strings.init();

  char[] errorMsg;
  char[] usageMsg;

  switch (args[1])
  {
    case "search":
      usageMsg = "search";
      if (args.length < 3)
      {
        errorMsg = "missing query and author(s) arguments.";
        goto Lerr;
      }

      args = args[2..$];

      int options;
      char[] refList;
      char[][] callArgs;

      for(int i; i < args.length; ++i)
      {
        char[] arg = args[i];
        if (arg.length && arg[0] == '-')
        {
          switch(arg)
          {
            case "-p":
              options |= Options.References;
              break;
            case "-any":
              options |= Options.MatchAny;
              break;
            case "-r":
              if (i+1 >= args.length)
              {
                errorMsg = "missing reference list after -r.";
                goto Lerr;
              }
              refList = args[++i];
              break;
            default:
              errorMsg = format("invalid option: %s.", arg);
              goto Lerr;
          }
        }
        else
          callArgs ~= arg;
      }

      if (callArgs.length < 2)
      {
        errorMsg = "no author(s) specified.";
        goto Lerr;
      }

      if (!refList)
        refList = "*";

      try
        search(callArgs[0], refList, callArgs[1..$], options);
      catch(Exception e)
        writefln(e);

      return;
    case "show":
      usageMsg = "show";
      if (args.length < 3)
      {
        errorMsg = "missing references and author(s) arguments.";
        goto Lerr;
      }

      args = args[2..$];

      int options;
      int randomNUM;
      char[][] callArgs;

      foreach (arg; args)
      {
        if (arg.length && arg[0] == '-')
        {
          if (arg == "-a")
            options |= Options.Alternating;
          else if (find(arg, "-rnd") == 0)
          {
            options |= Options.Random;
            if (arg.length > 4)
              randomNUM = atoi(arg[4..$]);
          }
          else
          {
            errorMsg = format("invalid option: %s.", arg);
            goto Lerr;
          }
        }
        else
          callArgs ~= arg;
      }

      if (options & Options.Random)
        callArgs = ["*"] ~ callArgs;

      if (callArgs.length < 2)
      {
        errorMsg = "no author(s) specified.";
        goto Lerr;
      }

      try
        show(callArgs[0], callArgs[1..$], options, randomNUM);
      catch(Exception e)
        writefln(e);

      return;
    case "tohtml":
      usageMsg = "tohtml";
      if (args.length < 3)
      {
        errorMsg = "no authors specified.";
        goto Lerr;
      }
      toHTML(args[2..$]);
      return;
    case "help":
      if (args.length > 2)
        return printHelp(args[2]);
    default:
      printHelp("");
      return;
  }

  return;
Lerr:
  printUsage(usageMsg);
  fwritefln(stderr, "Error: ", errorMsg);
  return -1;
}
