#!/usr/bin/perl
#*****************************************************************************
#
#                          Frozen-Bubble
#
# Copyright (c) 2000, 2001, 2002, 2003 Guillaume Cottenceau <guillaume.cottenceau at free.fr>
#
# Sponsored by MandrakeSoft <http://www.mandrakesoft.com/>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
#
#******************************************************************************
#
# Design & Programming by Guillaume Cottenceau between Oct 2001 and Jan 2002.
# Level Editor parts by Kim Joham and David Joham between Oct 2002 and Jan 2003
#
# Check official home: http://www.frozen-bubble.org/
#
#******************************************************************************
#
#
# Yes it uses Perl, you non-believer :-).
#

#use diagnostics;
#use strict;

use vars qw($TARGET_ANIM_SPEED $BUBBLE_SIZE $ROW_SIZE $LAUNCHER_SPEED $BUBBLE_SPEED $MALUS_BUBBLE_SPEED $TIME_APPEARS_NEW_ROOT
            %POS %POS_1P %POS_2P $KEYS %actions %angle %pdata $app $font %apprects $event %rects %sticked_bubbles %root_bubbles
            $background $background_orig @bubbles_images $gcwashere %bubbles_anim %launched_bubble %tobe_launched %next_bubble
            $shooter $sdl_flags $mixer $mixer_enabled $music_disabled $sfx_disabled @playlist %sound %music %pinguin %canon
            $graphics_level @update_rects $CANON_ROTATIONS_NB %malus_bubble %falling_bubble %exploding_bubble %malus_gfx
            %sticking_bubble $version $time %imgbin $TIME_HURRY_WARN $TIME_HURRY_MAX $TIMEOUT_PINGUIN_SLEEP $FREE_FALL_CONSTANT
            $direct @PLAYERS %levels $display_on_app_disabled $total_time $time_1pgame $fullscreen $rcfile $hiscorefile $HISCORES
            $lev_number $playermalus $loaded_levelset $direct_levelset $chainreaction %chains %history);

use Data::Dumper;

use SDL;
use SDL::App;
use SDL::Surface;
use SDL::Event;
use SDL::Cursor;
use SDL::Font;
use SDL::Mixer;

use fb_stuff;
use fbsyms;
use FBLE;

$| = 1;

$TARGET_ANIM_SPEED = 20;        # number of milliseconds that should last between two animation frames
$LAUNCHER_SPEED = 0.03;  	# speed of rotation of launchers
$BUBBLE_SPEED = 10;		# speed of movement of launched bubbles
$MALUS_BUBBLE_SPEED = 30;	# speed of movement of "malus" launched bubbles
$CANON_ROTATIONS_NB = 40;       # number of rotations of images for canon (should be consistent with gfx/shoot/Makefile)

$TIMEOUT_PINGUIN_SLEEP = 200;
$FREE_FALL_CONSTANT = 0.5;
$KEYS = { p1 => { left => SDLK_x,    right => SDLK_v,     fire => SDLK_c,  center => SDLK_d },
	  p2 => { left => SDLK_LEFT, right => SDLK_RIGHT, fire => SDLK_UP, center => SDLK_DOWN },
	  misc => { fs => SDLK_f } };

$sdl_flags = SDL_ANYFORMAT | SDL_HWSURFACE | SDL_DOUBLEBUF | SDL_HWACCEL | SDL_ASYNCBLIT;
$mixer = 0;
$graphics_level = 3;
@PLAYERS = qw(p1 p2);
$playermalus = 0;
$chainreaction = 0;

$rcfile = "$ENV{HOME}/.fbrc";
eval(cat_($rcfile));
eval(cat_($hiscorefile = "$ENV{HOME}/.fbhighscores"));

$version = '1.0.1';

print "        [[ Frozen-Bubble-$version ]]\n\n";
print '  http://www.frozen-bubble.org/

  Copyright (c) 2000, 2001, 2002, 2003 Guillaume Cottenceau.
  Artwork: Alexis Younes <73lab at free.fr>
           Amaury Amblard-Ladurantie <amaury at linuxfr.org>
  Soundtrack: Matthias Le Bidan <matthias.le_bidan at caramail.com>
  Design & Programming: Guillaume Cottenceau <guillaume.cottenceau at free.fr>
  Level Editor: Kim and David Joham <[k|d]joham at yahoo.com>

  Sponsored by MandrakeSoft <http://www.mandrakesoft.com/>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2, as
  published by the Free Software Foundation.

';

local $_ = "@ARGV";

