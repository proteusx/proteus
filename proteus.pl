#!/usr/bin/perl
#--------------------------------------------------
#     Uses C utility tlg2u for decoding.
#     Symbols handled by interchartocks
#--------------------------------------------------
my $version_msg = sprintf( << 'END');
TLG to PDF and Unicode Text Converter.

     Version: 10.1.0    (2007 - 2021)

       proteuss@sdf.org
END
#---------------------------------------------
# preliminaries:
# check operating system
# whether xetex is installed
# and fix cwd to absolute path
#---------------------------------------------
my ($OS, $ms_icon, $xetex, $cwd);
BEGIN
{
  use Cwd qw/abs_path cwd/;
  use File::Basename;
  $cwd = dirname(abs_path($0));
  chdir $cwd;
  $OS = $^O;  # linux or MSWIN32
  eval "use Tk::Icon";
  if ($@ || $OS =~ /linux/)
  {
    $ms_icon = 0;  #don't use Tk::Icon
  }
  else
  {
    $ms_icon = 1;
  }
  my $resp = `xelatex -version`;
  ($resp =~/XeTeX/) ? ($xetex = 1): ($xetex = 0);
}
#------------------------------
# If we are runing on M$ Windows
# hide the console
# Needs  Win32::GUI installed
#------------------------------
if ($OS =~ /MS/)
{
  eval
  q{
    use Win32::GUI;
    my $hw = Win32::GUI::GetPerlWindow();
    Win32::GUI::Hide($hw);
  } or warn $@;
}
#---------------------------------------
use strict;
use warnings;
use Tk;
use Tk::BrowseEntry;
use Tk::ROText;
use Tk::PNG;
use File::Copy;
use File::Slurp;
use Data::Dumper;
use Storable qw/store retrieve freeze thaw/;
use Encode qw/decode_utf8/;
use utf8;

#--------------------------------------------------
# Global Variables
#--------------------------------------------------
#------------------------
# directory Variables
#-------------------------
# find users home directory
my $home;
# for windows no home directory
# so use the install directory
if ($OS =~ /MS/)
{
  $home = $cwd;
}
else
{
  # create ~/.proteus if first run or if has been deleted
  $home = (getpwuid $>)[7] . '/.proteus';
  unless (-d $home)
  {
    mkdir $home or die $!;
    mkdir $home . '/books' or die $!;
    copy("$cwd/proteusrc", "$home/proteusrc") or die $!;
    symlink("$cwd/escape_codes.tex", "$home/books/escape_codes.tex");
  }
}
my ($tlg_dir, $phi5_dir, $phi7_dir);
my (%dirs, $results_dir);
my $rc_file = $home . '/proteusrc';

#--------------------------
# Font related
my  (%font_props, %print_font);
my %sample;
my ( $pt_size, $external_font_dir, );
my ( $font_selector,
    @system_fonts, @external_fonts,
    $f_left, $f_right, $tw,
    $size_selector );
my $active_font;
my $sample_text;
my @fonts = qw/Greek Latin Symbol Bold/;
my $list_font="{Times New Roman} 12";
my $gui_font = "{Arial} 10";
#--------------------------
# conversion program
# and cannon location
#--------------------------
my ($tlg2u, $canon_dir);
if ($OS =~ /MS/)
{
  $tlg2u = qq{.\\bin\\tlg2u.exe};
  $canon_dir = qq{.\\canons\\};
}
else
{
  $tlg2u = $cwd . '/bin/tlg2u';
  $canon_dir = $cwd . '/canons/';
}
my $canons_file = 'canons';
#--------------------------------------------------
#     Program Variables
#--------------------------------------------------
my $corpus = '';    # default corpus (save in rc)
my (%canons, %canon);
my ( $works_window, $works_list);
my $corpus_dir_win;  # corpus directories window object
my %author_selection;             # displayed authors
my ( $author_id, $book_id);
my ( $lbot, $ed_box);  # window components that need to be global
my ( $i, $j);                     # list position indexes
my $wait;                         # ms windows wait message
#-----------------------------------
#    Label vars  (to change labels)
#-----------------------------------
my  (
     $number_of_works,
     $page_data, $year,
     $geo, $see_also,
     $max_text, $max_margin,
     $lines_count,
     $wc, $cla, $ed1
   );
#--------------------------
# Options control vars
#--------------------------
my (
    $output_file_type,
    $view, $lines, $cits, $par,
    $marginalia, $tex, $page_nos, $info,
    $page_nos_enable, $ligatures, $bold
   );
#--------------------------
$max_margin = 0; #  default value to dissable option
&defaults;       # read default variables (dirs and fonts)
my $found_corpus;

#--------------------------------------------------
# Main window
#--------------------------------------------------
my $mw = MainWindow->new;
&set_icon(\$mw, 'column');
$mw->optionAdd("*font", $gui_font)  if $OS =~ /linux/;
$mw->title("Author List ($corpus)");
$mw->protocol('WM_DELETE_WINDOW' => sub{&save_rc; exit});
$mw->withdraw();   # withdraw until tlg_dir is found

#-----------------
# retrieve canons
#-----------------
my $canons_ref = retrieve($canon_dir . $canons_file);
unless (defined $canons_ref)
{
  &error_msg("Canons No found!");
  die;
}
%canons = %{$canons_ref};

#--------------
# The menubar
#--------------
my $menubar = $mw->Menu(-menuitems =>&menu_items, -relief =>'flat');
$mw->configure(-menu=> $menubar);
unless ($xetex)    # if xetex is not installed use utf only
{
  $output_file_type = 'unicode';
  my $options = $menubar->entrycget('Files', -menu);
  $options->entryconfigure('Pdf', -state =>'disabled');
  &error_msg("   No TeX installed!\npdf options are disabled.");
}

#--------------------------------
# Check corpus directories
#-------------------------------
$found_corpus = &check_dirs;
unless ($found_corpus)
{
  my $msg1 = "No Valid Corpus Directory Found\n";
  my $msg2 = "I Need at least one to start!\n";
  my $msg3 = 'Use "Corpus Directories" to find.';
  &error_msg ($msg1 . $msg2 . $msg3);
  $corpus = '' if $found_corpus == 0;
  &corpus_locator;
}
$mw->deiconify; # display window now

#----------------
# The search box
#----------------
my $search = '';
my $frm_top = $mw->Frame()->pack( qw/-fill x -pady 3/);
my $search_box = $frm_top->Entry(
                      -textvariable => \$search,
                      -relief =>'sunken',
                      -background =>'ivory2',
                      -border =>'2',
                      -width =>'30',
                      -highlightthickness => 0
                )->pack(qw/-side left -expand 1 -fill x -anchor w /);
$search_box->bind("<KeyPress>", [\&do_search, Tk::Ev("K") ]);
$frm_top->Label(
                -text =>'Search',
                -width =>8
               )->pack(-side => 'right');

#--------------
# Authors list
#--------------
my %authors;
my $authors_list = $mw->Scrolled(
                  'Listbox',
                  -scrollbars => 'osoe',
                  -exportselection => 0,
                  -background => 'ivory1',
                  -selectmode => 'single',
                  -height => 20,
                  -width => 40,
                  -font => $list_font
                            )->pack(qw/-side top -expand 1 -fill both /);
$authors_list->Subwidget("yscrollbar")->configure(-troughcolor=>'skyblue3');
$authors_list->Subwidget("xscrollbar")->configure(-troughcolor=>'skyblue3');
$mw->bind("<KeyPress>", [\&arrow, Tk::Ev("K"), 'authors']);
$authors_list->bind('<ButtonRelease-1>' => [\&arrow, 'mouse', 'authors']);
$i = $j = 0 ;     #  $i=author list index, $j = work list index
&populate_author_list ;

#---------------
# Bottom labels
#---------------
my $bot_frame = $mw->Frame->pack(-side => 'bottom',-fill => 'x');
my $bot_frame_tlg = $mw->Frame->pack(-side => 'bottom',-fill => 'x');
my $see_also_txt = $bot_frame->ROText( -height => 1,
                                       -font   => '{Arial} 10',
                                       -width => 45,
                                       -wrap =>'word',
                                      )->pack(qw/-side bottom -fill x -expand 1/);
