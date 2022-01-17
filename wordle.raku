#!/usr/bin/env raku

use Term::ReadKey;
use Terminal::ANSIColor;
use Terminal::Print < T >;

unit sub MAIN(:$chars = 5, :$tries = 6);

my @wordlist = 'SOWPODS.txt'.IO.words;
my $words = @wordlist.grep(*.chars == $chars).Set;

T.initialize-screen;
signal(SIGINT).tap: { exit }
END { T.shutdown-screen }

my ($h, $w) = (T.rows, T.columns);
my $X = ($w div 2) - 1;
my $Y = ($h div 2) - ($tries div 2) - 2;

my ($x, $y);

my %letters = ('A' .. 'Z') Z=> <
    Ａ   Ｂ   Ｃ   Ｄ   Ｅ   Ｆ   Ｇ   Ｈ   Ｉ   Ｊ   Ｋ   Ｌ   Ｍ
    Ｎ   Ｏ   Ｐ   Ｑ   Ｒ   Ｓ   Ｔ   Ｕ   Ｖ   Ｗ   Ｘ   Ｙ   Ｚ
>;

my $used  = Set();
my $found = Bag();
my $good  = Bag();

my &draw-remaining = {

    # QWERTY
    state @qwerty = 'QWERTYUIOPASDFGHJKLZXCVBNM'.comb.rotor(10,9,7);
    T.print-string: $X - 10, $Y + $tries + 2, @qwerty.kv.map(-> $k, @l {
        ' ' x $k ~ join '', @l.map: -> $l {
            my $col = do {
                when $l ∈ $good { 'black on_green' }
                when $l ∈ $found { 'black on_yellow' }
                when $l ∈ $used { 'magenta' }
                default { 'white' }
            }
            colored(%letters{$l}, $col)
        }
    }).join("\n")
}

my &draw-blanks = {
    my $col = 'white';
    for 0 ..^ $tries -> $i {
        T.print-string:
          $x, $y + $i, colored('＿' x $chars, $col);
        $col = 'magenta';
    }
}

my @word;
my @guess;
my $turn = 0;

my &start-game = {
    ($x, $y) = ($X - ($chars × 2) div 2, $Y);
    @word = $words.keys.pick.comb;
    draw-remaining();
    draw-blanks();
}

start-game();

react {
    whenever key-pressed(:!echo) -> $k {
        given $k {
            when $turn == $tries {
                T.print-string: $x, $Y + $tries, ' ' x ($chars × 2);
                @word =  $words.keys.pick.comb;
                $used = $found = $good = Set();
                start-game();
                $turn = 0;
            }
            when /<:L>/ && @guess.elems < $chars {
                @guess.push: $k.uc;
                T.print-string: $x, $y, %letters{$k.uc};
                $x += 2;
            }
            when .ord == 127 && @guess.elems > 0 {
                $x -= 2;
                T.print-string: $x, $y, '＿';
                @guess.pop if @guess;
            }
            when .ord == 10 && @guess.elems == $chars {
                if $words{@guess.join}:!exists {
                    for (< red white > xx 2).flat -> $col {
                        T.print-string:
                           $X - ($chars × 2) div 2, $y,
                           colored(%letters{@guess}.join, $col);
                        sleep 0.05;
                    }
                }
                else {
                    my $ok = 0;
                    my $word = @word.Bag;
                    my @block;
                    for (@guess Z @word).kv -> $i, ($a, $b) {
                        if $a eq $b {
                            @block[$i] = colored(%letters{$a}, 'black on_green');
                            $word ∖= $a;
                            $good ∪= $a;
                            $ok++;
                        }
                    }
                    for @guess.kv -> $i, $a {
                        next if @block[$i];
                        if $a ∈ $word {
                            @block[$i] = colored(%letters{$a}, 'black on_yellow');
                            $word ∖= $a;
                            $found ∪= $a;
                        }
                        else {
                            @block[$i] = colored(%letters{$a}, 'white')
                        }
                    }
                    $x = $X - ($chars × 2) div  2; 
                    T.print-string: $x, $y, @block.join;
                    $used ∪= @guess;
                    draw-remaining();
                    @guess = ();
                    $turn++;
                    $y++;
                    if $ok == $chars {
                        $turn = $tries;
                        T.print-string:
                          $x, $Y + $tries, colored('＊' x $chars,  'green');
                    }
                    elsif $turn == $tries {
                        T.print-string:
                          $x, $Y + $tries, colored(%letters{@word}.join,  'red');
                    }
                    else {
                        T.print-string: $x, $y, '＿' x $chars;
                    }
                }
            }
        }
    }
}
