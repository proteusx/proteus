#!/usr/bin/perl
#===============================================================================
#
#         FILE:  make-canon.pl
#
#        USAGE:  ./make-canon.pl
#
#  DESCRIPTION:  Create canons file used by proteus
#                Generate canons as perl hashes
#                for all phi databases.
#                Extract data from the existing
#                authtabs (eg authortab.dir) -> get author_id, author
#                Also for each author_id extracts from:
#                .idt (author, book_id, book, block number, citation data),
#                .txt file (line count, text width, margin width),
#                And decodes the canon files (doccan2.txt, lat9999.txt).
#                Generates one hash structure per corpus.
#                All canon hashes are combined in a single hash:
#                $canons{corpus} = frozen(%canon)
#                and stored to a file
#
#
# REQUIREMENTS:  - proteusrc to read the location of
#                - tlg, phi5 and phi7 cd-rom files,
#                - read_idt to decode .idt files,
#                - tlg2u to decode .txt files,
#                - dpp-authtab.dir (ddp corpus author table)
#
#       AUTHOR:  proteuss@sdf.org
#      VERSION:  4.0
#      CREATED:  07/06/2010
#===============================================================================
#
#
#
#
#---------------------------------------------------------------------------
#                  The %canon data structure
#---------------------------------------------------------------------------
#%canon = (
# 'author_id' => {
#                 'key'     => 'xxxx'
#                 'nam'     => 'e.g. Comarius',
#                 'epi'     => 'e.g. Alchem.',
#                 'dat'     => 'e.g. 5 B.C.',
#                 'gen'     => 'genre, e.g. math.',
#                 'geo'     => 'e.g. Atheniensis',
#                 'vid'     => 'related authors',
#                 'books'   => {                          # hash ref
#                                 'book_id' => {
#                                               'key'    => 'xxxx xxx'
#                                               'blk'    => "starting 8k block",
#                                               'wrk'    => "book title",
#                                               'cla'    => 'work classification',
#                                               'lines'  => '225',
#                                               'wct'    => '2,355',
#                                               'text'   => '73',  # chars
#                                               'margin' => '0',   # chars
#                                               'cit'    => 'Volume/page/line',
#                                               'ed1'    => 'printed edition 1'
#                                               'ed2'    => 'printed edition 2'
#                                               'lang'   => 'greek(g) or latin(l)'
#                                             }
#                                 },
#                  },
#          )
#---------------------------------------------------------------------------
# TODO read dirs from proteusrc. -- Done!
#----------------------------------------------------------------------------
use strict;
use warnings;
use bytes;
use Data::Dumper;
use File::Slurp;
use Encode;
use Storable qw/store retrieve freeze thaw/;
$Storable::canonical=1;

# prototypes
sub combine_edition(@);
sub escapes($) ;
sub test_file($);
sub read_tlg_canon ;
sub read_latin_canon;
sub read_ddp_canon ;

#--------------------------------------
#  Decoding programs
#  Verify they exist
#--------------------------------------
# my $bin_dir = './bin/';
my $bin_dir = '/usr/local/proteus/bin/';
my $idt_decode_prog = $bin_dir . 'read_idt';         # .idt-decoder
die if &test_file($idt_decode_prog);
my $txt_decode_prog = $bin_dir . 'tlg2u';            # .txt-decoder
die if &test_file($txt_decode_prog);

# The ddp corpus has no author table.
# We have made our own from Web info
# look for this file in the current dir.
my $ddp_authtab='./canons/dpp-authtab.dir' ;
die if &test_file($ddp_authtab);
#--------------------------------------
# Corpus directories
# These are read from
# proteusrc file
#--------------------------------------
my ($tlg_dir, $phi5_dir, $phi7_dir);
my $rc_file = './proteusrc';
# if rc file exists read dirs from it
die if (&test_file($rc_file));

# Read  CDROM directories from proteusrc
# Sets variables $tlg_dir, $phi5_dir and $phi7_dir
#
# FIXME This is not robust.  It assumes that the top 3 lines
# are the 3 dir variables.
eval (join ';', (split /\;/, read_file($rc_file))[0 .. 2]);

