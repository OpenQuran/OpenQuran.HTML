/**
  Author: Aziz Köksal
  License: GPL2
*/
module fuzzy;
import std.stdio;
import std.utf;

int min(int a, int b, int c)
{
  int m = a;
  if (b < m)
    m = b;
  else if (c < m)
    m = c;
  return m;
}

size_t utf8len(char[] s)
{
  size_t res;
  while (s.length)
  {
    s = s[stride(s, 0)..$];
    ++res;
  }
  return res;
}

int levenshteinDistance(char[] str1, char[] str2)
{
  int d[2][];
  int i, j, cost;

  // Only two rows are needed
  d[0] = new int[utf8len(str2) + 1];
  d[1] = d[0].dup;

//   d[0][0] = 0;
  foreach (dchar dc; str2)
  {
    ++j;
    d[0][j] = j;
  }
// writefln("      ", str2, "\n", 0, "  ", d[0]);
  foreach (dchar di; str1)
  {
    d[1][0] = ++i;
    j=0;
    foreach (dchar dj; str2)
    {
      if (di == dj)
        cost = 0;
      else
        cost = 1;
      d[1][j+1] = min(d[0][j+1] + 1,     // deletion
                      d[1][ j ] + 1,     // insertion
                      d[0][ j ] + cost); // substitution
// writefln("%s == %s, ", di, dj, d[1][j+1]);
      ++j;
    }
// writefln(i, " ", di, d[1]);
    // Swap rows
    int[] tmp = d[0];
    d[0] = d[1];
    d[1] = tmp;
  }
  return d[0][j];
}