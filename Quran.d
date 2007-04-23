/**
  Author: Aziz Köksal
  License: GPL2
*/
module Quran;

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

/+
  A table of offset values to the start of a chapter
  in an array of all verses in the Qur'an.
+/
const int[NR_OF_CHAPTERS] chapter_offset_table = [
    0,    7,  293,  493,  669,  789,
  954, 1160, 1235, 1364, 1473, 1596,
 1707, 1750, 1802, 1901, 2029, 2140,
 2250, 2348, 2483, 2595, 2673, 2791,
 2855, 2932, 3159, 3252, 3340, 3409,
 3469, 3503, 3533, 3606, 3660, 3705,
 3788, 3970, 4058, 4133, 4218, 4272,
 4325, 4414, 4473, 4510, 4545, 4583,
 4612, 4630, 4675, 4735, 4784, 4846,
 4901, 4979, 5075, 5104, 5126, 5150,
 5163, 5177, 5188, 5199, 5217, 5229,
 5241, 5271, 5323, 5375, 5419, 5447,
 5475, 5495, 5551, 5591, 5622, 5672,
 5712, 5758, 5800, 5829, 5848, 5884,
 5909, 5931, 5948, 5967, 5993, 6023,
 6043, 6058, 6079, 6090, 6098, 6106,
 6125, 6130, 6138, 6146, 6157, 6168,
 6176, 6179, 6188, 6193, 6197, 6204,
 6207, 6213, 6216, 6221, 6225, 6230
];

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

  public char[][] chapter(int chapterIndex)
  in { assert( 0 <= chapterIndex && chapterIndex < 114 ); }
  body
  {
    int flatChapterIdx = chapter_offset_table[chapterIndex];
    return verses[flatChapterIdx .. (flatChapterIdx + verses_table[chapterIndex])];
  }

  public char[] getAuthor()
  { return author; }

  private char[] author;
  private char[] language;
  private char[] fileName;
  private char[][] verses;
}
