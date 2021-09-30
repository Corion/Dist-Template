#!/usr/bin/perl
=for article
# use the system Perl to setup/maintain the local Perl

    apt install libsql-translator-perl


sqlite: create diff between SQL and existing table, upgrade missing columns/alter table width
=cut

use strict;
use DBIx::RunSQL;
use SQL::Translator;
use SQL::Translator::Diff;
use Getopt::Long;

GetOptions(
    'from|f=s'  => \my $rev_from,
    'to|t=s'    => \my $rev_to,
    'file=s'    => \my $filename,
    'git-dir=s' => \my $git_dir,
    'dry-run|n' => \my $dry_run,
);
$filename //= 'sql/create.sql';
$git_dir //= '.';

# Get the schema of the old DB
#my $t_old = SQL::Translator->new(
#    parser => 'SQLite',
#    producer => 'SQLite',
#);

sub fetch_schema {
    my( $sql) = @_;

    my $t = SQL::Translator->new(
        parser => 'SQLite',
        producer => 'SQLite',
    );
    my $out = $t->translate( \$sql );
    if( ! defined $out ) {
	    warn "Error?!";
    };
    return $t->schema;
}

sub fetch_schema_file {
    my( $sql_file) = @_;
    my $sql = do { local(@ARGV,$/) = ($sql_file); <> };
    my $res = fetch_schema( $sql );
    $res->name( $sql_file );
    return $res
}

sub fetch_schema_rev {
    my( $sql_file, $rev ) = @_;
    my $cmd = qq(git --git-dir "$git_dir" show $rev:$sql_file);
    my $sql = readpipe($cmd);
    #warn "Fetched $rev as $sql_file";
    my $res = fetch_schema( $sql );
    $res->name( "$rev:$sql_file" );
    return $res
}

sub fetch_schema_dsn {
    my( $dsn ) = @_;
    my $dbh = DBI->connect( $dsn, undef, undef, {FetchHashKeyName => 'NAME_lc'});
    my $t = SQL::Translator->new(
        debug => 1,
        parser_args => {
            dsn         => $dsn,
            #db_user     => undef,
            #db_password => undef,
            #dbh => $dbh
        },
        #producer => 'SQLite',
        name => 'live db',
    );
    $t->parser('DBI');
    $t->producer('SQLite');

    # Dummy call to actually fetch the data ...
    $t->translate(data => '');

    my $res = $t->schema;
    if( ! $res->name ) {
        $res->name( 'live DB' );
    };

    return $res
}

my $s_old;
if( $rev_from =~ /^dbi:/ ) {
    $s_old = fetch_schema_dsn( $rev_from );
} else {
    $s_old = fetch_schema_rev( $filename, $rev_from );
}

#use Data::Dumper; warn Dumper $s_old;

my $s_new = fetch_schema_rev( $filename, $rev_to );

my $migrate = SQL::Translator::Diff->new({
    output_db     => 'SQLite',
    source_schema => $s_old,
    target_schema => $s_new,
})->compute_differences->produce_diff_sql;

# Release the DBI handle
undef $s_old;
undef $s_new;

if( $dry_run ) {
    print $migrate;
} else {
    # actually perform the changes on the DB
    print "Migrating $rev_from to $rev_to\n";
    DBIx::RunSQL->create(
        dsn => $rev_from,
        sql => \$migrate,
    );

};
