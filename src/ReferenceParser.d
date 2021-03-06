/**
  Author: Aziz Köksal
  License: GPL2
*/
module ReferenceParser;

import std.string;
import Quran;

enum TOK
{
  Dash,
  Plus,
  Comma,
  Colon,
  Semicolon,
  Wildcard,
  Number,
  Eof
}

char[][TOK.max+1] TOKname =
[
  "dash",
  "plus",
  "comma",
  "colon",
  "semicolon",
  "wildcard",
  "number",
  "eof"
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

    bool inRange(int idx)
    { return 0 < idx && idx <= NR_OF_CHAPTERS; }

    foreach(range; chapters)
    switch(range.type)
    {
      case Range.Type.Any:
        for(int i; i < NR_OF_CHAPTERS; ++i)
          indices ~= i;
        break;
      case Range.Type.Number:
        if (inRange(range.left))
          indices ~= range.left -1;
        break;
      case Range.Type.Number_Any:
        if (inRange(range.left))
          for(int i = range.left -1; i < NR_OF_CHAPTERS; ++i)
            indices ~= i;
      case Range.Type.Number_Number:
        int left = range.left, right = range.right;
        if (inRange(left) && inRange(right))
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
    assert( 0 <= chapterIdx && chapterIdx < NR_OF_CHAPTERS, "Chapter index out of range.");
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
    // Exclude the last character, because the parser
    // adds '\0' as a sentinel character to the input.
    // Everything that comes after '\0' is ignored when printed with printf,
    // which happens when the exception is caught by D's outer main method.
    this.input = input[0..$-1];
  }

  char[] toString()
  {
    return format(input,"\n"~repeat(" ",errorPos)~"^\nError in reference list: ",msg);
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
    assert((p-input.ptr) < (input.length));
    while (1)
    {
      char c = *p;
      switch (c)
      {
        case 0:
          tok.id = TOK.Eof;
          tok.pos = p - input.ptr;
          ++p;
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
        case '+':
          tok.id = TOK.Plus;
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
      if (token.id == TOK.Semicolon)
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
      Number '+' Number
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
          switch (nextToken())
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
        else if (token.id == TOK.Plus)
        {
          if (nextToken() != TOK.Number)
            goto Lerr;
          right = left + token.number;
          type = Range.Type.Number_Number;
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