my $tlg_code_label = $bot_frame_tlg->LabEntry(
                          -label        => "ID Code: ",
                          -labelPack    => [-side => 'left', -anchor =>'w'],
                          -textvariable	=> \$author_id,
                          -borderwidth 	=> 2,
                          -relief 	    => 'sunken',
                          -foreground 	=> 'blue',
                          -width        => 5,
                          -state        => 'readonly'
                                )->pack(qw/-fill x -side left/);
my $works_no_label = $bot_frame_tlg->LabEntry(
                          -label        => 'Number of works by author: ',
                          -labelPack    => [-side => 'left', -anchor =>'w'],
                          -textvariable	=> \$number_of_works,
                          -borderwidth 	=> 2,
                          -relief 	    => 'sunken',
                          -foreground 	=> 'blue',
                          -width        => 4,
                          -state        => 'readonly'
                                )->pack(qw/-fill x -side right/);
my $time_label = $bot_frame->Entry(
                          -textvariable =>\$year,
                          -foreground => 'blue',
                          -width => '15',
                          -state => 'readonly',
                                )->pack(qw/-side right -expand 1 -fill x/);
my $geo_label = $bot_frame->Entry(
                          -textvariable =>\$geo,
                          -foreground => 'blue',
                          -width => '32',
                          -state => 'readonly',
                                )->pack(qw/-side left -expand 1 -fill x/);
&font_selector(\$mw);
&create_works_window;
&options_togle;
$works_window->withdraw;  #withdraw works window untill needed
$search_box->focus;
MainLoop;


###################################################
# Subroutines
###################################################
sub set_icon {
  my	$widget 	= ${shift @_};
  my $icon_file = shift @_;
  my $dir = 'icons/';
  unless ($ms_icon)
  {
    my $icon = $mw->Photo(-file => $dir . $icon_file . '.png', -format =>'PNG');
    $widget->iconimage( $icon );
    $widget->iconmask('@' . $dir . $icon_file . '-mask.xbm');
  }
  else
  {
    $widget->setIcon( -file => $dir . $icon_file . '.ico');
  }
}	# ----------  end of subroutine set_icon  ----------

sub corpus_locator
# Window to select the corpus directories
# called from "Corpus Directories" in the menubar
# buttons call sub get_dir
{
	unless(Exists($corpus_dir_win))
  {
	 $corpus_dir_win = $mw->Toplevel(-title =>'Directory Finder');
   $corpus_dir_win->protocol('WM_DELETE_WINDOW' => \&close_dirs_window);
    my $folder = $corpus_dir_win->Photo(
                              -file => './icons/winfolder.xpm',
                              -format => 'xpm'
                                   );
    my $fr = $corpus_dir_win->Frame( -borderwidth => 3, -relief => 'groove');
    my $l1 = $fr->Label(  -text => '        Corpus Directory Locator')->grid();
    my ($e1, $e2, $e3);
    my @labEns = (\$e1, \$e2, \$e3);
    my @labels = qw/TLG PHI-5 PHI-7/;
    my @corpus_dir_refs = (\$tlg_dir, \$phi5_dir, \$phi7_dir);
    ${$labEns[$_]} = $fr->LabEntry(
                                  -label => $labels[$_],
                                  -textvariable => $corpus_dir_refs[$_],
                                  -labelPack    => [qw/-side left -anchor e/],
                                  -borderwidth 	=> 2,
                                  -relief 	    => 'sunken',
                                  -width        => 30) for (0,1,2);
    my ($bt1, $bt2, $bt3);
    my @bts = (\$bt1, \$bt2, \$bt3);
    my @corps = qw/tlg civ ddp/;
    ${$bts[$_]} = $fr->Button(
                              -image => $folder,
                              -command => [ sub{ ${$_[0]}  = &get_dir(${$_[0]}, $_[1])},
                                              $corpus_dir_refs[$_], $corps[$_]
                                          ],
#                              -state => 'active',
                            ) for(0,1,2);
    Tk::grid($e1, $bt1);
    Tk::grid($e2, $bt2);
    Tk::grid($e3, $bt3);
    Tk::grid($fr, -sticky => 'ew');
    $fr->gridColumnconfigure(0,-weight=>1);
    $_->gridConfigure(-sticky => 'ew') foreach($e1,$e2,$e3);
    my $fr_bot = $corpus_dir_win->Frame( -borderwidth => 3,
                                     -relief => 'groove'
                                   )->grid( -sticky => 'ew');
    $fr_bot->Button( -text => 'OK',
                     -command => \&save_dirs
                        )->grid(-padx,3, -pady,5, -row,0, -column,0, -sticky,'w');
    $fr_bot->Button( -text => 'Cancel',
                     -command => \&close_dirs_window
                        )->grid(-padx,3, -pady,5, -row,0, -column,1, -sticky,'e');
    $fr_bot->gridColumnconfigure(0,-weight=>1);
    $corpus_dir_win->gridColumnconfigure(0,-weight=>1);
  }
	else{ $corpus_dir_win->deiconify(); }
} # --- end sub corpus_locator
#-----------------------------------------------------

sub check_dirs
# Checks  the validity of corpus directories
# called from main and everytime a directory
# chosen from sub get_dir
{
  my $found = 0;
  my $corps = $menubar->entrycget('Corpus', -menu);
  foreach (sort keys %dirs)
  {
    if (-e ${$dirs{$_}[0]} . $dirs{$_}[2] .'0001.idt')
    {
      $corps->entryconfigure($dirs{$_}[1], -state => 'normal');
      $corpus = $dirs{$_}[2] unless $corpus;
      $found++;
    }
    else
    {
      $corps->entryconfigure($dirs{$_}[1], -state => 'disabled');
    }
  }
 return $found;
} # --- end sub check_dirs.
#-----------------------------------------------------

sub get_dir
{
  # Opens the choosedirectory dialogue
  # returns the selected directory
  # called from &corpus_locator.
  # FIXME maybe merge with sub set books directory
  my ($dir, $corp) = @_;
  my $new_dir;
  my $test_file = $corp . '0001.idt';
  $new_dir = $mw->chooseDirectory
              (
                  -title => 'Find Directory',
                  -initialdir => $dir
              );
  return $dir unless $new_dir;
  $new_dir =~ s#/?$#/#;   # in case final / is missing
  &error_msg("Not a Valid Corpus Directory!") unless -e $new_dir . $test_file;
  return $new_dir;
}

sub close_dirs_window
{
  $corpus_dir_win->withdraw;
}

sub save_dirs
{

  $found_corpus =  &check_dirs;
  $corpus_dir_win->withdraw;
  #&save_rc;
  $corpus='' if $found_corpus == 0;
  &populate_author_list ;
}
#--------------------------------------------------

sub set_books_dir {
  my $initial_dir;
  ( defined $results_dir && -d $results_dir )
    ? ($initial_dir = $results_dir)
    :($initial_dir = '~/');
  my $dir = $mw->chooseDirectory
                       (
                         -title => 'Output Files Diectory',
                         -initialdir => $initial_dir
                       );
  return unless ($dir);
  ($results_dir = $dir) =~ s#/?$#/#;
  # &save_rc;
}

