#!/usr/bin/perl -w

# https://docops.ca.com/ca-unified-infrastructure-management-probes/en/alphabetical-probe-articles/vplex-emc-vplex-monitoring/vplex-metrics
# https://thomas-asnar.github.io/wp-content/uploads/docu52647_VPLEX-Element-Manager-API-Guide.pdf
package Vplex;
#use strict;
#use warnings FATAL => 'all';
use warnings;
use utf8;


#use Net::SSH::Perl;
use Net::SSH::Expect;
use Data::Dumper;
use LWP::UserAgent;
use Digest::MD5 qw(md5_hex);
use XML::Simple;
use JSON;


#use NET::SSL;

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
#$ENV{HTTPS_VERSION} = 3;

my $zabbixSender = "/usr/bin/zabbix_sender";
my $zabbixConfd = "/etc/zabbix/zabbix_agentd.conf";
my $sendFile = "/var/tmp/zabbixSenderVplex";
my $zabbixSendCommand = "$zabbixSender -c $zabbixConfd -i ";

#my $USERNAME = "zsm";
#my $PASSWORD = "Mzoning2";

my $debug = 1;

if ($debug == 1) {
    $zabbixSendCommand = "$zabbixSender -vv -c $zabbixConfd -i ";
}

sub getZabbixValues {
    my $hostname = shift;
    my $colHash = shift;
    my $type = shift;
    my $outputString = "";

    foreach my $key (keys %{$colHash}) {
        foreach my $itemKey (keys %{$colHash->{$key}}) {
            $outputString .= "\"$hostname\" \"vplex.stat.${type}.${itemKey}[$key]\" \"$colHash->{$key}->{$itemKey}\"\n";
        }
    }
    if ($debug == 1) {
        print $outputString;
    }

    #print $outputString;

    $outputString;
}

sub getHPEventsZabbixValues {
    my $hostname = shift;
    my $colHash = shift;
    my $type = shift;
    my $outputString = "";

    foreach my $key (keys %{$colHash}) {
        #foreach my $itemKey (keys %{$colHash->{$key}}) {
        $outputString .= "\"$hostname\" \"hp.p2000.stats[$type,controller_".lc( $colHash->{$key}->{key} ).",event]\" \"$colHash->{$key}->{event}\"\n";
        #}
    }
    if ($debug == 1) {
        print $outputString;
    }

    #print $outputString;

    $outputString;
}

# $ipAddr = $ARGV[0];
# $ipPort = $ARGV[1];
# $username = $ARGV[2];
# $password = $ARGV[3];
# $command = $ARGV[4];
# $object = $ARGV[5];
# $zabbixhost = $ARGV[6];

my $hostname = $ARGV[0] or die( "Usage: vplex.pl <HOSTNAME> [lld|stats|event]" );
my $ipPort = $ARGV[1];
my $username = $ARGV[2];
my $password = $ARGV[3];
my $function = $ARGV[4] || 'lld';
my $object = $ARGV[5];
#my $object = $ARGV[5];
my $zabbixhost = $ARGV[6];
#my $eventid = $ARGV[7];
my $perfType = $ARGV[7];
my $perfInstance = $ARGV[8];
my $perfParentInstance = $ARGV[9];

#print "123123123" . $username;

die( "Usage: vplex.pl <HOSTNAME> [lld|stats|event]" ) unless ($function =~ /^(lld|stats|event|perf)$/);

my $ua = LWP::UserAgent->new;
my $url;
my $http_v = "";
#$ua->ssl_opts( verify_hostnames => 0 );
if ($ipPort eq "80") {
    $http_v = "http";
    $url = "http://$hostname/vplex/";
}
else {
    $ua->ssl_opts( verify_hostnames => 0 );
    $http_v = "https";
    $url = "https://$hostname/vplex/";
}

