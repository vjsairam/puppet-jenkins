# == Class: jenkins::slave
#
# This module setups up a swarm client for a jenkins server.  It requires the swarm plugin on the Jenkins master.
#
# https://wiki.jenkins-ci.org/display/JENKINS/Swarm+Plugin
#
# It allows users to add more workers to Jenkins without having to specifically add them on the Jenkins master.
#
# === Parameters
#
# [*masterurl*]
#   Specify the URL of the master server.  Not required, the plugin will do a UDP autodiscovery. If specified, the autodiscovery will be skipped.
#
# [*ui_user*] & [*ui_pass*]
#   User name & password for the Jenkins UI.  Not required, but may be ncessary for your config, depending on your security model.
#
# [*version*]
#   The version of the swarm client code. Must match the pluging version on the master.  Typically it's the latest available.
#
# [*executors*]
#   Number of executors for this slave.  (How many jenkins jobs can run simultaneously on this host.)
#
# [*manage_slave_user*]
#   Should the class add a user to run the slave code?  1 is currently true
#   TODO: should be updated to use boolean.
#
# [*slave_user*]
#   Defaults to 'jenkins-slave'. Change it if you'd like..
#
# [*slave_uid*]
#   Not required.  Puppet will let your system add the user, with the new UID if necessary.
#
# [*slave_home*]
#   Defaults to '/home/jenkins-slave'.  This is where the code will be installed, and the workspace will end up.
#
# [*labels*]
#   Not required.  Single string of whitespace-separated list of labels to be assigned for this slave.
#
# [*jave_version*]
#   Specified which version of java will be used.
#

# === Examples
#
#  class { 'jenkins::slave':
#    masterurl => 'http://jenkins-master1.example.com:8080',
#    ui_user => 'adminuser',
#    ui_pass => 'adminpass',
#  }
#
# === Authors
#
# Matthew Barr <mbarr@mbarr.net>
#
# === Copyright
#
# Copyright 2013 Matthew Barr , but can be used for anything by anyone..

class jenkins::slave (
  $masterurl = undef,
  $ui_user = undef,
  $ui_pass = undef,
  $version = '1.9',
  $executors = 2,
  $manage_slave_user = 1,
  $slave_user = 'jenkins-slave',
  $slave_uid = undef,
  $slave_home = '/home/jenkins-slave',
  $labels = undef,
  $java_version = '1.6.0'
) {

  $client_jar = "swarm-client-${version}-jar-with-dependencies.jar"
  $client_url = "http://maven.jenkins-ci.org/content/repositories/releases/org/jenkins-ci/plugins/swarm-client/${version}/"

  case $::osfamily {
    'RedHat', 'Linux': {
      $java_package = "java-${$java_version}-openjdk"
    }
    'Debian': {
      #needs java package for debian.
      fail( "Unsupported OS family: ${::osfamily}" )
  #    $java_package=''
    }

    default: {
      fail( "Unsupported OS family: ${::osfamily}" )
    }
  }


  #add jenkins slave if necessary.

  if $manage_slave_user == 1 and $slave_uid {
    user { 'jenkins-slave_user':
      ensure     => present,
      name       => $slave_user,
      comment    => 'Jenkins Slave user',
      home       => $slave_home,
      managehome => true,
      uid        => $slave_uid
    }
  }

  if ($manage_slave_user == 1) and (! $slave_uid) {
    user { 'jenkins-slave_user':
      ensure     => present,
      name       => $slave_user,
      comment    => 'Jenkins Slave user',
      home       => $slave_home,
      managehome => true,
    }
  }

  package { $java_package:
    ensure => installed;
  }

  exec { 'get_swarm_client':
    command      => "wget -O ${slave_home}/${client_jar} ${client_url}/${client_jar}",
    path         => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    user         => $slave_user,
    #refreshonly => true,
    creates      => "${slave_home}/${client_jar}"
    ## needs to be fixed if you create another version..
  }

  if $ui_user {
    $ui_user_flag = "-username ${ui_user}"
  }
  else {$ui_user_flag = ''}

  if $ui_pass {
    $ui_pass_flag = "-password ${ui_pass}"
  } else {
    $ui_pass_flag = ''
  }

  if $masterurl {
    $masterurl_flag = "-master ${masterurl}"
  } else {
    $masterurl_flag = ''
  }

  if $labels {
    $labels_flag = "-labels \"${labels}\""
  } else {
    $labels_flag = ''
  }

  file { '/etc/init.d/jenkins-slave':
      ensure  => 'file',
      mode    => '0700',
      owner   => 'root',
      group   => 'root',
      content => template("${module_name}/jenkins-slave.erb"),
      notify  => Service['jenkins-slave']
  }

  service { 'jenkins-slave':
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
  }

  Package[ $java_package ]
  -> Exec['get_swarm_client']
  -> Service['jenkins-slave']

}