#-------------------------------
# the menubar configuration data
#-------------------------------
sub menu_items {
  [
    [Cascade=> '~Files', -menuitems =>
      [
        [Checkbutton => '~Display',-variable => \$view],
        [Separator => ''],
        [Radiobutton => '~Pdf', -value    => 'pdf',
                                -variable => \$output_file_type,
                                -command  => \&options_togle],
        [Checkbutton =>" Save TeX", -variable => \$tex],
        [Separator => ''],
        [Radiobutton => '~Unicode', -value =>   'unicode',
                                    -variable=> \$output_file_type,
                                    -command  => \&options_togle],
        [Separator => ''],
        [Command => '~Corpus Directories',-command => \&corpus_locator],
        [Command => '~Output Directory', -command => \&set_books_dir],
        [Command => '~Exit', -command => sub {&save_rc; exit}]
      ], -tearoff => 1
    ],
    [Cascade => '~Corpus',  -menuitems =>
      [
        [Radiobutton => 'Greek Texts   (~TLG)',   -value    => 'tlg',
                                                 -variable => \$corpus,
                                                 -command  => \&populate_author_list],
        [Radiobutton => 'Latin Texts   (~LAT)',   -value    => 'lat',
                                                 -variable => \$corpus,
                                                 -command  => \&populate_author_list],
        [Radiobutton => 'Bible Texts   (~CIV)',   -value    => 'civ',
                                                 -variable => \$corpus,
                                                 -command  => \&populate_author_list],
        [Radiobutton => 'Duke Papyri   (~DDP)',   -value    => 'ddp',
                                                 -variable => \$corpus,
                                                 -command  => \&populate_author_list],
        [Radiobutton => 'Classsical inscriptions (~INS)',  -value    => 'ins',
                                                 -variable => \$corpus,
                                                 -command  => \&populate_author_list],
        [Radiobutton => 'Christian  inscriptions (C~HR)',   -value    => 'chr',
                                                 -variable => \$corpus,
                                                 -command  => \&populate_author_list],
      ],
    ],
    [Cascade=>'~Options', -menuitems=>
      [
        [Checkbutton =>" Author Info", -variable => \$info],
        [Separator =>''],
        [Checkbutton =>" Marginalia", -variable => \$marginalia],
        [Checkbutton =>" Citations", -variable => \$cits],
        [Checkbutton =>" Paragraphs (\xa7)", -variable => \$par],
        [Checkbutton =>" Line Numbers", -variable => \$lines],
        [Checkbutton =>" Ligatures", -variable => \$ligatures],
        [Separator =>''],
        [Checkbutton => " Page Numbers",
                        -variable => \$page_nos_enable,
                        -command => \&toggle_page_nos],
        [Radiobutton =>" Arabic", -value => 'arabic', -variable=>\$page_nos],
        [Radiobutton =>" Roman",  -value => 'Roman',  -variable=>\$page_nos],
        [Radiobutton =>" Greek",  -value => 'alph' ,  -variable=>\$page_nos],
      ],
    ],
    [Command => 'Fo~nts', -command => [\&font_selector, \$mw]],
    [Cascade=> '~Help', -menuitems =>
      [
        [Command => '~About', -command => sub{ $mw->messageBox(
                                  -title => 'Proteus',
                                  -message => $version_msg,
                                  -icon => 'info',
                                  -type => 'OK')}]
      ], -tearoff => 0
    ]
  ];
} # --- end sub menu_items

sub populate_author_list {
  # Extract author list from the canon
  # and insert in authors window
  # %authors{"name + epithets + gen"} = txt_id_number
  unless ($corpus){
    $authors_list->delete(0, 'end');
    return;
  }
  undef %authors;
  %canon = %{thaw( $canons{$corpus})};
  foreach my $id (sort keys %canon)
  {
    my $genre;
    my $name =  decode_utf8($canon{$id}->{'nam'});
    if ($corpus =~ /tlg/){
      $name =~ s/[\(\)\[\]\?]//g;
      $name = lc $name;
      $name =~ s/\b(\w+)\b/ucfirst($1)/ge;
      $name =~ s/Et /et /g;
      $name .= ',';
      my $epithet =  $canon{$id}->{'epi'};
      if (defined $canon{$id}->{gen})
      {
        $genre = $canon{$id}->{gen} ;
        $genre =~ s/, $//;
        $genre = " $genre";
      } else { $genre = ''};
      $epithet = '' unless defined $epithet;
      $name .= "  " . decode_utf8($epithet);
      $name =~ s/et $//;
    }
    $genre = 'Lexicogr.' if $name =~/suda/i; # show suda with other lexica
    $name .= ' (2)' if exists  $authors{$name}; # protect duplicate names
    $name .= decode_utf8($genre) if defined $genre;
    my $syn =   decode_utf8($canon{$id}->{'syn'});
    if (defined $syn){
      $syn =~ s/[\(\)\[\]\?]//g;
      $name .= " ($syn)";
    }
    $authors{$name} = $id;
  }
  undef %author_selection;
  %author_selection = %authors;
  $authors_list->delete(0, 'end');
  $authors_list->insert('end', sort(keys %author_selection));
  &options_togle if Exists($works_window); # FIXME refine.
  $mw->title("Author List ($corpus)");
}
#--------------------------------------------------

sub toggle_page_nos {
  my @buts = (' Arabic', ' Roman', ' Greek');
  my $options = $menubar->entrycget('Options', -menu);
  unless ($page_nos_enable)
  {
    $options->entryconfigure($_, -state =>'disable') foreach @buts;
    $page_nos = 0;
  }
  else
  {
    $options->entryconfigure($_, -state =>'normal') foreach @buts;
    $page_nos = 'arabic';
  }
}	# ----------  end of subroutine toggle_page_nos  ----------

sub options_togle {
  #----------------------------------------
  # enable or dissable options checkbuttons
  #----------------------------------------
  my $state;
  ($output_file_type =~ /pdf/) ? ($state = 'normal')
                               : ($state = 'disabled');
  my @buts = (' Ligatures', ' Page Numbers',
              ' Arabic',' Roman', ' Greek');
  my $options = $menubar->entrycget('Options', -menu);
  $options->entryconfigure($_, -state =>$state) foreach @buts;
  my $files = $menubar->entrycget('Files', -menu);
  $files->entryconfigure(' Save TeX', -state => $state);
  $menubar->entryconfigure('Fonts', -state => $state);
  ($state =~ /normal/) ? ($lbot->pack(-side => 'right'))
                               : ($lbot->packForget);
  if ($max_margin) {
    $options->entryconfigure(' Marginalia', -state =>'normal')
  } else{
    $options->entryconfigure(' Marginalia', -state =>'disabled');
    $marginalia = 0;
  }
  if ($bold)  #   change the state of the bold fonts list
  {
    $font_props{Bold}->{FontList}->configure(-state => 'normal');
  }else{
    $font_props{Bold}->{FontList}->configure(-state => 'disabled');
  }
  unless ($output_file_type =~ /pdf/)
  {
    $font_selector->withdraw;
    $tw->withdraw if Exists($tw);
  }
}

#--------------------------------------------------
sub create_works_window {
  #---------------------------------
  #  The works of each author Window
  #---------------------------------
	unless(Exists($works_window)){
		$works_window = $mw->Toplevel();
    &set_icon(\$works_window, 'column');
		$works_window->title("Work List");
    #-----------------------
    # works list
    #-----------------------
		$works_list = $works_window->Scrolled(
                  qw/Listbox
                    -background ivory1
                    -selectmode single
                    -scrollbars osoe
                    -height 25
                    -width 50
                    /)->pack(qw/-expand 1 -fill both/);
    $works_list->configure(-font=> $list_font);
    $works_list->Subwidget("yscrollbar")->configure(-troughcolor=>'skyblue3');
    $works_list->Subwidget("xscrollbar")->configure(-troughcolor=>'skyblue3');
		$works_window->bind("<KeyPress>", [\&arrow, Ev("K"), 'works' ]);
    $works_window->bind('<Double-1>' => [\&arrow, Tk::Ev("b"), 'works']);
		$works_list->bind(
            '<ButtonRelease-1>' => [\&arrow, 'mouse', 'works']);
    #-----------------------
    # bottom labels
    #-----------------------
    my $bot_frame2 = $works_window->Frame->pack(qw/-side bottom -fill x/);
    my $bot_frame = $works_window->Frame->pack(qw/-side bottom -fill x/);
    $ed_box =   $bot_frame->ROText(
                                       -font   => '{Arial} 10',
                                       -height => 2,
                                       -width => 40,
                                       -wrap =>'none',
                                        )->pack(qw/-side top -fill x -expand 1/);
    my $class_label = $bot_frame->LabEntry(
                    -label        => 'Class: ',
                    -labelPack    => [qw/-side left -anchor w/],
                    -textvariable	=> \$cla,
                    -borderwidth 	=> 2,
                    -relief 	    => 'sunken',
                    -foreground 	=> 'blue',
                    -width        => 15,
                    -state        => 'readonly'
                          )->pack(qw/-fill x -side left -expand 1/);
    my $cit = $bot_frame->LabEntry(
                    -label        => 'Sections: ',
                    -labelPack    => [qw/-side left -anchor w/],
                    -textvariable	=> \$page_data,
                    -borderwidth 	=> 2,
                    -relief 	    => 'sunken',
                    -foreground 	=> 'blue',
                    -width        => 15,
                    -state        => 'readonly'
                          )->pack(qw/-fill x -side left -expand 1/);
    my $line_cnt = $bot_frame2->LabEntry(
                    -label        => 'Line count: ',
                    -labelPack    => [-side => 'left', -anchor =>'w'],
                    -textvariable => \$lines_count,
                    -foreground   => 'blue',
                    -width        => 8,
                          )->pack(qw/-fill x -side left/);
    my $wc_label = $bot_frame2->LabEntry(
                    -label        => 'Word count: ',
                    -labelPack    => [qw/-side left -anchor w/],
                    -textvariable	=> \$wc,
                    -borderwidth 	=> 2,
                    -relief 	    => 'sunken',
                    -foreground 	=> 'blue',
                    -width        => 8,
                    -state        => 'readonly'
                          )->pack(qw/-fill x -side left/);
        $lbot=$bot_frame2->LabEntry(
                    -label        => 'Font: ',
                    -labelPack    => [-side => 'left', -anchor =>'w'],
                    -textvariable => \$active_font,
                    -foreground   => 'blue',
                    -width        => 20,
                          );
  $lbot->pack(-side => 'top') if $output_file_type =~/pdf/;
	}else{ $works_window->deiconify(); }
}