if ($function eq 'lld') {
    my $zbxArray = [ ];

    if ($object eq 'events') {
        if ($debug == 1) {
            print 'events\n';
        }
        getLastEventsId( $ua, $sessionKey, $http_v, "$hostname/api/show/events/A/last/1",
            "event", "event-id", "controller", $zbxArray );

        getLastEventsId( $ua, $sessionKey, $http_v, "$hostname/api/show/events/B/last/1",
            "event", "event-id", "controller", $zbxArray );
    }

    if ($object eq 'clusters') {
        if ($debug == 1) {
            print 'clusters\n';
        }
        getHPP200Objects ( $ua, $http_v, "$hostname:$ipPort/vplex/clusters",
            "clusters", "durable-id", "controller-id", "Кластеры", "", "", 0, $zbxArray );
    }

    if ($object eq 'storage-arrays') {
        if ($debug == 1) {
            print 'storage-arrays\n';
        }
        getHPP200Objects ( $ua, $http_v, "$hostname:$ipPort/vplex/clusters/*/storage-elements/storage-arrays",
            "storage-arrays", "durable-id", "controller-id", "Массивы", "Кластеры", "2", 0, $zbxArray );
    }

    if ($object eq 'devices') {
        if ($debug == 1) {
            print 'devices\n';
        }
        getHPP200Objects ( $ua, $http_v, "$hostname:$ipPort/vplex/clusters/*/devices",
            "devices", "durable-id", "controller-id", "Backend-устройства", "Кластеры", "2", 0, $zbxArray );
    }

    if ($object eq 'virtual-volumes') {
        if ($debug == 1) {
            print 'virtual-volumes\n';
        }
        getHPP200Objects ( $ua, $http_v, "$hostname:$ipPort/vplex/clusters/*/virtual-volumes",
            "virtual-volumes", "durable-id", "controller-id", "Виртуальные тома", "Кластеры", "2", 0, $zbxArray );
    }

    if ($object eq 'engines') {
        if ($debug == 1) {
            print 'engines\n';
        }
        getHPP200Objects ( $ua, $http_v, "$hostname:$ipPort/vplex/engines",
            "engines", "durable-id", "controller-id", "Шасси", "", "", 0, $zbxArray );
    }

    if ($object eq 'fans') {
        if ($debug == 1) {
            print 'fans\n';
        }
        getHPP200Objects ( $ua, $http_v, "$hostname:$ipPort/vplex/engines/*/fans",
            "fans", "durable-id", "controller-id", "Вентиляторы", "Шасси", "2", 0, $zbxArray );
    }

    if ($object eq 'modules') {
        if ($debug == 1) {
            print 'modules\n';
        }
        getHPP200Objects ( $ua, $http_v, "$hostname:$ipPort/vplex/engines/*/mgmt-modules",
            "modules", "durable-id", "controller-id", "Модули", "Шасси", "2", 0, $zbxArray );
    }

    if ($object eq 'power-supplies') {
        if ($debug == 1) {
            print 'power-supplies\n';
        }
        getHPP200Objects ( $ua, $http_v, "$hostname:$ipPort/vplex/engines/*/power-supplies",
            "power-supplies", "durable-id", "controller-id", "Блоки питания сетевой", "Шасси", "2", 0, $zbxArray );
    }

    if ($object eq 'stand-by-power-supplies') {
        if ($debug == 1) {
            print 'stand-by-power-supplies\n';
        }
        getHPP200Objects ( $ua, $http_v, "$hostname:$ipPort/vplex/engines/*/stand-by-power-supplies",
            "stand-by-power-supplies", "durable-id", "controller-id", "Батарейный блок", "Шасси", "2", 0,
            $zbxArray );
    }

    if ($object eq 'directors') {
        if ($debug == 1) {
            print 'directors\n';
        }
        getHPP200Objects ( $ua, $http_v, "$hostname:$ipPort/vplex/engines/*/directors",
            "directors", "durable-id", "controller-id", "Директоры", "Шасси", "2", 0, $zbxArray );
    }

    if ($object eq 'io-modules') {
        if ($debug == 1) {
            print 'io-modules\n';
        }
        getHPP200Objects ( $ua, $http_v, "$hostname:$ipPort/vplex/engines/*/directors/*/hardware/io-modules",
            "io-modules", "durable-id", "controller-id", "Платы ввода-вывода", "Директоры", "4", 0, $zbxArray );
    }

    if ($object eq 'ports') {
        if ($debug == 1) {
            print 'ports\n';
        }
        getHPP200Objects ( $ua, $http_v, "$hostname:$ipPort/vplex/engines/*/directors/*/hardware/ports",
            "ports", "durable-id", "controller-id", "Порты", "Директоры", "4", 0, $zbxArray );
    }

    if ($object eq 'distributed-devices') {
        if ($debug == 1) {
            print 'distributed-devices\n';
        }
        getHPP200Objects ( $ua, $http_v, "$hostname:$ipPort/vplex/distributed-storage/distributed-devices",
            "distributed-devices", "durable-id", "controller-id", "Распределенные Backend-устройства", "", "", 0,
            $zbxArray );
    }

    if ($object eq 'cluster-witness') {
        if ($debug == 1) {
            print 'cluster-witness\n';
        }
        getHPP200Objects ( $ua, $http_v, "$hostname:$ipPort/vplex/cluster-witness/components",
            "cluster-witness", "durable-id", "controller-id", "Компоненты Witness", "", "", 0, $zbxArray );
    }

    print to_json( { data => $zbxArray }, { utf8 => 1, pretty => 1 } )."\n";


    # logOut($ua, $sessionKey, $hostname);
}
elsif ($function eq 'event') {
    my $ctrls = { };
    my $vdisks = { };
    my $volumes = { };
    my $outputString = "";

    #if ($object eq 'event'){
    if ($debug == 1) {
        print 'event\n';
    }

    if ($eventid =~ /^([aA-zZ]+)(\d+)$/) {
        my $id = $2;
        $id++;
        $eventid = $1.$id;
    }

    getLastEvents ( $ua, $sessionKey, $http_v, "$hostname/api/show/events/".$object."/from-event/".$eventid,
        "event", $ctrls );

    $outputString .= getHPEventsZabbixValues( $zabbixhost, $ctrls, "events" );

    logOut( $ua, $sessionKey, $hostname );

    #$outputString .= getZabbixValues($zabbixhost, $ctrls, "Controller");
    #$outputString .= getZabbixValues($zabbixhost, $vdisks, "Vdisk");
    #$outputString .= getZabbixValues($zabbixhost, $volumes, "Volume");

    $sendFile .= "_${hostname}_$$";
    die "Could not open file $sendFile!" unless (open( FH, ">", $sendFile ));
    print FH $outputString;
    die "Could not close file $sendFile!" unless (close( FH ));

    $zabbixSendCommand .= $sendFile;

    my $result = qx($zabbixSendCommand);
    if ($debug == 1) {
        print $result;
    }

    if ($result =~ /Failed 0/) {
        $res = 1;
    } else {
        $res = 0;
    }

    die "Can not remove file $sendFile!" unless (unlink ( $sendFile ));
    print "$res\n";
    exit ( $res - 1 );
    #}

}
elsif ($function eq 'stats') {
    my $ctrls = { };
    my $vdisks = { };
    my $volumes = { };
    my $outputString = "";

    if ($object eq 'clusters') {
        if ($debug == 1) {
            print 'clusters\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname:$ipPort/vplex/clusters/*",
            "clusters", "durable-id", "operational-status|health-state|connected", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "cluster" );
    }

    if ($object eq 'storage-arrays') {
        if ($debug == 1) {
            print 'storage-arrays\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v,
            "$hostname:$ipPort/vplex/clusters/*/storage-elements/storage-arrays/*",
            "storage-arrays", "durable-id", "connectivity-status", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "storage-array" );
    }

    if ($object eq 'devices') {
        if ($debug == 1) {
            print 'devices\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname:$ipPort/vplex/clusters/*/devices/*",
            "devices", "durable-id", "operational-status|health-state|service-status", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "device" );
    }

    if ($object eq 'virtual-volumes') {
        if ($debug == 1) {
            print 'virtual-volumes\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname:$ipPort/vplex/clusters/*/virtual-volumes/*",
            "virtual-volumes", "durable-id", "operational-status|health-state|service-status", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "virtual-volume" );
    }

    if ($object eq 'engines') {
        if ($debug == 1) {
            print 'engines\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname:$ipPort/vplex/engines/*",
            "engines", "durable-id", "operational-status|health-state", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "engine" );
    }

    if ($object eq 'fans') {
        if ($debug == 1) {
            print 'fans\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname:$ipPort/vplex/engines/*/fans/*",
            "fans", "durable-id", "operational-status|speed-threshold-exceeded", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "fan" );
    }

    if ($object eq 'mgmt-modules') {
        if ($debug == 1) {
            print 'mgmt-modules\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname:$ipPort/vplex/engines/*/mgmt-modules/*",
            "mgmt-modules", "durable-id", "operational-status", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "mgmt-module" );
    }

    if ($object eq 'power-supplies') {
        if ($debug == 1) {
            print 'power-supplies\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname:$ipPort/vplex/engines/*/power-supplies/*",
            "power-supplies", "durable-id", "operational-status|temperature-threshold-exceeded", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "power-supply" );
    }

    if ($object eq 'stand-by-power-supplies') {
        if ($debug == 1) {
            print 'stand-by-power-supplies\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname:$ipPort/vplex/engines/*/stand-by-power-supplies/*",
            "stand-by-power-supplies", "durable-id", "operational-status|battery-status", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "stand-by-power-supply" );
    }

    if ($object eq 'directors') {
        if ($debug == 1) {
            print 'directors\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname:$ipPort/vplex/engines/*/directors/*",
            "directors", "durable-id",
            "health-state|operational-status|communication-status|vplex-splitter-status|temperature-threshold-exceeded|voltage-threshold-exceeded"
            ,
            $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "director" );
    }

    if ($object eq 'io-modules') {
        if ($debug == 1) {
            print 'io-modules\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v,
            "$hostname:$ipPort/vplex/engines/*/directors/*/hardware/io-modules/*",
            "io-modules", "durable-id", "is-present|operational-status",
            $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "io-module" );
    }

    if ($object eq 'ports') {
        if ($debug == 1) {
            print 'ports\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname:$ipPort/vplex/engines/*/directors/*/hardware/ports/*",
            "ports", "durable-id", "enabled|operational-status|port-status",
            $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "port" );
    }

    if ($object eq 'distributed-devices') {
        if ($debug == 1) {
            print 'distributed-devices\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname:$ipPort/vplex/distributed-storage/distributed-devices/*",
            "distributed-devices", "durable-id", "health-state|operational-status|service-status",
            $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "distributed-device" );
    }

    if ($object eq 'cluster-witness') {
        if ($debug == 1) {
            print 'cluster-witness\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname:$ipPort/vplex/cluster-witness/components/*",
            "cluster-witness", "durable-id", "management-connectivity|operational-state|admin-state",
            $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "cluster-witness" );
    }

    if ($object eq 'perf') {
        if ($debug == 1) {
            print 'perf\n';
        }
        getHPPerf( $ctrls, $perfType, $perfInstance, $perfParentInstance );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "perf" );
    }



    # getHPP200Stats ( $ua, $sessionKey, "https://$hostname/api/show/controller-statistics",
    #              "controller-statistics", "durable-id", $ctrls);
    # getHPP200Stats ( $ua, $sessionKey, "https://$hostname/api/show/vdisk-statistics",
    #              "vdisk-statistics", "name", $vdisks);
    # getHPP200Stats ( $ua, $sessionKey, "https://$hostname/api/show/volume-statistics",
    #              "volume-statistics", "volume-name", $volumes);
    #logOut($ua, $sessionKey, $hostname);

    #$outputString .= getZabbixValues($zabbixhost, $ctrls, "Controller");
    #$outputString .= getZabbixValues($zabbixhost, $vdisks, "Vdisk");
    #$outputString .= getZabbixValues($zabbixhost, $volumes, "Volume");

    $sendFile .= "_${hostname}_$$";
    die "Could not open file $sendFile!" unless (open( FH, ">", $sendFile ));
    print FH $outputString;
    die "Could not close file $sendFile!" unless (close( FH ));

    $zabbixSendCommand .= $sendFile;

    my $result = qx($zabbixSendCommand);
    if ($debug == 1) {
        print $result;
    }

    if ($result =~ /Failed 0/) {
        $res = 1;
    } else {
        $res = 0;
    }

    die "Can not remove file $sendFile!" unless (unlink ( $sendFile ));
    print "$res\n";
    exit ( $res - 1 );
}

