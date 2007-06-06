/**
  Author: Aziz Köksal
  License: GPL2
*/
//module Query;

function findAll(queries, text)
{
  var found = queries.length ? true : false;
  for(var i=0; i < queries.length; ++i)
  {
    found = queries[i].find(text) && found;
    if (!found)
      break;
  }
  return found;
}

function findAll2(queries, text, matchIndices)
{
  var found = queries.length ? true : false;
  for(var i=0; i < queries.length; ++i)
  {
    found = found && queries[i].find2(text, matchIndices);
    if (!found)
      break;
  }
  return found;
}

function findAny(queries, text)
{
  for(var i=0; i < queries.length; ++i)
    if (queries[i].find(text))
      return true;
  return false;
}

function findAny2(queries, text, matchIndices)
{
  var found = false;
  for(var i=0; i < queries.length; ++i)
    found = found || queries[i].find2(text, matchIndices);
  return found;
}

/**
  A simple query looks for one word in a text using ifind().
*/
function SimpleQuery(str)
{
  this.query = str;

  this.find2 = function(text, matchIndices)
  {
    var start = 0, total = 0;
    while ((start = text.slice(total).indexOf(this.query)) != -1 )
    {
      total += start;
      matchIndices.push( [total, total + this.query.length] );
      total += this.query.length;
    }
    return total != 0;
  }

  this.find = function(text)
  {
    return text.indexOf(this.query) != -1;
  }
}

/**
  A regular expression query.
*/
function RegExpQuery(query, flags)
{
  alert(query);
  this.rx = new RegExp(query, flags + "g");

  this.find2 = function(text, matchIndices)
  {
    var found = false;
    var m;
    if (m = this.rx.exec(text))
    {
      found = true;
      do
      {
        matchIndices.push( [m.index, this.rx.lastIndex] );
      } while (m = this.rx.exec(text));
    }
    return found;
  }

  this.find = function(text)
  {
    return rx.test(text);
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
  Unrecognized characters are ignored.
*/
function parseQuery(q)
{
  var queries = [];

  for (var i=0; i < q.length; ++i)
  {
    var c = q.charAt(i);

    if (c == '/')
    {
      ++i;
      var end = i;
      for (; end < q.length && q.charAt(end) != '/'; ++end)
      {}
      if (end == q.length || q.charAt(end) != '/')
        throw new Error("Terminating slash of regular expression not found.\n");

      var flags = "";
      if (end + 1 < q.length)
        if (q.charAt(end + 1) == 'i')
          flags = "i";
      queries.push( new RegExpQuery(q.slice(i, end), flags) );
      i = end + flags.length;
    }
    else if (!isspace(c))
    {
      var end = i + 1;
      for (; end < q.length; ++end)
      {
        c = q.charAt(end);
        if (isspace(c))
          break;
      }
      queries.push( new SimpleQuery(q.slice(i, end)) );
      i = end - 1;
    }
  }

  return queries;
}


/**
  Takes a list of two-pair index values, slices the text and inserts
  em-tags at those positions.
*/
function highlightMatches(text, m)
{
  /// Compare function for sorting match indices.
  function compareFunction(a, b)
  {
    if (a[0] < b[0])
      return -1;
    if (a[0] > b[0])
      return 1;
    return 0;
  }

  // Sort the match tuples
  m.sort(compareFunction);
  // Merge overlapping slices.
  var tmp = [];
  var i = 0;

  function max(a, b){ return a<b?b:a; }

  for (; i < (m.length -1); ++i)
  {
    if ((m[i][1]) >= m[i+1][0])
    {
      tmp.push( [m[i][0], max(m[i][1], m[i+1][1])] );
      ++i;
    }
    else
      tmp.push( m[i] );
  }

  if (i != m.length)
    tmp.push( m[m.length-1] );
  // Iterate over the tuples and return a highlighted string.
  var start;
  var hltext = "";
  for(i = 0; i < tmp.length; ++i)
  {
    var offs = tmp[i];
    hltext += text.slice(start, offs[0]) + "<em>" + text.slice(offs[0], offs[1]) + "</em>";
    start = offs[1];
  }
  hltext += text.slice(start, text.length);
  return hltext;
}
