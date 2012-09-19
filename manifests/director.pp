# Class: bacula::director
#
# This class manages the bacula director component
#
# Parameters:
# [*director_server*]
#   The FQDN of the bacula director
# [*password*]
#   The password of the director
# [*db_backend*]
#   The DB backend to store the catalogs in. (Currently only support +sqlite+
#   and +mysql+)
# [*storage_server*]
#   The FQDN of the storage daemon server
# [*dir_template*]
#   The ERB template to us to generate the +bacula-dir.conf+ file
#   * Default: +'bacula/bacula-dir.conf.erb'+
# [*use_console*]
#   Whether to manage the Console resource in the director
# [*console_password*]
#   If $use_console is true, then use this value for the password
#
# === Sample Usage:
#
#  class { 'bacula::director':
#    director_server  => 'bacula.domain.com',
#    password         => 'XXXXXXXXX',
#    db_backend       => 'sqlite',
#    storage_server   => 'bacula.domain.com',
#    mail_to          => 'bacula-admin@domain.com',
#    use_console      => true,
#    console_password => 'XXXXXX',
#  }
#
class bacula::director(
    $director_server  = undef,
    $password         = '',
    $db_backend       = 'sqlite',
    $db_user          = '',
    $db_password      = '',
    $db_host          = 'localhost',
    $db_database      = 'bacula',
    $db_port          = '3306',
    $storage_server   = undef,
    $mail_to          = undef,
    $dir_template     = 'bacula/bacula-dir.conf.erb',
    $use_console      = false,
    $console_password = '',
    $clients = {}
  ) {
  include bacula::params

  $director_server_real = $director_server ? {
    undef   => $bacula::params::director_server_default,
    default => $director_server,
  }
  $storage_server_real = $storage_server ? {
    undef   => $bacula::params::storage_server_default,
    default => $storage_server,
  }
  $mail_to_real = $mail_to ? {
    undef   => $bacula::params::mail_to_default,
    default => $mail_to,
  }
  $storage_name_array = split($storage_server_real, '[.]')
  $director_name_array = split($director_server_real, '[.]')
  $storage_name = $storage_name_array[0]
  $director_name = $director_name_array[0]


  # This function takes each client specified in $clients
  # and generates a bacula::client resource for each
  #
  # It also searches top scope for variables in the style
  # $::bacula_client_mynode with values in format
  # fileset=Basic:noHome,schedule=Hourly
  # In order to work with Puppet 2.6 where create_resources isn't in core,
  # we just skip the top-level stuff for now.
  if versioncmp($::puppetversion, '2.7.0') >= 0 {
    generate_clients($clients)
  } else {
    create_resources('bacula::config::client', $clients)
  }

#TODO add postgresql support
  $db_package = $db_backend ? {
    'mysql'       => $bacula::params::director_mysql_package,
    'postgresql'  => $bacula::params::director_postgresql_package,
    default       => $bacula::params::director_sqlite_package,
  }

  package { $db_package:
    ensure => present,
  }

# Create the configuration for the Director and make sure the directory for
# the per-Client configuration is created before we run the realization for
# the exported files below

#FIXME Need to set file perms
  file { '/etc/bacula/bacula-dir.conf':
    ensure  => file,
    owner   => 'bacula',
    group   => 'bacula',
    content => template($dir_template),
    require => Package[$db_package],
    notify  => Service[$bacula::params::director_service],
  }

#FIXME Need to set file perms
  file { '/etc/bacula/bacula-dir.d':
    ensure => directory,
    owner  => 'bacula',
    group  => 'bacula',
    before => Service[$bacula::params::director_service],
  }

#FIXME Need to set file perms
  file { '/etc/bacula/bacula-dir.d/empty.conf':
    ensure => file,
    before => Service[$bacula::params::director_service],
  }

  # Register the Service so we can manage it through Puppet

  service { $bacula::params::director_service:
    ensure      => running,
    enable      => true,
    hasstatus   => true,
    hasrestart  => true,
    require     => Package[$db_package],
  }
}
