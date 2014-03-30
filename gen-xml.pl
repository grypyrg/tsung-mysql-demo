#!/usr/bin/perl
#
#
#
# Probably the worst code ever, but the best code ever made on a Sundaymorning!
#
# 
use strict;
use Data::Dumper;
local $Data::Dumper::Indent    = 1;
local $Data::Dumper::Sortkeys  = 1;
local $Data::Dumper::Quotekeys = 0;

my $dir=$ARGV[0];
my $hash=$ARGV[1];

open REGEX, "$dir/hashes/$hash.fingerprint" or die $!;
open SESSIONXML, ">$dir/hashes/$hash.session.xml" or die $!;
open SESSIONVALS, ">$dir/hashes/$hash.session.vals" or die $!;
open XMLOPTIONS, ">$dir/hashes/$hash.options.xml" or die $!;

my $regex;
while (<REGEX>) {
	$regex=$regex . $_;
}
print "#########################################################\n";
print "ORIGINAL FINGERPRINT\n";
print "#########################################################\n";
print $regex;
close(REGEX);


my $allqueries=$regex;

# example: t?id should become t?.id, potential bug in pt-fingerprint
$allqueries =~ s/\?([^\s])/?$1/g;
$allqueries =~ s/\?\+/?/g;


my @queries = split /\n/, $allqueries;
print SESSIONXML "<session probability=\"100\" name=\"$hash\" type=\"ts_mysql\">\n"
	. "	<request><mysql type=\"connect\" /></request>\n"
	. "	<request><mysql type=\"authenticate\" database=\"test\" username=\"test\" password=\"\" /></request>\n"
	;



$regex =~ s/([a-zA-Z])\(/$1\\s*(/g;

# make sure all current chars are not seen as part of regex
$regex =~ s/(\(|\))/\\$1/g;

# if it's ?+ then we just use (.*)
$regex =~ s/\?\+/(.*)/g;

# example: t?id should become t?.id, potential bug in pt-fingerprint
$regex =~ s/\?([^\s])/?.$1/g;

# all remaining ? to (.*)
$regex =~ s/\?/(.*)/g;




#$regex =~ s/\n/\\n/g;
#$regex =~ s/\s/\\s*/g;


print "#########################################################\n";
print "REGEX\n";
print "#########################################################\n";
#$regex='use (.*) .*';
print $regex;
print "\n";


open SESSIONS, "$dir/hashes/$hash" or die $!;

my $session;
my $columncount;

while (<SESSIONS>) {
	$session=$_;

	$columncount++;


	open FILE, "$dir/sessions/$session" or die $!;
	my $file;
	while (<FILE>) {
		$file = $file . $_;
	}
	$file =~ s/\n\n/\n/g;
	$file =~ s/^--.*\n//g;

	#$file =~ s/\n/ /g;
	close FILE;

	#use re 'debugcolor';

	if ( my @vals = $file =~ m/$regex/i )
	{

		if ( $columncount == 1 ) {
			my $headercount=0;

			my $hashid= $hash;
			$hashid =~ s/-//;
			print SESSIONXML "\t<setdynvars sourcetype=\"file\" fileid=\"$hashid\" delimiter=\";\" order=\"random\">\n";
			print XMLOPTIONS "\t<option name=\"file_server\" id=\"$hashid\" value=\"hashes/$hash.session.vals\" />\n";
			foreach my $header (@vals) {
				$headercount++;
				#print SESSIONVALS "val$headercount;";
				print SESSIONXML "\t\t<var name=\"val$headercount\" />\n";

			}
			#print SESSIONVALS "\n";
			print SESSIONXML "\t</setdynvars>\n";
		}

		my $count=0;
		foreach my $val (@vals) {
			print SESSIONVALS "$val;";			
		}
	} else {
		die "Error: nothing matched";
	}
	print SESSIONVALS "\n";


}


my $querycount=1;
foreach my $query  ( @queries ) 
{
	while ( $query =~ s/\?/%%_val$querycount%%/) {
		$querycount++;
	}
	print SESSIONXML "\t<request subst=\"true\"><mysql type=\"sql\">$query;</mysql></request>\n";
}
print SESSIONXML "\t<request><mysql type=\"close\" /></request>\n";

print SESSIONXML "</session>\n";


close(SESSIONXML);
close(XMLOPTIONS);
close(SESSIONVALS);