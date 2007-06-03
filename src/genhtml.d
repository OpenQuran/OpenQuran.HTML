/**
  Author: Aziz Köksal
  License: GPL2
*/
module genhtml;
import std.string;
import std.stdio;
import std.file;
import Quran;
import ReferenceParser;

char[] reflist = "96 68 73 74 1 111 81 87 92 89 93 94 103 100 108 102 107 109 105 113 114 112 53 80 97 91 85 95 106 101 75 104 77 50 90 86 54 38 7 72 36 25 35 19 20 56 26 27 28 17 19 11 12 15 6 37 31 34 39 40 41 42 43 44 45 46 51 88 18 16 71 14 21 23 32 52 67 69 70 78 79 82 84 30 29 83 2 8 3 33 60 4 99 57 47 13 55 76 65 98 59 24 22 63 58 49 66 64 61 62 48 5 9 110";

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


void main(char[][] args)
{
  auto authors = args[1..$];

  char[] Quran_js = readFile("Quran.js");
  char[] ReferenceParser_js = readFile("ReferenceParser.js");
  char[] template_html = readFile("template.html");

  // Expand template macros
  template_html = replace(template_html, "{Quran.js}", Quran_js);

  template_html = replace(template_html, "{ReferenceParser.js}", ReferenceParser_js);

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
    char[] verses = toArrayLiteral(quran.getVerses);
    char[] titles = toArrayLiteral(quran.getTitles);
    char[] authorObject = std.string.format("new Quran(\n%s,\n%s,\n%s\n)", "'"~escapeQuotes(quran.getAuthor)~"'", titles, verses);
    authorsArray ~= authorObject ~ ",\n";
  }
  authorsArray.length = authorsArray.length - 2;
  authorsArray ~= "\n]; // End of Authors array";

  writefln("%s", replace(template_html, "{QuranObjects}", authorsArray));
}