my @corpi = qw/lat civ ins chr ddp tlg/;
#my @corpi = qw/ddp/; # for testing

# set the directory for each corpus
my %dirs = (
  'ins' => $phi7_dir,
  'ddp' => $phi7_dir,
  'chr' => $phi7_dir,
  'lat' => $phi5_dir,
  'civ' => $phi5_dir,
  'tlg' => $tlg_dir
);
# print $_, ": ",$dirs{$_}, "\n" foreach @corpi;
#--------------------------------------
#     Global vars
#--------------------------------------
# my @corpi = qw/tlg/;
my $canon_dir = './';            # only for ddp_authtab canon
my $dir;                         # The working corpus directory
my %canon;
my %canons;                  #frozen canons store, $canons{$corpus} = (frozen %canon)
my $canon_file = './canons';    # output canon file

#--------------------------------------
# Titles and descriptions often
# contain escape beta codes (% or #).
# Define them here. (may need more).
#
my %punctuation = (
      1   => '?', # Latin '?'  # question
      3   => '/',              # slash
      4   => '!',              # exclamation
      5   => '|', #            # vertical
      6   => '=',              # equal
      7   => '+',              # plus
      8   => '%',              # percent
      9   => '&',              # ampersand
      10  => ':',              # dicolon
      18  => '\'',
      19  => "-", # %19 u2013 utf8-e28093 en-dash
      # combining accents
      20  => '́',  # acute 20             c_oxy
      21  => '̀',  # grave 21             c_bary
      22  => '̂',  # circumflex 22        c_circum
      24  => '̃',  # tilde 24             c_tilde
      25  => '̧',  # cedilla 25           c_cedil
      27  => '̆',  # breve 27             c_breve
      28  => '̈',  # diaresis umlout'     c_diaer
    );

