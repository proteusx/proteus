/* Latin combining accents */
#define UMLAUT  0x0308
#define GRAVE   0x0300
#define ACUTE   0x0301
#define CARET   0x0302

/* Capital special symbols
 * The rest are handled by the
 * handle_escape_codes routine*/
#define KOPA    0x03de
#define STIGMA  0x03da
#define ARKOPA  0x03d8
#define SAMPI   0x03e0

/* Other code defines */
#define GREEK_UPPER 0x3f                        /* print '?' */
#define ACCENT 0x2f                             /* print '/' */
#define SIGMEDIAL 0x3c3
#define SIGFINAL 0x3c2

/* --------------------- Table of Greek Letters ------------------------ */
/* TLG stream translation table -- Unicode
   A B G D E Z H Q I K L M N C O P R S T U F X Y W V; V is digamma
   A value under 0x20 is a state change control code.
   Zero means no character.
 */
unsigned int greek[] = {
        /* sp     !     "     #     $     %     &     ' */
         0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
        /*    (       )               *       +     ,     -     .       / */
         ACCENT, ACCENT, GREEK_UPPER, ACCENT, 0x2c, 0x2d, 0x2e, ACCENT,
        /*  0     1     2     3     4     5     6     7 */
         0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
        /*  8     9     :     ;     <     =     >     ?     @ */
         0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f, 0x40,
        /*   a      b      c      d      e      f      g      h */
         0x3b1, 0x3b2, 0x3be, 0x3b4, 0x3b5, 0x3c6, 0x3b3, 0x3b7,
        /*   i      j      k      l      m      n      o      p */
         0x3b9, 0x3c2, 0x3ba, 0x3bb, 0x3bc, 0x3bd, 0x3bf, 0x3c0,
        /*   q      r      s      t      u      v      w     x */
         0x3b8, 0x3c1, 0x3c2, 0x3c4, 0x3c5, 0x3dd, 0x3c9, 0x3c7,
        /*   y      z     [     \     ]     ^     _  sep`*/
         0x3c8, 0x3b6, 0x54, 0x55, 0x56, 0x57, 0x00, 0x00,
        /*   A      B      C      D      E      F      G      H */
         0x391, 0x392, 0x39e, 0x394, 0x395, 0x3a6, 0x393, 0x397,
        /*   I      J      K      L      M      N      O      P */
         0x399, 0x3A3, 0x39a, 0x39b, 0x39c, 0x39d, 0x39f, 0x3a0,
        /*   Q      R      S      T      U      V      W      X */
         0x398, 0x3a1, 0x3a3, 0x3a4, 0x3a5, 0x3dc, 0x3a9, 0x3a7,
        /*   Y      Z     {     |     }     ~   DEL */
         0x3a8, 0x396, 0x7b, 0x7c, 0x7d, 0x00, 0x00};

/* --------------------- Table of Accented letters --------------------- */
/* Accents can be described in three groups, all optional
 * In the first group are - mutually exclusive - psili, daseia or dialytika
 * In the second group are - mutually exclusive - oxia, varia or perispomeni
 * In the third group are - mutually exclusive - ypogegrammeni, subscript dot or missing letter dot
 * The last two are not part of fully-formed characters, so they will be added as combining diacritical marks
 * The simplified form is then:
 * [ ) or ( or + ]  [ / or \ or = ]  [ | ]
 *
 * This can be described by 5 accent flag bits (reverse order)
 *
 * 0 00 00 --- 0 00 00 no accent
 * |  |  |
 * |  |   ---- 01 psili, 10 dasia, 11 dialytika
 * |   ------- 01 varia, 10 oxia,  11 perispomeni
 * -----------  1 ypogegrammeni
 *
 * The resulting table of accentable characters will have 32-character rows
 * with the formed character codes in the appropriate positions, or zero:
 * plain, psili, dasia, dialytika, varia, psili-varia, dasia-varia, dialytika-varia
 * oxia, psili-oxia, dasia-oxia, dialytika-oxia, perispomeni, psili-perisp, dasia-perisp, dialytika-perisp
 * ditto with ypogegrammeni
 *
 * If zero is returned, combining diacritical marks should be generated from the accent flags.
 *
 * Credit and thanks to Dimitri Marinakis for this.
 */
unsigned int alpha[] = {
	0x03b1, 0x1f00, 0x1f01, 0x0000, 0x1f70, 0x1f02, 0x1f03, 0x0000,
	0x03ac, 0x1f04, 0x1f05, 0x0000, 0x1fb6, 0x1f06, 0x1f07, 0x0000,
	0x1fb3, 0x1f80, 0x1f81, 0x0000, 0x1fb2, 0x1f82, 0x1f83, 0x0000,
	0x1fb4, 0x1f84, 0x1f85, 0x0000, 0x1fb7, 0x1f86, 0x1f87, 0x0000
	};
unsigned int Alpha[] = {
	0x0391, 0x1f08, 0x1f09, 0x0000, 0x1fba, 0x1f0a, 0x1f0b, 0x0000,
	0x0386, 0x1f0c, 0x1f0d, 0x0000, 0x0000, 0x1f0e, 0x1f0f, 0x0000,
	0x1fbc, 0x1f88, 0x1f89, 0x0000, 0x0000, 0x1f8a, 0x1f8b, 0x0000,
	0x0000, 0x1f8c, 0x1f8d, 0x0000, 0x0000, 0x1f8e, 0x1f8f, 0x0000
	};
