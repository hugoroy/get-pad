#!/usr/bin/perl

# Author: Benjamin Bayart

use strict;
use warnings;
use WWW::Mechanize;
use FDN::Common::Config;

my $url = Config_Key('pad.cfg','pad','url');
my $email = Config_Key('pad.cfg','pad','email');
my $passwd = Config_Key('pad.cfg','pad','passwd');
my $recursive = 1;
my $dirty = 0;


my $dir = '.';
while ( $ARGV[0] !~ /^\d+(=[\w-]+)?$/ ) {
	my $argv = shift @ARGV;
	if ( $argv eq '-o' || $argv eq '--output-dir' ) {
		$dir = shift @ARGV;
		next;
	}
	if ( $argv eq '-p' || $argv eq '--pad-url' ) {
		$url = shift @ARGV;
		next;
	}
	if ( $argv eq '-login' ) {
		$email = shift @ARGV;
		next;
	}
	if ( $argv eq '-passwd' ) {
		$passwd = shift @ARGV;
		next;
	}
	if ( $argv eq '-nr' || $argv eq '--no-recursive' ) {
		$recursive = 0;
		next;
	}
	if ( $argv eq '-r' || $argv eq '--recursive' ) {
		$recursive = 1;
		next;
	}
	print STDERR "Unknown argument: $argv\n";
	$dirty = 1;
}

my @pads;
for my $p ( @ARGV ) {
	if ( $p =~ /^(\d+)(=([\w-]+))?$/ ) {
		my $pad = $1;
		my $as = $3 // $pad;
		push @pads, { pad => $pad, as => $as };
		next;
	}
	print STDERR "Invalid id: $p\n";
	$dirty = 1;
}
if ( $dirty ) {
	print STDERR "Found invalid arguments.\n";
	print STDERR "Syntaxe: $0 [-o|--output-dir <directory>] [-p|--pad-url <URL-of-the-etherpad>] [-login <LOGIN>] [-passwd <PASSWD>] [-r|--recursive] [-nr|--no-recursive] <numeric pad id>*\n";
	exit(1);
}

print STDERR "Authentication... ";
my $mech = WWW::Mechanize->new( ssl_opts => { verify_hostname => 0 });
$mech->get($url);
$mech->submit_form(
	fields => {
		email => $email,
		password => $passwd
	}
);
print STDERR "OK\n";

my $target;
while ( $target = shift @pads ) {
	my $pad = $target->{'pad'};
	my $as  = $target->{'as'};
	print STDERR "Fetching pad $pad... ";
	$mech->get($url.'/ep/pad/export/'.$pad.'/latest?format=txt');
	if ( $mech->is_html ) {
		print STDERR "Error in fetching $pad\n";
		$dirty = 1;
	}
	my $content = $mech->content;
	if ( Encode::is_utf8($content) ) {
		Encode::_utf8_off($content);
	}
	print STDERR "OK\n";

	$content =~ s/^\s*\*\s*\\item/\\item/smg;

	open(OUT,'>',$dir.'/'.$as.'.txt') or die "Failed to open $as.txt";
	print OUT $content;
	close(OUT);

	while ( $content =~ s/^\\input\s+(\d+)\s*$//m ) {
		print STDERR "Need to take pad $1 as $1 too\n";
		push @pads, { pad => $1, as => $1 };
	}
}

