#!/usr/bin/perl

#    bitchbot IRC bot
#    Copyright (C) 2001  Richard Stanway
#
#### 5W jutut rivilta: ~570, ~2800, kyb3R
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

#    View the license online at http://www.gnu.org/copyleft/gpl.html

###############################################################################
#                         BitchBOT for PERL by R1CH
###############################################################################
#
#  ----------------
#  IMPORTANT NOTICE
#  ----------------
#  If you modify this source and release it, please keep the original version string
#  but modify the $bot_version_number to reflect your changes, and you'd probably
#  want to set $autoupdate to 0. Separate releases of bitchbot are called 'bitchlings'
#  and must be distributed in accordance with the license. Please poke your head in
#  irc.edgeirc.net #bitchbot and let me know what you've done, it would be nice to
#  know what people come up with.
#
#  Also, please note THIS SOURCE IS PROBABLY NOT 100% SECURE AND/OR WORKING. Consider
#  this a beta quality release, it works for me (tm), so I don't think I'll do much
#  more modifications. If you have any questions or comments, you can probably find
#  me on irc.edgeirc.net #bitchbot. If you feel like helping out, either code the bot
#  some more (:P), idle on IRC to help people with config problems or spread the word
#  about how messy my code is (keep in mind, this is my first real perl app).
#
#  Enjoy the bot :) - R1CH
#
#
# Running BitchBOT
# ----------------
#
# Before running,
# check the bitch.conf file for important settings.
#
# For *nix users:
# Make bitch.pl executable by running chmod 775 bitch.pl and then fire it up
# with perl bitch.pl. Keep in mind on a quit (admin command, time out, etc) the
# bot will not automatically run again. see the bitchbot website for a sample
# auto restart script so you can keep it running in the background.
#
# For Win32 users:
# Download ActivePerl at http://www.activestate.com/ and move bitch.pl to your
# perl\bin directory, and run 'perl bitch.pl' from the command line. To hide
# the bitchbot console window, you'll need to use some other 3rd party app.
# I've actually made 'runhide' which will achieve this, grab it from my random
# stuff page on www.r1ch.net
#
# WARNING WITH WIN32: If you DONT exit the bot "cleanly", ie, a 'botname, quit'
# command, all modifications since the bot was loaded will be LOST. With unix
# flavoured OS'es this isn't a problem since bitchbot handles SIGTERM/KILL/HUP
# etc and performs the appropriate action, but Windows being the amazing OS it
# is doesn't like signals.
#
# Addon Modules:
# Time::HiRes
# You could use Time::HiRes for accurate ping replies (www.cpan.org for a *nix
# version, for Win32, I compiled it for you: http://www.r1ch.net/projects/bitchbot/download/)
#
# Net::FTP (aka libnet)
# This module, if installed, will allow you to upload the channel statistics
# to a remote FTP server once they are done. For Win32 users, there again is a
# precompiled version on the bitchbot website. Unix users, check out CPAN.
#
# Quake (and other games) Server Statistics
# qstat by Steve Jankowski allows the bot to query a wide range of game servers
# and report results to the channel: http://www.qstat.org/
# Comes in Win32 and *nix flavours, once compiled/extracted, move qstat or qstat.exe
# to your directory with bitch.pl
# Please be aware if the 'p' command is issued when querying a game server with a
# lot of players, the bot will become very lagged/flood off if it does not have an
# O line or some other method of evading flood control. As of 1.0.1 you can optionally
# disable 'floody' commands with config directives. checkout bitch.conf.template.
#
# Commands reference:
# Check http://www.r1ch.net/projects/bitchbot/commmands/
#
# Support:
# None :/ Don't have time I'm afraid so please save me the trouble of downloading
# email and don't email me. Try irc.edgirc.net #bitchbot to possibly find other bot
# users who may be able to help you. In any instance, I don't believe anything
# should be too hard to figure out without a little playing around.
##############################################################################

######################
# REQUIRE PERL 5.002 #
######################
require 5.002;

#################
# USE LIBRARIES #
#################
use Socket;
use POSIX ":sys_wait_h";
use XML::Feed;
use threads;
use Thread::Queue;
use Switch;
use HTTP::Request;
use XML::RSS;
#use XML::RSS::Tools;
use XML::LibXML;
use Data::Dumper;
use LWP::Simple;
use XML::Simple;
use XML::DOM;
use HTML::TreeBuilder;
use Image::Size;
use Date::Format;
#use utf8;

sub REAPER {
  my $waitedpid;
  $waitedpid = wait;
  # loathe sysV: it makes us not only reinstate
  # the handler, but place it after the wait
  $SIG{CHLD} = \&REAPER;
}

sub INT_handler {
    print("\nbitchbot: caught SIGINT, dying\n");
    snd("QUIT :Ack! SIGINT!!");
    sleep 1;
    &Cleanup;
    exit;
}

sub ALARM_handler {
#  if (time() - $lastmsgtime > 240) {
#    snd("QUIT :Hmm, I seem to have timed out");
#    sleep 2;
#    &Cleanup;
#    exit;
#  }

  #ugh, only way i can think of. i hate fork() and such, there isn't any decent documentation
  #all i wanna do is run a program and have it say "done" somehow to parent when its done.

#  if ($chanstats_running) {
#    &checkchanstats;
#    alarm (2);
#  } else {
#    alarm (30);
#  }
}

sub KILL_handler {
    print("\nbitchbot: caught SIGKILL, dying\n");
    snd("QUIT :Caught a SIGKILL");
    sleep 1;
    &Cleanup;
    exit;
}

sub HUP_handler {
  print "bitchbot: Caught a SIGHUP, becoming a semi daemon.\n";
	open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
	open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
	open STDERR, '>&STDOUT'	or die "Can't dup stdout: $!";
}

sub PWR_handler {
  snd ("QUIT :Hmm, my UPS claims the power is failing. I'm gonna go hide.");
  open (NOSPAWN, ">${win321}nospawn");
  print NOSPAWN "powerfail";
  close (NOSPAWN);
  sleep 1;
  &Cleanup;
  exit;
}

$SIG{PWR} = \&PWR_handler;
$SIG{INT} = \&INT_handler;
$SIG{KILL} = \&KILL_handler;
$SIG{TERM} = \&KILL_handler;
$SIG{ALRM} = \&ALARM_handler;
$SIG{CHLD} = \&REAPER;
$SIG{HUP} = \&HUP_handler;

if (lc($^O) eq 'mswin32') {
  $win321 = '';
  $mfail = "[FAILED]";
  $mok =   "[  OK  ]";
} else {
  $win321 = './';
  $mfail = "[[31mFAILED[0m]";
  $mok =   "[  [32mOK[0m  ]";
}

##################################
# DO MY VARIABLES FOR MORE SPEED #
##################################
my ($remote, $port, $iaddr, $paddr, $proto, $line, $spoken, $bitchcmds, $newfacts);

#set up defaults (stops -w warning)

@swearwords = ();

$ctcp_reply = 1;
$noqq = 0;
$uploadname = "";
$uploadpath = "";
$uploaduser = "";
$uploadhost = "";
$uploadpass = "";
$uploadpasv = 0;
$outfile = "";
$outurl = "";
$notoys = 0;
$maxpolloptions = 6;
$maxpending = 5;
$key = "";
$allowstats = 1;
$enableshortcuts = 1;
$defaultmode = "";
$usermodemaster = "";
$autooper = 0;
$noeval = 1;
$opername = "";
$admin = "";
$botemail = "";
$novote = 0;
$nopoll = 0;
$noplayerlist = 1;
$prevdate = "empty";

#for (lame) nick validation
$nickchars = "abcdefghijklmnopqrstuvxyzABCDEFGHIJKLMNOPQRSTUVXYZ1234567890-[]\\`^{}|";

#############################################
# 5W muuttujat
$lurkki_hiljaa = 0;
#############################################

