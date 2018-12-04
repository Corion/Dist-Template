#!perl
use strict;
use warnings;

my $latest_tag = `git describe --tags --abbrev=0`;
$latest_tag =~ s!\s+$!!;

system( "git log $latest_tag..HEAD --oneline" );
print "$latest_tag\n";