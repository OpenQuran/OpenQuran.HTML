/**
  Author: Aziz Köksal
  License: GPL2
*/
module openquran;
import std.stdio;
import std.file;
import std.string;

/// Number of chapters in the Qur'an.
const int NR_OF_CHAPTERS = 114;
/// Total number of verses in the Qur'an (excluding the basmalahs.)
const int NR_OF_VERSES = 6236;

/// Number of verses in each chapter of the Qur'an.
const int[NR_OF_CHAPTERS] verses_table = [
   7, 286, 200, 176, 120, 165,
 206,  75, 129, 109, 123, 111,
  43,  52,  99, 128, 111, 110,
  98, 135, 112,  78, 118,  64,
  77, 227,  93,  88,  69,  60,
  34,  30,  73,  54,  45,  83,
 182,  88,  75,  85,  54,  53,
  89,  59,  37,  35,  38,  29,
  18,  45,  60,  49,  62,  55,
  78,  96,  29,  22,  24,  13,
  14,  11,  11,  18,  12,  12,
  30,  52,  52,  44,  28,  28,
  20,  56,  40,  31,  50,  40,
  46,  42,  29,  19,  36,  25,
  22,  17,  19,  26,  30,  20,
  15,  21,  11,   8,   8,  19,
   5,   8,   8,  11,  11,   8,
   3,   9,   5,   4,   7,   3,
   6,   3,   5,   4,   5,   6
];

/**
  Calculates the chapter index into an array of all 6236 verses.
*/
int getFlatChapterIndex(int chapter)
in
{
  assert(0 <= chapter && chapter < NR_OF_CHAPTERS);
}
body
{
  int idx;
  foreach(i, verses; verses_table)
  {
    if (i == chapter)
      break;
    idx += verses;
  }
  return idx;
}

enum TOK
{
  Dash,
  Comma,
  Colon,
  Semicolon,
  Wildcard,
  Number,
  Eof
}

char[][TOK.max+1] TOKname =
[
  "Dash",
  "Comma",
  "Colon",
  "Semicolon",
  "Wildcard",
  "Number",
  "Eof"
];

struct Token
{
  union
  {
    ushort number;
    char  c; // - , : ; *
  }
  TOK id;
  int pos; /// the position of the Token in the input stream

  char[] toString()
  {
    return TOKname[id];
  }
}

class Reference
{
  this(Range[] chapters, Range[] verses=null)
  {
    this.chapters = chapters;
    if (verses is null)
      verses ~= new Range(Range.Type.Any);
    this.verses   = verses;
  }

  int[] getChapterIndices()
  {
    int[] indices;
    foreach(range; chapters)
    switch(range.type)
    {
      case Range.Type.Any:
        for(int i; i < NR_OF_CHAPTERS; ++i)
          indices ~= i;
        break;
      case Range.Type.Number:
        if (range.left <= NR_OF_CHAPTERS)
          indices ~= range.left -1;
        break;
      case Range.Type.Number_Any:
        if (range.left <= NR_OF_CHAPTERS)
          for(int i = range.left -1; i < NR_OF_CHAPTERS; ++i)
            indices ~= i;
      case Range.Type.Number_Number:
        int left = range.left, right = range.right;
        if (left <= NR_OF_CHAPTERS && right <= NR_OF_CHAPTERS)
          for(int i = left -1; i < right; ++i)
            indices ~= i;
        break;
      default:
        assert(0, "Error: unhandled case in switch statement!");
    }
    return indices;
  }

  int[] getVerseIndices(int chapterIdx)
  {
    assert( 0 <= chapterIdx && chapterIdx < NR_OF_CHAPTERS );
    int[] indices;
    foreach(range; verses)
    switch(range.type)
    {
      case Range.Type.Any:
        int end = verses_table[chapterIdx];
        for(int i; i < end; ++i)
          indices ~= i;
        break;
      case Range.Type.Number:
        if (range.left <= verses_table[chapterIdx])
          indices ~= range.left -1;
        break;
      case Range.Type.Number_Any:
        int end = verses_table[chapterIdx];
        for(int i = range.left -1; i < end; ++i)
          indices ~= i;
        break;
      case Range.Type.Number_Number:
        int end = verses_table[chapterIdx];
        if (range.right < end)
          end = range.right;
        for(int i = range.left -1; i < end; ++i)
          indices ~= i;
        break;
      default:
        assert(0, "Error: unhandled case in switch statement!");
    }
    return indices;
  }

