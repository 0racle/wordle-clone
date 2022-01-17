#!/usr/bin/env perl

use utf8;
use v5.26;
use warnings qw< FATAL all >;
use integer;
use experimentals;
use Getopt::Long;
use List::Util qw< mesh pairs >;
use Path::Tiny qw< path >;
use Term::ANSIColor;
use Term::Screen;
use Time::HiRes qw< usleep >;

binmode(*STDOUT, 'encoding(UTF-8)');

GetOptions(
    'chars=n' => \(my $chars = 5),
    'tries=n' => \(my $tries = 6),
);

my @wordlist = split(' ', path('SOWPODS.txt')->slurp);
my %words    = map { $_ => 1 } grep { length == 5 } @wordlist;

my $scr = Term::Screen->new;
$scr->curinvis;
$scr->noecho;
$scr->clrscr;

my ($h, $w) = ($scr->rows, $scr->cols);
my $X = ($w / 2) - 1;
my $Y = ($h / 2) - ($tries / 2) - 2;

my ($x, $y);

my %letters = mesh ['A' .. 'Z'], [qw<
    Ａ   Ｂ   Ｃ   Ｄ   Ｅ   Ｆ   Ｇ   Ｈ   Ｉ   Ｊ   Ｋ   Ｌ   Ｍ
    Ｎ   Ｏ   Ｐ   Ｑ   Ｒ   Ｓ   Ｔ   Ｕ   Ｖ   Ｗ   Ｘ   Ｙ   Ｚ
>];

my (%good, %found, %used);

my @word;
my @guess;
my $turn = 0;

sub draw_blanks() {
    my $col = 'white';
    for my $i (0 .. $tries - 1) {
        $scr->at($y + $i, $x)->puts(colored('＿' x $chars, $col));
        $col = 'magenta';
    }
}

sub draw_used_letters() {
    state @qwerty = map { [split(//)] } qw< QWERTYUIOP ASDFGHJKL ZXCVBNM >;
    my @output;
    for my $i (0 .. 2) {
        my @row = ' ' x $i;
        for my $l ($qwerty[$i]->@*) {
            my $col;
            if    ($good{$l})  { $col = 'black on_green' }
            elsif ($found{$l}) { $col = 'black on_yellow' }
            elsif ($used{$l})  { $col = 'magenta' }
            else               { $col = 'white' }
            push @row, colored($letters{$l}, $col);
        }
        $scr->at($Y + $tries + 2 + $i, $X - 10)->puts(join('', @row));
    }
}

sub pick { @_[rand @_] }

sub start_game() {
    ($x, $y) = ($X - ($chars * 2) / 2, $Y);
    @word = split(//, pick(keys %words));
    %used = %found = %good = ();
    draw_used_letters();
    draw_blanks();
    $turn = 0;
}

start_game();

while (1) {
    my $k = uc($scr->getch);
    if ($turn == $tries) {
        $scr->at($Y + $tries, $x)->puts(' ' x ($chars * 2));
        start_game();
    }
    if ($k =~ /[A-Z]/ && @guess < $chars) {
        push @guess, $k;
        $scr->at($y, $x)->puts($letters{$k});
        $x += 2;
    }
    if (ord($k) == 127 && @guess > 0) {    # BACKSPACE
        $x -= 2;
        $scr->at($y, $x)->puts('＿');
        pop @guess;
    }
    if ((ord($k) == 10 || ord($k) == 13) && @guess == $chars) {
        if (!exists $words{ join('', @guess) }) {
            my $col = 'red';
            for my $col ((qw< red white >) x 2) {
                $scr->at($y, $X - ($chars * 2) / 2);
                $scr->puts(colored(join('', @letters{@guess}), $col));
                usleep(50_000);
            }
            next;
        }
        my $ok = 0;
        my %bag; map { $bag{$_}++ } @word;
        my @block;
        for my $i (0 .. $chars - 1) {
            my $l = $guess[$i];
            if ($l eq $word[$i]) {
                $block[$i] = colored($letters{$l}, 'black on_green');
                $good{$l}++;
                $bag{$l}--;
                $ok++;
            }
        }
        for my $i (0 .. $chars - 1) {
            my $l = $guess[$i];
            if (exists $bag{$l} && $bag{$l} > 0) {
                $block[$i] //= colored($letters{$l}, 'black on_yellow');
                $found{$l}++;
                $bag{$l}--;
            }
            else {
                $block[$i] //= colored($letters{$l}, 'white');
            }
        }
        $x = $X - ($chars * 2) / 2;
        $scr->at($y, $x)->puts(join('', @block));
        map { $used{$_} = 1 } @guess;
        draw_used_letters();
        @guess = ();
        $turn++;
        $y++;

        if ($ok == $chars) {
            $turn = $tries;
            $scr->at($Y + $tries, $x)->puts(colored('＊' x $chars, 'green'));
        }
        elsif ($turn == $tries) {
            $scr->at($Y + $tries, $x);
            $scr->puts(colored(join('', @letters{@word}), 'red'));
        }
        else {
            $scr->at($y, $x)->puts('＿' x $chars);
        }
    }
}