unsigned int epsilon[] = {
	0x03b5, 0x1f10, 0x1f11, 0x0000, 0x1f72, 0x1f12, 0x1f13, 0x0000,
	0x03ad, 0x1f14, 0x1f15, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
	};
 unsigned int Epsilon[] = {
	0x0395, 0x1f18, 0x1f19, 0x0000, 0x1fc8, 0x1f1a, 0x1f1b, 0x0000,
	0x0388, 0x1f1c, 0x1f1d, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
	};
unsigned int eta[] = {
	0x03b7, 0x1f20, 0x1f21, 0x0000, 0x1f74, 0x1f22, 0x1f23, 0x0000,
	0x03ae, 0x1f24, 0x1f25, 0x0000, 0x1fc6, 0x1f26, 0x1f27, 0x0000,
	0x1fc3, 0x1f90, 0x1f91, 0x0000, 0x1fc2, 0x1f92, 0x1f93, 0x0000,
	0x1fc4, 0x1f94, 0x1f95, 0x0000, 0x1fc7, 0x1f96, 0x1f97, 0x0000
	};
unsigned int Eta[] = {
	0x0397, 0x1f28, 0x1f29, 0x0000, 0x1fca, 0x1f2a, 0x1f2b, 0x0000,
	0x0389, 0x1f2c, 0x1f2d, 0x0000, 0x0000, 0x1f2e, 0x1f2f, 0x0000,
	0x1fcc, 0x1f98, 0x1f99, 0x0000, 0x0000, 0x1f9a, 0x1f9b, 0x0000,
	0x0000, 0x1f9c, 0x1f9d, 0x0000, 0x0000, 0x1f9e, 0x1f9f, 0x0000
	};
unsigned int iota[] = {
	0x03b9, 0x1f30, 0x1f31, 0x03ca, 0x1f76, 0x1f32, 0x1f33, 0x1fd2,
	0x03af, 0x1f34, 0x1f35, 0x0390, 0x1fd6, 0x1f36, 0x1f37, 0x1fd7,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
	};
 unsigned int Iota[] = {
	0x0399, 0x1f38, 0x1f39, 0x03aa, 0x1fda, 0x1f3a, 0x1f3b, 0x0000,
	0x038a, 0x1f3c, 0x1f3d, 0x0000, 0x0000, 0x1f3e, 0x1f3f, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
	};
unsigned int omicron[] = {
	0x03bf, 0x1f40, 0x1f41, 0x0000, 0x1f78, 0x1f42, 0x1f43, 0x0000,
	0x03cc, 0x1f44, 0x1f45, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
	};
 unsigned int Omicron[] = {
	0x039f, 0x1f48, 0x1f49, 0x0000, 0x1ff8, 0x1f4a, 0x1f4b, 0x0000,
	0x038c, 0x1f4c, 0x1f4d, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
	};
unsigned int ypsilon[] = {
	0x03c5, 0x1f50, 0x1f51, 0x03cb, 0x1f7a, 0x1f52, 0x1f53, 0x1fe2,
	0x03cd, 0x1f54, 0x1f55, 0x03b0, 0x1fe6, 0x1f56, 0x1f57, 0x1fe7,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
	};
 unsigned int Ypsilon[] = {
	0x03a5, 0x0000, 0x1f59, 0x03ab, 0x1fea, 0x0000, 0x1f5b, 0x0000,
	0x038e, 0x0000, 0x1f5d, 0x0000, 0x0000, 0x0000, 0x1f5f, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
	};
unsigned int omega[] = {
	0x03c9, 0x1f60, 0x1f61, 0x0000, 0x1f7c, 0x1f62, 0x1f63, 0x0000,
	0x03ce, 0x1f64, 0x1f65, 0x0000, 0x1ff6, 0x1f66, 0x1f67, 0x0000,
	0x1ff3, 0x1fa0, 0x1fa1, 0x0000, 0x1ff2, 0x1fa2, 0x1fa3, 0x0000,
	0x1ff4, 0x1fa4, 0x1fa5, 0x0000, 0x1ff7, 0x1fa6, 0x1fa7, 0x0000
	};
unsigned int Omega[] = {
	0x03a9, 0x1f68, 0x1f69, 0x0000, 0x1ffa, 0x1f6a, 0x1f6b, 0x0000,
	0x038f, 0x1f6c, 0x1f6d, 0x0000, 0x03a9, 0x1f6e, 0x1f6f, 0x0000,
	0x1ffc, 0x1fa8, 0x1fa9, 0x0000, 0x0000, 0x1faa, 0x1fab, 0x0000,
	0x0000, 0x1fac, 0x1fad, 0x0000, 0x0000, 0x1fae, 0x1faf, 0x0000
	};
unsigned int rho[] = {
	0x03c1, 0x1fe4, 0x1fe5, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
	};
unsigned int Rho[] = {
	0x03a1, 0x0000, 0x1fec, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
	0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
	};
