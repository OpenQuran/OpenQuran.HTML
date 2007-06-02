/**
  Author: Aziz Köksal
  License: GPL2
*/
//module ReferenceParser;

const TOK = {
  Dash : 0,
  Plus : 1,
  Comma : 2,
  Colon : 3,
  Semicolon : 4,
  Wildcard : 5,
  Number : 6,
  Eos : 7
}

const CharToTOK = {
  '-' : TOK.Dash,
  '+' : TOK.Plus,
  ',' : TOK.Comma,
  ':' : TOK.Colon,
  ';' : TOK.Semicolon,
  '*' : TOK.Wildcard
}

const TOKname =
[
  "dash",
  "plus",
  "comma",
  "colon",
  "semicolon",
  "wildcard",
  "number",
  "end of string"
];

function Token()
{
  this.number = 0;
  this.c = ""; // - , : ; *

  this.id = 0;
  this.pos = 0; /// the position of the Token in the input stream
  this.toString = function() {
    return TOKname[this.id];
  }
}

function Reference(chapters, verses)
{
  this.chapters = chapters;
  if (!(verses instanceof Array) || verses.length == 0)
    verses = [new Range(Type.Any, 0 , 0)];
  this.verses   = verses;
/*
  this.getChapterVerseNumberPairs = function()
  {
    var tuples;
    var cindices = this.getChapterIndices();
    for(var i=0; i < cindices.length; ++i)
    {
      var cidx = cindices[i];
      var vindices = this.getVerseIndices(cidx);
      for(var j=0; j < vindices.length; ++j)
        tuples.push( [cidx, vindices[j]] );
    }
    return tuples;
  }
*/
  this.getChapterIndices = function()
  {
    var indices = [];

    var inRange = function(idx)
    { return 0 < idx && idx <= NR_OF_CHAPTERS; }

    for(var n = 0; n < this.chapters.length; ++n)
    {
      var range = this.chapters[n];
    switch(range.type)
    {
      case Type.Any:
        for(var i = 0; i < NR_OF_CHAPTERS; ++i)
          indices.push( i );
        break;
      case Type.Number:
        if (inRange(range.left))
          indices.push( range.left -1 );
        break;
      case Type.Number_Any:
        if (inRange(range.left))
          for(var i = range.left -1; i < NR_OF_CHAPTERS; ++i)
            indices.push( i );
      case Type.Number_Number:
        var left = range.left, right = range.right;
        if (inRange(left) && inRange(right))
          for(var i = left -1; i < right; ++i)
            indices.push( i );
        break;
      default:
//         assert(0, "Error: unhandled case in switch statement!");
    }
    }
    return indices;
  }

  this.getVerseIndices = function(chapterIdx)
  {
//     assert( 0 <= chapterIdx && chapterIdx < NR_OF_CHAPTERS, "Chapter index out of range.");
    var indices = [];
    for(var n = 0; n < this.verses.length; ++n)
    {
      var range = this.verses[n];
    switch(range.type)
    {
      case Type.Any:
        var end = verses_table[chapterIdx];
        for(var i = 0; i < end; ++i)
          indices.push( i );
        break;
      case Type.Number:
        if (range.left <= verses_table[chapterIdx])
          indices.push( range.left -1 );
        break;
      case Type.Number_Any:
        var end = verses_table[chapterIdx];
        for(var i = range.left -1; i < end; ++i)
          indices.push( i );
        break;
      case Type.Number_Number:
        var end = verses_table[chapterIdx];
        if (range.right < end)
          end = range.right;
        for(var i = range.left -1; i < end; ++i)
          indices.push( i );
        break;
      default:
//         assert(0, "Error: unhandled case in switch statement!");
    }
    }
    return indices;
  }
}

const Type = {
  Any : 0, // *
  Number_Any : 1, // 123-*
  Number : 2, // 123
  Number_Number : 3 // 123-123
}


function Range(type, left, right)
{
  this.type = type;
  this.left = left;
  this.right = right;
}

function ParseError(errorMsg, string, position)
{
  this.msg = errorMsg;
  this.str = string;
  this.pos = position;

  this.toString = function()
  {
//     return format(input,"\n"~repeat(" ",errorPos)~"^\nError in reference list: ",msg);
    return this.errorMsg;
  }
}

