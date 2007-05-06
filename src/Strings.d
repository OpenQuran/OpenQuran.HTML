/**
  A collection of format strings.
  Author: Aziz Köksal
  License: GPL2
*/
module Strings;

/// Indicates whether to use bash color codes in output format strings.
bool useColor;
/++
  Returns an empty string instead of the color code
  when compiled for Windows.
+/
char[] ColorCode(char[] code)
{
  version(Windows)
    return "";
  else
    return useColor ? code : "";
}

char[] Author;
char[] AuthorVerse;
char[] ChapterNrVerseNr;
char[] ChapterNrVerseNrVerse;
char[] HighlightL;
char[] HighlightR;
/++
  Initialize strings without color codes on Windows.
  On Linux it can be turned on and off with the useColor variable.
+/
void init()
{
  alias ColorCode C;
  Author = "["~C("\33[32m")~"%s"~C("\33[0m")~"]";
  AuthorVerse = C("\33[32m")~"%s"~C("\33[0m")~":\n";
  ChapterNrVerseNr = "["~C("\33[34m")~"%03d:%03d"~C("\33[0m")~"]";
  ChapterNrVerseNrVerse = C("\33[34m")~"%03d:%03d"~C("\33[0m")~": ";
  HighlightL = C("\33[31m");
  HighlightR = C("\33[0m");
}