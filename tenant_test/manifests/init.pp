class check_mk_ws2016 {

  $checkmkhost = lookup('checkmkmonitoringhost')
  $checkmkenv = lookup('checkmkenvironment')
  $checkmkuser = lookup('checkmkuser')
  $checkmkpass = lookup('checkmkpassword')
  $checkmkcert = lookup('checkmkcert')
  $checkmkproxyaddr = lookup('checkmkproxyaddr')
  $checkmkproxyport = lookup('checkmkproxyport')

  file { 'C:\Windows\Temp\check_mk_agent.msi':
    ensure => present,
    source => 'puppet:///modules/check_mk_ws2016/check_mk_agent.msi'
  }

  package { 'Check_MK Agent':
    ensure          => '1.4.0.2853',
    source          => 'C:\Windows\Temp\check_mk_agent.msi',
    install_options => ['/quiet'],
    require         => File['C:\Windows\Temp\check_mk_agent.msi'],
  }

  file { 'C:\Program Files (x86)\check_mk\check_mk.ini':
    ensure => present,
    source => 'puppet:///modules/check_mk_ws2016/check_mk.ini',
    require => Package['Check_MK Agent'],
    notify => Service['check_mk_agent'],
  }
  service { 'check_mk_agent':
    ensure => running,
    enable => true,
    require => Package['Check_MK Agent'],
  }

  file { 'C:\Windows\Temp\addHostNagios.rb':
    ensure  => 'file',
    mode    => '0660',
    owner   => 'VF-admin',
    group   => 'Administrators',
    content => epp('check_mk_ws2016/addHostNagios.rb.epp', {'checkmkhost' => $checkmkhost, 'checkmkenv' => $checkmkenv, 'checkmkuser' => $checkmkuser, 'checkmksecret' => $checkmkpass, 'checkmkcert' => $checkmkcert, 'checkmkproxyaddr' => $checkmkproxyaddr, 'checkmkproxyport' => $checkmkproxyport }),
  }

  exec {'trigger_nagios':
    path      => "C:\Program Files\Puppet Labs\Puppet\sys\ruby\bin",
    command   => "ruby C:\Windows\Temp\addHostNagios.rb"
    provider  => "windows",
    subscribe => File['C:\Windows\Temp\addHostNagios.rb'],
    logoutput => true,
  }
}
