/**
  Author: Aziz Köksal
  License: GPL2
*/
module Query;
import std.string;
import fuzzy;
static import std.regexp;
alias std.regexp RX;

abstract class Query
{
  this(char[] query)
  { this.query = query; }

  int find(char[]);

  int find(char[], ref int[2][]);

  char[] toString()
  {
    return query;
  }

  char[] query;
}

bool findAll(Query[] queries, char[] text)
{
  bool found = queries.length ? true : false;
  foreach(query; queries)
  {
    found &= query.find(text) != 0;
    if (!found)
      break;
  }
  return found;
}

bool findAll2(Query[] queries, char[] text, ref int[2][] matchIndices)
{
  bool found = queries.length ? true : false;
  foreach(query; queries)
  {
    found &= query.find(text, matchIndices) != 0;
    if (!found)
      break;
  }
  return found;
}

bool findAny(Query[] queries, char[] text)
{
  foreach(query; queries)
    if (query.find(text))
      return true;
  return false;
}

bool findAny2(Query[] queries, char[] text, ref int[2][] matchIndices)
{
  bool found;
  foreach(query; queries)
    found |= query.find(text, matchIndices) != 0;
  return found;
}

class SimpleQuery : Query
{
  this(char[] query)
  { super(query); }

  int find(char[] text, ref int[2][] matchIndices)
  {
    uint start, total;
    while ((start = ifind(text[total .. $], query)) != -1 )
    {
      total += start;
      matchIndices ~= [total, total + query.length];
      total += query.length;
    }
    return total != 0;
  }

  int find(char[] text)
  {
    return ifind(text, query) != -1;
  }
}

class FuzzyQuery : Query
{
  this(char[] query)
  { super(tolower(query)); }

  int find(char[] text, ref int[2][] matchIndices)
  {
    int matchIndicesLen = matchIndices.length;
    SplitUniAlpha towords;
    towords.text = text;
    foreach(index, word; towords)
    {
      uint maxDistance = query.length > word.length ? query.length : word.length;
      uint levDistance = levenshtein_distance(query, tolower(word));
      if (levDistance == 0 ||
          (cast(float)levDistance / maxDistance) <= 0.3)
      {
        matchIndices ~= [index, index + word.length];
      }
    }
    return matchIndicesLen != matchIndices.length;
  }

  int find(char[] text)
  {
    SplitUniAlpha towords;
    towords.text = text;
    foreach(index, word; towords)
    {
      uint maxDistance = query.length > word.length ? query.length : word.length;
      uint levDistance = levenshtein_distance(query, tolower(word));
      if (levDistance == 0)
      {
        return 1; // Exact match
      }
      if ((cast(float)levDistance / maxDistance) <= 0.3)
      {
        return 1; // Deviates about 30 percent
      }
    }
    return 0;
  }
}

class RegExpQuery : Query
{
  this(char[] query, char[] flags)
  {
    super(query);
    rx = new RX.RegExp(query, flags);
  }

  int find(char[] text, ref int[2][] matchIndices)
  {
    bool match;
    if (rx.test(text)) {
      match = true;
      goto L;
      while (rx.test())
      L:
        matchIndices ~= [rx.pmatch[0].rm_so, rx.pmatch[0].rm_eo];
    }

    return match;
  }

  int find(char[] text)
  {
    return rx.test(text);
  }

  RX.RegExp rx;
}

