# jdk7::instal7
#
# On Linux low entropy can cause certain operations to be very slow.
# Encryption operations need entropy to ensure randomness. Entropy is
# generated by the OS when you use the keyboard, the mouse or the disk.
#
# If an encryption operation is missing entropy it will wait until
# enough is generated.
#
# three options
#  use rngd service (this class)
#  set java.security in JDK ( jre/lib/security )
#  set -Djava.security.egd=file:/dev/./urandom param
#
define jdk7::install7 (
  $version                   = '7u51',
  $fullVersion               = 'jdk1.7.0_51',
  $javaHomes                 = '/usr/java',
  $x64                       = true,
  $alternativesPriority      = 17065,
  $downloadDir               = '/install',
  $cryptographyExtensionFile = undef,
  $urandomJavaFix            = true,
  $rsakeySizeFix             = false,  # set true for weblogic 12.1.1 and jdk 1.7 > version 40
  $sourcePath                = 'puppet:///modules/jdk7/',
) {

  if ( $x64 == true ) {
    $type = 'x64'
  } else {
    $type = 'i586'
  }

  case $::kernel {
    'Linux': {
      $install_version   = 'linux'
      $install_extension = '.tar.gz'
      $path              = '/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:'
      $user              = 'root'
      $group             = 'root'
    }
    default: {
      fail("Unrecognized operating system ${::kernel}, please use it on a Linux host")
    }
  }

  $jdk_file = "jdk-${version}-${install_version}-${type}${install_extension}"

  exec { "create ${$downloadDir} directory":
    command => "mkdir -p ${$downloadDir}",
    unless  => "test -d ${$downloadDir}",
    path    => $path,
    user    => $user,
  }

  # check install folder
  if !defined(File[$downloadDir]) {
    file { $downloadDir:
      ensure  => directory,
      require => Exec["create ${$downloadDir} directory"],
      replace => false,
      owner   => $user,
      group   => $group,
      mode    => '0777',
    }
  }

  # download jdk to client
  file { "${downloadDir}/${jdk_file}":
    ensure  => file,
    source  => "${sourcePath}/${jdk_file}",
    require => File[$downloadDir],
    replace => false,
    owner   => $user,
    group   => $group,
    mode    => '0777',
  }

  if ( $cryptographyExtensionFile != undef ) {
    file { "${downloadDir}/${cryptographyExtensionFile}":
      ensure  => file,
      source  => "${sourcePath}/${cryptographyExtensionFile}",
      require => File[$downloadDir],
      before  => File["${downloadDir}/${jdk_file}"],
      replace => false,
      owner   => $user,
      group   => $group,
      mode    => '0777',
    }
  }

  # install on client
  jdk7::config::javaexec { "jdkexec ${title} ${version}":
    download_dir                => $downloadDir,
    full_version                => $fullVersion,
    java_homes_dir              => $javaHomes,
    jdk_file                    => $jdk_file,
    cryptography_extension_file => $cryptographyExtensionFile,
    alternatives_priority       => $alternativesPriority,
    user                        => $user,
    group                       => $group,
    require                     => File["${downloadDir}/${jdk_file}"],
  }

  if ($urandomJavaFix == true) {
    exec { "set urandom ${fullVersion}":
      command => "sed -i -e's/securerandom.source=file:\\/dev\\/urandom/securerandom.source=file:\\/dev\\/.\\/urandom/g' ${javaHomes}/${fullVersion}/jre/lib/security/java.security",
      unless  => "grep '^securerandom.source=file:/dev/./urandom' ${javaHomes}/${fullVersion}/jre/lib/security/java.security",
      require => Jdk7::Config::Javaexec["jdkexec ${title} ${version}"],
      path    => $path,
      user    => $user,
    }
  }
  if ($rsakeySizeFix == true) {
    exec { "sleep 3 sec for urandomJavaFix ${fullVersion}":
      command => '/bin/sleep 3',
      unless  => "grep 'RSA keySize < 512' ${javaHomes}/${fullVersion}/jre/lib/security/java.security",
      require => Jdk7::Config::Javaexec["jdkexec ${title} ${version}"],
      path    => $path,
      user    => $user,
    }
    exec { "set RSA keySize ${fullVersion}":
      command     => "sed -i -e's/RSA keySize < 1024/RSA keySize < 512/g' ${javaHomes}/${fullVersion}/jre/lib/security/java.security",
      unless      => "grep 'RSA keySize < 512' ${javaHomes}/${fullVersion}/jre/lib/security/java.security",
      subscribe   => Exec["sleep 3 sec for urandomJavaFix ${fullVersion}"],
      refreshonly => true,
      path        => $path,
      user        => $user,
    }
  }
}
