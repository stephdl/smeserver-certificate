#!/usr/bin/perl -w 

package esmith::FormMagick::Panel::certificate;

use strict;
use warnings;
use esmith::ConfigDB;
use esmith::FormMagick;
use esmith::cgi;


our @ISA = qw(esmith::FormMagick Exporter);

our @EXPORT = qw(
    write_pem
    read_pem
);

our $config_db = esmith::ConfigDB->open || die "Couldn't open ConfigDB\n";


our $ssl_crt = '/home/e-smith/ssl.crt';
our $ssl_key = '/home/e-smith/ssl.key';

sub new {
    shift;
    my $fm = esmith::FormMagick->new();
    $fm->{calling_package} = (caller)[0];
    bless $fm;
    return $fm;
}



sub read_pem{
    my ($fm,$pem) = @_;
    my $q = $fm->{cgi};
    my $dir = '';
    my $ret;
    my $domain = $config_db->get_value('DomainName');

    if ($pem eq 'domain.crt') { 
        $dir = $ssl_crt;
        $pem = "$domain.crt";
    }
    if ($pem eq 'domain.key') {
        $dir = $ssl_key;
        $pem = "$domain.key";
    }
    if ($pem eq 'certificate.chainfile') {
        $dir = $ssl_crt;
        $pem = "chain.pem";
    }
    if (! open (PEM, "<$dir/$pem")){
        $fm->error('ERROR_OPEN_PEM','FIRST');
        # Tell the user something bad has happened
        return;
    }
    while (<PEM>){
        $ret .= $_;
    }
    close PEM;

    return $ret;
}

sub write_pem{
    my ($fm) = @_;
    my $q = $fm->{cgi};
    my $domain = $config_db->get_value('DomainName')|| die "Couldn't open ConfigDB\n";

    my $domain_crt  = $q->param('ca_crt');
    my $domain_key = $q->param('ca_key');
    my $chain_crt = $q->param('chain_crt_file');


if (($domain_crt eq '') && ($domain_key eq ''))
    {
        my $ssl_crt     = '/home/e-smith/ssl.crt';
        my $ssl_key     = '/home/e-smith/ssl.key';

        my $domain      = $config_db->get_value('DomainName') || die "Couldn't open ConfigDB\n";
        my $server      = $config_db->get_value('SystemName') || die "Couldn't open ConfigDB\n";

        my $crt_path    = "$ssl_crt" . '/' . $domain . '.crt' || '';
        my $key_path    = "$ssl_key" . '/' . $domain . '.key' || '';
        my $chain_path  = "$ssl_crt" . '/chain.pem' || '';
        
        #we return to the default certificate of sme and we remove the db entry CertificateChainFile
        system("/sbin/e-smith/db configuration delprop modSSL crt");
        system("/sbin/e-smith/db configuration delprop modSSL key");
        system("/sbin/e-smith/db configuration delprop modSSL CertificateChainFile");
 
        system("/sbin/e-smith/expand-template /home/e-smith/ssl.pem/pem");
        system("/sbin/e-smith/expand-template /etc/httpd/conf/httpd.conf");
        system("/sbin/service httpd-e-smith restart");
        system("/sbin/e-smith/signal-event ldap-update");
        system("/sbin/e-smith/signal-event email-update");

               if (( -f $crt_path) && ( -f $key_path )) { 
                system("/bin/rm $ssl_crt/$domain.crt");
                system("/bin/rm $ssl_key/$domain.key");
                system("/bin/rm $ssl_crt/chain.pem");
               }
    }

elsif (($domain_crt ne '') && ($domain_key ne ''))
    {
        if (! open (CRT, ">$ssl_crt/$domain.crt")){
            $fm->error('ERROR_OPEN_CRT','FIRST');
            # Tell the user something bad has happened
            return;
            }
        print CRT $domain_crt;
        close CRT;

        if (! open (KEY, ">$ssl_key/$domain.key")){
            $fm->error('ERROR_OPEN_KEY','FIRST');
            # Tell the user something bad has happened
            return;
        }
        print KEY $domain_key;
        close KEY;

        if (! open (CHAIN, ">$ssl_crt/chain.pem")){
            $fm->error('ERROR_OPEN_KEY','FIRST');
            # Tell the user something bad has happened
            return;
        }
        print CHAIN $chain_crt;
        close CHAIN;
        
        # Restrict permissions on sensitive data
        esmith::util::chownFile("root", "root","$ssl_key/$domain.key");
        esmith::util::chownFile("root", "root","$ssl_crt/$domain.crt");
        chmod 0600, "$ssl_key/$domain.key";
        chmod 0600, "$ssl_crt/$domain.crt";
        
        #we load new certificates in db
        system("/sbin/e-smith/db configuration setprop modSSL crt $ssl_crt/$domain.crt");
        system("/sbin/e-smith/db configuration setprop modSSL key $ssl_key/$domain.key");
        
        #we look if the certificate chain file is not equal to nothing, if not we load in db
        if  ($chain_crt ne '') {
        system("/sbin/e-smith/db configuration setprop modSSL CertificateChainFile /home/e-smith/ssl.crt/chain.pem");
        }
        
        system("/sbin/e-smith/expand-template /home/e-smith/ssl.pem/pem");
        system("/sbin/e-smith/expand-template /etc/httpd/conf/httpd.conf");
        #system("/sbin/service httpd-e-smith restart >/dev/null 2>&1");
            system("/sbin/service httpd-e-smith restart");

        system("/sbin/e-smith/signal-event ldap-update");
        system("/sbin/e-smith/signal-event email-update");
        #$fm->success('SUCCESS','FIRST');
        return undef;
    }
}
1;