  Range[] chapters;
  Range[] verses;
}

class Range
{
  enum Type
  {
    Any, // *
    Number_Any, // 123-*
    Number, // 123
    Number_Number // 123-123
  }

  this(Type type, ushort left = 0, ushort right = 0)
  {
// writefln("type=%s,left=%s,right=%s", type, left, right);
    this.type = type;
    this.left  = left;
    this.right = right;
  }

  ushort left;
  ushort right;
  Type type;
}

class ParseError : Error
{
  this(char[] errorMsg, char[] input, int position)
  {
    super(errorMsg);
    this.errorPos = position;
    this.input = input;
  }

  char[] toString()
  {
    return std.string.format(input,"\n"~std.string.repeat(" ",errorPos)~"^\n","ParseError: ",msg);
  }

  private char[] input;
  private int errorPos;
}

/++
Parses a string into a list of Reference objects.
Examples:
<pre>
  2; 2:44; 2:44-45; 5-8; 5-8:19; 5-8:19-20
  2,3,8; 2:39,5; 2,3-4;49
  *:3-4,9,12-*;
  3:45 2:232
</pre>
Comma has lower precedence than dash.
BNF:
<pre>
  references := reference (';'? reference)* ';'?
   reference := chapterlist (':' verselist)?
   verselist := chapterlist
 chapterlist := chapterrange (',' chapterrange)
chapterrange := '*' | (number ('-' number | '*')?)
      number := [0-9]{1,3}
</pre>
+/
class ReferenceListParser
{
  this(char[] str)
  {
    // Add '0' as sentinel character for scanner.
    input = str ~ "\0";
    p = input.ptr;
  }

  /**
    Splits the input into a list of tokens.
  */
  public Token[] getTokens()
  {
    scope(exit) resetScanner();

    Token[] tokens;
    while(token.id != TOK.Eof)
    {
      tokens ~= this.token;
      nextToken();
    }
    return tokens;
  }

  /**
    Advance to the next token.
  */
  public TOK nextToken()
  {
    token = Token.init;
    scan(token);
// writefln("nextToken:",token);
    return token.id;
  }

  /**
    Resets the scanner.
  */
  public void resetScanner()
  {
    p = input.ptr;
    token = Token.init;
  }

  /**
    Analyzes the input and returns a token at each invocation.
  */
  public void scan(inout Token tok)
  {
    while (1)
    {
      char c = *p;
      switch (c)
      {
        case 0:
          tok.id = TOK.Eof;
          tok.pos = p - input.ptr;
          return;
        case ' ','\t':
          p++;
          continue;
        case '0','1','2','3','4','5','6','7','8','9':
          ushort n = c - '0';
          c = *(++p);
          while ('0' <= c && c <= '9')
          {
            if (n < ushort.max/10 || (n == ushort.max/10 && c <= '5'))
              n = n * 10 + (c - '0');
            else
              throw new ParseError("number overflow.", input, p - input.ptr);
            c = *(++p);
          }
          tok.id = TOK.Number;
          tok.number = n;
          tok.pos = p - input.ptr;
          return;
        case ':':
          tok.id = TOK.Colon;
          goto Lsymbols;
        case '-':
          tok.id = TOK.Dash;
          goto Lsymbols;
        case '*':
          tok.id = TOK.Wildcard;
          goto Lsymbols;
        case ',':
          tok.id = TOK.Comma;
          goto Lsymbols;
        case ';':
          tok.id = TOK.Semicolon;
        Lsymbols:
          tok.c = c;
          tok.pos = p - input.ptr;
          p++;
          return;
        default:
          throw new ParseError("illegal token found.", input, p - input.ptr);
      }
    }
  }

