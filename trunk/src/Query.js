/**
  Author: Aziz Köksal
  License: GPL2
*/
//module Query;

function Search(query, casei)
{
  this.casei = casei;
  this.queries = parseQuery(query, casei);

  this.findAll_ = function(text)
  {
    var found = this.queries.length ? 1 : 0;
    for(var i=0; i < this.queries.length; ++i)
    {
      found &= this.queries[i].find(text);
      if (!found)
        break;
    }
    return found;
  }

  this.findAll2_ = function(text, matchIndices)
  {
    var found = this.queries.length ? 1 : 0;
    for(var i=0; i < this.queries.length; ++i)
    {
      found &= this.queries[i].find2(text, matchIndices);
      if (!found)
        break;
    }
    return found;
  }

  this.findAny_ = function(text)
  {
    for(var i=0; i < this.queries.length; ++i)
      if (this.queries[i].find(text))
        return 1;
    return 0;
  }

  this.findAny2_ = function(text, matchIndices)
  {
    var found = 0;
    for(var i=0; i < this.queries.length; ++i)
      found |= this.queries[i].find2(text, matchIndices);
    return found;
  }

  if (casei)
  {
    this.findAll = function(text) {
      return this.findAll_(text.toLowerCase());
    }
    this.findAll2 = function(text,m) {
      return this.findAll2_(text.toLowerCase(), m);
    }
    this.findAny = function(text) {
      return this.findAny_(text.toLowerCase());
    }
    this.findAny2 = function(text,m) {
      return this.findAny2_(text.toLowerCase(), m);
    }
  }
  else
  {
    this.findAll = this.findAll_;
    this.findAll2 = this.findAll2_;
    this.findAny = this.findAny_;
    this.findAny2 = this.findAny2_;
  }
}

/**
  A simple query looks for str in a text using String.indexOf().
*/
function SimpleQuery(str, negate)
{
  this.query = str;
  this.negate = negate;

  this.find2 = function(text, matchIndices)
  {
    var start = 0, total = 0;
    while ((start = text.slice(total).indexOf(this.query)) != -1 )
    {
      total += start;
      matchIndices.push( [total, total + this.query.length] );
      total += this.query.length;
    }
    return (total != 0) ^ this.negate;
  }

  this.find = function(text)
  {
    return (text.indexOf(this.query) != -1) ^ this.negate;
  }
}

/**
  A regular expression query.
*/
function RegExpQuery(query, flags, negate)
{
  this.rx = new RegExp(query, flags + "g");
  this.negate = negate;

  this.find2 = function(text, matchIndices)
  {
    var found = 0;
    var m;
    if (m = this.rx.exec(text))
    {
      found = 1;
      do
      {
        matchIndices.push( [m.index, this.rx.lastIndex] );
      } while (m = this.rx.exec(text));
    }
    return found ^ this.negate;
  }

  this.find = function(text)
  {
    this.rx.lastIndex = 0;
    return this.rx.test(text) ^ this.negate;
  }
}

function isspace(c)
{
  if (c == ' ' || c == '\t')
    return true;
  return false;
}

/**
  Parses a query string into an array of Query objects.
*/
function parseQuery(q, casei)
{
  var toLower = casei ?
    function(t){return t.toLowerCase();} :
    function(t){return t;};

  var queries = [];

  var end = 0;
  var negate = 0;
  for (var i=0; i < q.length; ++i)
  {
    var c = q.charAt(i);

    if (c == '-')
    {
      negate = 1;
    }
    else if (c == '/')
    {
      ++i;
      end = q.slice(i).indexOf('/');
      if (end == -1)
        throw new Error("terminating slash of regular expression not found.\n");
      end += i; // add i, because we sliced the string above
      var flags = "";
      if (end + 1 < q.length)
        if (q.charAt(end + 1) == 'i')
          flags = "i";
      queries.push( new RegExpQuery(q.slice(i, end), (casei ? "i":flags), negate) );
      i = end + flags.length;
    }
    else if (c == '"')
    {
      ++i;
      end = q.slice(i).indexOf('"');
      if (end == -1)
        throw new Error("terminating double quote not found.");
      end += i;
      queries.push( new SimpleQuery(toLower(q.slice(i, end)), negate) );
      i = end;
    }
    else if (!isspace(c))
    {
      end = i + 1;
      for (; end < q.length; ++end)
      {
        c = q.charAt(end);
        if (isspace(c))
          break;
      }
      queries.push( new SimpleQuery(toLower(q.slice(i, end)), negate) );
      i = end - 1;
    }
    else
      negate = 0;
  }

  return queries;
}


/// Compare function for sorting match indices.
function compareFunction(a, b)
{
  a = a[0]; b = b[0];
  if (a < b)
    return -1;
  if (a > b)
    return 1;
  return 0;
}

/**
  Takes a list of two-pair index values, slices the text and inserts
  em-tags at those positions.
*/
function highlightMatches(text, m)
{
  if (!m || !m.length)
    return text;

  // Sort the match tuples
  m.sort(compareFunction);

  function max(a, b){ return a<b?b:a; }

  // Merge overlapping and adjacent match tuples.
  var m2 = [];
  var i = 1;
  var so = m[0][0], eo = m[0][1];
  for (; i < m.length; ++i)
  {
    if (eo < m[i][0])
    {
      m2.push( [so, eo] );
      so = m[i][0];
      eo = m[i][1];
    }
    else
    {
      eo = max(eo, m[i][1]);
    }
  }
  m2.push( [so, eo] );

  // Iterate over the tuples and return a highlighted string.
  var start;
  var hltext = "";
  for(i = 0; i < m2.length; ++i)
  {
    so = m2[i][0]; eo = m2[i][1];
    hltext += text.slice(start, so) + "<em>" + text.slice(so, eo) + "</em>";
    start = eo;
  }
  hltext += text.slice(start);
  return hltext;
}
