#!perl -w
use strict;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';

use Path::Class;
use Config '%Config';
use Getopt::Long;

GetOptions(
    'd|dist=s' => \my $distbase,
) or pod2usage(2);

sub find_distbase( $distbase='.', $target_file='Makefile.PL' ) {
    $distbase = dir($distbase);
    while(     !$distbase->contains($target_file)
           and $distbase->parent ne $distbase) {
        $distbase = $distbase->parent;
    };

    if( !$distbase->contains($target_file)) {
        return undef
    };
    
    $distbase
};

if( ! $distbase ) {
    $distbase = find_distbase( '.' );
};

if( ! $distbase ) {
    die "Couldn't find 'Makefile.PL' starting from here.";
};

$distbase = dir( $distbase )->absolute;
#warn $distbase;

my $dist_info;

sub load_dist_info( $distbase ) {
    require "$distbase/Makefile.PL";
    get_module_info()
};

sub dist_version_dir( %info ) {
    if( ! keys %info ) {
        %info=load_dist_info( $distbase )
    };
    my $module = $info{ NAME };
    (my $distbase = $module) =~ s!::!-!g;
    (sort { $b cmp $a } glob "$distbase-[0-9]*")[0]
};

sub run( @cmd ) {
    system( @cmd ) == 0
        or die "$!";
};

sub make(@commands) {
    run( $Config{ make }, @commands );
}

run( $^X, 'Makefile.PL' );

run( $Config{ make } );
run( $Config{ make }, 'distmeta' );
my %module_info = load_dist_info( $distbase );

my @meta = (file( dist_version_dir(), 'META.yml' ),
           file( dist_version_dir(), 'META.json' ));

for my $f (@meta) {
    #warn $f;
    my $target = $distbase->file( $f->basename );
    #warn $f;
    #warn $target;
    $f->copy_to( $target );
};