#--------------------------------------
#             Main
#--------------------------------------
foreach my $corpus (@corpi) {
  $dir = $dirs{$corpus};
  print "Processing Corpus:  $corpus ($dir), ";
  #--------------------------------------
  # Read table of contents (authtab.dir)
  #--------------------------------------
  my $authtab = $dir . 'authtab.dir';
  die if &test_file($authtab);
  my $slurp = read_file($authtab, err_mode => 'carp');
  $slurp =~ s/[\x00-\x1f]+//g;
  $slurp =~ s/\x80/ /g;
  $slurp =~ s/\x83/|/g;
  my @entries = split ( /[\x80-\xff]+/, $slurp);
  undef %canon;
  my ( $author_id, $book_id, $level_id, $author, $book, $block_no, $lang);
  my $authors_total = 0;   # author counter;
  my $works_total = 0;     # works in corpus counter
  foreach my $entry(@entries) {
    #------------------------------------------
    # Each entry in the table of contents
    # corresponds to an author
    # extract the author_id, author name and lang.
    # Read the idt file of the author.
    #------------------------------------------
    next unless ($entry =~ /^(?:$corpus)\d/i);    # match only corpus
    if ($entry =~ /(?:$corpus)(\d+) (\S.+)\|(\w)$/i){
      ($author_id, $author, $lang) = ($1, $2, $3);
    }
    elsif ($entry =~ /(?:$corpus)(\d+) (\S.+)$/i){
      ($author_id, $author) = ($1, $2);
      $lang = 'g'; # Greek is the default but some ddp's are latin
                   # do these by hand
                   # FIXME Some latin ddp's have problems.
                   # $ -> greek in strange places.
    }
    $author =~ s/\&1(\w+\.?)\&/uc$1/ge;  # uc the main name
    $lang = uc $lang;
    next unless $lang =~ /[lg]/i; # exclude h and c
    # Read the idt file
    my $idt_file = $dir . $corpus . $author_id . '.idt';
    my @idt_data = `$idt_decode_prog $idt_file`;
    my $cit='';                                   # citations string
    $authors_total++;
    $works_total += scalar @idt_data;
    foreach (@idt_data){
      #-----------------------------------------------
      # idt decoder returns string:
      # "author_id | book_id | block_no | author |
      # book | [level_id | level]" for each book.
      # For each book decode the book's data from the
      # author's txt file and read text_width, margin
      # width and line count
      #-----------------------------------------------
      chomp $_;
      my @entries = split /\|/, $_;
      my ($aut_id, $aut);  # dummies
      ($aut_id, $book_id, $block_no, $aut, $book) = splice( @entries, 0, 5 );
      $author = $aut if $corpus =~ 'civ';
      $book = $author unless $book =~ /\w/;     # empty book title -> same as author
      if ( ( $corpus ne 'civ') ||  ( $book_id == 1) ) {  # civ cits repeat first book
        $cit='';
        push @entries, ' ' unless $#entries % 2;  # in case odd number of elements
        my %levels = @entries;    # the rest is level data
        foreach (4,3,2,1,0){
          (defined $levels{$_}) ? ($cit .= "$levels{$_}/") : ($cit .= '/');
        }
        # Clean up empty ////s and return 'Line' if all are empty.
        $cit = 'line' unless($cit =~ s#^/+(\w.*)/$#$1#);
      }
      # Read the .txt file,  -n = canon run.
      my $txt_data = `$txt_decode_prog -c $corpus -$lang -n -d $dir -a $author_id -b $book_id`;
      # -----------------------------------------------------------------------
      # txt_decoder returns string: text_width, margin_width, lines
      # -----------------------------------------------------------------------
      chomp $txt_data;
      unless ($corpus =~ /tlg/)
      {
        $author = ${&escapes(\$author)};
        $book = ${&escapes(\$book)};
        # These are extracted from doccan2.txt
        $canon{$author_id}->{key} = $author_id;
        $canon{$author_id}->{nam} = $author;
        $canon{$author_id}->{books}->{$book_id}->{key} = "$author_id $book_id";
        $canon{$author_id}->{books}->{$book_id}->{wrk} = $book;
        $canon{$author_id}->{books}->{$book_id}->{cit} = $cit;
      }
      $canon{$author_id}->{books}->{$book_id}->{blk} = $block_no;
      $canon{$author_id}->{books}->{$book_id}->{lang} = $lang;
      $canon{$author_id}->{books}->{$book_id}->{ed1} = '';
      $canon{$author_id}->{books}->{$book_id}->{ed2} = '';
      ( $canon{$author_id}->{books}->{$book_id}->{text},
        $canon{$author_id}->{books}->{$book_id}->{margin},
        $canon{$author_id}->{books}->{$book_id}->{lines}) = split /,/, $txt_data;
    }
  } # -- end foreach entry
  # read additional data for some corpi
  # to include in canon
  &read_latin_canon if $corpus eq 'lat' ;
  &read_ddp_canon if $corpus eq 'ddp';
  if ( $corpus eq 'tlg')
  {
    &read_tlg_canon ;
    #-----------------------------------------------------------
    #  Read file with corrected dates
    #  and put them in %jiang{id} = "date"
    #-----------------------------------------------------------
    my %jiang ;
    my $amend_file = 'dates-jiang.csv';  # Thanks to Jiang Quian
    my @jiang_dates = split ( /\n/, read_file($amend_file) );
    foreach (@jiang_dates){
      my @author = split ( /, /, $_);
      $jiang{$author[0]} = $author[1];
    }
    #-----------------------------------------------------------
    foreach my $author_id (keys %canon)
    {
      foreach my $book_id (keys %{$canon{$author_id}->{books}})
      {
        &combine_edition($author_id, $book_id);
      }
      #-----------------------------------------------------------
      #  If a corrected date exists in %jiang
      #  overwrite {dat} field with the new data
      #-----------------------------------------------------------
      if ($jiang{$author_id}){
        $canon{$author_id}->{dat} = $jiang{$author_id} . " *";
      }
      #-----------------------------------------------------------
    }
  }

  #---------------------------------------------------
  # Save the hash in a file ready for use by proteus
  #----------------------------------------------------
  $canons{$corpus} =  freeze(\%canon) ;     # is a string
  # utf8::downgrade($canons{$corpus});
  print "Frozen!\n";
  print "Total authors: $authors_total,  Total Works: $works_total\n\n";
} # --- end foreach corpus
store(\%canons, $canon_file) or die "Error in storing %a in $canon_file!\n";
print "All Done!\n";

#---------------------------------------------------------------------------
# Subroutines
#---------------------------------------------------------------------------
sub read_tlg_canon
{
  # read and decode the canon file (doccan2.txt)
  # into list of lines.
  my $doccan_file = $dir . "doccan2.txt";         # canon file
  die if &test_file($doccan_file);
  my @doccan = `$txt_decode_prog -L -C $doccan_file`;
  my ($author_id, $book_id, $entry, $key);

  # extract author and book information
  # and put in a hash (%canon)
  # primary key is the author id
  #
  foreach (@doccan){
    my ($entry, $txt_data);
    chomp ;
    $_ =~ s/\s+$//;                               # remove trailing spaces
    if (/^(\d+)\.(\d*a*)\.\d+\s+(\S.*)$/){        # data line, drop all others
      ($author_id, $book_id, $entry) = ($1, $2, $3);
      $author_id = sprintf("%04d", $author_id);

      if($book_id =~ /a/){                          # a = author fields
        if ($entry =~ /^(\w\w\w)\s(.*)$/) {
          ($key, $txt_data) = ($1, $2);
          if (exists $canon{$author_id}->{$key}){   # append if key exists
            $canon{$author_id}->{$key} .= ", $txt_data";
          }
          else{
            $canon{$author_id}->{$key} = $txt_data;
          }
        }
        else{                                      # Continuation line
          $entry =~ /^\s+/;
          $canon{$author_id}->{$key} .= " $entry";
        }
      } # -- end if author field
      else{                                         # book fields
        $book_id = sprintf("%03d", $book_id);
        if ($entry =~ /^(\w\w\w)\s(.*)$/) {
          ($key, $txt_data) = ($1, $2);
          if (exists $canon{$author_id}->{books}->{$book_id}->{$key}){
            $canon{$author_id}->{books}->{$book_id}->{$key} .= ", $txt_data";
          }
          else{
            $canon{$author_id}->{books}->{$book_id}->{$key} = $txt_data;
          }
        }
        else{                                       # Continuation line
          $entry =~ /^\s+/;
          $canon{$author_id}->{books}->{$book_id}->{$key} .= " $entry";
        }
      } # --- end if book field
    } # --- end if match data line
  } # ---end foreach @doccan
} # ---end sub read tlg_canon
#-----------------------------------------------------
sub escapes($) {
  my $ref = shift @_;
	$$ref =~ s#[\&\$]\d*`?##g; 		# remove font controls
  # replace punctuation symbols (#n escapes)
  $$ref =~ s/\+/$punctuation{28}/gex;
  $$ref =~ s/\\/$punctuation{21}/gex;
  $$ref =~ s/\//$punctuation{20}/gex;
  $$ref =~ s/=/$punctuation{22}/gex;
  $$ref =~ s/\%(\d*)`?/$punctuation{$1}/gex;
	$$ref =~ s#`##g;			# remove separators
  return $ref;
}
#-----------------------------------------------------
sub read_latin_canon {
  #---------------------------------------------------
  # Only for latin corpus
  # Read and decode the latin canon file
  # extract hard copy info into ed1 and ed2 fields
  #---------------------------------------------------
  # latin canon (printed ed details only).
  my $doccan_file = $dir . "lat9999.txt";
  return if &test_file($doccan_file);
  my $slurp = `$txt_decode_prog -L $doccan_file`;
  my @entries = split(/^\s*$/m, $slurp);
  foreach (@entries){
    chomp $_;
    $_ =~ s/\s+/ /mg;
    $_ =~ s/^\s//;
    $_ =~ s/\n//g;
    $_ =~ /^(\w.*) \((.*)\)\. \{(\d+)\.(\d+)\}/;
    my ($auth_book, $ed, $author_id, $book_id) = ($1, $2, $3, $4);
    $ed =~ /^(.*,) (.*, \d*)$/;
    my $ed1 = $1;
    my $ed2 = $2;
    $canon{$author_id}->{books}->{$book_id}->{ed1} = $ed1;
    $canon{$author_id}->{books}->{$book_id}->{ed2} = $ed2;
  }
} # -- end sub read_lat_canon

#----------------------------------------------------
sub combine_edition(@){
  #----------------------------------------------------
  # Conbine printed edition data
  # and delete irelevant fields
  # Hard copy book info now in fields
  # 'ed1' and 'ed2'
  #----------------------------------------------------
  my ($author_id, $book_id) = @_;
  my $line1 = my $line2 ='';
  my $tit = $canon{$author_id}->{books}->{$book_id}->{tit};
  my $pub = $canon{$author_id}->{books}->{$book_id}->{pub};
  my $pla = $canon{$author_id}->{books}->{$book_id}->{pla};
  my $pyr = $canon{$author_id}->{books}->{$book_id}->{pyr};
  my $ryr = $canon{$author_id}->{books}->{$book_id}->{ryr};
  my $pag = $canon{$author_id}->{books}->{$book_id}->{pag};
  my $edr = $canon{$author_id}->{books}->{$book_id}->{edr};
  foreach ($tit,$pub,$pla,$pyr,$ryr,$pag,$edr){$_ = '' unless defined $_;}
  $edr .= " (Ed)"  if $edr;
  foreach ($tit, $edr) { $line1 .= "$_, " if $_};
  $line1 =~s/, $// ;
  $pla .= ":" if $pla;
  $pag = "p.p. $pag" if $pag;
  foreach ($pla, $pub, $pyr, $ryr, $pag) { $line2 .= "$_, " if $_};
  $line2 =~s/, $//;
  $line2 =~s/:, /: /;
  $canon{$author_id}->{books}->{$book_id}->{ed1} = $line1;
  $canon{$author_id}->{books}->{$book_id}->{ed2} = $line2;
  $canon{$author_id}->{books}->{$book_id}->{lang} = 'G';
  #delete unwanted keys
  foreach (qw/tit pub pla pyr ryr pag edr xmt typ crt ser rpu rpl brk/){
    delete $canon{$author_id}->{books}->{$book_id}->{$_}
  }
} # -- end sub combine editions
sub read_ddp_canon {
  #---------------------------------
  # dpp-authtab.dir contains additional info
  # for some files
  # as obtained from the internet
  #----------------------------------
  # my $file = $canon_dir . 'dpp-authtab.dir';
  my $file = $ddp_authtab;
  return if &test_file($file);
  open(FILE, $file);
  while(<FILE>)
  {
    chomp;
    $_ =~/^(\w.+?): (\w.*\.) \((Greek|Latin)\)\s*$/;
    my ($author, $long, $lang) = ($1, $2, $3);
#    print "$author --- $long ---  $lang\n";
    $author =~ s/\.//g;
    $author =~ s/\s*//g;
    $lang =~s/Greek//;
    foreach my $id (values %canon)
    {
      if ($id->{nam} eq $author)
      {
        $id->{nam} .= " - $long" ;
        if ($lang =~ /L/i)
        {
          # some files are latin
          # this has been added manualy in the file
          # see: ddp0203 for example
          $id->{nam} .= " ($lang)";
          $_->{lang} = 'l' foreach (values %{$id->{books}})
        }
      }
    }
  }
  close FILE;
};
#---------------------------------------------------------------
sub test_file($) {
  my $file =  shift @_;
  return 0 if( -e  $file );
  warn "Error! File: $file Not found: $!\n";
  return 1;
}