sub getHPP200Objects {
    my $ua = shift;
    my $http_v = shift;
    my $url = shift;
    my $objectName = shift;
    my $idName = shift;
    my $Name = shift;
    #my $typeName = shift;
    my $type = shift;

    my $parenttype = shift;
    my $parentid = shift;

    my $useparentarray = shift;
    my $zbxArray = shift;

    my $idNameFull = shift; # "controller|phy-index"
    my $NameFull = shift; # "type|enclosure-id|controller|wide-port-index|phy-index"

    $url = $http_v."://".$url;

    #print $username;

    my $req = HTTP::Request->new( GET => $url );
    $req->header( 'Accept' => 'application/json;format=1;prettyprint=0' );
    $req->header( 'Username' => $username );
    $req->header( 'Password' => $password );
    my $res = $ua->request( $req );

    #my $ref = XMLin($res->content, KeyAttr => "oid");

    if ($debug == 1) {
        print Dumper( $res->content );
    }

    my $decodedresponse = JSON::PP->new->pretty->decode( $res->content );
    if ($debug == 1) {
        print Dumper( $decodedresponse );
    }
    my @contexts = @{$$decodedresponse{"response"}{"context"}};
    if ($debug == 1) {
        print Dumper( @contexts );
    }
    for my $context (@contexts)
    {
        if ($debug == 1) {
            print Dumper( $context );
        }

        my $element_parent = "";
        my $parent = "";
        #print $parentid;
        #$element_parent = $$context{"parent"};

        $element_parent = $$context{"parent"};

        if ($parentid ne "") {
            my @values = split( '/', $element_parent );
            #print $values[$parentid];

            $parent = $values[$parentid];
        }

        $element_type = $$context{"type"};

        @children = @{$$context{"children"}};
        for my $children (@children)
        {
            if ($debug == 1) {
                print Dumper( $children );
            }

            my $fullparent = "";
            if ($parent ne "") {
                $fullparent = $parent." (".$parenttype.")::";
            }
            else {
                $fullparent = $parent;
            }

            # my $childrenid = $element_parent."/".$element_type."/".$children;
            my $childrenid = $element_parent."/".$$context{"name"}."/".$children;

            # delete //
            $childrenid =~ s/[\/]+/\//g;

            $reference = { '{#VPLEX_NAME}' => $children,
                '{#VPLEX_TYPE}'            => $type,
                '{#VPLEX_FULLID}'          => lc( $childrenid ),
                '{#VPLEX_ID}'              => lc( $children ),
                '{#VPLEX_ORIGIN_TYPE}'     => $element_type,
                '{#VPLEX_PARENT}'          => $fullparent,
                '{#VPLEX_PARENTNAME}'      => $parent,
                '{#VPLEX_PARENTTYPE}'      => $parenttype };

            push @{$zbxArray}, { %{$reference} };
        }
    }

}


