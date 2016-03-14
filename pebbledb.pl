#!/bin/perl

use strict;
use warnings;
use LWP::Simple;
use JSON;
use Data::Dumper;
use DBI;

my $appurl = "https://api2.getpebble.com/v2/apps/collection/all/watchapps-and-companions";
my $faceurl = "https://api2.getpebble.com/v2/apps/collection/all/watchfaces";
my $dbfile = "pebble.db";
my $dbname = "dbi:SQLite:dbname=$dbfile";
my $dbcon = DBI->connect($dbname,"","");
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

print "get apps\n";
GetAll($appurl);
$count = 0;
print "get faces\n";
GetAll($faceurl);

$dbcon->disconnect;
