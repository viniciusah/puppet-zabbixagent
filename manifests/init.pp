# Class: zabbixagent
#
# This module manages the zabbix agent on a monitored machine.
#
# Parameters: none
#
# Actions:
#
# Requires: see Modulefile
#
# Sample Usage:
#
class zabbixagent(
  $servers = '',
  $hostname = '',
  $serversactive = '',
) {
  $servers_real = $servers ? {
    ''      => 'localhost',
    default => $servers,
  }
  $hostname_real = $hostname ? {
    ''      => $::fqdn,
    default => $hostname,
  }
  $serversactive_real = $serversactive ? {
    ''      => '127.0.0.1',
    default => $serversactive,
  }

  Package <| |> -> Ini_setting <| |>

  case $::operatingsystem {
    centos: {
      include epel

      package {'zabbix-agent' :
        ensure  => installed,
        require => Yumrepo["epel"]
      }
    }

    debian, ubuntu: {
      package {'zabbix-agent' :
        ensure  => installed,
        require => Exec['aptitude_update']
      }
    }
  }

  case $::operatingsystem {
    debian, ubuntu, centos: {
  	  file { 'zabbix_release_6' :
        path   => '/tmp/zabbix-release_2.0-1_debian_6.deb',
        ensure => 'present',
        source => 'puppet:///modules/zabbixagent/debian/zabbix-release_2.0-1_debian_6.deb'
      }      

      file { 'zabbix_release_7' :
        path   => '/tmp/zabbix-release_2.0-1_debian_7.deb',
        ensure => 'present',
        source => 'puppet:///modules/zabbixagent/debian/zabbix-release_2.0-1_debian_7.deb'
      }

      case $::lsbmajdistrelease {
      6: {
          exec {'add_repository':
             command => 'dpkg -i /tmp/zabbix-release_2.0-1_debian_6.deb',
             path    => '/usr/bin:/bin:/sbin:/usr/sbin',
             require => File['zabbix_release_6']
            }
          }
      7: {
          exec {'add_repository':
             command => 'dpkg -i /tmp/zabbix-release_2.0-1_debian_7.deb',
             path    => '/usr/bin:/bin:/sbin:/usr/sbin',
             require => File['zabbix_release_7']
           }
          }
      }

      exec {'aptitude_update':
        command => 'aptitude update',
        path    => '/usr/bin:/bin:/sbin:/usr/sbin',
        require => Exec['add_repository']
      }	
		  
      service {'zabbix-agent' :
        ensure  => running,
        enable  => true,
        require => Package['zabbix-agent'],
      }

      ini_setting { 'servers setting':
        ensure  => present,
        path    => '/etc/zabbix/zabbix_agentd.conf',
        section => '',
        setting => 'Server',
        value   => join(flatten([$servers_real]), ','),
        notify  => Service['zabbix-agent'],
      }

      ini_setting { 'hostname setting':
        ensure  => present,
        path    => '/etc/zabbix/zabbix_agentd.conf',
        section => '',
        setting => 'Hostname',
        value   => $hostname_real,
        notify  => Service['zabbix-agent'],
      }

      ini_setting { 'Include setting':
        ensure  => present,
        path    => '/etc/zabbix/zabbix_agentd.conf',
        section => '',
        setting => 'Include',
        value   => '/etc/zabbix/zabbix_agentd/',
        notify  => Service['zabbix-agent'],
      }

      ini_setting { 'server active setting':
        ensure  => present,
        path    => '/etc/zabbix/zabbix_agentd.conf',
        section => '',
        setting => 'ServerActive',
        value   => join(flatten([$serversactive_real]), ','),
        require => Package['zabbix-agent'],
      }

      file { '/etc/zabbix/zabbix_agentd':
        ensure  => directory,
        require => Package['zabbix-agent'],
      }
    }
    windows: {
      $confdir = 'C:/ProgramData/Zabbix'
      $homedir = 'C:/Program Files/Zabbix/'

      file { $confdir: ensure => directory }
      file { "${confdir}/zabbix_agentd.conf":
        ensure  => present,
        mode    => '0770',
      }

      ini_setting { 'servers setting':
        ensure  => present,
        path    => "${confdir}/zabbix_agentd.conf",
        section => '',
        setting => 'Server',
        value   => join(flatten([$servers_real]), ','),
        require => File["${confdir}/zabbix_agentd.conf"],
        notify  => Service['Zabbix Agent'],
      }

      ini_setting { 'hostname setting':
        ensure  => present,
        path    => "${confdir}/zabbix_agentd.conf",
        section => '',
        setting => 'Hostname',
        value   => $hostname_real,
        require => File["${confdir}/zabbix_agentd.conf"],
        notify  => Service['Zabbix Agent'],
      }
      
      file { $homedir:
        ensure  => directory,
        source  => 'puppet:///modules/zabbixagent/win64',
        recurse => true,
        mode    => '0770',
      }

      exec { 'install Zabbix Agent':
        path    => $::path,
        cwd     => $homedir,
        command => "\"${homedir}/zabbix_agentd.exe\" --config ${confdir}/zabbix_agentd.conf --install",
        require => [File[$homedir], File["${confdir}/zabbix_agentd.conf"]],
        unless  => 'sc query "Zabbix Agent"'
      }

      service { 'Zabbix Agent':
        ensure  => running,
        require => Exec['install Zabbix Agent'],
      }
    }
    default: { notice "Unsupported operatingsystem  ${::operatingsystem}" }
  }
}