sub getHPP200Stats {
    my $ua = shift;
    my $sessionKey = shift;
    my $http_v = shift;
    my $url = shift;
    my $objectName = shift;
    my $idName = shift;
    my $params = shift;

    my $colHash = shift;

    my $idNameFull = shift; # "controller|phy-index"

    $url = $http_v."://".$url;

    #print $username;

    my $req = HTTP::Request->new( GET => $url );
    $req->header( 'Accept' => 'application/json;format=1;prettyprint=0' );
    $req->header( 'Username' => $username );
    $req->header( 'Password' => $password );
    my $res = $ua->request( $req );

    #my $ref = XMLin($res->content, KeyAttr => "oid");

    if ($debug == 1) {
        print Dumper( $res->content );
    }

    my $decodedresponse = JSON::PP->new->pretty->decode( $res->decoded_content() ); #$res->content
    if ($debug == 1) {
        print Dumper( $decodedresponse );
    }
    my @contexts = @{$$decodedresponse{"response"}{"context"}};
    if ($debug == 1) {
        print Dumper( @contexts );
    }

    for my $context (@contexts)
    {
        if ($debug == 1) {
            print Dumper( $context );
        }

        my $element_parent = $$context{"parent"};
        my $element_name = $$context{"name"};
        my $fullid = $element_parent."/".$element_name;
        my $hashKey = lc( $fullid );
        my $reference;
        #my %context1 = $context;
        # no warnings 'experimental';
        while(my ($key, $value) = each %$context)
        {
            #$h{uc $k} = $h{$k} * 2; # BAD IDEA!
            if ($key =~ /^($params)$/) {
                if ($debug == 1) {
                    #print Dumper($oid);
                    print "key: $key, value: $value\n";

                }

                if ($value =~ /^ARRAY/) {
                    #print $value->[0];
                    #print Dumper($value);
                    $value = $value->[0];
                }

                $reference->{lc( $key )} = $value;
            }
        }

        $colHash->{$hashKey} = { %{$reference} };

    }

    if ($debug == 1) {
        print Dumper( $colHash );
    }
}