#--------------------------------------------------
sub works_display {
  #--------------------------------
  # insert list of works
  #--------------------------------
  my %works;
	my $i= $authors_list->index('active');
	$author_id = $authors{$authors_list->get('active')};
  #-------------------------------------------------
  # Get Works and level data from %canon
  # %works{work_id} = work_title
  #-------------------------------------------------
  foreach my $wrk_id (sort keys %{$canon{$author_id}->{books}})
  {
    my $wrk = $canon{$author_id}->{books}->{$wrk_id}->{wrk};
    $wrk =~ s/[=\?]//g;  # remove '=' from work title
    #$wrk_id = sprintf("%03d", $wrk_id);
    $works{$wrk_id} = decode_utf8($wrk);
  }
	&create_works_window;
	$works_list->delete(0,'end');
	$works_window->configure(-title => $authors_list->get('active'));
  my $number;
  unless ($corpus =~ /tlg|lat/){
    foreach $number (sort keys %works) {
     	$works_list->insert('end', "$number:  " . $works{$number});
    }
  } else {
    foreach $number (sort {$works{$a} cmp $works{$b}} keys %works) {
      $works_list->insert('end', "$number:  " . $works{$number});
    }
  }
  &move_cursor($works_list, 0);
  $works_list->selectionSet(0);
  $works_list->activate(0);
  $mw->focus;
}
#--------------------------------------------------