import std.uni, std.utf;
Query[] parseQuery(char[] query)
{
  dchar[] q = toUTF32(query);
  Query[] queries;

  for (uint i; i < q.length; ++i)
  {
    dchar c = q[i];
    if (isUniAlpha(c) || ('0' <= c && c <= '9'))
    {
      uint end = i + 1;
      for (; end < q.length; ++end)
      {
        dchar d = q[end];
        if (!(isUniAlpha(d) || ('0' <= d && d <= '9')))
          break;
      }
      queries ~= new SimpleQuery(toUTF8(q[i .. end]));
      i = end - 1;
    }
    else if (c == '~')
    {
      ++i;
      uint end = i;
      for (; end < q.length; ++end)
      {
        dchar d = q[end];
        if (!(isUniAlpha(d) || ('0' <= d && d <= '9')))
          break;
      }
      if (end == i)
        throw new Error("No characters found after '~'.");
      queries ~= new FuzzyQuery(toUTF8(q[i .. end]));
      i = end - 1;
    }
    else if (c == '/')
    {
      ++i;
      int end = i;
      for (; end < q.length && q[end] != '/'; ++end)
      {}
      if (end == q.length || q[end] != '/')
        throw new Error("Terminating slash of regular expression not found.\n");

      char[] flags;
      if (end + 1 < q.length)
        if (q[end + 1] == 'i')
          flags = "i";
      queries ~= new RegExpQuery(toUTF8(q[i .. end]), flags);
      i = end + flags.length;
    }
  }

  return queries;
}

struct SplitUniAlpha
{
  char[] text;

  int opApply(int delegate(ref int index, ref char[] word) foreachbody)
  {
    int result;
    uint i, j;
    dchar c = decode(text, j);
    for(; i < text.length; (c = decode(text, j)))
    {
      if (isUniAlpha(c))
      {
        uint end = text.length;
        foreach (k, dchar d; text[j..$])
          if (!isUniAlpha(d))
          {
            end = j+k;
            break;
          }
        int index = i;
        char[] word = text[i..end];
        result = foreachbody(index, word);
        if (result)
          break;
        i = end;
        j = end;
      }
      else i = j;
    }
    return result;
  }

}

char[][] splitUniAlpha(char[] text)
{
  char[][] result;
  uint i, j;
  dchar c = decode(text, j);
  for(; i < text.length; (c = decode(text, j)))
  {
    if (isUniAlpha(c))
    {
      uint end = text.length;
      foreach (k, dchar d; text[j..$])
        if (!isUniAlpha(d))
        {
          end = j+k;
          break;
        }
      result ~= text[i..end];
      i = end;
      j = end;
    }
    else i = j;
  }
  return result;
}

/++
  A simple implementation of the quicksort algorithm.
+/
int[2][] quicksort(int[2][] list)
{
  int[2][] less, pivotList, greater;
  if (list.length <= 1)
    return list;
  int pivot = list[0][0];
  foreach(x; list)
    if (x[0] < pivot)
      less ~= x;
    else if (x[0] > pivot)
      greater ~= x;
    else /*if (x[0] == pivot)*/
      pivotList ~= x;
  return quicksort(less) ~ pivotList ~ quicksort(greater);
}

char[] highlightMatches(char[] text, int[2][] matchIndices)
{
  assert(matchIndices.length != 0);
  // Sort the match tuples
  matchIndices = quicksort(matchIndices);
  // Merge overlapping slices.
  int[2][] tmp;
  int i;
  int max(int a, int b){return a<b?b:a;}
  for (; i < (matchIndices.length -1); ++i)
  {
    alias matchIndices m;
    if ((m[i][1]) >= m[i+1][0])
    {
      tmp ~= [m[i][0], max(m[i][1], m[i+1][1])];
      ++i;
    }
    else
      tmp ~= m[i];
  }
  if (i != matchIndices.length)
    tmp ~= matchIndices[$-1];
  // Iterate over the tuples and return a highlighted string
  // with bash color codes or marking characters for Windows.
  int start;
  char[] hltext;
  foreach(offs; tmp)
  {
    version(linux)
      hltext ~= text[start..offs[0]] ~ "\33[31m" ~ text[offs[0]..offs[1]] ~ "\33[0m";
    else
      hltext ~= text[start..offs[0]] ~ "*" ~ text[offs[0]..offs[1]] ~ "*";
    start = offs[1];
  }
  hltext ~= text[start..$];
  return hltext;
}