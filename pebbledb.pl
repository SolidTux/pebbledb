#!/bin/perl

use strict;
use warnings;
use LWP::Simple;
use JSON;
use Data::Dumper;
use DBI;
use Encode qw(encode decode);
use Getopt::Long;

Getopt::Long::Configure ('bundling');

my $appurl = "https://api2.getpebble.com/v2/apps/collection/all/watchapps-and-companions";
my $faceurl = "https://api2.getpebble.com/v2/apps/collection/all/watchfaces";
my $dbfile = "pebble.db";
my $dbname = "dbi:SQLite:dbname=$dbfile";
my $dbcon = DBI->connect($dbname,"","");
my $count = 0;
my $step = 100;

sub GetAll{
    my ($base,$url) = @_;
    $url //= "$base?limit=$step";
    $count += $step;
    my $resp = decode_json(get($url));
    my $next = $resp->{'links'}->{'nextPage'};
    my $data = $resp->{'data'};
    foreach (@$data) {
        my $id = $_->{'id'};
        my $title = $_->{'title'};
        my $author = $_->{'author'};
        my $category = $_->{'category_name'};
        my $description = $_->{'description'};
        my $screenshoti = $_->{'screenshot_images'};
        my $screenshot = "";
        if (ref($screenshoti) eq "ARRAY") {
            my $screenshota = @$screenshoti[0];
            $screenshot = (values %$screenshota)[0];
        }
        my $capabilities = "";
        my $cap = $_->{'capabilities'};
        if (defined $cap) {
            foreach (@$cap) {
                if ($capabilities eq "") {
                    $capabilities = $_;
                } else {
                    $capabilities = $capabilities . "," . $_;
                }
            }
        }
        my $hearts = $_->{'hearts'};
        my $pbw = $_->{'latest_release'}->{'pbw_file'};
        my $created = $_->{'created_at'};
        my $updated = $_->{'latest_release'}->{'published_date'};
        my $type = $_->{'type'};
        $dbcon->do("INSERT INTO pebble (id,title,author,category,description,screenshot,capabilities,hearts,pbw,created,updated,type) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
            undef,
        $id,$title,$author,$category,$description,$screenshot,$capabilities,$hearts,$pbw,$created,$updated,$type);
    }
    print "$count\n";
    if (defined $next) {
        GetAll($base,$next);
    }
}

sub UpdateDb {
    $dbcon->do("DROP TABLE pebble");
    $dbcon->do('CREATE TABLE pebble (
        "id" TEXT,
        "title" TEXT,
        "type" TEXT,
        "author" TEXT,
        "category" TEXT,
        "description" TEXT,
        "screenshot" TEXT,
        "capabilities" TEXT,
        "hearts" INTEGER,
        "pbw" TEXT,
        "created" TEXT,
        "updated" TEXT
    )');
    $dbcon->do('CREATE INDEX "id" on pebble (id ASC)');
    $dbcon->do('CREATE INDEX "type" on pebble (type ASC)');

    print "downloading apps\n";
    GetAll($appurl);
    $count = 0;
    print "downloading faces\n";
    GetAll($faceurl);
}

sub PrintEntry {
    my ($entry,$width) = @_;
    my $str = " " . $entry->{"hearts"} . "\t" . $entry->{"title"} . " (" . $entry->{"author"} . ")" . "\n";
    if ($entry->{"type"} eq "watchface") {
        $str = "W" . $str;
    } else {
        $str = "A" . $str;
    }
    print encode("utf-8",$str);
    my $desc = $entry->{'description'};
    $desc =~ s/^[ \t]*//;
    $desc =~ s/\n.*//g;
    if (length($desc) > $width) {
        $desc = substr($desc,0,$width) . '...';
    } else {
        $desc = substr($desc,0,$width);
    }
    print "\t\t" . $desc . "\n";
}

sub Search {
    my ($query,$string,$column) = @_;
    $string =~ s/[^a-zA-Z0-9 ]//g;
    $column =~ s/[^a-zA-Z]//g;
    my $ins = " $column COLLATE UTF8_GENERAL_CI LIKE \"%$string%\"";
    if ($query =~ /WHERE/) {
        $query .= " AND ";
    } else {
        $query .= " WHERE ";
    }
    return $query . $ins;
}

my $search;
my $title;
my $limit;
my $update;
my $help;
my $description;
my $width;
my $order;
my $orderdir;
my @columns = ("id", "title", "type", "author", "category", "description", "screenshot", "capabilities", "hearts", "pbw", "created", "updated");
my $query = "SELECT * FROM pebble";
GetOptions("s|search" => \$search, "t|title=s" => \$title, "d|description=s" => \$description, "l|limit=i" => \$limit, "u|update" => \$update, "h|help" => \$help, "w|width=i" => \$width, "o|order=s" => \$order, "a|ascending" => \$orderdir);
$width //= 100;

if (defined $search) {
    if (defined $title) {
        $query = Search $query, $title, "title";
    }
    if (defined $description) {
        $query = Search $query, $description, "description";
    }
    if ((defined $order) and ($order ~~ @columns)) {
        $query .= " ORDER BY " . $order;
        if (defined $orderdir) {
            $query .= " ASC";
        } else {
            $query .= " DESC";
        }
    }
    if ((defined $limit) and ($limit > 0)) {
        $query .= " LIMIT " . $limit;
    }
    my $sth = $dbcon->prepare($query);
    if (defined $sth) {
        $sth->execute();
        while (my $row = $sth->fetchrow_hashref) {
            PrintEntry $row, $width;
        }
    }
} elsif (defined $update) {
    UpdateDb;
}

$dbcon->disconnect;