/-h/ and die "Usage: ", basename($0), " [OPTION]...
  -h, --help                 display this help screen
 -fs, --fullscreen           start in fullscreen mode
 -ns, --nosound              don't try to start any sound stuff
 -nm, --nomusic              disable music (only)
 -nfx, --nosfx               disable sound effects (only)
      --playlist<file>       use all files listed in the given file as music files and play them
      --playlist<directory>  use all files inside the given directory as music files and play them
 -sl, --slow_machine         enable slow machine mode (disable a few animations)
 -vs, --very_slow_machine    enable very slow machine mode (disable all that can be disabled)
 -di, --direct               directly start (2p) game (don't display menu)
 -so, --solo                 directly start solo (1p) game, with random levels
 -cr, --chain_reaction       enable chain-reaction
 -l<#n>, --level<#n>         directly start the n-th level
 -cb, --colourblind          use bubbles for colourblind people
 -pm<#n>, --playermalus<#n>  add a malus of n to the left player (can be negative)
 -ls<name>, --levelset<name> directly start with the specified levelset name

";

/-fs/ || /-fu/ and $fullscreen = 1;
/-ns/ || /-noso/ and $mixer = 'SOUND_DISABLED';
/-nm/ || /-nom/ and $music_disabled = 1;
/-nfx/ || /-nosf/ and $sfx_disabled = 1;
/-playlist\s*(\S+)/ and @playlist = -d $1 ? glob("$1/*") : cat_($1);
/-sl/ and $graphics_level = 2;
/-vs/ || /-ve/ and $graphics_level = 1;
/-srand/ and srand 0;
/-di/ and $direct = 1;
/-so/ and $direct = 1, @PLAYERS = ('p1');
/-cr/ || /-chain_reaction/ and $chainreaction = 1;
/-cb/ || /-co/ and $colourblind = 1;
/-pm\s*(-?[\d]+)/ || /-playermalus\s*(-?\d+)/ and $playermalus = $1;
/-ls\s*(\S+)/ || /-levelset\s*(\S+)/ and $levels{current} = 1, $direct = 1, @PLAYERS = ('p1'), $direct_levelset = $1;
/-l\s*(\d+)/ || /-level\s*(\d+)/ and $levels{current} = $1, $direct = 1, @PLAYERS = ('p1');


#- ------------------------------------------------------------------------

END {
    if ($app) {
	$total_time = ($app->ticks - $total_time)/1000;
	my $h = int($total_time/3600);
	my $m = int(($total_time-$h*3600)/60);
	my $s = int($total_time-$h*3600-$m*60);
	print "\nAddicted for ", $h ? "$h"."h " : "", $m ? "$m"."m " : "", "$s"."s.\n";
    }
}

#- it doesn't keep ordering (but I don't care)
sub fastuniq { my %l; @l{@_} = @_; values %l }


#- ----------- sound related stuff ----------------------------------------

sub play_sound($) {
    $mixer_enabled && $mixer && !$sfx_disabled && $sound{$_[0]} and $mixer->play_channel(-1, $sound{$_[0]}, 0);
}
sub chomp_ { my @l = map { my $l = $_; chomp $l; $l } @_; wantarray() ? @l : $l[0] }
sub play_music($;$) {
    my ($name, $pos) = @_;
    $mixer_enabled && $mixer && !$music_disabled or return;
    @playlist && $mixer->playing_music and return;
    $app->delay(10) while $mixer->fading_music;   #- mikmod will deadlock if we try to fade_out while still fading in
    $mixer->playing_music and $mixer->fade_out_music(500); $app->delay(400);
    $app->delay(10) while $mixer->playing_music;  #- mikmod will segfault if we try to load a music while old one is still fading out
    my %musics = (intro => '/snd/introzik.xm', main1p => '/snd/frozen-mainzik-1p.xm', main2p => '/snd/frozen-mainzik-2p.xm');
    my $mus if 0;                                 #- I need to keep a reference on the music or it will be collected at the end of this function, thus I manually collect previous music
    if (@playlist) {
	my $tryanother = sub {
	    my $elem = chomp_(shift @playlist);
	    $elem or return -1;
	    -f $elem or return 0;
	    push @playlist, $elem;
	    $mus = SDL::Music->new($elem);
	    if ($mus->{-data}) {
		print STDERR "[Playlist] playing `$elem'\n";
		$mixer->play_music($mus, 0);
		return 1;
	    } else { 
		print STDERR "Warning, could not create new music from `$elem' (reason: ", $app->error, ").\n";
		return 0;
	    }
	};
	while ($tryanother->() == 0) {};
    } else {
	$mus = SDL::Music->new("$FPATH$musics{$name}");
	$mus->{-data} or print STDERR "Warning, could not create new music from `$FPATH$musics{$name}' (reason: ", $app->error, ").\n";
	if ($pos) {
	    fb_c_stuff::fade_in_music_position($mus->{-data}, -1, 500, $pos);
	} else {
	    $mixer->play_music($mus, -1);
	}
    }
}

sub init_sound() {
    $mixer = eval { SDL::Mixer->new(-frequency => 44100, -channels => 2, -size => 1024); };
    if ($@) {
	$@ =~ s| at \S+ line.*\n||;
	print STDERR "\nWarning: can't initialize sound (reason: $@).\n";
	return 0;
    }
    print "[Sound Init]\n";
    my @sounds = qw(stick destroy_group newroot newroot_solo lose hurry pause menu_change menu_selected rebound launch malus noh snore cancel typewriter applause);
    foreach (@sounds) {
	my $sound_path = "$FPATH/snd/$_.wav";
	$sound{$_} = SDL::Sound->new($sound_path);
	if ($sound{$_}{-data}) {
	    $sound{$_}->volume(80);
	} else {
	    print STDERR "Warning, could not create new sound from `$sound_path'.\n";
	}
    }
    return 1;
}


#- ----------- graphics related stuff --------------------------------------

sub add_default_rect($) {
    my ($surface) = @_;
    $rects{$surface} = SDL::Rect->new(-width => $surface->width, -height => $surface->height);
}

sub put_image($$$) {
    my ($image, $x, $y) = @_;
    $rects{$image} or die "please don't call me with no rects\n".backtrace();
    my $drect = SDL::Rect->new(-width => $image->width, -height => $image->height, -x => $x, '-y' => $y);
    $image->blit($rects{$image}, $app, $drect);
    push @update_rects, $drect;
}

sub erase_image_from($$$$) {
    my ($image, $x, $y, $img) = @_;
    my $drect = SDL::Rect->new(-width => $image->width, -height => $image->height, -x => $x, '-y' => $y);
    $img->blit($drect, $app, $drect);
    push @update_rects, $drect;
}

sub erase_image($$$) {
    my ($image, $x, $y) = @_;
    erase_image_from($image, $x, $y, $background);
}

sub put_image_to_background($$$) {
    my ($image, $x, $y) = @_;
    my $drect;
    ($x == 0 && $y == 0) and print "put_image_to_background: warning, X and Y are 0\n";
    if ($y > 0) {
	$drect = SDL::Rect->new(-width => $image->width, -height => $image->height, -x => $x, '-y' => $y);
	$display_on_app_disabled or $image->blit($rects{$image}, $app, $drect);
	$image->blit($rects{$image}, $background, $drect);
    } else {  #- clipping seems to not work when from one Surface to another Surface, so I need to do clipping by hand
	$drect = SDL::Rect->new(-width => $image->width, -height => $image->height + $y, -x => $x, '-y' => 0);
	my $irect = SDL::Rect->new(-width => $image->width, -height => $image->height + $y, '-y' => -$y);
	$display_on_app_disabled or $image->blit($irect, $app, $drect);
	$image->blit($irect, $background, $drect);
    }
    push @update_rects, $drect;
}

sub remove_image_from_background($$$) {
    my ($image, $x, $y) = @_;
    ($x == 0 && $y == 0) and print "remove_image_from_background: warning, X and Y are 0\n";
    my $drect = SDL::Rect->new(-width => $image->width, -height => $image->height, -x => $x, '-y' => $y);
    $background_orig->blit($drect, $background, $drect);
    $background_orig->blit($drect, $app, $drect);
    push @update_rects, $drect;
}

sub remove_images_from_background {
    my ($player, @images) = @_;
    foreach (@images) {
	($_->{'x'} == 0 && $_->{'y'} == 0) and print "remove_images_from_background: warning, X and Y are 0\n";
	my $drect = SDL::Rect->new(-width => $_->{img}->width, -height => $_->{img}->height, -x => $_->{'x'}, '-y' => $_->{'y'});
	$background_orig->blit($drect, $background, $drect);
	$background_orig->blit($drect, $app, $drect);
	push @update_rects, $drect;
    }
}

sub put_allimages_to_background($) {
    my ($player) = @_;
    put_image_to_background($_->{img}, $_->{'x'}, $_->{'y'}) foreach @{$sticked_bubbles{$player}};
}

sub switch_image_on_background($$$;$) {
    my ($image, $x, $y, $save) = @_;
    my $drect = SDL::Rect->new(-width => $image->width, -height => $image->height, -x => $x, '-y' => $y);
    if ($save) {
	$save = SDL::Surface->new(-width => $image->width, -height => $image->height, -depth => 32, -Amask => "0 but true");  #- grrr... this piece of shit of Amask made the surfaces slightly modify along the print/erase of "Hurry" and "Pause".... took me so much time to debug and find that the problem came from a bug when Amask is set to 0xFF000000 (while it's -supposed- to be set to 0xFF000000 with 32-bit graphics!!)
	$background->blit($drect, $save, $rects{$image});
    }
    $image->blit($rects{$image} || SDL::Rect->new(-width => $image->width, -height => $image->height), $background, $drect);
    $background->blit($drect, $app, $drect);
    push @update_rects, $drect;
    return $save;
}

sub add_image($) {
    my $file = "$FPATH/gfx/$_[0]";
    my $img = SDL::Surface->new(-name => $file);
    $img->{-surface} or die "FATAL: Couldn't load `$file' into a SDL::Surface.\n";
    add_default_rect($img);
    return $img;
}

sub add_bubble_image($) {
    my ($file) = @_;
    my $bubble = add_image($file);
    push @bubbles_images, $bubble;
}


#- ----------- generic game stuff -----------------------------------------

sub iter_players(&) {
    my ($f) = @_;
    local $::p;
    foreach $::p (@PLAYERS) {
	&$f;
    }
}
sub iter_players_(&) {  #- so that I can do an iter_players_ from within an iter_players
    my ($f) = @_;
    local $::p_;
    foreach $::p_ (@PLAYERS) {
	&$f;
    }
}
sub is_1p_game() { @PLAYERS == 1 }
sub is_2p_game() { @PLAYERS == 2 }


#- ----------- bubble game stuff ------------------------------------------

sub calc_real_pos_given_arraypos($$$) {
    my ($cx, $cy, $player) = @_;
    ($POS{$player}{left_limit} + $cx * $BUBBLE_SIZE + odd($cy+$pdata{$player}{oddswap}) * $BUBBLE_SIZE/2,
     $POS{top_limit} + $cy * $ROW_SIZE);
}

sub calc_real_pos($$) {
    my ($b, $player) = @_;
    ($b->{'x'}, $b->{'y'}) = calc_real_pos_given_arraypos($b->{cx}, $b->{cy}, $player);
}

sub get_array_yclosest($) {
    my ($y) = @_;
    return int(($y-$POS{top_limit}+$ROW_SIZE/2) / $ROW_SIZE);
}

sub get_array_closest_pos($$$) { # roughly the opposite than previous function
    my ($x, $y, $player) = @_;
    my $ny = get_array_yclosest($y);
    my $nx = int(($x-$POS{$player}{left_limit}+$BUBBLE_SIZE/2 - odd($ny+$pdata{$player}{oddswap})*$BUBBLE_SIZE/2)/$BUBBLE_SIZE);
    return ($nx, $ny);
}

sub is_collision($$$) {
    my ($bub, $x, $y) = @_;
    my $DISTANCE_COLLISION_SQRED = sqr($BUBBLE_SIZE * 0.82);
    my $xs = sqr($bub->{x} - $x);
    ($xs > $DISTANCE_COLLISION_SQRED) and return 0; 
    return ($xs + sqr($bub->{'y'} - $y)) < $DISTANCE_COLLISION_SQRED;
}

sub create_bubble_given_img($) {
    my ($img) = @_;
    my %bubble;
    ref($img) eq 'SDL::Surface' or die "<$img> seems to not be a valid image\n" . backtrace();
    $bubble{img} = $img;
    return \%bubble;
}

sub create_bubble(;$) {
    my ($p) = @_;
    my $b = create_bubble_given_img($bubbles_images[rand(@bubbles_images)]);
    is_1p_game() && $p && !member($b->{img}, map { $_->{img} } @{$sticked_bubbles{$p}})
      and return &create_bubble($p);  #- prototype checking pb w/ recursion
    return $b;
}

sub iter_rowscols(&$) {
    my ($f, $oddswap) = @_;
    local $::row; local $::col;
    foreach $::row (0 .. 11) {
	foreach $::col (0 .. 7 - odd($::row+$oddswap)) {
	    &$f;
	}
    }
}

sub each_index(&@) {
    my $f = shift;
    local $::i = 0;
    foreach (@_) {
	&$f($::i);
	$::i++;
    }
}
sub img2numb { my ($i, $f) = @_; each_index { $i eq $_ and $f = $::i } @bubbles_images; return defined($f) ? $f : '-' }

#sub history {
#    foreach my $frame (@{$history{$_[0]}}[-10...1]) {
#	iter_rowscols {
#	    if ($::col == 0) {
#		$::row == 0 or print "\n";
#		odd($::row+$frame->{oddswap}) and print "  ";
#	    }
#	    foreach (@{$frame->{sticked}}) {
#		$_->[0] == $::col && $_->[1] == $::row or next;
#		print $_->[2];
#		goto non_void;
#	    }
#	    if ($frame->{sticking}[0] == $::col && $frame->{sticking}[1] == $::row) {
#		print "\033[D!$frame->{sticking}[2]";
#		goto non_void;
#	    }
#	    print '-';
#	  non_void:
#	    $::col+odd($::row+$frame->{oddswap}) < 7 and print "   ";
#        } $frame->{oddswap};
#	print "\n\n";
#    }
#}

sub bubble_next_to($$$$$) {
    my ($x1, $y1, $x2, $y2, $player) = @_;
    $x1 == $x2 && $y1 == $y2 and die "bubble_next_to: assert failed -- same bubbles ($x1:$y1;$player)" . backtrace();
#    $x1 == $x2 && $y1 == $y2 and history($player), die "bubble_next_to: assert failed -- same bubbles ($x1:$y1;$player)" . backtrace();
    return to_bool((sqr($x1+odd($y1+$pdata{$player}{oddswap})*0.5 - ($x2+odd($y2+$pdata{$player}{oddswap})*0.5)) + sqr($y1 - $y2)) < 3);
}

sub next_positions($$) {
    my ($b, $player) = @_;
    my $validate_pos = sub {
	my ($x, $y) = @_;
	if_($x >= 0 && $x+odd($y+$pdata{$player}{oddswap}) <= 7 && $y >= 0 && $y >= $pdata{$player}{newrootlevel} && $y <= 11,
	    [ $x, $y ]);
    };
    ($validate_pos->($b->{cx} - 1, $b->{cy}),
     $validate_pos->($b->{cx} + 1, $b->{cy}),
     $validate_pos->($b->{cx} - even($b->{cy}+$pdata{$player}{oddswap}), $b->{cy} - 1),
     $validate_pos->($b->{cx} - even($b->{cy}+$pdata{$player}{oddswap}), $b->{cy} + 1),
     $validate_pos->($b->{cx} - even($b->{cy}+$pdata{$player}{oddswap}) + 1, $b->{cy} - 1),
     $validate_pos->($b->{cx} - even($b->{cy}+$pdata{$player}{oddswap}) + 1, $b->{cy} + 1));
}

#- bubble ends its life sticked somewhere
sub real_stick_bubble {
    my ($bubble, $xpos, $ypos, $player, $neighbours_ok) = @_;
    $bubble->{cx} = $xpos;
    $bubble->{cy} = $ypos;
    foreach (@{$sticked_bubbles{$player}}) {
	if (bubble_next_to($_->{cx}, $_->{cy}, $bubble->{cx}, $bubble->{cy}, $player)) {
	    push @{$_->{neighbours}}, $bubble;
	    $neighbours_ok or push @{$bubble->{neighbours}}, $_;
	}
    }
    push @{$sticked_bubbles{$player}}, $bubble;
    $bubble->{cy} == $pdata{$player}{newrootlevel} and push @{$root_bubbles{$player}}, $bubble;
    calc_real_pos($bubble, $player);
    put_image_to_background($bubble->{img}, $bubble->{'x'}, $bubble->{'y'});
}

sub destroy_bubbles {
    my ($player, @bubz) = @_;
    $graphics_level == 1 and return;
    foreach (@bubz) {
	$_->{speedx} = rand(3)-1.5;
	$_->{speedy} = -rand(4)-2;
    }
    push @{$exploding_bubble{$player}}, @bubz;
}

sub find_bubble_group($) {
    my ($b) = @_;
    my @neighbours = $b;
    my @group;
    while (1) {
	push @group, @neighbours;
	@neighbours = grep { $b->{img} eq $_->{img} && !member($_, @group) } fastuniq(map { @{$_->{neighbours}} } @neighbours);
	last if !@neighbours;
    }
    @group;
}

sub stick_bubble($$$$$) {
    my ($bubble, $xpos, $ypos, $player, $count_for_root) = @_;
    my @falling;
    my $need_redraw = 0;
    @{$bubble->{neighbours}} = grep { bubble_next_to($_->{cx}, $_->{cy}, $xpos, $ypos, $player) } @{$sticked_bubbles{$player}};

    #- in multiple chain reactions, it's possible that the group doesn't exist anymore in some rare situations :/
    exists $bubble->{chaindestx} && !@{$bubble->{neighbours}} and return;

    my @will_destroy = difference2([ find_bubble_group($bubble) ], [ $bubble ]);

    if (@will_destroy <= 1) {
	#- stick
	play_sound('stick');
	real_stick_bubble($bubble, $xpos, $ypos, $player, 1);
	$sticking_bubble{$player} = $bubble;
	$pdata{$player}{sticking_step} = 0;
    } else {
	#- destroy the group
	play_sound('destroy_group');
	foreach my $b (difference2([ fastuniq(map { @{$_->{neighbours}} } @will_destroy) ], \@will_destroy)) {
	    @{$b->{neighbours}} = difference2($b->{neighbours}, \@will_destroy);
	}
	@{$sticked_bubbles{$player}} = difference2($sticked_bubbles{$player}, \@will_destroy);
	@{$root_bubbles{$player}} = difference2($root_bubbles{$player}, \@will_destroy);

	$bubble->{'cx'} = $xpos;
	$bubble->{'cy'} = $ypos;
	calc_real_pos($bubble, $player);
	destroy_bubbles($player, @will_destroy, $bubble);

	#- find falling bubbles
	$_->{mark} = 0 foreach @{$sticked_bubbles{$player}};
	my @still_sticked;
	my @neighbours = @{$root_bubbles{$player}};
	my $distance_to_root;
	while (1) {
	    $_->{mark} = ++$distance_to_root foreach @neighbours;
	    push @still_sticked, @neighbours;
	    @neighbours = grep { $_->{mark} == 0 } map { @{$_->{neighbours}} } @neighbours;
	    last if !@neighbours;
	}
	@falling = difference2($sticked_bubbles{$player}, \@still_sticked);
	@{$sticked_bubbles{$player}} = difference2($sticked_bubbles{$player}, \@falling);

	#- chain-reaction on falling bubbles
	if ($chainreaction) {
	    my @falling_colors = map { $_->{img} } @falling;
	    #- optimize a bit by first calculating bubbles that are next to another bubble of the same color
	    my @grouped_bubbles = grep {
		my $b = $_;
		member($b->{img}, @falling_colors) && any { $b->{img} eq $_->{img} } @{$b->{neighbours}}
	    } @{$sticked_bubbles{$player}};
	    if (@grouped_bubbles) {
		#- all positions on which we can't chain-react
		my @occupied_positions = map { $_->{cy}*8 + $_->{cx} } @{$sticked_bubbles{$player}};
		push @occupied_positions, map { $_->{chaindestcy}*8 + $_->{chaindestcx} } @{$chains{$player}{falling_chained}};
		#- examine groups beginning at the root bubbles, for the case in which
		#- there is a group that will fall from an upper chain-reaction
		foreach my $pos (sort { $a->{mark} <=> $b->{mark} } @grouped_bubbles) {
		    #- now examine if there is a free position to chain-react in it
		    foreach my $npos (next_positions($pos, $player)) {
			#- we can't chain-react somewhere if it explodes a group already chained
			next if any { $pos->{cx} == $_->{cx} && $pos->{cy} == $_->{cy} }
			        map { @{$chains{$player}{chained_bubbles}{$_}}} keys %{$chains{$player}{chained_bubbles}};
			if (!member($npos->[1]*8 + $npos->[0], @occupied_positions)) {
			    #- find a suitable falling bubble for that free position
			    foreach my $falling (@falling) {
				next if member($falling, @{$chains{$player}{falling_chained}});
				if ($pos->{img} eq $falling->{img}) {
				    ($falling->{chaindestcx}, $falling->{chaindestcy}) = ($npos->[0], $npos->[1]);
				    ($falling->{chaindestx}, $falling->{chaindesty}) = calc_real_pos_given_arraypos($npos->[0], $npos->[1], $player);
				    push @{$chains{$player}{falling_chained}}, $falling;
				    push @occupied_positions, $npos->[1]*8 + $npos->[0];
				    
				    #- next lines will allow not to chain-react on the same group from two different positions,
				    #- and even to not chain-react on a group that will itself fall from a chain-reaction
				    @{$falling->{neighbours}} = grep { bubble_next_to($_->{cx}, $_->{cy}, $npos->[0], $npos->[1], $player) } @{$sticked_bubbles{$player}};
				    my @chained_bubbles = find_bubble_group($falling);
				    $_->{mark} = 0 foreach @{$sticked_bubbles{$player}};
				    my @still_sticked;
				    my @neighbours = difference2($root_bubbles{$player}, \@chained_bubbles);
				    while (1) {
					$_->{mark} = 1 foreach @neighbours;
					push @still_sticked, @neighbours;
					@neighbours = difference2([ grep { $_->{mark} == 0 } map { @{$_->{neighbours}} } @neighbours ],
								  \@chained_bubbles);
					last if !@neighbours;
				    }
				    @{$chains{$player}{chained_bubbles}{$falling}} = difference2($sticked_bubbles{$player}, \@still_sticked);
				    last;
				}
			    }
			}
		    }
		}
	    }
	}

	#- prepare falling bubbles
	if ($graphics_level > 1) {
	    my $max_cy_falling = fold_left { $::b->{cy} > $::a ? $::b->{cy} : $::a } 0, @falling;  #- I have a fold_left in my prog! :-)
	    my ($shift_on_same_line, $line) = (0, $max_cy_falling);
	    foreach (sort { $b->{cy}*8 + $b->{cx} <=> $a->{cy}*8 + $a->{cx} } @falling) {  #- sort bottom-to-up / right-to-left
		$line != $_->{cy} and $shift_on_same_line = 0;
		$line = $_->{cy};
		$_->{wait_fall} = ($max_cy_falling - $_->{cy})*5 + $shift_on_same_line;
		$shift_on_same_line++;
		$_->{speed} = 0;
	    }
	    push @{$falling_bubble{$player}}, @falling;
	}

	remove_images_from_background($player, @will_destroy, @falling);
	#- redraw neighbours because parts of neighbours have been erased by previous statement
	put_image_to_background($_->{img}, $_->{'x'}, $_->{'y'})
	  foreach grep { !member($_, @will_destroy) && !member($_, @falling) } fastuniq(map { @{$_->{neighbours}} } @will_destroy, @falling);
	$need_redraw = 1;
    }

    if ($count_for_root) {
	$pdata{$player}{newroot}++;
	if ($pdata{$player}{newroot} == $TIME_APPEARS_NEW_ROOT-1) {
	    $pdata{$player}{newroot_prelight} = 2;
	    $pdata{$player}{newroot_prelight_step} = 0;
	}
	if ($pdata{$player}{newroot} == $TIME_APPEARS_NEW_ROOT) {
	    $pdata{$player}{newroot_prelight} = 1;
	    $pdata{$player}{newroot_prelight_step} = 0;
	}
	if ($pdata{$player}{newroot} > $TIME_APPEARS_NEW_ROOT) {
	    $need_redraw = 1;
	    $pdata{$player}{newroot_prelight} = 0;
	    play_sound(is_1p_game() ? 'newroot_solo' : 'newroot');
	    $pdata{$player}{newroot} = 0;
	    $pdata{$player}{oddswap} = !$pdata{$player}{oddswap};
	    remove_images_from_background($player, @{$sticked_bubbles{$player}});
	    foreach (@{$sticked_bubbles{$player}}) {
		$_->{'cy'}++;
		calc_real_pos($_, $player);
	    }
	    foreach (@{$falling_bubble{$player}}) {
		exists $_->{chaindestx} or next;
		$_->{chaindestcy}++;
		$_->{chaindesty} += $ROW_SIZE;
	    }
	    put_allimages_to_background($player);
	    if (is_1p_game()) {
		$pdata{$player}{newrootlevel}++;
		print_compressor();
	    } else {
		@{$root_bubbles{$player}} = ();
		real_stick_bubble(create_bubble($player), $_, 0, $player, 0) foreach (0..(7-$pdata{$player}{oddswap}));
	    }
	}
    }

    if ($need_redraw) {
	my $malus_val = @will_destroy + @falling - 2;
	$malus_val > 0 and $malus_val += ($player eq 'p1' ? $playermalus : -$playermalus);
	$malus_val < 0 and $malus_val = 0;
	$background->blit($apprects{$player}, $app, $apprects{$player});
	malus_change($malus_val, $player);
    }

#    push @{$history{$player}}, { sticking => [ $xpos, $ypos, img2numb($bubble->{img}) ],
#				 oddswap => $pdata{$player}{oddswap},
#				 sticked => [ map { [ $_->{cx}, $_->{cy}, img2numb($_->{img}) ] } @{$sticked_bubbles{$player}} ] };
}

sub print_next_bubble($$;$) {
    my ($img, $player, $not_on_top_next) = @_;
    put_image_to_background($img, $next_bubble{$player}{'x'}, $next_bubble{$player}{'y'});
    $not_on_top_next or put_image_to_background($bubbles_anim{on_top_next}, $POS{$player}{left_limit}+$POS{next_bubble}{x}-4, $POS{next_bubble}{'y'}-3);
}

sub generate_new_bubble {
    my ($player, $img) = @_;
    $tobe_launched{$player} = $next_bubble{$player};
    $tobe_launched{$player}{'x'} = ($POS{$player}{left_limit}+$POS{$player}{right_limit})/2 - $BUBBLE_SIZE/2;
    $tobe_launched{$player}{'y'} = $POS{'initial_bubble_y'};
    $next_bubble{$player} = $img ? create_bubble_given_img($img) : create_bubble($player);
    $next_bubble{$player}{'x'} = $POS{$player}{left_limit}+$POS{next_bubble}{x}; #- necessary to keep coordinates, for verify_if_end
    $next_bubble{$player}{'y'} = $POS{next_bubble}{'y'};
    print_next_bubble($next_bubble{$player}{img}, $player);
}


#- ----------- game stuff -------------------------------------------------

sub handle_graphics($) {
    my ($fun) = @_;

    iter_players {
	#- bubbles
	foreach ($launched_bubble{$::p}, if_($fun ne \&erase_image, $tobe_launched{$::p})) {
	    $_ and $fun->($_->{img}, $_->{'x'}, $_->{'y'});
	}
	if ($fun eq \&put_image && $pdata{$::p}{newroot_prelight}) {
	    if ($pdata{$::p}{newroot_prelight_step}++ > 30*$pdata{$::p}{newroot_prelight}) {
		$pdata{$::p}{newroot_prelight_step} = 0;
	    }
	    if ($pdata{$::p}{newroot_prelight_step} <= 8) {
		my $hurry_overwritten = 0;
		foreach my $b (@{$sticked_bubbles{$::p}}) {
		    next if ($graphics_level == 1 && $b->{'cy'} > 0);  #- in low graphics, only prelight first row
		    $b->{'cx'}+1 == $pdata{$::p}{newroot_prelight_step} and put_image($b->{img}, $b->{'x'}, $b->{'y'});
		    $b->{'cx'} == $pdata{$::p}{newroot_prelight_step} and put_image($bubbles_anim{white}, $b->{'x'}, $b->{'y'});
		    $b->{'cy'} > 6 and $hurry_overwritten = 1;
		}
		$hurry_overwritten && $pdata{$::p}{hurry_save_img} and print_hurry($::p, 1);  #- hurry was potentially overwritten
	    }
	}
	if ($sticking_bubble{$::p} && $graphics_level > 1) {
	    my $b = $sticking_bubble{$::p};
	    if ($fun eq \&erase_image) {
		put_image($b->{img}, $b->{'x'}, $b->{'y'});
	    } else {
		if ($pdata{$::p}{sticking_step} == @{$bubbles_anim{stick}}) {
		    $sticking_bubble{$::p} = undef;
		} else {
		    put_image(${$bubbles_anim{stick}}[$pdata{$::p}{sticking_step}], $b->{'x'}, $b->{'y'});
		    if ($pdata{$::p}{sticking_step_slowdown}) {
			$pdata{$::p}{sticking_step}++;
			$pdata{$::p}{sticking_step_slowdown} = 0;
		    } else {
			$pdata{$::p}{sticking_step_slowdown}++;
		    }
		}
	    }
	}

	#- shooter
	if ($graphics_level > 1) {
	    my $num = int($angle{$::p}*$CANON_ROTATIONS_NB/($PI/2) + 0.5)-$CANON_ROTATIONS_NB;
	    $fun->($canon{img}{$num},
		   ($POS{$::p}{left_limit}+$POS{$::p}{right_limit})/2 - 50 + $canon{data}{$num}->[0],
		   $POS{'initial_bubble_y'} + 16 - 50 + $canon{data}{$num}->[1] );  #- 50/50 stand for half width/height of gfx/shoot/base.png
	} else {
	    $fun->($shooter,
		   ($POS{$::p}{left_limit}+$POS{$::p}{right_limit})/2 - 1 + 60*cos($angle{$::p}),  #- 1 for $shooter->width/2
		   $POS{'initial_bubble_y'} + 16 - 1 - 60*sin($angle{$::p}));  #- 1/1 stand for half width/height of gfx/shoot/shooter.png
	}
	#- penguins
	if ($graphics_level == 3) {
	    $fun->($pinguin{$::p}{$pdata{$::p}{ping_right}{state}}[$pdata{$::p}{ping_right}{img}], $POS{$::p}{left_limit}+$POS{$::p}{pinguin}{x}, $POS{$::p}{pinguin}{'y'});
	}

	#- moving bubbles --> I want them on top of the rest
	foreach (@{$malus_bubble{$::p}}, @{$falling_bubble{$::p}}, @{$exploding_bubble{$::p}}) {
	    $fun->($_->{img}, $_->{'x'}, $_->{'y'});
	}

    };

}

#- extract it from "handle_graphics" to optimize a bit animations
sub malus_change($$) {
    my ($numb, $player) = @_;
    return if $numb == 0 || is_1p_game();
    if ($numb >= 0) {
	$player = ($player eq 'p1') ? 'p2' : 'p1';
    }
    my $update_malus = sub($) {
	my ($fun) = @_;
	my $malus = $pdata{$player}{malus};
	my $y_shift = 0;
	while ($malus > 0) {
	    my $print = sub($) {
		my ($type) = @_;
		$fun->($type, $POS{$player}{malus_x} - $type->width/2, $POS{'malus_y'} - $y_shift - $type->height);
		$y_shift += $type->height - 1;
	    };
	    if ($malus >= 7) {
		$print->($malus_gfx{tomate});
		$malus -= 7;
	    } else {
		$print->($malus_gfx{banane});
		$malus--;
	    }
	}
    };
    $update_malus->(\&remove_image_from_background);
    $pdata{$player}{malus} += $numb;
    $update_malus->(\&put_image_to_background);
}

sub print_compressor() {
    my $x = $POS{compressor_xpos};
    my $y = $POS{top_limit} + $pdata{$PLAYERS[0]}{newrootlevel} * $ROW_SIZE;
    my ($comp_main, $comp_ext) = ($imgbin{compressor_main}, $imgbin{compressor_ext});

    my $drect = SDL::Rect->new(-width => $comp_main->width, -height => $y,
			       -x => $x - $comp_main->width/2, '-y' => 0);
    $background_orig->blit($drect, $background, $drect);
    $display_on_app_disabled or $background_orig->blit($drect, $app, $drect);
    push @update_rects, $drect;

    put_image_to_background($comp_main, $x - $comp_main->width/2, $y - $comp_main->height);

    $y -= $comp_main->height - 3;

    while ($y > 0) {
	put_image_to_background($comp_ext, $x - $comp_ext->width/2, $y - $comp_ext->height);
	$y -= $comp_ext->height;
    }
}

sub handle_game_events() {
    $event->pump;
    if ($event->poll != 0) {
	if ($event->type == SDL_KEYDOWN) {
	    my $keypressed = $event->key_sym;

	    iter_players {
		my $pkey = is_1p_game() ? 'p2' : $::p;
		foreach (qw(left right fire center)) {
		    $keypressed == $KEYS->{$pkey}{$_} and $actions{$::p}{$_} = 1, last;
		}
	    };
	    
	    if ($keypressed == $KEYS->{misc}{fs}) {
		$fullscreen = !$fullscreen;
		$app->fullscreen;
	    }

	    if ($keypressed == SDLK_PAUSE) {
		play_sound('pause');
		$mixer_enabled && $mixer and $mixer->pause_music;
		my $back_saved = switch_image_on_background($imgbin{back_paused}, 0, 0, 1);
	      pause_label:
		while (1) {
		    my ($index, $side) = (0, 1);
		    while ($index || $side == 1) {
			put_image(${$imgbin{paused}}[$index], $POS_1P{pause_clip}{x}, $POS_1P{pause_clip}{'y'});
			$app->flip;
			foreach (1..80) {
			    $app->delay(20);
			    $event->pump;
			    if ($event->poll != 0 && $event->type == SDL_KEYDOWN) {
				last pause_label if $event->key_sym != $KEYS->{misc}{fs};
				$fullscreen = !$fullscreen;
				$app->fullscreen;
			    }
			}
			rand() < 0.2 and play_sound('snore');
			$index += $side;
			if ($index == @{$imgbin{paused}}) {
			    $side = -1;
			    $index -= 2;
			}
		    }
		}
		switch_image_on_background($back_saved, 0, 0);
		iter_players { $actions{$::p}{left} = 0; $actions{$::p}{right} = 0; };
		$mixer_enabled && $mixer and $mixer->resume_music;
		$event->pump while $event->poll != 0;
		$app->flip;
	    }

	}

	if ($event->type == SDL_KEYUP) {
	    my $keypressed = $event->key_sym;

	    iter_players {
		my $pkey = is_1p_game() ? 'p2' : $::p;
		foreach (qw(left right fire center)) {
		    $keypressed == $KEYS->{$pkey}{$_} and $actions{$::p}{$_} = 0, last;
		}
	    }
	}

	if ($event->type == SDL_QUIT ||
	    $event->type == SDL_KEYDOWN && $event->key_sym == SDLK_ESCAPE) {
	    die 'quit';
	}
    }
}

sub print_scores($) {
    my ($surface) = @_;  #- TODO all this function has hardcoded coordinates
    my $drect = SDL::Rect->new(-width => 120, -height => 30, -x => 260, '-y' => 428);
    $background_orig->blit($drect, $surface, $drect);
    push @update_rects, $drect;
    iter_players_ {  #- sometimes called from within a iter_players so...
	$surface->print($POS{$::p_}{scoresx}-SDL_TEXTWIDTH($pdata{$::p_}{score})/2, $POS{scoresy}, $pdata{$::p_}{score});
    };
}

sub verify_if_end {
    iter_players {
	if (any { $_->{cy} > 11 } @{$sticked_bubbles{$::p}}) {
	    $pdata{state} = "lost $::p";
	    play_sound('lose');
	    $pdata{$::p}{ping_right}{state} = 'lose';
	    $pdata{$::p}{ping_right}{img} = 0;
	    if (!is_1p_game()) {
		my $won = $::p eq 'p1' ? 'p2' : 'p1';
		$pdata{$won}{score}++;
		$pdata{$won}{ping_right}{state} = 'win';
		$pdata{$won}{ping_right}{img} = 0;
		print_scores($background); print_scores($app);
	    }
	    foreach ($launched_bubble{$::p}, $tobe_launched{$::p}, @{$malus_bubble{$::p}}) {
		$_ or next;
		$_->{img} = $bubbles_anim{lose};
		$_->{'x'}--;
		$_->{'y'}--;
	    }
	    iter_players_ {
		remove_hurry($::p_);
		@{$falling_bubble{$::p_}} = grep { !exists $_->{chaindestx} } @{$falling_bubble{$::p_}};
	    };
	    print_next_bubble($bubbles_anim{lose}, $::p, 1);
	    iter_players_ {
		@{$sticked_bubbles{$::p_}} = sort { $b->{'cx'}+$b->{'cy'}*10 <=> $a->{'cx'}+$a->{'cy'}*10 } @{$sticked_bubbles{$::p_}};
		$sticking_bubble{$::p_} = undef;
		$launched_bubble{$::p_} and destroy_bubbles($::p_, $launched_bubble{$::p_});
		$launched_bubble{$::p_} = undef;
		$pdata{$::p_}{newroot_prelight} = 0;
	    };
	    @{$malus_bubble{$::p}} = ();
	}
    };

    if (is_1p_game() && @{$sticked_bubbles{$PLAYERS[0]}} == 0) {
	put_image_to_background($imgbin{win_panel_1player}, $POS{centerpanel}{x}, $POS{centerpanel}{'y'});
	$pdata{state} = "won $PLAYERS[0]";
	$pdata{$PLAYERS[0]}{ping_right}{state} = 'win';
	$pdata{$PLAYERS[0]}{ping_right}{img} = 0;
	$levels{current} and $levels{current}++;
	if ($levels{current} && !$levels{$levels{current}}) {
	    $levels{current} = 'WON';
	    @{$falling_bubble{$PLAYERS[0]}} = @{$exploding_bubble{$PLAYERS[0]}} = ();
	    die 'quit';
	}
    }
}

sub print_hurry($;$) {
    my ($player, $dont_save_background) = @_;
    my $t = switch_image_on_background($imgbin{hurry}{$player}, $POS{$player}{left_limit} + $POS{hurry}{x}, $POS{hurry}{'y'}, 1);
    $dont_save_background or $pdata{$player}{hurry_save_img} = $t;
}
sub remove_hurry($) {
    my ($player) = @_;
    $pdata{$player}{hurry_save_img} and
      switch_image_on_background($pdata{$player}{hurry_save_img}, $POS{$player}{left_limit} + $POS{hurry}{x}, $POS{hurry}{'y'});
    $pdata{$player}{hurry_save_img} = undef;
}


#- ----------- mainloop helper --------------------------------------------

sub update_game() {

    if ($pdata{state} eq 'game') {
	handle_game_events();
	iter_players {
	    $actions{$::p}{left} and $angle{$::p} += $LAUNCHER_SPEED;
	    $actions{$::p}{right} and $angle{$::p} -= $LAUNCHER_SPEED;
	    if ($actions{$::p}{center}) {
		if ($angle{$::p} >= $PI/2 - $LAUNCHER_SPEED
		    && $angle{$::p} <= $PI/2 + $LAUNCHER_SPEED) {
		    $angle{$::p} = $PI/2;
		} else {
		    $angle{$::p} += ($angle{$::p} < $PI/2) ? $LAUNCHER_SPEED : -$LAUNCHER_SPEED;
		}
	    }
	    ($angle{$::p} < 0.1) and $angle{$::p} = 0.1;
	    ($angle{$::p} > $PI-0.1) and $angle{$::p} = $PI-0.1;
	    $pdata{$::p}{hurry}++;
	    if ($pdata{$::p}{hurry} > $TIME_HURRY_WARN) {
		my $oddness = odd(int(($pdata{$::p}{hurry}-$TIME_HURRY_WARN)/(500/$TARGET_ANIM_SPEED))+1);
		if ($pdata{$::p}{hurry_oddness} xor $oddness) {
		    if ($oddness) {
			play_sound('hurry');
			print_hurry($::p);
		    } else {
			remove_hurry($::p)
		    }
		}
		$pdata{$::p}{hurry_oddness} = $oddness;
	    }

	    if (($actions{$::p}{fire} || $pdata{$::p}{hurry} == $TIME_HURRY_MAX)
		&& !$launched_bubble{$::p}
		&& !(any { exists $_->{chaindestx} } @{$falling_bubble{$::p}})
		&& !@{$malus_bubble{$::p}}) {
		play_sound('launch');
		$launched_bubble{$::p} = $tobe_launched{$::p};
		$launched_bubble{$::p}->{direction} = $angle{$::p};
		$tobe_launched{$::p} = undef;
		$actions{$::p}{fire} = 0;
		$actions{$::p}{hadfire} = 1;
		$pdata{$::p}{hurry} = 0;
		remove_hurry($::p);
	    }

	    if ($launched_bubble{$::p}) {
		$launched_bubble{$::p}->{'x_old'} = $launched_bubble{$::p}->{'x'}; # save coordinates for potential collision
		$launched_bubble{$::p}->{'y_old'} = $launched_bubble{$::p}->{'y'};
		$launched_bubble{$::p}->{'x'} += $BUBBLE_SPEED * cos($launched_bubble{$::p}->{direction});
		$launched_bubble{$::p}->{'y'} -= $BUBBLE_SPEED * sin($launched_bubble{$::p}->{direction});
		if ($launched_bubble{$::p}->{x} < $POS{$::p}{left_limit}) {
		    play_sound('rebound');
		    $launched_bubble{$::p}->{x} = 2 * $POS{$::p}{left_limit} - $launched_bubble{$::p}->{x};
		    $launched_bubble{$::p}->{direction} -= 2*($launched_bubble{$::p}->{direction}-$PI/2);
		}
		if ($launched_bubble{$::p}->{x} > $POS{$::p}{right_limit} - $BUBBLE_SIZE) {
		    play_sound('rebound');
		    $launched_bubble{$::p}->{x} = 2 * ($POS{$::p}{right_limit} - $BUBBLE_SIZE) - $launched_bubble{$::p}->{x};
		    $launched_bubble{$::p}->{direction} += 2*($PI/2-$launched_bubble{$::p}->{direction});
		}
		if ($launched_bubble{$::p}->{'y'} <= $POS{top_limit} + $pdata{$::p}{newrootlevel} * $ROW_SIZE) {
		    my ($cx, $cy) = get_array_closest_pos($launched_bubble{$::p}->{x}, $launched_bubble{$::p}->{'y'}, $::p);
		    stick_bubble($launched_bubble{$::p}, $cx, $cy, $::p, 1);
		    $launched_bubble{$::p} = undef;
		} else {
		    foreach (@{$sticked_bubbles{$::p}}) {
			if (is_collision($launched_bubble{$::p}, $_->{'x'}, $_->{'y'})) {
			    my ($cx, $cy) = get_array_closest_pos(($launched_bubble{$::p}->{'x_old'}+$launched_bubble{$::p}->{'x'})/2,
								  ($launched_bubble{$::p}->{'y_old'}+$launched_bubble{$::p}->{'y'})/2,
								  $::p);
			    stick_bubble($launched_bubble{$::p}, $cx, $cy, $::p, 1);
			    $launched_bubble{$::p} = undef;

			    #- malus generation
			    if (!any { $_->{chaindestx} } @{$falling_bubble{$::p}}) {
				$pdata{$::p}{malus} > 0 and play_sound('malus');
				while ($pdata{$::p}{malus} > 0 && @{$malus_bubble{$::p}} < 7) {
				    my $b = create_bubble($::p);
				    do {
					$b->{'cx'} = int(rand(7));
				    } while (member($b->{'cx'}, map { $_->{'cx'} } @{$malus_bubble{$::p}}));
				    $b->{'cy'} = 12;
				    $b->{'stick_y'} = 0;
				    foreach (@{$sticked_bubbles{$::p}}) {
					if ($_->{'cy'} > $b->{'stick_y'}) {
					    if ($_->{'cx'} == $b->{'cx'}
						|| odd($_->{'cy'}+$pdata{$::p}{oddswap}) && ($_->{'cx'}+1) == $b->{'cx'}) {
						$b->{'stick_y'} = $_->{'cy'};
					    }
					}
				    }
				    $b->{'stick_y'}++;
				    calc_real_pos($b, $::p);
				    push @{$malus_bubble{$::p}}, $b;
				    malus_change(-1, $::p);
				}
				#- sort them and shift them
				@{$malus_bubble{$::p}} = sort { $a->{'cx'} <=> $b->{'cx'} } @{$malus_bubble{$::p}};
				my $shifting = 0;
				$_->{'y'} += ($shifting+=7)+int(rand(20)) foreach @{$malus_bubble{$::p}};
			    }

			    last;
			}
		    }
		}
	    }

	    !$tobe_launched{$::p} and generate_new_bubble($::p);

	    if (!$actions{$::p}{left} && !$actions{$::p}{right} && !$actions{$::p}{hadfire}) {
		$pdata{$::p}{sleeping}++;
	    } else {
		$pdata{$::p}{sleeping} = 0;
		$pdata{$::p}{ping_right}{movelatency} = -20;
	    }
	    if ($pdata{$::p}{sleeping} > $TIMEOUT_PINGUIN_SLEEP) {
		$pdata{$::p}{ping_right}{state} = 'sleep';
	    } elsif ($pdata{$::p}{ping_right}{state} eq 'sleep') {
		$pdata{$::p}{ping_right}{state} = 'normal';
	    }
	    if ($pdata{$::p}{ping_right}{state} eq 'right' && !($actions{$::p}{right})
		|| $pdata{$::p}{ping_right}{state} eq 'left' && !($actions{$::p}{left})
		|| $pdata{$::p}{ping_right}{state} eq 'action' && ($pdata{$::p}{ping_right}{actionlatency}++ > 5)) {
		$pdata{$::p}{ping_right}{state} = 'normal';
	    }
	    $actions{$::p}{right} and $pdata{$::p}{ping_right}{state} = 'right';
	    $actions{$::p}{left} and $pdata{$::p}{ping_right}{state} = 'left';
	    if ($actions{$::p}{hadfire}) {
		$pdata{$::p}{ping_right}{state} = 'action';
		$actions{$::p}{hadfire} = 0;
		$pdata{$::p}{ping_right}{actionlatency} = 0;
	    }
	    if ($pdata{$::p}{ping_right}{state} eq 'normal' && ($pdata{$::p}{ping_right}{movelatency}++ > 10)) {
		$pdata{$::p}{ping_right}{movelatency} = 0;
		rand() < 0.4 and $pdata{$::p}{ping_right}{img} = int(rand(@{$pinguin{$::p}{normal}}));
	    }

	    if ($pdata{$::p}{ping_right}{img} >= @{$pinguin{$::p}{$pdata{$::p}{ping_right}{state}}}) {
		$pdata{$::p}{ping_right}{img} = 0;
	    }
	};

	verify_if_end();

    } elsif ($pdata{state} =~ /lost (.*)/) {
	my $lost_slowdown if 0;  #- ``if 0'' is Perl's way of doing what C calls ``static local variables''
	if ($lost_slowdown++ > 1) {
	    $lost_slowdown = 0;
	    iter_players {
		if ($::p eq $1) {
		    if (@{$sticked_bubbles{$::p}}) {
			my $b = shift @{$sticked_bubbles{$::p}};
			put_image_to_background($bubbles_anim{lose}, --$b->{'x'}, --$b->{'y'});
	#		my $line = $b->{'cy'};
	#		while (@{$sticked_bubbles{$::p}} && ${$sticked_bubbles{$::p}}[0]->{'cy'} == $line) {
	#		    my $b = shift @{$sticked_bubbles{$::p}};
	#		    put_image_to_background($bubbles_anim{lose}, --$b->{'x'}, --$b->{'y'});
	#		}

			if (@{$sticked_bubbles{$::p}} == 0) {
			    $graphics_level == 1 and put_image($imgbin{win}{$::p eq 'p1' ? 'p2' : 'p1'}, $POS{centerpanel}{x}, $POS{centerpanel}{'y'});
			    if (is_1p_game()) {
				put_image($imgbin{lose}, $POS{centerpanel}{'x'}, $POS{centerpanel}{'y'});
				play_sound('noh');
			    }
			}

			if (!@{$sticked_bubbles{$::p}}) {
			    $event->pump while $event->poll != 0;
			}
		    } else {
			$event->pump;
			die 'new_game' if $event->poll != 0 && $event->type == SDL_KEYDOWN;
		    }
		} else {
		    if (@{$sticked_bubbles{$::p}} && $graphics_level > 1) {
			my $b = shift @{$sticked_bubbles{$::p}};
			destroy_bubbles($::p, $b);
			remove_image_from_background($b->{img}, $b->{'x'}, $b->{'y'});
			#- be sure to redraw at least upper line
			foreach (@{$b->{neighbours}}) {
			    next if !member($_, @{$sticked_bubbles{$::p}});
			    put_image_to_background($_->{img}, $_->{'x'}, $_->{'y'});
			}
		    }
		}
	    };

	}

    } elsif ($pdata{state} =~ /won (.*)/) {
	if (@{$exploding_bubble{$1}} == 0) {
	    $event->pump;
	    die 'new_game' if $event->poll != 0 && $event->type == SDL_KEYDOWN;
	}

    } else {
	die "oops unhandled game state ($pdata{state})\n";
    }


    #- things that need to be updated in all states of the game
    iter_players {
	my $malus_end = [];
	foreach my $b (@{$malus_bubble{$::p}}) {
	    $b->{'y'} -= $MALUS_BUBBLE_SPEED;
	    if (get_array_yclosest($b->{'y'}) <= $b->{'stick_y'}) {
		real_stick_bubble($b, $b->{'cx'}, $b->{'stick_y'}, $::p, 0);
		push @$malus_end, $b;
	    }
	}
	@$malus_end and @{$malus_bubble{$::p}} = difference2($malus_bubble{$::p}, $malus_end);

	my $falling_end = [];
	foreach my $b (@{$falling_bubble{$::p}}) {
	    if ($b->{wait_fall}) {
		$b->{wait_fall}--;
	    } else {
		if (exists $b->{chaindestx} && ($b->{'y'} > 375 || $b->{chaingoingup})) {
		    my $acceleration = $FREE_FALL_CONSTANT*3;
		    if (!$b->{chaingoingup}) {
			my $time_to_zero = $b->{speed}/$acceleration;
			my $distance_to_zero = $b->{speed} * ($b->{speed}/$acceleration + 1) / 2;
			my $time_to_destination = (-1 + sqrt(1 + 8/$acceleration*($b->{'y'}-$b->{chaindesty}+$distance_to_zero))) / 2;
			$b->{speedx} = ($b->{chaindestx} - $b->{x}) / ($time_to_zero + $time_to_destination);
			$b->{chaingoingup} = 1;
		    }
		    $b->{speed} -= $acceleration;
		    $b->{x} += $b->{speedx};
		    if (abs($b->{x} - $b->{chaindestx}) < abs($b->{speedx})) {
			$b->{'x'} = $b->{chaindestx};
			$b->{speedx} = 0;
		    }
		    $b->{'y'} += $b->{speed};
		    $b->{'y'} < $b->{chaindesty} and push @$falling_end, $b;
		} else {
		    $b->{'y'} += $b->{speed};
		    $b->{speed} += $FREE_FALL_CONSTANT;
		}
	    }
	    $b->{'y'} > 470 && !exists $b->{chaindestx} and push @$falling_end, $b;
	}
	@$falling_end and @{$falling_bubble{$::p}} = difference2($falling_bubble{$::p}, $falling_end);
	foreach (@$falling_end) {
	    exists $_->{chaindestx} or next;
	    @{$chains{$::p}{falling_chained}} = difference2($chains{$::p}{falling_chained}, [ $_ ]);
	    delete $chains{$::p}{chained_bubbles}{$_};
	    stick_bubble($_, $_->{chaindestcx}, $_->{chaindestcy}, $::p, 0);
	}

	my $exploding_end = [];
	foreach my $b (@{$exploding_bubble{$::p}}) {
	    $b->{'x'} += $b->{speedx};
	    $b->{'y'} += $b->{speedy};
	    $b->{speedy} += $FREE_FALL_CONSTANT;
	    push @$exploding_end, $b if $b->{'y'} > 470;
	}
	if (@$exploding_end) {
	    @{$exploding_bubble{$::p}} = difference2($exploding_bubble{$::p}, $exploding_end);
	    if ($pdata{state} =~ /lost (.*)/ && $::p ne $1 && !is_1p_game()
		&& !@{$exploding_bubble{$::p}} && !@{$sticked_bubbles{$::p}}) {
		put_image($imgbin{win}{$::p}, $POS{centerpanel}{'x'}, $POS{centerpanel}{'y'});
	    }
	}

	if (member($pdata{$::p}{ping_right}{state}, qw(win lose)) && ($pdata{$::p}{ping_right}{movelatency}++ > 5)) {
	    my $state = $pdata{$::p}{ping_right}{state};
	    $pdata{$::p}{ping_right}{movelatency} = 0;
	    $pdata{$::p}{ping_right}{img}++;
	    $pdata{$::p}{ping_right}{img} == @{$pinguin{$::p}{$state}}
	      and $pdata{$::p}{ping_right}{img} = $pinguin{$::p}{"$state".'_roll_back_index'};
	}

    };

    #- advance playlist when the current song finished
    $mixer_enabled && $mixer && @playlist && !$mixer->playing_music and play_music('dummy', 0);
}

#- ----------- init stuff -------------------------------------------------

sub restart_app() {
    $app = SDL::App->new(-flags => $sdl_flags | ($fullscreen ? SDL_FULLSCREEN : 0), -title => 'Frozen-Bubble', -width => 640, -height => 480);
}

sub print_step($) {
    my ($txt) = @_;
    print $txt;
    my $step if 0; $step ||= 0;
    put_image($imgbin{loading_step}, 100 + $step*12, 10);
    $app->flip;
    $step++;
}

sub load_levelset {
    my ($levelset_name) = @_;

    -e $levelset_name or die "No such levelset ($levelset_name).\n";

    $loaded_levelset = $levelset_name;
    my $row_numb = 0;
    my $curr_level = $levels{current};

    %levels = ();
    $levels{current} = $curr_level;
    $lev_number = 1;

    foreach my $line (cat_($levelset_name)) {
	if ($line !~ /\S/) {
	    if ($row_numb) {
		$lev_number++;
		$row_numb = 0;
	    }
	} else {
	    my $col_numb = 0;
	    foreach (split ' ', $line) {
		/-/ or push @{$levels{$lev_number}}, { cx => $col_numb, cy => $row_numb, img_num => $_ };
		$col_numb++;
	    }
	    $row_numb++;
	}
    }
}

sub init_game() {
    -r "$FPATH/$_" or die "[*ERROR*] the datafiles seem to be missing! (could not read `$FPATH/$_')\n".
                          "          The datafiles need to go to `$FPATH'.\n"
			    foreach qw(gfx snd data);

    print '[SDL Init] ';
    restart_app();
    $font = SDL::Font->new("$FPATH/gfx/font.png");
    $apprects{main} = SDL::Rect->new(-width => $app->width, -height => $app->height);
    $event = SDL::Event->new;
    $event->set_unicode(1);
    SDL::Cursor::show(0);
    $total_time = $app->ticks;
    $imgbin{loading} = add_image('loading.png');
    put_image($imgbin{loading}, 10, 10);
    $app->print(30, 60, uc("tip!  use '-h' on command-line to get more options"));
    $app->flip;
    $imgbin{loading_step} = add_image('loading_step.png');
 
    print_step('[Graphics');
    $imgbin{back_2p} = SDL::Surface->new(-name => "$FPATH/gfx/backgrnd.png");
    $imgbin{back_1p} = SDL::Surface->new(-name => "$FPATH/gfx/back_one_player.png");
    $background = SDL::Surface->new(-width => $app->width, -height => $app->height, -depth => 32, -Amask => '0 but true');
    $background_orig = SDL::Surface->new(-width => $app->width, -height => $app->height, -depth => 32, -Amask => '0 but true');
    $imgbin{backstartfull} = SDL::Surface->new(-name => "$FPATH/gfx/menu/back_start.png");

    print_step('.'); 
    add_bubble_image('balls/bubble-'.($colourblind && 'colourblind-')."$_.gif") foreach (1..8);
    $bubbles_anim{white} = add_image("balls/bubble_prelight.png");
    $bubbles_anim{lose} = add_image("balls/bubble_lose.png");
    $bubbles_anim{on_top_next} = add_image("on_top_next.png");
    push @{$bubbles_anim{stick}}, add_image("balls/stick_effect_$_.png") foreach (0..6);

    $shooter = add_image("shoot/shooter.png");
    $canon{img}{$_} = add_image("shoot/base_$_.png") foreach (-$CANON_ROTATIONS_NB..$CANON_ROTATIONS_NB);
    /(\S+) (\S+) (\S+)/ and $canon{data}{$1} = [ $2, $3 ] foreach cat_("$FPATH/gfx/shoot/data");  #- quantity of shifting needed (because of crop reduction)
    $malus_gfx{banane} = add_image('banane.png');
    $malus_gfx{tomate} = add_image('tomate.png');

    print_step('.'); 
    push @{$imgbin{paused}}, add_image("pause_$_.png") foreach 1..5;
    $imgbin{back_paused} = add_image('back_paused.png');
    $imgbin{lose} = add_image('lose_panel.png');
    $imgbin{win_panel_1player} = add_image('win_panel_1player.png');
    $imgbin{compressor_main} = add_image('compressor_main.png');
    $imgbin{compressor_ext} = add_image('compressor_ext.png');

    $imgbin{txt_1pgame_off}  = add_image('menu/txt_1pgame_off.png');
    $imgbin{txt_1pgame_over} = add_image('menu/txt_1pgame_over.png');
    $imgbin{txt_2pgame_off}  = add_image('menu/txt_2pgame_off.png');
    $imgbin{txt_2pgame_over} = add_image('menu/txt_2pgame_over.png');
    $imgbin{txt_editor_off}  = add_image('menu/txt_editor_off.png');
    $imgbin{txt_editor_over} = add_image('menu/txt_editor_over.png');
    $imgbin{txt_fullscreen_off}  = add_image('menu/txt_fullscreen_off.png');
    $imgbin{txt_fullscreen_over} = add_image('menu/txt_fullscreen_over.png');
    $imgbin{txt_fullscreen_act_off}  = add_image('menu/txt_fullscreen_act_off.png');
    $imgbin{txt_fullscreen_act_over} = add_image('menu/txt_fullscreen_act_over.png');
    $imgbin{txt_keys_off}  = add_image('menu/txt_keys_off.png');
    $imgbin{txt_keys_over} = add_image('menu/txt_keys_over.png');
    $imgbin{txt_sound_off}  = add_image('menu/txt_sound_off.png');
    $imgbin{txt_sound_over} = add_image('menu/txt_sound_over.png');
    $imgbin{txt_sound_act_off}  = add_image('menu/txt_sound_act_off.png');
    $imgbin{txt_sound_act_over} = add_image('menu/txt_sound_act_over.png');
    $imgbin{txt_graphics_1_off}  = add_image('menu/txt_graphics_1_off.png');
    $imgbin{txt_graphics_1_over} = add_image('menu/txt_graphics_1_over.png');
    $imgbin{txt_graphics_2_off}  = add_image('menu/txt_graphics_2_off.png');
    $imgbin{txt_graphics_2_over} = add_image('menu/txt_graphics_2_over.png');
    $imgbin{txt_graphics_3_off}  = add_image('menu/txt_graphics_3_off.png');
    $imgbin{txt_graphics_3_over} = add_image('menu/txt_graphics_3_over.png');
    $imgbin{txt_highscores_off}  = add_image('menu/txt_highscores_off.png');
    $imgbin{txt_highscores_over} = add_image('menu/txt_highscores_over.png');
    $imgbin{void_panel} = add_image('menu/void_panel.png');
    $imgbin{version} = add_image('menu/version.png');

    $imgbin{back_hiscores} = add_image('back_hiscores.png');
    $imgbin{hiscore_frame} = add_image('hiscore_frame.png');

    $imgbin{banner_artwork} = add_image('menu/banner_artwork.png');
    $imgbin{banner_soundtrack} = add_image('menu/banner_soundtrack.png');
    $imgbin{banner_cpucontrol} = add_image('menu/banner_cpucontrol.png');
    $imgbin{banner_leveleditor} = add_image('menu/banner_leveleditor.png');
    
    print_step('.'); 
    #- temporarily desactivate the intro storyboard because it's not finished yet
    #- $imgbin{frozen} = add_image('intro/txt_frozen.png');
    #- $imgbin{bubble} = add_image('intro/txt_bubble.png');
    #- $imgbin{intro_penguin_imgs}->{$_} = add_image("intro/intro_$_.png") foreach 1..19;

    local @PLAYERS = qw(p1 p2);  #- load all images even if -so commandline option was passed
    iter_players {
	$imgbin{hurry}{$::p} = add_image("hurry_$::p.png");
	$pinguin{$::p}{normal} = [ map { add_image($_) } ("pinguins/base_$::p.png", map { "pinguins/base_$::p"."_extra_0$_.png" } (1..3)) ];
	$pinguin{$::p}{sleep} = [ add_image("pinguins/sleep_$::p.png") ];
	$pinguin{$::p}{left} = [ add_image("pinguins/move_left_$::p.png") ];
	$pinguin{$::p}{right} = [ add_image("pinguins/move_right_$::p.png") ];
	$pinguin{$::p}{action} = [ add_image("pinguins/action_$::p.png") ];
	$pinguin{$::p}{win} = [ map { add_image("pinguins/$::p"."_win_$_.png") } qw(1 2 3 4 5 6 7 8 6) ];
	$pinguin{$::p}{win_roll_back_index} = 4;
	$pinguin{$::p}{lose} = [ map { add_image("pinguins/$::p"."_loose_$_.png") } qw(1 2 3 4 5 6 7 8 9) ];
	$pinguin{$::p}{lose_roll_back_index} = 5;
	$pinguin{$::p}{win} = [ map { add_image("pinguins/$::p"."_win_$_.png") } qw(1 2 3 4 5 6 7 8 6) ];
	$pinguin{$::p}{walkright} = [ map { add_image("pinguins/$::p"."_dg_walk_0$_.png") } qw(1 2 3 4 5 6) ];
	$imgbin{win}{$::p} = add_image("win_panel_$::p.png");
	$pdata{$::p}{score} = 0;
    };
    print_step('] '); 

    $lev_number = 0;
    print_step("[Levels] "); 
    load_levelset("$FPATH/data/levels");

    if ($mixer eq 'SOUND_DISABLED') {
	$mixer_enabled = $mixer = undef;
    } else {
	$mixer_enabled = init_sound();
    }

    fb_c_stuff::init_effects($FPATH);

    print "Ready.\n";
}

sub open_level($) {
    my ($level) = @_;

    $level eq 'WON' and $level = $lev_number;

    @{$levels{$level}} or die "No such level or void level ($level).\n";
    foreach my $l (@{$levels{$level}}) {
	iter_players {
	    my $img = $l->{img_num} =~ /^\d+$/ ? $bubbles_images[$l->{img_num}] : $bubbles_anim{lose};
	    real_stick_bubble(create_bubble_given_img($img), $l->{cx}, $l->{cy}, $::p, 0);
	};
    }
}

sub grab_key($) {
    my ($unicode) = @_;
    my $keyp;
    do {
	$event->wait;
	if ($event->type == SDL_KEYDOWN) {
	    $keyp = $unicode ? ($event->key_unicode || $event->key_sym) : $event->key_sym;
	}
    } while ($event->type != SDL_KEYDOWN);
    do { $event->wait } while ($event->type != SDL_KEYUP);
    return $keyp;
}

sub display_highscores() {

    $imgbin{back_hiscores}->blit($apprects{main}, $app, $apprects{main});

    $display_on_app_disabled = 1;
    @PLAYERS = ('p1');
    %POS = %POS_1P;
    $POS{top_limit} = $POS{init_top_limit};

    my $initial_high_posx = 90;
    my ($high_posx, $high_posy) = ($initial_high_posx, 68);
    my $high_rect = SDL::Rect->new('-x' => $POS{p1}{left_limit} & 0xFFFFFFFC, '-y' => $POS{top_limit} & 0xFFFFFFFC,
				   '-width' => ($POS{p1}{right_limit}-$POS{p1}{left_limit}) & 0xFFFFFFFC, -height => ($POS{'initial_bubble_y'}-$POS{top_limit}-10) & 0xFFFFFFFC);

    $font = SDL::Font->new("$FPATH/gfx/font-hi.png");
    my $centered_print = sub($$$) {
	my ($x, $y, $txt) = @_;
	$app->print($x+($imgbin{hiscore_frame}->width-SDL_TEXTWIDTH(uc($txt)))/2 - 6,
		    $y+$imgbin{hiscore_frame}->height - 8, uc($txt));
    };

    my $old_levelset = $loaded_levelset;

    foreach my $high (ordered_highscores()) {
	iter_players {
	    @{$sticked_bubbles{$::p}} = ();
	    @{$root_bubbles{$::p}} = ();
	    $pdata{$::p}{newrootlevel} = 0;
	    $pdata{$::p}{oddswap} = 0;
	};
	$imgbin{back_1p}->blit($high_rect, $background, $high_rect);

	# try to get it from the default-levelset. If we can't, default to the
	# last level in the default levelset
	if (!$high->{piclevel}) {
	    $loaded_levelset ne "$FPATH/data/levels" and load_levelset("$FPATH/data/levels");
        
	    # handle the case where the user has edited/created a levelset with more levels
	    # than the default levelset and then got a high score
	    if ($high->{level} > $lev_number) {
		open_level($lev_number);
	    } else {
		open_level($high->{level});
	    }
	} else {
	    # this is the normal case. just load the level that the file tells us
	    if ($loaded_levelset ne "$ENV{HOME}/.fbhighlevelshistory") {
		load_levelset("$ENV{HOME}/.fbhighlevelshistory");
	    }
	    open_level($high->{piclevel});
	}

	put_image($imgbin{hiscore_frame}, $high_posx - 7, $high_posy - 6);
	fb_c_stuff::shrink($app->{-surface}, $background->display_format->{-surface}, $high_posx, $high_posy, $high_rect->{-rect}, 4);
	$centered_print->($high_posx, $high_posy,    $high->{name});
	$centered_print->($high_posx, $high_posy+20, $high->{level} eq 'WON' ? "WON!" : "LVL-".$high->{level});
	my $min = int($high->{time}/60);
	my $sec = int($high->{time} - $min*60); length($sec) == 1 and $sec = "0$sec";
	$centered_print->($high_posx, $high_posy+40, "$min'$sec''");
	$high_posx += 98;
	$high_posx > 550 and $high_posx = $initial_high_posx, $high_posy += 175;
	$high_posy > 440 and last;
    }
    load_levelset($old_levelset);
    $app->flip;
    $display_on_app_disabled = 0;

    $font = SDL::Font->new("$FPATH/gfx/font.png");
    $event->pump while ($event->poll != 0);
    grab_key(0);
}

sub keysym_to_char($) { my ($key) = @_; eval("$key eq SDLK_$_") and return uc($_) foreach @fbsyms::syms }

sub ask_from($) {
    my ($w) = @_;
    # $w->{intro} = [ 'text_intro_line1', 'text_intro_line2', ... ]
    # $w->{entries} = [ { q => 'question1?', a => \$var_answer1, f => 'flags' }, {...} ]   flags: ONE_CHAR
    # $w->{outro} = 'text_outro_uniline'
    # $w->{erase_background} = $background_right_one

    my $xpos_panel = (640-$imgbin{void_panel}->width)/2;
    my $ypos_panel = (480-$imgbin{void_panel}->height)/2;
    put_image($imgbin{void_panel}, $xpos_panel, $ypos_panel);

    my $xpos;
    my $ypos = $ypos_panel + 5;

    foreach my $i (@{$w->{intro}}) {
	if ($i) {
	    my $xpos = (640-SDL_TEXTWIDTH($i))/2;
	    $app->print($xpos, $ypos, $i);
	}
	$ypos += 22;
    }

    $ypos += 3;

    my $ok = 1;
  entries:
    foreach my $entry (@{$w->{entries}}) {
	$xpos = (640-$imgbin{void_panel}->width)/2 + 120 - SDL_TEXTWIDTH($entry->{'q'})/2;
	$app->print($xpos, $ypos, $entry->{'q'});
	$app->flip;
	my $srect_mulchar_redraw = SDL::Rect->new(-width => $imgbin{void_panel}->width, -height => 30,
						 -x => $xpos + 140 - $xpos_panel, '-y' => $ypos - $ypos_panel);
	my $drect_mulchar_redraw = SDL::Rect->new(-width => $imgbin{void_panel}->width, -height => 30,
						 -x => $xpos + 140, '-y' => $ypos);
	my $txt;
	while (1) {
	    my $k = grab_key($entry->{f} !~ 'ONE_CHAR');
	    $k == SDLK_ESCAPE and $ok = 0, last entries;
	    play_sound('typewriter');
	    if ($entry->{f} =~ 'ONE_CHAR' || $k != SDLK_RETURN) {
		my $x_echo = (640-$imgbin{void_panel}->width)/2 + 230;
		if ($entry->{f} =~ 'ONE_CHAR') {
		    $txt = $k;
		    $app->print($x_echo, $ypos, keysym_to_char($k));
		} else {
		    $k = keysym_to_char($k);
		    length($k) == 1 && length($txt) < 8 and $txt .= $k;
		    member($k, qw(BACKSPACE DELETE LEFT)) and $txt =~ s/.$//;
		    $imgbin{void_panel}->blit($srect_mulchar_redraw, $app, $drect_mulchar_redraw);
		    $app->print($x_echo, $ypos, $txt);
		}
		$app->flip;
	    }
	    $entry->{f} =~ 'ONE_CHAR' || $k == SDLK_RETURN and last;
	}
	$entry->{answer} = $txt;
	$ypos += 22;
    }

    if ($ok) {
	${$_->{a}} = $_->{answer} foreach @{$w->{entries}};
	$xpos = (640-SDL_TEXTWIDTH($w->{outro}))/2;
	$ypos = (480+$imgbin{void_panel}->height)/2 - 35;
	$app->print($xpos, $ypos, $w->{outro});
	$app->flip;
	play_sound('menu_selected');
	sleep 1;
    } else {
	play_sound('cancel');
    }

    exists $w->{erase_background} and erase_image_from($imgbin{void_panel}, $xpos_panel, $ypos_panel, $w->{erase_background});
    $app->flip;
    $event->pump while ($event->poll != 0);
}

sub new_game() {

    $display_on_app_disabled = 1;

    my $backgr;
    if (is_2p_game()) {
	$backgr = $imgbin{back_2p};
	%POS = %POS_2P;
	$TIME_APPEARS_NEW_ROOT = 11;
	$TIME_HURRY_WARN = 250;
	$TIME_HURRY_MAX = 375;
    } elsif (is_1p_game()) {
	$backgr = $imgbin{back_1p};
	%POS = %POS_1P;
	$TIME_APPEARS_NEW_ROOT = 8;
	$TIME_HURRY_WARN = 400;
	$TIME_HURRY_MAX = 525;
	$POS{top_limit} = $POS{init_top_limit};
	$pdata{$PLAYERS[0]}{score} = $levels{current} || "RANDOM";
    } else {
	die "oops";
    }

    $backgr->blit($apprects{main}, $background_orig, $apprects{main});
    $background_orig->blit($apprects{main}, $background, $apprects{main});

    iter_players {
	$actions{$::p}{$_} = 0 foreach qw(left right fire center);
	$angle{$::p} = $PI/2;
	@{$sticked_bubbles{$::p}} = ();
	@{$malus_bubble{$::p}} = ();
	@{$root_bubbles{$::p}} = ();
	@{$falling_bubble{$::p}} = ();
	@{$exploding_bubble{$::p}} = ();
	@{$chains{$::p}{falling_chained}} = ();
	%{$chains{$::p}{chained_bubbles}} = ();
	$launched_bubble{$::p} = undef;
	$sticking_bubble{$::p} = undef;
	$pdata{$::p}{$_} = 0 foreach qw(newroot newroot_prelight oddswap malus hurry newrootlevel);
	$pdata{$::p}{ping_right}{img} = 0;
	$pdata{$::p}{ping_right}{state} = 'normal';
	$apprects{$::p} = SDL::Rect->new('-x' => $POS{$::p}{left_limit}, '-y' => $POS{top_limit},
					 -width => $POS{$::p}{right_limit}-$POS{$::p}{left_limit}, -height => $POS{'initial_bubble_y'}-$POS{top_limit});
    };
    print_scores($background);

    is_1p_game() and print_compressor();

    if ($levels{current}) {
	open_level($levels{current});
    } else {
	foreach my $cy (0 .. 4) {
	    foreach my $cx (0 .. (6 + even($cy))) {
		my $b = create_bubble();
		real_stick_bubble($b, $cx, $cy, $PLAYERS[0], 0);  #- this doesn't map well to the 'iter_players' subroutine..
		is_2p_game() and real_stick_bubble(create_bubble_given_img($b->{img}), $cx, $cy, $PLAYERS[1], 0);
	    }
	}
    }

    $next_bubble{$PLAYERS[0]} = create_bubble($PLAYERS[0]);
#    $next_bubble{$PLAYERS[0]} = create_bubble_given_img($bubbles_images[5]);
    generate_new_bubble($PLAYERS[0]);
    if (is_2p_game()) {
	$next_bubble{$PLAYERS[1]} = create_bubble_given_img($tobe_launched{$PLAYERS[0]}->{img});
	generate_new_bubble($PLAYERS[1], $next_bubble{$PLAYERS[0]}->{img});
    }

    if ($graphics_level == 1) {
	$background->blit($apprects{main}, $app, $apprects{main});
	$app->flip;
    } else {
	fb_c_stuff::effect($app->{-surface}, $background->display_format->{-surface});
    }

    $display_on_app_disabled = 0;

    $event->pump while ($event->poll != 0);
    $pdata{state} = 'game';
}

sub new_game_once() {
    is_1p_game() && $levels{current} and choose_levelset();
    if (is_2p_game() && $graphics_level > 1) {
	my $answ;
	ask_from({ intro => [ '2-PLAYER GAME', '', '', 'ENABLE CHAIN-REACTION?', '' ],
		   entries => [ { 'q' => 'Y OR N?', 'a' => \$answ, f => 'ONE_CHAR' } ],
		   outro => 'ENJOY THE GAME!' });
	$chainreaction = $answ == SDLK_y; #;;
    }
    play_music(is_1p_game() ? 'main1p' : 'main2p');
}

sub lvl_cmp($$) { $_[0] eq 'WON' ? ($_[1] eq 'WON' ? 0 : 1) : ($_[1] eq 'WON' ? -1 : $_[0] <=> $_[1]) }

sub ordered_highscores() { return sort { lvl_cmp($b->{level}, $a->{level}) || $a->{time} <=> $b->{time} } @$HISCORES }

sub handle_new_hiscores() {
    is_1p_game() && $levels{current} or return;

    my @ordered = ordered_highscores();
    my $worst = pop @ordered;

    my $total_seconds = ($app->ticks - $time_1pgame)/1000;

    if (@$HISCORES == 10 && (lvl_cmp($levels{current}, $worst->{level}) == -1
			     || lvl_cmp($levels{current}, $worst->{level}) == 0 && $total_seconds > $worst->{time})) {
	return;
    }

    play_sound('applause');
    append_highscore_level();

    my %new_entry;
    $new_entry{level} = $levels{current};
    $new_entry{time} = $total_seconds;
    $new_entry{piclevel} = count_highscorehistory_levels();
    ask_from({ intro => [ 'CONGRATULATIONS!', "YOU HAVE A HIGHSCORE!", '' ],
	       entries => [ { 'q' => 'YOUR NAME?', 'a' => \$new_entry{name} } ],
	       outro => 'GREAT GAME!',
	       erase_background => $background,
	     });

    return if $new_entry{name} eq '';

    push @$HISCORES, \%new_entry;
    if (@$HISCORES == 11) {
	my @high = ordered_highscores();
	pop @high;
	$HISCORES = \@high;
    }

    output($hiscorefile, Data::Dumper->Dump([$HISCORES], [qw(HISCORES)]));
    display_highscores();
}

# append the new highscore to the .fbhighlevelshistory
sub append_highscore_level() {

    my $row_numb = 0;
    my $lvl = 1;

    my @contents;

    foreach my $line (cat_($loaded_levelset)) {
	if ($line !~ /\S/) {
	    if ($row_numb) {
		$lvl++;
		$row_numb = 0;
            } 
        } else {
            $row_numb++;
            $lvl == ($levels{current} eq 'WON' ? (keys %levels)-1 : $levels{current})
	      and push @contents, $line;
        }
    }

    append_to_file("$ENV{HOME}/.fbhighlevelshistory", @contents, "\n\n");
}

sub count_highscorehistory_levels() {
    my $cnt = 0;
    my $row_numb = 0;
    foreach my $line (cat_("$ENV{HOME}/.fbhighlevelshistory")) {
	if ($line !~ /\S/) {
	    if ($row_numb) {
		$cnt++;
		$row_numb = 0;
            } 
        } else {
            $row_numb++;
        }
    }
    return $cnt;
} 


#- ----------- mainloop ---------------------------------------------------

sub maingame() {
    my $synchro_ticks = $app->ticks;

    handle_graphics(\&erase_image);
    update_game();
    handle_graphics(\&put_image);

    $app->update(@update_rects);
    @update_rects = ();

    my $to_wait = $TARGET_ANIM_SPEED - ($app->ticks - $synchro_ticks);
    $to_wait > 0 and fb_c_stuff::fbdelay($to_wait);
}


#- ----------- intro stuff ------------------------------------------------

sub intro() {

    my %storyboard = (
		      sleeping => {
				   start => { type => 'time', value => 0 },
				   type => 'penguin',
				   animations => [ qw(1 2 3 4 5 6 7 6 5 4 3 2) ],
				  },
		      music => { start => { type => 'time', value => 1 } },
		      bubble_fall1 => { start => { type => 'synchro', value => 0x01 },
					type => 'bubble_falling', img => 2, xpos => 200, xaccel => -1.5 },
		      bubble_fall2 => { start => { type => 'synchro', value => 0x02 },
					type => 'bubble_falling', img => 3, xpos => 350, xaccel => 1 },
		      bubble_fall3 => { start => { type => 'synchro', value => 0x03 },
					type => 'bubble_falling', img => 4, xpos => 400, xaccel => 2 },
		      eyes_moving => {
				      start => { type => 'synchro', value => 0x21 },
				      type => 'penguin',
				      animations => [ qw(8 9 10 11 12 11 10 9) ],
				  },
		      arms_moving => {
				      start => { type => 'synchro', value => 0x22 },
				      type => 'penguin',
				      animations => [ qw(12 13 14 15 14 13) ],
				  },
		      fear => {
			       start => { type => 'synchro', value => 0x31 },
			       type => 'penguin',
			       animations => [ qw(15 16 17 18 19 18 17 16) ],
			      },
		      txt_frozen_arriving => {
					      start => { type => 'synchro', value => 0x31 },
					      type => 'bitmap_animation',
					      img => $imgbin{frozen},
					      finalpos => { x => 300, 'y' => 100 },
					      factor => 1,
					     },
		      txt_bubble_arriving => {
					      start => { type => 'synchro', value => 0x32 },
					      type => 'bitmap_animation',
					      img => $imgbin{bubble},
					      finalpos => { x => 340, 'y' => 155 },
					      factor => 4,
					     },
		     );

    my %sb_params = (
		     animation_speed => 20
		    );


    my $start_menu;
    my ($slowdown_number, $slowdown_frame);

    return menu(0);   #- temporarily desactivate the intro storyboard because it's not finished yet

    if ($mixer_enabled && $mixer) {
	play_music('intro');
	$mixer->pause_music;
	my $back_start = SDL::Surface->new(-name => "$FPATH/intro/back_intro.png");
	$back_start->blit($apprects{main}, $app, $apprects{main});
	$app->flip;

	my $penguin;
	my @bubbles_falling;
	my @bitmap_animations;

	my $anim_step = -1;
	my $start_time = $app->ticks;
	my $current_time = $start_time;

	while (!$start_menu) {
	    my $synchro_ticks = $app->ticks;

	    my $current_time_ = int(($app->ticks - $start_time)/1000);
	    my $anim_step_ = fb_c_stuff::get_synchro_value();

	    if ($anim_step_ != $anim_step || $current_time_ != $current_time) {
		$anim_step = $anim_step_;
		$current_time = $current_time_;
		printf "Anim step: %12s Time: <$current_time>\n", sprintf "<0x%02x>", $anim_step;

		foreach my $evt (keys %storyboard) {
		    next if $storyboard{$evt}->{already};
		    if ($storyboard{$evt}->{start}->{type} eq 'time' && $storyboard{$evt}->{start}->{value} <= $current_time
			|| $storyboard{$evt}->{start}->{type} eq 'synchro' && $storyboard{$evt}->{start}->{value} eq $anim_step) {
			$storyboard{$evt}->{already} = 1;
			print "*** Starting <$evt>\n";
			$evt eq 'music' and $mixer->resume_music;
			if ($storyboard{$evt}->{type} eq 'penguin') {
			    $penguin = { animations => $storyboard{$evt}->{animations},
					 current_anim => 0,
					 anim_step => $sb_params{animation_speed} };
			}
			if ($storyboard{$evt}->{type} eq 'bubble_falling') {
			    push @bubbles_falling, { img => $bubbles_images[$storyboard{$evt}->{img}], 'y' => 0, speed => 3,
						     x => $storyboard{$evt}->{xpos}, xaccel => $storyboard{$evt}->{xaccel} };
			}
			if ($storyboard{$evt}->{type} eq 'bitmap_animation') {
			    push @bitmap_animations, { img => $storyboard{$evt}->{img}, 'y' => 0,
						       x => $storyboard{$evt}->{finalpos}->{x},
						       finaly => $storyboard{$evt}->{finalpos}->{'y'},
						       factor => $storyboard{$evt}->{factor},
						     };
			}
		    }
		}

		$anim_step == 0x09 and $start_menu = 1;
	    }

	    if ($penguin) {
		$penguin->{anim_step}++;
		if ($penguin->{anim_step} >= $sb_params{animation_speed}) {
		    my $img_number = ${$penguin->{animations}}[$penguin->{current_anim}];
		    erase_image_from($imgbin{intro_penguin_imgs}->{$img_number}, 260, 293, $back_start);
		    $penguin->{anim_step} = 0;
		    $penguin->{current_anim}++;
		    $penguin->{current_anim} == @{$penguin->{animations}} and $penguin->{current_anim} = 0;
		    $img_number = ${$penguin->{animations}}[$penguin->{current_anim}];
		    put_image($imgbin{intro_penguin_imgs}->{$img_number}, 260, 293);
		}
	    }

	    foreach my $b (@bubbles_falling) {
		erase_image_from($b->{img}, $b->{x}, $b->{'y'}, $back_start);
		$b->{'x'} += $b->{xaccel};
		$b->{'y'} += $b->{speed};
		if ($b->{'y'} >= 360 && !$b->{already_rebound}) {
		    $b->{already_rebound} = 1;
		    $b->{'y'} = 2*360 - $b->{'y'};
		    $b->{speed} *= -0.5;
		}
		$b->{speed} += $FREE_FALL_CONSTANT;
		$b->{kill} = $b->{'y'} > 470;
		$b->{kill} or put_image($b->{img}, $b->{x}, $b->{'y'});
	    }
	    @bubbles_falling = grep { !$_->{kill} } @bubbles_falling;

	    erase_image_from($_->{img}, $_->{x}, $_->{'y'}, $back_start) foreach @bitmap_animations;
	    foreach my $b (@bitmap_animations) {
		foreach (0..$slowdown_frame) {
		    $b->{'y'} = $b->{'finaly'} - 200*cos(3*$b->{step})/exp($b->{step}*$b->{step});
		    $b->{step} += 0.015 * $b->{factor};
		}
	    }
	    $slowdown_frame = 0;
	    put_image($_->{img}, $_->{x}, $_->{'y'}) foreach @bitmap_animations;

	    $app->update(@update_rects);
	    @update_rects = ();

	    my $to_wait = $TARGET_ANIM_SPEED - ($app->ticks - $synchro_ticks);
	    if ($to_wait > 0) {
		$app->delay($to_wait);
	    } else {
#		print "slow by: <$to_wait>\n";
		$slowdown_number += -$to_wait;
		if ($slowdown_number > $TARGET_ANIM_SPEED) {
		    $slowdown_frame = int($slowdown_number / $TARGET_ANIM_SPEED);
		    $slowdown_number -= $slowdown_frame * $TARGET_ANIM_SPEED;
#		    print "skip frames: <$slowdown_frame>\n";
		}
	    }

	    $event->pump;
	    $event->poll != 0 && $event->type == SDL_KEYDOWN && member($event->key_sym, (SDLK_RETURN, SDLK_SPACE, SDLK_KP_ENTER, SDLK_ESCAPE))
		and $start_menu = 2;

	}
    }


#    if ($start_menu == 1) {
#	my $bkg = SDL::Surface->new(-width => $app->width, -height => $app->height, -depth => 32, -Amask => '0 but true');
#	$app->blit($apprects{main}, $bkg, $apprects{main});
#	menu(1, $bkg);
#    } else {
	menu(1);
#    }
}


#- ----------- menu stuff -------------------------------------------------

sub menu {
    my ($from_intro, $back_from_intro) = @_;

    handle_new_hiscores();

    if (!$from_intro) {
	play_music('intro', 8);
    }

    my $back_start;
    my $display_menu = sub {
	$back_start->blit($apprects{main}, $app, $apprects{main});
	put_image($imgbin{version}, 17, 432);
    };

    if (!$from_intro || !$back_from_intro) {
	$back_start = $imgbin{backstartfull};
	$display_menu->();
    } else {
	$back_start = $back_from_intro;
    }

    my $invalidate_all;

    my $menu_start_sound = sub {
	if (!$mixer_enabled && !$mixer && !init_sound()) {
	    return 0;
	} else {
	    $mixer_enabled = 1;
	    play_music('intro', 8);
	    return 1;
	}
    };

    my $menu_stop_sound = sub {
	if ($mixer_enabled && $mixer && $mixer->playing_music) {
	    $app->delay(10) while $mixer->fading_music;   #- mikmod will deadlock if we try to fade_out while still fading in
	    $mixer->playing_music and $mixer->fade_out_music(500); $app->delay(450);
	    $app->delay(10) while $mixer->playing_music;  #- mikmod will segfault if we try to load a music while old one is still fading out
	}
	$mixer_enabled = undef;
	return 1;
    };

    my $menu_display_highscores = sub {
	display_highscores();

	$display_menu->();
	$app->flip;
	$invalidate_all->();
    };

    my $change_keys = sub {
	ask_from({ intro => [ 'PLEASE ENTER NEW KEYS' ],
		   entries => [
			       { 'q' => 'RIGHT-PL/LEFT?',  'a' => \$KEYS->{p2}{left},  f => 'ONE_CHAR' },
			       { 'q' => 'RIGHT-PL/RIGHT?', 'a' => \$KEYS->{p2}{right}, f => 'ONE_CHAR' },
			       { 'q' => 'RIGHT-PL/FIRE?',  'a' => \$KEYS->{p2}{fire},  f => 'ONE_CHAR' },
			       { 'q' => 'RIGHT-PL/CENTER?',  'a' => \$KEYS->{p2}{center},  f => 'ONE_CHAR' },
			       { 'q' => 'LEFT-PL/LEFT?',  'a' => \$KEYS->{p1}{left},  f => 'ONE_CHAR' },
			       { 'q' => 'LEFT-PL/RIGHT?', 'a' => \$KEYS->{p1}{right}, f => 'ONE_CHAR' },
			       { 'q' => 'LEFT-PL/FIRE?',  'a' => \$KEYS->{p1}{fire},  f => 'ONE_CHAR' },
			       { 'q' => 'LEFT-PL/CENTER?',  'a' => \$KEYS->{p1}{center},  f => 'ONE_CHAR' },
			       { 'q' => 'TOGGLE FULLSCREEN?', 'a' => \$KEYS->{misc}{fs}, f => 'ONE_CHAR' },
			      ],
		   outro => 'THANKS!',
		   erase_background => $back_start
		 });
	$invalidate_all->();
    };

    my $launch_editor = sub {
        SDL::ShowCursor(1);
        FBLE::init_setup('embedded', $app);
        FBLE::handle_events();
        SDL::ShowCursor(0);
        $back_start->blit($apprects{main}, $app, $apprects{main});
        $app->flip;
        $invalidate_all->();
    };
    my ($MENU_XPOS, $MENU_FIRSTY, $SPACING) = (56, 30, 51);
    my %menu_ypos = ( '1pgame' =>      $MENU_FIRSTY,
		      '2pgame' =>      $MENU_FIRSTY +     $SPACING,
		      'editor' =>      $MENU_FIRSTY + 2 * $SPACING,
		      'fullscreen' =>  $MENU_FIRSTY + 3 * $SPACING,
		      'graphics' =>    $MENU_FIRSTY + 4 * $SPACING,
		      'sound' =>       $MENU_FIRSTY + 5 * $SPACING,
		      'keys' =>        $MENU_FIRSTY + 6 * $SPACING,
		      'highscores' =>  $MENU_FIRSTY + 7 * $SPACING,
		  );
    my %menu_entries = ( '1pgame' => { pos => 1, type => 'rungame',
				       run => sub { @PLAYERS = ('p1'); $levels{current} = 1; $chainreaction = 0; $time_1pgame = $app->ticks } },
			 '2pgame' => { pos => 2, type => 'rungame',
				       run => sub { @PLAYERS = qw(p1 p2); $levels{current} = undef; } },
			 'editor' => { pos => 3, type => 'run', run => sub { $launch_editor->(); } },
			 'fullscreen' => { pos => 4, type => 'toggle',
					   act => sub { $fullscreen = 1; $app->fullscreen },
					   unact => sub { $fullscreen = 0; $app->fullscreen },
					   value => $fullscreen },
			 'graphics' => { pos => 5, type => 'range', valuemin => 1, valuemax => 3,
					 change => sub { $graphics_level = $_[0] }, value => $graphics_level },
			 'sound' => { pos => 6, type => 'toggle',
				      act => sub { $menu_start_sound->() },
				      unact => sub { $menu_stop_sound->() },
				      value => $mixer_enabled },
			 'keys' => { pos => 7, type => 'run',
				     run => sub { $change_keys->() } },
			 'highscores' => { pos => 8, type => 'run',
					   run => sub { $menu_display_highscores->() } },
		       );
    my $current_pos if 0; $current_pos ||= 1;
    my @menu_invalids;
    $invalidate_all = sub { push @menu_invalids, $menu_entries{$_}->{pos} foreach keys %menu_entries };

    my $menu_update = sub {
	@update_rects = ();
	foreach my $m (keys %menu_entries) {
	    member($menu_entries{$m}->{pos}, @menu_invalids) or next;
	    my $txt = "txt_$m";
	    $menu_entries{$m}->{type} eq 'toggle' && $menu_entries{$m}->{value} and $txt .= "_act";
	    $menu_entries{$m}->{type} eq 'range' and $txt .= "_$menu_entries{$m}->{value}";
	    $txt .= $menu_entries{$m}->{pos} == $current_pos ? '_over' : '_off';
	    erase_image_from($imgbin{$txt}, $MENU_XPOS, $menu_ypos{$m}, $back_start);
	    put_image($imgbin{$txt}, $MENU_XPOS, $menu_ypos{$m});
	}
	@menu_invalids = ();
	$app->update(@update_rects);
    };

    $app->flip;
    $invalidate_all->();
    $menu_update->();
    $event->pump while ($event->poll != 0);

    my $start_game = 0;
    my ($BANNER_START, $BANNER_SPACING) = (720, 80);
    my %banners = (artwork => $BANNER_START,
		   soundtrack => $BANNER_START + $imgbin{banner_artwork}->width + $BANNER_SPACING,
		   cpucontrol => $BANNER_START + $imgbin{banner_artwork}->width + $BANNER_SPACING
		                 + $imgbin{banner_soundtrack}->width + $BANNER_SPACING,
		   leveleditor => $BANNER_START + $imgbin{banner_artwork}->width + $BANNER_SPACING
                                 + $imgbin{banner_soundtrack}->width + $BANNER_SPACING
                                 + $imgbin{banner_cpucontrol}->width + $BANNER_SPACING);
    my ($BANNER_MINX, $BANNER_MAXX, $BANNER_Y) = (81, 292, 443);
    my $banners_max = $banners{leveleditor} - (640 - ($BANNER_MAXX - $BANNER_MINX)) + $BANNER_SPACING;
    my $banner_rect = SDL::Rect->new(-width => $BANNER_MAXX-$BANNER_MINX, -height => 30, '-x' => $BANNER_MINX, '-y' => $BANNER_Y);

    while (!$start_game) {
	my $synchro_ticks = $app->ticks;

	$graphics_level > 1 and $back_start->blit($banner_rect, $app, $banner_rect);

	$event->pump;
	if ($event->poll != 0) {
	    if ($event->type == SDL_KEYDOWN) {
		my $keypressed = $event->key_sym;
		if (member($keypressed, (SDLK_DOWN, SDLK_RIGHT)) && $current_pos < max(map { $menu_entries{$_}->{pos} } keys %menu_entries)) {
		    $current_pos++;
		    push @menu_invalids, $current_pos-1, $current_pos;
		    play_sound('menu_change');
		}
		if (member($keypressed, (SDLK_UP, SDLK_LEFT)) && $current_pos > 1) {
		    $current_pos--;
		    push @menu_invalids, $current_pos, $current_pos+1;
		    play_sound('menu_change');
		}

		if (member($keypressed, (SDLK_RETURN, SDLK_SPACE, SDLK_KP_ENTER))) {
		    play_sound('menu_selected');
		    push @menu_invalids, $current_pos;
		    foreach my $m (keys %menu_entries) {
			if ($menu_entries{$m}->{pos} == $current_pos) {
			    if ($menu_entries{$m}->{type} =~ /^run/) {
				$menu_entries{$m}->{run}->();
				$menu_entries{$m}->{type} eq 'rungame' and $start_game = 1;
			    }
			    if ($menu_entries{$m}->{type} eq 'toggle') {
				$menu_entries{$m}->{value} = !$menu_entries{$m}->{value};
				if ($menu_entries{$m}->{value}) {
				    $menu_entries{$m}->{act}->() or $menu_entries{$m}->{value} = 0;
				} else {
				    $menu_entries{$m}->{unact}->() or $menu_entries{$m}->{value} = 1;
				}
			    }
			    if ($menu_entries{$m}->{type} eq 'range') {
				$menu_entries{$m}->{value}++;
				$menu_entries{$m}->{value} > $menu_entries{$m}->{valuemax}
				  and $menu_entries{$m}->{value} = $menu_entries{$m}->{valuemin};
				$menu_entries{$m}->{change}->($menu_entries{$m}->{value});
			    }
			}
		    }
		}

		if ($keypressed == SDLK_ESCAPE || $event->type == SDL_QUIT) {
		    exit 0;
		}
	    }
	    $menu_update->();
	}

	if ($graphics_level > 1) {
	    my $banner_pos if 0;
	    $banner_pos ||= 670;
	    foreach my $b (keys %banners) {
		my $xpos = $banners{$b} - $banner_pos;
		my $image = $imgbin{"banner_$b"};

		$xpos > $banners_max/2 and $xpos = $banners{$b} - ($banner_pos + $banners_max);

		if ($xpos < $BANNER_MAXX && $xpos + $image->width >= 0) {
		    my $irect = SDL::Rect->new(-width => min($image->width+$xpos, $BANNER_MAXX-$BANNER_MINX), -height => $image->height, -x => -$xpos);
		    $image->blit($irect, $app, SDL::Rect->new(-x => $BANNER_MINX, '-y' => $BANNER_Y));
		}
	    }
	    $banner_pos++;
	    $banner_pos >= $banners_max and $banner_pos = 1;
	}
	$app->update($banner_rect);

	my $to_wait = $TARGET_ANIM_SPEED - ($app->ticks - $synchro_ticks);
	$to_wait > 0 and $app->delay($to_wait);
    }

    #- for $KEYS, try hard to keep SDLK_<key> instead of integer value in rcfile
    my $KEYS_;
    foreach my $p (keys %$KEYS) {
	foreach my $k (keys %{$KEYS->{$p}}) {
	    eval("$KEYS->{$p}->{$k} eq SDLK_$_") and $KEYS_->{$p}->{$k} = "SDLK_$_" foreach @fbsyms::syms;
	}
    }
    my $dump = Data::Dumper->Dump([$fullscreen, $graphics_level, $KEYS_], [qw(fullscreen graphics_level KEYS)]);
    $dump =~ s/'SDLK_(\w+)'/SDLK_$1/g;
    output($rcfile, $dump);

    iter_players {
	!is_1p_game() and $pdata{$::p}{score} = 0;
    };
}


#- ----------- editor stuff --------------------------------------------

sub choose_levelset() {

    my @levelsets = sort glob("$FBLEVELS/*");

    if ($direct_levelset) {
        load_levelset("$FBLEVELS/$direct_levelset");
        $direct_levelset = '';

    } elsif (!@levelsets) {
        # no .fblevels directory or void directory, just return and let the
        # game continue (means that the level editor has never been opened)

    } else {
	
	if (@levelsets <= 1) {
	    load_levelset($levelsets[0]);
	} else {
	    FBLE::init_app('embedded', $app);
	    FBLE::create_play_levelset_dialog();
	    SDL::ShowCursor(1);
	    my $play_level = FBLE::handle_events();
	    load_levelset("$FBLEVELS/$play_level");
	    SDL::ShowCursor(0);
	}
    }
}


#- ----------- main -------------------------------------------------------

init_game();

$direct or intro();

new_game_once();
new_game();


while (1) {
    eval { maingame() };
    if ($@) {
	if ($@ =~ /^new_game/) {
	    new_game();
	} elsif ($@ =~ /^quit/) {
	    menu();
	    new_game_once();
	    new_game();
	} else {
	    die;
	}
    }
}