###################################################
# FIND OUT WHETHER TO RUN A DIFFERENT CONFIG FILE #
###################################################
if (!defined($ARGV[0])) {
  @tmp = split(/[\/]|[\\]/,$0);
  $scriptname = $tmp[$#tmp];
  ($scriptname) = split(/\./,$scriptname);
  undef @tmp;
} else {
  $scriptname = $ARGV[0];
}

##################
# EXECUTE CONFIG #
##################
print "Executing config file... ";
do "$win321$scriptname.conf" or die " $mfail ($scriptname.conf -- $!)\n";
print " $mok ($botname from $scriptname.conf)\n";

#yuck.
@tmp = split(//, $botname);
foreach (@tmp) {
  if (index($nickchars,$_) == -1 ) {
    print "Illegal nickname ($botname): Can't contain a $_\n";
    exit;
  }
}
undef @tmp;

#anti idiot check
if (!defined($botname) || !defined($server) || !defined($serverport) || !defined($channel)) {
  print "Try SETTING UP THE CONFIG before running the bot.\n";
  exit;
}

#yucky way of checking config migration
if (!defined($autoupdate)) {
  print "\nNOTICE: Your config appears to be out of date as it is missing at\nleast one default option. If you have just upgraded from a previous\nversion don't forget to check out the new bitch.conf.template\nfor new configuration options.\n\n";
  $autoupdate = 1;
}

############################################
# VERSION FOR AUTO UPDATE -- DO NOT MODIFY #
############################################
$bot_version_number = "bitchbot-1.0.2";

#removed until people stop being idiots
#if ($autoupdate == 1) {
#  if (checkupdate() == 2) {
#    print "$mfail\nAn error occured accessing the update server.\nMaybe this is because you are behind a firewall or proxy\nor are not currently connected to the Internet.\n\n";
#  }
#}



######################
# INITIALISE MODULES #
######################
$notime = 0;
$lastmsgtime = time();

print "Trying Time::HiRes...    ";
if (eval "use Time::HiRes", $@) {$notime = 1;}
if ($notime == 1) {
  print " $mfail (module not compatible/installed on this platform)\n";
} else {
  print " $mok (hi-resolution ping times enabled)\n";
}


print "Trying to set alarm...   ";
if (eval "alarm (30)", $@) {$noalarm = 1;}
if (defined($noalarm)) {
  print " $mfail (not applicable for this OS)\n";
} else {
  print " $mok (will detect timeout)\n";
}

$| = 1;

################
# GET LIFETIME #
################
if (open (TIMES,"$scriptname.time")) {
  $allstartlifetime = <TIMES>;
  chomp ($allstartlifetime);
  close (TIMES);
} else {
  $allstartlifetime = 0;
}


###################
# INITIALISE VARS #
###################
$usermodemaster = " ADDFACTS DELFACTS DELALLFACTS SERVERMANIP STATIC ADMIN OP AV NULL ";

@usermodes = split(" ",$usermodemaster);

$bitchcmds = 0;
$newfacts = 0;
$spoken = 0;

@msg = ();
@checkaccess = ();
@owners = ();
@facts = ();
@objects = ();
@splitters = ();
@factoidmsg = ();
%nicklist = ();

%deltimer = ();
%seen = ();
%access = ();
%servers = ();
%ignore = ();
%profiles = ();

$optimeout = time() - 5;
$factoiddelay = time() - 20;

$startlifetime = time();

$timezone .= ' ';

srand;

############################
# SET HELP TEXT FOR WHATIS #
############################
$hlp{"ADDFACTS"} = "Allows you to add factoids (\002$botname, x is y\002)";
$hlp{"DELFACTS"} = "Allows you to delete factoids you set (\002$botname, forget factoidname[:number]\002)";
$hlp{"DELALLFACTS"} = "Allows you to delete anyone's factoids (\002$botname, forget factoidname[:number]\002)";
$hlp{"SERVERMANIP"} = "Allows you to add a server to the lookup table (\002$botname, addq2server IP[:PORT] NAME\002)";
$hlp{"STATIC"} = "Specifies that your IP address/name is static (ie, doesn't change)";
$hlp{"ADMIN"} = "Access to admin only commands.";
$hlp{"OP"} = "Allows user to perform op commands (\002$botname, voice nick\002, \002$botname, kick nick\002, etc)";
$hlp{"AV"} = "Auto-voices the user when they join $channel (can be set by user with OP)";
$hlp{"IGNORE"} = "Ignores all further events from the nick/hostmask specified.";
$hlp{"FACTOIDLIST"} = "List all factoids for the parameter specified, (\002$botname, factoidlist OBJECT[:page]\002)";
$hlp{"Q2INFO"} = "Get Q2 server information from the IP specified. If a user with SERVERMANIP has added a name, you can use the name, (\002$botname, q2info some.q2.server:27910\002 or \002$botname, q2info ctf-server1\002)";
$hlp{"INFO"} = "Return the number of factoids a user added.";
$hlp{"ADDQ2SERVER"} = "Add a Q2 IP->NICENAME. Used to make \002$botname, q2info\002 easier to use, (\002$botname, addq2server IP:PORT NAME\002)";
$hlp{"SHUTDOWN"} = "Shutdown ${botname}.";
$hlp{"BITCHMSG"} = "Sends a text message when I next see specified user. \002$botname, bitchmsg nick message\002.";
$hlp{"RESTART"} = "Cause ${botname} to quit and re-execute the .PL file.";

#################
# OPEN LOGFILES #
#################
open (BITCHLOG, ">>$win321$scriptname.log") or die "$mfail can't output to logfile: $!\n";
open (CHATLOG, ">>$logfile") or die "$mfail can't output to logfile: $!\n";

###############
# create data #
###############
if (!-e "$win321$datadir") {
  mkdir ("$win321$datadir",0755) or die "$mfail Couldn't create data directory: $!\n";
}

###############
# load access #
###############
#dbmopen (%access,"$win321$datadir/access",0755) || die "Unable to open $datadir/access: $!\n";
#dbmopen (%servers,"$win321$datadir/servers",0755) || die "Unable to open $datadir/servers: $!\n";
#dbmopen (%ignore,"$win321$datadir/ignores",0755) || die "Unable to open $datadir/ignores: $!\n";
#dbmopen (%seen,"$win321$datadir/seen",0755) || die "Unable to open $datadir/seen: $!\n";
#dbmopen (%profiles,"$win321$datadir/profiles",0755) || die "Unable to open $datadir/profiles: $!\n";
#dbmopen (%hosts,"$win321$datadir/hosts",0755) || die "Unable to open $datadir/hosts: $!\n";

#DBM sucks. period. ndbm is pathetic. i wiped the entire set by using | as a key. gah.
#so i created my own style DBM thingie hash loading or something...
if (-e "$win321$datadir/access.dat") {
  open (DBMHACK,"$win321$datadir/access.dat") or die "$mfail Broken DBM: $!\n";
  @tmp=<DBMHACK>;
  for(@tmp){
    chomp;
    ($key,$value) = split(/\001/,$_);
    $access{$key} = $value;
  }
  close (DBMHACK) or die "$mfail Cannot close DBM: $!\n";
}

if (-e "$win321$datadir/servers.dat") {
  open (DBMHACK,"$win321$datadir/servers.dat") or die "$mfail Broken DBM: $!\n";
  @tmp=<DBMHACK>;
  foreach $_ (@tmp){
    chomp;
    ($key,$value) = split(/\001/,$_);
    $servers{$key} = $value;
  }
  close (DBMHACK) or die "$mfail Cannot close DBM: $!\n";
}

if (-e "$win321$datadir/ignore.dat") {
  open (DBMHACK,"$win321$datadir/ignore.dat") or die "$mfail Broken DBM: $!\n";
  @tmp=<DBMHACK>;
  foreach $_ (@tmp){
    chomp;
    ($key,$value) = split(/\001/,$_);
    $ignore{$key} = $value;
  }
  close (DBMHACK) or die "$mfail Cannot close DBM: $!\n";
}

if (-e "$win321$datadir/seen.dat") {
  open (DBMHACK,"$win321$datadir/seen.dat") or die "$mfail Broken DBM: $!\n";
  @tmp=<DBMHACK>;
  foreach $_ (@tmp){
    chomp;
    ($key) = split(/\001/,$_);
    $seen{$key} = substr($_, index($_,"\001")+1);
  }
  close (DBMHACK) or die "$mfail Cannot close DBM: $!\n";
}

if (-e "$win321$datadir/profiles.dat") {
  open (DBMHACK,"$win321$datadir/profiles.dat") or die "$mfail Broken DBM: $!\n";
  @tmp=<DBMHACK>;
  foreach $_ (@tmp){
    chomp;
    ($key,$value) = split(/\001/,$_);
    $profiles{$key} = $value;
  }
  close (DBMHACK) or die "$mfail Cannot close DBM: $!\n";
}

if (-e "$win321$datadir/hosts.dat") {
  open (DBMHACK,"$win321$datadir/hosts.dat") or die "$mfail Broken DBM: $!\n";
  @tmp=<DBMHACK>;
  foreach $_ (@tmp){
    chomp;
    ($key,$value) = split(/\001/,$_);
    $hosts{$key} = $value;
  }
  close (DBMHACK) or die "$mfail Cannot close DBM: $!\n";
}

####################
# LOAD STATS TIMER #
####################
if (open (ST,"$win321$datadir/stats.time")) {
  $stattime = <ST>;
  close (ST);
} else {
  $stattime = 0;
}

###############
#Load Factoids#
###############

print "Loading factoids...";

if (-e "$win321$datadir/msg1.dat") {
  open (MSGSFILE,"$win321$datadir/msg1.dat") or die "$mfail Unable to open $win321$datadir/msg1.dat :$!\n";
  @msg=<MSGSFILE>;
  for(@msg){chomp;}
  close (MSGSFILE) or die "$mfail Cannot close msgs: $!\n";
}

if (-e "$win321$datadir/kicks.dat") {
  open (KICKSFILE,"$win321$datadir/kicks.dat") or die "$mfail Unable to open $win321$datadir/kicks.dat :$!\n";
  @kicks=<KICKSFILE>;
  for(@kicks){chomp;}
  close (KICKSFILE) or die "$mfail Cannot close kicks: $!\n";
}

if (-e "$win321$datadir/facts.dat") { 
  open (FACTSFILE,"$win321$datadir/facts.dat") or die "$mfail Unable to open $win321$datadir/facts.dat :$!\n";
  @facts=<FACTSFILE>;
  for(@facts){chomp;}
  close (FACTSFILE) or die "$mfail Cannot close facts: $!\n";
}

if (-e "$win321$datadir/denies.dat") { 
  open (FACTSFILE,"$win321$datadir/denies.dat") or die "$mfail Unable to open $win321$datadir/denies.dat :$!\n";
  @deny=<FACTSFILE>;
  for(@deny){chomp;}
  close (FACTSFILE) or die "$mfail Cannot close denies: $!\n";
}


if (-e "$win321$datadir/objects.dat") { 
  open (OBJECTSFILE,"$win321$datadir/objects.dat") or die "$mfail Unable to open $win321$datadir/objects.dat :$!\n";
  @objects=<OBJECTSFILE>;
  for(@objects){chomp;}
  close (OBJECTSFILE) or die "$mfail Cannot close objects: $!\n";
}


if (-e "$win321$datadir/owners.dat") {
  open (OWNERSFILE,"$win321$datadir/owners.dat") or die "$mfail Unable to open $win321$datadir/owners.dat :$!\n";
  @owners=<OWNERSFILE>;
  for(@owners){chomp;}
  close (OWNERSFILE) or die "$mfail Cannot close owners: $!\n";
}

if (-e "$win321$datadir/splitters.dat") {
  open (SPLITTERSFILE,"$win321$datadir/splitters.dat") or die "$mfail Unable to open $win321$datadir/splitters.dat :$!\n";
  @splitters=<SPLITTERSFILE>;
  for(@splitters){chomp;}
  close (SPLITTERSFILE) or die "$mfail Cannot close splitters: $!\n";
}

  print "       $mok (loaded " . ($#facts+1) ." factoids (" . ($#deny+1) . " denied))\n";

#print "There are " . ($#facts+1) . " factoids loaded, " . ($#msg+1) . " messages queued, " . ($#kicks+1) . " kick msgs loaded, " . ($#deny+1) . " factoids denied.\n";

#####################
# CONNECT TO SERVER #
#####################
print "Connecting to server...   ";
$remote = $server;
$port = $serverport;
if ($port =~ /\D/) { $port = getservbyname($port, 'tcp') }
$iaddr = inet_aton($remote) or die "$mfail (invalid host: $remote)\n";
$paddr = sockaddr_in($port,$iaddr);
$proto = getprotobyname('tcp');
socket (SOCK,PF_INET,SOCK_STREAM,$proto) or die "$mfail (socket error: $!)\n";
connect (SOCK, $paddr) or die "$mfail (connect error: $!)\n";
print "$mok (connected to ${server}:${serverport})\n";

$nl = chr(13);
$nl = $nl . chr(10);

$nicklist{lc($botname)} = '';

$lastpong = time();
$msgto = $channel;

snd ("USER $botname $botemail $botname :$bot_version_number (5w.fi)");

if ($botpass ne "") {
  snd ("NICK ${botname}|" . rand() * 1000000);
} else {
  snd ("NICK $botname");
}
#####################
# ALOITA SAIKEET    #
#####################
###########################################################################################
print("------- 5w tietoa konffista -------\n\r");
print("Postataan vote ja poll tulokset käsittelijälle $handler_votes\n\r");
####################################################################################
#### SET TOPIC #####
my $eventurl = "http://hallitus.5w.fi/events.xml";
my @eventTypes = ('Miitti','Hallituksen kokous','Opetus/Hack','Demo');
#setIrcTopic($eventurl);
my $CmdQueue = Thread::Queue->new(); # komennot tulee tahan puskuriin. Worker saie hakee yhden kerrallaan.
my $FbQueue = Thread::Queue->new(); # Facebook postaus komennot tulee tahan puskuriin. facebook saie hakee yhden kerrallaan.
print("Käynnistetään säikeet...");
my $thr = threads->create(\&worker); # kaynnista worker(pull tyyppinen, eli ei tee mitaan pyytamatta).
my $thr = threads->create(\&facebook); # kaynnista facebook toimintojen säie.
my $thr = threads->create(\&pusher); # kaynnista pusher(push tyyppinen, seuraa uusia tapahtumia).
my $thr = threads->create(\&setIrcTopic); # kaynnista setIrcTopic, paivittaa myös facebookin.
print("OK\n\r");
my $pushersleep = 30; # pusher saikeelle.
my @data;
$guser = $channel;
my $project = new XML::Simple;
my $datalimit = 50; # vain 50 viimeisinta tapahtumaa sailotaan

sub setIrcTopic {
my $link= $eventurl;
my $fb_msg;
my $temp;
my $toirc="false";
my $tofb="false";
my $runfirst = "true";
threads->detach();   # Irrota. saie on nyt omillaan, muu ohjelma jatkaa
    while (1) {
 
	eval{
 
	    
	    my $eventType = "";
	    my $eventTypeNro = "";
	    my $eventTitle = "";
	    my $eventTime = "";
	    my $eventPlace = "";
	    my $eventDesc = "";
	    my $msgsuffix = "||  mode 5w :: visit http://5w.fi";
	    
	    my $browser = LWP::UserAgent->new;
	    my $response = $browser->get( $link );
	    my $xml = $response->content;
	    my $parser = XML::LibXML->new();
	    my $feede = $parser->load_xml(location=> $link);
	    my $root = $feede->getDocumentElement;
	    my $elname = $root -> getName();
	    my @curList  = $root->getElementsByTagName('updated');
	    my $curListDate = @curList[0]->getFirstChild->getData;
	    
	    if($curListDate eq $prevdate){

	    }else{
		@kids = $root -> childNodes();
		foreach $child(@kids) {
		    $elname = $child -> getName();
		    if($elname eq 'entry'){
			@atts = $child -> getAttributes();
			#print "elname = $elname (";
			foreach $at (@atts) {
			    $na = $at -> getName();
			    $va = $at -> getValue();
			    $eventTypeNro = $va;
			    #print " ${na}[$va] ";
			    $eventType = @eventTypes[$va];
			    my @title_node  = $child->getElementsByTagName('title');
			    $eventTitle = @title_node[0]->getFirstChild->getData;
			    
			    
			    my @time_node  = $child->getElementsByTagName('time');
			    $eventTime = @time_node[0]->getFirstChild->getData;
			    
			    my @place_node  = $child->getElementsByTagName('place');
			    $eventPlace = @place_node[0]->getFirstChild->getData;

			    my @desc_node  = $child->getElementsByTagName('description');
			    $eventDesc = "";
			    $eventDesc .= @desc_node[0]->getFirstChild->getData;
			    $eventDesc .= "";
			    my @link_nodes  = $child->getElementsByTagName('link');
			    
			    $temp = $channel . " : ".$eventTime." [".$eventType."]:". $eventTitle ." (". $eventPlace .") ".$msgsuffix;
			    my $temp_fb = $eventTime." [".$eventType."]:". $eventTitle ." Paikka:". $eventPlace .". Kuvaus tapahtumasta: ";
			    use Encode qw/encode decode/;
			    $fb_msg = encode("iso-8859-1", $temp_fb);
                            $fb_msg .= $eventDesc;
			    $tofb = "false";
			    $toirc = "false";
			    foreach $link(@link_nodes) {
				$rel = $link->getAttribute('rel');
				printf("rel = ".$rel."\n\r");
				if($rel eq "irc"){
                                    $toirc = "true";
				    $prevdate = $curListDate;
				}
				elsif ($rel eq "facebook") {
				    $tofb = "true";
				    $prevdate = $curListDate;
				}
				else{
				    
				}
			    }
			}
		    }
		}
	    }
            if($firstrun eq "true"){
		$firstrun = "false";
		$tofb = "false";
		$toirc = "false";
	    }else{

		if(($toirc eq "true") && ($prevdate ne "empty")){
		    $toirc = "false";
		    snd ("TOPIC ".$temp);
		}
		if(($tofb eq "true") && ($prevdate ne "empty")){
		    $msgto = "kyber";
		    my $temptitle = $eventTime." [".$eventType."]:".$eventTitle;
		    $FbQueue->enqueue("event#.#".$eventTypeNro."#.#kyber#.#http://5w.fi#.#".$eventDesc."#.#".$temptitle."#.#".$eventTitle."#.#".$eventPlace);
		    $tofb = "false";
		}
	    }

            printf("sleep 15 sek...\n\r");

	    sleep(15); 

	} or do { 
	  printf("Something went wrong...\n\r");  
	  $tofb = "false";
	  $toirc = "false";
	}
	
    }
}
sub facebook {
    threads->detach();   # Irrota. saie on nyt omillaan, muu ohjelma jatkaa
    while (1) {
	# hae seuraava kasky jonosta...
	while (my $CmdElement = $FbQueue->dequeue()) {
	    my @cmd_parts = split('#.#', $CmdElement);
	    switch (@cmd_parts[0]) {
		# kirjoittaa ryhmän Facebookin seinälle
		case "wall"{
		    my $message = $cmd_parts[2];
		    my $userto = $cmd_parts[1];
		    
		    my $command = "fbcmd wallpost 266052117082 '".$message."'";
		    my $returncode = system("$command");
                    #    print($returncode);
		    $msgto = $userto;
		    print("facebook -> wall, msgto = $msgto\n\r");
		    if($returncode == 0){
			sndtxt("Viestisi ' $message ' on lisätty seinälle: http://www.facebook.com/group.php?gid=266052117082");
		    }else{
			sndtxt("Jotain meni pieleen viestin lisäämisessä ryhmän FB seinälle...");
		    }
		}
		# Lisää linkinryhmän Facebook seinälle.
                # $FbQueue->enqueue("link#.#".$msgto."#.#".@items[0]."#.#".@items[1]);
		case "link"{
		    if(scalar(@cmd_parts) != 4){
			print("Löytyi väärä määrä parametreja.");
			sndtxt("Antamasi komento fb-link sisältää väärän määrän parametreja. Tarkista komento.");
			
		    }else{
			
			my $userto = $cmd_parts[1];
			my $link = $cmd_parts[2];
			my $message = $cmd_parts[3];
			my $linkcopy = $link;
			
			my $url = $link;
			$link =~ s/^\s+//;
			my $html = get ($url);
			my $title = "";
			my $desc = $html;
			my $h1 =  get_heading($html);
			my $ptitle =  get_title($html);
			print("heading = ".$h1."\n\r");
			
			print("ptitle = ".$ptitle."\n\r");
			## TITLE ######################################
			($title) = ($html =~ m#<title>\s*(.*?)\s*</title>#is);
			if($ptitle != "empty"){$title = $ptitle;}
			if (!$title){$title = "Avaa ja lue!";}

			my $tlen = length($title);
			if($tlen >90){
			    $title = substr($title,0,90)."...";
			}
			$title = clean_string($title);
#			$title = substr($title,1,$tlen-1);
			## DESC ######################################
			(my $description) = ($desc =~ m#<meta name="description" content=\s*(.*?)\s*</meta>#is);
			# print($description."\n\r");
			if (!$description){$description = $message;}
			$description = get_meta_desc($html);
			if (!$description){$description = $message;}
			$description = clean_string($description);
			my $img_src = get_image($html);
			if ($link =~ m/5w.fi/){$img_src="http://5w.fi/data/logo/logo-90x38.png";}

			#my $command = "fbcmd WALLPOST 266052117082 IMG '$message' '$img_src' '$title' '$link' '$description ($userto | irc.freenode.org#5w | http://5w.fi)'";	
			my $command = "fbcmd WALLPOST 266052117082 IMG \"$message\" \"$img_src\" \"$link\" \"$title\" \"$link\" \"$description\" \"($userto | irc.freenode.org#5w | Visit hackerspace at http://5w.fi)\"";
			print($command."\n\r");
			
			my $returncode = system("$command");
			$msgto = $userto;

			if($returncode == 0){
			    sndtxt("Linkkisi ' $message ' on lisätty seinälle: http://www.facebook.com/group.php?gid=266052117082");
			}else{
			    sndtxt("Uups. Jotain meni pieleen linkin lisäämisessä ryhmän FB seinälle...");
			}
		    }
		}
		# Lisää event linkinryhmän Facebook seinälle.
                # $FbQueue->enqueue("event#.#[type]#.#".$msgto."#.#".@items[0]."#.#".@items[1]);
		case "event"{
		    if(scalar(@cmd_parts) != 8){
			print("Löytyi väärä määrä parametreja.");
			sndtxt("Antamasi komento fb-link(event) sisältää väärän määrän parametreja. Tarkista komento.");
			
		    }else{
			my $type = $cmd_parts[1];
                        my $img_src = "http://5w.fi/data/events/images/".$type.".png"; 
			my $temptitle3 = $cmd_parts[6];
			my $loc = "Paikka: ".$cmd_parts[7];
                        my $title = @eventTypes[$type].": ".$temptitle3;
			my $userto = $cmd_parts[2];
		
			my $link = $cmd_parts[3];
			my $message = $cmd_parts[4];
			my $temptitle2 = $cmd_parts[5];
		
			my $command = "fbcmd WALLPOST 266052117082 IMG \"$message\" \"$img_src\" \"$link\" \"$title\" \"$link\" \"$temptitle2\" \"$loc\"";
			print($command."\n\r");
			
			my $returncode = system("$command");
			$msgto = $userto;

			if($returncode == 0){
			    sndtxt("Event ' $message ' on lisätty seinälle: http://www.facebook.com/group.php?gid=266052117082");
			}else{
			    sndtxt("Uups. Jotain meni pieleen eventin lisäämisessä ryhmän FB seinälle...");
			}
		    }
		}
		else{ 
		    # print "none of previous case not true\n\r"; 
		    sndtxt("Uups! facebook säie ei tunnistanut komentoa ".@cmd_parts[0]);
		}
		
	    }  
	    sleep(5); # take a nap
	}
    }
}

sub get_heading {
      my $tree = HTML::TreeBuilder->new;
      $tree->parse($_[0]);
      my $heading;
      my $h1 = $tree->look_down('_tag', 'h1');
      if ($h1) {
          $heading = $h1->as_text;
      } else {
        #  warn "No heading in $_[0]";
      }
      ## another look
      my @headings = $tree->find_by_tag_name('h2');
      print("Found: ".scalar(@headings)."\n\r");

      $tree->delete;     # clear memory
      return clean_string($heading);
  }

sub get_meta_desc {
      my $tree = HTML::TreeBuilder->new;
      $tree->parse($_[0]);
      my $desc;
      foreach my $meta ($tree->find_by_tag_name('meta')) {
	  my $name = $meta->attr('name');
	  if($name eq 'description') {
	      $desc = $meta->attr('content');
	  }
	  if($name eq 'Description') {
	      $desc = $meta->attr('content');
	  }
      }
      print("Desc = ".$desc."\n\r");
      return clean_string($desc);
}

sub get_title {
      my $tree = HTML::TreeBuilder->new;
      $tree->parse($_[0]);
      my $retstr;
      my $title = $tree->look_down('_tag', 'title');
      if ($title) {
          $retstr = $title->as_text;
	  print("Found title element with content: $retstr \n\r");
      } else {
          warn "No title in $_[0]";
	  $retstr = "empty";
      }
      $tree->delete;     # clear memory
      return clean_string($retstr);
  }
sub get_image {
      my $tree = HTML::TreeBuilder->new;
      $tree->parse($_[0]);
      my $retstr ="http://5w.fi/data/logo/logo-90x38.png";
      foreach my $img ($tree->find_by_tag_name('img')) {
	  my $src = $img->attr('src');
	  my $str = substr($src,0,5);
#	  print("img src= ".$str."\n\r");
	  if($str eq "http:"){
	      getstore($src,'temp.img');
	      my ($size_x, $size_y) = Image::Size::imgsize("temp.img");	      
	      print ("Image is: $size_y x $size_x (height x width)\n\r");
	      if(($size_x < 351) && ($size_x > 30) && ($size_y < 351) && ($size_y > 30)){
		  $retstr = $src;
		  print("retstr = ".$retstr."\n\r");
		  last;
	      }
	  }
	  
      }
      
      return $retstr;
}

sub clean_string {
     $str = shift;
     $str =~ s/'/\'/g;
     $str =~ s/|//g;
     $str =~ s/^\s+//;
     $str =~ s/\n//;
     $str =~ s/\r//;
     return $str;
}

sub worker {
    threads->detach();   # Irrota. saie on nyt omillaan, muu ohjelma jatkaa
    while (1) {
	# hae seuraava kasky jonosta...
	while (my $CmdElement = $CmdQueue->dequeue()) {
	    my @cmd_parts = split(' ', $CmdElement);
	    switch (@cmd_parts[0]) {
		# hakee projektiehdotuksia annetun parametrin maaran, maks 5
		case "projektit"{
		    my $count = $cmd_parts[1];
		    my $userto = $cmd_parts[2];
		    $msgto = $userto;
		     print("projektit -> worker: msgto = $msgto\n\r");
		    getProjects($count, $userto);
		}
		# hakee projektin tiedot annetun parametrin id:sta. Jos 3 param, haetaan sen mukaisesti, muuten kuvaus
		case "projekti"	{ 
		    my $pid = $cmd_parts[1];
		    my $pitem = $cmd_parts[2];
		    my $user = $cmd_parts[3];
		    
		    my $ilen = length($pitem);
		 #   if($ilen > 3){
		    #$guser = $user;
		  #  print("worker: msgto = $msgto\n\r");
			getProjectDetail($pid, $pitem, $user);
		#    }else{
		#	sndtxt("Uups! Worker säie ei tunnistanut komentoa projektin tietojen haussa...");
		#    }
		}
		# hakee projektin tiedot annetun parametrin id:sta. Jos 3 param, haetaan sen mukaisesti, muuten kuvaus
		case "projektidetail"	{ 
		    my $pid = $cmd_parts[1];
		    my $user = $cmd_parts[2];
		  #  my $ilen = length($pitem);
		 #   if($ilen > 3){
		    $msgto = $user;
		 #   print("worker- projektidetail: msgto = $msgto\n\r");
		    getProjectDetailCombined($pid, $user);
		    #getProjectDetailCombined($pid);
		#    }else{
		#	sndtxt("Uups! Worker säie ei tunnistanut komentoa projektin tietojen haussa...");
		#    }
		}
		# hakee annetun parametrin mukaisia projekteja 3 kpl
		case "projektit-moodi"	{ 
		    $user = $cmd_parts[2];
		    $msgto = $user;
		    getProjectsOfType($cmd_parts[1], $msgto);
		#    print("worker- projekti-moodi: msgto = $msgto\n\r");
		}
                # hakee hallituksen kokouksen asialistan palvelimelta
		case "hae-kokous"	{ 
		    $user = $cmd_parts[1];
		    $msgto = $user;

		    getHallitusKokousTxt($msgto);
		#    print("worker- hae-kokous: msgto = $msgto\n\r");
		}
                # hakee annetun parametrin mukaisia projekteja 3 kpl
		case "uutiset"	{
#		    sndtxt("Worker uutiset");
		    my $param1 = $cmd_parts[1];
		    my $user = $cmd_parts[2];
		    $msgto = $user;
		    if($param1 > 0){
#			sndtxt(" param1 gt 0");
			getNews($param1);
		    }else{
			getNews("3");
		    }
		}
		else{ 
		  #  print "previous case not true"; 
		    sndtxt("Uups! Worker säie ei tunnistanut komentoa ".@cmd_parts[0]);
		}
	    }  
	    sleep(3); # take a nap
        }
    }
}

sub getHallitusKokousTxt {
    my $user = shift;
    my $url = $conf_file_asialista;
    my $asialista = get($url);
    print("getHallitusKokousTxt: $url\n\r");
    $asialista =~ s/\r|\n/#.#/g;
    my @lines = split('#.#', $asialista);
    foreach my $line (@lines){
	sndtxt($line);
	if($user eq $channel){
	    sleep(5);
	}else{
	    sleep(2);
	}
    }
    snd("EOF");
}
sub pusher {
    my $i = 0;
    my $secs = 300;
    my $run = 0;
    my $url;
    my $data_file= "feeds.txt";
    open(DAT, $data_file) || die("Could not open feed-list file!\n\r");
    @rssfiles=<DAT>;
    my $address = pop(@rssfiles);
    my @feednros = ("1","2","3","4","10"); 
#    my @data = ("1", "3"); # kaikki aikaisemmat tapahtumat, uutiset yms. 
   
    threads->detach();   # Irrota. saie on nyt omillaan, muu ohjelma jatkaa
#    print("raw-address = ".$address."\n\r"); # ilman numeroa
    while (1){
	if($run == 0){
	    sleep(30); # odota etta paastaan kanavalle, riittanee 45 sek...
#	    print "\n\rpusher inits database...from\n\r";
	    $run++;
	    foreach $one (@feednros) {
#		printf("datasize = ".scalar(@data)."\n\r");
		my $str = substr($address,0,scalar($address)-1); # chomp tyhjas koko rivin?!
		$url = $str.$one; # no niin, siina on feed url
		my $feed;
		######### LUE FEEDIT ##################################################
		eval {
		    $feed = XML::Feed->parse(URI->new($url)) or die XML::Feed->errstr;
		    putData($feed);
		  #  print ("address: ".$url." in database\n\r");  
		    
		    1;
		   
		} or do {  
		    my $err = substr($@,0,index($@, "at bitch.pl"));
		   # printf($url." luku epäonnistui. Syy: ".$err."\n\r");
		    next;
		};
		 
		#######################################################################
	    }
#	    sndtxt("NOTICE $adminnick : ".$str.@feednros." sisällöt lisätty tietokantaan");
#	    sndtxt(substr($address,0,scalar($address)-1).join(", ",@feednros)." sisällöt lisätty tietokantaan");
	    snd("NOTICE kyb3R : ".substr($address,0,scalar($address)-1).join(", ",@feednros)." sisällöt lisätty tietokantaan");
	}else{
	    foreach $one (@feednros) {
		my $str = substr($address,0,scalar($address)-1); # chomp tyhjas koko rivin?!
		$url = $str.$one; # no niin, siina on feed url
		######### LUE UUDET FEEDIT ############################################
		eval {
		    $feed = XML::Feed->parse(URI->new($url)) or die XML::Feed->errstr;
		    my @temp = putTempData($feed);
		    postData(\@temp);
		    
		    
		    1;
		}
		or do {  
		    my $err = substr($@,0,index($@, "at bitch.pl"));
		    print("luku epäonnistui. Syy: ".$err."\n\r");
		    snd("NOTICE kyb3R : Atom ongelma: pusher ei pystynyt lukemaan: ".$url.", ".$err);
		    snd("NOTICE leonarven : Atom ongelma: pusher ei pystynyt lukemaan: ".$url.", ".$err);
		   # sndtxt("Atom ongelma: pusher ei pystynyt lukemaan: ".$url.", ".$err);
		    next;
		};
		
	    }
	    #snd("NOTICE kyb3R : pusher -säie päivitti kantansa");
	}
	sleep($secs); # uneksi vahan, ettei turhaan suoritella
	
    }   
}

sub postData {

my $tmpref=shift;
my @tmp=@$tmpref;
    #print("postData".scalar(@tmp)."\n\r");
    foreach my $item (@tmp){
	## onkos lista nyt liian iso vai ei?
	my $datasize = scalar(@data);
	if($datasize > $datalimit){
	#    pop (@data); 
	#    pop (@data); # otetaan pari samantien pois LOPUSTA 
	#    print("datasize '$datasize', poistettiin arrays: data 2 viimeista...\n\r");
	}
	#print("item = ".$item."\n\r");
	foreach my $old (@data) {
	    #print("old = ".$old."\n\r");
	    if ( $old eq $item ) {
	#	print ("Loytyi vanhoista (".$old."), annetaan olla...\n\r");
	    }else{
		push(@data, $item);
		unshift (@data, $item); # lisaa ALKUUN aina uusin  
		if(length($item) > 2){
		    #print ("Uusi! (".$item.") tulostetaan...\n\r");
		    if($lurkki_hiljaa != 1){
			#sndtxt("uusi: ".$item);
		    }
		    
		    sleep(5); # ota henkea vahan, rankkaa hommaa
		}
	    }
	}
    }
    
}


sub putData {
    my $datain=shift; # XML data
    $chantitle = $datain->title;
    my @entries = $datain->entries; 
    foreach my $entry (@entries) { 
	my @links = $entry->link(); 
	my $outlink = @links[0];
	### TITLE ####
	my $entrytitle = $entry->title;
	my $t_len = length($entrytitle);
	my @splitted = split(" ",$entrytitle);
	my $max_len = 30;
	my $prev = "";
	my $next = "";
	my $title = "";
	my $dots = "..................................";
	if($t_len > $max_len){
	    foreach my $word (@splitted) {
		$prev = $next;
		$next = $next." ".$word;
		if(length($next)< $max_len){
		    $title = $next;
		}else{
		    $title = $prev."...";
		}
	    }
	}else{
	    $title = $entrytitle;
	}
	my $str = "[".$chantitle."] ".$title." ".$outlink;
#	print("putData = ".scalar(@data)."\n\r");
	
	unshift(@data, $str); # lisaa ALKUUN aina uusin  

    } 
}

sub putTempData {
    my $data=shift; # XML data
    @temp;
    $chantitle = $data->title;
    my @entries = $data->entries; 
    foreach my $entry (@entries) { 
	print ("putTempData: ".scalar(@entries)."\n\r");
	my @links = $entry->link(); 
	my $outlink = @links[0];
	### TITLE ####
	my $entrytitle = $entry->title;
	my $t_len = length($entrytitle);
	my @splitted = split(" ",$entrytitle);
	my $max_len = 30;
	my $prev = "";
	my $next = "";
	my $title = "";
	my $dots = "..................................";
	if($t_len > $max_len){
	    foreach my $word (@splitted) {
		$prev = $next;
		$next = $next." ".$word;
		if(length($next)< $max_len){
		    $title = $next;
		}else{
		    $title = $prev."...";
		}
	    }
	}else{
	    $title = $entrytitle;
	}
	my $str = "[".$chantitle."] ".$title." ".$outlink;
#	print($str);
#	foreach my $old (@temp) {
#	    print($old."\n\r");
#	    if ( $old eq $str ) {
#		print("str loytyi jo @tempista\n\r");
#	    }else{
		unshift(@temp, $str);
#		push(@temp, $str);
#		print($str."\n\r");
#	    }
#	}
#print("\n\rtemp size = ".scalar(@temp)."\n\r");
    } 
    
    return @temp;
}


sub closeWorkers {
    $workers = threads->list(); # TODO: Saa tehda.
    
}

sub pushQueue{
    my $cmd=shift;
    $CmdQueue->enqueue($cmd);
}

sub getProjectsOfType {
#print("guser = ".$guser); 
    my $type=shift;
    my @linkList;
    my @newList;
    my $count = 3;
    my $linkdata= "feeds.txt";
    my $data_file= $linkdata;
    open(DAT, $data_file) || die("Could not open file!\n\r");
    @rssfiles=<DAT>;
    close(DAT);

# parsi XML data, joka samalla lisaa kaikki itemit listaan(linkList)
    foreach $link (@rssfiles) {
	# hae feed tai sitten tyhja -> ilmoita epaonnistumisesta
	eval {
	    $feed = XML::Feed->parse(URI->new($link.$type)) or die XML::Feed->errstr;
	    1;
        } or do {  
	    my $f = $link;
	    sndtxt("Atom-feed: ".$f); 
	    my $err = substr($@,0,index($@, "at bitch.pl"));
	    sndtxt("luku epäonnistui. Syy: ".$err);
	    next;
	};

	#printf($link.$type);
	my $chantitle = "";
	my $rsslink = "NotFoundInFile";
	my $now = localtime time;
	$chantitle = $feed->title;
	#sndtxt("[".$now."]Fetching: ".$chantitle);
	
	my @entries = $feed->entries; 
	foreach my $entry (@entries) { 
	    my @links = $entry->link(); 
	    my $outlink = @links[0];
	    my $pid = substr($outlink,index($outlink, 'p=')+2,length($outlink));

	    ### TITLE ####
	    my $entrytitle = $entry->title;
	    my $t_len = length($entrytitle);
	    my @splitted = split(" ",$entrytitle);
	    my $max_len = 30;
	    my $prev = "";
	    my $next = "";
	    my $title = "";
	    my $dots = "..................................";
	    if($t_len > $max_len){
		foreach my $word (@splitted) {
		    $prev = $next;
		    $next = $next." ".$word;
		    if(length($next)< $max_len){
			$title = $next;
		    }else{
			$title = $prev."...";
			#my $fill = $max_len-length($title);
			#$title = $title.substr($dots, 0,$fill);
		    }
		}
	    }else{
		$title = $entrytitle;
	    }
	    ###

#	    my $str = "[".$chantitle."] ".$entrytitle."-".$outlink;
	    my $str = "[".$chantitle.":".$pid."] \002".$title."\002 ".$outlink;
	    if ( grep { $_ eq $str} @newList ) {
	    }else{
		push(@newList, $str);
	    }
	} 

    } # //foreach $link
    #
    ## tulosta kanavalle
    if(scalar(@newList)> 0){
	print($msgto);
	$i = 0;
	foreach $item (@newList){
	    if($count>$i){
		#$msgto = $guser;
		#$msgto = $guser;
		print("msgto = ".$msgto."\n\r");
#		sndtxt ($item);
		sndtxt($item);
		++$i;
		if($msgto eq $channel){sleep(5);}
	    }
	}
    }else{
	sndtxt("Ei löytynyt yhtään projektia :( Rip rap tekemään...");
    }
    
}
    
sub getProjects { 
    my $count=shift;
    my @linkList;
    my @newList;
    my $linkdata= "feeds.txt";
    my $data_file= $linkdata;
    open(DAT, $data_file) || die("Could not open file!\n\r");
    @rssfiles=<DAT>;
    close(DAT);

# parsi XML data, joka samalla lisaa kaikki itemit listaan(linkList)
    foreach $link (@rssfiles) {
	# hae feed tai sitten tyhja -> ilmoita epaonnistumisesta
	eval {
	    $feed = XML::Feed->parse(URI->new($link."1")) or die XML::Feed->errstr;
	    1;
        } or do {  
	    my $f = $link;
	    sndtxt("Atom-feed: ".$f); 
	    my $err = substr($@,0,index($@, "at bitch.pl"));
	    sndtxt("luku epäonnistui. Syy: ".$err);
	    next;
	};

	my $chantitle = "";
	my $rsslink = "NotFoundInFile";
	my $now = localtime time;
	$chantitle = $feed->title;
	#sndtxt("[".$now."]Fetching: ".$chantitle);
	
	my @entries = $feed->entries; 
	foreach my $entry (@entries) { 
	    my @links = $entry->link(); 
	    my $outlink = @links[0];
	    # ota id linkin lopusta
	    my $pid = substr($outlink,index($outlink, 'p=')+2,length($outlink));

	    ### TITLE ####
	    my $entrytitle = $entry->title;
	    my $t_len = length($entrytitle);
	    my @splitted = split(" ",$entrytitle);
	    my $max_len = 30;
	    my $prev = "";
	    my $next = "";
	    my $title = "";
	    my $dots = "..................................";
	    if($t_len > $max_len){
		foreach my $word (@splitted) {
		    $prev = $next;
		    $next = $next." ".$word;
		    if(length($next)< $max_len){
			$title = $next;
		    }else{
			$title = $prev."...";
			#my $fill = $max_len-length($title);
			#$title = $title.substr($dots, 0,$fill);
		    }
		}
	    }else{
		$title = $entrytitle;
	    }
	    ###

#	    my $str = "[".$chantitle."] ".$entrytitle."-".$outlink;
	    my $str = "[".$chantitle.":".$pid."] \002".$title."\002 ".$outlink;
	    if ( grep { $_ eq $str} @newList ) {
	    }else{
		push(@newList, $str);
	    }
	} 
    } # //foreach $link
    if(scalar(@newList)> 0){
	$i = 0;
	#$msgto = $guser;
	foreach $item (@newList){
	    if($count>$i){	
#		snd("PRIVMSG ".$nickname." :  ".$item);
		sndtxt($item);
		++$i;
		sleep(5);
	    }
	}
    }else{
	sndtxt("Ei löytynyt yhtään projektia :( Rip rap tekemään...");
    }
}
    
sub getNews { 
    my $count=shift;
    my @linkList;
    my @newList;
    my $linkdata= "feeds.txt";
    my $data_file= $linkdata;
    open(DAT, $data_file) || die("Could not open feed-list file!\n\r");
    @rssfiles=<DAT>;
    close(DAT);

# parsi XML data, joka samalla lisaa kaikki itemit listaan(linkList)
    foreach $link (@rssfiles) {
	# hae feed tai sitten tyhja -> ilmoita epaonnistumisesta
	eval {
	    $feed = XML::Feed->parse(URI->new($link."10")) or die XML::Feed->errstr;
	    1;
        } or do {  
	    my $f = $link;
	    sndtxt("Atom-feed: ".$f."10"); 
	    my $err = substr($@,0,index($@, "at bitch.pl"));
	    sndtxt("luku epäonnistui. Syy: ".$err);
	    next;
	};
	my $chantitle = "";
	my $rsslink = "NotFoundInFile";
	my $now = localtime time;
	$chantitle = $feed->title;
#	$chantitle = "Uutiset";
#	sndtxt("[".$now."]Fetching: ".$chantitle);
	
	my @entries = $feed->entries; 
	foreach my $entry (@entries) { 
	    my @links = $entry->link(); 
	    my $outlink = @links[0];
	    ### TITLE ####
	    my $entrytitle = $entry->title;
	    my $t_len = length($entrytitle);
	    my @splitted = split(" ",$entrytitle);
	    my $max_len = 30;
	    my $prev = "";
	    my $next = "";
	    my $title = "";
	    my $dots = "..................................";
	    if($t_len > $max_len){
		foreach my $word (@splitted) {
		    $prev = $next;
		    $next = $next." ".$word;
		    if(length($next)< $max_len){
			$title = $next;
		    }else{
			$title = $prev."...";
		    }
		}
	    }else{
		$title = $entrytitle;
	    }
	    my $str = "[".$chantitle."] ".$title." ".$outlink;
	    if ( grep { $_ eq $str} @newList ) {
	    }else{
		push(@newList, $str);
	    }
	} 
    } # //foreach $link
    if(scalar(@newList)> 0){
	$i = 0;
	my $prevurl;
	foreach $item (@newList){
	    if($count>$i){
	
		my $newurl = "http".substr($item, index($item,'http:')+4,length($item));
		my $part1 = substr($item, 0, index($item,'http:'));
		if($newurl eq $prevurl){
		    sndtxt("  ".$part1);
		    if($msgto eq $channel){sleep(5);}
		}else{
		    
		    $prevurl = $newurl;
		    sndtxt("  ".$prevurl);
		    sndtxt("  ".$part1);
		    if($msgto eq $channel){sleep(5);}
		}
		#sndtxt("  ".$part1);
		#sndtxt("  ".$part2);
		++$i;
	    }
	}
    }else{
	sndtxt("Ei löytynyt yhtään uutista tai tapahtumaa.");
    }
}

sub getProjectDetail{
#    my $item=shift; # projektin id
    my $pid = $_[0];
    my $item = $_[1];
    my $cuser = $_[2];
    my $urli = "http://5w.fi/projektit/feed.php?p=".$pid;
    $msgto = $cuser;

    print("getProjectDetail: msgto = $msgto\n\r");
#    my $testload = get($urli);
#    my $testlen = length($testload);
#    print ("testlen = ".$testlen."\n\r");
    if (is_error(get($urli))) {
	sndtxt("Peelo! Ei ole sellaista projektia, jonka id = $pid");
    }
    eval {
	my $parser = XML::DOM::Parser->new();
	print("item = ".$item);
	my $doc = $parser->parsefile($urli);
	my $feed = $doc->getFirstChild;
	# pitää hakea toinen title elementti, koska eka on kanavan otsikko
	my $ptitle = $feed->getElementsByTagName("title")->item(1)->getFirstChild->getData;
	my $what = $feed->getElementsByTagName("what")->item(0)->getFirstChild->getData;
	my $when = $feed->getElementsByTagName("when")->item(0)->getFirstChild->getData;
	my $where = $feed->getElementsByTagName("where")->item(0)->getFirstChild->getData;
	my $why = $feed->getElementsByTagName("why")->item(0)->getFirstChild->getData;
	my $who = $feed->getElementsByTagName("who")->item(0)->getFirstChild->getData;
	my $how = $feed->getElementsByTagName("how")->item(0)->getFirstChild->getData;
	$doc->dispose; # tyhjää, ettei keräänny muistiin
#	snd("MSG $nickname: \002".strip_string($ptitle)."\002: ".strip_string($why));
#	snd("MSG $nickname: \002".strip_string($ptitle)."\002: ".strip_string($when));
#	sndtxt("NOTICE ".strip_string($ptitle)."\002: ".strip_string($who));
#	snd("NOTICE ${nickname} : tietoa tulee");
	switch ($item) {
		case "kuvaus"	{ 
		    sndtxt("\002".strip_string($ptitle)."\002: ".strip_string($what));
		}
		case "miten"	{ 
		    sndtxt("\002".strip_string($ptitle)."\002: ".strip_string($how));
		}
		case "kuka"	{ 
		    sndtxt("\002".strip_string($ptitle)."\002: ".strip_string($who));
		}
		case "koska"	{ 
		    sndtxt("\002".strip_string($ptitle)."\002: ".strip_string($when));
		}
		case "miksi"	{ 
		    sndtxt("\002".strip_string($ptitle)."\002: ".strip_string($why));
		}
		else{ 
	#	    sndtxt("Uups! en tunnistanut antamaasi kentän nimeä: $item (vaihtoehdot: kuvaus | miten | kuka)");
		}
	}
	1;
    } or do { 
	my $err = substr($@,0,index($@, "at bitch.pl"));
	#sndtxt("luku epäonnistui. Syy: ".$err);
	sndtxt("Ei ole sellaista projektia, jonka id = $pid");

    }

}

sub getProjectDetailCombined{
#    my $item=shift; # projektin id
    my $pid = $_[0];
    my $user = $_[1];
    #$msgto = $user;
print("getProjectDetailCombined: user = $user\n\r");
print("getProjectDetailCombined: msgto = $msgto\n\r");
    my $urli = "http://5w.fi/projektit/feed.php?p=".$pid;
#    my $testload = get($urli);
#    my $testlen = length($testload);
#    print ("testlen = ".$testlen."\n\r");
    if (is_error(get($urli))) {
	sndtxt("Peelo! Ei ole sellaista projektia, jonka id = $pid");
    }
    eval {
	my $parser = XML::DOM::Parser->new();
#	print("item = ".$item);
	my $doc = $parser->parsefile($urli);
	my $feed = $doc->getFirstChild;
	# pitää hakea toinen title elementti, koska eka (0) on kanavan otsikko
	my $ptitle = $feed->getElementsByTagName("title")->item(1)->getFirstChild->getData;
	my $what = $feed->getElementsByTagName("what")->item(0)->getFirstChild->getData;
	my $when = $feed->getElementsByTagName("when")->item(0)->getFirstChild->getData;
	my $where = $feed->getElementsByTagName("where")->item(0)->getFirstChild->getData;
	my $why = $feed->getElementsByTagName("why")->item(0)->getFirstChild->getData;
	my $who = $feed->getElementsByTagName("who")->item(0)->getFirstChild->getData;
	my $how = $feed->getElementsByTagName("how")->item(0)->getFirstChild->getData;
	$doc->dispose; # tyhjää, ettei keräänny muistiin
	sndtxt("Nimi: ".strip_string($ptitle));
	if($msgto eq $channel){sleep(5);}
	sndtxt("Miksi: ".strip_string($why));
	if($msgto eq $channel){sleep(5);}
	sndtxt("Kuvaus: ".strip_string($what));
	if($msgto eq $channel){sleep(5);}
	sndtxt("Miten: ".strip_string($how));
	if($msgto eq $channel){sleep(5);}
	sndtxt("Osallistujat: ".strip_string($who));

	1;
    } or do { 
	my $err = substr($@,0,index($@, "at bitch.pl"));
	#sndtxt("luku epäonnistui. Syy: ".$err);
	sndtxt("Ei ole sellaista projektia, jonka id = $pid");

    }

}

sub strip_string {
    my $str=shift;
    $str =~ s/^\s*//; 
    $str =~ s/\s*$//; 
    return $str;
}

sub parseXML {
my $link=shift;
#<?xml version="1.0" encoding="utf-8"?>
#<feed xmlns="http://www.w3.org/2005/Atom">
#	<title>Example Feed</title>
#	<subtitle>A subtitle.</subtitle>
#	<link href="http://example.org/feed/" rel="self" />
#	<link href="http://example.org/" />
#	<id>urn:uuid:60a76c80-d399-11d9-b91C-0003939e0af6</id>
#	<updated>2003-12-13T18:30:02Z</updated>
#	<author>
#		<name>John Doe</name>
#		<email>johndoe@example.com</email>
#	</author> 
#	<entry>
#		<title>Atom-Powered Robots Run Amok</title>
#		<link href="http://example.org/2003/12/13/atom03" />
#		<link rel="alternate" type="text/html" href="http://example3/atom03.html"/>
#		<link rel="edit" href="http://example.org/2003/12/13/atom03/edit"/>
#		<id>urn:uuid:1225c695-cfb8-4ebb-aaaa-80da344efa6a</id>
#		<updated>2003-12-13T18:30:02Z</updated>
#		<summary>Some text.</summary>
#	</entry> 
#</feed>
my $feed = XML::Feed->parse(URI->new($link)) or die XML::Feed->errstr;
my $chantitle = "";
my $rsslink = "NotFoundInFile";
my $now = localtime time;
 $chantitle = $feed->title;
printf "[".$now."]Fetching: ".$chantitle."\n\r";

 my @entries = $feed->entries; 
 foreach my $entry (@entries) { 
     my @links = $entry->link(); 
     my $outlink = @links[0];
     my $entrytitle = $entry->title;
     my $str = "[".$chantitle."] ".$entrytitle."-".$outlink;
#     printf $str."\n\r";
     if ( grep { $_ eq $str} @newList ) {
     }else{
	 push(@newList, $str);
     }
 } 
}

my @cmd_list = ("projektit [lkm]","uusin-ehdotus","tapahtumat-listaa [lkm]", "projektit-moodi [projektimoodi]", "seen", "projekti [id] [tieto]");
sub getMan {
    my $cmd = shift;
    switch ($cmd) {
		case "projektit"	{ 
		    sndtxt("\002$cmd\002 : projektit [lkm], jossa parametri lkm on lukumäärä. Lukumäärä voi olla 5 tai vähemmän.");
		}
		case "uusin-ehdotus"	{ 
		    sndtxt("\002$cmd\002 : uusin-ehdotus. Näyttää uusimman projektiehdotuksen otsikon ja linkin.");
		}
		case "tapahtumat-listaa"	{ 
		    sndtxt("\002$cmd\002 : tapahtumat-listaa [lkm]. Listaa uusimmat tapahtumat (otsikon ja linkin). Parametri lkm tapahtumien lukumäärä. Lukumäärä voi olla 5 tai vähemmän.");
		}
		case "projektit-moodi"	{ 
		    sndtxt("\002$cmd\002 : projektit-moodi [projektimoodi], jossa parametri voi olla: [ 1 ] = ehdotus [ 2 ] = aktiivinen [ 3 ] = passiivinen [ 4 ] = valmis ");
		}
		case "projekti"	{ 
		    sndtxt("\002$cmd\002 : projekti [id] [tieto], jossa ensimmäinen parametri on projektin id. Id:n näet projektilistauksessa jokaisen projektin tietojen alussa olevan [xxxxxx:id] sisältä. Toinen parametri (ei pakollinen) määrittää mikä tieto halutaan. Vaihtoehdot: kuka, koska, miten, miksi, kuvaus(oletus).");
		}	
		case "seen"	{ 
		    sndtxt("\002$cmd\002 : seen [nickname], jossa parametri on kyselyn kohteen nickname.");
		}	
		else{ 
		    sndtxt("Uups! en tunnistanut antamaasi komentokyselyä: $cmd. ");
		    my $string = join(', ', @cmd_list);
		    sndtxt("Komennot ovat: $string");
		}
	}
}

sub accessCtrl {
    my $checknick=shift;
    foreach my $item (@accessList){
	if($item eq $checknick){
	    return $item;
	}
    }

}


###########################################################################################
######################
#####################
####################
#START OF SOCKET READ LOOP
####################
#####################
######################


STARTOFLOOP: while ($line = <SOCK>) {

$lastmsgtime = time();
$line =~ s/\027-\036\004-\025\376\377//gi;

$silent = 0;  
$usermode = "";
undef $nickname;
undef $command;
undef $mtext;
undef $hostmask;

################
# EXTRACT VARS #
################
$hostmask = substr($line,index($line,":"));
$mtext = substr($line,index($line,":",index($line,":")+1)+1);
($hostmask, $command) = split(" ",substr($line,index($line,":")+1));
($nickname) = split("!",$hostmask);

@spacesplit = split(" ",$line);

$mtext =~ s/[\r|\n]//g;

#print("command = $command\n\r");
#print("mtext = $mtext\n\r");




####################

$guser = $nickname;
if ((uc($command) eq "PRIVMSG" || uc($command) eq "KICK") && lc($msgto) eq lc($channel) && !($chanstats_running)) {
  $action = 0;

  if (uc($command) eq "KICK") {
    $kicknick = $spacesplit[3];
    if ($mtext eq '') {
      $mtext = $nickname;
    }
    logline (4, $nickname, "*** $kicknick was kicked from $channel by $nickname ($mtext)");
    logline (5, $kicknick, "*** $kicknick was kicked from $channel by $nickname ($mtext)");
  } else {
    if ($mtext =~ /^\001ACTION .+\001$/) {
      logline (1, $nickname, $mtext);
    } elsif ($mtext =~ /^\Q$botname\E($botanswer)/i || ($mtext =~ /\?\?$/ && $noqq == 0)) {
      logline (2, $nickname, $mtext);
    } elsif ($mtext =~ /\?$/) {
      logline (3, $nickname, $mtext);
    } else {
      logline (0, $nickname, $mtext);
    }
  }
}

if ($mtext =~ /^\001.+\001$/) {
  $ctcp_hax = 1;
} else {
  $ctcp_hax = 0;
}

$line =~ s/\001//g;
$mtext =~ s/\001//g;

if ( ( uc($command) eq "PRIVMSG") || (uc($command) eq "NOTICE")) {
  $msgto = $spacesplit[2];
  if (lc($msgto) eq lc($botname)) {
#    $msgto = "PRIVMSG ".$nickname." : ";
#    print("priv msg to Lurkki\n\r");
#    $guser = $nickname;
#    print($msgto."\n\r");
#print("mtext = $mtext\n\r");
#    snd("PRIVMSG $nickname : joo joo");
    $mtext = $botname.": ".$mtext;
 #   $msgto = $nickname;
  }
} else {
    $msgto = $channel;
}

if ($noalarm && $chanstats_running) {
  &checkchanstats;
}

if ($command eq '001') {
  &NickServ;
}

if (uc($command) eq 'TOPIC' || uc($command) eq 'KICK') {
  next;
}

if (uc($command) eq 'MODE') {
  %nicklist = ();
  snd ("NAMES $channel");
}

if ( uc($command) eq "PRIVMSG" ) {
  $msgto = $spacesplit[2];
  if (lc($msgto) eq lc($botname)) {

      $msgto = $nickname;
#      print("msgto = $msgto");
  }
}



####################################################################################
# 5W EVENTS TO FILE
# Kirjoittaa viestit tiedostoon mita 
# halutaan kertoa muille emailin kautta
# Tiedosto: /tmp/emailmessages.txt
####################################################################################

$foundkw = 'false';
@kws = ('yhteisö','postilista','5wee','jakelu','miitti','yhteistyö','hub','näkötorni','jarkko','projekti','idea','uutta');


foreach $kw (@kws)
{
    if( index($line, $kw) != -1){
	print "kw found: $kw\n";
	$foundkw = 'true';
    }
} 
if ($foundkw eq 'true') {
    my $string = $line;
    open (MYFILE, '>>/tmp/emailmessages.txt');
    my $stime = time2str("%Y/%m/%d", time);
    print MYFILE "$stime $mtext";
    print MYFILE "\n\r";
    close (MYFILE);
    $foundkw = 'false';
}




#########################
####################
# IF CHANGING NICK #
####################
if (uc($command) eq 'NICK') {
  $nickname = $mtext;
  chomp($nickname);
  $nickname =~ s/[\r|\n]//g;
  $deltimer{lc($nickname)} = time()+60;
}

#####################
# MAINTAIN NICKLIST #
#####################
if ($command eq "353") {
  local @nicks = ();
  @nicks = split(/ /,$mtext);

  foreach $nnick (@nicks) {
    if (index($nnick,'+') != -1) {
      $nnick =~ s/\+//;
      $nicklist{lc($nnick)} = '+';
    }
    if (index($nnick,'@') != -1) {
      $nnick =~ s/\@//;
      $nicklist{lc($nnick)} = '@';
    }
  }
}

if (($command eq 'QUIT') || ($command eq 'PART')) {
  delete $nicklist{lc($nickname)};
}

##################################
#Enter results from WHO into IAL
##################################
if ($command eq "352") {
  if ($verbose eq "on") { print $line }
  $hosts{lc($spacesplit[7])} = $spacesplit[7] . "!" . $spacesplit[4] . "\@" . $spacesplit[5];
}

#######################################
#Add speaking/joining nick to host list
#######################################
$hosts{lc($nickname)} = $hostmask;

$usermode = $defaultmode;

if ($hostmask =~ $admin) {
  $usermode = " ADDFACTS DELFACTS DELALLFACTS SERVERMANIP ADMIN OP AV ";
}

##############
# LOOKUP AXS #
##############
foreach $checkmode ( keys (%access )) {
  $levels = $access{$checkmode};
  $checkmode = lc($checkmode);
  if (lc($hostmask) =~ /$checkmode/) {
    $usermode = uc(" $levels ");
    last;
  }
}

############################
# KILL ADMIN IMPERSONATORS #
############################
if ($adminnickservpass ne '') {
  if ( ( lc($nickname) eq lc($adminnick)) && ($hostmask !~ $admin) ) {
    snd ("PRIVMSG NickServ :GHOST $adminnick $adminnickservpass");
    next;
  }
}

####################
# ADD TO SEEN HASH #
####################
$curdate = localtime();
$sendate = substr($curdate,11);
$sendate = substr($sendate,0,index($sendate," "));
$seen{lc($nickname)} = time() . "\001$sendate";


#####################
# IGNORE IF IGNORED #
#####################
#$iponly = lc(substr($hosts{lc($nickname)},index($hosts{lc($nickname)},"\@")+1));

foreach $testregex (keys %ignore) {
  if ($hosts{lc($nickname)} =~ /$testregex/i) {
    if (($ignore{$testregex} - time) <= 0) {
      delete $ignore{$testregex};
    } else {
      next STARTOFLOOP;
    }
  }
}

###################
# SEARCH FOR MSGS #
###################
if ((uc($command) ne 'QUIT') && (uc($command) ne 'PART')) {
  for ($i = 0;$i < ($#msg+1);$i++) {
    ($recipient, $message, $sendtime) = split(/\001/, $msg[$i]);
    if (lc($nickname) eq lc($recipient)) {
      snd ("PRIVMSG $nickname :Sinulle on jätetty viesti: $message");
      splice (@msg,$i,1);
      $i--;
    }

    #expire messages over 4 weeks old
    if (time() - $sendtime > 2419200) {
      splice (@msg,$i,1);
      $i--;
    }
  }
}

if ( (uc($command) eq "QUIT") || (uc($command) eq "PART")) {
  next;
}

chomp $mtext;

#######################
# VERBOSE STATUS MSGS #
#######################
if ($verbose eq "on") {
  print "RAW : $line\n\n";
  print "TEXT: $mtext\n";
  print "MSG2: $msgto\n";
  print "NICK: $nickname ($hostmask)\n";
  print "CMND: $command\n";
  print "USER: $usermode\n\n";
}

###############################
# GET FIRST WORD (USED A LOT) #
###############################
if (index($mtext, " ") > -1) {
  $ffirstword = substr($mtext,0,index($mtext," "));
} else {
  $ffirstword = $mtext;
  printf " ".$ffirstword;
}

#strip color/bold/et al
$ffirstword =~ s/[\001|\002|\003|\026|\017]//gi;

#################
# CMD SHORTCUTS #
#################
if ($enableshortcuts == 1) {
  if (lc($ffirstword) eq "!kick") {
    $mtext = lc($botname) . ", kick " . substr($mtext, 6);
  }

  if (lc($ffirstword) eq "!voice") {
    $mtext = lc($botname) . ", voice " . substr($mtext, 7);
    if ($mtext eq "$botname, voice ") {
      $mtext = "$botname, voice $nickname";
    }
  }

  if (lc($ffirstword) eq "!bewt") {
    $mtext = lc($botname) . ", kickban " . substr($mtext, 6);
  }

  if (lc($ffirstword) eq "!deop") {
    $mtext = lc($botname) . ", deop " . substr($mtext, 6);
  }

  if (lc($ffirstword) eq "!ban") {
    $mtext = lc($botname) . ", ban " . substr($mtext,5);
  }

  if (lc($ffirstword) eq "!op") {
    $mtext = lc($botname) . ", op " . substr($mtext, 4);
    if ($mtext eq "$botname, op ") {
      $mtext = "$botname, op $nickname";
    }
  }

  if ((lc($mtext) eq "vote yes") && ($voting == 1)) {
    $mtext = "$botname, vote yes";
  }

  if ((lc($mtext) eq "vote no") && ($voting == 1)) {
    $mtext = "$botname, vote no";
  }
}

#######################
# CHECK FOR COMMAND?? #
#######################
if ($noqq == 0 && substr($mtext,-2,2) eq "??") {
  if ($mtext =~ /^\Q$botname\E($botanswer)/i) {
    sndtxt("Use either \002$botname, command\002 or \002command??\002, not both.");
    next;
  }
  $mtext = "$botname, " . substr($mtext,0,length($mtext)-2);
  $silent = 1;
}

if (lc($ffirstword) eq "seen") {
  if ($silent == 0) {
    $mtext = lc($botname) . ", " . $mtext;
  }
}


###########
# lINE CNT#
###########
if (($command eq "PRIVMSG") && (lc($msgto) eq lc($channel))) {
  $spoken++;
}

######################################
#   REJOIN IF KICKED (30 sec delay)
######################################
if ($command eq "KICK") {
  if ($spacesplit[3] eq $botname) {
    sleep 30;
    snd ("JOIN $channel $key");
  }
}

####################
# NEED OPS FOR OP. #
####################
if ($command eq "482") {
  if ((time - $optimeout) > 5) {
    sndtxt ("Sorry, I need ops to do that.");
    $optimeout = time();
    next;
  }
}

#############
# CTCP SHIZ #
#############

if ($msgto eq $nickname && $ctcp_hax == 1 && $ctcp_reply == 1) {
  if ($command eq "PRIVMSG") {
    if ($mtext =~ "^VERSION") {
      snd ("NOTICE $nickname :\001VERSION $bot_version_number\001");
      if ($adminnick ne '') {
        snd ("NOTICE $adminnick :$nickname requested VERSION");
      }
    } elsif ($mtext =~ "^PING") {
      snd ("NOTICE $nickname :\001$mtext\001");
      if ($adminnick ne '') {
        snd ("NOTICE $adminnick :$nickname requested PING");
      }
    }
    next;
  } elsif ($command eq "NOTICE") {
    if ($mtext =~ "^PING") {
      if ($notime == 1) {
        $ctime = time();
      } else {
        $ctime = Time::HiRes::time();
      }

      if (exists($pendingping{$nickname})) {
        ($msgto, $oldtime) = split (/\001/, $pendingping{$nickname});
        sndtxt ($nickname . " ping reply: " . ($ctime - $oldtime) . "secs.");
        delete $pendingping{$nickname};
      }
      next;
    }
  }

}

###################################
#  RETRY EVERY MIN. if banned     #
###################################
if ($command eq "474") {
  sleep 60;
  snd ("JOIN $channel $key");
}

#####################################
#        ON JOIN MESSAGE
#####################################
if ($command eq "JOIN") {
  GetFactoid($nickname);
  $deltimer{lc($nickname)} = time()+60;
  if (($usermode =~ / AV /) && ($nicklist{lc($botname)} eq '@')) {
    snd("MODE $channel +v $nickname");
  }

  if (defined($factoidmsg[$#factoidmsg])) {
    $randm = int(rand(@factoidmsg));
    $thatnum = $randm;
    sndtxt ($factoidmsg[$randm]);    
    next;
  }
}

#######################################
#             LOGIN CODE
#######################################


##################################################################
# BOTNAME, ONLY COMMANDS FOLLOW FROM HERE ON. DO NOT VIOLATE THIS. #
##################################################################
if ($mtext =~ /^\Q$botname\E[$botanswer] (.+)/i) {

local $text = $1;

$bitchcmds++;

#$text = substr($mtext,index(lc($mtext),lc($botname) . $1)+length($botname . $1));
#chomp($text);

$text =~ s/^\s+//;
$text =~ s/\s+$//;

#######
# LOG #
#######
print BITCHLOG "$text from $nickname ($hostmask) at " . localtime() . "\n";


if (index($text, " ") > -1) {
  $firstword = substr($text,0,index($text," "));
} else {
  $firstword = $text;
}

if (lc($firstword) eq 'factiodlist') {
  sndtxt("Its \002FACTOIDLIST\002 god damnit!!");
  next;
}

###############
# COUNT FCTS  #
###############
if (lc($firstword) eq "count") {
  local $counter = 0;
  local $query = "";

  $query = substr($text,6);
  if ($query eq "") { 
    sndtxt ("Missing parameter. Use \002${botname}, count [object]\002 to count number of factoids referencing [object]");
    next;
  }

  for ($i = 0; $i < (($#objects)+1); $i++) {
    if (lc($objects[$i]) eq lc($query)) {
      $counter++ 
    }
  }

  #ack, divide by zero possibility...
  if ($#facts >= 0) {
    $prcnt = (($counter / (($#facts)+1)) * 100);
  } else {
    $prcnt = 0;
  }
  

  if ($counter > 1) {
    sndtxt ("There are $counter factoids for '$query' (" . round($prcnt,5) . "% of the total)");
  } elsif ($counter == 1) {
    sndtxt ("There is $counter factoid for '$query' (" . round($prcnt,5) . "% of the total)");
  } elsif ($counter == 0) {
    sndtxt ("There are no factoids for '$query'");
  }
  next;
}

####################
# BITCHMSG SYSTEME #
####################
if (lc($firstword) eq "viesti") {

  local $query = "";
  local $nick = "";
  local $message = "";


  if (index($text," ") == -1) {
    sndtxt("Puuttuvia parametreja. Komento \002$botname: viesti nickname viesti\002.");
    next;
  }

  $query = substr($text,index($text," ")+1);

  if (index($query," ") == -1) {
    sndtxt("Puuttuvia parametreja. Komento \002$botname: viesti nickname viesti\002.");
    next;
  }

  $nick = substr($query,0,index($query," "));

  if (!defined($seen{lc($nick)})) {
    sndtxt("Uups, en tiedä kuka $nick on.");
    next;
  }

  $message = substr($query,index($query," ")+1);

  if (length($message) > 180) {
    sndtxt("Liian pitkä viesti! Vain alle 180 merkkiä sallittu.");
    next;
  }

  $pending = 0;
  for ($i = 0;$i < ($#msg+1);$i++) {
    ($recipient) = split(/\001/, $msg[$i]);
    if (lc($nick) eq lc($recipient)) {
      $pending++;
    }
  }

  if ($pending < $maxpending) {
    $msg[$#msg+1] = "$nick\001\002$message\002 (from $hosts{lc($nickname)})\001 " . time();
    sndtxt("Viestisi $nick :lle on lisätty jonoon odottamaan.");
  } else {
    sndtxt ("Uups, $nick :lla on jo maksimimäärä: $maxpending viestejä odottamassa.");
  }
  
  next;
}

#########
# HOSTS #
#########
if (lc($firstword) eq "host") {

  local $query = "";

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}: host [nick]\002 for host info.");
    next;  
  }

  $query = substr($text,5);

  if (!defined($hosts{lc($query)})) { 
    sndtxt ("Sorry ${nickname}, I have no host info for ${query}.");
    next; 
  } else {
    sndtxt ("$query is $hosts{lc($query)}");
    next;
  }

}

########
#  IP  #
########

if (lc($firstword) eq "ip") {

  local $query = "";

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}: ip [nick]\002 for [nick]'s address.");
    next;  
  }

  $query = substr($text,3);

  if (!defined($hosts{lc($query)})) { 
    sndtxt ("Sorry ${nickname}, I don't have those details for ${query}.");
    next; 
  } else {
    sndtxt ("$query is " . substr($hosts{lc($query)},index($hosts{lc($query)},"\@")+1));
    next;
  }

}


####################
# SEEN X LOOKUP!!! #
####################
if (lc($firstword) eq "seen")   {

    print("command = ".$command."\n\r");
  local $query = "";
  local $mytime;
  local $daytime;
  local $thiny;

  $query = substr($text,5);

  if ((!defined($query)) || ($query eq "")) {
    next;
  }

  if (!defined($seen{lc($query)})) {
    sndtxt("No.");
    next;
  }

  ($mytime,$daytime) = split(/\001/,$seen{lc($query)});


  $upTime = (time()-$mytime);
  $upString = "";

  $upYears = int($upTime / (60*60*24*365));
  if ($upYears > 0) {
  	$upString .= $upYears." year";
  	$upString .= "s" if ($upYears > 1);
  	$upString .=", ";
  }
  $upTime -= $upYears * 60*60*24*365;

  $upWeeks = int($upTime / (60*60*24*7));
  if ($upWeeks > 0) {
  	$upString .= $upWeeks." week";
  	$upString .= "s" if ($upWeeks > 1);
  	$upString .=", ";
  }
  $upTime -= $upWeeks * 60*60*24*7;

  $upDays = int($upTime / (60*60*24));
  if ($upDays > 0) {
  	$upString .= $upDays." day";
  	$upString .= "s" if ($upDays > 1);
  	$upString .=", ";
  }
  $upTime -= $upDays * 60*60*24;

  $upHours = int($upTime / (60*60));
  if ($upHours > 0) {
  	$upString .= $upHours." hour";
  	$upString .= "s" if ($upHours > 1);
  	$upString .=", ";
  }
  $upTime -= $upHours *60*60;

  $upMinutes = int($upTime / 60);
  if ($upMinutes > 0) {
  	$upString .= $upMinutes." minute";
  	$upString .= "s" if ($upMinutes > 1);
  	$upString .=", ";
  }
  $upTime -= $upMinutes * 60;

  $upSeconds = $upTime;
  $upString .= $upSeconds." second";
  $upString .= "s" if ($upSeconds != 1);

  if (substr($upString,-2,2) eq ', ') {
    $upString = substr($upString,0,(length($upString)-2));
  }

  $day = (Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday)[(localtime($mytime))[6]];
  $month = (January,February,March,April,May,June,July,August,September,October,November,December)[(localtime($mytime))[4]];

  (undef,undef,undef,$mday,$mon,$year,undef,undef,undef) = localtime($mytime);

  $year = 1900 + $year;
  $mon++;

  $thiny = "th";

  $mmday = substr($mday,length($mday)-1,1);

  if ($mmday == 1) {
    $thiny = "st";
  } elsif ($mmday == 2) {
    $thiny = "nd";
  } elsif ($mmday == 3) {
    $thiny = "rd";
  }

  if (($mday == 11) || ($mday == 12) || ($mday == 13)) {
    $thiny = "th";
  }



  sndtxt("$nickname :  I last saw $query at $daytime ${timezone}on $day the $mday$thiny of $month, $year ($upString ago)");
  next;

}

#################
# MISC INFOS !!!#
#################
if (lc($text) eq "stats") {
  local $stats = "no stats available";
  foreach $_ (`ps u $$ | awk '{print "I am using "\$3"% of cpu and "\$4"% of mem I was started at "\$9" my pid is "\$2" i was run by "\$1}'`) {
    $stats = $_;
  }
  sndtxt($stats);
  next;
}

#############
# PING USER #
#############
if (lc($text) eq "ping me") {
  snd ("PRIVMSG $nickname :PING " . time . "");
  if ($notime == 1) {
    $pendingping{$nickname} = $msgto . "\001" . time();
  } else {
    $pendingping{$nickname} = $msgto . "\001" . Time::HiRes::time();
  }
  next;
}

###############
#  TIME (!)  #
###############
if (lc($text) eq "time") {
  sndtxt (scalar localtime());
  next;
}

################
#   STATUS     #
################
if (lc($text) eq "status") {

	$upTime = (time()-$startlifetime);
  $upString = "";

  $upYears = int($upTime / (60*60*24*365));
  if ($upYears > 0) {
  	$upString .= $upYears." year";
  	$upString .= "s" if ($upYears > 1);
  	$upString .=", ";
  }
  $upTime -= $upYears * 60*60*24*365;

  $upWeeks = int($upTime / (60*60*24*7));
  if ($upWeeks > 0) {
  	$upString .= $upWeeks." week";
  	$upString .= "s" if ($upWeeks > 1);
  	$upString .=", ";
  }
  $upTime -= $upWeeks * 60*60*24*7;

  $upDays = int($upTime / (60*60*24));
  if ($upDays > 0) {
  	$upString .= $upDays." day";
  	$upString .= "s" if ($upDays > 1);
  	$upString .=", ";
  }
  $upTime -= $upDays * 60*60*24;

  $upHours = int($upTime / (60*60));
  if ($upHours > 0) {
  	$upString .= $upHours." hour";
  	$upString .= "s" if ($upHours > 1);
  	$upString .=", ";
  }
  $upTime -= $upHours *60*60;

  $upMinutes = int($upTime / 60);
  if ($upMinutes > 0) {
  	$upString .= $upMinutes." minute";
  	$upString .= "s" if ($upMinutes > 1);
  	$upString .=", ";
  }
  $upTime -= $upMinutes * 60;

  $upSeconds = $upTime;
  $upString .= $upSeconds." second";
  $upString .= "s" if ($upSeconds != 1);

  if (substr($upString,-2,2) eq ', ') {
    $upString = substr($upString,0,(length($upString)-2));
  }

  $lifetime = $upString;

  $upTime = ($allstartlifetime + time()-$startlifetime);
  $upString = "";

  $upYears = int($upTime / (60*60*24*365));
  if ($upYears > 0) {
  	$upString .= $upYears." year";
  	$upString .= "s" if ($upYears > 1);
  	$upString .=", ";
  }
  $upTime -= $upYears * 60*60*24*365;

  $upWeeks = int($upTime / (60*60*24*7));
  if ($upWeeks > 0) {
  	$upString .= $upWeeks." week";
  	$upString .= "s" if ($upWeeks > 1);
  	$upString .=", ";
  }
  $upTime -= $upWeeks * 60*60*24*7;

  $upDays = int($upTime / (60*60*24));
  if ($upDays > 0) {
  	$upString .= $upDays." day";
  	$upString .= "s" if ($upDays > 1);
  	$upString .=", ";
  }
  $upTime -= $upDays * 60*60*24;

  $upHours = int($upTime / (60*60));
  if ($upHours > 0) {
  	$upString .= $upHours." hour";
  	$upString .= "s" if ($upHours > 1);
  	$upString .=", ";
  }
  $upTime -= $upHours *60*60;

  $upMinutes = int($upTime / 60);
  if ($upMinutes > 0) {
  	$upString .= $upMinutes." minute";
  	$upString .= "s" if ($upMinutes > 1);
  	$upString .=", ";
  }
  $upTime -= $upMinutes * 60;

  $upSeconds = $upTime;
  $upString .= $upSeconds." second";
  $upString .= "s" if ($upSeconds != 1);

  if (substr($upString,-2,2) eq ', ') {
    $upString = substr($upString,0,(length($upString)-2));
  }

  $alllifetime = $upString;


  sndtxt ("I currently reference ". ($#objects+1) ." factoids, $newfacts of which are new this life. There have been $spoken lines said in $channel so far, and I have recevied $bitchcmds commands. So far I have been connected to $server for $lifetime ($alllifetime total) and have seen " . (scalar keys %seen) ." clients. Running under $^O.");
  next;
}

####################
#   FACTOIDLIST    #
####################
if (lc($firstword) eq "factoidlist") {

  local $numfacts = 0;
  local $query = "";
  local $startat = 0;
  local @factoidmsg = ();
  local $stupidvalue = 0;

  if ( ($factoiddelay - time) > 0) {
    snd ("NOTICE $nickname :Please wait " . ($factoiddelay - time) . " seconds.");
    $ignore{$iponly} = $factoiddelay;
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, factoidlist object\002 for a factoid list.");
    next;  
  }

  $query = substr($text,12);

  ($query,$startat) = split(":",$query);
	
  for ($i = 0; $i < (($#objects)+1); $i++) {
    if (lc($objects[$i]) eq lc($query)) {
      $numfacts++;
    }
  }

  if ($numfacts == 0) {
    sndtxt ("I don't have any factoids for $query.");
    next;
  }

  if ( ($numfacts > 10) && ($startat eq "")) {
    snd ("NOTICE $nickname :'$query' yielded > 10 factoids! Try \002${botname}, factoidlist object[:page]\002 to list factoids, starting from page 0");
  }

  GetFactoid($query);

  if ((!defined($startat)) || ($startat eq "")) {
    $startat = 0;
  } else {

    if ($startat =~ /\D/) {
      sndtxt ("$startat is not a valid number!"); 
      next;
    } else {
      $startat = $startat * 10;
    }

  }

  if ($startat > $numfacts) {
    sndtxt ("$numfacts is the total number of factoids for '$query'");
    next;
  }


  if ($numfacts > 10) {
    $numfacts = 10;
  }

  if ($numfacts >= 2) {
   $factoiddelay = time() + (($numfacts * 2) - 1);
  }

  $numfacts = $startat;
  sndtxt ("$query:");

  while (defined($factoidmsg[$numfacts])) {
    if ($factoidmsg[$numfacts] ne "") {
      if (lc($factoidmsg[$numfacts]) =~ /^\Q$query\E\s+(.*)/i) {
        sndtxt ("${numfacts}: " . $1); #substr($factoidmsg[$numfacts],length($query)));
      } else {
        sndtxt ("${numfacts}: " . $factoidmsg[$numfacts]);
      }
    }
    undef $thatnum;
    undef $thatfact;
    $numfacts++;
    $stupidvalue++;

    if ($stupidvalue >= 10) {
      $stupidvalue = 0;
      next STARTOFLOOP;
    }

  }

  next;

}

##############
# Q2 INFO
##############
if ( (lc($firstword) eq "q2info") || (lc($firstword) eq "utinfo") || (lc($firstword) eq "q3info") || (lc($firstword) eq "hlinfo") || (lc($firstword) eq "t2info") || (lc($firstword) eq "trinfo")) {

  local $parameter = "";
  local $serverinfo = "";
  local $mode = "";
  local $cc = "";
  local $tn = "";
  local $pr0t = 0;
  local @snfo = ();
  local $game = "";
  local $var = "";
  local $setting = "";
  local $gameinfo = "";
  local $serveruptime = "";
  local $tmp = "";
  local $i = 0;
  local $mygamename = "game";

  $text =~ s/[\001|\002|\003|\026]//gi;

  $parameter = substr($text,7);

  if (index($parameter, " ") != -1) {
    $tmp = substr($parameter,index($parameter," ")+1);
    if (lc($tmp) eq 'p') {
      if ($noplayerlist && $usermode !~ / ADMIN /) {
        sndtxt ("Player list has been disabled by my owner.");
        next;
      }
      $tmp = " -P";
    }
    $parameter = substr($parameter,0,index($parameter," "));
  }
    

  if ( defined ($servers{lc($parameter)} ) ) {
    $parameter = $servers{lc($parameter)};
  } elsif (defined($hosts{lc($parameter)})) {
    $parameter = substr($hosts{lc($parameter)},index($hosts{lc($parameter)},"\@")+1);
  }

  ($tn,$pr0t) = split(/:/,$parameter);
  if (defined($hosts{lc($tn)})) {
    $parameter = substr($hosts{lc($tn)},index($hosts{lc($tn)},"\@")+1) . ":$pr0t";
  }

  if ( ($parameter !~  /[a-zA-Z0-9]+\.[a-zA-Z0-9]+\.[a-zA-Z0-9]+/) || (substr($parameter,0,1) eq '.') || (substr($parameter,length($parameter)-1,1) eq '.')) {
    sndtxt("Invalid address - $parameter");
    next;
  }

  if (lc($firstword) eq "q2info") {
    $mode = "q2s";
    $mygamename = "gamedir";
  } elsif (lc($firstword) eq "utinfo") {
    $mode = "uns";
  } elsif (lc($firstword) eq "q3info") {
    $mode = "q3s";
    $mygamename = "gamename";
  } elsif (lc($firstword) eq "hlinfo") {
    $mode = "hls";
  } elsif (lc($firstword) eq "trinfo") {
    $mode = "tbs";
  } elsif (lc($firstword) eq "t2info") {
    $mode = "t2s";
  }

  @snfo = (`${win321}qstat -$mode $parameter -raw \001 -R$tmp`);
  $serverinfo = $snfo[0];
  $gameinfo = $snfo[1];

  foreach $kee (split (/\001/,$gameinfo)) {
    ($var,$setting) = split(/=/,$kee);
    $sstats{lc($var)} = $setting;
  }

  $game = $sstats{$mygamename};
  if ($game eq '') {
    $game = 'default';
  }

  if (defined($sstats{'uptime'})) {
    $serveruptime = "\002Uptime:\002$sstats{'uptime'}";
  }

  chomp ($serverinfo);
  $serverinfo =~ s/[\n\r]//g;
  (undef,$ip,$stat,$mapname,$maxclients,$curclients,$ping) = split(/\001/,$serverinfo);

  if (defined($sstats{'curplayers'})) {
    $rcur = $curclients;
    $curclients = "$sstats{'curplayers'}";
  }

  if (defined($sstats{'maxplayers'})) {
    $rmax = $maxclients;
    $maxclients = "$sstats{'maxplayers'}";
    if ($maxclients > $rmax) {
      $maxclients = $rmax;
    }
  }

  if ($ip eq '') {
    sndtxt ("Server info is not supported on this operating system.");
    next;
  }

  if (lc($stat) eq 'down') {
    sndtxt ("\002ERROR\002 \($ip\): Server is DOWN.");
    next;
  } elsif (lc($stat) eq 'error') {
    sndtxt ("\002ERROR\002 \($ip\): Host not found.");
    next;
  } elsif (lc($stat) eq 'no') {
    sndtxt ("\002ERROR\002 \($ip\): No response.");
    next;
  } elsif (lc($stat) eq 'timeout') {
    sndtxt ("\002ERROR\002 \($ip\): No response.");
    next;
  }

  if ($maxclients == $curclients) {
    $cc = "\00304";
  } elsif ($curclients == 0) {
    $cc = "";
  } else {
    $cc = "\00303";
  }

  if (defined($rmax) && defined($rcur)) {
    if ($rmax == $rcur) {
      $cc2 = "\00304";
    } elsif ($rcur == 0) {
      $cc2 = "";
    } else {
      $cc2 = "\00303";
    }
  }

  if (defined($rmax)) {
    if ($rmax != $maxclients || $rcur != $curclients) {
      $sstring = " ($cc2$rcur\003/$rmax)";

    }
  }

  if ($tmp eq " -P") {
    snd ("PRIVMSG $nickname :\002Server:\002$ip \002Game:\002$game \002Players:\002$cc$curclients\003/$maxclients$sstring \002Map:\002$mapname \002Ping:\002${ping} $serveruptime");
    snd ("PRIVMSG $nickname :+---------------+-----+----+");
    snd ("PRIVMSG $nickname :|  Player Name  |Score|Ping|");
    snd ("PRIVMSG $nickname :+---------------+-----+----+");
    splice(@snfo,0,2);
    splice(@snfo,$#snfo,1);
    @snfo = sort { lc($a) cmp lc($b) } @snfo;
    for ($i = 0;$i <= $#snfo;$i++) {
      chomp $snfo[$i];
      @playerinfo = split(/\001/,$snfo[$i]);
      if (length($playerinfo[0]) > 15) {
        $playerinfo[0] = substr($playerinfo[0],0,15);
      }
      if ($playerinfo[2] == 0) {
        $playerinfo[2] = "CNCT";
      }
      $stat = sprintf ("|%-15s|%-5d|%-4s|",$playerinfo[0],$playerinfo[1],$playerinfo[2]);
      snd ("PRIVMSG $nickname :$stat");
    }
    snd ("PRIVMSG $nickname :+---------------+-----+----+");
  } else {
    sndtxt("\002Server:\002$ip \002Game:\002$game \002Players:\002$cc$curclients\003/$maxclients$sstring \002Map:\002$mapname \002Ping:\002$ping $serveruptime");
  }
  undef %sstats;
  undef $sstring;
  undef $rmax;
  undef $rcur;

  next;
}

if (lc($text) eq 'version') {
  sndtxt("I am $bot_version_number by R1CH! Visit http://www.r1ch.net/projects/bitchbot/ for more info.");
  next;
}

#############
# DEL FACTS #
#############
if ((lc($firstword) eq "forget") || (lc($firstword) eq "delete")) {

  local $num = 0;
  local $query = "";
  local $mytodel = 0;
  local $delcount = 0;
  local $foundcount = 0;
  local $i = 0;

  if (time() - $deltimer{lc($nickname)} < 0) {
    sndtxt("Please wait " . ($deltimer{lc($nickname)} - time()) . " seconds before using this function.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, forget factoid[:number[,number]]\002 to delete a factoid.");
    next;  
  }

  if (($usermode !~ / DELFACTS /) && ($usermode !~ / DELALLFACTS /)) {
    sndtxt ("Only users with access level DELFACTS or DELALLFACTS can delete factoids.");
    next;
  }

  $query = substr($text,7);

  if ($query eq 'that') {
    if (defined($thatnum) && defined($thatfact)) {
      $query = $objects[$thatfact];
      $num = $thatnum
    } else {
      sndtxt("What's that?");
      next;
    }
  } else {
    ($query,$num) = split(":",$query);
  }

  #############
  # KILL ALL  #
  #############
  if (!defined($num)) {


    for ($i = 0;$i < @owners;$i++) {

      if (lc($objects[$i]) eq lc($query)) {
        $foundcount++;

        if ( ( ($usermode =~ / DELFACTS /) && (lc($nickname) eq lc($owners[$i])) ) || ($usermode =~ / DELALLFACTS /) ) {

          $delcount++;
          $removed = splice(@objects, $i, 1);
          $removed = splice(@owners, $i, 1);
          $removed = splice(@facts, $i, 1);
          $removed = splice(@splitters, $i, 1);
          $i--;

        }

      }

    }

    if ($delcount > 0) {
      undef $thatnum;
      undef $thatfact;
    }
    sndtxt ("Found $foundcount factoids referencing '$query', deleted $delcount of them.");

    if (($delcount == 0) && ($foundcount != 0) && ($usermode !~ / DELALLFACTS /)) {
      sndtxt ("Only users with access level DELALLFACTS can delete others' factoids.");
      next;
    }

    next;
  }


  ##########
  # NUKE X #
  ##########
  if (defined($num)) {
      local @tokill = ();
      @tokill = split(",",$num);

      foreach $num (@tokill) {

      if ($num =~ /\D/) {
        sndtxt ("$num must be the factoid number. Use \002$botname, factoidlist $query\002 to determine this.");
        next;
      }

      $num -= $delcount;
      $mytodel = 0;

      if ($num =~ /\D/) {
        sndtxt ("$num must be the factoid number. Use \002$botname, factoidlist $query\002 to determine this.");
        next;
      }

        for ($i = 0;$i < @owners;$i++) {

          if (lc($objects[$i]) eq lc($query)) {

            $mytodel++;
            if ($mytodel-1 == $num) {
            $foundcount++;    
            if (($usermode =~ / DELFACTS /) && ((lc($nickname) eq lc($owners[$i])) || ($usermode =~ / DELALLFACTS /))) {

              $delcount++;
              $removed = splice(@objects, $i, 1);
              $removed = splice(@owners, $i, 1);
              $removed = splice(@facts, $i, 1);
              $removed = splice(@splitters, $i, 1);
              $i--;

            }

          }

        }

      }

    }


    if ( ($foundcount == 0) || ( ($foundcount == 0) && ($delcount == 0) ) ) {
      sndtxt("Match for '$query' not found.");
      next;
    }

    if (($delcount == 0) && ($foundcount != 0)) {
      sndtxt ("Only users with access level DELALLFACTS can delete others' factoids.");
    } else {
      sndtxt("Deleted $delcount of " . ($#tokill + 1) . " factoids matching '$query'");
      undef $thatnum;
      undef $thatfact;
    }

    next;


  }
}

###############
# UPTIME (!)  #
###############
if (lc($text) eq "uptime") {
   if ($win321 eq '') {
     $upTime = (`uptime`);
     $upTime = int($upTime / 1000);
     $upString = "";

     $upYears = int($upTime / (60*60*24*365));
     if ($upYears > 0) {
     	$upString .= $upYears." year";
     	$upString .= "s" if ($upYears > 1);
     	$upString .=", ";
     }
     $upTime -= $upYears * 60*60*24*365;

     $upWeeks = int($upTime / (60*60*24*7));
     if ($upWeeks > 0) {
     	$upString .= $upWeeks." week";
     	$upString .= "s" if ($upWeeks > 1);
     	$upString .=", ";
     }
     $upTime -= $upWeeks * 60*60*24*7;

     $upDays = int($upTime / (60*60*24));
     if ($upDays > 0) {
     	$upString .= $upDays." day";
     	$upString .= "s" if ($upDays > 1);
     	$upString .=", ";
     }
     $upTime -= $upDays * 60*60*24;

    $upHours = int($upTime / (60*60));
    if ($upHours > 0) {
    	$upString .= $upHours." hour";
    	$upString .= "s" if ($upHours > 1);
    	$upString .=", ";
    }
    $upTime -= $upHours *60*60;

    $upMinutes = int($upTime / 60);
    if ($upMinutes > 0) {
    	$upString .= $upMinutes." minute";
    	$upString .= "s" if ($upMinutes > 1);
    	$upString .=", ";
    }
    $upTime -= $upMinutes * 60;

    $upSeconds = $upTime;
    $upString .= $upSeconds." second";
    $upString .= "s" if ($upSeconds != 1);
    if (substr($upString,-2,2) eq ', ') {
      $upString = substr($upString,0,(length($upString)-2));
    }

    sndtxt("Uptime: $upString");
  } else {
    sndtxt(`uptime`);
  }
  next;
}


#############
# DO STATS  #
#############
if (lc($text) eq "updatestats") {

  if ($allowstats != 1) {
    sndtxt("Stats are disabled!");
    next;
  }

  if ($usermode eq '') {
    sndtxt("Only users on my access list can update stats.");
    next;
  }

  if ($chanstats_running) {
    sndtxt ("Chanstats are already running! Wait for them to finish you impatient bastard.");
    next;
  }

  if ((time() - $stattime) < 7200) {
    sndtxt("Stats can only be updated once every 2 hours.");
    next;
  }


  $stattime = time();

  open (STATSTIMER,">$win321$datadir/stats.time");
  print STATSTIMER $stattime;
  close (STATSTIMER);

  &updatestats;
  next;
}

if (lc($text) eq "timeleft") {
  $upTime = (7200 - (time() - $stattime));

  if ((time() - $stattime) >= 7200) {
    sndtxt("You may update stats now, use \002$botname, updatestats\002");
    next;
  }

  $upString = "";

  $upYears = int($upTime / (60*60*24*365));
  if ($upYears > 0) {
  	$upString .= $upYears." year";
  	$upString .= "s" if ($upYears > 1);
  	$upString .=", ";
  }
  $upTime -= $upYears * 60*60*24*365;

  $upWeeks = int($upTime / (60*60*24*7));
  if ($upWeeks > 0) {
  	$upString .= $upWeeks." week";
  	$upString .= "s" if ($upWeeks > 1);
  	$upString .=", ";
  }
  $upTime -= $upWeeks * 60*60*24*7;

  $upDays = int($upTime / (60*60*24));
  if ($upDays > 0) {
  	$upString .= $upDays." day";
  	$upString .= "s" if ($upDays > 1);
  	$upString .=", ";
  }
  $upTime -= $upDays * 60*60*24;

  $upHours = int($upTime / (60*60));
  if ($upHours > 0) {
  	$upString .= $upHours." hour";
  	$upString .= "s" if ($upHours > 1);
  	$upString .=", ";
  }
  $upTime -= $upHours *60*60;

  $upMinutes = int($upTime / 60);
  if ($upMinutes > 0) {
  	$upString .= $upMinutes." minute";
  	$upString .= "s" if ($upMinutes > 1);
  	$upString .=", ";
  }
  $upTime -= $upMinutes * 60;

  unless ($upTime == 0) {
    $upSeconds = $upTime;
    $upString .= $upSeconds." second";
    $upString .= "s" if ($upSeconds != 1);
  }

  if (substr($upString,-2,2) eq ', ') {
    $upString = substr($upString,0,(length($upString)-2));
  }

  sndtxt("You may update the stats in $upString");
  next;
}

##########################
# CYBORG (FROM SOME URL) #
##########################
if (lc($firstword) eq "cyborg") {

  local ($cyb) = "";

  if ($notoys) {
    sndtxt ("My owner disabled these toys >:/");
    next;
  }

  if (index($text, " ") == -1) {
    sndtxt("Missing parameter. Use \002$botname, cyborg [nick]\002.");
    next;
  }


  $query = substr($text,7);

  if (length($query) > 7) {
    sndtxt("'$query' is too long!");
    next;
  } elsif (length($query) < 3) {
    sndtxt("'$query' is too short!");
    next;
  }

  $cyb = cyborgify($query);

  if (substr(lc($cyb),0,2) eq 'st') {
    sndtxt("'$query' is not valid!");
    next;
  }

  sndtxt($cyb);
  next;
}

##########################
# TECHNO (FROM SOME URL) #
##########################
if (lc($firstword) eq "techify") {

  local ($cyb) = "";

  if ($notoys) {
    sndtxt ("My owner disabled these toys >:/");
    next;
  }

  if (index($text, " ") == -1) {
    sndtxt("Missing parameter. Use \002$botname, techify [acronym]\002.");
    next;
  }


  $query = substr($text,8);

  if (length($query) > 6) {
    sndtxt("'$query' is too long!");
    next;
  } elsif (length($query) < 2) {
    sndtxt("'$query' is too short!");
    next;
  }

  $cyb = techify($query);
  sndtxt($cyb);
  next;
}

############
# PROFILES #
############
if (lc($firstword) eq "addprofile") {
  local $profile = "";
  local @profiledata = ();
  local $pfname = "";

  if ($usermode !~ / ADMIN /) {
    sndtxt("Only an ADMIN can add profiles. Try \002$botname, bitchmsg $adminnick add my profile... [info]\002");
    next;
  }

  if (index($text," ") == -1) {
    sndtxt("\002Format:\002 nick|realname|email|web|icq|location|other| (NOTE: No spaces either side of |'s)");
    next;
  }

  $profile = substr($text,11);
  $pfname = substr($profile,0,index($profile,'|'));
  $pfname2 = lc($pfname);
  $profiles{$pfname2} = substr($profile,(index($profile,'|')+1));

  sndtxt("Profile for $pfname added successfully.");
  next;
}

if (lc($firstword) eq "delprofile") {
  local $profile = "";

  if ($usermode !~ / ADMIN /) {
    sndtxt("Only an ADMIN can delete profiles. Try bugging my owner.");
    next;
  }

  $profile = substr($text,11);

  if (!defined($profiles{lc($profile)})) {
    sndtxt("I don't have a profile for $profile!");
    next;
  }

  delete $profiles{lc($profile)};
  sndtxt("${profile}'s profile was deleted.");
  next;
}

if (lc($firstword) eq "getprofile") {

  local $query = "";
  local$profname = "";
  local @profiledata = ();
  local $i = 0;
  local @pfdesc = qw(Name Email Web ICQ Location Other);
  
  if (index($text," ") == -1) {
    sndtxt("Missing parameter. Please specify nick of profile, eg \002$botname, getprofile R1CH\002");
    next;
  }

  $query = substr($text,11);
  $profname = lc($query);

  if (!defined($profiles{$profname})) {
    sndtxt("Sorry $nickname, I don't have a profile for ${query}.");
  } else {
    @profiledata = split(/\|/,$profiles{$profname});
    foreach (@profiledata) {
      snd("PRIVMSG $nickname :$pfdesc[$i]: $_");
      $i++;
    }
  }

  next;
}

##############
# COOKIE 4 U #
##############
if (lc($firstword) eq "cookie") {

  local $query = "";
  local @cookie = ();
  local $_ = "";
  local $txt = "";

  if (index($text, " ") != -1) {
    $query = substr($text,7);

    if (!-e "/usr/games/lib/fortunes/$query") {
      sndtxt ("Cookie file $query not found - try limerick, startrek, zippy or fortunes2.");
      next;
    }

  }

  @cookie = `/usr/games/fortune $query`;

  while (length(scalar @cookie) > 300) {
    @cookie = `/usr/games/fortune $query`;
  }

  foreach $txt (@cookie) {
    $txt =~ s/\011//gi;
    sndtxt ($txt);
  }
  next;
}

#####################
# SEARCH FOR PLAYER #
#####################

if (substr(lc($text),0,6) eq "search") {

  local $foundm = 0;
  local $servername = "";
  local $parameter = "";
  local $name = "";
  local $frags = 0;
  local $ping = 0;

  ($servername,$parameter) = split(/ /,substr($text,7));

  if (($servername eq '') || ($parameter eq '')) {
    sndtxt("Invalid parameters. Try \002$botname, search [server] [player]\002 for info.");
    next;
  }

  if ( defined ($servers{$servername} ) ) {
    $servername = $servers{$servername};
  }

  if ( ($servername !~  /[a-zA-Z0-9]+\.[a-zA-Z0-9]+\.[a-zA-Z0-9]+/) || (substr($servername,0,1) eq '.') || (substr($servername,length($servername)-1,1) eq '.')) {
    sndtxt("Invalid address - $servername");
    next;
  }

  foreach (`${win321}qstat -q2s $servername -P -raw \001`) {
    chomp;
    ($name,$frags,$ping) = split(/\001/,$_);
    if (index(lc($name),lc($parameter)) != -1) {
      sndtxt("I found $name on $servername with $frags frags and a ping of ${ping}ms");
      $foundm++;
      if ($foundm > 2) {
        sndtxt("Too many matches.");
        next STARTOFLOOP;
      }
    }
  }

  if ($foundm == 0) {
    sndtxt("$parameter was not found on $servername.");
  }

  next;

}


################
# INFO ON USER #
################
if (lc($firstword) eq "info") {

  local $query = "";
  local $ufactcount = 0;
  local $i = 0;
  local $prcnt = 0;

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, info [nick]\002 for user info.");
    next;  
  }

  $query = substr($text,5);

  for ($i = 0;$i < $#facts+1;$i++) {
    if (defined($owners[$i])) {
      if (lc($query) eq lc($owners[$i])) {
        $ufactcount++;
      }
    }
  }

  if ($#facts >= 0) {
    $prcnt = (($ufactcount / (($#facts)+1)) * 100);
  } else {
    $prcnt = 0;
  }

  if ($ufactcount > 1) {
    sndtxt ("$query has added $ufactcount factoids (" . round($prcnt,5) . "% of the total)");
  } elsif ($ufactcount == 1) {
    sndtxt ("$query has added 1 factoid (" . round($prcnt,5) . "% of the total)");
  } elsif ($ufactcount == 0) {
    sndtxt ("$query has not added any factoids.");
  }

  next;

}

##################
#  ADD    SERVER #
##################
if (lc($firstword) eq "addserver") {

  local $servername = "";
  local $nicename = "";

  if ($usermode !~ / SERVERMANIP /) {
    sndtxt ("Only users with access level SERVERMANIP can add/remove servers.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, addserver IP NAME\002 to add.");
    next;  
  }

  ($servername,$nicename) = split(" ",substr($text,10));

  if ( (!defined($nicename)) || (!defined($servername)) || ($servername eq "") || ($nicename eq "")) {
    sndtxt ("Missing parameter. Use \002$botname, addserver IP:PORT NICENAME\002 to add a game server.");
    next;
  }

  if (defined($servers{$nicename})) {
    sndtxt ("'$nicename' is already defined as '$servers{$nicename}'!");
    next;
  }

  $servers{lc($nicename)} = lc($servername);
  sndtxt ("Server $servername added, use \002$botname, [q2|q3|hl|ut|tr]info $nicename\002 to query.");
  next;

}

##################
#  DEL SERVER    #
##################
if (lc($firstword) eq "delserver") {

  local $param;

  if ($usermode !~ / SERVERMANIP /) {
    sndtxt ("Only users with access level SERVERMANIP can add/remove servers.");
    next STARTOFLOOP;
  }

  $param = lc(substr($text,10));

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, delserver NAME\002 to remove.");
    next;  
  }

  if (defined ($servers{$param})) {
    delete $servers{$param};
    sndtxt("$param was removed from the server list.");
  } else {
    sndtxt("$param is not defined as any server!");
  }

  next;

}

##########################
# WHO ADDED FACTOID:NUM  #
##########################
if (lc($firstword) eq "whoadded") {

  local $counter = 0;
  local $query = "";
  local $num = "";
  local $i = 0;

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, whoadded object:number\002 to find out info.");
    next;  
  }

  $query = substr($text,9);

  if ($query eq 'that') {
    if (defined($thatnum) && defined($thatfact)) {
      $query = $objects[$thatfact];
      $num = $thatnum
    } else {
      sndtxt("What's that?");
      next;
    }
  } else {
    ($query,$num) = split(":",$query);
  }


  if ((!defined($num)) || ($num eq "")) {
    sndtxt ("Please specify which number to get information about, eg (\002$botname, whoadded $query:2\002)");
    next;
  }

  if ($num =~ /\D/ && lc($num) ne "last") {
    sndtxt ("$num is not a valid number, learn some Math and try again.");
    next;
  }

  for ($i = 0; $i < (($#objects)+1); $i++) {
    if (lc($objects[$i]) eq lc($query)) {
      if ($counter == $num && $num ne 'last') {
        if ($owners[$i] ne "") {
          sndtxt ("That factoid was added by $owners[$i]");
        } else {
          sndtxt ("Sorry, there is no owner information available about that factoid.");
        }
        next STARTOFLOOP;
      }
      $last = $i;
      $counter++;
    }
  }

  if (lc($num) eq "last" && $counter > 0) {
    if ($owners[$last] ne "") {
      sndtxt ("That factoid was added by $owners[$last]");
    } else {
      sndtxt ("Sorry, there is no owner information available about that factoid.");
    }
    next;
  }

  if ($counter == 0) {
    sndtxt ("I couldn't find any factoids matching '$query'");
    next;
  }    

  if ($num >= $counter) {
    sndtxt ("$num is out of range. Factoids range from 0 - " .  ($counter - 1) . " for $query.");
    next;
  }

  if ($num < 0) {
    sndtxt ("Very clever $nickname.");
    next;
  }

  #shouldn't need this
  next;

}

###################
# VOTE POLL THING #
###################
if (lc($firstword) eq "vote-aloita") {
  if ($novote && $usermode !~ / ADMIN /) {
    sndtxt ("Voting has been disabled by my owner.");
    next;
  }


  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, startvote [topic]");
    next;  
  }

  if ($voting == 1) {
    sndtxt ("A vote is still in progress, use \002$botname, stopvote\002 to finish.");
    next;
  }

  $votetopic = substr($text,11);

  ($vfw) = split (" ", $votetopic);

  if (lc($vfw) eq "kick") {
    if ($voteopcommands == 1) {
      if (!defined($hosts {lc ( substr ($votetopic,5) ) } ) ) { 
        sndtxt ("Sorry $nickname, I don't recognise " . substr($votetopic,5));
        next;
      }
    } else {
      sndtxt("I can't do that, $nickname.");
      next;
    }
  } elsif (lc($vfw) eq "ban") {
    if ($voteopcommands == 1) {
      if (!defined($hosts{lc(substr($votetopic,4))})) { 
        sndtxt ("Sorry $nickname, I don't recognise " . substr($votetopic,4));
        next;
      }
    } else {
      sndtxt("I can't do that, $nickname.");
      next;
    }
  }


  sndtxt ("$nickname käynnisti äänestyksen: \002$votetopic\002");
  sndtxt ("Anna äänesi komennolla \002$botname: vote yes | no\002!");

  $voting = 1;
  $votestarted = $nickname;
  $votesyes = 0;
  $votesno = 0;
  %voted = ();

  next;

}

###############
# STOP A VOTE #
###############
if (lc($text) eq "vote-lopeta") {

  if ($voting == 0) {
    sndtxt("Ei ole äänestyksiä!");
    next;
  }

  if ( (lc($nickname) ne lc($votestarted)) && ($usermode !~ / ADMIN /) && ($usermode !~ / OP /) ) {
    sndtxt ("Vain $votestarted tai ADMIN/OP voi lopettaa äänestyksen.");
    next;
  }

  $voting = 0;
  sndtxt ("Äänestys aiheesta: \002$votetopic\002 on päättynyt. Tulokset:");
  if (($votesyes + $votesno) == 0) {
    sndtxt ("Doh! Kukaan ei äänestänyt!");
    next;
  }

  sndtxt ("\0033KYLLÄ\003\002:\002 $votesyes (" . round(($votesyes / ($votesyes + $votesno)) * 100,5) . "%)");
  sndtxt ("\0034EI\003 \002:\002 $votesno ("  . round(($votesno / ($votesyes + $votesno)) * 100,5) . "%)");

  if (lc($vfw) eq "kick") {
    if (($votesyes + $votesno) < 3) {
      sndtxt ("At least 3 people must vote!");
      next;
    }

    if ($votesyes <= $votesno) {
      sndtxt("Voting on $votetopic failed.");
      next;
    }

    $victim = substr($votetopic,5);
    $msg = "You were vote-kicked by $channel";

    if (lc($victim) eq lc($botname)) {
      $victim = $votestarted;
      $msg = "hupsista saatana!";
    }

    snd ("KICK $channel $victim :$msg");
  } elsif (lc($vfw) eq "ban") {
    if (($votesyes + $votesno) < 6) {
      sndtxt ("At least 6 people must vote!");
      next;
    }

    if ($votesyes <= $votesno) {
      sndtxt("Voting on $votetopic failed.");
      next;
    }

    $victim = substr($votetopic,4);
    $msg = "You were vote-banned by $channel";

    if (lc($victim) eq lc($botname)) {
      $victim = $votestarted;
      $msg = "oops.";
    }

    snd ("MODE $channel +b *!*@" . substr($hosts{lc($victim)},index($hosts{lc($victim)},"\@")+1));
    snd ("KICK $channel $victim :$msg");
  }
  #########
  # muodostetaan array johon POST tiedot tallennusta varten. 
  @vote_params= ();
  push(@vote_params, ('$votetopic', '$voteyes', '$voteno'));

  # ja sitten lähetetään
  postVote(\@vote_params);
  ##########
  next;
}

sub postVote {
    my $tmpref=shift;
    my @tmp=@$tmpref;

    $ua = LWP::UserAgent->new; 
    $ua->agent("Lurkki version 0.1");
    use HTTP::Request::Common qw(POST);
    my $req = (POST "$handler_votes", ['type' => 'vote', 'title' => '@tmp[0]', 'y' => '@tmp[1]', 'n' => '@tmp[2]']);
    
    $request = $ua->request($req); 
    $content = $request->content;  
    if($content eq "NOK"){
     snd("PRIVMSG kyb3R : Jotain meni vituiksi: sub postVote");
     }else{
        snd("PRIVMSG kyb3R : Toimii kuin junan vessa: sub postVote"); 

    }
}

# Kyselyn tietojen välittäminen
#sub postPoll {
#    my $tmpref=shift;
#    my @tmp=@$tmpref;

#my $options = "['type' => 'poll', 'title' => '@tmp[0]'";
#$i = 0;
#foreach my $item (@tmp){
#    if($i>0){
#        $options .=" ,'option$i' => '@tmp[$i]'"; ## 2x risuaita on nyt erotin
#    }
#    $i++;
#}
#$ua = LWP::UserAgent->new; 
#$ua->agent("Lurkki version 0.1");
#use HTTP::Request::Common qw(POST);
#my $req = (POST "$handler_votes", $options]);
#$request = $ua->request($req); 
#$content = $request->content; 
#  if($content eq "NOK"){
#     snd("PRIVMSG kyb3R : Jotain meni vituiksi: sub postVote");
#     }else{
#        snd("PRIVMSG kyb3R : Toimii kuin junan vessa: sub postVote"); 
#    }


##############
# VOTED YES! #
##############
if (lc($text) eq "vote yes") {

  if ($voting == 0) {
    snd ("NOTICE $nickname :Ei ole äänestystä!");
    next;
  }

  if (defined($voted{$iponly})) {
    snd ("NOTICE $nickname :Olet jo äänestänyt! (\002$votetopic\002)");
    next;
  }

  $votesyes++;
  $voted{$iponly} = $text;
  snd ("NOTICE $nickname :Äänesi on rekisteröity.");
  next;
}

##############
# VOTED AIHE #
##############
if (lc($text) eq "vote-aihe") {

  if ($voting == 0) {
    snd ("NOTICE $nickname :Ei ole äänestystä!");
    next;
  }

  sndtxt ("Äänestys on aiheesta: \002$votetopic\002 ");
  next;
}

############
# VOTED NO #
############
if (lc($text) eq "vote no") {

  if ($voting == 0) {
    snd ("NOTICE $nickname :Ei ole äänestyksiä! Anna komento \002${botname}: vote-aloita [aihe] aloittaaksesi äänestyksen.");
    next;
  }

  if (defined($voted{$iponly})) {
    snd ("NOTICE $nickname :Olet jo äänestänyt!");
    next;
  }

  $votesno++;
  $voted{$iponly} = $text;
  snd ("NOTICE $nickname :Äänesi on rekisteröity.");
  next;
}


###################
# VOTE POLL THING #
###################
if (lc($firstword) eq "kysely-aloita") {

  if ($nopoll && $usermode !~ / ADMIN /) {
    sndtxt ("Polls have been disabled by my owner.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}: start-poll topic ~~ option1 ~~ option2 ~~ etc ~~");
    next;  
  }

  if ($polling == 1) {
    sndtxt ("A poll is still in progress, use \002$botname: kysely-lopeta\002 to finish.");
    next;
  }

  $polltopic = substr($text,14,index($text,"~~")-11);
  $pollchoices = substr($text,index($text,"~~")-1);
  @polloptions = split("~~",$pollchoices);

#  $polltopic = substr($text,10,index($text,"|")-11);
#  $pollchoices = substr($text,index($text,"|")-1);
#  @polloptions = split(/\|/,$pollchoices);

  if (@polloptions < 3) {
    sndtxt ("Must have at least two choices!");
    next;
  }

  if (@polloptions > $maxpolloptions) {
    sndtxt("Too many options! Keep below " . ($maxpolloptions+1) . ".");
    next;
  }

  sndtxt ("$nickname aloitti kyselyn(poll): \002$polltopic\002");

  for ($i = 1;$i < @polloptions;$i++) {
    $polloptions[$i] = stripspaces($polloptions[$i]);
    sndtxt ("$i: $polloptions[$i]");
    $pollvotes[$i] = 0;
  }

  sndtxt ("Osallistu komennolla \002$botname: kysely [number]\002 . \002$botname: kysely-lopeta\002 lopettaa kyselyn.");

  $polling = 1;
  $pollstarted = $nickname;
  $polltotal = 0;
  %polled = ();

  next;

}

#################
# STOP THE POLL #
#################
if (lc($text) eq "kysely-lopeta") {

  if ($polling == 0) {
    sndtxt("Ei käynnissä olevia kyselyitä!");
    next;
  }

  if ( (lc($nickname) ne lc($pollstarted)) && ($usermode !~ / ADMIN /) && ($usermode !~ / OP /) ) {
    sndtxt ("Only $pollstarted or an ADMIN/OP can stop the poll.");
    next
  }

  $polling = 0;
  sndtxt ("Kysely aiheesta: \002$polltopic\002 loppui. Tulokset:");
  if ($polltotal == 0) {
    sndtxt ("Kukaan ei osallistunut!");
    next;
  }

  for ($i = 1;$i < @polloptions;$i++) {
    sndtxt ("\002$polloptions[$i]: \002$pollvotes[$i] (" . round(($pollvotes[$i] / $polltotal) * 100,5) . "%)");
  }
  next;
}

####################
# CAST A POLL VOTE #
####################
if (lc($firstword) eq "kysely") {

  local $query = "";

  if ($polling == 0) {
    snd ("NOTICE $nickname :There is no poll in progress! Use \002${botname}: start-poll [topic] | [option1|option2|etc] to begin a poll.");
    next;
  }

  $query = substr($text,7);

  if ($query =~ /\D/) {
    snd ("NOTICE $nickname :You must specify the item number, eg \002$botname, poll 2\002.");
    next;
  }

  if (!defined($polloptions[$query]) || ($query eq '0')) {
    snd ("NOTICE $nickname :There is no option $query!");
    next;
  }

  if (defined($polled{$iponly})) {
    snd ("NOTICE $nickname :You already voted in that poll!");
    next;
  }

  $pollvotes[$query]++;
  $polltotal++;

  $polled{$iponly} = $text;
  snd ("NOTICE $nickname :Your vote has been registered.");
  next;
}

if (lc($firstword) eq 'whois') {
  local $mymask = "";
  local $mask = substr($text, 6);
  local $nummatches = 0;
  local $match = "";
  local $excess = 0;

  if ($mask eq '') {
    sndtxt ("Usage: \002$botname, whois nick!ident\@host.domain\002 (use wildcards, case sensitive)");
    next;
  }

  if ($mask !~ /.+!.+\@.+/) {
    sndtxt ("Query mask must be in the format nick!ident\@domain, eg \002$botname, whois *!lamer@*.aol.com\002");
    next;
  }

  $mymask = regexify($mask);

  if (eval 'if ($hosts{lc($nickname)} =~ /$mymask/) {}', $@) {
    sndtxt ("Bad query mask: $mask");
    next;
  }

  foreach (keys %hosts) {
    if ($hosts{$_} =~ /$mymask/) {
      if (++$nummatches > 10) {
        $excess++;
      } else {
        if ($nummatches > 1) {
          $match .= ", ";
        }
        ($nick) = split (/!/, $hosts{$_});
        $match .= $nick;
      }
    }
  }

  if ($excess) {
    $match .= ", ($excess others...)";
  }

  if ($match eq '') {
    $match = "None.";
  }
  sndtxt ("Users matching $mask: $match");
  next;
}

###############
#  DISK (!)  #
###############
#if (lc($text) eq "df") {
#  foreach $_ (`df`) {
#    sndtxt ($_);
#  }
#  next;
#}

###############
# ACCESS HELP #
###############
if (lc($firstword) eq "whatis") {

  local $query = "";

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, whatis [accesslevel]\002 for info.");
    next;  
  }

  $query = uc(substr($text,7));

  $query =~ s/\[//;
  $query =~ s/\]//;


  if ((lc($query) eq "level") || (lc($query) eq "accesslevel")) {
    sndtxt("*cough${nickname}isamoroncough*");
    next;
  }

  if (!defined($hlp{$query})) {
    sndtxt ("$query is not a valid user mode.");
    next;
  }

  sndtxt ("$query - $hlp{$query}");
  next;

}

if (lc($text) eq 'help' || lc ($text) eq 'commands'){
  sndtxt ("komento referenssi: http://www.r1ch.net/projects/bitchbot/commands/");
  next;
}


################################################################
################################################################
################################################################
################################################################
################################################################
################################################################
# 5 w OMAT JUTUT JOTKA TARKOITETTU KAIKILLE                    #
################################################################
if (lc($text) eq 'amuse' ) {
  my $quotesfile = "quotes.txt";
  my $data_file2= $quotesfile;
  open(DAT, $data_file2) || die("Could not open file!\n\r");
  @quotes=<DAT>;
  close(DAT);
  my $range = @quotes;
  my $nro = rand($range);
  my $quote = @quotes[$nro];

  sndtxt ($quote);
  next;
}
if (lc($text) eq 'projektit-top3' ) {
  sndtxt ("top3 palauttaa aktiivisimmat projektit ja linkit niihin");
  next;
}

if (lc($text) eq 'listalle' ) {
  my $quotesfile = "quotes.txt";
  my $data_file2= $quotesfile;
  open(DAT, $data_file2) || die("Could not open file!\n\r");
  @quotes=<DAT>;
  close(DAT);
  my $range = @quotes;
  my $nro = rand($range);
  my $quote = @quotes[$nro];

  sndtxt ($quote);
  next;
}
if (lc($text) eq 'projektit-top3' ) {
  sndtxt ("top3 palauttaa aktiivisimmat projektit ja linkit niihin");
  next;
}

## MANUAALIHAKU KOMENNOLLE ########################
if (lc($firstword) eq "man") {

    my @in = split(' ', $text);
    my $cmd = @in[1];
    getMan($cmd);
 
  next;
}

## HAE PROJEKTIEN NIMET ########################################
if (lc($text) eq 'uusin-ehdotus' ) {
    my $prefix = "Haen uusimman projektiehdotuksen.";
    $CmdQueue->enqueue("projektit 1 ".$msgto);
    sndtxt($prefix);
  next;
}

## HAE PROJEKTEJA PARAMETRI KERTOO MOODIN ########################
if (lc($firstword) eq "projektit-moodi") {
  my $moodi = substr($text,15);
  $moodi =~ s/\[//;
  $moodi =~ s/\]//;

#      print("msgto = $msgto.\n\r");
#  $msgto = $nickname;
#print("msgto = $msgto.\n\r");
  if($moodi<5){
      my $prefix = "Haen projekteja (maks 3kpl) moodista: ".$moodi;
      
      if(is_integer_string($moodi)){
	 # $msgto = $nickname;
	  $CmdQueue->enqueue("projektit-moodi ".$moodi." ".$msgto);
	  sndtxt ($prefix);
      }else{
	  $prefix = "Antamasi parametri (".$moodi.") ei ole moodia määrittävä luku (1,2,3 tai 4).";
	  sndtxt ($prefix);
      }
  }else{
      sndtxt ("Antamasi parametri (".$moodi.") ei ole moodia määrittävä luku (1,2,3 tai 4).");
  }
  next;
}

## HAE PROJEKTIEHDOTUKSIA, PARAMETRI KERTOO MONTAKO ########################
if (lc($firstword) eq "projektit") {
  my $montako = substr($text,9);
  $montako =~ s/\[//;
  $montako =~ s/\]//;
  my $prefix = "Haen ".$montako." projektia:";

  if(is_integer_string($montako)){
      if($montako > 5){
	  $montako = 5;    
	  $prefix = "Määrä voi olla enintään 5. Haen siis 5 projektia.";
	  $CmdQueue->enqueue("projektit ".$montako." ".$msgto); # lisaa saikeen kasittelyjonoon
      }else{
	  $CmdQueue->enqueue("projektit ".$montako." ".$msgto);
      }
      sndtxt ($prefix);
  }else{
      $prefix = "Antamasi parametri ei ole kokonaisluku.";
       sndtxt ($prefix);
  }
  next;
}

## HAE PROJEKTIN TIEDOT, PARAMETRI KERTOO ID:N ########################
if (lc($firstword) eq "projekti") {
# projekti 324 kuvaus | miten | koska | kuka 
    my $params = substr($text,8);
    my @in = split(' ', $params);
    my $pid = @in[0];
    my $itemwanted = @in[1];
    my $ilen = length($itemwanted); 
    
#    print (" item = ".$itemwanted);
#    print (" len = ".length($itemwanted));
    print("firstword = projekti, msgto = $msgto\n\r");
    $pid =~ s/\[//;
    $pid =~ s/\]//;
#    $item =~ s/\[//;
#    $item =~ s/\]//;
    my $prefix = "Haen projektin id:".$pid." tietoja";
    
    

    if(is_integer_string($pid)){
	$CmdQueue->enqueue("projekti ".$pid);
	if($ilen > 3){
	    print("kentta: ".$itemwanted."\n\r");
	    $prefix = "Haen projektin:".$pid." tietoa: ".$itemwanted;
	    $CmdQueue->enqueue("projekti ".$pid." ".$itemwanted." ".$msgto);
	}else{
	    $CmdQueue->enqueue("projektidetail ".$pid." ".$msgto);
	}
	#sndtxt ($prefix);
    }
    else{
	$prefix = "Antamasi parametri ei ole kokonaisluku.";
	#$msgto = $nickname;
	sndtxt ($prefix);
    }
  next;
}


## HAE PERUSKOMENNOT OSOITE  ########################################
if ((lc($text) eq 'komennot' ) || (lc($text) eq 'apua' )) {
  sndtxt ("Komennot löytyvät portaalista: http://5w.fi/con/index.php/kommunikointi/irc/irc-bot ");
  next;
}

## HAE ADMIN/OP NICKNAMET  ########################################
if (lc($text) eq 'admins' ) {
  snd ("NOTICE $nickname : Löytyi ADMIN: $adminnick , OPS: ");
  next;
}

## HAE HALLITUKSEN SEURAAVAN KOKOUKSEN TIEDOT ########################################
if ((lc($text) eq 'hallitus-kokous' ) || (lc($text) eq 'kokous-hallitus' )) {
  #sndtxt ("Hakee 5w ry:n hallituksen seuraavan kokouksen tiedot");
  my $suffix = getHallitusKokous();
  if(length($suffix)<10){
      $suffix = "Uups! En pystynyt hakemaan kokouksen ajankohtaa.";
  }
  sndtxt("Hallituksen kokous: ".$suffix);
  next;
}

## HAE HALLITUKSEN SEURAAVAN KOKOUKSEN TIEDOT ########################################
if ((lc($text) eq 'hae-hallitus-kokous' ) || (lc($text) eq 'hae-kokous-hallitus' )) {
  #sndtxt ("Hakee 5w ry:n hallituksen seuraavan kokouksen tiedot");
  #my $suffix = getHallitusKokousTxt($msgto);
    $CmdQueue->enqueue("hae-kokous $msgto");
  next;
}

## HAE UUTISIA, PARAMETRI KERTOO MONTAKO ########################
if (lc($firstword) eq "tapahtumat-listaa") {
    my $montako = substr($text,17);
    $montako =~ s/\[//;
    $montako =~ s/\]//;
#    sndtxt ($montako);
    my $prefix = "Haen ".$montako." tapahtumaa:";
    
    if(is_integer_string($montako)){
	if($montako > 5){
	    $montako = 5;    
	    $prefix = "Määrä voi olla enintään 5. Haen siis 5 uutista.";
	    $CmdQueue->enqueue("uutiset ".$montako." ".$msgto); # lisaa saikeen kasittelyjonoon
	    sndtxt ($prefix);
	}else{
	    $CmdQueue->enqueue("uutiset ".$montako." ".$msgto);
	}
	
    }else{
	$prefix = "Antamasi parametri (".$montako.") ei ole kokonaisluku.";
	sndtxt ($prefix);
    }
    next;
}



##############################################################
# 5W ADMIN OP komennot

## FACEBOOK STUFF 
if (lc($firstword) eq "fb-wall") {

    my $message = substr($text,7);
    print($usermode);
    if ( ($usermode !~ / ADMIN /) && ($usermode !~ / OP /) ) {
	sndtxt ("Vain ADMIN/OP voi postittaa ryhmän Facebook seinälle.");
	next;
    }
    $FbQueue->enqueue("wall#.#".$msgto."#.#".$message);
    
    next;
}

if (lc($firstword) eq "fb-link") {

    my $raw = substr($text,7);
    my @items = split("##",$raw);
    if ( ($usermode !~ / ADMIN /) && ($usermode !~ / OP /) ) {
	sndtxt ("Vain ADMIN/OP voi postittaa ryhmän Facebook seinälle.");
	next;
    }
    $FbQueue->enqueue("link#.#".$msgto."#.#".@items[0]."#.#".@items[1]);
    
    next;
}


###
if (lc($firstword) eq "hiljaa")  {
my $moodi = substr($text,7);

 if ( (lc($nickname) ne lc($pollstarted)) && ($usermode !~ / ADMIN /) && ($usermode !~ / OP /) ) {
    sndtxt ("Vain ADMIN/OP voi muuttaa asetuksia.");
    next;
  }

if(is_integer_string($moodi)){

  if ($moodi == 1) {
      if($lurkki_hiljaa == 0){
	  sndtxt("hymph, ei sitten...ollaan hiljaa. Muista laittaa päälle joskus...");
	  $lurkki_hiljaa = 1;
	  next;
      }else{
	  sndtxt("on jo hiljaa...uskon kerrasta.");
	  next;
      }
  }
  if ($moodi == 0) {
      if($lurkki_hiljaa == 1){
	  sndtxt("hyppii ilosta, koska sai luvan osallistua.");
	  $lurkki_hiljaa = 0;
	  next;
      }else{
	  sndtxt("joo, joo! ilmoitan kun on jotain sanottavaa.");
	  next;
      }
  }
      
  if (($moodi != 1) or ($moodi != 0)){
      sndtxt("komento ei nyt täsmää: hiljaa 0 | 1");
      next;
  } 
}else{
    sndtxt("hyvä yritys, mutta parametri ei kelpaa :)");
}

}



##############################################################
sub is_integer_string {

   # a valid integer is any amount of white space, followed
   # by an optional sign, followed by at least one digit,
   # followed by any amount of white space

   return $_[0] =~ /^\s*[\+\-]?\d+\s*$/;
}
sub getHallitusKokous {
    my $url = "http://hallitus.5w.fi/kokous.txt";
    my $asialista = get($url);
    $asialista =~ s/\r|\n//g;
    my $begin = index $asialista, "Aika:";
    my $end =  index $asialista, "----";
    return substr($asialista,$begin+6,$end-$begin-6);
}



#########################
## 5W SAIKEET
#@threads = threads->list();
#$workers = threads->list(); # TODO: Saa tehda.
#foreach $thr (@threads) { 
#    sndtxt("t:".$thr->tid()); 
#}
################################################################


######################
######################
# OP ONLY COMMANDS   #
######################
######################


#############
# OP IGNORE #
#############
if (lc($firstword) eq "ignore") {
  local $query = "";
  local $regex = "";
  local $origregex = "";
  local $timein = 0;
  local $timeout = 0;
  local $banmask = "";

  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Only users with access level OP can temporarily ignore users.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, ignore nick [minutes]\002 to ignore a user.");
    next;  
  }

  $query = substr($text,7);
  ($query,$timeout) = split(" ",$query);

  if (index($query,"\@") == -1) {
    if (!defined($hosts{lc($query)})) {
      sndtxt ("Sorry $nickname, I have no host info with which to ignore $query!");
      next;
    }
  } else {
    if ($usermode !~ / ADMIN /) {
      sndtxt ("Only ADMIN users can specify a custom ignore mask.");
      next;
    }
    if ($query !~ /.+!.+\@.+/) {
      sndtxt ("You must either specify a nickname to ignore or an address in the format nick!user\@host.domain (wildcards allowed)");
      next;
    }
    $origregex = $query;
    $regex = regexify($query);

    if (eval 'if ($hosts{lc($nickname)} =~ /$regex/) {}', $@) {
      sndtxt ("Conversion of $query to a regular expression failed. You probably messed up the hostmask or used some invalid characters.");
      next;
    }

  }

  if (!(defined($timeout))) {
    $timeout = 10;
  } else {
    if ($timeout eq '0') {
      sndtxt ("Perhaps you are looking for \002$botname, unignore\002?");
      next;
    } elsif ($timeout <= 0) {
      $timeout = 10;
    }
  }

  if ($timeout =~ /\D/) {
    sndtxt ("$timeout is not a valid number.");
    next;
  }

  $timein = $timeout;

  if ($timeout > 1440 && $usermode !~ / ADMIN /) {
    sndtxt ("Only users with ADMIN access can ignore a user for more than one day (1440 minutes)");
    next;
  }

  $timeout = (time + ($timeout * 60));

  $upTime = ($timeout - time());
  $upString = "";

  $upYears = int($upTime / (60*60*24*365));
  if ($upYears > 0) {
  	$upString .= $upYears." year";
  	$upString .= "s" if ($upYears > 1);
  	$upString .=", ";
  }
  $upTime -= $upYears * 60*60*24*365;

  $upWeeks = int($upTime / (60*60*24*7));
  if ($upWeeks > 0) {
  	$upString .= $upWeeks." week";
  	$upString .= "s" if ($upWeeks > 1);
  	$upString .=", ";
  }
  $upTime -= $upWeeks * 60*60*24*7;

  $upDays = int($upTime / (60*60*24));
  if ($upDays > 0) {
  	$upString .= $upDays." day";
  	$upString .= "s" if ($upDays > 1);
  	$upString .=", ";
  }
  $upTime -= $upDays * 60*60*24;

  $upHours = int($upTime / (60*60));
  if ($upHours > 0) {
  	$upString .= $upHours." hour";
  	$upString .= "s" if ($upHours > 1);
  	$upString .=", ";
  }
  $upTime -= $upHours *60*60;

  $upMinutes = int($upTime / 60);
  if ($upMinutes > 0) {
  	$upString .= $upMinutes." minute";
  	$upString .= "s" if ($upMinutes > 1);
  }

  if (substr($upString,-2,2) eq ', ') {
    $upString = substr($upString,0,(length($upString)-2));
  }

  $upTime -= $upMinutes * 60;

  if ($regex ne '') {
    $banmask = $regex;
    $query = "User specified mask";
  } else {
    if (index($query,"\@") == -1) {
      $banmask = substr($hosts{lc($query)},index($hosts{lc($query)},"\@")+1);
      @temp = split(/\./,$banmask);
      if ($#temp > 1) {
        if ($temp[$#temp] !~ /\D/) {
            $temp[$#temp]     = "*";
        } else {
            $temp[0]          = "*";
        }
      }
      $banmask = join('.',@temp);
      $nicemask = "*!*@$banmask";
      $banmask = regexify($banmask);
      $banmask = ".*!.*\@$banmask";
    } else {
      $banmask = $regex;
    }
  }

  $ignore{$banmask} = $timeout;

  $ignore_nicemask = deregexify ($banmask);

  sndtxt ("$query ($ignore_nicemask) is being ignored for $upString");
  next;
}

###############
# OP UNIGNORE #
###############
if (lc($firstword) eq "unignore") {
  local $regex = "";
  local $unignore_person = "";
  local $origregex = "";

  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Only users with access level OP can unignore users.");
    next;
  }
  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, unignore nick\002 to ignore a user.");
    next;  
  }
  
  $unignore_person = substr($text, 9);

  if (index($unignore_person,"\@") == -1) {
    if (!defined($hosts{lc($unignore_person)})) {
      sndtxt("Who the hell is $unignore_person?");
      next;
    }
  } else {
    if ($usermode !~ / ADMIN /) {
      sndtxt ("Only ADMIN users can specify a custom unignore mask.");
      next;
    }
    if ($unignore_person !~ /.+!.+\@.+/) {
      sndtxt ("You must either specify a nickname to unignore or an address in the format nick!user\@host.domain (wildcards allowed)");
      next;
    }
    $origregex = $unignore_person;
    $regex = regexify($unignore_person);

    if (eval 'if ($hosts{lc($nickname)} =~ /$regex/) {}', $@) {
      sndtxt ("Conversion of $unignore_person to a regular expression failed. You probably messed up the hostmask or used some invalid characters.");
      next;
    }
  }


  if ($regex ne '') {
    $unignore_hostmask = $regex;
    $unignore_person = "User specified mask";
  } else {
    if (index($query,"\@") == -1) {
      $unignore_hostmask = substr($hosts{lc($query)},index($hosts{lc($query)},"\@")+1);
      @temp = split(/\./,$unignore_hostmask);
      if ($#temp > 1) {
        if ($temp[$#temp] !~ /\D/) {
            $temp[$#temp]     = "*";
        } else {
            $temp[0]          = "*";
        }
      }
      $unignore_hostmask = join('.',@temp);
      $nicemask = "*!*@$unignore_hostmask";
      $unignore_hostmask = regexify($unignore_hostmask);
      $unignore_hostmask = ".*!.*\@$unignore_hostmask";
    } else {
      $unignore_hostmask = $regex;
    }
  }

  $unignore_nicemask = deregexify ($unignore_hostmask);

  if (defined($ignore{$unignore_hostmask})) {
    delete $ignore{$unignore_hostmask};
    sndtxt ("$unignore_person ($unignore_nicemask) is no longer being ignored");
  } else {
    sndtxt ("$unignore_person isn't in the ignore list...");
  }
  next;
}

########
# SLAP#
########
if (lc($firstword) eq "slap") {

  local $query = "";
  local @tokick;

  if (($usermode !~ / ADMIN /) && ($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Only users with access level OP can bitchslap users.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, bitchslap [nick]\002 to bitchslap [nick].");
    next;  
  }

#  if ($nicklist{lc($botname)} ne '@') {
#    sndtxt("Sorry $nickname, I need ops to do that.");
#    next;
#  }

  $query = substr($text,10);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {

    if (lc($query) eq lc($botname)) {
      sndtxt ("Dah! En kait minä itseäni läpsi...peelo.");
      next;
    }

    sndtxt("\001ACTION grabs $query by the ass and gives 'em a good slappin!\001");
 #   snd("KICK $channel $query :You have been bitchslapped!");
  }
  next;
}

########
# KICK #
########
if (lc($firstword) eq "kick") {

  local $query = "";
  local @tokick;

  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Only users with access level OP can kick users.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, kick [nick]\002 to kick [nick] from $channel.");
    next;  
  }

  if ($nicklist{lc($botname)} ne '@') {
    sndtxt("Sorry $nickname, I need ops to do that.");
    next;
  }

  $query = substr($text,5);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {

    if (lc($query) eq lc($botname)) {
      sndtxt ("I'm not going to kick myself, moron.");
      next;
    }

    snd("KICK $channel $query :$kicks[rand($#kicks)]");
  }
  next;
}


###########
# KICKBAN #
###########
if (lc($firstword) eq "kickban") {

  local $query = "";
  local @tokick;

  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Only users with access level OP can kickban users.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, kickban [nick]\002 to kickban [nick] from $channel.");
    next;  
  }

  if ($nicklist{lc($botname)} ne '@') {
    sndtxt("Sorry $nickname, I need ops to do that.");
    next;
  }


  $query = substr($text,8);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {

    if (lc($query) eq lc($botname)) {
      sndtxt ("I'm not going to kickban myself, moron.");
      next;
    }

    snd("MODE $channel +b *!*@" . substr($hosts{lc($query)},index($hosts{lc($query)},"\@")+1));
    snd("KICK $channel $query :$kicks[rand($#kicks)]");
  }
  next;
}


########### 
# JUSTBAN # 
########### 
if (lc($firstword) eq "ban") { 
 
  local $query = ""; 
  local @tokick; 
 
  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) { 
    sndtxt ("Only users with access level OP can ban users."); 
    next; 
  } 
 
  if (index($text," ") == -1) {  
    sndtxt ("Missing parameter. Use \002${botname}, ban [nick]\002 to ban [nick] from $channel."); 
    next;   
  } 
 
  if ($nicklist{lc($botname)} ne '@') { 
    sndtxt("Sorry $nickname, I need ops to do that."); 
    next; 
  } 
 
 
  $query = substr($text,4); 
 
  @tokick = split(" ",$query); 
 
  foreach $query (@tokick) { 
 
    if (lc($query) eq lc($botname)) { 
      sndtxt ("I'm not going to ban myself, moron."); 
      next; 
    } 

    snd("MODE $channel +b *!*@" . substr($hosts{lc($query)},index($hosts{lc($query)},"\@")+1)); 
  } 
  next; 
} 

########### 
# UN  BAN # 
########### 
if (lc($firstword) eq "unban") { 
 
  local $query = ""; 
  local @tokick; 
 
  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) { 
    sndtxt ("Only users with access level OP can unban users."); 
    next; 
  } 
 
  if (index($text," ") == -1) {  
    sndtxt ("Missing parameter. Use \002${botname}, unban [nick]\002 to unban [nick] from $channel."); 
    next;   
  } 
 
  if ($nicklist{lc($botname)} ne '@') { 
    sndtxt("Sorry $nickname, I need ops to do that."); 
    next; 
  } 
 
 
  $query = substr($text,6); 
 
  @tokick = split(" ",$query); 
 
  foreach $query (@tokick) { 
 
  snd("MODE $channel -b *!*@" . substr($hosts{lc($query)},index($hosts{lc($query)},"\@")+1)); 
  } 
  next; 
} 

############
# VOICE    #
############
if (lc($firstword) eq "voice") {

  local $query = "";
  local @tokick;

  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Only users with access level OP can voice users.");
    next;
  }


  if ($nicklist{lc($botname)} ne '@') {
    sndtxt("Sorry $nickname, I need ops to do that.");
    next;
  }

  if (index($text," ") == -1) { 
    $text = $text . " $nickname";
  }

  $query = substr($text,6);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {
    snd("MODE $channel +v $query");
  }

  next;
}

############
#   DEOP     #
############
if (lc($firstword) eq "deop") {

  local $query = "";
  local @tokick;

  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Only users with access level OP can -o users.");
    next;
  }

  if ($nicklist{lc($botname)} ne '@') {
    sndtxt("Sorry $nickname, I need ops to do that.");
    next;
  }
  
  if (index($text," ") == -1) { 
    $text = $text . " $nickname";
  }

  $query = substr($text,3);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {
    snd("MODE $channel -o $query");
  }
  next;
}

############
#   OP     #
############
if (lc($firstword) eq "op") {

  local $query = "";
  local @tokick;

  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Only users with access level OP can +o users.");
    next;
  }

  if ($nicklist{lc($botname)} ne '@') {
    sndtxt("Sorry $nickname, I need ops to do that.");
    next;
  }

  if (index($text," ") == -1) { 
    $text = $text . " $nickname";
  }

  $query = substr($text,3);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {
    snd("MODE $channel +o $query");
  }
  next;
}



####################
###################
################
## admin cmds ##
################
####################
#####################

############
# SHUTDOWN #
############
if (lc($text) eq "quit") {
  if ($usermode =~ / ADMIN /) {
    open (NOSPAWN, ">${win321}nospawn");
    print NOSPAWN "quit";
    close (NOSPAWN);
    snd ("QUIT :$bot_version_number by R1CH - http://www.r1ch.net/projects/bitchbot/");
    sleep 1;
    &Cleanup;
    exit;
  } else {
    sndtxt ("You need ADMIN level access to make me go away!");
    next;
  }
}

###################
# DENIED FACTOIDS #
###################
if (lc($firstword) eq 'undeny') {
  local $query = lc(substr($text,7));
  local $i = 0;

  if ($usermode =~ / ADMIN /) {
    for ($i = 0;$i < ($#deny+1);$i++) {
      if ($deny[$i] eq lc($query)) {
        splice (@deny,$i,1);
        sndtxt("Factoid adding for $query is now allowed.");
        next STARTOFLOOP;
      }
    }
    sndtxt("Factoid adding for $query isn't denied anyway!");
    next;
  } else {
    sndtxt("You must have ADMIN access to undeny factoids.");
    next;
  }
}

if (lc($firstword) eq 'deny') {

  local $query = lc(substr($text,5));

  if ($usermode =~ / ADMIN /) {

    foreach (@deny) {
      if ($_ eq lc($query)) {
        sndtxt("Factoid adding for $query is already denied!");
        next STARTOFLOOP;
      }
    }

    $deny[$#deny+1] = lc($query);
    sndtxt("Factoid adding for $query has been denied.");
    next;
  } else {
    sndtxt("Only ADMIN can add denies.");
    next;
  }
}

##################
# VIEW MISC LOGS #
##################
if (lc($firstword) eq "viewlogs") {
  if ($usermode =~ / ADMIN /) {

    local $tail = "-10";
    local $log;

    close (BITCHLOG);

    $log = "$win321$scriptname.log";

  	open (ACCESS, "tail $tail $log | tail $tail |");
  	while (<ACCESS>) {
  	  snd("PRIVMSG $nickname :$_");
  	}
  	close (ACCESS);

    open (BITCHLOG, ">>$win321$scriptname.log") or die "can't output to logfile: $!\n";
  } else {
    sndtxt("Only ADMIN can view logs.");
  }

  next;
}

############
# EVAL CMD #
############
if (lc($firstword) eq "eval") {
  if ($noeval == 1) {
    sndtxt("Eval disabled.");
    next;
  }
  if ($text =~ /\Q$operpass\E/) {
    next;
  }
  if ($usermode =~ / ADMIN /) {
    eval substr($text,5);
    if ($@ ne '') {
      sndtxt("Error: $@");
    } 
  } else {
    sndtxt("Eval denied.");
  }
  next;
}

########
# OPER #
########
if ($text eq "oper") {
  if ($usermode =~ / ADMIN /) {
    snd("OPER $opername $operpass");
  }
  next;
}

#############
# OPER KILL #
#############
if (lc($firstword) eq "kill") {

  local $query = "";
  local $killnick = "";
  local $killmsg = "";

  if ($usermode =~ / ADMIN /) {
    $query = substr($text,5);
    if (index($query, " ") == -1) {
      sndtxt ("Missing parameter");
      next;
    }
    $killnick = substr($query,0,index($query," "));
    $killmsg  = substr($query,index($query," ")+1);
    snd("KILL $killnick :$killmsg");
    next;
  } else {
    sndtxt("Denied.");
    next;
  }
}


#############
#CHANGE NICK#
#############
if (lc($firstword) eq "changenick") {
  if ($usermode =~ / ADMIN /) {

    local $valid = 0;

    #yuck.
    @tmp = split(//, substr($text,11));
    foreach (@tmp) {
      if (index($nickchars,$_) == -1) {
        sndtxt ("Illegal nickname: Can't contain a $_\n");
	next STARTOFLOOP;
      } else {
        $valid = 1;
      }
    }
    undef @tmp;

    if ($valid == 0) {
      sndtxt("Must specify a valid nickname!");
      next;
    }

    snd ("NICK " . substr($text,11));

    $botname = substr($text,11);

  } else {
    sndtxt ("You need ADMIN access to change my nick.");
  }
  next;
}

##############
#MOVE CHANNEL#
##############
if (lc($firstword) eq "migrate") {
  if ($usermode =~ / ADMIN /) {
    snd ("PART $channel");
    $channel = substr($text,8);
    snd ("JOIN $channel $key");
    snd ("WHO $channel");
  } else {
    sndtxt ("You need ADMIN access to make me migrate.");
  }
  next;
}

############
# VALIDATE #
############
if (lc($firstword) eq "validate") {
  if ($usermode =~ / ADMIN /) {
    foreach (validateurl (substr($text,9))) {
      sndtxt($_);
    }
  } else {
    sndtxt("Validate is only available to ADMIN users.");
  }
  next;
}

###########
# RESTART #
###########
if (lc($text) eq "restart") {
  if ($usermode =~ / ADMIN /) {
    snd ("QUIT :$bot_version_number");
    sleep 1;
    &Cleanup;
    exit;
  }
}




############################
# DELETE USER (its a hack) #
############################
if (lc($firstword) eq "deluser") {

  local $query = "";

  if ($usermode !~ / ADMIN /) {
    sndtxt ("Only users with access level ADMIN can remove users.");
    next;
  }

  $firstword = "adduser";
  # Get the address
  $query = substr($text,8);

  if ($query eq "") {
      sndtxt ("You forgot to specify a user, moron.");
    next;
  }

  # Split to IP/hostmask ONLY (or do nick lookup)

#  if (index($query," ") != -1) {
#    $accesslevels = substr($query,index($query," ")+1);
#    $query = substr($query,0,index($query," "));
#  }

  $text = "adduser $query DELETE";
}

##################
# ADD USER TO DB #
##################
if (lc($firstword) eq "adduser") {

if ($usermode !~ / ADMIN /) {
  sndtxt ("Only users with access level ADMIN can add users.");
  next;
}

local @temp = ();
local $query = "";
local $fullhost = "";
local $accesslevels = "";
local $ident = "";


# Get the address
$query = substr($text,8);

if ($query eq "") {
  sndtxt ("You forgot to specify a user, moron.");
  next;
}

# Split to IP/hostmask ONLY (or do nick lookup)

if (index($query," ") != -1) {
  $accesslevels = uc(substr($query,index($query," ")+1));
  $query = substr($query,0,index($query," "));
}

$usertoadd = $query;

if (index($query,"\@") == -1) {
  #$query = substr($query,index($query," "));

  if ($hosts{lc($query)} eq "") {
    sndtxt ("Could not look up address for ${query}.");
    next;
  }

  $query = $hosts{lc($query)};

}

$fullhost = $query;

# Get IDENT (position before the @)
$ident = substr($query,0,index($query,"\@"));
$ident = substr($ident,index($ident,"!")+1);

$query = substr($query,index($query,"\@")+1);

@temp = split(/\./,$query);

if ($accesslevels !~ "STATIC") {
######################################
# If STATIC is not a access level...
######################################
  if ($temp[$#temp] !~ /\D/) {
      ########################################################
      ## It's an IP, change the last two digits to wildcards #
      ########################################################
      $temp[$#temp]     = "[0-9]*";
      $temp[$#temp - 1] = "[0-9]*";
  } else {
      ##################################################################
      # Its a domain name thingy, add it with the *!*ident@*.rest.of.ip
      ##################################################################
      $temp[0]          = ".*";
  }
}


if ($accesslevels eq "") {
  sndtxt ("Hey $nickname you forgot what user levels to give $usertoadd. *coughretardcough*");
  next;
}

$regex = ".*!.*${ident}\@".join("\\.",@temp);
$accesslevels = " $accesslevels ";
@checkaccess = split(" ",$accesslevels);


TisOK: foreach $test (@checkaccess) {

  foreach $testcompare (@usermodes) {
    if (lc($testcompare) eq lc($test)) {
      next TisOK;
    }
  }

  if (uc($test) ne "DELETE") {
    sndtxt ("$nickname, $test is not a valid user mode.");
    next STARTOFLOOP;
  }
}


if (index(uc($accesslevels)," DELETE ") == -1) {

  if (defined($access{$regex})) {
    sndtxt ("$usertoadd already has access!");
    next;
  }

  $access{$regex} = $accesslevels;
  sndtxt ("$usertoadd was added successfully.");
  snd ("NOTICE $usertoadd :You have been given access levels\002$accesslevels\002- use \002$botname, whatis [level]\002 for more info.");
  snd ("NOTICE $nickname :You gave $usertoadd access levels\002$accesslevels\002- Reg. Ex is $regex");
} else {
  if (defined($access{$regex}) && $access{$regex} ne "") {
    delete $access{$regex};
    sndtxt ("$usertoadd was removed successfully.");
  } else {
    sndtxt ("No match in access hash for $usertoadd.");
  }
}

next;
}

########################
#  ADD A FACTOID(TM)
########################

for ($i = 0;$i < @splitwords;$i++) {
  if (index($text,$splitwords[$i]) != -1) {
    $splitter = $splitwords[$i];
    $object = substr($text,0,index($text,$splitter));
    $object =~ s/\?//gi;
    $object =~ s/://gi;
    if ($object =~ /[\001-\037]/) {
      sndtxt("Grr, stop trying to break me $nickname!");
      next;
    }
    $fact = substr($text,index($text,$splitter)+length($splitter));

    if ($usermode !~ / ADMIN /) {
      foreach $testm (@deny) {
        if (lc($object) eq $testm) {
          sndtxt("Adding factoids for $object is denied.");
          next STARTOFLOOP;
        }
      }
    }

    if ((defined($deltimer{lc($nickname)})) && (time() - $deltimer{lc($nickname)} < 0)) {
      sndtxt("Please wait " . ($deltimer{lc($nickname)} - time()) . " seconds before using this function.");
      next STARTOFLOOP;
    }

    if ($usermode !~ / ADDFACTS /) {
      sndtxt ("Only users with access level ADDFACTS can add factoids.");
      next STARTOFLOOP;
    }

    for ($p = 0;$p < @facts;$p++) {
      if ((lc($facts[$p]) eq lc($fact)) && (lc($objects[$p]) eq lc($object))) {
        sndtxt ("...but $nickname, $object${splitter}already ${fact}!");
        next STARTOFLOOP;
      }
    }

    $sfact = $fact;
    $sfact =~ s/[\001-\037]//gi;

    if (index(lc($sfact),"<reply>") != -1) {
      $sfact = substr($sfact,index(lc($sfact),"<reply>")+7);
    }

    if (index(lc($sfact),"<action>") != -1) {
      $sfact = substr($sfact,index(lc($sfact),"<action>")+8);
    }

    $sfact =~ s/^\s+//;
    $sfact =~ s/\s+$//;

    if (($sfact eq '') || ($object eq '')) {
      sndtxt("Stop haxing me damnit ${nickname}!");
      next STARTOFLOOP;
    }

    undef $sfact;

    $thatnum = 0;
    undef $thatfact;

    for ($i = 0; $i < (($#objects)+1); $i++) {
      if (lc($objects[$i]) eq lc($object)) {
        $thatnum++;
      }
    }
    undef $i;

    $thatfact = ($#objects+1);
    $facts[$#facts+1] = $fact;
    $objects[$#objects+1] = $object;
    $splitters[$#splitters+1] = $splitter;
    $owners[$#owners+1] = $nickname;
    sndtxt ("OK $nickname");
    &SaveData;
    $newfacts++;
    next STARTOFLOOP;
  }
}




###################################
###################################
#F A C T O I D S  L O O K U P ! ! !
###################################
###################################

$text2 = $text;

($text2,$num) = split(":",$text2);
$text2 =~ s/\?//g;

GetFactoid($text2);

if ((defined($factoidmsg[$#factoidmsg])) && ($factoidmsg[$#factoidmsg] ne "")) {
  if ((!defined($num)) || ($num eq "")) {
    $randm = int(rand(@factoidmsg));
    $thatnum = $randm;
    sndtxt ($factoidmsg[$randm]);
  } else {
    if ($num eq 'last') {
      $num = $#factoidmsg;
    }
    if (defined($factoidmsg[$num])) {
      sndtxt ($factoidmsg[$num]);
      $thatnum = $num;
    } else {
      sndtxt ("There is no factoid number $num for $text2.");
    }
  }
  next;
}

if ($silent == 0) {
  snd ("NOTICE $nickname :Sorry $nickname, I don't know what '$text' ".isare($text).".");
}

}


####################
# PING SERVER BACK #
####################
if ($line =~ /^PING :/) {
  $lastpong = time();
  snd ("PONG :" . substr($line,index($line,":")+1));

  foreach $iponly ( keys (%ignore )) {
    if (($ignore{$iponly} - time) <= 0) {
      delete $ignore{$iponly};
    }
  }
}

##################################
#   PRINT RECEIVED LINE TO CON
##################################

#print "${hostmask}: $maintext";
#print substr($line,index($line,":")+1);

}

######################################
#            EXIT CODE
######################################

open (QIT,">>${win321}${scriptname}quit.log");
print QIT "Connection lost at ".localtime()." - last error was $!\n";
close (QIT);
&Cleanup;
exit;

#########################
#   NICKSERV SUB CODE   #
#########################

sub NickServ {
  if ($botpass ne "") { 
  	snd ("PRIVMSG NICKSERV :GHOST $botname $botpass");
  }
  sleep 1;

  if ($botpass ne "") {
    snd ("NICK $botname");
  }

  if ($autooper == 1) {
    snd("OPER $opername $operpass");
  }

  if ($botpass ne "") {
  	snd ("PRIVMSG NICKSERV :IDENTIFY $botpass");
  }

  sleep 1;
  snd ("JOIN $channel $key");
  snd ("WHO $channel");
  if ($#facts + $#splitters + $#objects + $#owners != $#facts * 4) {
    sleep 6;
    sndtxt ("\002\003" . "4WARNING\003\002: Factoid database appears corrupted! $#facts facts for $#objects objects, with $#owners owners and $#splitters splitwords.");
    sleep 1;
    snd ("QUIT: Factoid database is FUBAR!!");
    sleep 1;
    die "Factoid database is corrupted!\n";
  }
}

##############
# SND TO SERV
##############


sub snd {
  my ($text) = @_;
  chomp ($text);
  $text = $text . $nl;
  if ($verbose eq "on") { print "SEND: $text" }
  send (SOCK,$text,0);
  return;
}

sub snd2 {
  my ($text) = shift;
# chomp ($text);
print "SEND: $text"; 
  $text = $text . $nl;
  send (SOCK,$text,0);
  return;
}

##############
# SEND TEXT
##############


sub sndtxt {
  my ($i) = 0;
  my ($txt) = @_;
  my ($ch) = 0;
  if ($verbose eq "medium") {
    print "<${botname}> $txt\n";
  }

  if (!($chanstats_running)) {
    $action = 0;

    if ($txt =~ /^\001.*\001$/) {
      $action |= 1;
      logline ($action, $botname, $txt);
    } elsif ($txt =~ /\?$/) {
      $action |= 3;
      logline ($action, $botname, $txt);
    } else {
      $action |= 0;
      logline ($action, $botname, $txt);
    }
  }

  @haq = split(/ /,$txt);

  for ($i = 0;$i < @haq;$i++) {
    if ($haq[$i] =~ /(^http:\/\/)|(^https:\/\/)|(^www\.)|(^ftp:\/\/)|(^ftp\.)|(^members\..*)/i) {
      $haq[$i] = "12" . $haq[$i] . "";
      $ch = 1;
    }
  }

  if ($ch == 1) {
    $txt = join(" ",@haq);
  }

  snd ("PRIVMSG $msgto : $txt");
}

########################
# COW = IS, COWS = ARE
########################

sub isare {
  my ($txt) = @_;
  if (substr($txt,length($txt)-1,1) eq "s") {
    return "are";
  } else {
    return "is";
  }
}

########################
#  SAVE ALL DATAS!!!!
########################


sub SaveData {

  if ($#facts + $#splitters + $#objects + $#owners != $#facts * 4) {
    sndtxt ("\002\003" . "4WARNING\003\002: Factoid database appears corrupted! Please let $adminnick know what you just did. INFO: $#facts facts for $#objects objects, with $#owners owners and $#splitters splitwords.");
    die "Factoid database is corrupted!\n";
  }

  local $, = "\n";

  open (MSG,">$win321$datadir/msg1.dat") or die "Can't save msg1: $!\n";
  print MSG @msg;
  #, "\n";
  close (MSG) or die "Can't close msg1.dat: $!\n";

  open (OWNZ,">$win321$datadir/owners.dat") or die "Can't save data: $!\n";
  print OWNZ @owners;
  #, "\n";
  close (OWNZ) or die "Can't close owners.dat: $!\n";

  open (OBJEX,">$win321$datadir/objects.dat") or die "Can't save data: $!\n";
  print OBJEX @objects;
  #, "\n";
  close (OBJEX) or die "Can't close objects.dat: $!\n";

  open (FACTX,">$win321$datadir/facts.dat") or die "Can't save data: $!\n";
  print FACTX @facts;
  #, "\n";
  close (FACTX) or die "Can't close facts.dat: $!\n";

  open (SPLITX,">$win321$datadir/splitters.dat") or die "Can't save data: $!\n";
  print SPLITX @splitters;
  #, "\n";
  close (SPLITX) or die "Can't close splitters.dat: $!\n";

  open (SPLITX2,">$win321$datadir/denies.dat") or die "Can't save data: $!\n";
  print SPLITX2 @deny;
  #, "\n";
  close (SPLITX2) or die "Can't close denies.dat: $!\n";

  open (DBMHACK,">$win321$datadir/servers.dat") or die "Can't savE DBM: $!\n";
  foreach $key (keys %servers) {
    print DBMHACK "$key\001$servers{$key}\n";
  }
  close (DBMHACK);

  open (DBMHACK,">$win321$datadir/seen.dat") or die "Can't savE DBM: $!\n";
  foreach $key (keys %seen) {
    print DBMHACK "$key\001$seen{$key}\n";
  }
  close (DBMHACK);

  open (DBMHACK,">$win321$datadir/ignore.dat") or die "Can't savE DBM: $!\n";
  foreach $key (keys %ignore) {
    print DBMHACK "$key\001$ignore{$key}\n";
  }
  close (DBMHACK);

  open (DBMHACK,">$win321$datadir/hosts.dat") or die "Can't savE DBM: $!\n";
  foreach $key (keys %hosts) {
    print DBMHACK "$key\001$hosts{$key}\n";
  }
  close (DBMHACK);

  open (DBMHACK,">$win321$datadir/profiles.dat") or die "Can't savE DBM: $!\n";
  foreach $key (keys %profiles) {
    print DBMHACK "$key\001$profiles{$key}\n";
  }
  close (DBMHACK);

  open (DBMHACK,">$win321$datadir/access.dat") or die "Can't savE DBM: $!\n";
  foreach $key (keys %access) {
    print DBMHACK "$key\001$access{$key}\n";
  }
  close (DBMHACK);

}

############################
# RETURN FACTOID ABOUT @_
############################

sub GetFactoid {

my ($facttext) = @_;

@factoidmsg = ();
$i = 0;
$fullfactoid = "";

for ($i = 0; $i < (($#objects)+1); $i++) {

  if (lc($objects[$i]) eq lc($facttext)) {
    $thatfact = $i;
    $fullfactoid = $objects[$i] . $splitters[$i] . $facts[$i];

    $fullfactoid =~ s/(\$nick|\$who)/$nickname/gi;

    #special case <REPLY> forces reply of <reply> this text
    if (index(lc($fullfactoid),"<reply>") != -1) {
      $fullfactoid = substr($fullfactoid,index(lc($fullfactoid),"<reply>")+7);

      $fullfactoid =~ s/^\s+//;
      $fullfactoid =~ s/\s+$//;
   
      $factoidmsg[$#factoidmsg+1] = $fullfactoid;
      next;
    }

    #special case /ME style thingy
    if (index(lc($fullfactoid),"<action>") != -1) {
      $fullfactoid = substr($fullfactoid,index(lc($fullfactoid),"<action>")+8);

      $fullfactoid =~ s/^\s+//;
      $fullfactoid =~ s/\s+$//;
   
      $factoidmsg[$#factoidmsg+1] = "\001ACTION $fullfactoid\001";
      next;
    }

    $factoidmsg[$#factoidmsg+1] = $fullfactoid;

  }
}

}

#save stuff

sub Cleanup {
  &SaveData;
  $mytimes = $allstartlifetime + time()-$startlifetime;
  open (TIMES,">$scriptname.time");
  print TIMES $mytimes;
  close (TIMES);
  close (BITCHLOG);
  close (CHATLOG);
  #dbmclose (%access);
  #dbmclose (%servers);
  #dbmclose (%ignore);
  #dbmclose (%seen);
  #dbmclose (%profiles);
  #dbmclose (%hosts);
  close (SOCK);
}

#duh

sub stripspaces {
  my ($text) = @_;
  $text =~ s/^\s+//;
  $text =~ s/\s+$//;
  return $text;
}

#blah hack test

sub validateurl {

  my ($url) = @_;

  my ($remote,$port,$proto,$paddr,$headers,$nl,$crlf,$stuff,@status);

  $remote = substr($url,index($url,"//")+2);

  if (index($remote,"/") > 0) {
    $remote = substr($remote,0,index($remote,"/"));
  }

  $url =~ s/http:\/\///ig;
  $url =~ s/$remote//ig;

  if ($url eq '') {
    $url = '/';
  }

  snd("PRIVMSG R1CH :$remote");

  $port = "80";

  $iaddr = inet_aton($remote) or return "$remote: Domain is not resolvable.";
  $paddr = sockaddr_in($port,$iaddr);

  $proto = getprotobyname('tcp');

  socket (SOCKCHECK,PF_INET,SOCK_STREAM,$proto) or die "socket: $!";

  connect (SOCKCHECK, $paddr) or die "connect: $!";

  $nl = chr(10);
  $crlf = chr(13).chr(10);

  $headers .= "User-Agent: BitchBOT Validator$crlf";
  $headers .= "Host: ${remote}:${port}$crlf";
  $headers .= "Connection: Close$crlf";

  snd("PRIVMSG R1CH :$url");
  send (SOCKCHECK,"HEAD $url HTTP/1.1\013\010$headers" . $nl . $nl,0);

  while ($line = <SOCKCHECK>) {
    chomp($line);
    $status[$#status+1] = $line;
  }

  close (SOCKCHECK);
  return @status;

}

sub updatestats {
  my $failed = 0;

  $stats_pid = open (STATUS, "perl genstats.pl $scriptname 2>&1 |") or $failed = 1;

  if ($failed) {
    sndtxt ("Error: Can't fork to run stats: $!");
    return;
  }

  close (CHATLOG);

  $chanstats_running = 1;

  sndtxt ("Stats bitchlet(tm) started. Waiting for response...");

  $chanstats_begin = time();

  if (!$noalarm) {
    alarm (1);
  }
}

####################
# SORT NUMERICALLY #
####################
sub numeric {
  if ($a > $b) {
    return -1;
  } elsif ($a == $b) {
    return 0;
  } elsif ($a < $b) {
    return 1;
  }
}

#####################
# ROUND NUM (hacky) #
#####################
sub round {
  my ($num) = $_[0];
  my ($dec) = $_[1];

  if (length($num) <= $dec) {
    return $num;
  } else {
    $num = substr($num,0,$dec);
    #print "$num\n sub";
    if (substr($num,-1) eq '.') {
      $num = substr($num,0,(length($num)-1));
    }
    return $num;
  }

}

#################
# QUIT WITH ERR #
#################
sub burn {
  snd ("QUIT :@_");
  sleep 1;
  die (@_);
}

#############################
# CONVERT WILDCARD TO REGEX #
#############################
sub regexify {
  my ($param) = @_;
  undef $regexed;
  @regex = split(//,$param);
  foreach $char (@regex) {
    chomp ($char);
    $newchar = $char;
    if ($char eq '.') { $newchar = '\.';}
    if ($char eq '*') { $newchar = '.*';}
    if ($char eq '@') { $newchar = '\@';}
    if ($char eq '?') { $newchar = '.?';}    
    $regexed .= $newchar;
  }
  return $regexed;
}

#############################
# AND BACK AGAIN (horrible) #
#############################
sub deregexify {
  my ($param) = @_;
  undef $regexed;
  $regex = $param;
  $regex =~ s/\.\?/\?/g;
  $regex =~ s/\\\./\./g;
  $regex =~ s/\.\*/\*/g;
  $regex =~ s/\\\@/\@/g;
  return $regex;
}

#####################
# CYBORG BLAH STUFF #
#####################
sub cyborgify {
  my ($cyber) = @_;

  my ($remote,$port,$proto,$paddr,$headers,$nl,$crlf,$stuff,@status);

  $remote = "208.37.137.201";
  $url = "/cgi/toy-cyborger.cgi?acronym=$cyber";

  $port = "80";

  $iaddr = inet_aton($remote) or return "$remote: Domain is not resolvable.";
  $paddr = sockaddr_in($port,$iaddr);

  $proto = getprotobyname('tcp');

  socket (SOCKCHECK,PF_INET,SOCK_STREAM,$proto) or die "socket: $!";

  connect (SOCKCHECK, $paddr) or return "connect: $!";

  $nl = chr(10);
  $crlf = chr(13).chr(10);

  undef $headers;
  $headers .= "User-Agent: BitchBOT IRC Web Client$crlf";
  $headers .= "Host: ${remote}:${port}$crlf";
  $headers .= "Connection: Close$crlf";


  send (SOCKCHECK,"GET $url HTTP/1.1\013\010$headers" . $nl . $nl,0);

  while ($line = <SOCKCHECK>) {
    if (index(lc($line),lc("<P CLASS=\"head3\">")) != -1) {
      $func = substr($line,25);
      $func = substr($func,0,index(lc($func),lc("</CENTER>")));
      last;
    }
  }

  close (SOCKCHECK);
  return $func;
}


sub techify {
  my ($cyber) = @_;

  my ($remote,$port,$proto,$paddr,$headers,$nl,$crlf,$stuff,@status);

  $remote = "208.37.137.201";
  $url = "/cgi/toy-acronymer.cgi?acronym=$cyber";

  $port = "80";

  $iaddr = inet_aton($remote) or return "$remote: Domain is not resolvable.";
  $paddr = sockaddr_in($port,$iaddr);

  $proto = getprotobyname('tcp');

  socket (SOCKCHECK,PF_INET,SOCK_STREAM,$proto) or die "socket: $!";

  connect (SOCKCHECK, $paddr) or return "connect: $!";

  $nl = chr(10);
  $crlf = chr(13).chr(10);

  undef $headers;
  $nextm = 0;
  $headers .= "User-Agent: BitchBOT IRC Web Client$crlf";
  $headers .= "Host: ${remote}:${port}$crlf";
  $headers .= "Connection: Close$crlf";


  send (SOCKCHECK,"GET $url HTTP/1.1\013\010$headers" . $nl . $nl,0);

  while ($line = <SOCKCHECK>) {
    chomp ($line);

    if ($nextm == 1) {
      $func = $line;
      last;
    }

    if (uc($line) eq '<P><BIG><B>') {
      $nextm = 1;
    }
  }

  close (SOCKCHECK);
  return $func;
}

########################################
# RESTART BOT (same as exit really :P) #
########################################
sub restart {
  &Cleanup;
  exit;
}

#######################################
# NOT-SO-AUTO UPDATE CHECK            #
#######################################
sub checkupdate {
  my ($remote,$port,$proto,$paddr,$headers,$nl,$crlf,$stuff,@status);

  print "\nChecking for updates...   ";

  $remote = "www.r1ch.net";
  $url = "/projects/bitchbot/version.txt";

  #ripped from URI module, since it isn't installed by default on some systems...
  for (0..255) { $escapes{chr($_)} = sprintf("%%%02X", $_); }
  $url =~ s/([^;\/?:@&=+\$,A-Za-z0-9\-_.!~*'()])/$escapes{$1}/g;

  $port = "80";
  $iaddr = inet_aton($remote) or return 2;
  $paddr = sockaddr_in($port,$iaddr);

  $proto = getprotobyname('tcp');

  socket (SOCKCHECK,PF_INET,SOCK_STREAM,$proto) or return 2;

  connect (SOCKCHECK, $paddr) or return 2;

  $lf = chr(10);

  undef $headers;
  $headers .= "User-Agent: BitchBOT IRC Web Client$lf";
  $headers .= "Host: ${remote}:${port}$lf";
  $headers .= "Connection: Close$lf";


  send (SOCKCHECK,"GET $url HTTP/1.1$lf$headers" . $lf . $lf,0);

  while ($line = <SOCKCHECK>) {
    chomp ($line);
    ($s,$v) = split(/=/,$line);
    $v =~ s/[\n|\r]//g;
    if ($s eq 'version') {
      if ($v ne $bot_version_number) {
        print "$mok\n\nNOTICE: A bitchbot update is available.\nCurrent version: $bot_version_number\nNewest version : $v\n\nTo update, please download the latest source at\nhttp://www.r1ch.net/projects/bitchbot/download/\n\n";
        $response = 1;
      } else {
        print "$mok\nYou have the latest version.\n\n";
        $response = 1;
      }
    }
  }

  if (!($response)) {
    print "$mfail (Unknown response from $remote!)\n\n";
  }

  close (SOCKCHECK);
}

#my god what a mess.
#someone please fix this.

sub checkchanstats {
  my $output;
  my $failed;
  my $code;
  my $message;
  my $ftp;
  my $rin;
  my $win;
  my $ein;
  my $wout;
  my $rout;
  my $eout;
  my $nfound;

  #typically if it doesn't have ALARM it doesn't have working waitpid (win32)

  if (!($noalarm)) {
    $a = waitpid($stats_pid, &WNOHANG);
    if ($a == -1) {
      $output = <STATUS>;
    }
  } else {
    #little delay, lets try and avoid timing out if we can :/
    if (time() - $chanstats_begin > 30) {
      $output = <STATUS>;
    }
  }

  if (!(defined($output))) {
    return;
  }

  ($code, @message) = split (/ /, $output);
  $message = join (" ", @message);
  if ($code eq 'OK' || $code eq 'ERROR') {
    close (STATUS);
    kill (TERM, $stats_pid);
    $chanstats_running = 0;
    if (!($noalarm)) {
      alarm (30);
    }
    open (CHATLOG, ">>$logfile") or sndtxt ("WARNING: Can't continue logging to logfile: $!\n");
    if ($code eq 'OK') {
      if ($uploadhost ne '') {
        sndtxt("Uploading stats to remote server...");

        $failed = 0;

        if (eval "use Net::FTP", $@) {
          $failed = 1;
          sndtxt ("ERROR: Unable to initialize Net::FTP! It probably isn't installed. Consult your perl admin.");
        } else {
          $ftp = Net::FTP->new($uploadhost, Debug => 0, Passive => $uploadpasv);
          if (!(defined($ftp))) {
            sndtxt ("Unable to establish connection: $@");
            $failed = 1;
          } else {
            if (!($ftp->login ($uploaduser, $uploadpass))) {
              sndtxt ("Login to remote host failed.");
              $failed = 1;
            } else {
              if ($uploadpath ne '') {
                $ftp->cwd ($uploadpath);
              }
              $ftp->type ('A');
              $ftp->put ($outfile, $uploadname);
              $ftp->quit();
            }
          }
        }
      }

      if (!(defined($failed))) {
        sndtxt ("Chanstats complete! ${botname}'s $channel chanstats: $outurl");
      }
    } else {
      sndtxt ("Channel stats reported an error: $message");
    }
  }
}

sub portalMessage {
snd("Portal messages...");
}


sub logline {
  my $text;
  my $action;
  my $nickname;

  $action = $_[0];
  $nickname = $_[1];
  $text = $_[2];

  if ($verbose eq 'medium' && $action <= 3) {
    print "<$nickname> $text\n";
  }

  if ($action == 1) {
    $text =~ s/\001ACTION //gi;
    $text = "* $nickname $text";
  }

  $nickname =~ s/</&lt;/g;
  $nickname =~ s/>/&gt;/g;

  $text =~ s/</&lt;/g;
  $text =~ s/>/&gt;/g;
  $text =~ s/[\000-\037|\177|\225]//g;

  if ($action <= 4) {
    foreach $word (@swearwords) {
      if (index(lc($text),$word) != -1) {
        $action |= 8;
      }
    }
  }

  print CHATLOG time() . "\001$action\001$nickname\001$text\n";
}


sub mytest {

    my $user = shift;
    
    local @temp = ();
    local $query = "";
    local $fullhost = "";
    local $accesslevels = "";
    local $ident = "";
    
    
# Get the address
    $query = $user;
    
    if ($query eq "") {
	sndtxt ("You forgot to specify a user, moron.");
	next;
    }
    
# Split to IP/hostmask ONLY (or do nick lookup)
    
    if (index($query," ") != -1) {
	$accesslevels = uc(substr($query,index($query," ")+1));
	$query = substr($query,0,index($query," "));
    }
    
    $usertoadd = $query;
    
    #if (index($query,"\@") == -1) {
	#$query = substr($query,index($query," "));
	
	#if ($hosts{lc($query)} eq "") {
	#    sndtxt ("Could not look up address for ${query}.");
	    
	#    print("Käyttäjä ei ole edes käynyt kanavalla!\n\r");
	 #   next;
	#}
	
	#$query = $hosts{lc($query)};
	#print("query = $query");
	
    #}else{

	my $res = snd("WHOIS ".$user);

#	my $test = @res[3];
	my $register = snd("/NICK ".$user);
	snd("/NICK ".$botname);
	print("user = $res\n\r");
	print("register = $register\n\r");
    if ($query eq "") {
	print("");
    }
    #}
    next;
}