/**
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
*/
function ReferenceListParser(str)
{
  this.token = null; /// current token
  // Add '0' as sentinel character for scanner.
  this.str = str + "\0"; /// the input string that is analyzed
  this.p = 0; /// current index into input

  /**
    Splits the input into a list of tokens.
  */
  this.getTokens = function()
  {
    var tokens = [];
    this.nextToken();
    while(this.token.id != TOK.Eos)
    {
      tokens.push( this.token );
      this.nextToken();
    }
    this.resetScanner()
    return tokens;
  }

  /**
    Advance to the next token.
  */
  this.nextToken = function()
  {
    this.scan();
// writefln("nextToken:",token);
    return this.token.id;
  }

  /**
    Resets the scanner.
  */
  this.resetScanner = function()
  {
    this.p = 0;
    this.token = null;
  }

  /**
    Analyzes the input and stores a token at each invocation.
  */
  this.scan = function()
  {
    var tok = new Token();
    var str = this.str;
    var p = this.p;

    Lwhile_loop:
    while (1)
    {
      var c = str.charAt(p);
      switch (c)
      {
        case '\0':
          tok.id = TOK.Eos;
          tok.pos = p;
          break Lwhile_loop;
        case ' ':
        case '\t':
          ++p;
          continue;
        case '0':case '1':case '2':case '3':case '4':
        case '5':case '6':case '7':case '8':case '9':
          var begin = p;

          do
          {
            ++p;
            c = str.charAt(p);
          } while ('0' <= c && c <= '9');
          tok.id = TOK.Number;
          tok.number = parseInt(str.slice(begin, p), 10);
          tok.pos = p - 1;
          break Lwhile_loop;
        case ':':
        case '-':
        case '+':
        case '*':
        case ',':
        case ';':
          tok.id  = CharToTOK[c];
          tok.c   = c;
          tok.pos = p;
          ++p;
          break Lwhile_loop;
        default:
          throw new ParseError("illegal token found.", str, p);
      }
    }
    this.p = p;
    this.token = tok;
  }

  /**
  <pre>
    References:
      Reference
      Reference ' ' References
      Reference ';' References
  </pre>
  */
  this.parseReferences = function()
  {
    this.nextToken(); // start scanner

    var refs = [];
    while (this.token.id != TOK.Eos)
    {
      refs.push(this.parseReference());
      if (this.token.id == TOK.Number || this.token.id == TOK.Wildcard)
        continue;
      if (this.token.id != TOK.Semicolon &&
          this.token.id != TOK.Eos &&
          this.token.id != TOK.Number
      )
        throw new ParseError("expected number, semicolon or end of input, but found " + token.toString(), this.str, this.token.pos);
    }
    return refs;
  }

  /**
  <pre>
    Reference:
      List
      List ':' List
    List:
      Range
      Range ',' List
  </pre>
  */
  this.parseReference = function()
  {
    var left = [], right = [];

    this.parseList(left);
    if (this.token.id == TOK.Colon)
    {
      this.nextToken();
      this.parseList(right);
    }

    return new Reference(left, right);
  }

  this.parseList = function(list)
  {
    do
    {
      list.push(this.parseRange());
    } while (this.token.id == TOK.Comma && this.nextToken())
  }

  /**
  <pre>
    Range:
      *
      Number
      Number '-' '*'
      Number '-' Number
      Number '+' Number
  </pre>
 */
  this.parseRange = function()
  {
    var left, right;
    var type;

    var this_ = this;
    var error = function() {
      throw new ParseError("number or '*' expected, not " + this_.token.toString(), this_.str, this_.token.pos);
    }

    var skipNextToken = false;

    switch (this.token.id)
    {
      case TOK.Number:
        left = this.token.number;
        type = Type.Number;

        if (this.nextToken() == TOK.Dash )
        {
          switch (this.nextToken())
          {
            case TOK.Number:
              right = this.token.number;
              type = Type.Number_Number;
              break;
            case TOK.Wildcard:
              type = Type.Number_Any;
              break;
            default:
              error();
          }
        }
        else if (this.token.id == TOK.Plus)
        {
          if (this.nextToken() != TOK.Number)
            error();
          right = left + token.number;
          type = Type.Number_Number;
        }
        else
          skipNextToken = true; // skip nextToken() below
        break;
      case TOK.Wildcard:
        type = Type.Any;
        break;
      default:
        error();
    }
    if (skipNextToken == false)
      this.nextToken();
    return new Range(type, left, right);
  }
}