sub do_search {
	my ($entry, $key) = @_; # $entry is the searchbox
    undef %author_selection;
    foreach (keys %authors){
        $author_selection{$_} = $authors{$_} if $_ =~ m{$search}i;
    }
    %author_selection = %authors unless $search;
    $authors_list->delete(0, 'end');
    $authors_list->insert('end', sort(keys %author_selection));
    $i = 0 if $i > $authors_list->size;
    $authors_list->see($i);
    $authors_list->selectionClear(0, "end");
    $authors_list->selectionSet($i);
    $authors_list->activate($i);
}
#--------------------------------------------------------------------------
sub arrow {
  #-------------------------------
  # change selection in authors
  # or works list
  # also fill bottom labels
  # in both windows
  #-------------------------------
	my ($entry, $key, $a_or_w) = @_;
  my ($list, $idx);
  ($a_or_w eq 'authors') ? ($idx = $i) : ($idx = $j);
  ($a_or_w eq 'authors') ? ($list = $authors_list) :($list = $works_list);
  my $regex = qr/(down)|(up)|(next)|(prior)|(mouse)/i;
  #-----------------------------------------
  # Enter calls the conversion subroutine
  #-----------------------------------------
	if (($key=~ /return|KP_Enter|1/i)
                 &&
        ($a_or_w =~/works/) )
      {
        &convert($author_id, $book_id);
        return
      };
  #-----------------------------------------
  # selection move
  #-----------------------------------------
	return unless $key =~ $regex;
    $idx = $list->index('active') if $key =~/mouse/;
	if ( ($key=~ /Down/i) && ($idx < ($list->size() - 1)))
         { $idx++; &move_cursor($list,$idx);}
	if (($key=~ /up/i) && ($idx > 0))
         {$idx--; &move_cursor($list,$idx);}
	if ($key=~ /next/i) {
		if ($idx+ 20 < $list->size() - 1){
            $idx+=20; &move_cursor($list,$idx);
    }else{
            $idx = ($list->size() - 1);
            &move_cursor($list,$idx);
     }
  }
	if ($key=~ /prior/i) {
		if($idx-20 > 0) {$idx-=20; &move_cursor($list,$idx);}
			else{$idx = 0;&move_cursor($list,$idx);}
  }
  #-----------------------------------------
  # Update Works Display to show
  # the works  of the author
  #-----------------------------------------
  ($a_or_w eq 'authors') ? ($i = $idx) : ($j = $idx);
  &works_display if $a_or_w eq 'authors';
  $works_list->get('active')=~/^(0*\d+)/;
  # $book_id will go to the conversion routine
  $book_id = $1;
  &fill_bottom_labels($author_id, $book_id);
} # --- end sub &arrow
#------------------------------------------------------------------
sub move_cursor {
    my ($list, $index) = @_;
		$list->selectionClear(0, "end");
		$list->see($index);
		$list->selectionSet($index);
		$list->activate($index);
}
#------------------------------------------------------------------
sub fill_bottom_labels {
  #----------------------------------------------
  # Update Bottom Labels with data
  # fetched from %canon
  # need $author_id (tlg id) and $book_id
  #----------------------------------------------
  my ($author_id, $book_id) = @_;
  #--------------------
  # first the author window
  #--------------------
  $year = $canon{$author_id}->{dat};
  $year = 'N/A' unless defined $year;
  $geo = $canon{$author_id}->{geo};
  $geo = 'N/A' unless defined  $canon{$author_id}->{geo};
  $geo =~ s/, $//g ;
  $see_also = $canon{$author_id}->{vid};
  if (defined $see_also)                        # multiline
  {
      $see_also =~ s/Scholia.*Cf/Cf/g;          # Removes some unprintable chars
      $see_also = lc $see_also;                 # capitalize 1st letter only
      $see_also =~ s/\b(\w\w\w+)\b/ucfirst($1)/ge;
      $see_also =~ s/(\(\d+\),) /$1\n/g ;
      my @lines = split(/\n/, $see_also);       # count lines
      $see_also_txt->configure(-height => scalar(@lines));
      $see_also_txt->delete('0.0', 'end');
      $see_also_txt->insert('end',$see_also);
  }else{
    $see_also_txt->delete('0.0', 'end');
    $see_also_txt->configure(-height => 1);
    $see_also_txt->insert('end', 'N/A');
  }
  $number_of_works = scalar(keys %{$canon{$author_id}->{books}});
  #-----------------------
  # Then the works window
  #-----------------------
  $max_text = $canon{$author_id}->{books}->{$book_id}->{text};
  $max_margin = $canon{$author_id}->{books}->{$book_id}->{margin};
  $lines_count = $canon{$author_id}->{books}->{$book_id}->{lines};
  $lines_count =~ s/(\d{1,3}?)(?=(\d{3})+$)/$1,/g;             # thousands separator
  $page_data = $canon{$author_id}->{books}->{$book_id}->{cit};
  $page_data =~ s#/line##i;
  # $page_data =~ s#/#:#g;     # repace / with :
  $wc =  $canon{$author_id}->{books}->{$book_id}->{wct};
  $wc = 'N/A' unless defined $wc;
  $cla = $canon{$author_id}->{books}->{$book_id}->{cla};
  $cla = 'N/A' unless defined $cla;
  #-----------------------
  # printed edition data
  #-----------------------
  $ed1 = decode_utf8($canon{$author_id}->{books}->{$book_id}->{ed1});
  my $ed2 = decode_utf8($canon{$author_id}->{books}->{$book_id}->{ed2});
  ($ed1 eq '') ? ($ed1 = $ed2) : ($ed1 .= "\n$ed2");
  $ed_box->delete('0.0', 'end');
  $ed_box->insert('end',$ed1);
  #-----------------------
  &options_togle;
} # --- end sub fill_bottom_labels
#------------------------------------------------------------------
sub convert
{
  #----------------------
  # convert book to utf
  # if file_type is pdf
  # include tex controls
  #----------------------
  my ($author_id, $book_id) = @_;
  #--------------------------
  # Error checks first
  #--------------------------
  my $dir = $results_dir;
  unless (-d $dir)                # check output-dir exists
  {
    &error_msg('Output Directory Does Not Exist!') ;
    &set_books_dir;
    return;
  }
  if ($output_file_type eq "pdf"){              # for pdf only
    my %errors = %{ &font_error_check};         # check fonts
    foreach my $font (@fonts)    # warn of invalid fonts.
    {
      my $source;
      ($print_font{$font}->[0] == 1) ? ($source = 'system')
                                     : ($source = 'external');
      if ($errors{"$font"."_"."$source"})
      {
        &error_msg("Missing/Invalid Font:  $font ($source)\n Select a valid font!");
        &font_selector(\$mw);
        return;
      }
    }
  }
  #-------------------------------------------
  # form the txt filename as found in the cdrom
  my $tlg_file = $corpus . $author_id . '.txt';
  #
  # FIXME upper case filenames.  (may be never)
  # $tlg_file = uc $tlg_file if $author_tab_file =~ /DIR/; # uc filnames
  #
  #-------------------------------------------
  my ($base, $file_stub, $tex_file, $pdf_file );
  #-------------------------------------------
  # extract the three digits in $book.
  # (%03d will print $book = 2 as: "002")
  # these are stored in $1, $2, $3
  # and form various output filenames.
  #-------------------------------------------
  ($base = $tlg_file) =~ s/\.txt$//i;                 # Remove ".txt" postfix
  sprintf ("%03d", $book_id)  =~ /(\d|\s)(\d|\s)(\d)$/; # ger the book digits
  my $out_file_stub = $base . "_".$1.$2.$3;
  $tex_file = $home . "/$out_file_stub" .".tex";      # temp tex file,  input to xelatex.
  $pdf_file = $home . "/$out_file_stub" .".pdf";      # temp pdf file, ouput from xelatex
  # Save file dialogue, returns output filename and path
  # outfile is .pdf or .utf
  my $outfile = &dlg_save_file($out_file_stub, $results_dir);
  return unless $outfile; # abort if cancel is pressed
	#-----------------------------------
	# 	Start conversion ...
	#-----------------------------------
  #---------------------------
  # Minimize while converting
  # and show "wait .. message"
  # (MS Windows only)
  #---------------------------
  unless ($OS =~ /linux/)
  {
    $tw->withdraw if Exists $tw;
    $font_selector->withdraw if Exists $font_selector;
    $mw->iconify;
    $works_window->iconify;
    $wait= &wait_msg;
  }
############################################################################
#  call  C utility tlg2u
############################################################################
  my $start_block = $canon{$author_id}->{books}->{$book_id}->{blk};
  my $text_width = $canon{$author_id}->{books}->{$book_id}->{text};
  my $margin_width = $canon{$author_id}->{books}->{$book_id}->{margin};
  my $lang =         uc $canon{$author_id}->{books}->{$book_id}->{lang};
  #----------------------------------
  # form the tlg2u parameters string
  #----------------------------------
  my $params = ' ';
  $params .= '-m ' if $marginalia;
  $params .= '-C ' if $cits;      # cits and par are exclusive
  $params .= '-P ' if $par;
  $params .= '-l ' if $lines;
  $params .= "-$lang " if $lang =~ /L/i; # greek or latin, FIXME hebrew, coptic?
  $params .= "-d ${$dirs{$corpus}->[0]} ";
  $params .= "-c $corpus ";
  $params .= "-a $author_id ";
  $params .= "-b $book_id ";
  $params .= "-B $start_block ";
  $params .= "-T $text_width -M $margin_width " if $output_file_type eq "unicode";
  # print "$params\n";return;  # Debug parameters
	#-----------------------------------
	# 	UNICODE
	#-----------------------------------
  if ($output_file_type eq "unicode"){
    #    die warn "./tlg2u -u $params ******** $lang";
    my $book = `$tlg2u -u $params > "$outfile"`;
    # print "$!, $?\n";
    # $book = decode_utf8($book);
      if ($info)
      {
        # Append author and book info at the end, if required.
        open OUT, ">>$outfile";
        binmode OUT, ':utf8';
        # print OUT $book;
        my $head_info = &get_author_and_book_info;
        print OUT "---------------------------------------------------------------------\n";
        print OUT "$head_info\n";
        print OUT "---------------------------------------------------------------------\n";
        close OUT;
      }
      if ($view)
      {
        if ($^O =~ /linux/)
          { # FIXME No need to look for libreoffice writer. Use file assocs
            my $where = `which libreoffice 2>&1`;
            unless ($where =~ /which/)
            {
              system "libreoffice --writer $outfile &";
              # system "xdg-open $outfile" ;
              # system "/usr/bin/gvim $outfile &" ;
              # print ("Opening OpenOffice Writer... \n");
            }else{ &error_msg("Can't find LibreOffice!") };
          }
          else      # Windows
          {
            $outfile =~ s#/#\\#g; # change / to \
            # can also use "start"  but "cmd /c" is better
            #system qq(cmd /c "$outfile");
            system qq(start "" "$outfile");
          }
        }
    }
	#-----------------------------------
	# 	PDF
	#-----------------------------------
  if ($output_file_type eq "pdf")
  {
    # Determine text width and left margin width
    # FIXME Rationalize this.
    my $text_width =
          ($canon{$author_id}->{books}->{$book_id}->{text} / 5.5);
    $text_width = 14.5 if $text_width > 14.5;
    $text_width .= 'cm';
    my $margin_width = ( $max_margin /  10) .'cm';

    # Prepare Xetex preample and tail.
    my ($tex_header, $tex_tail) = &latex_head_foot($text_width, $margin_width);

    # Print header to file.
    open OUT, ">$tex_file";
    binmode OUT, ':utf8';
    print OUT $tex_header;
    close OUT;

    # Convert main text and send to file.
    # my $book = `./tlg2u -p -t $params -a $aut_id -b $bk_id -d $tlg_dir`;
    # my $book = `$tlg2u -p  $params`;
    if (system(qq{$tlg2u -p  $params >> "$tex_file"}))
    {
        &error_msg("tlg2u conversion failed!");
        &win_restore unless ($OS =~ /linux/);
        return;
    }
    open OUT, ">> $tex_file";
    binmode OUT, ':utf8';
    print OUT $tex_tail;
    close OUT;
    # Abort if there is no tex file for some reason
    unless ( -e $tex_file)
    {
      &error_msg("Aborted.\nNo TeX file!");
      &win_restore unless ($OS =~ /linux/);
      return;
    }
    #-----------------------------------
    # convert to pdf, surpress error messages
    if ($^O =~ /linux/)
    {
      system "xelatex -interaction=nonstopmode -output-directory=$home $tex_file &> /dev/null";
      sleep 2;    #  For some computers need to wait else pdf is not detected.
    }
    else      # Windows
    {
        my $win_cmd = q#START /B /HIGH /WAIT xelatex.exe -interaction=nonstopmode #;
        my $prot_dir = '-output-directory "C:\Program Files\proteus" ';
        system qq/$win_cmd $prot_dir "$tex_file"/;
        # system qq/xelatex.exe -interaction=nonstopmode  "$tex_file" > nul/;
    }
    unless ( -e $pdf_file)
    #Abort if there is no pdf file for some reason
    {
      &error_msg("Aborted.\nNo pdf file!");
      &win_restore unless ($OS =~ /linux/);
      return;
    }
    unless($pdf_file eq $outfile) # in case output dir is $home
    {
      move($pdf_file, $outfile) or die warn "No pdf file: $!";
      unlink $pdf_file;
      copy($tex_file, "$results_dir/") if $tex; # keep tex
      unlink $tex_file;
    }
    #-----------------------------------
    # Display pdf file if $view =1
    #-----------------------------------
    if ($view){
      unless( -e $outfile)
      {
        &error_msg("$outfile not created!\n
                    Possible Tex file error.");
        return;
      }
      if ($OS =~ /linux/)
      {
        system qq/xdg-open $outfile/;
      }
      else  # if windows
      {
        $outfile =~ s#/#\\#g;
        # system qq(cmd /c "$outfile");
        system qq(start "" "$outfile");
      }
    }	# -- end if view
    # comment out cleanup for debugging
    my $hm = $home;
    # escape spaces in path.
    # e.g. in Windows "Program Files"
    $hm =~ s/ /\\ /g;
    unlink glob("$hm/*.log"), glob("$hm/*.aux");
  } # --end if pdf
  &win_restore unless ($OS =~ /linux/);
} # -- end sub convert
sub win_restore
{
  #---------------------------
  # Restore panels
  # Windows only
  #---------------------------
  $wait->destroy if Exists $wait;
  $mw->deiconify;
  $mw->raise;
  $works_window->deiconify;
  $works_window->raise;
}
sub get_author_and_book_info
{
  #--------------------------------------------------------
  # Collect Author and book details from the canon
  # To be printed at the top of the pdf file
  # or at the end of the utf file
  # if required.
  #--------------------------------------------------------
  my $auth =  $authors_list->get('active') ;
  my $author_info = "\\textbf{Author:} " . $auth . "  (\\textbf{File id:} $author_id) \\\\\n";
  $author_info .= "\\textbf{Geo:} $geo"  . ".  \\textbf{Century:} $year\\\\\n";
  my $title = $works_list->get('active');
  $title =~ /(\d\d\d):(.*)/;
  my $book_info =  "\\textbf{Title:} " . $2 . ".  \\textbf{Genre:}  $cla" . " (\\textbf{id:} $1) \\\\\n";
  my $editor_info = $ed1;
  $editor_info =~ s/\n/\\\\\n/;
  $editor_info =  "\\textbf{Original text source:}" . "  $editor_info\\\\\n";
  my $info = $author_info . $book_info . $editor_info;
  # info string for utf output
  # remove tex formating.
  my $info_utf = $info;
  $info_utf =~ s/\\textbf\{(.+?:)\}/$1/g;
  $info_utf =~ s/\\\\//g;
  if ($output_file_type eq 'pdf')
  {
    return $info;
  }
  else
  {
    return $info_utf;
  }
  #---------------------------------------------------------

} # -- end sub get_author_and_book_info

sub dlg_save_file {
  # returns full path of output file pdf or utf
  my $stub = shift @_;
  my $dir = shift @_;
  my $ext;
  ($output_file_type eq 'pdf') ? ($ext = 'pdf'): ($ext = 'utf');
  my $type = $output_file_type . ' Files  ';
  my @filetypes = ([$type, ".$ext"], ['All Files  ', '*']);
  my $outfile = $mw->getSaveFile(
          -defaultextension => $ext, # it does not work on linux
          -filetypes => \@filetypes,
          -initialdir => $dir,
          -initialfile => $stub . ".$ext",
  );
  return $outfile;
}	# ----------  end of subroutine dlg_save_file  ----------

sub error_msg {
  #-------------
  # message box
  #-------------
  my	( $msg )	= @_;
  my $box = $mw->messageBox(
                        -title => "Warning Notice",
                        -message => "$msg",
                        -type =>'OK',
                        -icon => 'error',
                      );
  return ;
}	# ----------  end of subroutine error_msg  ----------
sub wait_msg
{
            my $wait=$mw->Toplevel(-title => 'Wait ...');
            $wait->raise;
            $wait->iconify;
            return $wait;
}
##################################################################################
sub defaults {
  #--------------------------------
  # Read rc file or
  # Set default values
  #--------------------------------
  $view =1,
  $tex = $cits = $par = $lines = $page_nos = $ligatures = $marginalia = 0;
  $pt_size = 16;
  $tlg_dir =    $home . '/CDROMS/tlg/';
  $phi5_dir =   $home . '/CDROMS/phi5/';
  $phi7_dir =   $home . '/CDROMS/phi7';
  $results_dir = $home . '/books/';
  #--------------------------
  %print_font = (
    Greek => [1, 'Times New Roman', 'select'],
    Latin => [1, 'Times New Roman', 'select'],
    Symbol=> [1, 'Times New Roman', 'select'],
  );
  $output_file_type = 'pdf';
  $external_font_dir = $home . '/fonts/';
  $bold = 0;
  #--------------------------
  undef %dirs;
  if (-e $rc_file)
  {
    eval(read_file($rc_file));  # read home defaults
  }
  elsif (-e $cwd . '/proteusrc')
  {
    eval(read_file($cwd . '/proteusrc')); # else from application dir
  }
  %dirs = (
            'tlg' =>    [\$tlg_dir ,1,  'tlg'],
            'lat' =>    [\$phi5_dir, 2, 'civ'],
            'civ' =>    [\$phi5_dir, 3, 'civ'],
            'ddp' =>    [\$phi7_dir, 4, 'ddp'],
            'ins' =>    [\$phi7_dir, 5, 'ddp'],
            'chr' =>    [\$phi7_dir, 6, 'ddp']
          );
  $active_font = $print_font{Greek}->[$print_font{Greek}->[0]];
}	# ----------  end of subroutine defaults  ----------

sub save_rc {
  write_file
    (
      $rc_file, Data::Dumper->Dump
      (
        [
          $tlg_dir, $phi5_dir, $phi7_dir,
          \%print_font,
          $corpus,
          $results_dir, $external_font_dir,
          $pt_size,  $bold,
          $output_file_type
        ],
        [
          'tlg_dir', 'phi5_dir', 'phi7_dir',
          "*print_font",
          'corpus',
          'results_dir', 'external_font_dir',
          'pt_size', 'bold',
          'output_file_type'
        ]
      )
    );
} # ----------- end sub save_rc ------------------------
###################################################################
# Generate xetex preample and closing
###################################################################
sub latex_head_foot($)
{
  # my $book =  ${shift @_};
  my ($text_width, $margin_width) = @_;
  my $head_info = &get_author_and_book_info;
  my $greek_font  = $print_font{Greek}->[$print_font{Greek}->[0]];
  my $latin_font  = $print_font{Latin}->[$print_font{Latin}->[0]];
  my $symbol_font = $print_font{Symbol}->[$print_font{Symbol}->[0]];
  # if external need the filename only.
  my $bold_font = $print_font{Bold}->[$print_font{Greek}->[0]];
  # if system font add "Bold" to the font name (if not already there)
  if ($print_font{Greek}->[0] == 1)
  {
    $bold_font =~ s/Rg// if $OS =~/MS/; # ms reports crap font names
    $bold_font = "$bold_font Bold" unless $bold_font =~/bold/i;
  }

  #---------------------------------------------------------
  #  Xetex preample and tail
  #---------------------------------------------------------
  my %h;
  $h{header} = qq/%!TEX TS-program = xelatex
  \\documentclass[a4paper,12pt]{article}
  \\usepackage[text={18cm, 25cm}, centering]{geometry}
  \\usepackage[no-math]{fontspec}
  \\usepackage{xltxtra}
  \\usepackage{longtable}
  \\setcounter{LTchunksize}{100}
  \\usepackage[ancientgreek]{xgreek}\n/;
  #---------------
  # font controls
  #---------------

  $h{pre_main} = qq/\\setmainfont[\n/;
  $h{post_main} = qq/]{$greek_font}\n/;
  $h{pre_Greek} =   qq/\\newfontfamily\\greek[\n/;
  $h{bold} = qq/BoldFont=$bold_font,
                ItalicFont=*,
                BoldItalicFont=*,
                Scale=MatchLowercase,\n/;
  $h{post_Greek} = qq/]{$greek_font}\n/;
  $h{pre_Latin} =   qq/\\newfontfamily\\latin[Scale=MatchLowercase,\n/;
  $h{post_Latin} = qq/]{$latin_font}\n/;
  $h{pre_Symbol} =  qq/\\newfontfamily\\Symbol[Scale=MatchLowercase,\n/;
  $h{post_Symbol} = qq/]{$symbol_font}\n/;
  $h{external} = qq/ExternalLocation=$external_font_dir,\n/;
  $h{ligatures} = qq/Ligatures={Historical,Contextual}, Script=Greek\n/;
  #------------------------------------------------------------------
  # Read escape code interchartoks character
  # definions from file escape_codes.tex.
  #------------------------------------------------------------------
  $h{xinterchars} = "\\input{./escape_codes}\n"
                  unless $symbol_font eq $greek_font;
  #------------------------------------------------------------------
  $h{page_numbers} = qq/\\pagenumbering{$page_nos}\n/;
  $h{begin} = qq/
\\begin{document}
\\newcommand{\\Hrule}{\\rule{\\linewidth}{0.2mm}}
/;

  $h{info} = qq/
  \\latin
  \\begin{verse}
  {\\scriptsize $head_info }
  \\end{verse}
  \\Hrule\n/;
  # ifuse xtab need this to prevent bad page breaks
  # \\xentrystretch{0}
  $h{table} = qq/
  \\greek
  \\begin{center}
  \\begin{longtable}{p{1cm}p{$text_width}p{0.8cm}p{$margin_width}}\n
  & & & \\\\ /;

  my $tex_tail = q/
  & & & \\
  \end{longtable}
  \end{center}
  \Hrule
  \vspace{2mm}
  \footnotesize Ἐν Ἀθήναις τῇ \grtoday.\hspace{7cm}
  \copyright Πρωτεύς~~~(proteuss@sdf.org).
  \end{document}
  /;
  my $tex_header = $h{header};
    $tex_header .= $h{"pre_main"};
    $tex_header .= $h{external} if $print_font{Greek}->[0] == 2;
    $tex_header .= $h{ligatures} if $ligatures;
    $tex_header .= $h{"post_main"};
  foreach (qw/Greek Latin Symbol/)
  {
    $tex_header .= $h{"pre_$_"};
    $tex_header .= $h{external} if $print_font{$_}->[0] == 2;
    $tex_header .= $h{bold} if  $bold && ($_ eq 'Greek');
    $tex_header .= $h{ligatures} if $ligatures;
    $tex_header .= $h{"post_$_"};
  }
  $tex_header .= $h{xinterchars}
                  unless $symbol_font eq $greek_font;
  $tex_header .= $h{page_numbers} if $page_nos;
  $tex_header .= '\pagestyle{empty}' unless $page_nos;
  $tex_header .= $h{begin};
  $tex_header .= $h{info} if $info;
  $tex_header .= $h{table};
  return ($tex_header, $tex_tail);
  # $book = $tex_header . $book . $tex_tail;
  # return \$book ;
}	# ----------  end of subroutine latex_head_foot  ----------

# eval(read_file('latex-head-foot.pl'));
###########################################################################
#-------------------------------------------------------------------
# Font selector subroutines
#-------------------------------------------------------------------
###########################################################################

sub font_selector {
  #-----------------------------------------------------------------
  # Controls the fonts hash of arrays
  # %print_fonts{'font'} = [ 1 or 2, system_font, external_font ]
  # 'font' is Greek, Latin, Symbol, Bold
  # 1, 2 means system or external is set
  #-----------------------------------------------------------------
  # Called from:
  # main window when $mw is first created
  # Fonts menu button
  # when conversion is started (on a font error)
  #--------------------------------------------------------------
  my $mw = ${shift @_};
  #------------------
  #read sample texts
  #------------------
  eval(read_file('sample.dat'));
  #------------------
	unless(Exists($font_selector))
  {
		$font_selector = $mw->Toplevel(-title =>'Font Selector');
    $font_selector->protocol('WM_DELETE_WINDOW' => \&close_fonts);
    &set_icon( \$font_selector, 'fonts');
    #---------------------------------------------------
    #             frames
    #---------------------------------------------------
    #------------------------------------------------
    # tw is a separate window -- the text samples
    #------------------------------------------------
    $tw = $font_selector->Toplevel(-title => 'Text Samples');
    &set_icon( \$tw, 'fonts');
    $tw->protocol('WM_DELETE_WINDOW' => sub{$tw->withdraw;});
    #-----------------------------
    # The text samples text box
    # belongs to $tw
    #-----------------------------
    $sample_text = $tw->ROText(
                                -wrap  => 'none', #'word',
                                -font  => "{Arial} 12 bold",
                                -foreground => 'blue'
                              )->pack(-fill => 'both', -expand => 1);
    $tw->withdraw;   # hide preview window
    #------------------------------------------------
    my $f_left = $font_selector->Frame( -borderwidth => 3, -relief => 'groove',);
    my $l2 = $f_left->Label(-text => 'Font Selectors            ');
    my $l3 = $f_left->Label(-text => 'System ');
    my $l4 = $f_left->Label(-text => 'External ');
    Tk::grid('x',$l2,$l3,$l4);
    #------------------------------------------------
    my $f_right = $font_selector->Frame(-borderwidth => 3);
    Tk::grid($f_left,$f_right);
    #--------------------------------------------------
    #
    #    create the Font selectors in the left frame.
    #    One for each of Greek Latin Symbol (and Bold).
    #
    #--------------------------------------------------
    my $row =1;
    foreach (@fonts)   # fonts = qw/Greek Latin Symbol Bold/;
    {
      # The list label, Greek, Latin,  etc...
      my $label = sprintf "%6s: ",$_;
      $f_left->Label(
                     -text => $label,
                     -width => 7,
                     -relief => 'flat'
                    )->grid(-row => $row, -column => 0, -sticky => 'ew');

      # The List box for the fonts
      $font_props{$_}->{FontList} = $f_left->BrowseEntry(
                            -width     => 20,
                            -variable  => $print_font{$_}->[$print_font{$_}->[0]],
                            -browsecmd => [\&update_font_list, $_ ]
#                            -listcmd => [\&update_font_list, $_, $print_font{$_}->[0]]
                                  )->grid(-row =>$row, -column =>1, -sticky => 'ew');

      unless ($_ eq 'Bold')     # No radio buttons for Bold
      {
        # System Radio Button
        $font_props{$_}->{rb_syst} = $f_left->Radiobutton(
                                  -value => 1,
                                  -variable => \$print_font{$_}->[0],
                                  -command => [\&update_font_list, $_],
                                  )->grid(-row =>$row, -column =>2);

        # External Radio Button
        $font_props{$_}->{rb_ext} = $f_left->Radiobutton(
                                  -value => 2,
                                  -variable => \$print_font{$_}->[0],
                                  -command => [\&update_font_list, $_],
                                  )->grid(-row =>$row, -column =>3);
      }

      #------------------------------------
      # Sample Text window
      # print sample text.
      # Create tag, format to  the
      # appropriate font.
      #------------------------------------
      $sample_text->insert('end', "$_:\n");
      $sample_text->tagConfigure($_, -font => "{$print_font{$_}->[1]} $pt_size",
                                     -foreground => 'black');
      $sample_text->insert('end', "$sample{$_}\n\n", $_);

      $row++;                         # row variable. Used for packing
    }
    $f_left->Checkbutton( -variable => \$bold,
                                     -command => sub{
                                          &options_togle;
                                          &get_fonts;}
                                   )->grid(-row => 4, -column => 2,-columnspan => 2 );

    #------------------------------------
    # Greek and Bold font must be selected from the
    # same source (system or external) because of
    # fontspec
    # Bold external or system same as greek
    #------------------------------------
    $font_props{Bold}->{FontList}->configure(
                          -variable  => \$print_font{Bold}->[$print_font{Greek}->[0]],
                        ) ;
    #---------------------------------------------------------------
    #
    #    The right frame
    #    preview size selector, font dir finder, ok button
    #
    #---------------------------------------------------------------
    #
    my @pt_sizes = qw/6 8 10 12 14 16 20 24 28 32 48/;
		$size_selector = $f_right->BrowseEntry(
                                    -width=>  2,
                                    -label => 'Preview point size:   ',
                                    -listwidth =>22,
                                    -choices => \@pt_sizes,
                                    -variable=>  \$pt_size,
                                    -validate=> 'key',
                                    -state => 'readonly',
                                    -browsecmd => \&update_font_preview
                )->grid(qw/-row 1 -column 0 -columnspan 2 -pady 5/);

    #-----------------------
    # The font dir finder
    #-----------------------
    # The picture for the button
    my $folder_icon = $font_selector->Photo(
                                            -file => './icons/winfolder.xpm',
                                            -format => 'xpm'
                                           );
    # its label to the left
    my $lb = $f_right->Label( -text => 'Browse Fonts Dir:'
                            )->grid(qw/-row 0 -column 0 -sticky w -pady 5/);
    # The browse fonts dir button
    my $bt1 = $f_right->Button(
                          -image => $folder_icon,
                          -command => \&get_external_fonts_dir,
                          -state => 'active',
                        )->grid(qw/-row 0 -column 1 -sticky e/);
    #-----------------------
    # The preview button
    #-----------------------
    $f_right->Button(     -text => 'Preview',
                          -command => sub{ $tw->deiconify if (Exists $tw);}
                    )->grid(qw/-row 2 -column 0 -sticky w -pady 5/);

    #-----------------------
    # The OK button
    #-----------------------
    $f_right->Button(     -text => 'OK',
                          -command => \&close_fonts,
                    )->grid(qw/-row 2 -column 1 -sticky e/);

    #--------------------------------
    # Read system and external fonts
    # and populate lists
    #--------------------------------
    &get_fonts;
    $font_selector->withdraw; # Hide selector until is needed.
	} # -- end unless exists
  else  # deiconify font_selector if called from font menu buttn.
  {
    $font_selector->deiconify;
  }
} #----------- end sub create_font_selector --------

sub close_fonts {
  # Called when OK is pressed,
  # or when window is closed
  $tw->withdraw if Exists $tw;
  $font_selector->withdraw;
  #&save_rc;
}	# ----------  end of subroutine close_fonts  ----------

sub get_external_fonts_dir {
  #-----------------------
  # Called from the Browse Fonts dir button
  #-----------------------
  my $init_dir;
  ($external_font_dir) ? ($init_dir = $external_font_dir)
                       : ($init_dir = $home);
  my $font_dir = $font_selector->chooseDirectory
              (
                -title => 'Find Fonts Directory',
                -initialdir => $init_dir,
              );
  (defined $font_dir) ?  $external_font_dir = $font_dir : return; # return if Cancel
  $external_font_dir =~ s#/?$#/#;   # in case final / is missing
  &get_fonts;
}	# ----------  end of subroutine get_external_fonts_dir  ------

sub get_fonts {
  #-------------------------------------------
  # Read all ttf, otf files for external fonts,
  # and all system fonts.
  #
  # Called from create_font_selector
  # and from get_external_font_dir
  #-------------------------------------------
  my $error = 0;
  if ((-d $external_font_dir) && ( opendir(DIR, $external_font_dir)))
  {
    @external_fonts= ();
    while(defined(my $font_file = readdir(DIR)))
    {
      next if $font_file =~ /^\./;
      push @external_fonts, $font_file if $font_file =~ /^.*\.[ot]?tf/;
    }
    close(DIR);
  # error if no ext fonts are found.
  $error = 1  unless scalar @external_fonts;
  }
  else
  {
    &error_msg(" Cannot read $external_font_dir\.");
  }

  @system_fonts = sort $mw->fontFamilies;

  # warn if no externals are found.
  if ($error)
  {
    &error_msg("External Fonts not found!\nUse the Fonts menu\nto locate the fonts.");
  }

  # Update all active (system or external)font lists
  if (Exists $font_selector)
  {
    &update_font_list($_, $print_font{$_}->[0]) foreach @fonts;
  }
}	# ----------  end of subroutine get_fonts  ----------

sub update_font_list {
  #------------------------------
  # Update a dropdown font list
  # called from &get_fonts,
  # the radio buttons and the
  # dropdown font selectors.
  #------------------------------
  my $font = shift @_;                          # greek, latin, etc.
  my $font_source = $print_font{$font}->[0];
  my $font_list;
  $print_font{$font}->[0] = $font_source;       # set by the radio buttons
  ($font_source == 1) ? ($font_list = \@system_fonts) : ($font_list = \@external_fonts);

  unless ($font eq 'Bold')    # Bold is a special case
  {
    $font_props{$font}->{FontList}->delete(0, 'end');
    $font_props{$font}->{FontList}->insert('end', sort @{$font_list});
    # Change the list variable
    # so that the entry shows the selected font
    $font_props{$font}->{FontList}->configure(
                        -variable => \$print_font{$font}->[$print_font{$font}->[0]] );
  }

  # If Bold update the list
  # but do the same if Greek
  if ( ($font eq 'Bold') || ($font eq 'Greek') )
  {
    $print_font{Bold}->[0] = $font_source;
    $font_props{Bold}->{FontList}->delete(0, 'end');
    $font_props{Bold}->{FontList}->insert('end', sort @{$font_list});
    $font_props{Bold}->{FontList}->configure(
                        -variable  => \$print_font{Bold}->[$print_font{Greek}->[0]],
                    );
  }
  &update_font_preview;
} # --- end sub update_font_list --------------------

sub update_font_preview
{
  foreach (@fonts)
  {
    $sample_text->markSet('insert', "$_.first");
    if ($print_font{$_}->[0] == 1)
    {
      $sample_text->tagConfigure($_, -font => "{$print_font{$_}->[1]} $pt_size",
                                     -foreground => 'black');
      $sample_text->tagConfigure($_, -font => "{$print_font{$_}->[1]} $pt_size bold",
                                     -foreground => 'black')
                                       if $_ eq 'Bold';
      $sample_text->delete("$_.first", "$_.last" ) if ($sample_text->tagRanges($_));
      $sample_text->insert('insert',  "$sample{$_}\n\n", $_);
    }
    else
    {
      $sample_text->delete("$_.first", "$_.last" ) if ($sample_text->tagRanges($_));
      $sample_text->tagConfigure($_, -foreground => 'red',
                                     -font  => "{Arial} 11",
                                     );
      $sample_text->insert('insert',  "External font selected. Preview not possible. \n\n", $_);
    }
  }
  unless ($bold)
  {
      $sample_text->delete("Bold.first", "Bold.last" ) if ($sample_text->tagRanges('Bold'));
      $sample_text->tagConfigure('Bold', -foreground => 'red',
                                     -font  => "{Arial} 11",
                                     );
      $sample_text->insert('insert',  "Disabled. \n\n", 'Bold');

  }
  $active_font = $print_font{Greek}[$print_font{Greek}[0]];
}	# ----------  end of subroutine update_font_preview  ----------

sub font_error_check {
  # Checks whether the selected fonts exist in the @font lists
  my %errors;
  foreach my $font (@fonts)
  {
    if (grep(/$print_font{$font}->[1]/, @system_fonts))
    {
      $errors{"$font"."_system"} = 0;
    }
    else
    {
      $errors{"$font"."_system"} = 1;
    }
    if (grep(/$print_font{$font}->[2]/, @external_fonts))
    {
      $errors{"$font"."_external"} = 0;
    }
    else
    {
      $errors{"$font"."_external"} = 1;
    }
  }
  return \%errors;
}	# ----------  end of subroutine font_error_check  ----------