sub getHPPerf {

    $debug = 1;

    my $colHash = shift; # 5
    my $perfType = shift; #"director";
    my $perfInstance = shift; #"director-1-1-A";
    my $perfParentInstance = shift;

    if ($debug == 1) {
        print $hostname."\n";
        print $username."\n";
        print $password."\n";
    }

    my $ssh = Net::SSH::Expect->new (
        host     => $hostname,
        password => $password,
        user     => $username,
        raw_pty  => 1
    );
    my $login_output = $ssh->login();
    if ($login_output !~ /vplex/) {
        die "Login has failed. Login output was $login_output";
    }

    my $fileName = sprintf( "%s_ovsm_%s.csv", $perfInstance, $perfType );
    my $cmd = sprintf(
        "head -n 1 /var/log/VPlex/cli/%s 2>/dev/null && tail -n 1 /var/log/VPlex/cli/%s 2>/dev/null",
        $fileName, $fileName );
    if ($debug == 1) {
        print Dumper( $cmd );
    }

    $ssh->exec( "stty raw -echo" );

    my $stdout = $ssh->exec( $cmd );
    if ($debug == 1) {
        print Dumper( $stdout );
    }
    my @values = split( '\n', $stdout );
    my $hashKey = $perfInstance;
    #    if ($perfParentInstance != null) {
    #        $hashKey = $perfParentInstance . "," . $hashKey;
    #    }
    my $reference;

    my $arrSize = @values;
    if ($arrSize > 1) {

        my $metrics = $values[0];
        my $metricsValues = $values[1];

        if ($debug == 1) {
            print Dumper( $metrics );
            print Dumper( $metricsValues );
        }

        my @metrics = split( ',', $metrics );
        my $arr2Size = @metrics;
        if ($arr2Size > 0) {
            my @metricsValues = split( ',', $metricsValues );

            for my $i (0 .. $#metrics)
            {
                $hashKey = $perfInstance;
                my @objects;
                # my $reference;
                my @metricsName = split( ' ', $metrics[$i] );
                if (@metricsName > 1) {
                    #print "*** 1: ".$metricsName[0]."\n";
                    $metrics[$i] = $metricsName[0];
                    if (@metricsName > 2) {
                        #print "*** 2: ".$metricsName[0]."\n";
                        #$reference->{"object"} = $metricsName[1];
                        $hashKey = $hashKey.",".$metricsName[1];

                        #$colHash->{$hashKey}->{lc( $metrics[$i] )} = $metricsValues[$i];  # add to hash

                        #$reference->{lc( $metrics[$i] )} = $metricsValues[$i];
                    }
                    else {
                        #$hashKey = $hashKey.",".$metricsName[1];

                        #$colHash->{$hashKey}->{lc( $metrics[$i] )} = $metricsValues[$i];  # add to hash

                    }
                }

                $colHash->{$hashKey}->{lc( $metrics[$i] )} = $metricsValues[$i];  # add to hash

                #print "*** HashKey: ".$hashKey."\n";

                #print $metrics[$i]." = ".$metricsValues[$i]."\n";
                #$reference->{lc( $metrics[$i] )} = $metricsValues[$i];

                #print Dumper( %{$reference} );
                #$colHash->{$hashKey} = { %{$reference} };

                #print Dumper( $colHash );
            }

            #$colHash->{$hashKey} = { %{$reference} };

        }
        else {
            print "File not found or has wrong format \n";
        }

    }
    else {
        print "File not found or wrong format \n";
    }

    if ($debug == 1) {
        print Dumper( $colHash );
    }
    #
    #    my($stdout, $stderr, $exit) = $ssh->cmd($cmd);
    #    if ($debug == 1) {
    #        print Dumper($stdout);
    #    }
    # closes the ssh connection
    $ssh->close();
}