  /++
  <pre>
    References:
      Reference
      Reference ' ' References
      Reference ';' References
  </pre>
  +/
  public Reference[] parseReferences()
  {
    scope(exit) resetScanner();

    nextToken(); // start scanner

    Reference[] refs;
    while (token.id != TOK.Eof)
    {
      refs ~= parseReference();
      if (token.id == TOK.Number || token.id == TOK.Wildcard)
        continue;
      if (token.id != TOK.Semicolon && token.id != TOK.Eof && token.id != TOK.Number)
        throw new ParseError("expected number, semicolon or end of input, but found " ~ token.toString(), input, token.pos);
      nextToken();
    }
    return refs;
  }

  /++
  <pre>
    Reference:
      List
      List ':' List
    List:
      Range
      Range ',' List
  </pre>
  +/
  public Reference parseReference()
  {
    Range[] left, right;

    void parseList(inout Range[] list)
    {
      do
      {
        list ~= parseRange();
      } while (token.id == TOK.Comma && nextToken())
    }

    parseList(left);
    if (token.id == TOK.Colon)
    {
      nextToken();
      parseList(right);
    }

    return new Reference(left, right);
  }

  /++
  <pre>
    Range:
      *
      Number
      Number '-' '*'
      Number '-' Number
  </pre>
  +/
  public Range parseRange()
  {
    ushort left, right;
    Range.Type type;

    switch (token.id)
    {
      case TOK.Number:
        left = token.number;
        type = Range.Type.Number;

        if (nextToken() == TOK.Dash )
        {
          nextToken();
          switch (token.id)
          {
            case TOK.Number:
              right = token.number;
              type = Range.Type.Number_Number;
              break;
            case TOK.Wildcard:
              type = Range.Type.Number_Any;
              break;
            default:
              goto Lerr;
          }
        }
        else
          goto Lexit; // skip nextToken() below
        break;
      case TOK.Wildcard:
        type = Range.Type.Any;
        break;

      default:
        goto Lerr;
    }
    nextToken();
  Lexit:
    return new Range(type, left, right);
  Lerr:
    throw new ParseError("number or '*' expected, not " ~ TOKname[token.id], input, token.pos);
  }

  private Token token; /// current token
  private char[] input; /// the input string that is analyzed
  private char* p; /// points to current character
}

class Quran
{
  this(char[] fileName)
  {
    if (!std.file.exists(fileName))
      throw new Exception("Error: the file of the author \"" ~ fileName ~ "\" doesn't exist.");

    char[] data = cast(char[]) std.file.read(fileName);

    char[][] header;

    for(int i; i<2; ++i)
    {
      int nlpos = find(data, '\n');
      if (nlpos == -1)
        goto Lcorrupt;
      header ~= data[0..nlpos];
      data = data[nlpos+1..$];
    }

    if (find(header[0],"Author:") != 0 || find(header[1],"Lang:") != 0)
      goto Lcorrupt;
    author = std.string.strip(header[0][7..$]);
    language = std.string.strip(header[1][5..$]);

    // Currently a new-line character is used to separate the verses.
    // This may change in case there are translations out there
    // that have new-lines in the verses.
    char[][] verses = std.string.split(data, "\n");

    if (verses.length != NR_OF_VERSES)
      throw new Exception("Error: the file \"" ~ fileName ~ "\" doesn't exactly have 6236 verses.");

    this.fileName = fileName;
    this.verses = verses;

    return;
    Lcorrupt:
      throw new Exception("Error: the header of the file \""~fileName~"\" is corrupt.");
  }

  private char[] author;
  private char[] language;
  private char[] fileName;
  private char[][] verses;
}

const char[] helpMessage =
`openquran v0.1
Copyright (c) 2007 by Aziz Köksal
Usage:

quran <reference[[;] ...]> <translator[,...]>`;

void main(char[][] args)
{
  if ( args.length <= 1 ||
      (args.length == 2 && (args[1] == "--help" || args[1] == "-h"))
     )
  {
    writefln(helpMessage);
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
    writefln("[%s]", quran.author);
    foreach(aref; refs)
    {
      foreach(cidx; aref.getChapterIndices())
      {
        int flatChapterIdx = getFlatChapterIndex(cidx);
        // Slice into chapter
        char[][] chapter = quran.verses[flatChapterIdx .. (flatChapterIdx + verses_table[cidx])];

        foreach(vidx; aref.getVerseIndices(cidx))
        {
          writefln("%03d:%03d: ", cidx+1, vidx+1, chapter[vidx]);
        }
      }
    }
  }
}
