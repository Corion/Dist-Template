#!perl -w
use 5.020;
use feature 'signatures';
no warnings 'experimental::signatures';

use Path::Class;
use Getopt::Long;

use Data::Dumper;

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

my $dist_info;

sub load_dist_info( $distbase ) {
    require "$distbase/Makefile.PL";
    get_module_info()
};

my %module_info = load_dist_info( $distbase );

sub add_section( $name, @items ) {
    my $res = '';

    if( @items ) {
        my $indent = $name ? '    ' : '';
        my $lines = join ";\n$indent",
            map {
                my( $mod, $ver ) = @$_;
                $ver = defined $ver ? ", '$ver'" : "";
                "requires '$mod'$ver"
            } @items;
        my $s = $name ? <<SECTION : $lines;
on '$name' => sub {
    $lines;
}
SECTION
        $res = $s;
    };
    return $res;
}

# update_file usually comes from our Makefile.PL already ...
#sub update_file {
#    my( $filename, $new_content ) = @_;
#    my $content;
#    if( -f $filename ) {
#        open my $fh, '<', $filename
#            or die "Couldn't read '$filename': $!";
#        binmode $fh;
#        local $/;
#        $content = <$fh>;
#    };
#
#    if( $content ne $new_content ) {
#        if( open my $fh, '>', $filename ) {
#            binmode $fh;
#            print $fh $new_content;
#        } else {
#            warn "Couldn't (re)write '$filename': $!";
#        };
#    };
#}

my $cpanfile = join "\n",
    add_section( '', map { [ $_ => $module_info{PREREQ_PM}->{$_} ] } keys %{ $module_info{PREREQ_PM}}),
    add_section( 'test', map { [ $_ => $module_info{PREREQ_PM}->{$_} ] } keys %{ $module_info{TEST_REQUIRES}});
    ;

update_file( "$distbase/cpanfile", $cpanfile );
